from flask import Blueprint, jsonify, abort, Response, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import is_logged_in, ensure_invoice_schema

try:
    import serial
    import serial.tools.list_ports
    SERIAL_OK = True
except ImportError:
    SERIAL_OK = False

thermal_bp = Blueprint("thermal", __name__)


def _build_escpos(invoice, items, paper_width=80):
    ESC, GS, LF = 0x1B, 0x1D, 0x0A
    W = 32 if paper_width == 58 else 48

    def enc(s):
        return [c if c < 128 else 0x3F for c in s.encode("ascii", errors="replace")]

    def pad_row(left, right, w):
        left, right = str(left or ""), str(right or "")
        gap = max(1, w - len(left) - len(right))
        line = left + " " * gap + right
        return enc(line[:w]) + [LF]

    buf = []
    b = buf.extend

    b([ESC, 0x40])
    b([ESC, 0x74, 0x00])

    b([ESC, 0x61, 0x01])
    b([ESC, 0x21, 0x30])
    b([ESC, 0x45, 0x01])
    b(enc("UMGAP") + [LF])
    b([ESC, 0x21, 0x00])
    b([ESC, 0x45, 0x00])
    b(enc("Nota Penjualan") + [LF])

    dash = enc("-" * W) + [LF]

    b(dash)
    b([ESC, 0x61, 0x00])

    inv_no = str(invoice.get("invoice_no", "") or "")
    created = ""
    if invoice.get("created_at"):
        try:
            created = invoice["created_at"].strftime("%d/%m/%Y %H:%M")
        except Exception:
            created = str(invoice["created_at"])[:16]

    b(pad_row("No", inv_no[:W - 3], W))
    b(pad_row("Tanggal", created, W))
    b(pad_row("Customer", str(invoice.get("customer_name") or "-")[:W - 10], W))
    b(pad_row("Kasir", str(invoice.get("created_by_name") or "-")[:W - 6], W))
    b(pad_row("Bayar", str(invoice.get("payment_method") or "CASH"), W))
    b(dash)

    for item in items:
        name = str(item.get("product_name", "") or "")
        qty = int(item.get("qty", 1) or 1)
        price = int(item.get("price", 0) or 0)
        sub = int(item.get("subtotal", 0) or 0)
        price_fmt = "{:,}".format(price).replace(",", ".")
        sub_fmt = "{:,}".format(sub).replace(",", ".")
        b([ESC, 0x45, 0x01])
        b(enc(name[:W]) + [LF])
        b([ESC, 0x45, 0x00])
        detail_left = "  {} x Rp {}".format(qty, price_fmt)
        detail_right = "Rp {}".format(sub_fmt)
        b(pad_row(detail_left, detail_right, W))

    b(dash)

    grand = int(invoice.get("grand_total", 0) or 0)
    grand_fmt = "{:,}".format(grand).replace(",", ".")
    b([ESC, 0x61, 0x02])
    b([ESC, 0x21, 0x10])
    b([ESC, 0x45, 0x01])
    b(enc("TOTAL: Rp {}".format(grand_fmt)) + [LF])
    b([ESC, 0x21, 0x00])
    b([ESC, 0x45, 0x00])
    b([ESC, 0x61, 0x00])
    b(dash)

    notes = str(invoice.get("notes") or "").strip()
    if notes:
        b(enc("Catatan: " + notes[:W - 9]) + [LF])
        b(dash)

    b([ESC, 0x61, 0x01])
    b(enc("Terima kasih sudah berbelanja!") + [LF])
    b([LF, LF, LF])

    b([GS, 0x56, 0x42, 0x20])

    return bytes(buf)


def _get_invoice_with_items(invoice_id):
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT i.*, u.name AS created_by_name
            FROM invoices i
            JOIN users u ON u.id = i.created_by
            WHERE i.id=%s
            LIMIT 1;
        """, (invoice_id,))
        inv = cur.fetchone()
        if not inv:
            return None, []

        cur.execute("""
            SELECT product_name, qty, price, subtotal
            FROM invoice_items
            WHERE invoice_id=%s
            ORDER BY id;
        """, (invoice_id,))
        items = cur.fetchall()

        return dict(inv), [dict(r) for r in items]
    finally:
        cur.close()
        conn.close()


@thermal_bp.route("/invoice/<int:invoice_id>/escpos")
def invoice_escpos(invoice_id):
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401

    ensure_invoice_schema()
    inv, items = _get_invoice_with_items(invoice_id)
    if not inv:
        abort(404)

    pw_str = (inv.get("print_size") or "80mm").replace("mm", "")
    pw = 58 if pw_str == "58" else 80

    data = _build_escpos(inv, items, paper_width=pw)
    fname = "nota_{}.bin".format(inv.get("invoice_no", str(invoice_id)))

    return Response(
        data,
        mimetype="application/octet-stream",
        headers={"Content-Disposition": 'attachment; filename="{}"'.format(fname)},
    )


@thermal_bp.route("/invoice/<int:invoice_id>/print-server", methods=["POST"])
def invoice_print_server(invoice_id):
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401

    if not SERIAL_OK:
        return jsonify({"ok": False, "error": "pyserial tidak terinstall di server. Jalankan: pip install pyserial"}), 500

    ensure_invoice_schema()
    inv, items = _get_invoice_with_items(invoice_id)
    if not inv:
        return jsonify({"ok": False, "error": "Invoice tidak ditemukan"}), 404

    com_port = (request.json or {}).get("port", "").strip()
    pw_str = (inv.get("print_size") or "80mm").replace("mm", "")
    pw = 58 if pw_str == "58" else 80

    if not com_port:
        ports = serial.tools.list_ports.comports()
        for p in ports:
            desc = (p.description or "").lower()
            if "bluetooth" in desc or "spp" in desc or "serial" in desc or "com" in desc.lower():
                com_port = p.device
                break
        if not com_port and ports:
            com_port = ports[0].device

    if not com_port:
        return jsonify({"ok": False, "error": "Tidak ada COM port ditemukan. Pastikan printer sudah di-pair di Windows."}), 400

    try:
        data = _build_escpos(inv, items, paper_width=pw)
        with serial.Serial(com_port, baudrate=9600, timeout=3) as ser:
            ser.write(data)
        return jsonify({"ok": True, "port": com_port, "bytes": len(data)})
    except serial.SerialException as e:
        return jsonify({"ok": False, "error": "Serial error: {}".format(str(e))}), 500
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@thermal_bp.route("/invoice/<int:invoice_id>/list-ports")
def invoice_list_ports(invoice_id):
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401

    if not SERIAL_OK:
        return jsonify({"ok": False, "ports": [], "error": "pyserial tidak terinstall"}), 200

    ports = [{"device": p.device, "desc": p.description} for p in serial.tools.list_ports.comports()]
    return jsonify({"ok": True, "ports": ports})
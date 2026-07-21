import io
import json

from flask import Blueprint, render_template, request, redirect, session, jsonify, abort, send_file, flash
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import (
    is_logged_in,
    owner_or_admin_required,
    get_materials_with_stock,
    get_company_profile,
    set_company_profile,
    create_fin_invoice,
    create_fin_purchase_invoice,
    get_invoice_history,
    get_fin_invoice_detail,
    settle_fin_debt_for_transaction,
    cancel_fin_transaction,
    get_notif_count,
)

nota_bp = Blueprint("nota", __name__)


# ---------- BUAT NOTA ----------
@nota_bp.route("/nota/new", methods=["GET", "POST"])
def nota_new():
    deny = owner_or_admin_required()
    if deny:
        return deny

    if request.method == "POST":
        try:
            items = json.loads(request.form.get("items_json") or "[]")
        except Exception:
            items = []

        nota_type = (request.form.get("nota_type") or "JUAL").strip().upper()
        is_paid = str(request.form.get("is_paid") or "1") in ("1", "true", "True", "on", "yes")

        try:
            if nota_type == "BELI":
                result = create_fin_purchase_invoice(
                    supplier_name=request.form.get("customer_name"),
                    supplier_phone=request.form.get("customer_phone"),
                    payment_method=request.form.get("payment_method") or "CASH",
                    notes=request.form.get("notes"),
                    discount=request.form.get("discount") or 0,
                    is_paid=is_paid,
                    items=items,
                    created_by=session.get("user_id"),
                )
            else:
                result = create_fin_invoice(
                    customer_name=request.form.get("customer_name"),
                    customer_phone=request.form.get("customer_phone"),
                    payment_method=request.form.get("payment_method") or "CASH",
                    notes=request.form.get("notes"),
                    discount=request.form.get("discount") or 0,
                    is_paid=is_paid,
                    items=items,
                    created_by=session.get("user_id"),
                )
            return redirect(f"/nota/{result['invoice_id']}")
        except ValueError as e:
            flash(str(e), "danger")
            return redirect("/nota/new")

    return render_template(
        "invoice_form.html",
        materials=get_materials_with_stock(),
        company_profile=get_company_profile(),
        notif_count=get_notif_count(),
    )


# ---------- RIWAYAT ----------
@nota_bp.route("/nota")
def nota_history():
    deny = owner_or_admin_required()
    if deny:
        return deny

    q = (request.args.get("q") or "").strip()
    type_f = (request.args.get("type") or "").strip().upper()
    status_f = (request.args.get("status") or "").strip().upper()
    date_from = (request.args.get("date_from") or "").strip()
    date_to = (request.args.get("date_to") or "").strip()

    invoices, total = get_invoice_history(
        q=q, type_f=type_f, status_f=status_f,
        date_from=date_from, date_to=date_to,
        limit=200, offset=0,
    )

    return render_template(
        "nota_history.html",
        invoices=invoices,
        total=total,
        q=q, type_f=type_f, status_f=status_f,
        date_from=date_from, date_to=date_to,
    )


# ---------- DETAIL / CETAK ----------
@nota_bp.route("/nota/<int:txn_id>")
def nota_detail(txn_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    invoice, items = get_fin_invoice_detail(txn_id)
    if not invoice:
        abort(404)

    return render_template(
        "invoice_print.html",
        invoice=invoice,
        items=items,
        action_base=f"/nota/{txn_id}",
        is_legacy=False,
    )


@nota_bp.route("/nota/<int:txn_id>/pdf")
def nota_pdf(txn_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    invoice, items = get_fin_invoice_detail(txn_id)
    if not invoice:
        abort(404)

    html = render_template("invoice_pdf.html", invoice=invoice, items=items)
    filename = f"{invoice['invoice_no']}.pdf"

    try:
        from weasyprint import HTML
        pdf_bytes = HTML(string=html).write_pdf()
        return send_file(
            io.BytesIO(pdf_bytes),
            mimetype="application/pdf",
            as_attachment=True,
            download_name=filename,
        )
    except Exception:
        from xhtml2pdf import pisa
        pdf_io = io.BytesIO()
        pisa.CreatePDF(src=html, dest=pdf_io)
        pdf_io.seek(0)
        return send_file(
            pdf_io,
            mimetype="application/pdf",
            as_attachment=True,
            download_name=filename,
        )


# ---------- THERMAL (ESC/POS via serial di server) ----------
@nota_bp.route("/nota/<int:txn_id>/escpos")
def nota_escpos(txn_id):
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401

    from routes.web.thermal import _build_escpos

    invoice, items = get_fin_invoice_detail(txn_id)
    if not invoice:
        abort(404)

    pw_str = (invoice.get("print_size") or "80mm").replace("mm", "")
    pw = 58 if pw_str == "58" else 80
    data = _build_escpos(invoice, items, paper_width=pw)
    fname = "nota_{}.bin".format(invoice.get("invoice_no", str(txn_id)))

    from flask import Response
    return Response(
        data,
        mimetype="application/octet-stream",
        headers={"Content-Disposition": f'attachment; filename="{fname}"'},
    )


@nota_bp.route("/nota/<int:txn_id>/print-server", methods=["POST"])
def nota_print_server(txn_id):
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401

    try:
        import serial
        import serial.tools.list_ports
        SERIAL_OK = True
    except ImportError:
        SERIAL_OK = False

    if not SERIAL_OK:
        return jsonify({"ok": False, "error": "pyserial tidak terinstall di server. Jalankan: pip install pyserial"}), 500

    from routes.web.thermal import _build_escpos

    invoice, items = get_fin_invoice_detail(txn_id)
    if not invoice:
        return jsonify({"ok": False, "error": "Nota tidak ditemukan"}), 404

    com_port = (request.json or {}).get("port", "").strip()
    pw_str = (invoice.get("print_size") or "80mm").replace("mm", "")
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
        data = _build_escpos(invoice, items, paper_width=pw)
        with serial.Serial(com_port, baudrate=9600, timeout=3) as ser:
            ser.write(data)
        return jsonify({"ok": True, "port": com_port, "bytes": len(data)})
    except serial.SerialException as e:
        return jsonify({"ok": False, "error": f"Serial error: {e}"}), 500
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


# ---------- MARK PAID ----------
@nota_bp.route("/nota/<int:txn_id>/mark-paid", methods=["POST"])
def nota_mark_paid(txn_id):
    if not is_logged_in():
        return jsonify({"ok": False}), 401

    data = request.get_json(silent=True) or {}
    is_paid = bool(data.get("is_paid"))

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        if is_paid:
            settle_fin_debt_for_transaction(cur, txn_id)
        else:
            cur.execute("UPDATE fin_transactions SET is_debt=TRUE WHERE id=%s RETURNING id;", (txn_id,))
            if not cur.fetchone():
                raise ValueError("Nota tidak ditemukan.")
        conn.commit()
    except ValueError as e:
        conn.rollback()
        return jsonify({"ok": False, "error": str(e)}), 400
    finally:
        cur.close()
        conn.close()

    return jsonify({"ok": True, "invoice_id": txn_id, "is_paid": is_paid})


# ---------- BATALKAN NOTA ----------
@nota_bp.route("/nota/<int:txn_id>/cancel", methods=["POST"])
def nota_cancel(txn_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        cancel_fin_transaction(txn_id, session.get("user_id"))
        flash("Nota berhasil dibatalkan, stok gudang sudah dikembalikan.", "success")
    except ValueError as e:
        flash(str(e), "danger")

    return redirect("/nota")


# ---------- PROFIL PERUSAHAAN ----------
@nota_bp.route("/nota/company-profile", methods=["GET", "POST"])
def nota_company_profile():
    deny = owner_or_admin_required()
    if deny:
        return deny

    if request.method == "POST":
        company_name = (request.form.get("company_name") or "").strip()
        logo_file = request.files.get("company_logo")

        logo_data_uri = None
        if logo_file and logo_file.filename:
            raw = logo_file.read()
            if len(raw) > 2_800_000:
                flash("Logo terlalu besar. Maksimal 2MB.", "danger")
                return redirect("/nota/company-profile")
            import base64
            mime = logo_file.mimetype or "image/png"
            logo_data_uri = f"data:{mime};base64,{base64.b64encode(raw).decode('ascii')}"

        set_company_profile(company_name, logo_data_uri, session.get("user_id"))
        flash("Info perusahaan tersimpan.", "success")
        return redirect("/nota/new")

    return render_template(
        "nota_company_profile.html",
        company_profile=get_company_profile(),
    )

import io
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP

from flask import Blueprint, request, send_file
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import (
    mobile_api_response,
    mobile_api_login_required,
    ensure_invoice_schema,
    _utc_naive_to_wib_string,
    _safe_int,
    _safe_decimal,
    _save_company_logo,
)

mobile_invoice_bp = Blueprint("mobile_invoice", __name__)


def _invoice_rows_from_json(items):
    rows = []
    if not isinstance(items, list):
        return rows
    for item in items:
        try:
            pid = int(item.get("product_id") or 0)
            qty = _safe_decimal(item.get("qty"), "0")
            if pid > 0 and qty > 0:
                rows.append({"product_id": pid, "qty": qty})
        except Exception:
            pass
    return rows


def _make_invoice_no():
    from datetime import datetime
    import uuid
    now = datetime.now()
    return "INV-" + now.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:5].upper()


@mobile_invoice_bp.route("/invoice/products", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_invoice_products():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    ensure_invoice_schema()
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, name, price
            FROM products
            WHERE is_global=TRUE
            ORDER BY name ASC;
        """)
        products = [dict(r) for r in cur.fetchall()]

        data = {"products": products}
        role = str(request.mobile_user.get("role") or "").strip().lower()
        if role in ("admin", "owner"):
            cur.execute("""
                SELECT id, name, email
                FROM users
                WHERE role='employee'
                ORDER BY name ASC;
            """)
            data["employees"] = [dict(r) for r in cur.fetchall()]

        return mobile_api_response(ok=True, message="OK", data=data, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_invoice_bp.route("/invoice", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_invoice_create():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    ensure_invoice_schema()
    user = request.mobile_user

    customer_name = (request.form.get("customer_name") or "").strip()
    customer_phone = (request.form.get("customer_phone") or "").strip()
    company_name = (request.form.get("company_name") or "").strip()
    payment_method = (request.form.get("payment_method") or "CASH").strip().upper()
    print_size = (request.form.get("print_size") or "80mm").strip()
    notes = (request.form.get("notes") or "").strip()
    discount = max(0, _safe_int(request.form.get("discount"), 0))
    is_paid = str(request.form.get("is_paid") or "1").strip() in ("1", "true", "True", "on", "yes")
    paid_at = datetime.utcnow() if is_paid else None

    logo_file = request.files.get("company_logo")
    company_logo_path = None
    if logo_file and logo_file.filename:
        try:
            company_logo_path = _save_company_logo(logo_file)
        except Exception:
            company_logo_path = None

    target_user_id = user["user_id"]
    role = str(user.get("role") or "").strip().lower()
    if role in ("admin", "owner"):
        emp_id = _safe_int(request.form.get("employee_id"), 0)
        if emp_id > 0:
            target_user_id = emp_id

    # items[] dikirim sebagai JSON string atau field product_id[] / qty[]
    import json
    items_json_str = request.form.get("items_json")
    if items_json_str:
        try:
            parsed = json.loads(items_json_str)
            item_rows = _invoice_rows_from_json(parsed)
        except Exception as e:
            print(f"[invoice] items_json parse error: {e}")
            item_rows = []
    else:
        product_ids = request.form.getlist("product_id[]")
        qtys = request.form.getlist("qty[]")
        item_rows = []
        for i in range(min(len(product_ids), len(qtys))):
            pid = _safe_int(product_ids[i], 0)
            qty = _safe_decimal(qtys[i], "0")
            if pid > 0 and qty > 0:
                item_rows.append({"product_id": pid, "qty": qty})

    if not item_rows:
        return mobile_api_response(ok=False, message="Item invoice kosong.", status_code=400)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        invoice_no = _make_invoice_no()
        final_items = []
        subtotal = Decimal("0")

        for row in item_rows:
            cur.execute("""
                SELECT id, name, price
                FROM products
                WHERE id=%s AND is_global=TRUE
                LIMIT 1;
            """, (row["product_id"],))
            p = cur.fetchone()
            if not p:
                continue

            qty = _safe_decimal(row["qty"], "0")
            price = Decimal(str(int(p.get("price") or 0)))
            line_subtotal = (qty * price).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
            subtotal += line_subtotal

            final_items.append({
                "product_id": p["id"],
                "product_name": p["name"],
                "qty": qty,
                "price": int(price),
                "subtotal": int(line_subtotal)
            })

        if not final_items:
            return mobile_api_response(ok=False, message="Semua item invoice tidak valid.", status_code=400)

        grand_total = max(0, subtotal - discount)

        cur.execute("""
            INSERT INTO invoices
                (invoice_no, created_by, customer_name, customer_phone, company_name, company_logo_path,
                 print_size, payment_method, subtotal, discount, grand_total, notes, is_paid, paid_at)
            VALUES
                (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id;
        """, (
            invoice_no,
            user["user_id"],
            customer_name,
            customer_phone,
            company_name,
            company_logo_path,
            print_size,
            payment_method,
            subtotal,
            discount,
            grand_total,
            notes,
            is_paid,
            paid_at
        ))
        invoice_id = (cur.fetchone() or {}).get("id")

        for item in final_items:
            cur.execute("""
                INSERT INTO invoice_items
                (invoice_id, product_id, product_name, qty, price, subtotal)
                VALUES (%s,%s,%s,%s,%s,%s);
            """, (
                invoice_id,
                item["product_id"],
                item["product_name"],
                str(item["qty"]),
                item["price"],
                item["subtotal"]
            ))

            cur.execute("""
                INSERT INTO sales_submissions
                (user_id, product_id, qty, note, status, created_at)
                VALUES (%s,%s,%s,%s,'APPROVED',CURRENT_TIMESTAMP);
            """, (
                target_user_id,
                item["product_id"],
                int(Decimal(str(item["qty"])).quantize(Decimal("1"), rounding=ROUND_HALF_UP)),
                f"INVOICE {invoice_no}"
            ))

        conn.commit()

        return mobile_api_response(
            ok=True,
            message="Invoice berhasil dibuat.",
            data={"invoice_id": invoice_id, "invoice_no": invoice_no},
            status_code=200
        )
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=f"Gagal membuat invoice: {str(e)}", status_code=500)
    finally:
        cur.close()
        conn.close()


@mobile_invoice_bp.route("/invoice/<int:invoice_id>", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_invoice_detail(invoice_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    ensure_invoice_schema()

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
        invoice = cur.fetchone()

        if not invoice:
            return mobile_api_response(ok=False, message="Invoice tidak ditemukan.", status_code=404)

        cur.execute("""
            SELECT id, product_id, product_name, qty, price, subtotal
            FROM invoice_items
            WHERE invoice_id=%s
            ORDER BY id ASC;
        """, (invoice_id,))
        items = cur.fetchall()

        inv = dict(invoice)
        inv["created_at_wib"] = _utc_naive_to_wib_string(inv.get("created_at"))
        inv["paid_at_wib"] = _utc_naive_to_wib_string(inv.get("paid_at")) if inv.get("paid_at") else None
        inv.setdefault("is_paid", True)
        inv.setdefault("discount", 0)
        inv.setdefault("customer_phone", "")
        inv.setdefault("company_name", "")
        inv.setdefault("company_logo_path", None)

        return mobile_api_response(
            ok=True,
            message="OK",
            data={"invoice": inv, "items": [dict(r) for r in items]},
            status_code=200
        )
    finally:
        cur.close()
        conn.close()


@mobile_invoice_bp.route("/invoice/<int:invoice_id>/mark-paid", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_invoice_mark_paid(invoice_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    ensure_invoice_schema()
    data = request.get_json(silent=True) or {}
    is_paid = bool(data.get("is_paid"))
    paid_at = datetime.utcnow() if is_paid else None

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            UPDATE invoices
            SET is_paid=%s, paid_at=%s
            WHERE id=%s
            RETURNING id, is_paid, paid_at;
        """, (is_paid, paid_at, invoice_id))
        row = cur.fetchone()
        conn.commit()

        if not row:
            return mobile_api_response(ok=False, message="Invoice tidak ditemukan.", status_code=404)

        return mobile_api_response(
            ok=True,
            message="Status pembayaran diperbarui.",
            data={
                "invoice_id": row["id"],
                "is_paid": row["is_paid"],
                "paid_at_wib": _utc_naive_to_wib_string(row["paid_at"]) if row["paid_at"] else None
            },
            status_code=200
        )
    finally:
        cur.close()
        conn.close()

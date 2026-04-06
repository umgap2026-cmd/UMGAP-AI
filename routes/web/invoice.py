import io
from datetime import datetime

from flask import Blueprint, render_template, request, redirect, session, jsonify, abort, send_file
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import is_logged_in, admin_required, ensure_invoice_schema, save_invoice_common, _utc_naive_to_wib_string

invoice_bp = Blueprint("invoice", __name__)


# ---------- USER ----------
@invoice_bp.route("/invoice/new", methods=["GET", "POST"])
def invoice_new_user():
    if not is_logged_in():
        return redirect("/login")

    if session.get("role") == "admin":
        return redirect("/admin/invoice/new")

    ensure_invoice_schema()

    if request.method == "POST":
        return save_invoice_common(request, is_admin_mode=False)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        cur.execute("""
            SELECT id, name, price
            FROM products
            WHERE is_global=TRUE
            ORDER BY name ASC;
        """)
        products = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template(
        "invoice_form.html",
        products=products,
        is_admin_mode=False
    )


# ---------- ADMIN ----------
@invoice_bp.route("/admin/invoice/new", methods=["GET", "POST"])
def invoice_new_admin():
    deny = admin_required()
    if deny:
        return deny

    ensure_invoice_schema()

    if request.method == "POST":
        return save_invoice_common(request, is_admin_mode=True)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        cur.execute("""
            SELECT id, name, price
            FROM products
            WHERE is_global=TRUE
            ORDER BY name ASC;
        """)
        products = cur.fetchall()

        cur.execute("""
            SELECT id, name, email
            FROM users
            WHERE role='employee'
            ORDER BY name ASC;
        """)
        employees = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template(
        "invoice_form.html",
        products=products,
        employees=employees,
        is_admin_mode=True
    )


# ---------- VIEW ----------
@invoice_bp.route("/invoice/<int:invoice_id>")
def invoice_view(invoice_id):
    if not is_logged_in():
        return redirect("/login")

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
            abort(404)

        cur.execute("""
            SELECT id, product_id, product_name, qty, price, subtotal
            FROM invoice_items
            WHERE invoice_id=%s
            ORDER BY id ASC;
        """, (invoice_id,))
        items = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    invoice["created_at_wib"] = _utc_naive_to_wib_string(invoice.get("created_at"))
    invoice["paid_at_wib"] = _utc_naive_to_wib_string(invoice.get("paid_at")) if invoice.get("paid_at") else None

    invoice.setdefault("is_paid", True)
    invoice.setdefault("discount", 0)
    invoice.setdefault("customer_phone", "")
    invoice.setdefault("company_name", "")
    invoice.setdefault("company_logo_path", None)

    return render_template("invoice_print.html", invoice=invoice, items=items)


# ---------- JSON ----------
@invoice_bp.route("/invoice/<int:invoice_id>/json")
def invoice_json(invoice_id):
    if not is_logged_in():
        return jsonify({"ok": False}), 401

    ensure_invoice_schema()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        cur.execute("SELECT * FROM invoices WHERE id=%s LIMIT 1;", (invoice_id,))
        invoice = cur.fetchone()

        if not invoice:
            return jsonify({"ok": False}), 404

        cur.execute("""
            SELECT product_name, qty, price, subtotal
            FROM invoice_items
            WHERE invoice_id=%s;
        """, (invoice_id,))
        items = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return jsonify({"ok": True, "invoice": invoice, "items": items})


# ---------- MARK PAID ----------
@invoice_bp.route("/invoice/<int:invoice_id>/mark-paid", methods=["POST"])
def invoice_mark_paid(invoice_id):
    if not is_logged_in():
        return jsonify({"ok": False}), 401

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
    finally:
        cur.close()
        conn.close()

    if not row:
        return jsonify({"ok": False}), 404

    return jsonify({
        "ok": True,
        "invoice_id": row["id"],
        "is_paid": row["is_paid"],
        "paid_at_wib": _utc_naive_to_wib_string(row["paid_at"]) if row["paid_at"] else None
    })


# ---------- PDF ----------
@invoice_bp.route("/invoice/<int:invoice_id>/pdf")
def invoice_pdf(invoice_id):
    if not is_logged_in():
        return redirect("/login")

    ensure_invoice_schema()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        cur.execute("""
            SELECT i.*, u.name AS created_by_name
            FROM invoices i
            JOIN users u ON u.id = i.created_by
            WHERE i.id=%s;
        """, (invoice_id,))
        invoice = cur.fetchone()

        if not invoice:
            abort(404)

        cur.execute("""
            SELECT product_name, qty, price, subtotal
            FROM invoice_items
            WHERE invoice_id=%s;
        """, (invoice_id,))
        items = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    invoice["created_at_wib"] = _utc_naive_to_wib_string(invoice.get("created_at"))
    invoice["paid_at_wib"] = _utc_naive_to_wib_string(invoice.get("paid_at")) if invoice.get("paid_at") else None

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
    except:
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
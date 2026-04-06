from flask import Blueprint, render_template, request, redirect, session
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import is_logged_in, admin_guard

sales_bp = Blueprint("sales", __name__)


# ---------- USER SALES ----------
@sales_bp.route("/sales", methods=["GET", "POST"])
def sales_user():
    if not is_logged_in():
        return redirect("/login")

    if session.get("role") == "admin":
        return redirect("/admin/sales")

    if request.method == "POST":
        product_id = request.form.get("product_id")
        qty = request.form.get("qty") or "0"
        note = (request.form.get("note") or "").strip()

        try:
            product_id = int(product_id)
            qty_int = int(qty)
        except:
            return redirect("/sales")

        if qty_int <= 0:
            return redirect("/sales")

        conn = get_conn()
        cur = conn.cursor(cursor_factory=RealDictCursor)

        try:
            cur.execute("""
                SELECT id FROM products
                WHERE id=%s AND is_global=TRUE
                LIMIT 1;
            """, (product_id,))

            if not cur.fetchone():
                return redirect("/sales")

            cur.execute("""
                INSERT INTO sales_submissions
                (user_id, product_id, qty, note, status)
                VALUES (%s,%s,%s,%s,'PENDING');
            """, (session["user_id"], product_id, qty_int, note))

            conn.commit()
        finally:
            cur.close()
            conn.close()

        return redirect("/sales")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        cur.execute("""
            SELECT id, name, price
            FROM products
            WHERE is_global=TRUE
            ORDER BY id DESC;
        """)
        products = cur.fetchall()

        cur.execute("""
            SELECT
                s.id,
                s.qty,
                s.note,
                s.status,
                s.admin_note,
                s.created_at,
                (s.created_at + interval '7 hour') AS created_at_wib,
                COALESCE(p.name, '-') AS product_name
            FROM sales_submissions s
            LEFT JOIN products p ON p.id = s.product_id
            WHERE s.user_id=%s
            ORDER BY s.id DESC
            LIMIT 50;
        """, (session["user_id"],))

        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template("sales.html", products=products, rows=rows)


# ---------- ADMIN SALES ----------
@sales_bp.route("/admin/sales")
def admin_sales():
    admin_guard()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        cur.execute("""
            SELECT
                s.id,
                s.qty,
                s.note,
                s.status,
                s.admin_note,
                s.created_at,
                (s.created_at + interval '7 hour') AS created_at_wib,
                u.name AS employee_name,
                COALESCE(p.name, '-') AS product_name
            FROM sales_submissions s
            JOIN users u ON u.id = s.user_id
            LEFT JOIN products p ON p.id = s.product_id
            ORDER BY
                (CASE WHEN s.status='PENDING' THEN 0 ELSE 1 END),
                s.created_at DESC
            LIMIT 300;
        """)
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template("admin_sales.html", rows=rows)


@sales_bp.route("/admin/sales/approve/<int:sid>", methods=["POST"])
def admin_sales_approve(sid):
    admin_guard()

    admin_note = (request.form.get("admin_note") or "").strip()

    conn = get_conn()
    cur = conn.cursor()

    try:
        cur.execute("""
            UPDATE sales_submissions
            SET status='APPROVED',
                admin_note=%s,
                decided_at=CURRENT_TIMESTAMP,
                decided_by=%s
            WHERE id=%s;
        """, (admin_note, session["user_id"], sid))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/sales")


@sales_bp.route("/admin/sales/reject/<int:sid>", methods=["POST"])
def admin_sales_reject(sid):
    admin_guard()

    admin_note = (request.form.get("admin_note") or "").strip()

    conn = get_conn()
    cur = conn.cursor()

    try:
        cur.execute("""
            UPDATE sales_submissions
            SET status='REJECTED',
                admin_note=%s,
                decided_at=CURRENT_TIMESTAMP,
                decided_by=%s
            WHERE id=%s;
        """, (admin_note, session["user_id"], sid))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/sales")


@sales_bp.route("/admin/sales/monitor")
def admin_sales_monitor():
    admin_guard()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        cur.execute("""
            SELECT
                u.id,
                u.name AS employee_name,
                COALESCE(SUM(s.qty), 0) AS total_qty
            FROM users u
            LEFT JOIN sales_submissions s
                ON s.user_id = u.id AND s.status='APPROVED'
            WHERE u.role='employee'
            GROUP BY u.id, u.name
            ORDER BY total_qty DESC, u.name ASC;
        """)
        summary = cur.fetchall()

        cur.execute("""
            SELECT
                s.created_at,
                (s.created_at + interval '7 hour') AS created_at_wib,
                u.name AS employee_name,
                COALESCE(p.name, '-') AS product_name,
                s.qty,
                s.status,
                s.note,
                s.admin_note
            FROM sales_submissions s
            JOIN users u ON u.id = s.user_id
            LEFT JOIN products p ON p.id = s.product_id
            ORDER BY s.created_at DESC
            LIMIT 200;
        """)
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template("admin_sales_monitor.html", summary=summary, rows=rows)
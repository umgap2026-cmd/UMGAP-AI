from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_sales_bp = Blueprint("mobile_sales", __name__)


def _fmt_sales_row(r):
    item = dict(r)
    if item.get("created_at"):
        item["created_at"] = item["created_at"].strftime("%Y-%m-%d %H:%M:%S")
    if item.get("created_at_wib"):
        item["created_at_wib"] = item["created_at_wib"].strftime("%Y-%m-%d %H:%M:%S")
    return item


@mobile_sales_bp.route("/sales", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_sales_list():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        if user.get("role") == "admin":
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
        else:
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
            """, (user["user_id"],))

        rows = [_fmt_sales_row(r) for r in cur.fetchall()]
        return mobile_api_response(ok=True, message="OK", data={"sales": rows}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_sales_bp.route("/sales", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_sales_submit():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    data = request.get_json(silent=True) or {}

    try:
        product_id = int(data.get("product_id"))
        qty_int = int(data.get("qty") or 0)
    except Exception:
        return mobile_api_response(ok=False, message="Produk atau qty tidak valid.", status_code=400)

    note = (data.get("note") or "").strip()

    if qty_int <= 0:
        return mobile_api_response(ok=False, message="Qty harus lebih dari 0.", status_code=400)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id FROM products
            WHERE id=%s AND is_global=TRUE
            LIMIT 1;
        """, (product_id,))
        if not cur.fetchone():
            return mobile_api_response(ok=False, message="Produk tidak ditemukan.", status_code=404)

        cur.execute("""
            INSERT INTO sales_submissions
            (user_id, product_id, qty, note, status)
            VALUES (%s,%s,%s,%s,'PENDING');
        """, (user["user_id"], product_id, qty_int, note))
        conn.commit()

        return mobile_api_response(ok=True, message="Penjualan berhasil dikirim.", data={}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_sales_bp.route("/sales/<int:sid>/approve", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_sales_approve(sid):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    if user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)

    data = request.get_json(silent=True) or {}
    admin_note = (data.get("admin_note") or "").strip()

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
        """, (admin_note, user["user_id"], sid))
        conn.commit()
        return mobile_api_response(ok=True, message="Sales disetujui.", data={}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_sales_bp.route("/sales/<int:sid>/reject", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_sales_reject(sid):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    if user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)

    data = request.get_json(silent=True) or {}
    admin_note = (data.get("admin_note") or "").strip()

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
        """, (admin_note, user["user_id"], sid))
        conn.commit()
        return mobile_api_response(ok=True, message="Sales ditolak.", data={}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_sales_bp.route("/sales/monitor", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_sales_monitor():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    if user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)

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
        summary = [dict(r) for r in cur.fetchall()]

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
        rows = [_fmt_sales_row(r) for r in cur.fetchall()]

        return mobile_api_response(
            ok=True,
            message="OK",
            data={"summary": summary, "rows": rows},
            status_code=200
        )
    finally:
        cur.close()
        conn.close()
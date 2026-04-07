from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from werkzeug.security import generate_password_hash

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_admin_users_bp = Blueprint("mobile_admin_users", __name__)


def _admin_only():
    user = request.mobile_user
    if user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)
    return None


@mobile_admin_users_bp.route("/admin/users", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_admin_users_list():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    deny = _admin_only()
    if deny:
        return deny

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT u.id, u.name, u.email, u.role, COALESCE(p.daily_salary, 0) AS daily_salary
            FROM users u
            LEFT JOIN payroll_settings p ON p.user_id=u.id
            ORDER BY u.id DESC;
        """)
        rows = [dict(r) for r in cur.fetchall()]
        return mobile_api_response(ok=True, message="OK", data={"users": rows}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_admin_users_bp.route("/admin/users", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_admin_users_create():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    deny = _admin_only()
    if deny:
        return deny

    data = request.get_json(silent=True) or {}

    name = (data.get("name") or "").strip()
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""
    role = (data.get("role") or "employee").strip()
    daily_salary = int(data.get("daily_salary") or 0)

    if not name or not email or not password:
        return mobile_api_response(ok=False, message="Nama, email, dan password wajib diisi.", status_code=400)

    pw_hash = generate_password_hash(password)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            INSERT INTO users (name, email, password_hash, role)
            VALUES (%s, %s, %s, %s)
            RETURNING id;
        """, (name, email, pw_hash, role))
        row = cur.fetchone() or {}
        uid = row.get("id")

        if uid:
            cur.execute("""
                INSERT INTO payroll_settings (user_id, daily_salary)
                VALUES (%s, %s)
                ON CONFLICT (user_id)
                DO UPDATE SET daily_salary=EXCLUDED.daily_salary, updated_at=CURRENT_TIMESTAMP;
            """, (uid, daily_salary))

        conn.commit()
        return mobile_api_response(ok=True, message="User berhasil dibuat.", data={"id": uid}, status_code=200)
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=f"Gagal membuat user: {str(e)}", status_code=500)
    finally:
        cur.close()
        conn.close()


@mobile_admin_users_bp.route("/admin/users/<int:uid>", methods=["PUT", "OPTIONS"])
@mobile_api_login_required
def mobile_admin_users_update(uid):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    deny = _admin_only()
    if deny:
        return deny

    data = request.get_json(silent=True) or {}

    name = (data.get("name") or "").strip()
    email = (data.get("email") or "").strip().lower()
    role = (data.get("role") or "employee").strip()
    daily_salary = int(data.get("daily_salary") or 0)
    new_password = (data.get("new_password") or "").strip()

    conn = get_conn()
    cur = conn.cursor()
    try:
        if new_password:
            pw_hash = generate_password_hash(new_password)
            cur.execute("""
                UPDATE users
                SET name=%s, email=%s, role=%s, password_hash=%s
                WHERE id=%s;
            """, (name, email, role, pw_hash, uid))
        else:
            cur.execute("""
                UPDATE users
                SET name=%s, email=%s, role=%s
                WHERE id=%s;
            """, (name, email, role, uid))

        cur.execute("""
            INSERT INTO payroll_settings (user_id, daily_salary)
            VALUES (%s, %s)
            ON CONFLICT (user_id)
            DO UPDATE SET daily_salary=EXCLUDED.daily_salary, updated_at=CURRENT_TIMESTAMP;
        """, (uid, daily_salary))

        conn.commit()
        return mobile_api_response(ok=True, message="User berhasil diupdate.", data={}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_admin_users_bp.route("/admin/users/<int:uid>", methods=["DELETE", "OPTIONS"])
@mobile_api_login_required
def mobile_admin_users_delete(uid):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    deny = _admin_only()
    if deny:
        return deny

    if uid == request.mobile_user["user_id"]:
        return mobile_api_response(ok=False, message="Tidak bisa menghapus akun sendiri.", status_code=400)

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM users WHERE id=%s;", (uid,))
        conn.commit()
        return mobile_api_response(ok=True, message="User berhasil dihapus.", data={}, status_code=200)
    finally:
        cur.close()
        conn.close()
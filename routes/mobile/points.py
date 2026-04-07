from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_points_bp = Blueprint("mobile_points", __name__)


@mobile_points_bp.route("/points", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_points():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    if request.mobile_user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, name, email,
            COALESCE(points,0) AS points,
            COALESCE(points_admin,0) AS points_admin
            FROM users WHERE role='employee'
            ORDER BY name ASC;
        """)
        employees = [dict(r) for r in cur.fetchall()]

        cur.execute("""
            SELECT l.created_at, u.name AS user_name,
                   l.delta, l.note, a.name AS admin_name
            FROM points_logs l
            JOIN users u ON u.id=l.user_id
            JOIN users a ON a.id=l.admin_id
            ORDER BY l.created_at DESC LIMIT 50;
        """)
        logs = []
        for r in cur.fetchall():
            item = dict(r)
            item["created_at"] = item["created_at"].strftime("%Y-%m-%d %H:%M:%S") if item.get("created_at") else "-"
            logs.append(item)

        return mobile_api_response(ok=True, message="OK", data={"employees": employees, "logs": logs}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_points_bp.route("/points/add", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_points_add():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    admin = request.mobile_user
    if admin.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)

    data = request.get_json(silent=True) or {}
    user_id = int(data.get("user_id"))
    delta = int(data.get("delta"))
    note = data.get("note")

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE users
            SET points_admin = COALESCE(points_admin,0)+%s
            WHERE id=%s;
        """, (delta, user_id))

        cur.execute("""
            INSERT INTO points_logs (user_id, admin_id, delta, note)
            VALUES (%s,%s,%s,%s);
        """, (user_id, admin["user_id"], delta, note))

        conn.commit()
        return mobile_api_response(ok=True, message="Poin berhasil ditambahkan.", data={}, status_code=200)
    finally:
        cur.close()
        conn.close()
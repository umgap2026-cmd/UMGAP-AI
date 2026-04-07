from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_dashboard_bp = Blueprint("mobile_dashboard", __name__)


@mobile_dashboard_bp.route("/dashboard", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_dashboard():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        if user.get("role") == "admin":
            cur.execute("SELECT COUNT(*) AS total FROM users WHERE role='employee';")
            total_employees = int((cur.fetchone() or {}).get("total") or 0)

            cur.execute("SELECT COUNT(*) AS total FROM products;")
            total_products = int((cur.fetchone() or {}).get("total") or 0)

            cur.execute("""
                SELECT COUNT(*) AS total
                FROM attendance
                WHERE work_date=CURRENT_DATE AND status='PRESENT';
            """)
            total_attendance_today = int((cur.fetchone() or {}).get("total") or 0)

            return mobile_api_response(
                ok=True,
                message="OK",
                data={
                    "role": "admin",
                    "summary": {
                        "total_employees": total_employees,
                        "total_products": total_products,
                        "total_attendance_today": total_attendance_today,
                    }
                },
                status_code=200
            )

        cur.execute("SELECT points_admin, name FROM users WHERE id=%s LIMIT 1;", (user["user_id"],))
        u = cur.fetchone() or {}

        cur.execute("""
            SELECT a.id, a.title, a.message, a.created_at
            FROM announcements a
            LEFT JOIN announcement_reads ar
              ON ar.announcement_id = a.id
             AND ar.user_id = %s
            WHERE a.is_active = TRUE
              AND ar.id IS NULL
            ORDER BY a.created_at DESC
            LIMIT 20;
        """, (user["user_id"],))
        announcements = cur.fetchall()

        items = []
        for a in announcements:
            item = dict(a)
            item["created_at"] = item["created_at"].strftime("%Y-%m-%d %H:%M:%S") if item.get("created_at") else "-"
            items.append(item)

        return mobile_api_response(
            ok=True,
            message="OK",
            data={
                "role": "employee",
                "user_name": u.get("name") or user.get("name"),
                "points_admin": int(u.get("points_admin") or 0),
                "notif_count": len(items),
                "announcements": items
            },
            status_code=200
        )
    finally:
        cur.close()
        conn.close()
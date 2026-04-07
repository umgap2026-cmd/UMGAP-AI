from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_notifications_bp = Blueprint("mobile_notifications", __name__)


@mobile_notifications_bp.route("/notifications", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_notifications():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, title, message, created_at
            FROM announcements
            WHERE is_active = TRUE
            ORDER BY created_at DESC
            LIMIT 50;
        """)
        rows = cur.fetchall()

        items = []
        for r in rows:
            item = dict(r)
            item["created_at"] = item["created_at"].strftime("%Y-%m-%d %H:%M:%S") if item.get("created_at") else "-"
            items.append(item)

        return mobile_api_response(ok=True, message="OK", data={"notifications": items}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_notifications_bp.route("/notifications/read/<int:ann_id>", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_notifications_read(ann_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO announcement_reads (announcement_id, user_id)
            VALUES (%s, %s)
            ON CONFLICT DO NOTHING;
        """, (ann_id, user["user_id"]))
        conn.commit()

        return mobile_api_response(ok=True, message="Notifikasi ditandai sudah dibaca.", data={}, status_code=200)
    finally:
        cur.close()
        conn.close()
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from db import get_conn
from core import mobile_api_response, mobile_api_login_required, _utc_naive_to_wib_string

mobile_notifications_bp = Blueprint("mobile_notifications", __name__)


@mobile_notifications_bp.route("/notifications", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_notifications():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user_id = request.mobile_user["user_id"]
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Langsung query tanpa cek information_schema (sudah pasti ada kolom ini)
        cur.execute("""
            SELECT
                a.id,
                a.title,
                a.body AS message,
                a.created_at,
                CASE WHEN ar.read_at IS NOT NULL THEN TRUE ELSE FALSE END AS is_read
            FROM announcements a
            LEFT JOIN announcement_reads ar
                ON ar.announcement_id = a.id
               AND ar.user_id = %s
            WHERE a.is_active = TRUE
              AND (ar.dismissed_at IS NULL OR ar.user_id IS NULL)
            ORDER BY a.created_at DESC
            LIMIT 50;
        """, (user_id,))

        rows  = cur.fetchall()
        items = []
        for r in rows:
            item = dict(r)
            item["created_at"] = _utc_naive_to_wib_string(item.get("created_at"))
            items.append(item)

        unread = sum(1 for i in items if not i.get("is_read"))

        return mobile_api_response(
            ok=True, message="OK",
            data={"notifications": items, "unread_count": unread},
            status_code=200)
    except Exception as e:
        return mobile_api_response(
            ok=False, message=f"Gagal: {e}", status_code=500)
    finally:
        cur.close()
        conn.close()


@mobile_notifications_bp.route("/notifications/read/<int:ann_id>",
                                methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_notifications_read(ann_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user_id = request.mobile_user["user_id"]
    conn = get_conn()
    cur  = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO announcement_reads (announcement_id, user_id)
            VALUES (%s, %s)
            ON CONFLICT (announcement_id, user_id) DO NOTHING;
        """, (ann_id, user_id))
        conn.commit()
        return mobile_api_response(
            ok=True, message="Ditandai sudah dibaca.",
            data={}, status_code=200)
    finally:
        cur.close()
        conn.close()

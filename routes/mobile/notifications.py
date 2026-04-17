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

    user_id = request.mobile_user["user_id"]
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Cek apakah kolom dismissed_at sudah ada
        cur.execute("""
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'announcement_reads'
              AND column_name = 'dismissed_at'
            LIMIT 1;
        """)
        has_dismissed = cur.fetchone() is not None

        # Cek apakah kolom 'body' atau 'message' yang dipakai
        cur.execute("""
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'announcements'
              AND column_name IN ('body', 'message')
            ORDER BY column_name;
        """)
        cols = [r["column_name"] for r in cur.fetchall()]
        body_col = "body" if "body" in cols else "message"

        # Filter dismissed hanya kalau kolomnya ada
        dismissed_filter = ""
        if has_dismissed:
            dismissed_filter = "AND (ar.dismissed_at IS NULL OR ar.user_id IS NULL)"

        cur.execute(f"""
            SELECT
                a.id,
                a.title,
                a.{body_col} AS message,
                a.created_at,
                CASE WHEN ar.read_at IS NOT NULL THEN TRUE ELSE FALSE END AS is_read
            FROM announcements a
            LEFT JOIN announcement_reads ar
                ON ar.announcement_id = a.id
               AND ar.user_id = %s
            WHERE a.is_active = TRUE
            {dismissed_filter}
            ORDER BY a.created_at DESC
            LIMIT 50;
        """, (user_id,))

        rows  = cur.fetchall()
        items = []
        for r in rows:
            item = dict(r)
            item["created_at"] = (
                item["created_at"].strftime("%Y-%m-%d %H:%M:%S")
                if item.get("created_at") else "-"
            )
            items.append(item)

        return mobile_api_response(
            ok=True, message="OK",
            data={"notifications": items},
            status_code=200)
    except Exception as e:
        import traceback
        print(f"[notifications] ERROR: {e}\n{traceback.format_exc()}")
        return mobile_api_response(
            ok=False, message=f"Gagal memuat notifikasi: {e}",
            status_code=500)
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
            ok=True, message="Notifikasi ditandai sudah dibaca.",
            data={}, status_code=200)
    finally:
        cur.close()
        conn.close()

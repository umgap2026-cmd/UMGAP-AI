from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from core import (mobile_api_response, mobile_api_login_required,
                  _utc_naive_to_wib_string, send_fcm_to_tokens)
from db import get_conn
import threading

mobile_announcements_bp = Blueprint("mobile_announcements", __name__)


@mobile_announcements_bp.route("/announcements", methods=["GET", "POST", "OPTIONS"])
@mobile_api_login_required
def mobile_announcements():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    if request.method == "GET":
        user_id = request.mobile_user["user_id"]
        conn = get_conn()
        cur  = conn.cursor(cursor_factory=RealDictCursor)
        try:
            cur.execute("""
                SELECT a.id, a.title, a.body, a.created_at,
                       u.name AS created_by_name,
                       CASE WHEN ar.read_at IS NOT NULL THEN TRUE ELSE FALSE END AS is_read,
                       ar.dismissed_at
                FROM announcements a
                JOIN users u ON u.id = a.created_by
                LEFT JOIN announcement_reads ar
                    ON ar.announcement_id = a.id AND ar.user_id = %s
                WHERE a.is_active = TRUE
                ORDER BY a.created_at DESC LIMIT 50;
            """, (user_id,))
            rows  = cur.fetchall()
            items = []
            for r in rows:
                d = dict(r)
                if d.get("dismissed_at") is not None:
                    continue
                d["created_at_wib"] = _utc_naive_to_wib_string(d.get("created_at"))
                d.pop("created_at", None)
                d.pop("dismissed_at", None)
                items.append(d)
            unread = sum(1 for a in items if not a["is_read"])
            return mobile_api_response(ok=True, message="OK",
                data={"announcements": items, "unread_count": unread},
                status_code=200)
        finally:
            cur.close()
            conn.close()

    # ── POST (admin only) ────────────────────────────────────────
    user = request.mobile_user
    if user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Hanya admin.", status_code=403)

    payload = request.get_json(silent=True) or {}
    title   = (payload.get("title") or "").strip()
    body    = (payload.get("body")  or "").strip()

    if not title:
        return mobile_api_response(ok=False, message="Judul wajib diisi.", status_code=400)
    if not body:
        return mobile_api_response(ok=False, message="Isi wajib diisi.", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            INSERT INTO announcements (title, body, message, created_by)
            VALUES (%s, %s, %s, %s)
            RETURNING id, title, body, created_at;
        """, (title, body, body, user["user_id"]))
        row = dict(cur.fetchone())
        conn.commit()
        row["created_at_wib"] = _utc_naive_to_wib_string(row.pop("created_at", None))

        def _push():
            try:
                c2 = get_conn()
                cu = c2.cursor(cursor_factory=RealDictCursor)
                cu.execute("""
                    SELECT DISTINCT fcm_token FROM mobile_device_tokens
                    WHERE is_active = TRUE AND COALESCE(fcm_token, '') <> '';
                """)
                tokens = [r["fcm_token"] for r in cu.fetchall()]
                cu.close(); c2.close()
                if tokens:
                    send_fcm_to_tokens(
                        tokens,
                        title=f"📢 {title}",
                        body=body[:120] + ("..." if len(body) > 120 else ""),
                        data={"type": "announcement", "screen": "notifications"}
                    )
                    print(f"[FCM] Pengumuman dikirim ke {len(tokens)} device")
            except Exception as ex:
                print(f"[FCM] {ex}")

        threading.Thread(target=_push, daemon=True).start()

        return mobile_api_response(ok=True, message="Pengumuman berhasil dikirim.",
            data={"announcement": row}, status_code=200)
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=f"Gagal: {e}", status_code=500)
    finally:
        cur.close()
        conn.close()


@mobile_announcements_bp.route("/announcements/<int:ann_id>",
                                methods=["DELETE", "OPTIONS"])
@mobile_api_login_required
def mobile_delete_announcement(ann_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)
    if request.mobile_user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Hanya admin.", status_code=403)
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("UPDATE announcements SET is_active=FALSE WHERE id=%s RETURNING id;",
                    (ann_id,))
        row = cur.fetchone()
        conn.commit()
        if not row:
            return mobile_api_response(ok=False, message="Tidak ditemukan.", status_code=404)
        return mobile_api_response(ok=True, message="Dihapus.", data={}, status_code=200)
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=f"Gagal: {e}", status_code=500)
    finally:
        cur.close()
        conn.close()


@mobile_announcements_bp.route("/announcements/<int:ann_id>/read",
                                methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_mark_read(ann_id):
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
        return mobile_api_response(ok=True, message="Ditandai dibaca.",
            data={}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_announcements_bp.route("/announcements/<int:ann_id>/dismiss",
                                methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_dismiss_announcement(ann_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)
    user_id = request.mobile_user["user_id"]
    conn = get_conn()
    cur  = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO announcement_reads (announcement_id, user_id, dismissed_at)
            VALUES (%s, %s, CURRENT_TIMESTAMP)
            ON CONFLICT (announcement_id, user_id)
            DO UPDATE SET dismissed_at = CURRENT_TIMESTAMP;
        """, (ann_id, user_id))
        conn.commit()
        return mobile_api_response(ok=True, message="Disembunyikan.",
            data={}, status_code=200)
    finally:
        cur.close()
        conn.close()

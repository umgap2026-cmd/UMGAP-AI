"""
routes/mobile/announcements.py
Mobile API untuk pengumuman (announcements).

Endpoint:
  GET    /api/mobile/announcements          - list semua pengumuman aktif + status baca
  POST   /api/mobile/announcements          - buat pengumuman baru (admin only)
  DELETE /api/mobile/announcements/<id>     - hapus/nonaktifkan pengumuman (admin only)
  POST   /api/mobile/announcements/<id>/read - tandai sudah dibaca

Tabel yang dibutuhkan (auto-create di ensure_announcements_schema):
  announcements(id, title, body, created_by, is_active, created_at)
  announcement_reads(id, announcement_id, user_id, read_at)
"""

from datetime import datetime

from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import (
    mobile_api_response,
    mobile_api_login_required,
    _utc_naive_to_wib_string,
    _safe_int,
)

mobile_announcements_bp = Blueprint("mobile_announcements", __name__)


# ─── Schema helper ─────────────────────────────────────────────────────────────

def _ensure_schema():
    conn = get_conn()
    cur  = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS announcements (
                id          SERIAL PRIMARY KEY,
                title       VARCHAR(200) NOT NULL,
                body        TEXT         NOT NULL,
                created_by  INTEGER      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
                created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS announcement_reads (
                id              SERIAL PRIMARY KEY,
                announcement_id INTEGER   NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
                user_id         INTEGER   NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                read_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                UNIQUE (announcement_id, user_id)
            );
        """)
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_ann_reads_user
            ON announcement_reads(user_id);
        """)
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_ann_active
            ON announcements(is_active, created_at DESC);
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()


# ─── GET /api/mobile/announcements ─────────────────────────────────────────────

@mobile_announcements_bp.route("/announcements", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_list_announcements():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    _ensure_schema()
    user    = request.mobile_user
    user_id = user["user_id"]

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                a.id,
                a.title,
                a.body,
                a.created_at,
                a.is_active,
                u.name   AS created_by_name,
                CASE WHEN ar.user_id IS NOT NULL THEN TRUE ELSE FALSE END AS is_read
            FROM announcements a
            JOIN users u ON u.id = a.created_by
            LEFT JOIN announcement_reads ar
                ON ar.announcement_id = a.id
               AND ar.user_id = %s
            WHERE a.is_active = TRUE
            ORDER BY a.created_at DESC
            LIMIT 50;
        """, (user_id,))

        rows = cur.fetchall()
        announcements = []
        for r in rows:
            d = dict(r)
            d["created_at_wib"] = _utc_naive_to_wib_string(d.get("created_at"))
            d.pop("created_at", None)  # hilangkan raw UTC
            announcements.append(d)

        # Jumlah yang belum dibaca
        unread = sum(1 for a in announcements if not a["is_read"])

        return mobile_api_response(
            ok=True,
            message="OK",
            data={"announcements": announcements, "unread_count": unread},
            status_code=200,
        )
    finally:
        cur.close()
        conn.close()


# ─── POST /api/mobile/announcements ────────────────────────────────────────────

# ─── POST /api/mobile/announcements ────────────────────────────────────────────

@mobile_announcements_bp.route("/announcements", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_create_announcement():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    if user.get("role") != "admin":
        return mobile_api_response(
            ok=False, message="Hanya admin yang dapat membuat pengumuman.",
            status_code=403
        )

    _ensure_schema()

    payload = request.get_json(silent=True) or {}
    title   = (payload.get("title") or "").strip()
    body    = (payload.get("body")  or "").strip()

    if not title:
        return mobile_api_response(ok=False, message="Judul pengumuman wajib diisi.", status_code=400)
    if not body:
        return mobile_api_response(ok=False, message="Isi pengumuman wajib diisi.",  status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            INSERT INTO announcements (title, body, created_by)
            VALUES (%s, %s, %s)
            RETURNING id, title, body, created_at;
        """, (title, body, user["user_id"]))

        row = dict(cur.fetchone())
        conn.commit()

        row["created_at_wib"] = _utc_naive_to_wib_string(row.pop("created_at", None))

        # ── Kirim FCM ke semua karyawan (background thread) ──────────
        import threading

        def _send_fcm():
            try:
                from core import send_fcm_to_tokens
                from psycopg2.extras import RealDictCursor as RDC
                from db import get_conn as gc

                c2 = gc()
                cu = c2.cursor(cursor_factory=RDC)
                try:
                    cu.execute("""
                        SELECT DISTINCT d.fcm_token
                        FROM mobile_device_tokens d
                        JOIN users u ON u.id = d.user_id
                        WHERE d.is_active = TRUE
                          AND COALESCE(d.fcm_token, '') <> '';
                    """)
                    tokens = [r["fcm_token"] for r in cu.fetchall()]
                finally:
                    cu.close(); c2.close()

                if tokens:
                    send_fcm_to_tokens(
                        tokens,
                        title=f"📢 {title}",
                        body=body[:120] + ("..." if len(body) > 120 else ""),
                        data={
                            "type":   "announcement",
                            "screen": "notifications",
                        }
                    )
                    print(f"[FCM] Pengumuman dikirim ke {len(tokens)} device")
            except Exception as ex:
                print(f"[FCM announcement error] {ex}")

        threading.Thread(target=_send_fcm, daemon=True).start()

        return mobile_api_response(
            ok=True,
            message="Pengumuman berhasil dikirim.",
            data={"announcement": row},
            status_code=200,
        )
    except Exception as e:
        conn.rollback()
        return mobile_api_response(
            ok=False, message=f"Gagal membuat pengumuman: {str(e)}", status_code=500
        )
    finally:
        cur.close()
        conn.close()


# ─── DELETE /api/mobile/announcements/<id> ─────────────────────────────────────

@mobile_announcements_bp.route("/announcements/<int:ann_id>", methods=["DELETE", "OPTIONS"])
@mobile_api_login_required
def mobile_delete_announcement(ann_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    if user.get("role") != "admin":
        return mobile_api_response(
            ok=False, message="Hanya admin yang dapat menghapus pengumuman.", status_code=403
        )

    _ensure_schema()

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Soft delete — set is_active = FALSE
        cur.execute("""
            UPDATE announcements
            SET is_active = FALSE
            WHERE id = %s
            RETURNING id;
        """, (ann_id,))

        row = cur.fetchone()
        conn.commit()

        if not row:
            return mobile_api_response(
                ok=False, message="Pengumuman tidak ditemukan.", status_code=404
            )

        return mobile_api_response(
            ok=True, message="Pengumuman berhasil dihapus.", data={}, status_code=200
        )
    except Exception as e:
        conn.rollback()
        return mobile_api_response(
            ok=False, message=f"Gagal menghapus pengumuman: {str(e)}", status_code=500
        )
    finally:
        cur.close()
        conn.close()


# ─── POST /api/mobile/announcements/<id>/read ──────────────────────────────────

@mobile_announcements_bp.route("/announcements/<int:ann_id>/read", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_mark_announcement_read(ann_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    _ensure_schema()
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
            ok=True, message="Ditandai sudah dibaca.", data={}, status_code=200
        )
    finally:
        cur.close()
        conn.close()

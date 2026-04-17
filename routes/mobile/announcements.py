"""
routes/mobile/announcements.py
Perubahan:
  - POST /announcements/<id>/dismiss  → user sembunyikan sendiri (tidak hapus dari DB)
  - GET /announcements                → exclude yang sudah di-dismiss user ini
  - POST /announcements (create)      → kirim FCM ke semua karyawan
"""
from datetime import datetime
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from core import (
    mobile_api_response, mobile_api_login_required,
    _utc_naive_to_wib_string, _safe_int,
)
from db import get_conn

mobile_announcements_bp = Blueprint("mobile_announcements", __name__)


def _ensure_schema():
    conn = get_conn(); cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS announcements (
                id         SERIAL PRIMARY KEY,
                title      VARCHAR(200) NOT NULL,
                body       TEXT         NOT NULL,
                created_by INTEGER      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                is_active  BOOLEAN      NOT NULL DEFAULT TRUE,
                created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS announcement_reads (
                id              SERIAL PRIMARY KEY,
                announcement_id INTEGER   NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
                user_id         INTEGER   NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                read_at         TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                dismissed_at    TIMESTAMP,          -- NULL = belum disembunyikan user
                UNIQUE (announcement_id, user_id)
            );
        """)
        # Tambah kolom dismissed_at jika belum ada (untuk DB yang sudah jalan)
        cur.execute("""
            ALTER TABLE announcement_reads
            ADD COLUMN IF NOT EXISTS dismissed_at TIMESTAMP;
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
        cur.close(); conn.close()


def _get_all_employee_fcm_tokens():
    """Ambil semua FCM token karyawan aktif."""
    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT DISTINCT d.fcm_token
            FROM mobile_device_tokens d
            JOIN users u ON u.id = d.user_id
            WHERE d.is_active = TRUE
              AND u.role = 'employee'
              AND COALESCE(d.fcm_token, '') <> '';
        """)
        return [r["fcm_token"] for r in cur.fetchall()]
    except Exception:
        return []
    finally:
        cur.close(); conn.close()


# ── GET /api/mobile/announcements ─────────────────────────────────────
@mobile_announcements_bp.route("/announcements", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_list_announcements():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    _ensure_schema()
    user_id = request.mobile_user["user_id"]

    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                a.id, a.title, a.body, a.created_at, a.is_active,
                u.name AS created_by_name,
                CASE WHEN ar.read_at IS NOT NULL THEN TRUE ELSE FALSE END AS is_read,
                ar.dismissed_at
            FROM announcements a
            JOIN users u ON u.id = a.created_by
            LEFT JOIN announcement_reads ar
                ON ar.announcement_id = a.id AND ar.user_id = %s
            WHERE a.is_active = TRUE
              AND (ar.dismissed_at IS NULL OR ar.dismissed_at IS NULL)
            ORDER BY a.created_at DESC
            LIMIT 50;
        """, (user_id,))

        rows = cur.fetchall()
        announcements = []
        for r in rows:
            d = dict(r)
            # Skip yang sudah di-dismiss user ini
            if d.get("dismissed_at") is not None:
                continue
            d["created_at_wib"] = _utc_naive_to_wib_string(d.get("created_at"))
            d.pop("created_at", None)
            d.pop("dismissed_at", None)
            announcements.append(d)

        unread = sum(1 for a in announcements if not a["is_read"])
        return mobile_api_response(ok=True, message="OK",
            data={"announcements": announcements, "unread_count": unread},
            status_code=200)
    finally:
        cur.close(); conn.close()


# ── POST /api/mobile/announcements (create) ────────────────────────────
@mobile_announcements_bp.route("/announcements", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_create_announcement():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    if user.get("role") != "admin":
        return mobile_api_response(
            ok=False, message="Hanya admin yang dapat membuat pengumuman.",
            status_code=403)

    _ensure_schema()
    payload = request.get_json(silent=True) or {}
    title   = (payload.get("title") or "").strip()
    body    = (payload.get("body")  or "").strip()

    if not title:
        return mobile_api_response(ok=False, message="Judul wajib diisi.", status_code=400)
    if not body:
        return mobile_api_response(ok=False, message="Isi pengumuman wajib diisi.", status_code=400)

    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            INSERT INTO announcements (title, body, created_by)
            VALUES (%s, %s, %s)
            RETURNING id, title, body, created_at;
        """, (title, body, user["user_id"]))
        row = dict(cur.fetchone())
        conn.commit()
        row["created_at_wib"] = _utc_naive_to_wib_string(row.pop("created_at", None))

        # ── Kirim FCM ke semua karyawan ──────────────────────────
        import threading
        def _push():
            try:
                from core import send_fcm_to_tokens
                tokens = _get_all_employee_fcm_tokens()
                if tokens:
                    send_fcm_to_tokens(
                        tokens,
                        title=f"📢 {title}",
                        body=body[:100] + ("..." if len(body) > 100 else ""),
                        data={"type": "announcement", "screen": "notifications",
                              "announcement_id": str(row["id"])}
                    )
            except Exception as ex:
                print(f"[FCM announcement] {ex}")
        threading.Thread(target=_push, daemon=True).start()

        return mobile_api_response(ok=True,
            message="Pengumuman berhasil dikirim.",
            data={"announcement": row}, status_code=200)
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False,
            message=f"Gagal membuat pengumuman: {str(e)}", status_code=500)
    finally:
        cur.close(); conn.close()


# ── DELETE /api/mobile/announcements/<id> (admin hapus semua) ──────────
@mobile_announcements_bp.route("/announcements/<int:ann_id>",
                                methods=["DELETE", "OPTIONS"])
@mobile_api_login_required
def mobile_delete_announcement(ann_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    if user.get("role") != "admin":
        return mobile_api_response(
            ok=False, message="Hanya admin yang dapat menghapus pengumuman.",
            status_code=403)

    _ensure_schema()
    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            UPDATE announcements SET is_active = FALSE
            WHERE id = %s RETURNING id;
        """, (ann_id,))
        row = cur.fetchone(); conn.commit()
        if not row:
            return mobile_api_response(ok=False,
                message="Pengumuman tidak ditemukan.", status_code=404)
        return mobile_api_response(ok=True,
            message="Pengumuman berhasil dihapus.", data={}, status_code=200)
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False,
            message=f"Gagal menghapus: {str(e)}", status_code=500)
    finally:
        cur.close(); conn.close()


# ── POST /api/mobile/announcements/<id>/read ───────────────────────────
@mobile_announcements_bp.route("/announcements/<int:ann_id>/read",
                                methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_mark_read(ann_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    _ensure_schema()
    user_id = request.mobile_user["user_id"]
    conn = get_conn(); cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO announcement_reads (announcement_id, user_id)
            VALUES (%s, %s)
            ON CONFLICT (announcement_id, user_id) DO NOTHING;
        """, (ann_id, user_id))
        conn.commit()
        return mobile_api_response(ok=True,
            message="Ditandai sudah dibaca.", data={}, status_code=200)
    finally:
        cur.close(); conn.close()


# ── POST /api/mobile/announcements/<id>/dismiss (user sembunyikan) ─────
@mobile_announcements_bp.route("/announcements/<int:ann_id>/dismiss",
                                methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_dismiss_announcement(ann_id):
    """
    User menyembunyikan pengumuman dari listnya sendiri.
    Tidak mempengaruhi user lain maupun is_active di tabel announcements.
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    _ensure_schema()
    user_id = request.mobile_user["user_id"]
    conn = get_conn(); cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO announcement_reads (announcement_id, user_id, dismissed_at)
            VALUES (%s, %s, CURRENT_TIMESTAMP)
            ON CONFLICT (announcement_id, user_id)
            DO UPDATE SET dismissed_at = CURRENT_TIMESTAMP;
        """, (ann_id, user_id))
        conn.commit()
        return mobile_api_response(ok=True,
            message="Pengumuman disembunyikan.", data={}, status_code=200)
    finally:
        cur.close(); conn.close()

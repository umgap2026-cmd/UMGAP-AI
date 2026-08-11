from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_content_bp = Blueprint("mobile_content", __name__)


def _ensure_content_plans_schema(cur):
    """Lazy-migration -- sama persis skema yg dibuat /init-content di
    routes/web/content.py, supaya endpoint mobile tidak bergantung pada
    endpoint one-off itu sudah pernah diakses manual."""
    cur.execute("""
        CREATE TABLE IF NOT EXISTS content_plans (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            plan_date DATE NOT NULL,
            platform VARCHAR(30) NOT NULL,
            content_type VARCHAR(30) NOT NULL,
            notes TEXT,
            is_done BOOLEAN NOT NULL DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)


def _check_admin(mobile_user):
    if (mobile_user.get("role") or "") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)
    return None


@mobile_content_bp.route("/content-plans", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def content_plans_list():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_admin(request.mobile_user)
    if deny: return deny

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_content_plans_schema(cur)
        conn.commit()
        cur.execute("""
            SELECT id, plan_date, platform, content_type, notes, is_done, created_at
            FROM content_plans
            WHERE user_id=%s
            ORDER BY is_done ASC, plan_date ASC, id DESC;
        """, (request.mobile_user.get("id"),))
        rows = [dict(r) for r in cur.fetchall()]
        for r in rows:
            r["plan_date"] = r["plan_date"].isoformat() if r.get("plan_date") else None
            r["created_at"] = r["created_at"].isoformat() if r.get("created_at") else None
        return mobile_api_response(ok=True, message="OK", data=rows)
    finally:
        cur.close(); conn.close()


@mobile_content_bp.route("/content-plans/add", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def content_plans_add():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_admin(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}
    plan_date    = (data.get("plan_date") or "").strip()
    platform     = (data.get("platform") or "").strip()
    content_type = (data.get("content_type") or "").strip()
    notes        = (data.get("notes") or "").strip()

    if not plan_date or not platform or not content_type:
        return mobile_api_response(ok=False, message="Tanggal, platform, dan jenis konten wajib diisi.", status_code=400)

    conn = get_conn()
    cur = conn.cursor()
    try:
        _ensure_content_plans_schema(cur)
        cur.execute("""
            INSERT INTO content_plans (user_id, plan_date, platform, content_type, notes)
            VALUES (%s, %s, %s, %s, %s) RETURNING id;
        """, (request.mobile_user.get("id"), plan_date, platform, content_type, notes or None))
        new_id = cur.fetchone()[0]
        conn.commit()
        return mobile_api_response(ok=True, message="Rencana konten ditambahkan.", data={"id": new_id})
    finally:
        cur.close(); conn.close()


def _update_done(cid, mobile_user, is_done):
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE content_plans SET is_done=%s
            WHERE id=%s AND user_id=%s;
        """, (is_done, cid, mobile_user.get("id")))
        conn.commit()
    finally:
        cur.close(); conn.close()


@mobile_content_bp.route("/content-plans/<int:cid>/done", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def content_plans_done(cid):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_admin(request.mobile_user)
    if deny: return deny
    _update_done(cid, request.mobile_user, True)
    return mobile_api_response(ok=True, message="Ditandai selesai.", data={"id": cid})


@mobile_content_bp.route("/content-plans/<int:cid>/undo", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def content_plans_undo(cid):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_admin(request.mobile_user)
    if deny: return deny
    _update_done(cid, request.mobile_user, False)
    return mobile_api_response(ok=True, message="Dibatalkan jadi belum selesai.", data={"id": cid})


@mobile_content_bp.route("/content-plans/<int:cid>/delete", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def content_plans_delete(cid):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_admin(request.mobile_user)
    if deny: return deny

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            DELETE FROM content_plans WHERE id=%s AND user_id=%s;
        """, (cid, request.mobile_user.get("id")))
        conn.commit()
        return mobile_api_response(ok=True, message="Rencana konten dihapus.", data={"id": cid})
    finally:
        cur.close(); conn.close()

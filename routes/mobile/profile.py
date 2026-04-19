"""
routes/mobile/profile.py
Endpoint untuk update profil karyawan (foto + data pribadi)
dan admin lihat profil karyawan.
"""
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from core import mobile_api_response, mobile_api_login_required, _utc_naive_to_wib_string
from db import get_conn

mobile_profile_bp = Blueprint("mobile_profile", __name__)


def _ensure_schema():
    conn = get_conn(); cur = conn.cursor()
    try:
        for col, typ in [
            ("avatar",     "TEXT"),
            ("phone",      "VARCHAR(20)"),
            ("address",    "TEXT"),
            ("birth_date", "DATE"),
            ("join_date",  "DATE"),
        ]:
            cur.execute(f"""
                ALTER TABLE users ADD COLUMN IF NOT EXISTS {col} {typ};
            """)
        conn.commit()
    except Exception:
        conn.rollback()
    finally:
        cur.close(); conn.close()


# ── GET/PUT /api/mobile/profile ─────────────────────────────────────────
@mobile_profile_bp.route("/profile", methods=["GET", "PUT", "OPTIONS"])
@mobile_api_login_required
def mobile_profile():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    _ensure_schema()
    user_id = request.mobile_user["user_id"]

    if request.method == "GET":
        conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
        try:
            cur.execute("""
                SELECT u.id, u.name, u.email, u.role,
                       u.avatar, u.phone, u.address,
                       u.birth_date, u.join_date,
                       COALESCE(pl.total_points, 0) AS points,
                       ps.daily_salary, ps.monthly_salary
                FROM users u
                LEFT JOIN (
                    SELECT user_id, SUM(points) AS total_points
                    FROM points_logs GROUP BY user_id
                ) pl ON pl.user_id = u.id
                LEFT JOIN payroll_settings ps ON ps.user_id = u.id
                WHERE u.id = %s;
            """, (user_id,))
            row = cur.fetchone()
            if not row:
                return mobile_api_response(ok=False, message="User tidak ditemukan.", status_code=404)
            d = dict(row)
            d["birth_date"] = str(d["birth_date"]) if d.get("birth_date") else None
            d["join_date"]  = str(d["join_date"])  if d.get("join_date")  else None
            return mobile_api_response(ok=True, message="OK", data={"profile": d}, status_code=200)
        finally:
            cur.close(); conn.close()

    # PUT — update profil
    payload = request.get_json(silent=True) or {}
    allowed = ["avatar", "phone", "address", "birth_date", "join_date"]
    updates = {k: v for k, v in payload.items() if k in allowed}

    if not updates:
        return mobile_api_response(ok=False, message="Tidak ada data yang diupdate.", status_code=400)

    # Validasi avatar size (max 2MB base64)
    if "avatar" in updates and updates["avatar"] and len(updates["avatar"]) > 2_800_000:
        return mobile_api_response(ok=False, message="Foto terlalu besar. Maksimal 2MB.", status_code=400)

    conn = get_conn(); cur = conn.cursor()
    try:
        set_clause = ", ".join([f"{k} = %s" for k in updates.keys()])
        values = list(updates.values()) + [user_id]
        cur.execute(f"UPDATE users SET {set_clause} WHERE id = %s;", values)
        conn.commit()
        return mobile_api_response(ok=True, message="Profil berhasil diperbarui.", data={}, status_code=200)
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=f"Gagal: {e}", status_code=500)
    finally:
        cur.close(); conn.close()


# ── GET /api/mobile/profile/<user_id> — admin lihat profil karyawan ─────
@mobile_profile_bp.route("/profile/<int:uid>", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_profile_user(uid):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    if request.mobile_user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Hanya admin.", status_code=403)

    _ensure_schema()
    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT u.id, u.name, u.email, u.role,
                   u.avatar, u.phone, u.address,
                   u.birth_date, u.join_date,
                   COALESCE(pl.total_points, 0) AS points,
                   ps.daily_salary, ps.monthly_salary,
                   att.total_hadir, att.hadir_bulan_ini
            FROM users u
            LEFT JOIN (
                SELECT user_id, SUM(points) AS total_points
                FROM points_logs GROUP BY user_id
            ) pl ON pl.user_id = u.id
            LEFT JOIN payroll_settings ps ON ps.user_id = u.id
            LEFT JOIN (
                SELECT user_id,
                       COUNT(*) AS total_hadir,
                       COUNT(*) FILTER (
                           WHERE DATE_TRUNC('month', check_in) = DATE_TRUNC('month', CURRENT_DATE)
                       ) AS hadir_bulan_ini
                FROM attendance GROUP BY user_id
            ) att ON att.user_id = u.id
            WHERE u.id = %s;
        """, (uid,))
        row = cur.fetchone()
        if not row:
            return mobile_api_response(ok=False, message="User tidak ditemukan.", status_code=404)
        d = dict(row)
        d["birth_date"] = str(d["birth_date"]) if d.get("birth_date") else None
        d["join_date"]  = str(d["join_date"])  if d.get("join_date")  else None
        return mobile_api_response(ok=True, message="OK", data={"profile": d}, status_code=200)
    finally:
        cur.close(); conn.close()
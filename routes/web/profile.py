import traceback

from flask import Blueprint, render_template, request, redirect, session, flash
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import is_logged_in, ensure_hr_v2_schema, home_url_for_role

profile_bp = Blueprint("profile", __name__)

PROFILE_ALLOWED_FIELDS = ["phone", "address", "birth_date", "join_date"]
AVATAR_MAX_LEN = 2_800_000  # ~2MB file base64-encoded, sama seperti batas di mobile


def _ensure_profile_schema(conn, cur):
    for col, typ in [
        ("avatar", "TEXT"),
        ("phone", "VARCHAR(20)"),
        ("address", "TEXT"),
        ("birth_date", "DATE"),
        ("join_date", "DATE"),
    ]:
        try:
            cur.execute(f"ALTER TABLE users ADD COLUMN IF NOT EXISTS {col} {typ};")
        except Exception:
            conn.rollback()


@profile_bp.route("/profile", methods=["GET", "POST"])
def profile_page():
    if not is_logged_in():
        return redirect("/login")

    user_id = session["user_id"]
    error = None

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        try:
            ensure_hr_v2_schema()
            _ensure_profile_schema(conn, cur)
            conn.commit()

            if request.method == "POST":
                phone = (request.form.get("phone") or "").strip()
                address = (request.form.get("address") or "").strip()
                birth_date = (request.form.get("birth_date") or "").strip() or None
                join_date = (request.form.get("join_date") or "").strip() or None
                avatar = (request.form.get("avatar") or "").strip()

                if avatar and len(avatar) > AVATAR_MAX_LEN:
                    error = "Foto terlalu besar. Maksimal 2MB."
                else:
                    if avatar:
                        cur.execute("""
                            UPDATE users
                            SET phone=%s, address=%s, birth_date=%s, join_date=%s, avatar=%s
                            WHERE id=%s;
                        """, (phone or None, address or None, birth_date, join_date, avatar, user_id))
                    else:
                        cur.execute("""
                            UPDATE users
                            SET phone=%s, address=%s, birth_date=%s, join_date=%s
                            WHERE id=%s;
                        """, (phone or None, address or None, birth_date, join_date, user_id))
                    conn.commit()
                    return redirect("/profile?saved=1")

            cur.execute("""
                SELECT u.id, u.name, u.email, u.role, u.avatar, u.phone, u.address,
                       u.birth_date, u.join_date,
                       COALESCE(pl.total_points, 0) AS points,
                       ps.salary_type, ps.daily_salary, ps.monthly_salary
                FROM users u
                LEFT JOIN (
                    SELECT user_id, SUM(delta) AS total_points
                    FROM points_logs GROUP BY user_id
                ) pl ON pl.user_id = u.id
                LEFT JOIN payroll_settings ps ON ps.user_id = u.id
                WHERE u.id=%s;
            """, (user_id,))
            profile = cur.fetchone()
        except Exception as e:
            conn.rollback()
            print(f"[PROFILE] {traceback.format_exc()}")
            flash(f"Gagal memuat halaman profil: {e}", "danger")
            return redirect(home_url_for_role(session.get("role")))
    finally:
        cur.close()
        conn.close()

    saved = request.args.get("saved") == "1"
    return render_template("profile.html", profile=profile, saved=saved, error=error)

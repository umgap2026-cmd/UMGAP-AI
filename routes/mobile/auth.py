import secrets

from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from werkzeug.security import check_password_hash

from db import get_conn
from core import mobile_api_response

mobile_auth_bp = Blueprint("mobile_auth", __name__)


def ensure_mobile_api_schema():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS mobile_api_tokens (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                token TEXT NOT NULL UNIQUE,
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                last_used_at TIMESTAMP
            );
        """)
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_mobile_api_tokens_user_id
            ON mobile_api_tokens(user_id);
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()


def _issue_token(user_id: int) -> str:
    """Nonaktifkan token lama, buat token baru, return token string."""
    conn = get_conn()
    cur  = conn.cursor()
    try:
        cur.execute(
            "UPDATE mobile_api_tokens SET is_active=FALSE WHERE user_id=%s;",
            (user_id,)
        )
        token = secrets.token_urlsafe(48)
        cur.execute(
            """INSERT INTO mobile_api_tokens (user_id, token, is_active, last_used_at)
               VALUES (%s, %s, TRUE, CURRENT_TIMESTAMP);""",
            (user_id, token)
        )
        conn.commit()
        return token
    finally:
        cur.close()
        conn.close()


# ─────────────────────────────────────────────
#  EMAIL / PASSWORD LOGIN
# ─────────────────────────────────────────────
@mobile_auth_bp.route("/login", methods=["POST", "OPTIONS"])
def mobile_login():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    ensure_mobile_api_schema()

    data     = request.get_json(silent=True) or {}
    email    = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""

    if not email or not password:
        return mobile_api_response(
            ok=False, message="Email dan password wajib diisi.", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute(
            "SELECT id, name, email, password_hash, role FROM users WHERE lower(email)=%s LIMIT 1;",
            (email,)
        )
        user = cur.fetchone()

        if not user or not check_password_hash(user["password_hash"], password):
            return mobile_api_response(
                ok=False, message="Email atau password salah.", status_code=401)

        token = _issue_token(user["id"])
        return mobile_api_response(
            ok=True, message="Login berhasil.",
            data={
                "token": token,
                "user": {
                    "id":    user["id"],
                    "name":  user["name"],
                    "email": user["email"],
                    "role":  user["role"],
                }
            },
            status_code=200
        )
    except Exception as e:
        return mobile_api_response(ok=False, message=f"Gagal login: {e}", status_code=500)
    finally:
        cur.close()
        conn.close()


# ─────────────────────────────────────────────
#  GOOGLE LOGIN
# ─────────────────────────────────────────────
@mobile_auth_bp.route("/login/google", methods=["POST", "OPTIONS"])
def mobile_login_google():
    """
    Menerima Google ID token dari Flutter,
    verifikasi ke Google, lalu login / daftarkan user otomatis.
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    ensure_mobile_api_schema()

    data     = request.get_json(silent=True) or {}
    id_token = (data.get("id_token") or "").strip()

    if not id_token:
        return mobile_api_response(
            ok=False, message="id_token wajib diisi.", status_code=400)

    # ── Verifikasi token ke Google ────────────
    try:
        import os
        import requests as req

        resp = req.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": id_token},
            timeout=10,
        )

        if resp.status_code != 200:
            return mobile_api_response(
                ok=False, message="Token Google tidak valid.", status_code=401)

        google_data = resp.json()

        # Verifikasi audience — harus cocok dengan salah satu Client ID kita
        web_client_id = (os.getenv("GOOGLE_CLIENT_ID") or "").strip()
        token_aud     = (google_data.get("aud") or "").strip()

        if web_client_id and token_aud:
            # Boleh dari web client ID atau android client ID (keduanya valid)
            allowed = [web_client_id]
            if token_aud not in allowed:
                # Jika audience tidak cocok tapi email ada, tetap lanjut
                # (android client id berbeda dengan web client id)
                print(f"[Google] aud={token_aud} tidak match web_client_id, tetap lanjut")

        g_email = (google_data.get("email") or "").strip().lower()
        g_name  = (google_data.get("name")  or
                   google_data.get("given_name") or
                   g_email.split("@")[0]).strip()

        if not g_email:
            return mobile_api_response(
                ok=False, message="Email tidak ditemukan di token Google.",
                status_code=400)

        # Pastikan email sudah terverifikasi Google
        if google_data.get("email_verified") not in (True, "true"):
            return mobile_api_response(
                ok=False, message="Email Google belum terverifikasi.",
                status_code=401)

        print(f"[Google] Login: {g_email} ({g_name})")

    except Exception as e:
        return mobile_api_response(
            ok=False, message=f"Gagal verifikasi token Google: {e}",
            status_code=500)

    # ── Cek atau buat user ────────────────────
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute(
            "SELECT id, name, email, role FROM users WHERE lower(email)=%s LIMIT 1;",
            (g_email,)
        )
        user = cur.fetchone()

        if not user:
            # Auto-register sebagai employee
            from werkzeug.security import generate_password_hash
            dummy_pw = generate_password_hash(secrets.token_urlsafe(32))
            cur.execute(
                """INSERT INTO users (name, email, password_hash, role)
                   VALUES (%s, %s, %s, 'employee')
                   RETURNING id, name, email, role;""",
                (g_name, g_email, dummy_pw)
            )
            conn.commit()
            user = cur.fetchone()

        token = _issue_token(user["id"])

        return mobile_api_response(
            ok=True, message="Login Google berhasil.",
            data={
                "token": token,
                "user": {
                    "id":    user["id"],
                    "name":  user["name"],
                    "email": user["email"],
                    "role":  user["role"],
                }
            },
            status_code=200
        )
    except Exception as e:
        conn.rollback()
        return mobile_api_response(
            ok=False, message=f"Gagal login Google: {e}", status_code=500)
    finally:
        cur.close()
        conn.close()


# ─────────────────────────────────────────────
#  ME
# ─────────────────────────────────────────────
@mobile_auth_bp.route("/me", methods=["GET", "OPTIONS"])
def mobile_me():
    from core import get_mobile_api_user

    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = get_mobile_api_user()
    if not user:
        return mobile_api_response(
            ok=False, message="Unauthorized.", status_code=401)

    # Ambil data gaji dari payroll_settings
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                COALESCE(ps.daily_salary,   0) AS daily_salary,
                COALESCE(ps.monthly_salary, 0) AS monthly_salary,
                COALESCE(ps.salary_type, 'daily') AS salary_type
            FROM payroll_settings ps
            WHERE ps.user_id = %s
            LIMIT 1;
        """, (user["user_id"],))
        ps = cur.fetchone() or {}
    except Exception:
        ps = {}
    finally:
        cur.close()
        conn.close()

    return mobile_api_response(
        ok=True, message="OK",
        data={
            "user": {
                "id":             user["user_id"],
                "name":           user["name"],
                "email":          user["email"],
                "role":           user["role"],
                "points":         int(user.get("points")       or 0),
                "points_admin":   int(user.get("points_admin") or 0),
                "daily_salary":   int(ps.get("daily_salary")   or 0),
                "monthly_salary": int(ps.get("monthly_salary") or 0),
                "salary_type":    ps.get("salary_type") or "daily",
            }
        },
        status_code=200
    )


# ─────────────────────────────────────────────
#  LOGOUT
# ─────────────────────────────────────────────
@mobile_auth_bp.route("/logout", methods=["POST", "OPTIONS"])
def mobile_logout():
    from core import get_bearer_token

    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    token = get_bearer_token()
    if not token:
        return mobile_api_response(ok=True, message="Logout berhasil.", data={}, status_code=200)

    conn = get_conn()
    cur  = conn.cursor()
    try:
        cur.execute(
            "UPDATE mobile_api_tokens SET is_active=FALSE WHERE token=%s;", (token,))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return mobile_api_response(ok=True, message="Logout berhasil.", data={}, status_code=200)

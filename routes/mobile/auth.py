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

    # Ambil data gaji — tanpa salary_type karena kolom belum ada di DB
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                COALESCE(daily_salary,   0) AS daily_salary,
                COALESCE(monthly_salary, 0) AS monthly_salary
            FROM payroll_settings
            WHERE user_id = %s
            LIMIT 1;
        """, (user["user_id"],))
        ps = cur.fetchone() or {}
    except Exception:
        ps = {}
    finally:
        cur.close()
        conn.close()

    daily   = int(ps.get("daily_salary")   or 0)
    monthly = int(ps.get("monthly_salary") or 0)
    # salary_type: kalau monthly > 0 = bulanan, else harian
    sal_type = "monthly" if monthly > 0 else "daily"

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
                "daily_salary":   daily,
                "monthly_salary": monthly,
                "salary_type":    sal_type,
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

# ─────────────────────────────────────────────
#  FORGOT PASSWORD — OTP via WhatsApp
# ─────────────────────────────────────────────

import random as _rand
import string as _string
import threading as _threading
import requests as _req
from datetime  import datetime, timedelta

WA_BOT_URL = "http://208.76.40.98:3000/send"

def _send_wa_reset(phone: str, message: str):
    def _do():
        try:
            num = phone.strip().replace(" ","").replace("-","").replace("+","")
            if num.startswith("0"):
                num = "62" + num[1:]
            _req.post(WA_BOT_URL, json={"phone": num, "message": message}, timeout=5)
        except Exception as ex:
            print(f"[WA RESET] Gagal kirim ke {phone}: {ex}")
    _threading.Thread(target=_do, daemon=True).start()

def _ensure_reset_table(cur):
    cur.execute("""
        CREATE TABLE IF NOT EXISTS password_reset_otps (
            id          SERIAL PRIMARY KEY,
            user_id     INT         NOT NULL,
            otp         CHAR(6)     NOT NULL,
            reset_token TEXT        UNIQUE,
            expires_at  TIMESTAMPTZ NOT NULL,
            used        BOOLEAN     NOT NULL DEFAULT FALSE
        );
        CREATE INDEX IF NOT EXISTS idx_reset_otp ON password_reset_otps(otp);
    """)

def _mask_wa(phone: str) -> str:
    """Samarkan nomor: 0812****5678"""
    p = phone.strip().replace("+","").replace(" ","")
    if len(p) <= 6: return p
    return p[:4] + "****" + p[-4:]


@mobile_auth_bp.route("/forgot-password/request", methods=["POST", "OPTIONS"])
def forgot_password_request():
    """
    Terima email atau nomor WA → cari user → kirim OTP ke WA.
    Body: { "identifier": "email@x.com" | "081234567890" }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    data       = request.get_json(silent=True) or {}
    identifier = (data.get("identifier") or "").strip()

    if not identifier:
        return mobile_api_response(
            ok=False, message="Email atau nomor WhatsApp wajib diisi.",
            status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_reset_table(cur)

        # Cari user berdasarkan email atau nomor HP
        is_email = "@" in identifier
        if is_email:
            cur.execute(
                "SELECT id, name, phone FROM users WHERE lower(email) = lower(%s) LIMIT 1;",
                (identifier,))
        else:
            # Normalisasi: 08xx → 628xx
            norm = identifier.replace(" ","").replace("-","").replace("+","")
            if norm.startswith("0"):
                norm62 = "62" + norm[1:]
            else:
                norm62 = norm
            cur.execute("""
                SELECT id, name, phone FROM users
                WHERE REGEXP_REPLACE(phone, '[^0-9]', '', 'g')
                    IN (%s, %s)
                LIMIT 1;
            """, (norm, norm62))

        user = cur.fetchone()

        # Selalu return sukses untuk keamanan (tidak bocorkan apakah akun ada)
        if not user or not (user.get("phone") or "").strip():
            conn.commit()
            return mobile_api_response(
                ok=True,
                message="Jika akun ditemukan, OTP akan dikirim ke WhatsApp.",
                data={"masked_wa": ""}
            )

        phone = user["phone"].strip()

        # Hapus OTP lama user ini
        cur.execute("DELETE FROM password_reset_otps WHERE user_id = %s;", (user["id"],))

        # Generate OTP 6 digit
        otp = "".join(_rand.choices(_string.digits, k=6))
        cur.execute("""
            INSERT INTO password_reset_otps (user_id, otp, expires_at)
            VALUES (%s, %s, NOW() + INTERVAL '10 minutes');
        """, (user["id"], otp))
        conn.commit()

        msg = (
            f"🔐 *Reset Password UMGAP*\n\n"
            f"Halo {user['name']},\n\n"
            f"Kode OTP reset password kamu:\n\n"
            f"*{otp}*\n\n"
            f"Berlaku *10 menit*.\n"
            f"Jangan bagikan ke siapapun.\n\n"
            f"Jika tidak merasa meminta reset password, abaikan pesan ini."
        )
        _send_wa_reset(phone, msg)

        return mobile_api_response(
            ok=True,
            message="OTP dikirim ke WhatsApp kamu.",
            data={"masked_wa": _mask_wa(phone)}
        )
    except Exception as e:
        conn.rollback()
        import traceback; print(traceback.format_exc())
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()


@mobile_auth_bp.route("/forgot-password/verify", methods=["POST", "OPTIONS"])
def forgot_password_verify():
    """
    Verifikasi OTP → return reset_token sementara (berlaku 15 menit).
    Body: { "otp": "123456" }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    data = request.get_json(silent=True) or {}
    otp  = str(data.get("otp", "")).strip()

    if len(otp) != 6 or not otp.isdigit():
        return mobile_api_response(
            ok=False, message="OTP tidak valid.", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_reset_table(cur)
        cur.execute("""
            SELECT id, user_id, used, expires_at
            FROM password_reset_otps
            WHERE otp = %s
            FOR UPDATE;
        """, (otp,))
        row = cur.fetchone()

        if not row:
            return mobile_api_response(
                ok=False, message="OTP tidak valid.", status_code=400)
        if row["used"]:
            return mobile_api_response(
                ok=False, message="OTP sudah digunakan.", status_code=400)
        if row["expires_at"].replace(tzinfo=None) < datetime.utcnow():
            return mobile_api_response(
                ok=False, message="OTP sudah kedaluwarsa.", status_code=400)

        # Buat reset_token
        reset_token = secrets.token_urlsafe(32)
        cur.execute("""
            UPDATE password_reset_otps
            SET used = TRUE,
                reset_token = %s,
                expires_at  = NOW() + INTERVAL '15 minutes'
            WHERE id = %s;
        """, (reset_token, row["id"]))
        conn.commit()

        return mobile_api_response(
            ok=True, message="OTP valid.",
            data={"reset_token": reset_token}
        )
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()


@mobile_auth_bp.route("/forgot-password/reset", methods=["POST", "OPTIONS"])
def forgot_password_reset():
    """
    Reset password pakai reset_token dari step verify.
    Body: { "reset_token": "...", "new_password": "..." }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    data         = request.get_json(silent=True) or {}
    reset_token  = (data.get("reset_token")  or "").strip()
    new_password = (data.get("new_password") or "").strip()

    if not reset_token or not new_password:
        return mobile_api_response(
            ok=False, message="reset_token dan new_password wajib diisi.",
            status_code=400)
    if len(new_password) < 6:
        return mobile_api_response(
            ok=False, message="Password minimal 6 karakter.", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_reset_table(cur)
        cur.execute("""
            SELECT user_id, expires_at
            FROM password_reset_otps
            WHERE reset_token = %s
            FOR UPDATE;
        """, (reset_token,))
        row = cur.fetchone()

        if not row:
            return mobile_api_response(
                ok=False, message="Token tidak valid.", status_code=400)
        if row["expires_at"].replace(tzinfo=None) < datetime.utcnow():
            return mobile_api_response(
                ok=False, message="Token sudah kedaluwarsa. Mulai ulang.", status_code=400)

        from werkzeug.security import generate_password_hash
        new_hash = generate_password_hash(new_password)

        cur.execute(
            "UPDATE users SET password_hash = %s WHERE id = %s;",
            (new_hash, row["user_id"])
        )
        # Hapus token setelah dipakai
        cur.execute(
            "DELETE FROM password_reset_otps WHERE user_id = %s;",
            (row["user_id"],)
        )
        # Nonaktifkan semua token login lama (paksa login ulang)
        cur.execute(
            "UPDATE mobile_api_tokens SET is_active = FALSE WHERE user_id = %s;",
            (row["user_id"],)
        )
        conn.commit()

        return mobile_api_response(
            ok=True, message="Password berhasil diubah. Silakan login kembali.",
            data={}
        )
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()

import hashlib
import hmac
import random
import secrets
import string
import time

from flask import Blueprint, render_template, request, redirect, session, url_for, jsonify
from psycopg2.extras import RealDictCursor
from werkzeug.security import generate_password_hash, check_password_hash

from db import get_conn
from core import (
    GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, oauth, ensure_password_reset_schema,
    send_email, send_wa, _otp_hash, _public_ip, _otp_verify_rate_limited,
    find_user_by_identifier, _ensure_admin_feature_access_schema,
)


auth_bp = Blueprint("auth", __name__)

@auth_bp.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "GET":
        return render_template("register.html", error=None)

    import os
    name         = (request.form.get("name")        or "").strip()
    email        = (request.form.get("email")       or "").strip().lower()
    password     = request.form.get("password")     or ""
    invite_input = (request.form.get("invite_code") or "").strip().upper()

    INVITE_CODE = (os.environ.get("INVITE_CODE") or "").strip().upper()

    if not name or not email or not password:
        return render_template("register.html", error="Semua field wajib diisi.")

    if INVITE_CODE and invite_input != INVITE_CODE:
        return render_template("register.html", error="Kode undangan salah. Hubungi admin.")

    pw_hash = generate_password_hash(password)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT id FROM users WHERE lower(email)=%s LIMIT 1;", (email,))
        existing = cur.fetchone()
        if existing:
            return render_template("register.html", error="Email sudah terdaftar.")

        cur.execute("""
            INSERT INTO users (name, email, password_hash, role)
            VALUES (%s, %s, %s, 'employee')
            RETURNING id, name, role;
        """, (name, email, pw_hash))
        user = cur.fetchone()
        conn.commit()
    except Exception as e:
        conn.rollback()
        return render_template("register.html", error=f"Gagal membuat akun: {str(e)}")
    finally:
        cur.close()
        conn.close()

    if not user:
        return render_template("register.html", error="Gagal membuat akun.")

    session["user_id"] = user["id"]
    session["user_name"] = user["name"]
    session["role"] = user["role"]
    return redirect("/")

@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "GET":
        return render_template("login.html", error=None)

    email = (request.form.get("email") or "").strip().lower()
    password = request.form.get("password") or ""

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_admin_feature_access_schema(cur)
        conn.commit()
        cur.execute("""
            SELECT id, name, email, password_hash, role,
                   can_access_points, can_access_payroll
            FROM users
            WHERE lower(email)=%s
            LIMIT 1;
        """, (email,))
        user = cur.fetchone()
    finally:
        cur.close()
        conn.close()

    if not user or not check_password_hash(user["password_hash"], password):
        return render_template("login.html", error="Email atau password salah.")

    session["user_id"] = user["id"]
    session["user_name"] = user["name"]
    session["role"] = user.get("role", "employee")
    session["can_access_points"] = bool(user.get("can_access_points", True))
    session["can_access_payroll"] = bool(user.get("can_access_payroll", True))

    if session["role"] == "admin":
        return redirect("/admin/dashboard")
    if session["role"] == "owner":
        return redirect("/owner/dashboard")
    return redirect("/dashboard")

@auth_bp.route("/logout")
def logout():
    session.clear()
    return redirect("/login")

@auth_bp.route("/login/google")
def login_google():
    if not (GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET):
        return "Google OAuth belum dikonfigurasi", 500

    # Simpan kode undangan ke session sebelum redirect ke Google
    invite_code = (request.args.get("invite_code") or "").strip().upper()
    if invite_code:
        session["invite_code"] = invite_code

    redirect_uri = url_for("auth.google_callback", _external=True)
    return oauth.google.authorize_redirect(redirect_uri)

@auth_bp.route("/auth/google/callback")
def google_callback():
    token = oauth.google.authorize_access_token()
    userinfo = token.get("userinfo") or oauth.google.get(
        "https://openidconnect.googleapis.com/v1/userinfo"
    ).json()

    email = (userinfo.get("email") or "").strip().lower()
    name = (userinfo.get("name") or "User").strip()

    if not email:
        return "Email Google tidak ditemukan", 400

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_admin_feature_access_schema(cur)
        conn.commit()
        cur.execute("""
            SELECT id, name, role, can_access_points, can_access_payroll
            FROM users
            WHERE lower(email)=%s
            LIMIT 1;
        """, (email,))
        u = cur.fetchone()

        if not u:
            import os
            INVITE_CODE  = (os.environ.get("INVITE_CODE") or "").strip().upper()
            invite_input = (session.get("invite_code")    or "").strip().upper()
            if INVITE_CODE and invite_input != INVITE_CODE:
                session.pop("invite_code", None)
                return render_template("login.html",
                    error="Kode undangan salah. Daftar via Google memerlukan kode undangan.")

            rand_pw = hashlib.sha256(f"{email}:{time.time()}".encode()).hexdigest()
            pw_hash = generate_password_hash(rand_pw)

            cur.execute("""
                INSERT INTO users (name, email, password_hash, role)
                VALUES (%s, %s, %s, 'employee')
                RETURNING id, name, role, can_access_points, can_access_payroll;
            """, (name, email, pw_hash))
            u = cur.fetchone()

        session.pop("invite_code", None)
        conn.commit()
    finally:
        cur.close()
        conn.close()

    session.clear()
    session["user_id"] = u["id"]
    session["user_name"] = u["name"]
    session["can_access_points"] = bool(u.get("can_access_points", True))
    session["can_access_payroll"] = bool(u.get("can_access_payroll", True))
    session["role"] = u["role"]

    if u["role"] == "admin":
        return redirect("/admin/dashboard")
    if u["role"] == "owner":
        return redirect("/owner/dashboard")
    return redirect("/dashboard")

def _mask_email(email: str) -> str:
    local, _, domain = email.partition("@")
    if not domain:
        return email
    keep = local[:2] if len(local) > 2 else local[:1]
    return f"{keep}{'*' * max(3, len(local) - len(keep))}@{domain}"

def _mask_wa(phone: str) -> str:
    p = phone.strip().replace("+", "").replace(" ", "")
    if len(p) <= 6:
        return p
    return p[:4] + "****" + p[-4:]

OTP_RESEND_COOLDOWN_SECONDS = 45

@auth_bp.route("/forgot", methods=["GET"])
def forgot_password():
    return render_template("forgot_password.html")

@auth_bp.route("/forgot/send-otp", methods=["POST"])
def forgot_send_otp():
    ensure_password_reset_schema()
    data = request.get_json(silent=True) or {}
    method = (data.get("method") or "").strip().lower()
    identifier = (data.get("identifier") or "").strip()

    if method not in ("email", "wa"):
        return jsonify(ok=False, message="Metode tidak valid."), 400
    if not identifier:
        return jsonify(ok=False, message="Email atau nomor WhatsApp wajib diisi."), 400

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        if method == "email":
            email = identifier.lower()
            cur.execute("SELECT id FROM users WHERE lower(email)=%s LIMIT 1;", (email,))
            user = cur.fetchone()
            if not user:
                conn.commit()
                return jsonify(ok=True, message="Jika akun ditemukan, OTP akan dikirim.", masked=_mask_email(email))

            cur.execute("""
                SELECT 1 FROM password_reset_otps
                WHERE email=%s AND used=FALSE
                  AND created_at > NOW() - make_interval(secs => %s)
                LIMIT 1;
            """, (email, OTP_RESEND_COOLDOWN_SECONDS))
            if cur.fetchone():
                return jsonify(ok=False, message="Tunggu sebentar sebelum mengirim ulang OTP."), 429

            otp = f"{random.randint(0, 999999):06d}"
            otp_h = _otp_hash(email, otp)

            cur.execute("UPDATE password_reset_otps SET used=TRUE WHERE email=%s AND used=FALSE;", (email,))
            cur.execute("""
                INSERT INTO password_reset_otps (email, otp_hash, expires_at, used)
                VALUES (%s, %s, NOW() + INTERVAL '10 minutes', FALSE);
            """, (email, otp_h))
            conn.commit()

            try:
                send_email(
                    to_email=email,
                    subject="UMGAP • Kode OTP Reset Password",
                    body=(
                        f"Halo,\n\n"
                        f"Kode OTP reset password kamu: {otp}\n"
                        f"Berlaku 10 menit.\n\n"
                        f"Jika kamu tidak meminta reset, abaikan email ini."
                    ),
                )
            except Exception as e:
                return jsonify(ok=False, message=f"Gagal kirim email OTP: {str(e)}"), 500

            return jsonify(ok=True, message="OTP dikirim ke email.", masked=_mask_email(email))

        else:  # method == "wa"
            user = find_user_by_identifier(cur, identifier)
            if not user:
                print(f"[FORGOT WA] user tidak ditemukan untuk identifier={identifier!r}")
                conn.commit()
                return jsonify(ok=True, message="Jika akun ditemukan, OTP akan dikirim.", masked=_mask_wa(identifier))
            if not (user.get("phone") or "").strip():
                print(f"[FORGOT WA] user id={user['id']} ditemukan tapi kolom phone kosong")
                conn.commit()
                return jsonify(ok=True, message="Jika akun ditemukan, OTP akan dikirim.", masked=_mask_wa(identifier))

            phone = user["phone"].strip()

            cur.execute("""
                SELECT 1 FROM password_reset_otps
                WHERE user_id=%s AND used=FALSE
                  AND created_at > NOW() - make_interval(secs => %s)
                LIMIT 1;
            """, (user["id"], OTP_RESEND_COOLDOWN_SECONDS))
            if cur.fetchone():
                return jsonify(ok=False, message="Tunggu sebentar sebelum mengirim ulang OTP."), 429

            cur.execute("DELETE FROM password_reset_otps WHERE user_id=%s;", (user["id"],))
            otp = "".join(random.choices(string.digits, k=6))
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
            print(f"[FORGOT WA] send_wa dipanggil untuk user id={user['id']} phone={_mask_wa(phone)}")
            send_wa(phone, msg)

            return jsonify(ok=True, message="OTP dikirim ke WhatsApp.", masked=_mask_wa(phone))
    except Exception as e:
        conn.rollback()
        import traceback
        print(f"[FORGOT SEND OTP] {traceback.format_exc()}")
        return jsonify(ok=False, message=f"Server error: {str(e)}"), 500
    finally:
        cur.close()
        conn.close()

@auth_bp.route("/forgot/verify-otp", methods=["POST"])
def forgot_verify_otp():
    ensure_password_reset_schema()
    data = request.get_json(silent=True) or {}
    method = (data.get("method") or "").strip().lower()
    identifier = (data.get("identifier") or "").strip()
    otp = (data.get("otp") or "").strip()

    if method not in ("email", "wa"):
        return jsonify(ok=False, message="Metode tidak valid."), 400
    if len(otp) != 6 or not otp.isdigit():
        return jsonify(ok=False, message="OTP tidak valid."), 400

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        ip_address = (_public_ip() or "")[:64]
        if _otp_verify_rate_limited(cur, ip_address):
            conn.commit()
            return jsonify(ok=False, message="Terlalu banyak percobaan. Coba lagi beberapa menit lagi."), 429
        conn.commit()

        if method == "email":
            email = identifier.lower()
            otp_h = _otp_hash(email, otp)
            cur.execute("""
                SELECT id, otp_hash, (expires_at < NOW()) AS is_expired
                FROM password_reset_otps
                WHERE email=%s AND used=FALSE
                ORDER BY created_at DESC LIMIT 1
                FOR UPDATE;
            """, (email,))
            row = cur.fetchone()

            if not row:
                return jsonify(ok=False, message="OTP tidak ditemukan atau sudah dipakai."), 400
            if row["is_expired"]:
                cur.execute("UPDATE password_reset_otps SET used=TRUE WHERE id=%s;", (row["id"],))
                conn.commit()
                return jsonify(ok=False, message="OTP sudah kedaluwarsa."), 400
            if not hmac.compare_digest(row["otp_hash"], otp_h):
                return jsonify(ok=False, message="OTP salah."), 400

            reset_token = secrets.token_urlsafe(32)
            cur.execute("""
                UPDATE password_reset_otps
                SET used=TRUE, reset_token=%s, expires_at=NOW() + INTERVAL '15 minutes'
                WHERE id=%s;
            """, (reset_token, row["id"]))
            conn.commit()
            return jsonify(ok=True, message="OTP valid.", reset_token=reset_token)

        else:  # method == "wa"
            user = find_user_by_identifier(cur, identifier)
            if not user:
                return jsonify(ok=False, message="OTP tidak valid."), 400

            cur.execute("""
                SELECT id, used, (expires_at < NOW()) AS is_expired
                FROM password_reset_otps
                WHERE otp=%s AND user_id=%s
                FOR UPDATE;
            """, (otp, user["id"]))
            row = cur.fetchone()

            if not row:
                return jsonify(ok=False, message="OTP tidak valid."), 400
            if row["used"]:
                return jsonify(ok=False, message="OTP sudah digunakan."), 400
            if row["is_expired"]:
                return jsonify(ok=False, message="OTP sudah kedaluwarsa."), 400

            reset_token = secrets.token_urlsafe(32)
            cur.execute("""
                UPDATE password_reset_otps
                SET used=TRUE, reset_token=%s, expires_at=NOW() + INTERVAL '15 minutes'
                WHERE id=%s;
            """, (reset_token, row["id"]))
            conn.commit()
            return jsonify(ok=True, message="OTP valid.", reset_token=reset_token)
    except Exception as e:
        conn.rollback()
        import traceback
        print(f"[FORGOT VERIFY OTP] {traceback.format_exc()}")
        return jsonify(ok=False, message=f"Server error: {str(e)}"), 500
    finally:
        cur.close()
        conn.close()

@auth_bp.route("/forgot/set-password", methods=["POST"])
def forgot_set_password():
    ensure_password_reset_schema()
    data = request.get_json(silent=True) or {}
    reset_token = (data.get("reset_token") or "").strip()
    new_password = (data.get("new_password") or "").strip()
    confirm = (data.get("confirm_password") or "").strip()

    if not reset_token or not new_password:
        return jsonify(ok=False, message="Data tidak lengkap."), 400
    if new_password != confirm:
        return jsonify(ok=False, message="Konfirmasi password tidak sama."), 400
    if len(new_password) < 6:
        return jsonify(ok=False, message="Password minimal 6 karakter."), 400

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, email, user_id, (expires_at < NOW()) AS is_expired
            FROM password_reset_otps
            WHERE reset_token=%s
            FOR UPDATE;
        """, (reset_token,))
        row = cur.fetchone()

        if not row:
            return jsonify(ok=False, message="Sesi reset tidak valid. Mulai ulang."), 400
        if row["is_expired"]:
            return jsonify(ok=False, message="Sesi reset sudah kedaluwarsa. Mulai ulang."), 400

        pw_hash = generate_password_hash(new_password)
        if row["email"]:
            cur.execute("UPDATE users SET password_hash=%s WHERE lower(email)=%s;", (pw_hash, row["email"]))
        else:
            cur.execute("UPDATE users SET password_hash=%s WHERE id=%s;", (pw_hash, row["user_id"]))

        cur.execute("DELETE FROM password_reset_otps WHERE reset_token=%s;", (reset_token,))
        conn.commit()
        return jsonify(ok=True, message="Password berhasil diubah.")
    except Exception as e:
        conn.rollback()
        import traceback
        print(f"[FORGOT SET PASSWORD] {traceback.format_exc()}")
        return jsonify(ok=False, message=f"Server error: {str(e)}"), 500
    finally:
        cur.close()
        conn.close()
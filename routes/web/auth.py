import hashlib
import hmac
import random
import time
from datetime import datetime, timedelta

from flask import Blueprint, render_template, request, redirect, session, url_for
from psycopg2.extras import RealDictCursor
from werkzeug.security import generate_password_hash, check_password_hash

from db import get_conn
from core import GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, oauth, ensure_password_reset_schema, send_email, _otp_hash


auth_bp = Blueprint("auth", __name__)

@auth_bp.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "GET":
        return render_template("register.html", error=None)

    name = (request.form.get("name") or "").strip()
    email = (request.form.get("email") or "").strip().lower()
    password = request.form.get("password") or ""

    if not name or not email or not password:
        return render_template("register.html", error="Semua field wajib diisi.")

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
        cur.execute("""
            SELECT id, name, email, password_hash, role
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

    return redirect("/admin/dashboard" if session["role"] == "admin" else "/dashboard")

@auth_bp.route("/logout")
def logout():
    session.clear()
    return redirect("/login")

@auth_bp.route("/login/google")
def login_google():
    if not (GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET):
        return "Google OAuth belum dikonfigurasi", 500

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
        cur.execute("""
            SELECT id, name, role
            FROM users
            WHERE lower(email)=%s
            LIMIT 1;
        """, (email,))
        u = cur.fetchone()

        if not u:
            rand_pw = hashlib.sha256(f"{email}:{time.time()}".encode()).hexdigest()
            pw_hash = generate_password_hash(rand_pw)

            cur.execute("""
                INSERT INTO users (name, email, password_hash, role)
                VALUES (%s, %s, %s, 'employee')
                RETURNING id, name, role;
            """, (name, email, pw_hash))
            u = cur.fetchone()

        conn.commit()
    finally:
        cur.close()
        conn.close()

    session.clear()
    session["user_id"] = u["id"]
    session["user_name"] = u["name"]
    session["role"] = u["role"]

    return redirect("/admin/dashboard" if u["role"] == "admin" else "/dashboard")

@auth_bp.route("/forgot", methods=["GET", "POST"])
def forgot_password():
    if request.method == "GET":
        return render_template("forgot_password.html")

    ensure_password_reset_schema()
    email = (request.form.get("email") or "").strip().lower()

    if not email:
        return render_template("forgot_password.html", error="Email wajib diisi.")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT id FROM users WHERE lower(email)=%s LIMIT 1;", (email,))
        u = cur.fetchone()
    finally:
        cur.close()
        conn.close()

    if not u:
        return render_template("forgot_password.html", sent=True)

    otp = f"{__import__('random').randint(0, 999999):06d}"
    otp_h = _otp_hash(email, otp)
    expires_at = datetime.utcnow() + timedelta(minutes=10)

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE password_reset_otps
            SET used=TRUE
            WHERE email=%s AND used=FALSE;
        """, (email,))
        cur.execute("""
            INSERT INTO password_reset_otps (email, otp_hash, expires_at, used)
            VALUES (%s, %s, %s, FALSE);
        """, (email, otp_h, expires_at))
        conn.commit()
    finally:
        cur.close()
        conn.close()

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
        return render_template("forgot_password.html", error=f"Gagal kirim email OTP: {str(e)}")

    return render_template("forgot_password.html", sent=True, email=email)

@auth_bp.route("/reset", methods=["GET", "POST"])
def reset_password():
    if request.method == "GET":
        email = (request.args.get("email") or "").strip().lower()
        return render_template("reset_password.html", email=email)

    ensure_password_reset_schema()

    email = (request.form.get("email") or "").strip().lower()
    otp = (request.form.get("otp") or "").strip()
    new_password = (request.form.get("new_password") or "").strip()
    confirm = (request.form.get("confirm_password") or "").strip()

    if not email or not otp or not new_password:
        return render_template("reset_password.html", email=email, error="Email, OTP, dan password baru wajib diisi.")
    if new_password != confirm:
        return render_template("reset_password.html", email=email, error="Konfirmasi password tidak sama.")
    if len(new_password) < 6:
        return render_template("reset_password.html", email=email, error="Password minimal 6 karakter.")

    otp_h = _otp_hash(email, otp)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, otp_hash, expires_at, used
            FROM password_reset_otps
            WHERE email=%s AND used=FALSE
            ORDER BY created_at DESC
            LIMIT 1;
        """, (email,))
        row = cur.fetchone()

        if not row:
            return render_template("reset_password.html", email=email, error="OTP tidak ditemukan atau sudah dipakai.")

        if datetime.utcnow() > row["expires_at"]:
            cur.execute("UPDATE password_reset_otps SET used=TRUE WHERE id=%s;", (row["id"],))
            conn.commit()
            return render_template("reset_password.html", email=email, error="OTP sudah kedaluwarsa.")

        if not hmac.compare_digest(row["otp_hash"], otp_h):
            return render_template("reset_password.html", email=email, error="OTP salah.")

        pw_hash = generate_password_hash(new_password)

        cur.execute("""
            UPDATE users
            SET password_hash=%s
            WHERE lower(email)=%s;
        """, (pw_hash, email))

        cur.execute("""
            UPDATE password_reset_otps
            SET used=TRUE
            WHERE id=%s;
        """, (row["id"],))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/login")
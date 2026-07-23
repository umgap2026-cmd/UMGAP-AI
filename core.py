import os
import io
import re
import ssl
import random
import smtplib
import hmac
import hashlib
import uuid
import threading
import requests
from collections import defaultdict
from datetime import datetime, timedelta
from email.message import EmailMessage
from functools import wraps
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from zoneinfo import ZoneInfo
from google.oauth2 import service_account
from google.auth.transport.requests import Request as GoogleAuthRequest


import pytz
from flask import session, request, redirect, abort, jsonify, url_for, flash
from dotenv import load_dotenv
from psycopg2.extras import RealDictCursor, Json
from authlib.integrations.flask_client import OAuth
from werkzeug.utils import secure_filename

from db import get_conn

load_dotenv()

wib = pytz.timezone("Asia/Jakarta")

oauth = OAuth()
GOOGLE_CLIENT_ID = (os.getenv("GOOGLE_CLIENT_ID") or "").strip()
GOOGLE_CLIENT_SECRET = (os.getenv("GOOGLE_CLIENT_SECRET") or "").strip()

UPLOAD_INVOICE_LOGO_DIR = os.path.join("static", "uploads", "invoice_logo")


# =========================
# OAUTH
# =========================
def init_oauth(app):
    oauth.init_app(app)

    if GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET:
        oauth.register(
            name="google",
            client_id=GOOGLE_CLIENT_ID,
            client_secret=GOOGLE_CLIENT_SECRET,
            server_metadata_url="https://accounts.google.com/.well-known/openid-configuration",
            client_kwargs={"scope": "openid email profile"},
        )


# =========================
# SESSION / AUTH HELPERS
# =========================
def is_logged_in():
    return "user_id" in session

def is_admin():
    return session.get("role") == "admin"

def admin_guard():
    if not is_logged_in():
        return redirect("/login")
    if not is_admin():
        abort(403)
    return None

def admin_required():
    if not session.get("user_id"):
        return redirect(url_for("auth.login"))
    if session.get("role") != "admin":
        flash("Akses ditolak. Hanya admin.", "danger")
        return redirect(url_for("dashboard.dashboard"))
    return None

# =========================
# FILE / DIR HELPERS
# =========================
def _ensure_invoice_logo_dir():
    os.makedirs(UPLOAD_INVOICE_LOGO_DIR, exist_ok=True)

def _save_company_logo(file_storage):
    if not file_storage or not file_storage.filename:
        return None

    _ensure_invoice_logo_dir()

    raw_name = secure_filename(file_storage.filename or "")
    ext = os.path.splitext(raw_name)[1].lower()
    if ext not in [".png", ".jpg", ".jpeg", ".webp"]:
        ext = ".png"

    filename = (
        f"inv_logo_{datetime.now(ZoneInfo('Asia/Jakarta')).strftime('%Y%m%d_%H%M%S')}_"
        f"{uuid.uuid4().hex[:8]}{ext}"
    )
    save_path = os.path.join(UPLOAD_INVOICE_LOGO_DIR, filename)
    file_storage.save(save_path)

    return f"uploads/invoice_logo/{filename}"


# =========================
# TIME / FORMAT HELPERS
# =========================
def _parse_manual_wib_naive(manual_dt):
    if not manual_dt:
        return None
    try:
        return datetime.strptime(manual_dt.strip(), "%Y-%m-%dT%H:%M")
    except Exception:
        return None

def _now_wib_naive_from_form():
    client_ts = request.form.get("client_ts")
    if client_ts and client_ts.isdigit():
        now_wib_aware = datetime.fromtimestamp(
            int(client_ts) / 1000,
            tz=ZoneInfo("Asia/Jakarta")
        )
    else:
        now_wib_aware = datetime.now(ZoneInfo("Asia/Jakarta"))
    return now_wib_aware.replace(tzinfo=None)

def _utc_naive_to_wib_naive(dt):
    if not dt:
        return None
    return dt + timedelta(hours=7)

def _now_wib_naive():
    return datetime.now(ZoneInfo("Asia/Jakarta")).replace(tzinfo=None)

def _utc_naive_to_wib_string(dt, fmt="%Y-%m-%d %H:%M:%S"):
    dt_wib = _utc_naive_to_wib_naive(dt)
    return dt_wib.strftime(fmt) if dt_wib else ""

def _parse_date(s):
    if not s:
        return None
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except Exception:
        return None

# =========================
# GENERAL HELPERS
# =========================
def _public_ip():
    xf = request.headers.get("X-Forwarded-For", "")
    if xf:
        return xf.split(",")[0].strip()
    return request.remote_addr

def pick(options):
    return random.choice(options)

def rupiah(s):
    try:
        n = int(s)
        return f"Rp {n:,}".replace(",", ".")
    except Exception:
        return f"Rp {s}"

def _safe_int(v, default=0):
    try:
        return int(v)
    except Exception:
        return default

def _safe_decimal(v, default="0"):
    try:
        raw = str(v or "").strip().replace(",", ".")
        if not raw:
            return Decimal(default)
        return Decimal(raw)
    except (InvalidOperation, ValueError, TypeError):
        return Decimal(default)

# =========================
# WA BOT
# =========================
WA_BOT_URL = os.getenv("WA_BOT_URL", "").strip()
WA_BOT_KEY = os.getenv("WA_BOT_KEY", "").strip()

def send_wa(phone: str, message: str):
    """Kirim WA via Baileys bot — fire and forget di background thread.
    Dipakai bersama oleh routes/mobile/attendance.py, finance.py, auth.py."""
    if not WA_BOT_URL:
        print(f"[WA] WA_BOT_URL belum diatur di .env — pesan untuk {phone} tidak terkirim via WA.")
        return

    def _do():
        try:
            # Normalisasi nomor: hapus karakter non-angka, ganti 0 di depan → 62
            num = phone.strip().replace(" ", "").replace("-", "").replace("+", "")
            if num.startswith("0"):
                num = "62" + num[1:]
            headers = {"X-Bot-Key": WA_BOT_KEY} if WA_BOT_KEY else {}
            requests.post(
                WA_BOT_URL,
                json={"phone": num, "message": message},
                headers=headers,
                timeout=5
            )
        except Exception as ex:
            print(f"[WA] Gagal kirim ke {phone}: {ex}")
    threading.Thread(target=_do, daemon=True).start()


# =========================
# OTP / EMAIL
# =========================
def _otp_hash(email, otp):
    salt = (os.getenv("RESET_OTP_SALT") or "umgap-reset-salt").encode("utf-8")
    msg = (email.lower().strip() + ":" + otp.strip()).encode("utf-8")
    return hashlib.sha256(salt + msg).hexdigest()

def send_email(to_email, subject, body):
    smtp_host = (os.getenv("SMTP_HOST") or "").strip()
    smtp_port = int((os.getenv("SMTP_PORT") or "465").strip())
    smtp_user = (os.getenv("SMTP_USER") or "").strip()
    smtp_pass = (os.getenv("SMTP_PASS") or "").strip()
    smtp_from = (os.getenv("SMTP_FROM") or smtp_user).strip()

    if not smtp_host or not smtp_user or not smtp_pass:
        raise RuntimeError("SMTP belum dikonfigurasi lengkap di .env")

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = smtp_from
    msg["To"] = to_email
    msg.set_content(body)

    context = ssl.create_default_context()
    with smtplib.SMTP_SSL(smtp_host, smtp_port, context=context) as server:
        server.login(smtp_user, smtp_pass)
        server.send_message(msg)


# =========================
# SCHEMA HELPERS
# =========================
def _ensure_transaction_cancel_columns(cur):
    """Lazy-migration: pastikan kolom pembatalan nota tersedia di fin_transactions.
    Dipakai bersama oleh routes/mobile/finance.py dan routes/mobile/invoice.py."""
    cur.execute("""
        ALTER TABLE fin_transactions
            ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP NULL,
            ADD COLUMN IF NOT EXISTS cancelled_by INTEGER NULL,
            ADD COLUMN IF NOT EXISTS print_size VARCHAR(20) NULL,
            ADD COLUMN IF NOT EXISTS delete_reason TEXT NULL,
            ADD COLUMN IF NOT EXISTS delete_mode VARCHAR(20) NULL,
            ADD COLUMN IF NOT EXISTS related_transaction_id INTEGER NULL;
    """)


def _ensure_fin_returns_schema(cur):
    """Lazy-migration: tabel retur sebagian (barang balik) tertaut ke nota asal."""
    cur.execute("""
        CREATE TABLE IF NOT EXISTS fin_returns (
            id SERIAL PRIMARY KEY,
            transaction_id INTEGER NOT NULL REFERENCES fin_transactions(id),
            material_id INTEGER NOT NULL REFERENCES fin_materials(id),
            qty_kg NUMERIC(14,3) NOT NULL,
            price_per_kg NUMERIC(14,2) NOT NULL,
            value NUMERIC(14,2) NOT NULL,
            reason TEXT,
            note TEXT,
            created_by INTEGER REFERENCES users(id),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
    """)

def _table_exists(cur, table):
    cur.execute("""
        SELECT 1 FROM information_schema.tables
        WHERE table_name=%s LIMIT 1;
    """, (table,))
    return cur.fetchone() is not None

def _col_exists(cur, table, column):
    cur.execute("""
        SELECT 1 FROM information_schema.columns
        WHERE table_name=%s AND column_name=%s LIMIT 1;
    """, (table, column))
    return cur.fetchone() is not None

# ── Rate limit percobaan verifikasi OTP (anti brute-force, per IP) ──
# Dipakai bersama oleh routes/web/auth.py dan routes/mobile/auth.py.
OTP_VERIFY_MAX_ATTEMPTS = 8
OTP_VERIFY_WINDOW_MINUTES = 15

def _ensure_otp_throttle_table(cur):
    cur.execute("""
        CREATE TABLE IF NOT EXISTS otp_verify_throttle (
            ip_address        VARCHAR(64) PRIMARY KEY,
            attempt_count     INT NOT NULL DEFAULT 0,
            window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
    """)

def _otp_verify_rate_limited(cur, ip_address: str) -> bool:
    """Catat satu percobaan verifikasi OTP untuk IP ini, lalu return True
    kalau IP tersebut sudah melewati batas percobaan dalam jendela waktu berjalan."""
    _ensure_otp_throttle_table(cur)
    cur.execute("""
        INSERT INTO otp_verify_throttle (ip_address, attempt_count, window_started_at)
        VALUES (%s, 1, NOW())
        ON CONFLICT (ip_address) DO UPDATE SET
            attempt_count = CASE
                WHEN otp_verify_throttle.window_started_at < NOW() - make_interval(mins => %s)
                    THEN 1
                ELSE otp_verify_throttle.attempt_count + 1
            END,
            window_started_at = CASE
                WHEN otp_verify_throttle.window_started_at < NOW() - make_interval(mins => %s)
                    THEN NOW()
                ELSE otp_verify_throttle.window_started_at
            END
        RETURNING attempt_count;
    """, (ip_address, OTP_VERIFY_WINDOW_MINUTES, OTP_VERIFY_WINDOW_MINUTES))
    row = cur.fetchone()
    count = row["attempt_count"] if row else 1
    return count > OTP_VERIFY_MAX_ATTEMPTS

def ensure_password_reset_schema():
    """Skema bersama untuk reset password web (email+otp_hash) & mobile
    (user_id+otp+reset_token via WA) — dulu ada 2 fungsi terpisah yang
    bikin tabel sama dengan kolom berbeda, siapa pun jalan duluan bikin
    alur satunya gagal. Sekarang 1 tabel, semua kolom opsional kecuali
    yang dipakai bersama (expires_at, used, created_at)."""
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS password_reset_otps (
                id SERIAL PRIMARY KEY,
                email VARCHAR(255),
                otp_hash TEXT,
                user_id INTEGER,
                otp CHAR(6),
                reset_token TEXT,
                expires_at TIMESTAMP NOT NULL,
                used BOOLEAN NOT NULL DEFAULT FALSE,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
        for col_sql in [
            "ALTER TABLE password_reset_otps ADD COLUMN IF NOT EXISTS email VARCHAR(255)",
            "ALTER TABLE password_reset_otps ADD COLUMN IF NOT EXISTS otp_hash TEXT",
            "ALTER TABLE password_reset_otps ADD COLUMN IF NOT EXISTS user_id INTEGER",
            "ALTER TABLE password_reset_otps ADD COLUMN IF NOT EXISTS otp CHAR(6)",
            "ALTER TABLE password_reset_otps ADD COLUMN IF NOT EXISTS reset_token TEXT",
        ]:
            try:
                cur.execute(col_sql)
            except Exception:
                conn.rollback()
        try:
            cur.execute("""
                CREATE UNIQUE INDEX IF NOT EXISTS idx_password_reset_otps_reset_token
                ON password_reset_otps(reset_token) WHERE reset_token IS NOT NULL;
            """)
        except Exception:
            conn.rollback()
        try:
            cur.execute("CREATE INDEX IF NOT EXISTS idx_password_reset_otps_otp ON password_reset_otps(otp);")
        except Exception:
            conn.rollback()
        conn.commit()
    finally:
        cur.close()
        conn.close()

_mobile_api_schema_ready = False

def ensure_mobile_api_schema():
    """Buat tabel/index mobile_api_tokens kalau belum ada.

    Dipanggil dari mobile_api_login_required (yaitu di setiap request mobile
    yang butuh login), jadi hasilnya di-cache di memori per-process supaya
    tidak menjalankan DDL berulang-ulang pada tiap request.
    """
    global _mobile_api_schema_ready
    if _mobile_api_schema_ready:
        return

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS mobile_api_tokens (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                token TEXT NOT NULL UNIQUE,
                device_name VARCHAR(120),
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
        _mobile_api_schema_ready = True
    finally:
        cur.close()
        conn.close()

def ensure_hr_v2_schema():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS payroll_settings (
                id SERIAL PRIMARY KEY,
                user_id INTEGER UNIQUE REFERENCES users(id) ON DELETE CASCADE,
                salary_type VARCHAR(20) NOT NULL DEFAULT 'monthly',
                monthly_salary NUMERIC(14,2) NOT NULL DEFAULT 0,
                daily_salary NUMERIC(14,2) NOT NULL DEFAULT 0,
                hourly_salary NUMERIC(14,2) NOT NULL DEFAULT 0,
                overtime_hourly NUMERIC(14,2) NOT NULL DEFAULT 0,
                bonus_default NUMERIC(14,2) NOT NULL DEFAULT 0,
                transport_default NUMERIC(14,2) NOT NULL DEFAULT 0,
                meal_default NUMERIC(14,2) NOT NULL DEFAULT 0,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()

def ensure_invoice_schema():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS invoices (
                id SERIAL PRIMARY KEY,
                invoice_no VARCHAR(80) UNIQUE NOT NULL,
                created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
                customer_name VARCHAR(120),
                customer_phone VARCHAR(50),
                company_name VARCHAR(150),
                company_logo_path TEXT,
                print_size VARCHAR(20) DEFAULT '80mm',
                payment_method VARCHAR(20) DEFAULT 'CASH',
                subtotal NUMERIC(14,2) NOT NULL DEFAULT 0,
                discount NUMERIC(14,2) NOT NULL DEFAULT 0,
                grand_total NUMERIC(14,2) NOT NULL DEFAULT 0,
                notes TEXT,
                is_paid BOOLEAN NOT NULL DEFAULT TRUE,
                paid_at TIMESTAMP,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)

        cur.execute("""
            CREATE TABLE IF NOT EXISTS invoice_items (
                id SERIAL PRIMARY KEY,
                invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
                product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
                product_name VARCHAR(150) NOT NULL,
                qty NUMERIC(14,2) NOT NULL DEFAULT 0,
                price NUMERIC(14,2) NOT NULL DEFAULT 0,
                subtotal NUMERIC(14,2) NOT NULL DEFAULT 0
            );
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()


# =========================
# ATTENDANCE / PUBLIC TOKEN
# =========================
def is_token_valid(token: str) -> bool:
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute(
            "SELECT 1 FROM attendance_links WHERE token=%s AND is_active=TRUE LIMIT 1;",
            (token,)
        )
        return cur.fetchone() is not None
    finally:
        cur.close()
        conn.close()


# =========================
# ATTENDANCE — CHECK-OUT (dipakai bersama web & mobile)
# =========================
def _ensure_attendance_checkout_column(cur):
    """Lazy-migration: kolom checkout_at/checkout_auto belum ada di skema
    attendance lama. Dipakai bersama routes/web/attendance.py,
    routes/web/admin.py, routes/mobile/attendance.py."""
    cur.execute("ALTER TABLE attendance ADD COLUMN IF NOT EXISTS checkout_at TIMESTAMP NULL;")
    cur.execute("ALTER TABLE attendance ADD COLUMN IF NOT EXISTS checkout_auto BOOLEAN NOT NULL DEFAULT FALSE;")


def record_checkout(user_id, work_date, checkout_time=None):
    """
    Catat jam pulang (check-out) untuk attendance yang SUDAH ADA hari itu
    (artinya check-in sudah pernah disetujui admin — lihat
    routes/*/attendance.py approve flow). Tidak membuat record baru dan
    tidak butuh approval — cukup update kolom checkout_at.
    Submit ulang di hari yang sama menimpa jam sebelumnya.
    Raise ValueError kalau belum ada attendance untuk user_id+work_date itu.
    Return dict {checkin_at, checkout_at}.
    """
    checkout_time = checkout_time or _now_wib_naive()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_attendance_checkout_column(cur)
        cur.execute("""
            UPDATE attendance
            SET checkout_at = %s, checkout_auto = FALSE
            WHERE user_id = %s AND work_date = %s
            RETURNING checkin_at, checkout_at;
        """, (checkout_time, user_id, work_date))
        row = cur.fetchone()
        if not row:
            conn.rollback()
            raise ValueError("Belum ada absensi masuk yang disetujui untuk hari ini. Checkout tidak bisa dilakukan.")
        conn.commit()
        return dict(row)
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal mencatat checkout: {e}")
    finally:
        cur.close()
        conn.close()


def auto_checkout_forgotten():
    """
    Checkout otomatis untuk attendance yang sudah check-in tapi lupa
    check-out, untuk hari-hari yang SUDAH LEWAT (work_date < hari ini).
    Dipanggil oleh endpoint /api/mobile/auto-checkout (app.py), yang
    dipicu cron eksternal sekitar tengah malam — lihat pola
    /api/mobile/send-reminder & /api/mobile/send-daily-summary di app.py.
    Return jumlah baris yang di-checkout otomatis.
    """
    conn = get_conn()
    cur = conn.cursor()
    try:
        _ensure_attendance_checkout_column(cur)
        cur.execute("""
            UPDATE attendance
            SET checkout_at = (work_date + TIME '23:59:59'), checkout_auto = TRUE
            WHERE checkin_at IS NOT NULL
              AND checkout_at IS NULL
              AND work_date < CURRENT_DATE;
        """)
        n = cur.rowcount
        conn.commit()
        return n
    finally:
        cur.close()
        conn.close()


# =========================
# MOBILE API HELPERS
# =========================
def mobile_api_response(ok=True, message="", data=None, status_code=200):
    payload = {
        "ok": ok,
        "message": message,
        "data": data if data is not None else {}
    }
    return jsonify(payload), status_code

def get_bearer_token():
    auth = request.headers.get("Authorization", "").strip()
    if not auth.lower().startswith("bearer "):
        return None
    return auth[7:].strip()

def get_mobile_api_user():
    token = get_bearer_token()
    if not token:
        return None

    ensure_mobile_api_schema()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                t.id AS token_id,
                t.user_id,
                t.token,
                t.is_active,
                u.id,
                u.name,
                u.email,
                u.role,
                COALESCE(u.points, 0) AS points,
                COALESCE(u.points_admin, 0) AS points_admin
            FROM mobile_api_tokens t
            JOIN users u ON u.id = t.user_id
            WHERE t.token=%s
              AND t.is_active=TRUE
            LIMIT 1;
        """, (token,))
        row = cur.fetchone()

        if row:
            cur.execute("""
                UPDATE mobile_api_tokens
                SET last_used_at=CURRENT_TIMESTAMP
                WHERE id=%s;
            """, (row["token_id"],))
            conn.commit()

        return row
    finally:
        cur.close()
        conn.close()

def mobile_api_login_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        user = get_mobile_api_user()
        if not user:
            return mobile_api_response(
                ok=False,
                message="Unauthorized. Token tidak valid atau belum login.",
                status_code=401
            )
        request.mobile_user = user
        return fn(*args, **kwargs)
    return wrapper


# =========================
# INVOICE HELPERS
# =========================
def _make_invoice_no(prefix="INV"):
    now = datetime.now(ZoneInfo("Asia/Jakarta"))
    return f"{prefix}-" + now.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:5].upper()

def _invoice_rows_from_form(form):
    product_ids = form.getlist("product_id[]")
    qtys = form.getlist("qty[]")

    rows = []
    for i in range(min(len(product_ids), len(qtys))):
        pid = _safe_int(product_ids[i], 0)
        qty = _safe_decimal(qtys[i], "0")

        if pid > 0 and qty > 0:
            rows.append({
                "product_id": pid,
                "qty": qty
            })
    return rows

def save_invoice_common(request, is_admin_mode=False):
    ensure_invoice_schema()

    created_by = session.get("user_id")
    customer_name = (request.form.get("customer_name") or "").strip()
    customer_phone = (request.form.get("customer_phone") or "").strip()
    company_name = (request.form.get("company_name") or "").strip()
    payment_method = (request.form.get("payment_method") or "CASH").strip().upper()
    print_size = (request.form.get("print_size") or "80mm").strip()
    notes = (request.form.get("notes") or "").strip()
    discount = max(0, _safe_int(request.form.get("discount"), 0))
    is_paid = str(request.form.get("is_paid") or "1").strip() in ("1", "true", "True", "on", "yes")
    paid_at = datetime.utcnow() if is_paid else None

    logo_file = request.files.get("company_logo")
    company_logo_path = _save_company_logo(logo_file)

    target_user_id = created_by
    if is_admin_mode:
        target_user_id = _safe_int(request.form.get("employee_id"), created_by)

    item_rows = _invoice_rows_from_form(request.form)
    if not item_rows:
        return redirect("/admin/invoice/new" if is_admin_mode else "/invoice/new")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        invoice_no = _make_invoice_no()

        final_items = []
        subtotal = Decimal("0")

        for row in item_rows:
            cur.execute("""
                SELECT id, name, price
                FROM products
                WHERE id=%s AND is_global=TRUE
                LIMIT 1;
            """, (row["product_id"],))
            p = cur.fetchone()

            if not p:
                continue

            qty = _safe_decimal(row["qty"], "0")
            price = Decimal(str(int(p.get("price") or 0)))
            line_subtotal = (qty * price).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
            subtotal += line_subtotal

            final_items.append({
                "product_id": p["id"],
                "product_name": p["name"],
                "qty": qty,
                "price": int(price),
                "subtotal": int(line_subtotal)
            })

        if not final_items:
            return redirect("/admin/invoice/new" if is_admin_mode else "/invoice/new")

        grand_total = max(0, subtotal - discount)

        cur.execute("""
            INSERT INTO invoices
                (invoice_no, created_by, customer_name, customer_phone, company_name, company_logo_path,
                 print_size, payment_method, subtotal, discount, grand_total, notes, is_paid, paid_at)
            VALUES
                (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id;
        """, (
            invoice_no,
            created_by,
            customer_name,
            customer_phone,
            company_name,
            company_logo_path,
            print_size,
            payment_method,
            subtotal,
            discount,
            grand_total,
            notes,
            is_paid,
            paid_at
        ))

        invoice_id = (cur.fetchone() or {}).get("id")

        for item in final_items:
            cur.execute("""
                INSERT INTO invoice_items
                (invoice_id, product_id, product_name, qty, price, subtotal)
                VALUES (%s,%s,%s,%s,%s,%s);
            """, (
                invoice_id,
                item["product_id"],
                item["product_name"],
                str(item["qty"]),
                item["price"],
                item["subtotal"]
            ))

            cur.execute("""
                INSERT INTO sales_submissions
                (user_id, product_id, qty, note, status, created_at)
                VALUES (%s,%s,%s,%s,'APPROVED',CURRENT_TIMESTAMP);
            """, (
                target_user_id,
                item["product_id"],
                int(Decimal(str(item["qty"])).quantize(Decimal("1"), rounding=ROUND_HALF_UP)),
                f"INVOICE {invoice_no}"
            ))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect(f"/invoice/{invoice_id}")


# =========================
# NOTA (fin_transactions) — dipakai bersama web & mobile
# =========================
def owner_or_admin_required():
    if not session.get("user_id"):
        return redirect(url_for("auth.login"))
    if session.get("role") not in ("admin", "owner"):
        flash("Akses ditolak. Khusus admin/owner.", "danger")
        return redirect(url_for("dashboard.dashboard"))
    return None


def owner_required():
    if not session.get("user_id"):
        return redirect(url_for("auth.login"))
    if session.get("role") != "owner":
        flash("Akses ditolak. Khusus owner.", "danger")
        return redirect(url_for("dashboard.dashboard"))
    return None


def ensure_company_profile_schema():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS company_profile (
                id INTEGER PRIMARY KEY DEFAULT 1,
                company_name VARCHAR(150),
                logo_data_uri TEXT,
                updated_by INTEGER REFERENCES users(id),
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                CONSTRAINT company_profile_singleton CHECK (id = 1)
            );
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()


def get_company_profile():
    ensure_company_profile_schema()
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT company_name, logo_data_uri FROM company_profile WHERE id=1;")
        row = cur.fetchone()
        return {
            "company_name": (row or {}).get("company_name") or "",
            "logo_data_uri": (row or {}).get("logo_data_uri") or "",
        }
    finally:
        cur.close()
        conn.close()


def set_company_profile(company_name, logo_data_uri, updated_by):
    ensure_company_profile_schema()
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO company_profile (id, company_name, logo_data_uri, updated_by, updated_at)
            VALUES (1, %s, %s, %s, CURRENT_TIMESTAMP)
            ON CONFLICT (id) DO UPDATE SET
                company_name  = COALESCE(EXCLUDED.company_name, company_profile.company_name),
                logo_data_uri = COALESCE(EXCLUDED.logo_data_uri, company_profile.logo_data_uri),
                updated_by    = EXCLUDED.updated_by,
                updated_at    = CURRENT_TIMESTAMP;
        """, (company_name or None, logo_data_uri or None, updated_by))
        conn.commit()
    finally:
        cur.close()
        conn.close()


def get_materials_with_stock():
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                m.id, m.name, m.unit, m.sort_order,
                COALESCE(s.qty_kg, 0)          AS qty_kg,
                COALESCE(s.avg_cost_per_kg, 0) AS avg_cost_per_kg,
                COALESCE(s.total_value, 0)     AS total_value
            FROM fin_materials m
            LEFT JOIN fin_stock_summary s ON s.material_id = m.id
            WHERE m.is_active = TRUE
            ORDER BY m.sort_order, m.name;
        """)
        return [dict(r) for r in cur.fetchall()]
    finally:
        cur.close()
        conn.close()


def _record_ongkir_expense(cur, txn_id, invoice_no, ongkir, created_by):
    """Insert pengeluaran 'Ongkir' tertaut ke nota (mode BEBAN -- kita yang bayar)."""
    cur.execute("""
        INSERT INTO fin_transactions
            (type, party_name, note, total_amount, created_by, related_transaction_id)
        VALUES ('PENGELUARAN', 'Ongkir', %s, %s, %s, %s);
    """, (f"Ongkir nota {invoice_no}", ongkir, created_by, txn_id))


def create_fin_invoice(customer_name, customer_phone, payment_method, notes,
                        discount, is_paid, items, created_by, print_size=None,
                        ongkir=0, ongkir_mode="BEBAN"):
    """
    Buat nota JUAL_INVOICE dari stok gudang (fin_materials), potong stok AVCO,
    catat piutang jika belum lunas. Logic diextract dari
    routes/mobile/finance.py:create_invoice() agar web & mobile berbagi 1
    sumber kebenaran. Raise ValueError(pesan) kalau validasi gagal.

    ongkir_mode: "BEBAN" (kita yang bayar -- jadi pengeluaran terpisah di
    Finance, tertaut ke nota ini, TIDAK mengubah total nota) atau
    "POTONGAN" (mereka yang bayar -- langsung mengurangi total nota,
    diperlakukan seperti diskon tambahan).

    Return dict: {invoice_id, invoice_no, subtotal, discount, ongkir,
    ongkir_mode, total, hpp, laba}.
    """
    from routes.mobile.finance import _update_stock_avco

    customer_name = (customer_name or "").strip()
    if not customer_name:
        raise ValueError("Nama customer wajib diisi.")
    if not items:
        raise ValueError("Minimal 1 item barang.")

    discount = float(discount or 0)
    ongkir = float(ongkir or 0)
    ongkir_mode = (ongkir_mode or "BEBAN").strip().upper()
    if ongkir_mode not in ("BEBAN", "POTONGAN"):
        ongkir_mode = "BEBAN"
    print_size = print_size if print_size in ("58mm", "80mm") else "80mm"
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_transaction_cancel_columns(cur)
        for item in items:
            mat_id = item.get("material_id")
            if not mat_id:
                raise ValueError("material_id wajib di setiap item.")
            cur.execute(
                "SELECT id, name FROM fin_materials WHERE id=%s AND is_active=TRUE;",
                (int(mat_id),)
            )
            if not cur.fetchone():
                raise ValueError(f"Barang dengan material_id={mat_id} tidak ditemukan di gudang.")

        for item in items:
            mat_id = int(item["material_id"])
            qty = float(item.get("qty", 0))
            cur.execute("""
                SELECT COALESCE(s.qty_kg, 0) AS qty, m.name
                FROM fin_materials m
                LEFT JOIN fin_stock_summary s ON s.material_id = m.id
                WHERE m.id=%s;
            """, (mat_id,))
            row = cur.fetchone()
            if not row or float(row["qty"]) < qty:
                stok_ada = float(row["qty"]) if row else 0
                raise ValueError(
                    f"Stok {row['name'] if row else mat_id} tidak cukup. "
                    f"Tersedia: {stok_ada:.1f} kg, diminta: {qty:.1f} kg"
                )

        subtotal_bruto = sum(float(i.get("qty", 0)) * float(i.get("price", 0)) for i in items)
        potongan_ongkir = ongkir if ongkir_mode == "POTONGAN" else 0.0
        grand_total = max(0.0, subtotal_bruto - discount - potongan_ongkir)

        cur.execute("""
            SELECT COUNT(*) AS cnt FROM fin_transactions
            WHERE created_at::date = CURRENT_DATE AND type = 'JUAL_INVOICE';
        """)
        seq = (cur.fetchone()["cnt"] or 0) + 1
        invoice_no = f"INV-{datetime.now().strftime('%Y%m%d')}-{seq:04d}"

        is_debt = not is_paid
        cur.execute("""
            INSERT INTO fin_transactions
                (type, party_name, party_type, note, is_debt, total_amount, created_by, print_size)
            VALUES ('JUAL_INVOICE', %s, 'PELANGGAN', %s, %s, %s, %s, %s)
            RETURNING id;
        """, (
            customer_name,
            f"[{invoice_no}] {payment_method}" + (f" | {notes}" if notes else ""),
            is_debt, grand_total, created_by, print_size
        ))
        txn_id = cur.fetchone()["id"]

        hpp_total = 0.0
        for item in items:
            mat_id = int(item["material_id"])
            qty = float(item.get("qty", 0))
            price = float(item.get("price", 0))
            subtotal = qty * price

            cur.execute(
                "SELECT COALESCE(avg_cost_per_kg, 0) AS avg FROM fin_stock_summary WHERE material_id=%s;",
                (mat_id,)
            )
            row = cur.fetchone()
            avg = float(row["avg"]) if row else 0
            hpp_total += qty * avg

            cur.execute("""
                INSERT INTO fin_transaction_items
                    (transaction_id, material_id, qty_kg, price_per_kg, subtotal)
                VALUES (%s, %s, %s, %s, %s);
            """, (txn_id, mat_id, qty, price, subtotal))

            _update_stock_avco(
                cur, mat_id, qty, avg, 'OUT', txn_id,
                note=f"Invoice {invoice_no} — {customer_name}"
            )

        if is_debt and customer_name:
            cur.execute("""
                INSERT INTO fin_debts
                    (type, party_name, party_type, amount, remaining, transaction_id, note)
                VALUES ('PIUTANG', %s, 'PELANGGAN', %s, %s, %s, %s);
            """, (customer_name, grand_total, grand_total, txn_id,
                  f"Invoice {invoice_no} — belum dibayar"))

        if ongkir > 0 and ongkir_mode == "BEBAN":
            _record_ongkir_expense(cur, txn_id, invoice_no, ongkir, created_by)

        conn.commit()

        return {
            "invoice_id": txn_id,
            "invoice_no": invoice_no,
            "subtotal": subtotal_bruto,
            "discount": discount,
            "ongkir": ongkir,
            "ongkir_mode": ongkir_mode,
            "total": grand_total,
            "hpp": hpp_total,
            "laba": grand_total - hpp_total,
        }
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal buat invoice: {e}")
    finally:
        cur.close()
        conn.close()


def create_fin_purchase_invoice(supplier_name, supplier_phone, payment_method, notes,
                                 discount, is_paid, items, created_by, print_size=None,
                                 ongkir=0, ongkir_mode="BEBAN"):
    """
    Buat nota BELI_GUDANG (pembelian barang ke gudang) dengan nomor nota resmi
    (prefix BELI-), sama persis alurnya dengan create_fin_invoice tapi stok
    masuk (bukan keluar) dan tanpa HPP/laba. 'discount' di sini berarti DP
    yang sudah dibayar ke pemasok, mengurangi nilai hutang yang dicatat.
    ongkir_mode: "BEBAN" (kita bayar -- pengeluaran terpisah tertaut ke
    nota ini) atau "POTONGAN" (mereka bayar -- langsung mengurangi total).
    Raise ValueError(pesan) kalau validasi gagal.
    Return dict: {invoice_id, invoice_no, subtotal, discount, ongkir, ongkir_mode, total}.
    """
    from routes.mobile.finance import _update_stock_avco

    supplier_name = (supplier_name or "").strip() or "Pembelian Umum"
    if not items:
        raise ValueError("Minimal 1 item barang.")

    discount = float(discount or 0)
    ongkir = float(ongkir or 0)
    ongkir_mode = (ongkir_mode or "BEBAN").strip().upper()
    if ongkir_mode not in ("BEBAN", "POTONGAN"):
        ongkir_mode = "BEBAN"
    print_size = print_size if print_size in ("58mm", "80mm") else "80mm"
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_transaction_cancel_columns(cur)
        for item in items:
            mat_id = item.get("material_id")
            if not mat_id:
                raise ValueError("material_id wajib di setiap item.")
            cur.execute(
                "SELECT id, name FROM fin_materials WHERE id=%s AND is_active=TRUE;",
                (int(mat_id),)
            )
            if not cur.fetchone():
                raise ValueError(f"Barang dengan material_id={mat_id} tidak ditemukan di gudang.")

        subtotal_bruto = sum(float(i.get("qty", 0)) * float(i.get("price", 0)) for i in items)
        potongan_ongkir = ongkir if ongkir_mode == "POTONGAN" else 0.0
        grand_total = max(0.0, subtotal_bruto - discount - potongan_ongkir)

        cur.execute("""
            SELECT COUNT(*) AS cnt FROM fin_transactions
            WHERE created_at::date = CURRENT_DATE AND type = 'BELI_GUDANG';
        """)
        seq = (cur.fetchone()["cnt"] or 0) + 1
        invoice_no = f"BELI-{datetime.now().strftime('%Y%m%d')}-{seq:04d}"

        is_debt = not is_paid
        cur.execute("""
            INSERT INTO fin_transactions
                (type, party_name, party_type, note, is_debt, total_amount, created_by, print_size)
            VALUES ('BELI_GUDANG', %s, 'SUPPLIER', %s, %s, %s, %s, %s)
            RETURNING id;
        """, (
            supplier_name,
            f"[{invoice_no}] {payment_method}" + (f" | {notes}" if notes else ""),
            is_debt, grand_total, created_by, print_size
        ))
        txn_id = cur.fetchone()["id"]

        for item in items:
            mat_id = int(item["material_id"])
            qty = float(item.get("qty", 0))
            price = float(item.get("price", 0))
            subtotal = qty * price

            cur.execute("""
                INSERT INTO fin_transaction_items
                    (transaction_id, material_id, qty_kg, price_per_kg, subtotal)
                VALUES (%s, %s, %s, %s, %s);
            """, (txn_id, mat_id, qty, price, subtotal))

            _update_stock_avco(
                cur, mat_id, qty, price, 'IN', txn_id,
                note=f"Nota {invoice_no} — {supplier_name}"
            )

        if is_debt and supplier_name:
            cur.execute("""
                INSERT INTO fin_debts
                    (type, party_name, party_type, amount, remaining, transaction_id, note)
                VALUES ('HUTANG', %s, 'SUPPLIER', %s, %s, %s, %s);
            """, (supplier_name, grand_total, grand_total, txn_id,
                  f"Nota {invoice_no} — belum dibayar"))

        if ongkir > 0 and ongkir_mode == "BEBAN":
            _record_ongkir_expense(cur, txn_id, invoice_no, ongkir, created_by)

        conn.commit()

        return {
            "invoice_id": txn_id,
            "invoice_no": invoice_no,
            "subtotal": subtotal_bruto,
            "discount": discount,
            "ongkir": ongkir,
            "ongkir_mode": ongkir_mode,
            "total": grand_total,
        }
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal buat nota beli: {e}")
    finally:
        cur.close()
        conn.close()


def update_fin_invoice_transaction(txn_id, customer_name, customer_phone, payment_method,
                                    notes, discount, is_paid, items, edited_by,
                                    ongkir=0, ongkir_mode="BEBAN"):
    """
    Edit nota JUAL_INVOICE/BELI_GUDANG yang sudah ada: balikkan efek stok &
    hutang/piutang LAMA (pola sama dengan cancel_fin_transaction), lalu
    terapkan efek BARU dari item yang diedit (pola sama dengan
    create_fin_invoice/create_fin_purchase_invoice). invoice_no & jenis nota
    (JUAL/BELI) TIDAK berubah. Tidak bisa dipakai kalau hutang/piutangnya
    sudah ada cicilan/pembayaran, atau nota-nya sudah dihapus/dibatalkan.
    ongkir_mode: "BEBAN" (kita bayar) / "POTONGAN" (mereka bayar) -- lihat
    create_fin_invoice(). Expense Ongkir lama (kalau ada) dihapus dulu
    sebelum yang baru dibuat, supaya edit berulang tidak numpuk expense.
    Return dict {invoice_id, invoice_no, total}.
    """
    from routes.mobile.finance import _update_stock_avco, _reverse_stock_movement

    customer_name = (customer_name or "").strip()
    if not items:
        raise ValueError("Minimal 1 item barang.")

    discount = float(discount or 0)
    ongkir = float(ongkir or 0)
    ongkir_mode = (ongkir_mode or "BEBAN").strip().upper()
    if ongkir_mode not in ("BEBAN", "POTONGAN"):
        ongkir_mode = "BEBAN"

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_transaction_cancel_columns(cur)

        cur.execute("""
            SELECT id, type, note, cancelled_at
            FROM fin_transactions WHERE id = %s FOR UPDATE;
        """, (txn_id,))
        txn = cur.fetchone()
        if not txn:
            raise ValueError("Nota tidak ditemukan.")
        if txn["type"] not in ("JUAL_INVOICE", "BELI_GUDANG"):
            raise ValueError("Nota jenis ini tidak bisa diedit dari sini.")
        if txn["cancelled_at"] is not None:
            raise ValueError("Nota yang sudah dihapus tidak bisa diedit.")

        is_beli = txn["type"] == "BELI_GUDANG"
        if not customer_name:
            if is_beli:
                customer_name = "Pembelian Umum"
            else:
                raise ValueError("Nama customer wajib diisi.")

        invoice_no, _pm, _extra = _parse_nota_note(txn["note"])
        if not invoice_no:
            raise ValueError("Nomor nota tidak valid untuk diedit.")

        cur.execute("SELECT id, paid_amount FROM fin_debts WHERE transaction_id = %s;", (txn_id,))
        debt = cur.fetchone()
        if debt and float(debt["paid_amount"] or 0) > 0:
            raise ValueError(
                "Nota ini tidak bisa diedit karena hutang/piutangnya sudah "
                "ada cicilan/pembayaran. Batalkan pembayarannya dulu."
            )

        for item in items:
            mat_id = item.get("material_id")
            if not mat_id:
                raise ValueError("material_id wajib di setiap item.")
            cur.execute(
                "SELECT id, name FROM fin_materials WHERE id=%s AND is_active=TRUE;",
                (int(mat_id),)
            )
            if not cur.fetchone():
                raise ValueError(f"Barang dengan material_id={mat_id} tidak ditemukan di gudang.")

        # Balikkan stok dari item-item LAMA
        cur.execute("""
            SELECT material_id, qty_kg, price_per_kg
            FROM fin_transaction_items WHERE transaction_id = %s;
        """, (txn_id,))
        old_items = cur.fetchall()
        original_movement = 'IN' if is_beli else 'OUT'
        for it in old_items:
            _reverse_stock_movement(
                cur, it["material_id"], float(it["qty_kg"]), txn_id,
                original_movement, note=f"Edit nota {invoice_no} (versi lama)")

        cur.execute("DELETE FROM fin_transaction_items WHERE transaction_id = %s;", (txn_id,))

        # Untuk JUAL, cek stok cukup untuk item-item BARU (setelah reversal di atas)
        if not is_beli:
            for item in items:
                mat_id = int(item["material_id"])
                qty = float(item.get("qty", 0))
                cur.execute("""
                    SELECT COALESCE(s.qty_kg, 0) AS qty, m.name
                    FROM fin_materials m
                    LEFT JOIN fin_stock_summary s ON s.material_id = m.id
                    WHERE m.id=%s;
                """, (mat_id,))
                row = cur.fetchone()
                if not row or float(row["qty"]) < qty:
                    stok_ada = float(row["qty"]) if row else 0
                    raise ValueError(
                        f"Stok {row['name'] if row else mat_id} tidak cukup untuk perubahan ini. "
                        f"Tersedia: {stok_ada:.1f} kg, diminta: {qty:.1f} kg"
                    )

        subtotal_bruto = sum(float(i.get("qty", 0)) * float(i.get("price", 0)) for i in items)
        potongan_ongkir = ongkir if ongkir_mode == "POTONGAN" else 0.0
        grand_total = max(0.0, subtotal_bruto - discount - potongan_ongkir)

        for item in items:
            mat_id = int(item["material_id"])
            qty = float(item.get("qty", 0))
            price = float(item.get("price", 0))
            subtotal = qty * price

            cur.execute("""
                INSERT INTO fin_transaction_items
                    (transaction_id, material_id, qty_kg, price_per_kg, subtotal)
                VALUES (%s, %s, %s, %s, %s);
            """, (txn_id, mat_id, qty, price, subtotal))

            if is_beli:
                _update_stock_avco(
                    cur, mat_id, qty, price, 'IN', txn_id,
                    note=f"Edit nota {invoice_no} — {customer_name}")
            else:
                cur.execute(
                    "SELECT COALESCE(avg_cost_per_kg, 0) AS avg FROM fin_stock_summary WHERE material_id=%s;",
                    (mat_id,))
                avg_row = cur.fetchone()
                avg = float(avg_row["avg"]) if avg_row else 0
                _update_stock_avco(
                    cur, mat_id, qty, avg, 'OUT', txn_id,
                    note=f"Edit nota {invoice_no} — {customer_name}")

        is_debt = not is_paid
        new_note = f"[{invoice_no}] {payment_method}" + (f" | {notes}" if notes else "")
        cur.execute("""
            UPDATE fin_transactions
            SET party_name = %s, note = %s, is_debt = %s, total_amount = %s
            WHERE id = %s;
        """, (customer_name, new_note, is_debt, grand_total, txn_id))

        cur.execute("DELETE FROM fin_debts WHERE transaction_id = %s;", (txn_id,))
        if is_debt and customer_name:
            debt_type = 'HUTANG' if is_beli else 'PIUTANG'
            party_type = 'SUPPLIER' if is_beli else 'PELANGGAN'
            cur.execute("""
                INSERT INTO fin_debts
                    (type, party_name, party_type, amount, remaining, transaction_id, note)
                VALUES (%s, %s, %s, %s, %s, %s, %s);
            """, (debt_type, customer_name, party_type, grand_total, grand_total, txn_id,
                  f"Nota {invoice_no} — belum dibayar (hasil edit)"))

        cur.execute("""
            DELETE FROM fin_transactions
            WHERE related_transaction_id = %s AND type = 'PENGELUARAN' AND party_name = 'Ongkir';
        """, (txn_id,))
        if ongkir > 0 and ongkir_mode == "BEBAN":
            _record_ongkir_expense(cur, txn_id, invoice_no, ongkir, edited_by)

        conn.commit()
        return {"invoice_id": txn_id, "invoice_no": invoice_no, "total": grand_total}
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal edit nota: {e}")
    finally:
        cur.close()
        conn.close()


def get_fin_invoice_detail(txn_id):
    """
    Ambil 1 nota (fin_transactions, JUAL_INVOICE atau BELI_GUDANG) beserta
    items-nya, dibentuk dengan field-name yang sama dipakai
    templates/invoice_print.html & invoice_pdf.html (invoice_no,
    customer_name, created_by_name, payment_method, subtotal, discount,
    grand_total, notes, print_size, is_paid, company_name, logo_data_uri,
    nota_type). Return (invoice_dict, items) atau (None, []) kalau tidak ada.
    """
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_transaction_cancel_columns(cur)
        conn.commit()

        cur.execute("""
            SELECT t.id, t.type, t.note, t.party_name AS customer_name, t.is_debt,
                   t.total_amount, t.created_at, t.print_size, t.cancelled_at,
                   u.name AS created_by_name
            FROM fin_transactions t
            LEFT JOIN users u ON u.id = t.created_by
            WHERE t.id = %s AND t.type IN ('JUAL_INVOICE', 'BELI_GUDANG');
        """, (txn_id,))
        row = cur.fetchone()
        if not row:
            return None, []

        invoice_no, payment_method, extra_notes = _parse_nota_note(row.get("note"))

        cur.execute("""
            SELECT ti.material_id, m.name AS product_name, m.unit, ti.qty_kg AS qty,
                   ti.price_per_kg AS price, ti.subtotal
            FROM fin_transaction_items ti
            LEFT JOIN fin_materials m ON m.id = ti.material_id
            WHERE ti.transaction_id = %s
            ORDER BY ti.id ASC;
        """, (txn_id,))
        items = [{
            "material_id": r.get("material_id"),
            "product_name": r.get("product_name") or "-",
            "unit": r.get("unit") or "",
            "qty": float(r["qty"] or 0),
            "price": int(r["price"] or 0),
            "subtotal": float(r["subtotal"] or 0),
        } for r in cur.fetchall()]

        items_subtotal = sum(it["subtotal"] for it in items)
        grand_total = float(row.get("total_amount") or 0)
        profile = get_company_profile()
        nota_type = "BELI" if row.get("type") == "BELI_GUDANG" else "JUAL"

        invoice = {
            "id": row["id"],
            "nota_type": nota_type,
            "invoice_no": invoice_no or f"NOTA-{row['id']}",
            "customer_name": row.get("customer_name") or "",
            "customer_phone": "",
            "created_by_name": row.get("created_by_name"),
            "payment_method": payment_method,
            "subtotal": items_subtotal,
            "discount": max(0.0, items_subtotal - grand_total),
            "grand_total": grand_total,
            "notes": extra_notes,
            "print_size": row.get("print_size") or "80mm",
            "is_paid": not bool(row.get("is_debt")),
            "cancelled_at": row.get("cancelled_at"),
            "paid_at_wib": None,
            "created_at": row.get("created_at"),
            "created_at_wib": _utc_naive_to_wib_string(row.get("created_at")),
            "company_name": profile.get("company_name") or "",
            "logo_data_uri": profile.get("logo_data_uri") or "",
            "company_logo_path": None,
        }
        return invoice, items
    finally:
        cur.close()
        conn.close()


_NOTA_NO_RE = re.compile(r"((?:INV|BELI)-\d{8}-\d{4})")


def _parse_nota_note(note):
    note = (note or "").strip()
    m = _NOTA_NO_RE.search(note)
    if not m:
        return None, "CASH", ""
    invoice_no = m.group(1)
    rest = note[m.end():].strip().lstrip("]").lstrip("-").strip()
    if "|" in rest:
        pm, extra = rest.split("|", 1)
        return invoice_no, (pm.strip() or "CASH"), extra.strip()
    return invoice_no, (rest or "CASH"), ""


def get_invoice_history(q="", type_f="", status_f="", date_from="", date_to="",
                         limit=100, offset=0):
    """
    Ambil riwayat nota dari fin_transactions (JUAL_INVOICE/BELI_GUDANG).
    Diextract dari routes/mobile/invoice.py:mobile_invoice_history() agar
    web & mobile berbagi 1 sumber kebenaran. Return (invoices, total).
    """
    limit = min(int(limit or 100), 500)
    offset = int(offset or 0)

    conditions = [
        "t.type IN ('JUAL_INVOICE', 'BELI_GUDANG')",
        r"t.note ~ '(INV|BELI)-[0-9]{8}-[0-9]{4}'",
        "t.cancelled_at IS NULL",
    ]
    params = []

    if q:
        conditions.append("(t.note ILIKE %s OR t.party_name ILIKE %s OR u.name ILIKE %s)")
        like = f"%{q}%"
        params += [like, like, like]

    if type_f == "JUAL":
        conditions.append("t.type = 'JUAL_INVOICE'")
    elif type_f == "BELI":
        conditions.append("t.type = 'BELI_GUDANG'")

    if status_f == "LUNAS":
        conditions.append("t.is_debt = FALSE")
    elif status_f == "BELUM":
        conditions.append("t.is_debt = TRUE")

    if date_from:
        conditions.append("t.created_at >= %s::date")
        params.append(date_from)
    if date_to:
        conditions.append("t.created_at < (%s::date + INTERVAL '1 day')")
        params.append(date_to)

    where = "WHERE " + " AND ".join(conditions)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_transaction_cancel_columns(cur)
        conn.commit()

        cur.execute(f"""
            SELECT COUNT(*) AS cnt
            FROM fin_transactions t
            LEFT JOIN users u ON u.id = t.created_by
            {where};
        """, params)
        total = (cur.fetchone() or {}).get("cnt", 0)

        cur.execute(f"""
            SELECT
                t.id, t.type, t.note, t.party_name AS customer_name, t.is_debt,
                t.total_amount, t.created_at, u.name AS created_by_name,
                TO_CHAR(t.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Jakarta',
                        'YYYY-MM-DD HH24:MI:SS') AS created_at_wib
            FROM fin_transactions t
            LEFT JOIN users u ON u.id = t.created_by
            {where}
            ORDER BY t.created_at DESC
            LIMIT %s OFFSET %s;
        """, params + [limit, offset])
        rows = cur.fetchall()

        invoices = []
        for r in rows:
            invoice_no, payment_method, extra_notes = _parse_nota_note(r.get("note"))
            invoices.append({
                "id": r["id"],
                "_type": r["type"],
                "invoice_no": invoice_no or f"NOTA-{r['id']}",
                "customer_name": r.get("customer_name") or "",
                "payment_method": payment_method,
                "grand_total": float(r.get("total_amount") or 0),
                "is_paid": not bool(r.get("is_debt")),
                "notes": extra_notes,
                "created_at": r.get("created_at"),
                "created_at_wib": r.get("created_at_wib"),
                "created_by_name": r.get("created_by_name"),
            })

        items_map = defaultdict(list)
        if invoices:
            inv_ids = [inv["id"] for inv in invoices]
            cur.execute("""
                SELECT ti.transaction_id AS invoice_id, ti.id, ti.material_id AS product_id,
                       m.name AS product_name, ti.qty_kg AS qty,
                       ti.price_per_kg AS price, ti.subtotal
                FROM fin_transaction_items ti
                LEFT JOIN fin_materials m ON m.id = ti.material_id
                WHERE ti.transaction_id = ANY(%s)
                ORDER BY ti.transaction_id ASC, ti.id ASC;
            """, (inv_ids,))
            for item in cur.fetchall():
                items_map[item["invoice_id"]].append({
                    "id": item["id"],
                    "product_id": item["product_id"],
                    "product_name": item.get("product_name") or "-",
                    "qty": float(item["qty"] or 0),
                    "price": int(item["price"] or 0),
                    "subtotal": float(item["subtotal"] or 0),
                })

        for inv in invoices:
            items = items_map.get(inv["id"], [])
            inv["items"] = items
            items_subtotal = sum(it["subtotal"] for it in items)
            inv["subtotal"] = items_subtotal
            inv["discount"] = max(0.0, items_subtotal - inv["grand_total"])
            del inv["_type"]

        return invoices, int(total)
    finally:
        cur.close()
        conn.close()


def cancel_fin_transaction(txn_id, cancelled_by):
    """
    Batalkan nota Jual/Beli: balikkan stok & HPP gudang, hapus hutang/piutang
    terkait (kalau belum ada cicilan), tandai cancelled_at. Diextract dari
    routes/mobile/finance.py:cancel_nota_transaction(). Raise ValueError kalau
    tidak bisa dibatalkan.
    """
    from routes.mobile.finance import _reverse_stock_movement

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_transaction_cancel_columns(cur)

        cur.execute("""
            SELECT id, type, party_name, is_debt, total_amount, cancelled_at
            FROM fin_transactions WHERE id = %s FOR UPDATE;
        """, (txn_id,))
        txn = cur.fetchone()
        if not txn:
            raise ValueError("Nota tidak ditemukan.")
        if txn["type"] not in ("JUAL_INVOICE", "BELI_GUDANG"):
            raise ValueError("Nota jenis ini tidak bisa dibatalkan dari sini.")
        if txn["cancelled_at"] is not None:
            raise ValueError("Nota ini sudah pernah dibatalkan.")

        cur.execute("SELECT id, paid_amount FROM fin_debts WHERE transaction_id = %s;", (txn_id,))
        debt = cur.fetchone()
        if debt and float(debt["paid_amount"] or 0) > 0:
            raise ValueError(
                "Nota ini tidak bisa dibatalkan karena hutang/piutangnya "
                "sudah memiliki cicilan/pembayaran. Batalkan pembayarannya dulu."
            )

        cur.execute("""
            SELECT material_id, qty_kg, price_per_kg
            FROM fin_transaction_items WHERE transaction_id = %s;
        """, (txn_id,))
        original_movement = 'IN' if txn["type"] == 'BELI_GUDANG' else 'OUT'
        for it in cur.fetchall():
            _reverse_stock_movement(
                cur, it["material_id"], float(it["qty_kg"]), txn_id,
                original_movement, note=f"Pembatalan nota #{txn_id}")

        if debt:
            cur.execute("DELETE FROM fin_debts WHERE id = %s;", (debt["id"],))

        cur.execute("""
            UPDATE fin_transactions
            SET cancelled_at = NOW(), cancelled_by = %s
            WHERE id = %s;
        """, (cancelled_by, txn_id))

        conn.commit()
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal membatalkan nota: {e}")
    finally:
        cur.close()
        conn.close()


def create_fin_return(transaction_id, material_id, qty, reason, note, created_by):
    """
    Catat "barang balik" (retur sebagian) dari sebuah nota yang sudah jadi --
    nota ASLI (nomor, total yang sudah dicetak) TIDAK berubah. Retur jadi
    transaksi terpisah yang tertaut ke nota asal, menyesuaikan stok/HPP
    gudang & sisa hutang-piutang nota tsb.

    Arah stok mengikuti jenis nota:
    - BELI_GUDANG (kita beli, retur balik ke pemasok) -> stok TURUN.
    - JUAL_INVOICE (customer balikin ke kita)          -> stok NAIK.
    Dihitung lewat _reverse_stock_movement dengan avg cost SAAT INI (bukan
    harga historis -- fin_transaction_items tidak menyimpan HPP per-item
    di masa lalu, jadi ini pilihan paling aman/konsisten).

    Nilai retur (utk penyesuaian hutang/piutang) pakai price_per_kg ASLI
    di nota tsb, bukan avg cost sekarang. Kalau nota sudah lunas penuh
    (atau retur melebihi sisa hutang/piutang), kelebihannya dilaporkan
    sbg "perlu refund tunai" -- tidak dicatat otomatis, ditangani admin
    di luar sistem.

    Return dict {qty, value, refund_needed}.
    """
    from routes.mobile.finance import _reverse_stock_movement

    try:
        qty = float(qty or 0)
    except (TypeError, ValueError):
        qty = 0
    reason = (reason or "").strip()
    note = (note or "").strip()

    if qty <= 0:
        raise ValueError("Jumlah retur harus lebih dari 0.")
    if not reason:
        raise ValueError("Alasan retur wajib diisi.")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_transaction_cancel_columns(cur)
        _ensure_fin_returns_schema(cur)

        cur.execute("""
            SELECT id, type, note, cancelled_at
            FROM fin_transactions WHERE id = %s FOR UPDATE;
        """, (transaction_id,))
        txn = cur.fetchone()
        if not txn:
            raise ValueError("Nota tidak ditemukan.")
        if txn["type"] not in ("JUAL_INVOICE", "BELI_GUDANG"):
            raise ValueError("Nota jenis ini tidak bisa diretur dari sini.")
        if txn["cancelled_at"] is not None:
            raise ValueError("Nota yang sudah dihapus tidak bisa diretur.")

        is_beli = txn["type"] == "BELI_GUDANG"
        invoice_no, _pm, _extra = _parse_nota_note(txn["note"])

        cur.execute("""
            SELECT qty_kg, price_per_kg FROM fin_transaction_items
            WHERE transaction_id = %s AND material_id = %s;
        """, (transaction_id, material_id))
        item = cur.fetchone()
        if not item:
            raise ValueError("Barang ini tidak ada di nota tersebut.")
        original_qty = float(item["qty_kg"])
        price_per_kg = float(item["price_per_kg"])

        cur.execute("""
            SELECT COALESCE(SUM(qty_kg), 0) AS total
            FROM fin_returns WHERE transaction_id = %s AND material_id = %s;
        """, (transaction_id, material_id))
        already_returned = float(cur.fetchone()["total"])

        if already_returned + qty > original_qty:
            sisa = max(0, original_qty - already_returned)
            raise ValueError(
                f"Jumlah retur melebihi qty di nota ini. "
                f"Sudah diretur sebelumnya: {already_returned:.1f}, sisa yang bisa diretur: {sisa:.1f}")

        original_movement = 'IN' if is_beli else 'OUT'
        _reverse_stock_movement(
            cur, material_id, qty, transaction_id, original_movement,
            note=f"Retur nota {invoice_no or transaction_id}: {reason}")

        value = qty * price_per_kg

        cur.execute("SELECT id, remaining FROM fin_debts WHERE transaction_id = %s;", (transaction_id,))
        debt = cur.fetchone()
        refund_needed = 0.0
        if debt:
            remaining = float(debt["remaining"])
            reduction = min(value, remaining)
            new_remaining = max(0.0, remaining - reduction)
            cur.execute("""
                UPDATE fin_debts
                SET amount = GREATEST(0, amount - %s),
                    remaining = %s,
                    is_settled = %s
                WHERE id = %s;
            """, (reduction, new_remaining, new_remaining <= 0, debt["id"]))
            refund_needed = value - reduction
        else:
            refund_needed = value

        cur.execute("""
            INSERT INTO fin_returns
                (transaction_id, material_id, qty_kg, price_per_kg, value, reason, note, created_by)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s);
        """, (transaction_id, material_id, qty, price_per_kg, value, reason, note or None, created_by))

        conn.commit()
        return {"qty": qty, "value": value, "refund_needed": refund_needed}
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal mencatat retur: {e}")
    finally:
        cur.close()
        conn.close()


def list_fin_returns(transaction_id):
    """Riwayat retur (barang balik) untuk 1 nota, terbaru duluan."""
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_fin_returns_schema(cur)
        conn.commit()
        cur.execute("""
            SELECT r.id, r.material_id, m.name AS material_name, m.unit,
                   r.qty_kg, r.price_per_kg, r.value, r.reason, r.note,
                   TO_CHAR(r.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Jakarta',
                           'YYYY-MM-DD HH24:MI:SS') AS created_at_wib,
                   u.name AS created_by_name
            FROM fin_returns r
            JOIN fin_materials m ON m.id = r.material_id
            LEFT JOIN users u ON u.id = r.created_by
            WHERE r.transaction_id = %s
            ORDER BY r.created_at DESC;
        """, (transaction_id,))
        return [dict(r) for r in cur.fetchall()]
    finally:
        cur.close()
        conn.close()


def delete_nota_transaction(txn_id, mode, reason, deleted_by):
    """
    Hapus nota dari Riwayat Nota (soft-delete — nota TIDAK benar-benar
    hilang dari database, hanya disembunyikan dari get_invoice_history()
    lewat kolom cancelled_at yang sudah dipakai bersama).

    mode:
      - "REVERSE": kembalikan stok & hutang/piutang (delegasi penuh ke
        cancel_fin_transaction, termasuk validasi & guard-nya).
      - "KEEP": hapus dari riwayat saja, stok & fin_debts TIDAK disentuh.

    Nota yang sudah dihapus tetap terlihat lewat list_deleted_nota()
    (halaman arsip khusus owner) sampai dihapus permanen lewat
    purge_fin_transaction().
    """
    mode = (mode or "").strip().upper()
    if mode not in ("REVERSE", "KEEP"):
        raise ValueError("Mode hapus tidak valid.")
    reason = (reason or "").strip()
    if not reason:
        raise ValueError("Alasan penghapusan wajib diisi.")

    if mode == "REVERSE":
        cancel_fin_transaction(txn_id, deleted_by)
    else:
        conn = get_conn()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        try:
            _ensure_transaction_cancel_columns(cur)
            cur.execute("""
                SELECT id, type, cancelled_at
                FROM fin_transactions WHERE id = %s FOR UPDATE;
            """, (txn_id,))
            txn = cur.fetchone()
            if not txn:
                raise ValueError("Nota tidak ditemukan.")
            if txn["type"] not in ("JUAL_INVOICE", "BELI_GUDANG"):
                raise ValueError("Nota jenis ini tidak bisa dihapus dari sini.")
            if txn["cancelled_at"] is not None:
                raise ValueError("Nota ini sudah pernah dihapus/dibatalkan.")

            cur.execute("""
                UPDATE fin_transactions
                SET cancelled_at = NOW(), cancelled_by = %s
                WHERE id = %s;
            """, (deleted_by, txn_id))
            conn.commit()
        except ValueError:
            conn.rollback()
            raise
        except Exception as e:
            conn.rollback()
            raise ValueError(f"Gagal menghapus nota: {e}")
        finally:
            cur.close()
            conn.close()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            UPDATE fin_transactions SET delete_reason = %s, delete_mode = %s WHERE id = %s;
        """, (reason, mode, txn_id))
        conn.commit()
    finally:
        cur.close()
        conn.close()


def list_deleted_nota():
    """Daftar nota yang sudah dihapus/dibatalkan — arsip khusus owner."""
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_transaction_cancel_columns(cur)
        conn.commit()
        cur.execute("""
            SELECT
                t.id, t.type, t.note, t.party_name, t.total_amount,
                t.delete_reason, t.delete_mode, t.cancelled_at,
                TO_CHAR(t.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Jakarta',
                        'YYYY-MM-DD HH24:MI:SS') AS created_at_wib,
                u.name AS cancelled_by_name,
                TO_CHAR(t.cancelled_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Jakarta',
                        'YYYY-MM-DD HH24:MI:SS') AS cancelled_at_wib
            FROM fin_transactions t
            LEFT JOIN users u ON u.id = t.cancelled_by
            WHERE t.type IN ('JUAL_INVOICE', 'BELI_GUDANG')
              AND t.cancelled_at IS NOT NULL
            ORDER BY t.cancelled_at DESC;
        """)
        rows = [dict(r) for r in cur.fetchall()]
        for r in rows:
            invoice_no, payment_method, _extra = _parse_nota_note(r.get("note"))
            r["invoice_no"] = invoice_no
            r["payment_method"] = payment_method
            r["grand_total"] = float(r.get("total_amount") or 0)
        return rows
    finally:
        cur.close()
        conn.close()


def purge_fin_transaction(txn_id):
    """
    Hapus PERMANEN sebuah nota dari database. Nota harus sudah di-soft-delete
    (cancelled_at terisi) lebih dulu lewat delete_nota_transaction(). Aksi ini
    tidak bisa dibatalkan — hanya dipanggil dari alur khusus owner.
    Urutan delete mengikuti pola delete_fin_material(): fin_stock_ledger →
    fin_transaction_items → fin_debts → fin_transactions.
    """
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT id, cancelled_at FROM fin_transactions WHERE id = %s;", (txn_id,))
        txn = cur.fetchone()
        if not txn:
            raise ValueError("Nota tidak ditemukan.")
        if txn["cancelled_at"] is None:
            raise ValueError("Nota harus dihapus dari riwayat dulu sebelum dihapus permanen.")

        cur.execute("DELETE FROM fin_stock_ledger WHERE transaction_id = %s;", (txn_id,))
        cur.execute("DELETE FROM fin_transaction_items WHERE transaction_id = %s;", (txn_id,))
        cur.execute("DELETE FROM fin_debts WHERE transaction_id = %s;", (txn_id,))
        cur.execute("DELETE FROM fin_transactions WHERE id = %s;", (txn_id,))
        conn.commit()
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal menghapus permanen: {e}")
    finally:
        cur.close()
        conn.close()


def _ensure_nota_drafts_schema(cur):
    """Lazy-migration: tabel draft nota (bisa banyak per user, dipakai
    supaya pembuatan nota tidak hilang kalau accidental-exit)."""
    cur.execute("""
        CREATE TABLE IF NOT EXISTS nota_drafts (
            id SERIAL PRIMARY KEY,
            created_by INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            nota_type VARCHAR(10) NOT NULL DEFAULT 'JUAL',
            draft_name VARCHAR(120),
            form_data JSONB NOT NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
    """)


def list_nota_drafts(user_id):
    """Daftar draft nota milik satu user, terbaru duluan."""
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_nota_drafts_schema(cur)
        conn.commit()
        cur.execute("""
            SELECT id, nota_type, draft_name, form_data,
                   TO_CHAR(updated_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Jakarta',
                           'YYYY-MM-DD HH24:MI:SS') AS updated_at_wib
            FROM nota_drafts
            WHERE created_by = %s
            ORDER BY updated_at DESC;
        """, (user_id,))
        return [dict(r) for r in cur.fetchall()]
    finally:
        cur.close()
        conn.close()


def save_nota_draft(user_id, nota_type, draft_name, form_data):
    """
    Simpan draft BARU (selalu insert, bukan update, supaya bisa banyak
    draft sekaligus). Kalau draft_name kosong, auto-generate dari nama
    customer/pemasok di form_data + waktu WIB. Draft user yang sama di
    luar 30 draft terbaru otomatis dibuang supaya tabel tidak membengkak.
    Return dict draft yang baru disimpan.
    """
    nota_type = (nota_type or "JUAL").strip().upper()
    if nota_type not in ("JUAL", "BELI"):
        nota_type = "JUAL"

    draft_name = (draft_name or "").strip()
    if not draft_name:
        who = (form_data or {}).get("customer_name") or "Draft"
        draft_name = f"{who} — {_now_wib_naive().strftime('%d/%m %H:%M')}"

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_nota_drafts_schema(cur)
        cur.execute("""
            INSERT INTO nota_drafts (created_by, nota_type, draft_name, form_data)
            VALUES (%s, %s, %s, %s)
            RETURNING id, nota_type, draft_name, form_data,
                      TO_CHAR(updated_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Jakarta',
                              'YYYY-MM-DD HH24:MI:SS') AS updated_at_wib;
        """, (user_id, nota_type, draft_name, Json(form_data or {})))
        draft = dict(cur.fetchone())

        cur.execute("""
            DELETE FROM nota_drafts
            WHERE created_by = %s
              AND id NOT IN (
                  SELECT id FROM nota_drafts
                  WHERE created_by = %s
                  ORDER BY updated_at DESC
                  LIMIT 30
              );
        """, (user_id, user_id))

        conn.commit()
        return draft
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal menyimpan draft: {e}")
    finally:
        cur.close()
        conn.close()


def delete_nota_draft(draft_id, user_id):
    """Hapus 1 draft milik user tsb. Raise ValueError kalau tidak ketemu/bukan miliknya."""
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            DELETE FROM nota_drafts WHERE id = %s AND created_by = %s RETURNING id;
        """, (draft_id, user_id))
        if not cur.fetchone():
            raise ValueError("Draft tidak ditemukan.")
        conn.commit()
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal menghapus draft: {e}")
    finally:
        cur.close()
        conn.close()


def settle_fin_debt_for_transaction(cur, txn_id):
    """Tandai nota lunas: set is_debt=FALSE di fin_transactions & lunasi fin_debts terkait."""
    cur.execute("UPDATE fin_transactions SET is_debt=FALSE WHERE id=%s RETURNING id;", (txn_id,))
    if not cur.fetchone():
        raise ValueError("Nota tidak ditemukan.")
    cur.execute("SELECT id, amount FROM fin_debts WHERE transaction_id=%s;", (txn_id,))
    debt = cur.fetchone()
    if debt:
        cur.execute("""
            UPDATE fin_debts
            SET paid_amount = amount, remaining = 0, is_settled = TRUE
            WHERE id = %s;
        """, (debt["id"],))


# =========================
# DASHBOARD / POINTS HELPERS
# =========================
def ensure_points_schema():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            ALTER TABLE users
            ADD COLUMN IF NOT EXISTS points INTEGER NOT NULL DEFAULT 0;
        """)
        cur.execute("""
            ALTER TABLE users
            ADD COLUMN IF NOT EXISTS points_admin INTEGER NOT NULL DEFAULT 0;
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS points_logs (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                admin_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                delta INTEGER NOT NULL,
                note TEXT,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()


def get_notif_count():
    if not session.get("user_id"):
        return 0

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT COUNT(*) AS total
            FROM announcements a
            LEFT JOIN announcement_reads ar
              ON ar.announcement_id = a.id
             AND ar.user_id = %s
            WHERE a.is_active = TRUE
              AND ar.announcement_id IS NULL;
        """, (session.get("user_id"),))
        row = cur.fetchone() or {}
        return int(row.get("total") or 0)
    finally:
        cur.close()
        conn.close()

def ensure_mobile_device_tokens_schema():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS mobile_device_tokens (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                fcm_token TEXT NOT NULL UNIQUE,
                platform VARCHAR(20) NOT NULL DEFAULT 'android',
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_mobile_device_tokens_user_id
            ON mobile_device_tokens(user_id);
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()

def _get_firebase_access_token():
    import json as _json

    sa_env = (os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON") or "").strip()

    if sa_env:
        # Env var berisi JSON string langsung — parse dulu jangan dibuka sebagai file
        try:
            sa_info = _json.loads(sa_env)
        except Exception as e:
            raise RuntimeError(f"FIREBASE_SERVICE_ACCOUNT_JSON bukan JSON valid: {e}")

        creds = service_account.Credentials.from_service_account_info(
            sa_info,
            scopes=["https://www.googleapis.com/auth/firebase.messaging"],
        )
    else:
        # Fallback: baca dari path file
        sa_path = (os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH") or "").strip()
        if not sa_path:
            raise RuntimeError(
                "FIREBASE_SERVICE_ACCOUNT_JSON atau FIREBASE_SERVICE_ACCOUNT_PATH belum diisi")
        creds = service_account.Credentials.from_service_account_file(
            sa_path,
            scopes=["https://www.googleapis.com/auth/firebase.messaging"],
        )

    creds.refresh(GoogleAuthRequest())
    return creds.token

def _deactivate_token(token: str):
    """Nonaktifkan FCM token yang sudah tidak terdaftar."""
    try:
        conn = get_conn()
        cur  = conn.cursor()
        cur.execute("""
            UPDATE mobile_device_tokens
            SET is_active = FALSE
            WHERE fcm_token = %s;
        """, (token,))
        conn.commit()
        cur.close()
        conn.close()
        print(f"[FCM] Token dinonaktifkan: ...{token[-10:]}")
    except Exception as e:
        print(f"[FCM] Gagal nonaktifkan token: {e}")


def send_fcm_to_tokens(tokens, title, body, data=None):
    if not tokens:
        return {"ok": True, "sent": 0}

    project_id = (os.getenv("FIREBASE_PROJECT_ID") or "").strip()
    if not project_id:
        raise RuntimeError("FIREBASE_PROJECT_ID belum diisi")

    access_token = _get_firebase_access_token()
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"

    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    sent = 0
    failed = 0

    for token in tokens:
        payload = {
            "message": {
                "token": token,
                "notification": {
                    "title": title,
                    "body": body,
                },
                "data": {k: str(v) for k, v in (data or {}).items()},
                "android": {
                    "priority": "high",
                    "notification": {
                        "channel_id": "umgap_main_channel",
                        "sound": "default",
                    }
                }
            }
        }

        try:
            resp = requests.post(url, headers=headers,
                     json=payload, timeout=15)
            if 200 <= resp.status_code < 300:
                sent += 1
            else:
                failed += 1
                # Auto-hapus token yang sudah tidak valid
                if resp.status_code == 404:
                    try:
                        err = resp.json()
                        err_code = (err.get("error", {})
                                       .get("details", [{}])[0]
                                       .get("errorCode", ""))
                        if err_code == "UNREGISTERED":
                            _deactivate_token(token)
                    except Exception:
                        pass
        except Exception:
            failed += 1

    return {"ok": True, "sent": sent, "failed": failed}

def get_admin_fcm_tokens():
    ensure_mobile_device_tokens_schema()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT DISTINCT d.fcm_token
            FROM mobile_device_tokens d
            JOIN users u ON u.id = d.user_id
            WHERE d.is_active = TRUE
              AND u.role = 'admin'
              AND COALESCE(d.fcm_token, '') <> '';
        """)
        rows = cur.fetchall()
        return [r["fcm_token"] for r in rows if r.get("fcm_token")]
    finally:
        cur.close()
        conn.close()


# =========================
# FINANCE — KASIR / STOK / HUTANG-PIUTANG (dipakai bersama web & mobile)
# Diextract dari routes/mobile/finance.py supaya web (routes/web/finance.py)
# & mobile (routes/mobile/finance.py) berbagi 1 sumber kebenaran, sama
# seperti pola create_fin_invoice/cancel_fin_transaction di atas.
# Semua fungsi raise ValueError(pesan) kalau validasi gagal — caller di
# layer route yang menerjemahkan ke response (400/flash message).
# =========================

def list_fin_materials():
    """Daftar barang gudang aktif + stok saat ini. Return (rows, total_value)."""
    from routes.mobile.finance import _clean
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                m.id, m.name, m.unit, m.sort_order,
                COALESCE(s.qty_kg, 0)          AS qty_kg,
                COALESCE(s.avg_cost_per_kg, 0) AS avg_cost_per_kg,
                COALESCE(s.total_value, 0)     AS total_value,
                s.updated_at
            FROM fin_materials m
            LEFT JOIN fin_stock_summary s ON s.material_id = m.id
            WHERE m.is_active = TRUE
            ORDER BY m.sort_order, m.name;
        """)
        rows = _clean([dict(r) for r in cur.fetchall()])
        total_value = sum(float(r['total_value'] or 0) for r in rows)
        return rows, total_value
    finally:
        cur.close()
        conn.close()


def add_fin_material(name, unit, init_qty, init_price, note, created_by):
    """Tambah barang baru ke fin_materials, opsional stok awal via AVCO."""
    name = (name or "").strip()
    unit = (unit or "kg").strip() or "kg"
    init_qty = float(init_qty or 0)
    init_price = int(init_price or 0)
    note = (note or "").strip()

    if not name:
        raise ValueError("Nama barang wajib diisi.")
    if init_qty > 0 and init_price <= 0:
        raise ValueError("Harga beli wajib diisi jika ada stok awal.")

    from routes.mobile.finance import _update_stock_avco

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute(
            "SELECT id FROM fin_materials WHERE LOWER(name)=LOWER(%s) AND is_active=TRUE;",
            (name,))
        if cur.fetchone():
            raise ValueError(f"Barang '{name}' sudah ada di gudang.")

        cur.execute("SELECT COALESCE(MAX(sort_order),0)+1 AS nxt FROM fin_materials;")
        sort_order = cur.fetchone()["nxt"]

        cur.execute("""
            INSERT INTO fin_materials (name, unit, sort_order, is_active)
            VALUES (%s, %s, %s, TRUE)
            RETURNING id;
        """, (name, unit, sort_order))
        material_id = cur.fetchone()["id"]

        cur.execute("""
            INSERT INTO fin_stock_summary
                (material_id, qty_kg, avg_cost_per_kg, total_value, updated_at)
            VALUES (%s, 0, 0, 0, NOW())
            ON CONFLICT (material_id) DO NOTHING;
        """, (material_id,))

        if init_qty > 0:
            cur.execute("""
                INSERT INTO fin_transactions
                    (type, party_name, party_type, note, is_debt,
                     total_amount, created_by)
                VALUES ('BELI', 'Stok Awal', 'SUPPLIER', %s, FALSE, %s, %s)
                RETURNING id;
            """, (
                note or f"Stok awal {name}",
                init_qty * init_price,
                created_by,
            ))
            txn_id = cur.fetchone()["id"]

            cur.execute("""
                INSERT INTO fin_transaction_items
                    (transaction_id, material_id, qty_kg, price_per_kg, subtotal)
                VALUES (%s, %s, %s, %s, %s);
            """, (txn_id, material_id, init_qty, init_price, init_qty * init_price))

            _update_stock_avco(
                cur, material_id, init_qty, init_price, 'IN', txn_id,
                note=note or f"Stok awal {name}")

        conn.commit()
        return {"material_id": material_id, "name": name, "unit": unit, "init_qty": init_qty}
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal tambah barang: {e}")
    finally:
        cur.close()
        conn.close()


def add_fin_material_stock(material_id, qty, price, note, created_by):
    """
    Tambah stok untuk barang gudang yang SUDAH ADA — beda dari
    add_fin_material() yang cuma bisa isi stok awal saat barang baru
    dibuat. Dipakai untuk kasus barang sudah tercatat di fin_materials
    tapi qty_kg masih 0 (atau memang perlu ditambah stok tanpa lewat
    alur Nota/Kasir Beli formal ke pemasok). Insert transaksi 'BELI'
    (party_name='Penyesuaian Stok') + update stok AVCO arah IN.
    Raise ValueError kalau barang tidak ditemukan/nonaktif atau input
    tidak valid. Return dict {id, name, qty_kg, avg_cost_per_kg, total_value}.
    """
    try:
        qty = float(qty or 0)
    except (TypeError, ValueError):
        qty = 0
    try:
        price = float(price or 0)
    except (TypeError, ValueError):
        price = 0
    note = (note or "").strip()

    if qty <= 0:
        raise ValueError("Jumlah stok harus lebih dari 0.")
    if price <= 0:
        raise ValueError("Harga/biaya per satuan wajib diisi.")

    from routes.mobile.finance import _update_stock_avco

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute(
            "SELECT id, name FROM fin_materials WHERE id=%s AND is_active=TRUE;",
            (material_id,))
        mat = cur.fetchone()
        if not mat:
            raise ValueError("Barang tidak ditemukan.")

        cur.execute("""
            INSERT INTO fin_transactions
                (type, party_name, party_type, note, is_debt, total_amount, created_by)
            VALUES ('BELI', 'Penyesuaian Stok', 'SUPPLIER', %s, FALSE, %s, %s)
            RETURNING id;
        """, (
            note or f"Tambah stok {mat['name']}",
            qty * price,
            created_by,
        ))
        txn_id = cur.fetchone()["id"]

        cur.execute("""
            INSERT INTO fin_transaction_items
                (transaction_id, material_id, qty_kg, price_per_kg, subtotal)
            VALUES (%s, %s, %s, %s, %s);
        """, (txn_id, material_id, qty, price, qty * price))

        _update_stock_avco(
            cur, material_id, qty, price, 'IN', txn_id,
            note=note or f"Tambah stok {mat['name']}")

        conn.commit()

        cur.execute("""
            SELECT m.id, m.name,
                   COALESCE(s.qty_kg, 0)          AS qty_kg,
                   COALESCE(s.avg_cost_per_kg, 0)  AS avg_cost_per_kg,
                   COALESCE(s.total_value, 0)      AS total_value
            FROM fin_materials m
            LEFT JOIN fin_stock_summary s ON s.material_id = m.id
            WHERE m.id = %s;
        """, (material_id,))
        return dict(cur.fetchone())
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal tambah stok: {e}")
    finally:
        cur.close()
        conn.close()


def reduce_fin_material_stock(material_id, qty, reason, note, created_by):
    """
    Kurangi stok barang gudang karena kotor/susut/rusak (bukan lewat nota
    penjualan) — kebalikan dari add_fin_material_stock(). Dicatat sebagai
    pengeluaran (kerugian) di Finance sebesar nilai stok yang hilang
    (qty x HPP rata-rata saat ini). HPP rata-rata itu sendiri TIDAK berubah
    (sesuai perilaku AVCO untuk movement OUT — cuma qty & total nilai turun).
    Raise ValueError kalau barang tidak ditemukan, qty tidak valid, alasan
    kosong, atau qty melebihi stok yang tersedia.
    Return dict {id, name, qty_kg, avg_cost_per_kg, total_value}.
    """
    try:
        qty = float(qty or 0)
    except (TypeError, ValueError):
        qty = 0
    reason = (reason or "").strip()
    note = (note or "").strip()

    if qty <= 0:
        raise ValueError("Jumlah pengurangan harus lebih dari 0.")
    if not reason:
        raise ValueError("Alasan pengurangan wajib diisi.")

    from routes.mobile.finance import _update_stock_avco

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute(
            "SELECT id, name FROM fin_materials WHERE id=%s AND is_active=TRUE;",
            (material_id,))
        mat = cur.fetchone()
        if not mat:
            raise ValueError("Barang tidak ditemukan.")

        cur.execute("""
            SELECT COALESCE(qty_kg, 0) AS qty, COALESCE(avg_cost_per_kg, 0) AS avg
            FROM fin_stock_summary WHERE material_id = %s FOR UPDATE;
        """, (material_id,))
        stock = cur.fetchone()
        current_qty = float(stock["qty"]) if stock else 0.0
        avg_cost = float(stock["avg"]) if stock else 0.0

        if qty > current_qty:
            raise ValueError(
                f"Jumlah melebihi stok tersedia. Tersedia: {current_qty:.1f} kg, diminta: {qty:.1f} kg")

        loss_value = qty * avg_cost
        full_note = reason + (f" — {note}" if note else "")

        cur.execute("""
            INSERT INTO fin_transactions
                (type, party_name, note, is_debt, total_amount, created_by)
            VALUES ('PENGELUARAN', 'Penyesuaian Stok', %s, FALSE, %s, %s)
            RETURNING id;
        """, (
            f"Pengurangan stok {mat['name']}: {full_note}",
            loss_value,
            created_by,
        ))
        txn_id = cur.fetchone()["id"]

        cur.execute("""
            INSERT INTO fin_transaction_items
                (transaction_id, material_id, qty_kg, price_per_kg, subtotal)
            VALUES (%s, %s, %s, %s, %s);
        """, (txn_id, material_id, qty, avg_cost, loss_value))

        _update_stock_avco(
            cur, material_id, qty, avg_cost, 'OUT', txn_id, note=full_note)

        conn.commit()

        cur.execute("""
            SELECT m.id, m.name,
                   COALESCE(s.qty_kg, 0)          AS qty_kg,
                   COALESCE(s.avg_cost_per_kg, 0)  AS avg_cost_per_kg,
                   COALESCE(s.total_value, 0)      AS total_value
            FROM fin_materials m
            LEFT JOIN fin_stock_summary s ON s.material_id = m.id
            WHERE m.id = %s;
        """, (material_id,))
        return dict(cur.fetchone())
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal mengurangi stok: {e}")
    finally:
        cur.close()
        conn.close()


def edit_fin_material(material_id, name, unit):
    """Edit nama & satuan barang gudang."""
    name = (name or "").strip()
    unit = (unit or "kg").strip() or "kg"
    if not name:
        raise ValueError("Nama barang wajib diisi.")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute(
            "UPDATE fin_materials SET name = %s, unit = %s WHERE id = %s RETURNING id, name;",
            (name, unit, material_id)
        )
        row = cur.fetchone()
        if not row:
            conn.rollback()
            raise ValueError("Barang tidak ditemukan.")
        conn.commit()
        return dict(row)
    except ValueError:
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(str(e))
    finally:
        cur.close()
        conn.close()


def delete_fin_material(material_id):
    """Nonaktifkan barang gudang & bersihkan referensi stok. Return nama barang."""
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT name FROM fin_materials WHERE id = %s;", (material_id,))
        row = cur.fetchone()
        if not row:
            conn.rollback()
            raise ValueError("Barang tidak ditemukan.")
        mat_name = row["name"]

        cur.execute("DELETE FROM fin_stock_ledger WHERE material_id = %s;", (material_id,))
        cur.execute("""
            UPDATE fin_transaction_items
            SET material_id = NULL
            WHERE material_id = %s;
        """, (material_id,))
        cur.execute("DELETE FROM fin_stock_summary WHERE material_id = %s;", (material_id,))
        cur.execute("UPDATE fin_materials SET is_active = FALSE WHERE id = %s;", (material_id,))
        conn.commit()
        return mat_name
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(str(e))
    finally:
        cur.close()
        conn.close()


def create_fin_purchase(party_name, is_debt, note, discount, items, created_by):
    """
    Kasir Beli — beli barang dari orang/pemasok, stok masuk gudang via AVCO.
    'discount' = nilai potongan/DP dalam Rupiah; total & hutang dicatat
    sebesar (total - discount), stok/HPP tetap pakai harga asli.
    Return dict {transaction_id, total, discount, grand_total}.
    """
    party_name = (party_name or "").strip()
    note = (note or "").strip()
    discount = max(0.0, float(discount or 0))
    is_debt = bool(is_debt)

    if not items:
        raise ValueError("Minimal 1 item barang.")

    from routes.mobile.finance import _update_stock_avco

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        total = sum(float(i.get("qty_kg", 0)) * float(i.get("price_per_kg", 0)) for i in items)
        grand_total = max(0.0, total - discount)

        cur.execute("""
            INSERT INTO fin_transactions
                (type, party_name, party_type, note, is_debt, total_amount, created_by)
            VALUES ('BELI_GUDANG', %s, 'PELANGGAN', %s, %s, %s, %s)
            RETURNING id;
        """, (party_name or None, note or None, is_debt, grand_total, created_by))
        txn_id = cur.fetchone()["id"]

        for item in items:
            mat_id = int(item["material_id"])
            qty = float(item["qty_kg"])
            price = float(item["price_per_kg"])
            subtotal = qty * price

            cur.execute("""
                INSERT INTO fin_transaction_items
                    (transaction_id, material_id, qty_kg, price_per_kg, subtotal)
                VALUES (%s, %s, %s, %s, %s);
            """, (txn_id, mat_id, qty, price, subtotal))

            _update_stock_avco(cur, mat_id, qty, price, 'IN', txn_id,
                               note=f"Beli dari {party_name or 'orang'}")

        if is_debt and party_name:
            cur.execute("""
                INSERT INTO fin_debts
                    (type, party_name, party_type, amount, remaining, transaction_id, note)
                VALUES ('HUTANG', %s, 'PELANGGAN', %s, %s, %s, %s);
            """, (party_name, grand_total, grand_total, txn_id, "Beli barang — belum dibayar"))

        conn.commit()
        return {
            "transaction_id": txn_id,
            "total": total,
            "discount": discount,
            "grand_total": grand_total,
        }
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal: {e}")
    finally:
        cur.close()
        conn.close()


def create_fin_sale_kasir(party_name, is_debt, note, items, created_by):
    """
    Kasir Jual — jual barang gudang ke orang, stok keluar via AVCO.
    Beda dari create_fin_invoice (Nota): tidak generate invoice_no/cetak,
    dipakai untuk transaksi cepat tanpa nota resmi.
    Return dict {transaction_id, total, hpp, laba}.
    """
    party_name = (party_name or "").strip()
    note = (note or "").strip()
    is_debt = bool(is_debt)

    if not items:
        raise ValueError("Minimal 1 item barang.")

    from routes.mobile.finance import _update_stock_avco

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        total = sum(float(i.get("qty_kg", 0)) * float(i.get("price_per_kg", 0)) for i in items)

        for item in items:
            mat_id = int(item["material_id"])
            qty = float(item["qty_kg"])
            cur.execute("""
                SELECT COALESCE(qty_kg, 0) AS qty, name
                FROM fin_stock_summary s
                JOIN fin_materials m ON m.id = s.material_id
                WHERE s.material_id = %s;
            """, (mat_id,))
            stok = cur.fetchone()
            if not stok or float(stok["qty"]) < qty:
                nama = stok["name"] if stok else f"Material #{mat_id}"
                tersedia = float(stok["qty"]) if stok else 0
                raise ValueError(f"Stok {nama} tidak cukup. Tersedia: {tersedia} kg")

        cur.execute("""
            INSERT INTO fin_transactions
                (type, party_name, party_type, note, is_debt, total_amount, created_by)
            VALUES ('JUAL_GUDANG', %s, 'PELANGGAN', %s, %s, %s, %s)
            RETURNING id;
        """, (party_name or None, note or None, is_debt, total, created_by))
        txn_id = cur.fetchone()["id"]

        hpp_total = 0.0
        for item in items:
            mat_id = int(item["material_id"])
            qty = float(item["qty_kg"])
            price = float(item["price_per_kg"])
            subtotal = qty * price

            cur.execute("""
                SELECT COALESCE(avg_cost_per_kg, 0) AS avg
                FROM fin_stock_summary WHERE material_id = %s;
            """, (mat_id,))
            row = cur.fetchone()
            avg = float(row["avg"]) if row else 0
            hpp_total += qty * avg

            cur.execute("""
                INSERT INTO fin_transaction_items
                    (transaction_id, material_id, qty_kg, price_per_kg, subtotal)
                VALUES (%s, %s, %s, %s, %s);
            """, (txn_id, mat_id, qty, price, subtotal))

            _update_stock_avco(cur, mat_id, qty, avg, 'OUT', txn_id,
                               note=f"Jual ke {party_name or 'orang'}")

        if is_debt and party_name:
            cur.execute("""
                INSERT INTO fin_debts
                    (type, party_name, party_type, amount, remaining, transaction_id, note)
                VALUES ('PIUTANG', %s, 'PELANGGAN', %s, %s, %s, %s);
            """, (party_name, total, total, txn_id, "Jual barang — belum dibayar"))

        conn.commit()
        laba = total - hpp_total
        return {"transaction_id": txn_id, "total": total, "hpp": hpp_total, "laba": laba}
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal: {e}")
    finally:
        cur.close()
        conn.close()


def create_fin_expense(note, items, created_by):
    """Input pengeluaran operasional (ongkir, makan, dll). Return dict {transaction_id, total}."""
    note = (note or "").strip()
    if not items:
        raise ValueError("Minimal 1 item pengeluaran.")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        total = sum(float(i.get("subtotal", 0)) for i in items)

        cur.execute("""
            INSERT INTO fin_transactions (type, note, total_amount, created_by)
            VALUES ('PENGELUARAN', %s, %s, %s)
            RETURNING id;
        """, (note or None, total, created_by))
        txn_id = cur.fetchone()["id"]

        for item in items:
            cur.execute("""
                INSERT INTO fin_transaction_items (transaction_id, expense_name, subtotal)
                VALUES (%s, %s, %s);
            """, (txn_id, (item.get("expense_name") or "Pengeluaran").strip(),
                  float(item.get("subtotal", 0))))

        conn.commit()
        return {"transaction_id": txn_id, "total": total}
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(f"Gagal: {e}")
    finally:
        cur.close()
        conn.close()


def list_fin_debts():
    """Daftar hutang (ke pemasok) & piutang yang belum lunas."""
    from routes.mobile.finance import _clean
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, type, party_name, amount, paid_amount,
                   remaining, due_date, is_settled, note, created_at
            FROM fin_debts
            WHERE is_settled = FALSE
            ORDER BY type, created_at DESC;
        """)
        rows = _clean([dict(r) for r in cur.fetchall()])
        hutang = [r for r in rows if r["type"] == "HUTANG"]
        piutang = [r for r in rows if r["type"] == "PIUTANG"]
        return {
            "hutang": hutang,
            "piutang": piutang,
            "total_hutang": sum(float(r["remaining"]) for r in hutang),
            "total_piutang": sum(float(r["remaining"]) for r in piutang),
        }
    finally:
        cur.close()
        conn.close()


def pay_fin_debt(debt_id, pay_amount):
    """Cicil/lunasi hutang atau piutang. Return dict {paid, remaining, is_settled}."""
    pay_amount = float(pay_amount or 0)
    if pay_amount <= 0:
        raise ValueError("Jumlah pembayaran harus lebih dari 0.")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, amount, paid_amount, remaining, type, party_name
            FROM fin_debts WHERE id = %s;
        """, (debt_id,))
        debt = cur.fetchone()
        if not debt:
            raise ValueError("Data tidak ditemukan.")

        new_paid = float(debt["paid_amount"]) + pay_amount
        new_remaining = max(0, float(debt["amount"]) - new_paid)
        is_settled = new_remaining <= 0

        cur.execute("""
            UPDATE fin_debts
            SET paid_amount = %s, remaining = %s, is_settled = %s
            WHERE id = %s;
        """, (new_paid, new_remaining, is_settled, debt_id))
        conn.commit()
        return {"paid": new_paid, "remaining": new_remaining, "is_settled": is_settled}
    except ValueError:
        conn.rollback()
        raise
    except Exception as e:
        conn.rollback()
        raise ValueError(str(e))
    finally:
        cur.close()
        conn.close()


def get_fin_stock_history(material_id):
    """Riwayat pergerakan stok 1 material + ringkasan stok saat ini."""
    from routes.mobile.finance import _clean
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT l.*, m.name AS material_name
            FROM fin_stock_ledger l
            JOIN fin_materials m ON m.id = l.material_id
            WHERE l.material_id = %s
            ORDER BY l.created_at DESC
            LIMIT 50;
        """, (material_id,))
        rows = _clean([dict(r) for r in cur.fetchall()])

        cur.execute("""
            SELECT qty_kg, avg_cost_per_kg, total_value
            FROM fin_stock_summary WHERE material_id = %s;
        """, (material_id,))
        summary = dict(cur.fetchone() or {})

        return {"current": summary, "history": rows}
    finally:
        cur.close()
        conn.close()


def get_fin_daily_report(report_date):
    """Laporan keuangan harian (kasir gudang + trip). `report_date` = datetime.date."""
    from routes.mobile.finance import _clean
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                t.id, t.type, t.party_name, t.total_amount,
                t.is_debt, t.note, t.created_at,
                json_agg(json_build_object(
                    'material_id',  i.material_id,
                    'expense_name', i.expense_name,
                    'qty_kg',       i.qty_kg,
                    'price_per_kg', i.price_per_kg,
                    'subtotal',     i.subtotal,
                    'material_name', m.name
                )) AS items
            FROM fin_transactions t
            LEFT JOIN fin_transaction_items i ON i.transaction_id = t.id
            LEFT JOIN fin_materials m ON m.id = i.material_id
            WHERE t.created_at::date = %s
            GROUP BY t.id
            ORDER BY t.created_at DESC;
        """, (report_date,))
        transactions = [dict(r) for r in cur.fetchall()]

        cur.execute("""
            SELECT
                ti.id, ti.type AS trip_item_type,
                ti.subtotal, ti.qty_kg, ti.expense_name,
                ti.payment_type,
                m.name AS material_name,
                p.name AS party_name,
                t.note AS trip_note,
                t.id   AS trip_id,
                ti.created_at
            FROM fin_trip_items ti
            JOIN fin_trips t ON t.id = ti.trip_id
            LEFT JOIN fin_materials m ON m.id = ti.material_id
            LEFT JOIN fin_trip_parties p ON p.id = ti.party_id
            WHERE ti.created_at::date = %s
            ORDER BY ti.created_at DESC;
        """, (report_date,))
        trip_items = [dict(r) for r in cur.fetchall()]

        for ti in trip_items:
            type_map = {
                'JUAL':    'JUAL_TRIP',
                'BELI':    'BELI_TRIP',
                'EXPENSE': 'PENGELUARAN_TRIP',
                'RETURN':  'RETURN_TRIP',
            }
            transactions.append({
                "id":           f"trip-{ti['id']}",
                "type":         type_map.get(ti['trip_item_type'], ti['trip_item_type']),
                "party_name":   ti.get('party_name') or ti.get('trip_note') or f"Trip #{ti['trip_id']}",
                "total_amount": float(ti['subtotal'] or 0),
                "note":         ti.get('expense_name') or ti.get('material_name'),
                "created_at":   str(ti['created_at']),
                "is_trip":      True,
                "items": [],
            })

        pemasukan = sum(float(t["total_amount"] or 0) for t in transactions
                        if t["type"] in ("JUAL_GUDANG", "JUAL_INVOICE", "TERIMA_HUTANG"))
        pengeluaran = sum(float(t["total_amount"] or 0) for t in transactions
                          if t["type"] in ("BELI_GUDANG", "PENGELUARAN", "PEMBAYARAN_DP", "BAYAR_HUTANG"))

        trip_jual = sum(float(t["total_amount"] or 0) for t in transactions if t["type"] == "JUAL_TRIP")
        trip_beli = sum(float(t["total_amount"] or 0) for t in transactions if t["type"] == "BELI_TRIP")
        trip_expense = sum(float(t["total_amount"] or 0) for t in transactions if t["type"] == "PENGELUARAN_TRIP")

        cur.execute("""
            SELECT COALESCE(SUM(i.qty_kg * s.avg_cost_per_kg), 0) AS hpp_total
            FROM fin_transactions t
            JOIN fin_transaction_items i ON i.transaction_id = t.id
            JOIN fin_stock_summary s ON s.material_id = i.material_id
            WHERE t.created_at::date = %s
              AND t.type IN ('JUAL_GUDANG', 'JUAL_INVOICE')
              AND i.material_id IS NOT NULL;
        """, (report_date,))
        hpp_gudang = float((cur.fetchone() or {}).get("hpp_total", 0))

        cur.execute("""
            SELECT COALESCE(SUM(ti.qty_kg * s.avg_cost_per_kg), 0) AS hpp_total
            FROM fin_trip_items ti
            JOIN fin_stock_summary s ON s.material_id = ti.material_id
            WHERE ti.created_at::date = %s AND ti.type = 'JUAL';
        """, (report_date,))
        hpp_trip = float((cur.fetchone() or {}).get("hpp_total", 0))

        hpp_total = hpp_gudang + hpp_trip
        omzet_jual = sum(float(t["total_amount"] or 0) for t in transactions
                         if t["type"] in ("JUAL_GUDANG", "JUAL_INVOICE", "JUAL_TRIP"))
        laba_kotor = omzet_jual - hpp_total - trip_expense

        cur.execute("SELECT COALESCE(SUM(total_value), 0) AS total FROM fin_stock_summary;")
        nilai_stok = float((cur.fetchone() or {}).get("total", 0))

        return _clean({
            "date": str(report_date),
            "transactions": transactions,
            "summary": {
                "pemasukan": pemasukan,
                "pengeluaran": pengeluaran,
                "omzet_jual": omzet_jual,
                "hpp": hpp_total,
                "laba_kotor": laba_kotor,
                "nilai_stok": nilai_stok,
                "trip_jual": trip_jual,
                "trip_beli": trip_beli,
                "trip_expense": trip_expense,
            }
        })
    finally:
        cur.close()
        conn.close()


def get_fin_weekly_report(week_start, week_end):
    """Laporan keuangan mingguan. `week_start`/`week_end` = datetime.date."""
    from routes.mobile.finance import _clean
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT type, SUM(total_amount) AS total, COUNT(*) AS count
            FROM fin_transactions
            WHERE created_at::date >= %s AND created_at::date <= %s
            GROUP BY type;
        """, (week_start, week_end))
        by_type = {r["type"]: dict(r) for r in cur.fetchall()}

        def _sum(types):
            return sum(float((by_type.get(t) or {}).get("total", 0)) for t in types)

        omzet = _sum(["JUAL_GUDANG", "JUAL_INVOICE"])
        modal = _sum(["BELI_GUDANG"])
        biaya = _sum(["PENGELUARAN", "PEMBAYARAN_DP"])
        masuk = _sum(["TERIMA_HUTANG"])

        cur.execute("""
            SELECT COALESCE(SUM(i.qty_kg * s.avg_cost_per_kg), 0) AS hpp
            FROM fin_transactions t
            JOIN fin_transaction_items i ON i.transaction_id = t.id
            JOIN fin_stock_summary s ON s.material_id = i.material_id
            WHERE t.created_at::date >= %s AND t.created_at::date <= %s
              AND t.type IN ('JUAL_GUDANG', 'JUAL_INVOICE')
              AND i.material_id IS NOT NULL;
        """, (week_start, week_end))
        hpp = float((cur.fetchone() or {}).get("hpp", 0))

        laba_kotor = omzet - hpp
        laba_bersih = laba_kotor - biaya

        cur.execute("""
            SELECT
                created_at::date AS hari,
                SUM(CASE WHEN type IN ('JUAL_GUDANG','JUAL_INVOICE') THEN total_amount ELSE 0 END) AS jual,
                SUM(CASE WHEN type = 'BELI_GUDANG'  THEN total_amount ELSE 0 END) AS beli,
                SUM(CASE WHEN type = 'PENGELUARAN'  THEN total_amount ELSE 0 END) AS biaya
            FROM fin_transactions
            WHERE created_at::date >= %s AND created_at::date <= %s
            GROUP BY hari ORDER BY hari;
        """, (week_start, week_end))
        per_hari = [dict(r) for r in cur.fetchall()]

        return _clean({
            "week_start": str(week_start),
            "week_end": str(week_end),
            "week_label": f"{week_start.strftime('%d %b')} – {week_end.strftime('%d %b %Y')}",
            "summary": {
                "omzet_jual": omzet,
                "modal_beli": modal,
                "hpp": hpp,
                "laba_kotor": laba_kotor,
                "biaya_ops": biaya,
                "laba_bersih": laba_bersih,
                "piutang_masuk": masuk,
            },
            "per_hari": per_hari,
        })
    finally:
        cur.close()
        conn.close()
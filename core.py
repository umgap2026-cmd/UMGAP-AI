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
from psycopg2.extras import RealDictCursor
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
            ADD COLUMN IF NOT EXISTS print_size VARCHAR(20) NULL;
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
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS password_reset_otps (
                id SERIAL PRIMARY KEY,
                email VARCHAR(255) NOT NULL,
                otp_hash TEXT NOT NULL,
                expires_at TIMESTAMP NOT NULL,
                used BOOLEAN NOT NULL DEFAULT FALSE,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
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
def _make_invoice_no():
    now = datetime.now(ZoneInfo("Asia/Jakarta"))
    return "INV-" + now.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:5].upper()

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


def create_fin_invoice(customer_name, customer_phone, payment_method, notes,
                        discount, is_paid, items, created_by, print_size=None):
    """
    Buat nota JUAL_INVOICE dari stok gudang (fin_materials), potong stok AVCO,
    catat piutang jika belum lunas. Logic diextract dari
    routes/mobile/finance.py:create_invoice() agar web & mobile berbagi 1
    sumber kebenaran. Raise ValueError(pesan) kalau validasi gagal.
    Return dict: {invoice_id, invoice_no, subtotal, discount, total, hpp, laba}.
    """
    from routes.mobile.finance import _update_stock_avco

    customer_name = (customer_name or "").strip()
    if not customer_name:
        raise ValueError("Nama customer wajib diisi.")
    if not items:
        raise ValueError("Minimal 1 item barang.")

    discount = float(discount or 0)
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
        grand_total = max(0.0, subtotal_bruto - discount)

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

        conn.commit()

        return {
            "invoice_id": txn_id,
            "invoice_no": invoice_no,
            "subtotal": subtotal_bruto,
            "discount": discount,
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


def get_fin_invoice_detail(txn_id):
    """
    Ambil 1 nota (fin_transactions) beserta items-nya, dibentuk dengan
    field-name yang sama dipakai templates/invoice_print.html &
    invoice_pdf.html (invoice_no, customer_name, created_by_name,
    payment_method, subtotal, discount, grand_total, notes, print_size,
    is_paid, company_name, logo_data_uri). Return (invoice_dict, items) atau
    (None, []) kalau tidak ada.
    """
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_transaction_cancel_columns(cur)
        conn.commit()

        cur.execute("""
            SELECT t.id, t.note, t.party_name AS customer_name, t.is_debt,
                   t.total_amount, t.created_at, t.print_size,
                   u.name AS created_by_name
            FROM fin_transactions t
            LEFT JOIN users u ON u.id = t.created_by
            WHERE t.id = %s AND t.type = 'JUAL_INVOICE';
        """, (txn_id,))
        row = cur.fetchone()
        if not row:
            return None, []

        invoice_no, payment_method, extra_notes = _parse_nota_note(row.get("note"))

        cur.execute("""
            SELECT m.name AS product_name, ti.qty_kg AS qty,
                   ti.price_per_kg AS price, ti.subtotal
            FROM fin_transaction_items ti
            LEFT JOIN fin_materials m ON m.id = ti.material_id
            WHERE ti.transaction_id = %s
            ORDER BY ti.id ASC;
        """, (txn_id,))
        items = [{
            "product_name": r.get("product_name") or "-",
            "qty": float(r["qty"] or 0),
            "price": int(r["price"] or 0),
            "subtotal": float(r["subtotal"] or 0),
        } for r in cur.fetchall()]

        items_subtotal = sum(it["subtotal"] for it in items)
        grand_total = float(row.get("total_amount") or 0)
        profile = get_company_profile()

        invoice = {
            "id": row["id"],
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
import os
import io
import ssl
import random
import smtplib
import hmac
import hashlib
import uuid
import requests
from datetime import datetime, date, timedelta
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

UPLOAD_ATT_USER_DIR = os.path.join("static", "uploads", "attendance_user")
UPLOAD_QA_DIR = os.path.join("static", "uploads", "quick_attendance")
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

def login_required():
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            if not session.get("user_id"):
                return redirect(url_for("auth.login"))
            return fn(*args, **kwargs)
        return wrapper
    return decorator


# =========================
# FILE / DIR HELPERS
# =========================
def _ensure_att_user_upload_dir():
    os.makedirs(UPLOAD_ATT_USER_DIR, exist_ok=True)

def _ensure_upload_dir():
    os.makedirs(UPLOAD_QA_DIR, exist_ok=True)

def _ensure_invoice_logo_dir():
    os.makedirs(UPLOAD_INVOICE_LOGO_DIR, exist_ok=True)

def cleanup_old_quick_attendance_photos():
    _ensure_upload_dir()
    today_prefix = "qa_" + date.today().strftime("%Y_%m_%d") + "_"
    for fn in os.listdir(UPLOAD_QA_DIR):
        if fn.startswith("qa_") and not fn.startswith(today_prefix):
            try:
                os.remove(os.path.join(UPLOAD_QA_DIR, fn))
            except Exception as e:
                print("cleanup error:", fn, e)

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

def _utc_naive_to_wib_string_short(dt, fmt="%d/%m/%Y %H:%M"):
    if not dt:
        return "-"
    try:
        return (dt + timedelta(hours=7)).strftime(fmt)
    except Exception:
        return "-"

def _parse_date(s):
    if not s:
        return None
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except Exception:
        return None

def _seconds_to_hms(total_seconds):
    total_seconds = int(total_seconds or 0)
    h = total_seconds // 3600
    m = (total_seconds % 3600) // 60
    s = total_seconds % 60
    return f"{h:02d}:{m:02d}:{s:02d}"


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

def _rupiah(value):
    try:
        n = int(value)
        return f"Rp {n:,}".replace(",", ".")
    except Exception:
        return f"Rp {value}"

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

def _decimal_to_display(v):
    d = _safe_decimal(v)
    s = format(d.normalize(), "f")
    if "." in s:
        s = s.rstrip("0").rstrip(".")
    return s.replace(".", ",")

def _pick(rng, items):
    return items[rng.randrange(len(items))]


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

def ensure_mobile_api_schema():
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
        conn.commit()
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
                                 data=json.dumps(payload), timeout=15)
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

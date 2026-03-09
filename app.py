# ==================== IMPORTS ====================
import os
import io
import re
import ssl
import time
import random
import smtplib
import calendar
import hmac
import hashlib
from datetime import datetime, date, timedelta
from email.message import EmailMessage
from functools import wraps
from decimal import Decimal
import uuid
import psycopg2


# Flask & Extensions
from flask import (
    Flask, render_template, request, redirect, session, abort,
    jsonify, url_for, flash, Response, send_file
)
from werkzeug.security import generate_password_hash, check_password_hash
from dotenv import load_dotenv

# Database
from psycopg2.extras import RealDictCursor
from db import get_conn

# AI
from openai import OpenAI
from openai import RateLimitError, APIError, AuthenticationError

# Excel Export
from openpyxl import Workbook
from openpyxl.utils import get_column_letter

# OAuth
from authlib.integrations.flask_client import OAuth

# Timezone
from zoneinfo import ZoneInfo

# Serial port untuk print thermal via Bluetooth COM port (Windows)
try:
    import serial
    import serial.tools.list_ports
    SERIAL_OK = True
except ImportError:
    SERIAL_OK = False

# Load .env
load_dotenv()

from werkzeug.middleware.proxy_fix import ProxyFix

from werkzeug.utils import secure_filename

# ==================== APP CONFIG ====================
app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "dev-secret-change-me")
IS_PROD = os.getenv("RENDER") == "true" or os.getenv("FLASK_ENV") == "production"
app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
app.config["SESSION_COOKIE_SECURE"] = True if IS_PROD else False
app.config["SESSION_COOKIE_HTTPONLY"] = True
app.config["PREFERRED_URL_SCHEME"] = "https" if IS_PROD else "http"
app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_port=1)
# OpenAI Client
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
OPENAI_API_KEY = (os.getenv("OPENAI_API_KEY") or "").strip()
oa_client = OpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None

# OAuth Setup
oauth = OAuth(app)
GOOGLE_CLIENT_ID = (os.getenv("GOOGLE_CLIENT_ID") or "").strip()
GOOGLE_CLIENT_SECRET = (os.getenv("GOOGLE_CLIENT_SECRET") or "").strip()

if GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET:
    oauth.register(
        name="google",
        client_id=GOOGLE_CLIENT_ID,
        client_secret=GOOGLE_CLIENT_SECRET,
        server_metadata_url="https://accounts.google.com/.well-known/openid-configuration",
        client_kwargs={"scope": "openid email profile"},
    )

# ==================== HELPER FUNCTIONS ====================
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
        return redirect(url_for("login"))
    if session.get("role") != "admin":
        flash("Akses ditolak. Hanya admin.", "danger")
        return redirect(url_for("dashboard"))
    return None

UPLOAD_ATT_USER_DIR = os.path.join("static", "uploads", "attendance_user")

def _ensure_att_user_upload_dir():
    os.makedirs(UPLOAD_ATT_USER_DIR, exist_ok=True)

UPLOAD_QA_DIR = os.path.join("static", "uploads", "quick_attendance")

def _ensure_upload_dir():
    os.makedirs(UPLOAD_QA_DIR, exist_ok=True)

def cleanup_old_quick_attendance_photos():
    """
    Hapus foto quick attendance yang bukan hari ini.
    Nama file kita buat prefix: qa_YYYY_MM_DD_...
    """
    _ensure_upload_dir()
    today_prefix = "qa_" + date.today().strftime("%Y_%m_%d") + "_"
    for fn in os.listdir(UPLOAD_QA_DIR):
        if fn.startswith("qa_") and not fn.startswith(today_prefix):
            try:
                os.remove(os.path.join(UPLOAD_QA_DIR, fn))
            except Exception as e:
                print("cleanup error:", fn, e)

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

def _public_ip():
    # Render biasanya set X-Forwarded-For
    xf = request.headers.get("X-Forwarded-For", "")
    if xf:
        return xf.split(",")[0].strip()
    return request.remote_addr

def login_required():
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            if not session.get("user_id"):
                return redirect(url_for("login"))
            return fn(*args, **kwargs)
        return wrapper
    return decorator

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
        now_wib_aware = datetime.fromtimestamp(int(client_ts) / 1000, tz=ZoneInfo("Asia/Jakarta"))
    else:
        now_wib_aware = datetime.now(ZoneInfo("Asia/Jakarta"))
    return now_wib_aware.replace(tzinfo=None)

def _utc_naive_to_wib_naive(dt):
    """
    DB kamu sekarang banyak menyimpan timestamp naive yang tampil seperti UTC.
    Fungsi ini geser +7 jam agar sinkron ke WIB.
    """
    if not dt:
        return None
    return dt + timedelta(hours=7)

def _parse_date(s):
    if not s:
        return None
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except Exception:
        return None

def pick(options):
    return random.choice(options)

def rupiah(s):
    try:
        n = int(s)
        return f"Rp {n:,}".replace(",", ".")
    except:
        return f"Rp {s}"

def _rupiah(value):
    try:
        n = int(value)
        return f"Rp {n:,}".replace(",", ".")
    except:
        return f"Rp {value}"

def _pick(rng, items):
    """Pick a random item from a list using the provided RNG."""
    return items[rng.randrange(len(items))]

def _otp_hash(email, otp):
    salt = (os.getenv("RESET_OTP_SALT") or "umgap-reset-salt").encode("utf-8")
    msg = (email.lower().strip() + ":" + otp.strip()).encode("utf-8")
    return hashlib.sha256(salt + msg).hexdigest()

# =========================
# Helper invoice
# =========================

def _make_invoice_no():
    now = datetime.now(ZoneInfo("Asia/Jakarta"))
    return "INV-" + now.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:5].upper()


def _safe_int(v, default=0):
    try:
        return int(v)
    except Exception:
        return default


def _invoice_rows_from_form(form):
    product_ids = form.getlist("product_id[]")
    qtys = form.getlist("qty[]")

    rows = []
    for i in range(min(len(product_ids), len(qtys))):
        pid = _safe_int(product_ids[i], 0)
        qty = _safe_int(qtys[i], 0)
        if pid > 0 and qty > 0:
            rows.append({
                "product_id": pid,
                "qty": qty
            })
    return rows


UPLOAD_INVOICE_LOGO_DIR = os.path.join("static", "uploads", "invoice_logo")

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

    filename = f"inv_logo_{datetime.now(ZoneInfo('Asia/Jakarta')).strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:8]}{ext}"
    save_path = os.path.join(UPLOAD_INVOICE_LOGO_DIR, filename)
    file_storage.save(save_path)

    return f"uploads/invoice_logo/{filename}"

def _utc_naive_to_wib_string(dt, fmt="%d/%m/%Y %H:%M"):
    if not dt:
        return "-"
    try:
        return (dt + timedelta(hours=7)).strftime(fmt)
    except Exception:
        return "-"

# =========================
# SIMPAN INVOICE
# =========================

def _save_invoice(is_admin_mode=False):
    ensure_invoice_schema()

    created_by = session.get("user_id")
    customer_name = (request.form.get("customer_name") or "").strip()
    company_name = (request.form.get("company_name") or "").strip()
    payment_method = (request.form.get("payment_method") or "CASH").strip().upper()
    print_size = (request.form.get("print_size") or "80mm").strip()
    notes = (request.form.get("notes") or "").strip()

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
        subtotal = 0

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

            qty = row["qty"]
            price = int(p.get("price") or 0)
            line_subtotal = qty * price
            subtotal += line_subtotal

            final_items.append({
                "product_id": p["id"],
                "product_name": p["name"],
                "qty": qty,
                "price": price,
                "subtotal": line_subtotal
            })

        if not final_items:
            return redirect("/admin/invoice/new" if is_admin_mode else "/invoice/new")

        grand_total = subtotal

        cur.execute("""
            INSERT INTO invoices
                (invoice_no, created_by, customer_name, company_name, company_logo_path,
                 print_size, payment_method, subtotal, grand_total, notes)
            VALUES
                (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            RETURNING id;
        """, (
            invoice_no,
            created_by,
            customer_name,
            company_name,
            company_logo_path,
            print_size,
            payment_method,
            subtotal,
            grand_total,
            notes
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
                item["qty"],
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
                item["qty"],
                f"INVOICE {invoice_no}"
            ))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect(f"/invoice/{invoice_id}")



# ==================== SCHEMA ENSURERS ====================
def ensure_points_schema():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS points INTEGER DEFAULT 0;")
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS points_admin INTEGER DEFAULT 0;")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS points_logs (
            id SERIAL PRIMARY KEY,
            user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            admin_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            delta INT NOT NULL,
            note TEXT,
            created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
        );
    """)
    conn.commit()
    cur.close()
    conn.close()

def init_points_v1():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS points INTEGER NOT NULL DEFAULT 0;")
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS points_admin INTEGER NOT NULL DEFAULT 0;")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS points_logs (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            admin_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
            delta INTEGER NOT NULL,
            note TEXT,
            created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT CURRENT_TIMESTAMP
        );
    """)
    conn.commit()
    cur.close()
    conn.close()

def ensure_hr_v2_schema():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS payroll_settings (
                user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
                daily_salary INTEGER NOT NULL DEFAULT 0,
                monthly_salary INTEGER NOT NULL DEFAULT 0,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        cur.execute("ALTER TABLE payroll_settings ADD COLUMN IF NOT EXISTS daily_salary INTEGER NOT NULL DEFAULT 0;")
        cur.execute("ALTER TABLE payroll_settings ADD COLUMN IF NOT EXISTS monthly_salary INTEGER NOT NULL DEFAULT 0;")
        cur.execute("ALTER TABLE payroll_settings ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;")
        cur.execute("ALTER TABLE attendance ADD COLUMN IF NOT EXISTS arrival_type VARCHAR(20) NOT NULL DEFAULT 'ONTIME';")
        cur.execute("ALTER TABLE attendance ADD COLUMN IF NOT EXISTS checkin_at TIMESTAMP NULL;")
        conn.commit()
    finally:
        cur.close()
        conn.close()

def ensure_password_reset_schema():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS password_reset_otps (
            id SERIAL PRIMARY KEY,
            email TEXT NOT NULL,
            otp_hash TEXT NOT NULL,
            expires_at TIMESTAMP NOT NULL,
            used BOOLEAN NOT NULL DEFAULT FALSE,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
    """)
    conn.commit()
    cur.close()
    conn.close()

def ensure_announcements_schema():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS announcements (
            id SERIAL PRIMARY KEY,
            title VARCHAR(255) NOT NULL,
            message TEXT NOT NULL,
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS announcement_reads (
            id SERIAL PRIMARY KEY,
            announcement_id INTEGER NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            read_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            UNIQUE(announcement_id, user_id)
        );
    """)
    conn.commit()
    cur.close()
    conn.close()

def get_unread_notifications(user_id):
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT COUNT(*) AS total
            FROM announcements a
            WHERE a.is_active = TRUE
              AND a.id NOT IN (
                SELECT announcement_id
                FROM announcement_reads
                WHERE user_id = %s
              )
        """, (user_id,))
        row = cur.fetchone() or {"total": 0}
        return int(row.get("total", 0) or 0)
    finally:
        cur.close()
        conn.close()

def get_notif_count():
    conn = get_conn()
    # PAKAI RealDictCursor kalau kamu konsisten pakai dict di app
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT COUNT(*) AS total FROM announcements WHERE is_active = TRUE;")
        row = cur.fetchone() or {"total": 0}
        return int(row.get("total", 0) or 0)
    finally:
        cur.close()
        conn.close()

def ensure_attendance_links_schema():
    conn = get_conn()
    cur = conn.cursor()
    try:
        # 1) pastikan tabel ada (minimal)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS attendance_links (
                id SERIAL PRIMARY KEY,
                token TEXT UNIQUE NOT NULL
            );
        """)

        # 2) migrasi kolom-kolom yang mungkin belum ada (untuk DB lama)
        cur.execute("ALTER TABLE attendance_links ADD COLUMN IF NOT EXISTS title TEXT;")
        cur.execute("ALTER TABLE attendance_links ADD COLUMN IF NOT EXISTS created_by INTEGER;")
        cur.execute("ALTER TABLE attendance_links ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;")
        cur.execute("ALTER TABLE attendance_links ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;")

        conn.commit()
    finally:
        cur.close()
        conn.close()

# ============== INVOICE GENERATOR ================
def ensure_invoice_schema():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS invoices (
                id SERIAL PRIMARY KEY,
                invoice_no VARCHAR(50) UNIQUE NOT NULL,
                created_by INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                customer_name VARCHAR(150),
                company_name VARCHAR(150),
                company_logo_path TEXT,
                print_size VARCHAR(10) NOT NULL DEFAULT '80mm',
                payment_method VARCHAR(30) DEFAULT 'CASH',
                subtotal INTEGER NOT NULL DEFAULT 0,
                grand_total INTEGER NOT NULL DEFAULT 0,
                notes TEXT,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)

        cur.execute("ALTER TABLE invoices ADD COLUMN IF NOT EXISTS company_name VARCHAR(150);")
        cur.execute("ALTER TABLE invoices ADD COLUMN IF NOT EXISTS company_logo_path TEXT;")

        cur.execute("""
            CREATE TABLE IF NOT EXISTS invoice_items (
                id SERIAL PRIMARY KEY,
                invoice_id INTEGER NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
                product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
                product_name VARCHAR(150) NOT NULL,
                qty INTEGER NOT NULL DEFAULT 1,
                price INTEGER NOT NULL DEFAULT 0,
                subtotal INTEGER NOT NULL DEFAULT 0
            );
        """)

        conn.commit()
    finally:
        cur.close()
        conn.close()

# ==================== AI CAPTION GENERATOR ====================
def generate_caption_ai(product, price, style, brand="", platform="Instagram", notes=""):
    product = (product or "").strip()
    price = (price or "").strip()
    style = (style or "Santai").strip()
    brand = (brand or "").strip()
    platform = (platform or "Instagram").strip()
    notes = (notes or "").strip()

    brand_rule = f'- WAJIB sebut brand "{brand}" minimal 1x di tiap versi.\n' if brand else ""
    price_hint = f'- Cantumkan harga "{price}" dengan format yang enak dibaca.\n' if price else ""

    platform_rules = {
        "WhatsApp": "Gaya WhatsApp: Ringkas, 4–7 baris, CTA chat/wa, hashtag 0–2.",
        "TikTok": "Gaya TikTok: Wajib HOOK 1 baris, 8–14 baris, ajakan komentar, hashtag 5–9.",
        "Instagram": "Gaya Instagram: Semi storytelling, 9–15 baris, CTA DM/komentar, hashtag 5–10."
    }
    plat_rule = platform_rules.get(platform, platform_rules["Instagram"])
    notes_block = f'Catatan pendukung: "{notes}"\n' if notes else ""

    prompt = f"""
Kamu copywriter UMKM Indonesia. Buat caption ORGANIK, manusiawi.

DATA: Produk: "{product}", Platform: "{platform}", Tone: "{style}"
{notes_block}

ATURAN: {brand_rule}{price_hint}Tidak klaim medis. Bahasa Indonesia sehari-hari.

{plat_rule}

Buat 3 versi berbeda: V1 (manfaat), V2 (cerita), V3 (promo halus).
Format: V1: ... V2: ... V3: ...
"""

    r = client.responses.create(
        model="gpt-4.1-mini",
        input=prompt,
        temperature=0.9,
        max_output_tokens=700
    )
    return (r.output_text or "").strip()

def build_caption(data):
    seed = time.time_ns()
    rng = random.Random(seed)

    template = (data.get("template") or "promo").strip()
    biz_type = (data.get("biz_type") or "produk").strip()
    tone = (data.get("tone") or "santai").strip()
    product = (data.get("product") or "").strip()
    price = _rupiah((data.get("price") or "").strip())
    wa = (data.get("wa") or "").strip()
    location = (data.get("location") or "").strip()
    extra = (data.get("extra") or "").strip()

    loc_line = f"📍 Lokasi: {location}\n" if location else ""
    extra_line = f"📝 Catatan: {extra}\n" if extra else ""

    hooks = {
        "santai": ["Lagi cari yang pas? Cek ini dulu 👇", "Info cepat, siapa tau cocok 👇", "Gas cek detailnya ya 👇"],
        "formal": ["Berikut informasi penawaran kami:", "Rincian penawaran saat ini:", "Detail layanan/produk:"],
        "sales": ["Jangan sampai kelewatan!", "Terbatas! Amankan sekarang!", "Kesempatan bagus—gas sekarang!"]
    }

    benefits_produk = ["Kualitas terjaga", "Cocok untuk kebutuhan harian", "Praktis & siap pakai", "Packing aman"]
    benefits_jasa = ["Pengerjaan rapi & profesional", "Tepat waktu", "Harga transparan", "Bisa konsultasi dulu"]

    ctas = {
        "santai": ["Chat aja ya 👉", "Langsung WA ya 👉", "Siap bantu order 👉"],
        "formal": ["Silakan hubungi:", "Hubungi admin:", "Reservasi melalui:"],
        "sales": ["Order sekarang!", "Amankan slot sekarang!", "Langsung WA!"]
    }

    hashtags = ["#UMKM", "#Promo", "#LocalBrand", "#Indonesia", "#BisnisLokal"]

    benefit = _pick(rng, benefits_produk if biz_type == "produk" else benefits_jasa)
    hook = _pick(rng, hooks.get(tone, hooks["santai"]))
    cta = _pick(rng, ctas.get(tone, ctas["santai"]))
    tagline = _pick(rng, ["✨", "🔥", "📌", "✅", "💡", "⚡"])

    s = _pick(rng, ["A", "B", "C"])

    if template == "promo":
        promo_line = _pick(rng, ["Harga spesial periode terbatas.", "Bisa tanya detail dulu ya.", "Order sekarang, proses mudah."])
        if s == "A":
            caption = f"{hook}\n\n{tagline} {product}\n💰 Mulai {price}\n✅ {benefit}\n{loc_line}{extra_line}📌 {promo_line}\n\n{cta} {wa}\n{_pick(rng, hashtags)} {_pick(rng, hashtags)}"
        elif s == "B":
            caption = f"{tagline} PROMO!\n{product} (mulai {price})\n- {benefit}\n- {promo_line}\n{loc_line}{extra_line}{cta} {wa}"
        else:
            caption = f"{hook}\n🎯 {product} • {price}\n✅ {benefit}\n{loc_line}{extra_line}⏳ {promo_line}\n📲 {cta} {wa}"

    elif template == "new":
        intro = _pick(rng, ["Rilis!", "Baru tersedia!", "New arrival!"])
        if s == "A":
            caption = f"{hook}\n\n✨ {intro} {product}\n💰 Harga: {price}\n✅ {benefit}\n{loc_line}{extra_line}{cta} {wa}\n{_pick(rng, hashtags)}"
        elif s == "B":
            caption = f"✨ {intro}\n{product}\nHarga {price}\nKeunggulan: {benefit}\n{loc_line}{extra_line}{cta} {wa}"
        else:
            caption = f"{hook}\n🆕 {product} — {price}\n✅ {benefit}\n{loc_line}{extra_line}📩 {cta} {wa}"

    elif template == "testi":
        testis = ["\"Respon cepat, prosesnya gampang.\"", "\"Hasilnya rapi, sesuai harapan.\"", "\"Worth it! Bakal order lagi.\""]
        testi = _pick(rng, testis)
        if s == "A":
            caption = f"{hook}\n\n⭐ Testimoni tentang {product}:\n{testi}\n\n💰 Mulai {price}\n✅ {benefit}\n{loc_line}{extra_line}{cta} {wa}"
        elif s == "B":
            caption = f"⭐ TESTIMONI\n{testi}\nProduk: {product}\nMulai: {price}\n{loc_line}{extra_line}{cta} {wa}"
        else:
            caption = f"{hook}\n⭐ {testi}\n📌 {product} • {price}\n✅ {benefit}\n{loc_line}{extra_line}📲 {cta} {wa}"

    else:
        rem = _pick(rng, ["Slot terbatas, amankan dulu ya.", "Bisa booking sekarang biar kebagian.", "Yang butuh cepat, ini waktunya!"])
        if s == "A":
            caption = f"{hook}\n\n⏰ Reminder: {product}\n💰 Mulai {price}\n✅ {benefit}\n{loc_line}{extra_line}📌 {rem}\n\n{cta} {wa}"
        elif s == "B":
            caption = f"⏰ REMINDER\n{product} (mulai {price})\n- {benefit}\n- {rem}\n{loc_line}{extra_line}{cta} {wa}"
        else:
            caption = f"{hook}\n⏰ {product} • {price}\n✅ {benefit}\n{loc_line}{extra_line}📌 {rem}\n📲 {cta} {wa}"

    return caption.strip(), hex(seed)[-6:]

# ==================== EMAIL ====================
def send_email(to_email, subject, body):
    host = (os.getenv("SMTP_HOST") or "").strip()
    port = int(os.getenv("SMTP_PORT") or "587")
    user = (os.getenv("SMTP_USER") or "").strip()
    passwd = (os.getenv("SMTP_PASS") or "").strip()
    mail_from = (os.getenv("SMTP_FROM") or user).strip()

    if not host or not user or not passwd:
        raise RuntimeError("SMTP belum dikonfigurasi.")

    msg = EmailMessage()
    msg["From"] = mail_from
    msg["To"] = to_email
    msg["Subject"] = subject
    msg.set_content(body)

    context = ssl.create_default_context()
    with smtplib.SMTP(host, port) as s:
        s.starttls(context=context)
        s.login(user, passwd)
        s.send_message(msg)

# ==================== ROUTES ====================

@app.route("/")
def landing():
    if is_logged_in():
        return redirect("/admin/dashboard" if session.get("role") == "admin" else "/dashboard")
    return render_template("landing.html")

@app.route("/db-check")
def db_check():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT 1 AS ok;")
    row = cur.fetchone()
    cur.close()
    conn.close()
    return row

@app.route("/init-db")
def init_db():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            email VARCHAR(120) UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role VARCHAR(20) DEFAULT 'employee',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    conn.commit()
    cur.close()
    conn.close()
    return "OK: tabel users siap."



@app.route("/init-products")
def init_products():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS products (
            id SERIAL PRIMARY KEY,
            user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
            name VARCHAR(120) NOT NULL,
            price INTEGER DEFAULT 0,
            is_global BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    conn.commit()
    cur.close()
    conn.close()
    return "OK: tabel products siap."

@app.route("/init-hr-v2")
def init_hr_v2():
    ensure_hr_v2_schema()
    return "OK: HR v2 tables/columns ensured."

# ---------- AUTH ----------
@app.route("/register", methods=["GET", "POST"])
def register():
    if request.method == "GET":
        return render_template("register.html", error=None)

    name = request.form.get("name", "").strip()
    email = request.form.get("email", "").strip().lower()
    password = request.form.get("password", "")

    if not name or not email or not password:
        return render_template("register.html", error="Semua field wajib diisi.")

    pw_hash = generate_password_hash(password)

    try:
        conn = get_conn()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "INSERT INTO users (name, email, password_hash, role) VALUES (%s, %s, %s, 'employee') RETURNING id;",
            (name, email, pw_hash),
        )
        user_id = (cur.fetchone() or {}).get("id")
        conn.commit()
        cur.close()
        conn.close()

        if not user_id:
            return render_template("register.html", error="Gagal membuat user (DB).")

        session["user_id"] = user_id
        session["user_name"] = name
        session["role"] = "employee"
        return redirect("/")
    except Exception:
        return render_template("register.html", error="Email sudah terdaftar / DB error.")

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "GET":
        return render_template("login.html", error=None)

    email = request.form.get("email", "").strip().lower()
    password = request.form.get("password", "")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT id, name, email, password_hash, role FROM users WHERE email=%s;", (email,))
    user = cur.fetchone()
    cur.close()
    conn.close()

    if not user or not check_password_hash(user["password_hash"], password):
        return render_template("login.html", error="Email atau password salah.")

    session["user_id"] = user["id"]
    session["user_name"] = user["name"]
    session["role"] = user.get("role", "user")
    return redirect("/")

@app.route("/logout")
def logout():
    session.clear()
    return redirect("/login")

@app.route("/login/google")
def login_google():
    if not (GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET):
        return "Google OAuth belum dikonfigurasi", 500
    redirect_uri = url_for("google_callback", _external=True)
    return oauth.google.authorize_redirect(redirect_uri)

@app.route("/auth/google/callback")
def google_callback():
    token = oauth.google.authorize_access_token()
    userinfo = token.get("userinfo") or oauth.google.get("https://openidconnect.googleapis.com/v1/userinfo").json()
    email = userinfo.get("email", "").lower()
    name = userinfo.get("name", "User")

    if not email:
        return "Email Google tidak ditemukan", 400

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT id, name, role FROM users WHERE lower(email)=%s LIMIT 1;", (email,))
    u = cur.fetchone()

    if not u:
        rand_pw = hashlib.sha256(f"{email}:{time.time()}".encode()).hexdigest()
        pw_hash = generate_password_hash(rand_pw)
        cur.execute(
            "INSERT INTO users (name, email, password_hash, role) VALUES (%s, %s, %s, 'employee') RETURNING id, name, role;",
            (name, email, pw_hash),
        )
        u = cur.fetchone()

    conn.commit()
    cur.close()
    conn.close()

    session.clear()
    session["user_id"] = u["id"]
    session["user_name"] = u["name"]
    session["role"] = u["role"]
    return redirect("/admin/dashboard" if u["role"] == "admin" else "/dashboard")

@app.route("/forgot", methods=["GET", "POST"])
def forgot_password():
    if request.method == "GET":
        return render_template("forgot_password.html")

    ensure_password_reset_schema()
    email = (request.form.get("email") or "").strip().lower()

    if not email:
        return "Email wajib diisi.", 400

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT id FROM users WHERE lower(email)=%s LIMIT 1;", (email,))
    u = cur.fetchone()
    cur.close()
    conn.close()

    if not u:
        return render_template("forgot_password.html", sent=True)

    otp = f"{random.randint(0, 999999):06d}"
    otp_h = _otp_hash(email, otp)
    expires_at = datetime.utcnow() + timedelta(minutes=10)

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("UPDATE password_reset_otps SET used=TRUE WHERE email=%s AND used=FALSE;", (email,))
    cur.execute(
        "INSERT INTO password_reset_otps (email, otp_hash, expires_at, used) VALUES (%s, %s, %s, FALSE);",
        (email, otp_h, expires_at)
    )
    conn.commit()
    cur.close()
    conn.close()

    try:
        send_email(
            to_email=email,
            subject="UMGAP • Kode OTP Reset Password",
            body=f"Halo,\n\nKode OTP reset password kamu: {otp}\nBerlaku 10 menit.\n\nJika kamu tidak meminta reset, abaikan email ini.",
        )
    except Exception as e:
        return f"Gagal kirim email OTP. Error: {str(e)}", 500

    return render_template("forgot_password.html", sent=True, email=email)

@app.route("/reset", methods=["GET", "POST"])
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
        return "Email, OTP, dan password baru wajib diisi.", 400
    if new_password != confirm:
        return "Konfirmasi password tidak sama.", 400
    if len(new_password) < 6:
        return "Password minimal 6 karakter.", 400

    otp_h = _otp_hash(email, otp)
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute(
        "SELECT id, otp_hash, expires_at, used FROM password_reset_otps WHERE email=%s AND used=FALSE ORDER BY created_at DESC LIMIT 1;",
        (email,)
    )
    row = cur.fetchone()

    if not row:
        cur.close()
        conn.close()
        return "OTP tidak ditemukan / sudah dipakai.", 400

    if datetime.utcnow() > row["expires_at"]:
        cur.execute("UPDATE password_reset_otps SET used=TRUE WHERE id=%s;", (row["id"],))
        conn.commit()
        cur.close()
        conn.close()
        return "OTP sudah kedaluwarsa.", 400

    if not hmac.compare_digest(row["otp_hash"], otp_h):
        cur.close()
        conn.close()
        return "OTP salah.", 400

    pw_hash = generate_password_hash(new_password)
    cur.execute("UPDATE users SET password_hash=%s WHERE lower(email)=%s;", (pw_hash, email))
    cur.execute("UPDATE password_reset_otps SET used=TRUE WHERE id=%s;", (row["id"],))
    conn.commit()
    cur.close()
    conn.close()

    return redirect("/login")

# ---------- DASHBOARD ----------
@app.route("/dashboard")
def dashboard():
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        user_id = session.get("user_id")

        # ambil poin user
        cur.execute("SELECT points_admin, name FROM users WHERE id=%s LIMIT 1;", (user_id,))
        u = cur.fetchone() or {}

        # notifikasi / pengumuman yang belum dibaca user
        cur.execute("""
            SELECT a.id, a.title, a.message, a.created_at
            FROM announcements a
            LEFT JOIN announcement_reads ar
              ON ar.announcement_id = a.id
             AND ar.user_id = %s
            WHERE a.is_active = TRUE
              AND ar.id IS NULL
            ORDER BY a.created_at DESC
            LIMIT 20;
        """, (user_id,))
        announcements = cur.fetchall()

        notif_count = len(announcements)

    finally:
        cur.close()
        conn.close()

    return render_template(
        "dashboard.html",
        user_name=session.get("user_name"),
        points_admin=(u.get("points_admin") or 0),
        notif_count=notif_count,
        announcements=announcements
    )
# ---------- ADMIN ----------
@app.route("/admin")
def admin_home():
    admin_guard()
    return redirect("/admin/dashboard")

@app.route("/admin/dashboard")
def admin_dashboard():
    deny = admin_required()
    if deny:
        return deny

    if os.getenv('RUN_SCHEMA_ON_REQUEST','').lower()=='true':
        ensure_points_schema()
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("SELECT COUNT(*) AS total FROM users WHERE role='employee';")
    total_employees = cur.fetchone()["total"]

    today = date.today()
    cur.execute("SELECT COUNT(*) AS total FROM attendance WHERE work_date=%s AND status='PRESENT';", (today,))
    total_attendance_today = cur.fetchone()["total"]

    cur.execute("SELECT COUNT(*) AS total FROM products;")
    total_products = cur.fetchone()["total"]

    cur.execute("SELECT id, name, email FROM users WHERE role='employee' ORDER BY name ASC;")
    employees = cur.fetchall()

    cur.close()
    conn.close()

    notif_count = get_notif_count()

    return render_template(
        "admin_dashboard.html",
        user_name=session.get("user_name", "Admin"),
        notif_count=int(notif_count or 0),
        total_employees=total_employees,
        total_attendance_today=total_attendance_today,
        total_products=total_products,
        employees=employees
    )

@app.route("/admin/users")
def admin_users():
    admin_guard()
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT u.id, u.name, u.email, u.role, COALESCE(p.daily_salary, 0) AS daily_salary
            FROM users u
            LEFT JOIN payroll_settings p ON p.user_id=u.id
            ORDER BY u.id DESC;
        """)
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()
    return render_template("admin_users.html", rows=rows, error=None)


@app.route("/admin/users/create", methods=["POST"])
def admin_users_create():
    admin_guard()
    name = (request.form.get("name") or "").strip()
    email = (request.form.get("email") or "").strip().lower()
    password = request.form.get("password") or ""
    role = (request.form.get("role") or "employee").strip()
    daily_salary = int(request.form.get("daily_salary") or "0")

    if not name or not email or not password:
        return redirect("/admin/users")

    pw_hash = generate_password_hash(password)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            INSERT INTO users (name, email, password_hash, role)
            VALUES (%s, %s, %s, %s)
            RETURNING id;
        """, (name, email, pw_hash, role))
        row = cur.fetchone() or {}
        uid = row.get("id")

        if uid:
            cur.execute("""
                INSERT INTO payroll_settings (user_id, daily_salary)
                VALUES (%s, %s)
                ON CONFLICT (user_id)
                DO UPDATE SET daily_salary=EXCLUDED.daily_salary, updated_at=CURRENT_TIMESTAMP;
            """, (uid, daily_salary))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/users")


@app.route("/admin/users/update/<int:uid>", methods=["POST"])
def admin_users_update(uid):
    admin_guard()
    name = (request.form.get("name") or "").strip()
    email = (request.form.get("email") or "").strip().lower()
    role = (request.form.get("role") or "employee").strip()
    daily_salary = int(request.form.get("daily_salary") or "0")
    new_password = (request.form.get("new_password") or "").strip()

    conn = get_conn()
    cur = conn.cursor()
    try:
        if new_password:
            pw_hash = generate_password_hash(new_password)
            cur.execute("""
                UPDATE users
                SET name=%s, email=%s, role=%s, password_hash=%s
                WHERE id=%s;
            """, (name, email, role, pw_hash, uid))
        else:
            cur.execute("""
                UPDATE users
                SET name=%s, email=%s, role=%s
                WHERE id=%s;
            """, (name, email, role, uid))

        cur.execute("""
            INSERT INTO payroll_settings (user_id, daily_salary)
            VALUES (%s, %s)
            ON CONFLICT (user_id)
            DO UPDATE SET daily_salary=EXCLUDED.daily_salary, updated_at=CURRENT_TIMESTAMP;
        """, (uid, daily_salary))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/users")


@app.route("/admin/users/delete/<int:uid>", methods=["POST"])
def admin_users_delete(uid):
    if uid == session.get("user_id"):
        return redirect("/admin/users")

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM users WHERE id=%s;", (uid,))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/users")

@app.route("/admin/quick-attendance-links", methods=["GET","POST"])
def admin_quick_attendance_links():
    deny = admin_required()
    if deny:
        return deny

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        if request.method == "POST":
            action = (request.form.get("action") or "").strip()

            if action == "create":
                label = (request.form.get("label") or "").strip() or "Link Absensi"
                token = uuid.uuid4().hex

                cur.execute("""
                    INSERT INTO attendance_links (token, label, created_by, is_active)
                    VALUES (%s,%s,%s,TRUE)
                """, (token,label,session.get("user_id")))

                conn.commit()

            elif action == "toggle":
                link_id = int(request.form.get("id"))

                cur.execute("""
                    UPDATE attendance_links
                    SET is_active = NOT is_active
                    WHERE id=%s
                """,(link_id,))

                conn.commit()

            elif action == "delete":
                link_id = int(request.form.get("id"))
                cur.execute("DELETE FROM attendance_links WHERE id=%s", (link_id,))
                conn.commit()

        cur.execute("""
            SELECT id, token, label, created_at, is_active
            FROM attendance_links
            ORDER BY created_at DESC
            LIMIT 50
        """)

        links = cur.fetchall()

        base_url = request.host_url.rstrip("/")

        return render_template(
            "admin_quick_attendance_links.html",
            links=links,
            base_url=base_url
        )

    finally:
        cur.close()
        conn.close()

# ---------- ADMIN: APPROVAL ATTENDANCE (QUICK + USER LOGIN) ----------
@app.route("/admin/attendance-approval", methods=["GET"])
def admin_attendance_approval():
    deny = admin_required()
    if deny:
        return deny

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                id,
                name_input,
                user_id,
                work_date,
                arrival_type,
                note,
                device_id,
                latitude,
                longitude,
                accuracy,
                photo_path,
                created_at,
                (created_at + interval '7 hour') AS created_at_wib
            FROM attendance_pending
            WHERE status='PENDING'
            ORDER BY created_at DESC
            LIMIT 200;
        """)
        pendings = cur.fetchall()

        cur.execute("""
            SELECT id, name, email
            FROM users
            WHERE role='employee'
            ORDER BY name ASC;
        """)
        employees = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template(
        "admin_attendance_approval.html",
        pendings=pendings,
        employees=employees
    )


@app.route("/admin/attendance-approval/approve", methods=["POST"])
def admin_attendance_approve():
    deny = admin_required()
    if deny:
        return deny

    pending_id = request.form.get("pending_id")
    user_id_form = request.form.get("user_id")
    if not pending_id:
        return redirect("/admin/attendance-approval")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                id,
                name_input,
                user_id,
                work_date,
                arrival_type,
                note,
                device_id,
                latitude,
                longitude,
                accuracy,
                photo_path,
                created_at,
                (created_at + interval '7 hour') AS created_at_wib
            FROM attendance_pending
            WHERE id=%s AND status='PENDING'
            LIMIT 1;
        """, (int(pending_id),))
        p = cur.fetchone()

        if not p:
            return redirect("/admin/attendance-approval")

        target_user_id = p.get("user_id") or (int(user_id_form) if user_id_form else None)
        if not target_user_id:
            return redirect("/admin/attendance-approval")

        created_at_wib = p.get("created_at_wib") or _utc_naive_to_wib_naive(p.get("created_at"))
        work_date = p.get("work_date") or (created_at_wib.date() if created_at_wib else date.today())
        checkin_at = created_at_wib

        arrival_type = (p.get("arrival_type") or "ONTIME").strip().upper()

        if arrival_type in ("ONTIME", "LATE"):
            status = "PRESENT"
        elif arrival_type == "SICK":
            status = "SICK"
        elif arrival_type == "LEAVE":
            status = "LEAVE"
        elif arrival_type == "ABSENT":
            status = "ABSENT"
        else:
            status = "PRESENT"
            arrival_type = "ONTIME"

        latv = p.get("latitude")
        lngv = p.get("longitude")
        map_url = f"https://www.google.com/maps?q={latv},{lngv}" if (latv is not None and lngv is not None) else None
        clean_note = (p.get("note") or "").strip()

        cur.execute("""
            UPDATE attendance_pending
            SET status='APPROVED',
                approved_user_id=%s,
                approved_by=%s,
                approved_at=NOW()
            WHERE id=%s;
        """, (int(target_user_id), session.get("user_id"), int(pending_id)))

        cur.execute("""
            INSERT INTO attendance
                (user_id, work_date, status, arrival_type, note, checkin_at,
                 device_id, latitude, longitude, accuracy, photo_path, map_url)
            VALUES
                (%s, %s, %s, %s, %s, %s,
                 %s, %s, %s, %s, %s, %s)
            ON CONFLICT (user_id, work_date)
            DO UPDATE SET
                status=EXCLUDED.status,
                arrival_type=EXCLUDED.arrival_type,
                note=EXCLUDED.note,
                checkin_at=EXCLUDED.checkin_at,
                device_id=EXCLUDED.device_id,
                latitude=EXCLUDED.latitude,
                longitude=EXCLUDED.longitude,
                accuracy=EXCLUDED.accuracy,
                photo_path=EXCLUDED.photo_path,
                map_url=EXCLUDED.map_url;
        """, (
            int(target_user_id),
            work_date,
            status,
            arrival_type,
            clean_note,
            checkin_at,
            p.get("device_id"),
            latv,
            lngv,
            p.get("accuracy"),
            p.get("photo_path"),
            map_url
        ))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/attendance-approval")


@app.route("/admin/attendance-approval/reject", methods=["POST"])
def admin_attendance_reject():
    deny = admin_required()
    if deny:
        return deny

    pending_id = request.form.get("pending_id")
    reason = (request.form.get("reason") or "").strip()
    if not pending_id:
        return redirect("/admin/attendance-approval")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            UPDATE attendance_pending
            SET status='REJECTED',
                rejected_by=%s,
                rejected_at=NOW(),
                reject_reason=%s
            WHERE id=%s AND status='PENDING';
        """, (session.get("user_id"), reason, int(pending_id)))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/attendance-approval")

# ---------- ATTENDANCE ----------
@app.route("/attendance")
def attendance_page():
    if not is_logged_in():
        return redirect("/login")
    if is_admin():
        return redirect("/admin")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT work_date, arrival_type, status, note, checkin_at FROM attendance WHERE user_id=%s ORDER BY work_date DESC, checkin_at DESC NULLS LAST;", (session["user_id"],))
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("attendance.html", rows=rows)

@app.route("/attendance/add", methods=["POST"])
def attendance_add():
    if not is_logged_in():
        return redirect("/login")

    arrival_type = (request.form.get("arrival_type") or "ONTIME").strip().upper()
    note = (request.form.get("note") or "").strip()
    now = _now_wib_naive_from_form()
    work_date = now.date()

    device_id = (request.form.get("device_id") or "").strip()
    lat = request.form.get("latitude")
    lng = request.form.get("longitude")
    acc = request.form.get("accuracy")

    def _to_float(x):
        try:
            return float(x) if x not in (None, "", "null") else None
        except:
            return None

    lat_f = _to_float(lat)
    lng_f = _to_float(lng)
    acc_f = _to_float(acc)

    # selfie upload
    photo = request.files.get("selfie")
    photo_path = None
    if photo and photo.filename:
        os.makedirs(os.path.join("static", "uploads", "attendance_user"), exist_ok=True)
        today_tag = date.today().strftime("%Y_%m_%d")
        filename = f"att_{today_tag}_{uuid.uuid4().hex}.jpg"
        save_path = os.path.join("static", "uploads", "attendance_user", filename)
        photo.save(save_path)
        photo_path = f"uploads/attendance_user/{filename}"

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # masukkan ke pending (menunggu admin)
        submit_at = _now_wib_naive_from_form()

        cur.execute("""
            INSERT INTO attendance_pending
                (user_id, work_date, arrival_type, note,
                name_input, device_id, latitude, longitude, accuracy, photo_path,
                ip_address, status, created_at)
            VALUES
                (%s,%s,%s,%s,
                %s,%s,%s,%s,%s,%s,
                %s,'PENDING', %s)
        """, (
            session.get("user_id"),
            work_date,
            arrival_type,
            note,
            session.get("user_name"),
            device_id,
            lat_f,
            lng_f,
            acc_f,
            photo_path,
            _public_ip(),
            submit_at
        ))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/attendance")

@app.route("/admin/attendance")
def admin_attendance():
    r = admin_guard()
    if r:
        return r

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT id, name, email FROM users WHERE role='employee' ORDER BY name ASC;")
    employees = cur.fetchall()
    cur.execute("""
        SELECT a.work_date, a.arrival_type, a.status, a.note, a.checkin_at, u.name AS employee_name
        FROM attendance a
        JOIN users u ON u.id=a.user_id
        ORDER BY a.work_date DESC, a.checkin_at DESC NULLS LAST
        LIMIT 80;
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("admin_attendance.html", employees=employees, rows=rows)

@app.route("/admin/attendance/add", methods=["POST"])
def admin_attendance_add():
    deny = admin_required()
    if deny:
        return deny

    user_id = int(request.form["user_id"])
    arrival_type = (request.form.get("arrival_type") or "ONTIME").strip().upper()
    note = (request.form.get("note") or "").strip()
    manual_checkin = (request.form.get("manual_checkin") or "").strip()

    if arrival_type in ("SICK", "LEAVE", "ABSENT"):
        status = arrival_type
    else:
        status = "PRESENT"

    if user_id == session.get("user_id"):
        now = _now_wib_naive_from_form()
    else:
        now = _parse_manual_wib_naive(manual_checkin) or _now_wib_naive_from_form()

    work_date = now.date()
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT id FROM attendance WHERE user_id=%s AND work_date=%s LIMIT 1;", (user_id, work_date))
    existing = cur.fetchone()

    if existing:
        cur.execute("UPDATE attendance SET status=%s, arrival_type=%s, note=%s, checkin_at=%s WHERE id=%s;",
            (status, arrival_type, note, now, existing["id"]))
    else:
        cur.execute("INSERT INTO attendance (user_id, work_date, status, arrival_type, note, created_at, checkin_at) VALUES (%s, %s, %s, %s, %s, %s, %s);",
            (user_id, work_date, status, arrival_type, note, now, now))

    conn.commit()
    cur.close()
    conn.close()
    return redirect("/admin/attendance")

# ---------- QUICK ATTENDANCE (PUBLIC, NO LOGIN) ----------
@app.route("/quick-attendance/<token>", methods=["GET"])
def quick_attendance_form(token):
    if not is_token_valid(token):
        return "Link absensi tidak valid / sudah nonaktif.", 404
    return render_template("quick_attendance.html", token=token)

@app.route("/quick-attendance/<token>/submit", methods=["POST"])
def quick_attendance_submit(token):
    if not is_token_valid(token):
        return "Link absensi tidak valid / sudah nonaktif.", 404

    name_input = (request.form.get("name_input") or "").strip()
    device_id = (request.form.get("device_id") or "").strip()
    lat = request.form.get("latitude")
    lng = request.form.get("longitude")
    acc = request.form.get("accuracy")

    if not name_input:
        return render_template("quick_attendance.html", token=token, error="Nama wajib diisi.")
    if not device_id:
        return render_template("quick_attendance.html", token=token, error="Device tidak terdeteksi. Coba refresh halaman.")

    # selfie file
    photo = request.files.get("selfie")
    if not photo or photo.filename == "":
        return render_template("quick_attendance.html", token=token, error="Selfie wajib diambil.")

    # bersihin foto lama (harian)
    cleanup_old_quick_attendance_photos()

    # simpan file
    _ensure_upload_dir()
    today_tag = date.today().strftime("%Y_%m_%d")
    filename = f"qa_{today_tag}_{uuid.uuid4().hex}.jpg"
    save_path = os.path.join(UPLOAD_QA_DIR, filename)
    photo.save(save_path)

    # path untuk ditampilkan via web
    photo_path = f"uploads/quick_attendance/{filename}"

    # parse angka (boleh kosong)
    def _to_float(x):
        try:
            return float(x) if x not in (None, "", "null") else None
        except:
            return None

    lat_f = _to_float(lat)
    lng_f = _to_float(lng)
    acc_f = _to_float(acc)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        submit_at = _now_wib_naive_from_form()

        cur.execute("""
            INSERT INTO attendance_pending
            (name_input, device_id, latitude, longitude, accuracy, photo_path, ip_address, status, created_at)
            VALUES
            (%s, %s, %s, %s, %s, %s, %s, 'PENDING', %s)
            RETURNING id;
        """, (
            name_input,
            device_id,
            lat_f,
            lng_f,
            acc_f,
            photo_path,
            _public_ip(),
            submit_at
        ))
        row = cur.fetchone() or {}
        conn.commit()
        pending_id = row.get("id")
    except psycopg2.IntegrityError:
        conn.rollback()
        # biasanya kena UNIQUE uq_pending_device_per_day
        return render_template(
            "quick_attendance.html",
            token=token,
            error="Perangkat ini sudah melakukan absensi hari ini."
        )
    finally:
        cur.close()
        conn.close()

    return render_template(
        "quick_attendance.html",
        token=token,
        success=f"Absensi terkirim (ID #{pending_id}). Menunggu approval admin."
    )

# ---------- PAYROLL ----------
def count_workdays_only_sunday_off(start_date, end_date):
    d = start_date
    n = 0
    while d < end_date:
        if d.weekday() != 6:
            n += 1
        d = d.fromordinal(d.toordinal() + 1)
    return n

@app.route("/admin/payroll")
def admin_payroll():
    deny = admin_required()
    if deny:
        return deny

    month = request.args.get("month")
    if not month:
        today = date.today()
        month = f"{today.year:04d}-{today.month:02d}"

    year = int(month.split("-")[0])
    mon = int(month.split("-")[1])
    start_date = date(year, mon, 1)
    end_date = date(year + 1, 1, 1) if mon == 12 else date(year, mon + 1, 1)
    WORKDAYS = count_workdays_only_sunday_off(start_date, end_date)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        SELECT u.id, u.name, COALESCE(p.daily_salary, 0) AS daily_salary, COALESCE(p.monthly_salary, 0) AS monthly_salary,
            COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END), 0) AS days_present,
            COALESCE(SUM(CASE WHEN a.status='SICK' THEN 1 ELSE 0 END), 0) AS days_sick,
            COALESCE(SUM(CASE WHEN a.status='LEAVE' THEN 1 ELSE 0 END), 0) AS days_leave,
            COALESCE(SUM(CASE WHEN a.status='ABSENT' THEN 1 ELSE 0 END), 0) AS days_absent
        FROM users u
        LEFT JOIN payroll_settings p ON p.user_id = u.id
        LEFT JOIN attendance a ON a.user_id = u.id AND a.work_date >= %s AND a.work_date < %s
        WHERE u.role = 'employee'
        GROUP BY u.id, u.name, p.daily_salary, p.monthly_salary
        ORDER BY u.name ASC;
    """, (start_date, end_date))

    rows = cur.fetchall()
    cur.close()
    conn.close()

    result = []
    for r in rows:
        daily_salary = int(r.get("daily_salary") or 0)
        monthly_salary = int(r.get("monthly_salary") or 0)
        if daily_salary == 0 and monthly_salary > 0 and WORKDAYS > 0:
            daily_salary = int(round(monthly_salary / WORKDAYS))
        days_present = int(r.get("days_present") or 0)
        result.append({
            "id": r["id"], "name": r["name"], "daily_salary": daily_salary, "workdays": int(WORKDAYS),
            "days_present": days_present, "days_sick": int(r.get("days_sick") or 0),
            "days_leave": int(r.get("days_leave") or 0), "days_absent": int(r.get("days_absent") or 0),
            "salary_paid": int(daily_salary * days_present),
        })

    return render_template("admin_payroll.html", month=month, rows=result, workdays=int(WORKDAYS))

# ---------- SALES ----------
@app.route("/sales", methods=["GET", "POST"])
def sales_user():
    if not is_logged_in():
        return redirect("/login")
    if session.get("role") == "admin":
        return redirect("/admin/sales")

    if request.method == "POST":
        product_id = request.form.get("product_id")
        qty = request.form.get("qty") or "0"
        note = (request.form.get("note") or "").strip()

        try:
            product_id = int(product_id)
            qty_int = int(qty)
        except Exception:
            return redirect("/sales")

        if qty_int <= 0:
            return redirect("/sales")

        conn = get_conn()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        try:
            # validasi produk global
            cur.execute("""
                SELECT id, name
                FROM products
                WHERE id=%s AND is_global=TRUE
                LIMIT 1;
            """, (product_id,))
            ok = cur.fetchone()

            if not ok:
                return redirect("/sales")

            cur.execute("""
                INSERT INTO sales_submissions (user_id, product_id, qty, note, status)
                VALUES (%s, %s, %s, %s, 'PENDING');
            """, (session["user_id"], product_id, qty_int, note))
            conn.commit()
        finally:
            cur.close()
            conn.close()

        return redirect("/sales")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # PRODUK untuk dropdown
        cur.execute("""
            SELECT id, name, price
            FROM products
            WHERE is_global=TRUE
            ORDER BY id DESC;
        """)
        products = cur.fetchall()

        # RIWAYAT submit user
        cur.execute("""
            SELECT
                s.id,
                s.qty,
                s.note,
                s.status,
                s.admin_note,
                s.created_at,
                (s.created_at + interval '7 hour') AS created_at_wib,
                COALESCE(p.name, '-') AS product_name
            FROM sales_submissions s
            LEFT JOIN products p ON p.id = s.product_id
            WHERE s.user_id=%s
            ORDER BY s.id DESC
            LIMIT 50;
        """, (session["user_id"],))
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template("sales.html", products=products, rows=rows)


@app.route("/admin/sales")
def admin_sales():
    admin_guard()
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                s.id,
                s.qty,
                s.note,
                s.status,
                s.admin_note,
                s.created_at,
                (s.created_at + interval '7 hour') AS created_at_wib,
                u.name AS employee_name,
                COALESCE(p.name, '-') AS product_name
            FROM sales_submissions s
            JOIN users u ON u.id = s.user_id
            LEFT JOIN products p ON p.id = s.product_id
            ORDER BY
                (CASE WHEN s.status='PENDING' THEN 0 ELSE 1 END),
                s.created_at DESC
            LIMIT 300;
        """)
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template("admin_sales.html", rows=rows)


@app.route("/admin/sales/approve/<int:sid>", methods=["POST"])
def admin_sales_approve(sid):
    admin_guard()
    admin_note = (request.form.get("admin_note") or "").strip()

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE sales_submissions
            SET status='APPROVED',
                admin_note=%s,
                decided_at=CURRENT_TIMESTAMP,
                decided_by=%s
            WHERE id=%s;
        """, (admin_note, session["user_id"], sid))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/sales")


@app.route("/admin/sales/reject/<int:sid>", methods=["POST"])
def admin_sales_reject(sid):
    admin_guard()
    admin_note = (request.form.get("admin_note") or "").strip()

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE sales_submissions
            SET status='REJECTED',
                admin_note=%s,
                decided_at=CURRENT_TIMESTAMP,
                decided_by=%s
            WHERE id=%s;
        """, (admin_note, session["user_id"], sid))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/sales")


@app.route("/admin/sales/monitor")
def admin_sales_monitor():
    admin_guard()
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                u.id,
                u.name AS employee_name,
                COALESCE(SUM(s.qty), 0) AS total_qty
            FROM users u
            LEFT JOIN sales_submissions s
                ON s.user_id = u.id
               AND s.status='APPROVED'
            WHERE u.role='employee'
            GROUP BY u.id, u.name
            ORDER BY total_qty DESC, u.name ASC;
        """)
        summary = cur.fetchall()

        cur.execute("""
            SELECT
                s.created_at,
                (s.created_at + interval '7 hour') AS created_at_wib,
                u.name AS employee_name,
                COALESCE(p.name, '-') AS product_name,
                s.qty,
                s.status,
                s.note,
                s.admin_note
            FROM sales_submissions s
            JOIN users u ON u.id = s.user_id
            LEFT JOIN products p ON p.id = s.product_id
            ORDER BY s.created_at DESC
            LIMIT 200;
        """)
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template("admin_sales_monitor.html", summary=summary, rows=rows)

# ---------- STATS ----------
@app.route("/admin/stats")
def admin_stats():
    admin_guard()

    month = request.args.get("month")
    if not month:
        today = date.today()
        month = f"{today.year:04d}-{today.month:02d}"

    year = int(month.split("-")[0])
    mon = int(month.split("-")[1])
    start_date = date(year, mon, 1)
    end_date = date(year + 1, 1, 1) if mon == 12 else date(year, mon + 1, 1)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)  # <<< FIX DI SINI
    try:
        cur.execute("""
            SELECT u.id, u.name AS employee_name,
                COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END), 0) AS present_days,
                COALESCE(SUM(CASE WHEN a.arrival_type='LATE' THEN 1 ELSE 0 END), 0) AS late_days,
                COALESCE(SUM(CASE WHEN a.status='SICK' THEN 1 ELSE 0 END), 0) AS sick_days,
                COALESCE(SUM(CASE WHEN a.status='LEAVE' THEN 1 ELSE 0 END), 0) AS leave_days,
                COALESCE(SUM(CASE WHEN a.status='ABSENT' THEN 1 ELSE 0 END), 0) AS absent_days
            FROM users u
            LEFT JOIN attendance a
                ON a.user_id=u.id
                AND a.work_date >= %s AND a.work_date < %s
            WHERE u.role='employee'
            GROUP BY u.id, u.name
            ORDER BY u.name ASC;
        """, (start_date, end_date))
        att = cur.fetchall()

        cur.execute("""
            SELECT u.id, COALESCE(SUM(s.qty), 0) AS sales_qty
            FROM users u
            LEFT JOIN sales_submissions s
                ON s.user_id=u.id
                AND s.created_at >= %s AND s.created_at < %s
            WHERE u.role='employee'
            GROUP BY u.id;
        """, (start_date, end_date))
        sales = cur.fetchall()

    finally:
        cur.close()
        conn.close()

    sales_map = {r["id"]: int(r["sales_qty"] or 0) for r in sales}

    rows = []
    totals = {"present": 0, "late": 0, "sick": 0, "leave": 0, "absent": 0, "sales": 0}

    for r in att:
        row = {
            "employee_name": r["employee_name"],
            "present_days": int(r["present_days"] or 0),
            "late_days": int(r["late_days"] or 0),
            "sick_days": int(r["sick_days"] or 0),
            "leave_days": int(r["leave_days"] or 0),
            "absent_days": int(r["absent_days"] or 0),
            "sales_qty": sales_map.get(r["id"], 0),
        }
        totals["present"] += row["present_days"]
        totals["late"] += row["late_days"]
        totals["sick"] += row["sick_days"]
        totals["leave"] += row["leave_days"]
        totals["absent"] += row["absent_days"]
        totals["sales"] += row["sales_qty"]
        rows.append(row)

    return render_template("admin_stats.html", month=month, rows=rows, totals=totals)

# --------- INVOICE ---------
@app.route("/invoice/new", methods=["GET", "POST"])
def invoice_new_user():
    if not is_logged_in():
        return redirect("/login")
    if session.get("role") == "admin":
        return redirect("/admin/invoice/new")

    ensure_invoice_schema()

    if request.method == "POST":
        return _save_invoice(is_admin_mode=False)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, name, price
            FROM products
            WHERE is_global=TRUE
            ORDER BY name ASC;
        """)
        products = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template(
        "invoice_form.html",
        products=products,
        is_admin_mode=False
    )


@app.route("/admin/invoice/new", methods=["GET", "POST"])
def invoice_new_admin():
    deny = admin_required()
    if deny:
        return deny

    ensure_invoice_schema()

    if request.method == "POST":
        return _save_invoice(is_admin_mode=True)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, name, price
            FROM products
            WHERE is_global=TRUE
            ORDER BY name ASC;
        """)
        products = cur.fetchall()

        cur.execute("""
            SELECT id, name, email
            FROM users
            WHERE role='employee'
            ORDER BY name ASC;
        """)
        employees = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template(
        "invoice_form.html",
        products=products,
        employees=employees,
        is_admin_mode=True
    )

@app.route("/invoice/<int:invoice_id>")
def invoice_view(invoice_id):
    if not is_logged_in():
        return redirect("/login")

    ensure_invoice_schema()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT i.*, u.name AS created_by_name
            FROM invoices i
            JOIN users u ON u.id = i.created_by
            WHERE i.id=%s
            LIMIT 1;
        """, (invoice_id,))
        invoice = cur.fetchone()
        if not invoice:
            abort(404)

        cur.execute("""
            SELECT id, product_id, product_name, qty, price, subtotal
            FROM invoice_items
            WHERE invoice_id=%s
            ORDER BY id ASC;
        """, (invoice_id,))
        items = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    invoice["created_at_wib"] = _utc_naive_to_wib_string(invoice.get("created_at"))

    return render_template("invoice_print.html", invoice=invoice, items=items)


@app.route("/invoice/<int:invoice_id>/json")
def invoice_json(invoice_id):
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401

    ensure_invoice_schema()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT *
            FROM invoices
            WHERE id=%s
            LIMIT 1;
        """, (invoice_id,))
        invoice = cur.fetchone()
        if not invoice:
            return jsonify({"ok": False, "error": "Invoice tidak ditemukan"}), 404

        cur.execute("""
            SELECT product_name, qty, price, subtotal
            FROM invoice_items
            WHERE invoice_id=%s
            ORDER BY id ASC;
        """, (invoice_id,))
        items = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return jsonify({
        "ok": True,
        "invoice": invoice,
        "items": items
    })

@app.route("/invoice/<int:invoice_id>/pdf")
def invoice_pdf(invoice_id):
    if not is_logged_in():
        return redirect("/login")

    ensure_invoice_schema()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT i.*, u.name AS created_by_name
            FROM invoices i
            JOIN users u ON u.id = i.created_by
            WHERE i.id=%s
            LIMIT 1;
        """, (invoice_id,))
        invoice = cur.fetchone()
        if not invoice:
            abort(404)

        cur.execute("""
            SELECT id, product_id, product_name, qty, price, subtotal
            FROM invoice_items
            WHERE invoice_id=%s
            ORDER BY id ASC;
        """, (invoice_id,))
        items = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    invoice["created_at_wib"] = _utc_naive_to_wib_string(invoice.get("created_at"))
    invoice["paid_at_wib"]    = _utc_naive_to_wib_string(invoice.get("paid_at")) if invoice.get("paid_at") else None
    invoice.setdefault("is_paid", True)
    invoice.setdefault("discount", 0)
    invoice.setdefault("customer_phone", "")
    invoice.setdefault("company_name", "")
    invoice.setdefault("company_logo_path", None)

    html = render_template("invoice_pdf.html", invoice=invoice, items=items)

    # 1) coba weasyprint dulu
    try:
        from weasyprint import HTML
        pdf_bytes = HTML(string=html, base_url=request.host_url).write_pdf()
        return send_file(
            io.BytesIO(pdf_bytes),
            mimetype="application/pdf",
            as_attachment=True,
            download_name=f"{invoice['invoice_no']}.pdf"
        )
    except Exception as e_weasy:
        # 2) fallback ke xhtml2pdf
        try:
            from xhtml2pdf import pisa

            pdf_io = io.BytesIO()
            pisa_status = pisa.CreatePDF(
                io.StringIO(html),
                dest=pdf_io
            )

            if pisa_status.err:
                return f"Gagal membuat PDF. WeasyPrint error: {e_weasy} | xhtml2pdf juga gagal.", 500

            pdf_io.seek(0)
            return send_file(
                pdf_io,
                mimetype="application/pdf",
                as_attachment=True,
                download_name=f"{invoice['invoice_no']}.pdf"
            )
        except Exception as e_xhtml:
            return (
                "Gagal membuat PDF.<br>"
                f"WeasyPrint error: {e_weasy}<br>"
                f"xhtml2pdf error: {e_xhtml}",
                500
            )

# ---------- PRODUCTS ----------
@app.route("/products")
def products():
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, name, price, user_id, is_global
            FROM products
            ORDER BY id DESC;
        """)
        rows = cur.fetchall()
        return render_template("products.html", products=rows, error=None)
    finally:
        cur.close()
        conn.close()


@app.route("/products/add", methods=["POST"])
def products_add():
    if not is_logged_in():
        return redirect("/login")

    name = (request.form.get("name") or "").strip()
    price = (request.form.get("price") or "0").strip()
    if not name:
        return redirect("/products")

    try:
        price_int = int(price)
        if price_int < 0:
            price_int = 0
    except ValueError:
        price_int = 0

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO products (user_id, name, price, is_global)
            VALUES (%s, %s, %s, TRUE);
        """, (session["user_id"], name, price_int))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/products")


@app.route("/products/delete/<int:pid>")
def products_delete(pid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM products WHERE id=%s;", (pid,))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/products")


@app.route("/products/edit/<int:pid>", methods=["GET", "POST"])
def products_edit(pid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, name, price, user_id, is_global
            FROM products
            WHERE id=%s
            LIMIT 1;
        """, (pid,))
        product = cur.fetchone()
        if not product:
            abort(404)

        if request.method == "GET":
            return render_template("product_edit.html", product=product, error=None)

        name = (request.form.get("name") or "").strip()
        price = (request.form.get("price") or "0").strip()
        if not name:
            return render_template("product_edit.html", product=product, error="Nama produk wajib diisi.")

        try:
            price_int = int(price)
            if price_int < 0:
                price_int = 0
        except ValueError:
            price_int = 0

        # update
        cur2 = conn.cursor()
        try:
            cur2.execute("UPDATE products SET name=%s, price=%s WHERE id=%s;", (name, price_int, pid))
            conn.commit()
        finally:
            cur2.close()

        return redirect("/products")
    finally:
        cur.close()
        conn.close()

# ---------- CONTENT ----------
@app.route("/init-content")
def init_content():
    conn = get_conn()
    cur = conn.cursor()
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
    conn.commit()
    cur.close()
    conn.close()
    return "OK: tabel content_plans siap."

@app.route("/content", methods=["GET", "POST"])
def content():
    if not is_logged_in():
        return redirect("/login")

    user_id = session.get("user_id")

    if request.method == "POST":
        plan_date = (request.form.get("plan_date") or "").strip()
        platform = (request.form.get("platform") or "").strip()
        content_type = (request.form.get("content_type") or "").strip()
        notes = (request.form.get("notes") or "").strip()

        if plan_date and platform and content_type:
            conn = get_conn()
            cur = conn.cursor()
            try:
                cur.execute("""
                    INSERT INTO content_plans (user_id, plan_date, platform, content_type, notes, is_done)
                    VALUES (%s, %s, %s, %s, %s, FALSE);
                """, (user_id, plan_date, platform, content_type, notes))
                conn.commit()
            finally:
                cur.close()
                conn.close()

        return redirect("/content")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                id,
                user_id,
                plan_date,
                platform,
                content_type,
                notes,
                is_done,
                created_at
            FROM content_plans
            WHERE user_id = %s
            ORDER BY
                is_done ASC,
                plan_date ASC,
                id DESC;
        """, (user_id,))
        plans = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template("content.html", plans=plans)

@app.route("/content/add", methods=["POST"])
def content_add():
    if not is_logged_in():
        return redirect("/login")
    plan_date = request.form.get("plan_date")
    platform = (request.form.get("platform") or "").strip()
    content_type = (request.form.get("content_type") or "").strip()
    notes = (request.form.get("notes") or "").strip()
    if not plan_date or not platform or not content_type:
        return redirect("/content")
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("INSERT INTO content_plans (user_id, plan_date, platform, content_type, notes) VALUES (%s, %s, %s, %s, %s);",
        (session["user_id"], plan_date, platform, content_type, notes))
    conn.commit()
    cur.close()
    conn.close()
    return redirect("/content")

@app.route("/content/done/<int:cid>")
def content_done(cid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE content_plans
            SET is_done = TRUE
            WHERE id = %s AND user_id = %s;
        """, (cid, session.get("user_id")))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/content")


@app.route("/content/undo/<int:cid>")
def content_undo(cid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE content_plans
            SET is_done = FALSE
            WHERE id = %s AND user_id = %s;
        """, (cid, session.get("user_id")))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/content")


@app.route("/content/delete/<int:cid>")
def content_delete(cid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            DELETE FROM content_plans
            WHERE id = %s AND user_id = %s;
        """, (cid, session.get("user_id")))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/content")

# ---------- CAPTION ----------
@app.route("/caption", methods=["GET", "POST"])
def caption():
    if not is_logged_in():
        return redirect("/login")

    form = {"template": "promo", "biz_type": "produk", "tone": "santai", "product": "", "price": "", "wa": "", "location": "", "extra": ""}
    caption_text = None

    if request.method == "POST":
        form["template"] = request.form.get("template", "promo")
        form["biz_type"] = request.form.get("biz_type", "produk")
        form["tone"] = request.form.get("tone", "santai")
        form["product"] = request.form.get("product", "").strip()
        form["price"] = request.form.get("price", "").strip()
        form["wa"] = request.form.get("wa", "").strip()
        form["location"] = request.form.get("location", "").strip()
        form["extra"] = request.form.get("extra", "").strip()

        nama = form["product"]
        harga = rupiah(form["price"])
        loc = f"\n📍 Lokasi: {form['location']}" if form["location"] else ""
        extra = f"\nℹ️ Catatan: {form['extra']}" if form["extra"] else ""

        benefit = pick(["Kualitas terjaga", "Cocok untuk kebutuhan harian", "Praktis dan mudah digunakan", "Bisa untuk hadiah"])
        hook = pick(["Lagi cari yang pas buat kamu?", "Biar makin gampang, cek ini dulu 👇", "Yang ini lagi banyak dicari loh!"])
        cta = pick(["Chat aja ya 👉", "Langsung DM/WA ya 👉", "Pesan sekarang 👉"])

        if form["template"] == "promo":
            caption_text = f"{hook}\n🎯 {nama}\n💰 Mulai {harga}\n✅ {benefit}\n📌 Harga spesial{loc}{extra}\n\n{cta} {form['wa']}"
        elif form["template"] == "new":
            caption_text = f"{hook}\n✨ Rilis: {nama}\n💰 Harga: {harga}\n✅ {benefit}{loc}{extra}\n\n{cta} {form['wa']}"
        elif form["template"] == "testi":
            testi = pick(["\"Pelayanannya cepat dan responsif.\"", "\"Hasilnya sesuai ekspektasi, recommended!\"", "\"Worth it!\""])
            caption_text = f"{hook}\n⭐ Testimoni: {testi}\n💰 Mulai {harga}\n✅ {benefit}{loc}{extra}\n\n{cta} {form['wa']}"
        else:
            caption_text = f"{hook}\n⏰ Reminder: {nama}\n💰 Mulai {harga}\n✅ {benefit}\n📌 Slot terbatas{loc}{extra}\n\n{cta} {form['wa']}"

    return render_template("caption.html", caption=caption_text, form=form)

# ==================== AI PENGHITUNG HPP (v2 — matang) ====================

import json as _json

def _parse_materials(materials_raw):
    """Parse & validasi list bahan. Return (list[dict], total_material_cost)."""
    if isinstance(materials_raw, str):
        try:
            materials_raw = _json.loads(materials_raw)
        except Exception:
            materials_raw = []
    if not isinstance(materials_raw, list):
        materials_raw = []

    rows = []
    total = 0
    for m in materials_raw:
        name = str(m.get("name") or "").strip()
        unit = str(m.get("unit") or "").strip()
        try:
            cost = int(m.get("cost") or 0)
        except Exception:
            cost = 0
        if cost < 0:
            cost = 0
        total += cost
        rows.append({"name": name, "unit": unit, "cost": cost})
    return rows, total


def _hpp_calculate(product_name, materials_raw, labor_cost_raw, overhead_cost_raw, output_qty_raw):
    """Hitung HPP. Kembalikan dict result lengkap."""
    try:
        labor_cost = max(0, int(labor_cost_raw or 0))
    except Exception:
        labor_cost = 0
    try:
        overhead_cost = max(0, int(overhead_cost_raw or 0))
    except Exception:
        overhead_cost = 0
    try:
        output_qty = max(1, int(output_qty_raw or 1))
    except Exception:
        output_qty = 1

    material_rows, total_material_cost = _parse_materials(materials_raw)
    total_cost = total_material_cost + labor_cost + overhead_cost
    hpp_per_unit = round(total_cost / output_qty) if output_qty > 0 else 0

    # Saran harga jual (margin 20%, 40%, 60%)
    price_suggestions = {
        "safe":   round(hpp_per_unit * 1.20),
        "normal": round(hpp_per_unit * 1.40),
        "ideal":  round(hpp_per_unit * 1.60),
    }

    return {
        "product_name":        product_name,
        "materials":           material_rows,
        "total_material_cost": total_material_cost,
        "labor_cost":          labor_cost,
        "overhead_cost":       overhead_cost,
        "output_qty":          output_qty,
        "total_cost":          total_cost,
        "hpp_per_unit":        hpp_per_unit,
        "price_suggestions":   price_suggestions,
    }


def _hpp_ai_prompt(data):
    """Bangun prompt AI review HPP yang kaya konteks."""
    mat_lines = "\n".join(
        ("  - " + m["name"] + " (" + (m["unit"] or "-") + "): Rp " + str(m["cost"]))
        for m in data["materials"]
    ) or "  (tidak ada bahan yang diinput)"

    return f"""Kamu adalah konsultan keuangan UMKM Indonesia yang ahli dalam menghitung HPP (Harga Pokok Produksi).

Data HPP yang disubmit user:
Produk: "{data['product_name']}"
Bahan baku:
{mat_lines}
Biaya tenaga kerja (per batch): Rp {data['labor_cost']:,}
Biaya overhead (per batch): Rp {data['overhead_cost']:,}
Jumlah produk jadi: {data['output_qty']} unit
Total biaya produksi: Rp {data['total_cost']:,}
HPP per unit: Rp {data['hpp_per_unit']:,}

Tugasmu:
1. Analisis kelengkapan dan keakuratan input.
2. Sebutkan biaya yang mungkin terlewat (contoh: kemasan, ongkir bahan, penyusutan alat, biaya air/listrik, dsb.).
3. Evaluasi apakah HPP per unit terlihat realistis untuk jenis produk tersebut.
4. Berikan saran harga jual yang optimal beserta alasannya.
5. Jika ada potensi efisiensi biaya, sebutkan.

Format jawaban WAJIB:
- Analisis: [2-3 kalimat evaluasi keseluruhan]
- Yang kurang spesifik: [list poin dengan bullet]
- Biaya yang mungkin terlewat: [list poin]
- Saran: [rekomendasi konkret, termasuk range harga jual dan alasannya]

Jawab dalam Bahasa Indonesia yang ramah dan mudah dipahami pelaku UMKM. Maksimal 350 kata.""".replace(",", ",")


@app.route("/hpp-ai", methods=["GET", "POST"])
def hpp_ai_page():
    if not is_logged_in():
        return redirect("/login")

    result = None
    ai_notes = None
    form_data = {
        "product_name": "",
        "labor_cost":   "",
        "overhead_cost":"",
        "output_qty":   "",
        "materials_json": "[]",
    }

    if request.method == "POST":
        product_name   = (request.form.get("product_name")   or "").strip()
        labor_cost_raw = (request.form.get("labor_cost")      or "0").strip()
        overhead_raw   = (request.form.get("overhead_cost")   or "0").strip()
        qty_raw        = (request.form.get("output_qty")      or "1").strip()
        mats_json      = (request.form.get("materials_json")  or "[]").strip()

        form_data = {
            "product_name":  product_name,
            "labor_cost":    labor_cost_raw,
            "overhead_cost": overhead_raw,
            "output_qty":    qty_raw,
            "materials_json": mats_json,
        }

        if not product_name:
            return render_template("hpp_ai.html", result=None, ai_notes=None,
                                   form_data=form_data, error="Nama produk wajib diisi.")

        result = _hpp_calculate(product_name, mats_json, labor_cost_raw, overhead_raw, qty_raw)

        if oa_client:
            try:
                prompt = _hpp_ai_prompt(result)
                resp = oa_client.chat.completions.create(
                    model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.35,
                    max_tokens=500,
                )
                ai_notes = (resp.choices[0].message.content or "").strip()
            except Exception as ex:
                ai_notes = f"AI tidak tersedia saat ini ({type(ex).__name__}). Hasil HPP tetap valid."

    return render_template(
        "hpp_ai.html",
        result=result,
        ai_notes=ai_notes,
        form_data=form_data,
    )


@app.route("/api/hpp-calculate", methods=["POST"])
def api_hpp_calculate():
    """Pure server-side HPP calculation — no AI, fast, untuk validasi JS."""
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Silakan login dulu."}), 401

    data = request.get_json(silent=True) or {}
    try:
        result = _hpp_calculate(
            product_name   = (data.get("product_name") or "").strip(),
            materials_raw  = data.get("materials") or [],
            labor_cost_raw = data.get("labor_cost") or 0,
            overhead_cost_raw = data.get("overhead_cost") or 0,
            output_qty_raw = data.get("output_qty") or 1,
        )
        return jsonify({"ok": True, "result": result})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/api/hpp-ai-review", methods=["POST"])
def api_hpp_ai_review():
    """AI review endpoint — dipanggil async dari frontend setelah kalkulasi."""
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Silakan login dulu."}), 401

    data = request.get_json(silent=True) or {}
    product_name  = (data.get("product_name") or "").strip()
    materials     = data.get("materials") or []
    labor_cost    = int(data.get("labor_cost")    or 0)
    overhead_cost = int(data.get("overhead_cost") or 0)
    output_qty    = max(1, int(data.get("output_qty") or 1))
    total_cost    = int(data.get("total_cost")    or 0)
    hpp_per_unit  = int(data.get("hpp_per_unit")  or 0)

    if not product_name:
        return jsonify({"ok": False, "error": "Nama produk wajib diisi."}), 400
    if not oa_client:
        return jsonify({"ok": False, "error": "AI belum dikonfigurasi (OPENAI_API_KEY missing)."}), 500

    calc_data = {
        "product_name": product_name,
        "materials":    [{"name": str(m.get("name","")).strip(),
                          "unit": str(m.get("unit","")).strip(),
                          "cost": int(m.get("cost") or 0)} for m in materials],
        "labor_cost":   labor_cost,
        "overhead_cost":overhead_cost,
        "output_qty":   output_qty,
        "total_cost":   total_cost or (sum(int(m.get("cost",0)) for m in materials) + labor_cost + overhead_cost),
        "hpp_per_unit": hpp_per_unit,
    }

    try:
        prompt = _hpp_ai_prompt(calc_data)
        resp = oa_client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            messages=[{"role": "user", "content": prompt}],
            temperature=0.35,
            max_tokens=500,
        )
        review = (resp.choices[0].message.content or "").strip()
        return jsonify({"ok": True, "review": review})
    except Exception as e:
        return jsonify({"ok": False, "error": f"AI gagal: {type(e).__name__}: {str(e)}"}), 500

#-----NOTIFICATION-------
@app.route("/notifications")
def notifications():
    if "user_id" not in session:
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        SELECT id, title, message, created_at
        FROM announcements
        WHERE is_active = TRUE
        ORDER BY created_at DESC
        LIMIT 50;
    """)
    announcements = cur.fetchall()
    cur.close()
    conn.close()

    return render_template("notifications.html", announcements=announcements)

@app.route("/notifications/read/<int:ann_id>")
def mark_notification_read(ann_id):
    if "user_id" not in session:
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO announcement_reads (announcement_id, user_id)
        VALUES (%s, %s)
        ON CONFLICT DO NOTHING
    """, (ann_id, session["user_id"]))

    conn.commit()
    conn.close()

    return redirect("/notifications")

@app.route("/admin/announcements")
def admin_announcements():
    if session.get("role") != "admin":
        return abort(403)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("SELECT * FROM announcements ORDER BY created_at DESC")
    data = cur.fetchall()

    conn.close()

    return render_template("admin_announcements.html", data=data)

@app.route("/admin/announcements/add", methods=["POST"])
def add_announcement():
    if session.get("role") != "admin":
        return abort(403)

    title = request.form["title"]
    message = request.form["message"]

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO announcements (title, message, created_by)
        VALUES (%s, %s, %s)
    """, (title, message, session["user_id"]))

    conn.commit()
    conn.close()

    return redirect("/admin/announcements")

@app.route("/admin/announcements/delete/<int:id>")
def delete_announcement(id):
    if session.get("role") != "admin":
        return abort(403)

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("DELETE FROM announcements WHERE id=%s", (id,))
    conn.commit()
    conn.close()

    return redirect("/admin/announcements")

# ---------- AI ----------
@app.route("/ai-test")
def ai_test():
    try:
        r = client.responses.create(model="gpt-4.1-mini", input="Buatkan caption jualan kopi susu yang santai")
        return r.output_text
    except Exception as e:
        return f"ERROR: {e}"

@app.route("/caption/ai", methods=["POST"])
def caption_ai():
    if not is_logged_in():
        return redirect("/login")
    product = request.form.get("product")
    price = request.form.get("price", "")
    style = request.form.get("style", "Santai")
    try:
        caption = generate_caption_ai(product, price, style)
    except Exception:
        caption = "⚠️ AI sedang sibuk, coba lagi sebentar."
    return render_template("caption.html", ai_result=caption, product=product, price=price, style=style)

@app.route("/api/caption-ai", methods=["POST"])
def api_caption_ai():
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Silakan login dulu."}), 401
    product = (request.form.get("product") or "").strip()
    price = (request.form.get("price") or "").strip()
    style = (request.form.get("style") or "Santai").strip()
    brand = (request.form.get("brand") or "").strip()
    platform = (request.form.get("platform") or "Instagram").strip()
    notes = (request.form.get("notes") or "").strip()

    if not product:
        return jsonify({"ok": False, "error": "Nama produk wajib diisi."}), 400
    try:
        caption = generate_caption_ai(product, price, style, brand=brand, platform=platform, notes=notes)
        return jsonify({"ok": True, "caption": caption})
    except Exception:
        return jsonify({"ok": False, "error": "AI sedang sibuk."}), 500

@app.route("/api/chat", methods=["POST"])
def api_chat():
    data = request.get_json(silent=True) or {}
    msg = (data.get("message") or "").strip()
    if not msg:
        return jsonify({"ok": False, "error": "Pesan kosong."}), 400
    if not oa_client:
        return jsonify({"ok": False, "error": "OPENAI_API_KEY belum dikonfigurasi."}), 500

    hist = session.get("chat_history") or []
    hist = [h for h in hist if isinstance(h, dict) and h.get("role") and h.get("content")]
    hist = hist[-12:]
    base_url = request.host_url.rstrip("/")
    app_url = base_url

    system_prompt = f"""
Kamu "Asisten UMGAP" untuk UMKM. Tujuan: bantu user + arahkan ke fitur UMGAP (soft-selling).
Fitur: Absensi, Monitor Penjualan, AI Caption, Kelola Karyawan.
Jawab pakai bahasa Indonesia ramah. Akhiri dengan CTA ke {app_url}/login atau {app_url}/register.
""".strip()

    messages = [{"role": "system", "content": system_prompt}] + hist + [{"role": "user", "content": msg}]
    try:
        resp = oa_client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            messages=messages, temperature=0.7, max_tokens=450,
        )
        reply = (resp.choices[0].message.content or "").strip()
        hist.append({"role": "user", "content": msg})
        hist.append({"role": "assistant", "content": reply})
        session["chat_history"] = hist[-12:]
        return jsonify({"ok": True, "reply": reply, "app_url": app_url})
    except Exception as e:
        return jsonify({"ok": False, "error": f"Gagal memproses AI: {str(e)}"}), 500

@app.route("/api/caption", methods=["POST"])
def api_caption():
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Silakan login dulu."}), 401
    data = request.get_json(silent=True) or {}
    for k in ["template", "biz_type", "tone", "product", "price", "wa"]:
        if not (data.get(k) or "").strip():
            return jsonify({"ok": False, "error": f"Field '{k}' wajib diisi."}), 400
    caption, vid = build_caption(data)
    return jsonify({"ok": True, "caption": caption, "variant_id": vid})

# ---------- POINTS ----------
@app.route("/admin/points")
def admin_points():
    deny = admin_required()
    if deny:
        return deny
    if os.getenv('RUN_SCHEMA_ON_REQUEST','').lower()=='true':
        ensure_points_schema()
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        SELECT id, name, email, COALESCE(points, 0) AS points, COALESCE(points_admin, 0) AS points_admin
        FROM users WHERE role = 'employee' ORDER BY name ASC;
    """)
    employees = cur.fetchall()
    cur.execute("""
        SELECT l.created_at, u.name AS user_name, l.delta, l.note, a.name AS admin_name
        FROM points_logs l
        JOIN users u ON u.id = l.user_id
        JOIN users a ON a.id = l.admin_id
        ORDER BY l.created_at DESC LIMIT 50;
    """)
    logs = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("input_poin.html", user_name=session.get("user_name"), notif_count=0, employees=employees, logs=logs)

@app.route("/admin/points/add", methods=["POST"])
def admin_points_add():
    deny = admin_required()
    if deny:
        return deny
    if os.getenv('RUN_SCHEMA_ON_REQUEST','').lower()=='true':
        ensure_points_schema()
    user_id = int(request.form["user_id"])
    delta_raw = (request.form.get("delta") or "").strip()
    note = (request.form.get("note") or "").strip()
    try:
        delta = int(delta_raw)
    except:
        return "Delta poin harus angka.", 400
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("UPDATE users SET points_admin = COALESCE(points_admin,0) + %s WHERE id=%s AND role='employee';", (delta, user_id))
    cur.execute("INSERT INTO points_logs (user_id, admin_id, delta, note) VALUES (%s, %s, %s, %s);", (user_id, session.get("user_id"), delta, note if note else None))
    conn.commit()
    cur.close()
    conn.close()
    return redirect("/admin/points")

# ---------- EXPORT ----------
def _validate_range(start, end):
    if end < start:
        return False, "Tanggal akhir harus >= tanggal awal."
    days = (end - start).days + 1
    if days > 31:
        return False, "Maksimal range 31 hari."
    today = datetime.now(ZoneInfo("Asia/Jakarta")).date()
    if start < (today - timedelta(days=183)):
        return False, "Range hanya boleh dari 6 bulan terakhir."
    if start.year != end.year or start.month != end.month:
        return False, "Range harus dalam bulan yang sama."
    return True, ""

def _autosize_columns(ws):
    for col in ws.columns:
        max_len = 0
        col_letter = get_column_letter(col[0].column)
        for cell in col:
            v = "" if cell.value is None else str(cell.value)
            max_len = max(max_len, len(v))
        ws.column_dimensions[col_letter].width = min(max_len + 2, 42)

def _build_attendance_xlsx(rows_detail, recap_rows, title):
    wb = Workbook()
    ws = wb.active
    ws.title = "Detail"
    ws.append([title])
    ws.append([])
    ws.append(["Nama", "Tanggal", "Jam Kehadiran", "Status", "Gaji Harian", "Catatan"])
    for r in rows_detail:
        ws.append([r.get("name", ""), r.get("work_date", ""), r.get("checkin_time", ""), r.get("status", ""), r.get("daily_salary", 0), r.get("note", "")])
    _autosize_columns(ws)

    ws2 = wb.create_sheet("Rekap")
    ws2.append([title])
    ws2.append([])
    ws2.append(["Nama", "Hadir", "Sakit", "Izin", "Absen", "Total Gaji"])
    for rr in recap_rows:
        ws2.append([rr["name"], rr["present"], rr["sick"], rr["leave"], rr["absent"], rr["total_salary"]])
    _autosize_columns(ws2)

    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()

@app.route("/admin/data/range.xlsx")
def admin_download_range_xlsx():
    deny = admin_required()
    if deny:
        return deny
    ensure_hr_v2_schema()

    start = _parse_date(request.args.get("start"))
    end = _parse_date(request.args.get("end"))
    if not start or not end:
        return "start & end wajib (YYYY-MM-DD)", 400

    ok, msg = _validate_range(start, end)
    if not ok:
        return msg, 400

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        SELECT u.name, COALESCE(p.daily_salary, 0) AS daily_salary, a.work_date, a.status, a.note, a.checkin_at
        FROM attendance a
        JOIN users u ON u.id = a.user_id
        LEFT JOIN payroll_settings p ON p.user_id = u.id
        WHERE u.role='employee' AND a.work_date >= %s AND a.work_date <= %s
        ORDER BY u.name ASC, a.work_date ASC, a.checkin_at ASC NULLS LAST;
    """, (start, end))
    raw = cur.fetchall()
    cur.close()
    conn.close()

    detail = []
    recap = {}
    for r in raw:
        name = r["name"]
        ds = int(r["daily_salary"] or 0)
        status = (r["status"] or "").upper()
        checkin_time = r["checkin_at"].strftime("%H:%M:%S") if r["checkin_at"] else ""
        detail.append({"name": name, "work_date": r["work_date"].isoformat() if r["work_date"] else "", "checkin_time": checkin_time, "status": status, "daily_salary": ds, "note": (r.get("note") or "").strip()})
        if name not in recap:
            recap[name] = {"name": name, "present": 0, "sick": 0, "leave": 0, "absent": 0, "total_salary": 0}
        if status == "PRESENT":
            recap[name]["present"] += 1
            recap[name]["total_salary"] += ds
        elif status == "SICK":
            recap[name]["sick"] += 1
        elif status == "LEAVE":
            recap[name]["leave"] += 1
        elif status == "ABSENT":
            recap[name]["absent"] += 1

    recap_rows = list(recap.values())
    title = f"Rekap Absensi & Gaji ({start.isoformat()} s/d {end.isoformat()})"
    xlsx_bytes = _build_attendance_xlsx(detail, recap_rows, title)
    filename = f"rekap_{start.isoformat()}_{end.isoformat()}.xlsx"
    return Response(xlsx_bytes, mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", headers={"Content-Disposition": f'attachment; filename="{filename}"'})

@app.route("/admin/data/range_user.xlsx")
def admin_download_range_user_xlsx():
    deny = admin_required()
    if deny:
        return deny
    ensure_hr_v2_schema()

    user_id = request.args.get("user_id")
    if not user_id:
        return "user_id wajib", 400
    start = _parse_date(request.args.get("start"))
    end = _parse_date(request.args.get("end"))
    if not start or not end:
        return "start & end wajib (YYYY-MM-DD)", 400

    ok, msg = _validate_range(start, end)
    if not ok:
        return msg, 400

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT id, name FROM users WHERE id=%s LIMIT 1;", (int(user_id),))
    urow = cur.fetchone()
    if not urow:
        cur.close()
        conn.close()
        return "User tidak ditemukan", 404
    user_name = urow["name"]

    cur.execute("""
        SELECT COALESCE(p.daily_salary, 0) AS daily_salary, a.work_date, a.status, a.note, a.checkin_at
        FROM attendance a
        LEFT JOIN payroll_settings p ON p.user_id = a.user_id
        WHERE a.user_id=%s AND a.work_date >= %s AND a.work_date <= %s
        ORDER BY a.work_date ASC, a.checkin_at ASC NULLS LAST;
    """, (int(user_id), start, end))
    raw = cur.fetchall()
    cur.close()
    conn.close()

    detail = []
    recap = {"name": user_name, "present": 0, "sick": 0, "leave": 0, "absent": 0, "total_salary": 0}
    for r in raw:
        ds = int(r["daily_salary"] or 0)
        status = (r["status"] or "").upper()
        checkin_time = r["checkin_at"].strftime("%H:%M:%S") if r["checkin_at"] else ""
        detail.append({"name": user_name, "work_date": r["work_date"].isoformat() if r["work_date"] else "", "checkin_time": checkin_time, "status": status, "daily_salary": ds, "note": (r.get("note") or "").strip()})
        if status == "PRESENT":
            recap["present"] += 1
            recap["total_salary"] += ds
        elif status == "SICK":
            recap["sick"] += 1
        elif status == "LEAVE":
            recap["leave"] += 1
        elif status == "ABSENT":
            recap["absent"] += 1

    title = f"Rekap {user_name} ({start.isoformat()} s/d {end.isoformat()})"
    xlsx_bytes = _build_attendance_xlsx(detail, [recap], title)
    filename = f"rekap_{user_name}_{start.isoformat()}_{end.isoformat()}.xlsx".replace(" ", "_")
    return Response(xlsx_bytes, mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", headers={"Content-Disposition": f'attachment; filename="{filename}"'})

# ---------- PREVIEW ----------
@app.route("/preview/<name>")
def preview_template(name):
    allowed = {"login": "login.html", "register": "register.html", "dashboard": "dashboard.html", "products": "products.html"}
    if name not in allowed:
        abort(404)
    dummy = {
        "user_name": "UMKM Demo", "total_products": 3, "total_contents": 5, "total_done": 2,
        "products": [{"id": 1, "name": "Kopi Susu", "price": 12000}, {"id": 2, "name": "Roti Bakar", "price": 15000}, {"id": 3, "name": "Teh Manis", "price": 6000}],
        "error": None
    }
    return render_template(allowed[name], **dummy)

# ==================== THERMAL PRINT API ====================

def _build_escpos(invoice, items, paper_width=80):
    """Build ESC/POS byte array for ZJ-5809 II and similar BT thermal printers."""
    import struct

    ESC, GS, LF = 0x1B, 0x1D, 0x0A
    W = 32 if paper_width == 58 else 48  # char width

    def enc(s):
        return [c if c < 128 else 0x3F for c in s.encode('ascii', errors='replace')]

    def pad_row(left, right, w):
        left, right = str(left or ''), str(right or '')
        gap = max(1, w - len(left) - len(right))
        line = left + ' ' * gap + right
        return enc(line[:w]) + [LF]

    buf = []
    b = buf.extend

    # Init
    b([ESC, 0x40])              # init
    b([ESC, 0x74, 0x00])        # codepage PC437

    # Header - center + big
    b([ESC, 0x61, 0x01])        # align center
    b([ESC, 0x21, 0x30])        # double width+height
    b([ESC, 0x45, 0x01])        # bold on
    b(enc('UMGAP') + [LF])
    b([ESC, 0x21, 0x00])        # normal size
    b([ESC, 0x45, 0x00])        # bold off
    b(enc('Nota Penjualan') + [LF])

    # Dashes
    dash = enc('-' * W) + [LF]

    b(dash)
    b([ESC, 0x61, 0x00])        # align left

    # Invoice info
    inv_no = str(invoice.get('invoice_no', '') or '')
    created = ''
    if invoice.get('created_at'):
        try:
            created = invoice['created_at'].strftime('%d/%m/%Y %H:%M')
        except Exception:
            created = str(invoice['created_at'])[:16]

    b(pad_row('No', inv_no[:W-3], W))
    b(pad_row('Tanggal', created, W))
    b(pad_row('Customer', str(invoice.get('customer_name') or '-')[:W-10], W))
    b(pad_row('Kasir', str(invoice.get('created_by_name') or '-')[:W-6], W))
    b(pad_row('Bayar', str(invoice.get('payment_method') or 'CASH'), W))
    b(dash)

    # Items
    for item in items:
        name = str(item.get('product_name', '') or '')
        qty  = int(item.get('qty', 1) or 1)
        price = int(item.get('price', 0) or 0)
        sub   = int(item.get('subtotal', 0) or 0)
        price_fmt = '{:,}'.format(price).replace(',', '.')
        sub_fmt   = '{:,}'.format(sub).replace(',', '.')
        b([ESC, 0x45, 0x01])    # bold
        b(enc(name[:W]) + [LF])
        b([ESC, 0x45, 0x00])    # bold off
        detail_left  = '  {} x Rp {}'.format(qty, price_fmt)
        detail_right = 'Rp {}'.format(sub_fmt)
        b(pad_row(detail_left, detail_right, W))

    b(dash)

    # Total - double height
    grand = int(invoice.get('grand_total', 0) or 0)
    grand_fmt = '{:,}'.format(grand).replace(',', '.')
    b([ESC, 0x61, 0x02])        # align right
    b([ESC, 0x21, 0x10])        # double height
    b([ESC, 0x45, 0x01])        # bold
    b(enc('TOTAL: Rp {}'.format(grand_fmt)) + [LF])
    b([ESC, 0x21, 0x00])        # normal
    b([ESC, 0x45, 0x00])        # bold off
    b([ESC, 0x61, 0x00])        # align left
    b(dash)

    # Notes
    notes = str(invoice.get('notes') or '').strip()
    if notes:
        b(enc('Catatan: ' + notes[:W-9]) + [LF])
        b(dash)

    # Footer
    b([ESC, 0x61, 0x01])        # center
    b(enc('Terima kasih sudah berbelanja!') + [LF])
    b([LF, LF, LF])

    # Cut
    b([GS, 0x56, 0x42, 0x20])  # partial cut

    return bytes(buf)


def _get_invoice_with_items(invoice_id):
    """Fetch invoice + items dict from DB."""
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT i.*, u.name AS created_by_name
            FROM invoices i JOIN users u ON u.id = i.created_by
            WHERE i.id=%s LIMIT 1;
        """, (invoice_id,))
        inv = cur.fetchone()
        if not inv:
            return None, []
        cur.execute("""
            SELECT product_name, qty, price, subtotal
            FROM invoice_items WHERE invoice_id=%s ORDER BY id;
        """, (invoice_id,))
        items = cur.fetchall()
        return dict(inv), [dict(r) for r in items]
    finally:
        cur.close()
        conn.close()


@app.route("/invoice/<int:invoice_id>/escpos")
def invoice_escpos(invoice_id):
    """Download raw ESC/POS binary - for RawBT or manual use."""
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401

    ensure_invoice_schema()
    inv, items = _get_invoice_with_items(invoice_id)
    if not inv:
        abort(404)

    pw_str = (inv.get('print_size') or '80mm').replace('mm', '')
    pw = 58 if pw_str == '58' else 80

    data = _build_escpos(inv, items, paper_width=pw)
    fname = 'nota_{}.bin'.format(inv.get('invoice_no', str(invoice_id)))

    return Response(
        data,
        mimetype='application/octet-stream',
        headers={'Content-Disposition': 'attachment; filename="{}"'.format(fname)}
    )


@app.route("/invoice/<int:invoice_id>/print-server", methods=["POST"])
def invoice_print_server(invoice_id):
    """Print via pyserial to Bluetooth COM port (Windows only)."""
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401

    if not SERIAL_OK:
        return jsonify({"ok": False, "error": "pyserial tidak terinstall di server. Jalankan: pip install pyserial"}), 500

    ensure_invoice_schema()
    inv, items = _get_invoice_with_items(invoice_id)
    if not inv:
        return jsonify({"ok": False, "error": "Invoice tidak ditemukan"}), 404

    com_port = (request.json or {}).get('port', '').strip()
    pw_str   = (inv.get('print_size') or '80mm').replace('mm', '')
    pw = 58 if pw_str == '58' else 80

    # Auto-detect if no port given
    if not com_port:
        ports = serial.tools.list_ports.comports()
        for p in ports:
            desc = (p.description or '').lower()
            if 'bluetooth' in desc or 'spp' in desc or 'serial' in desc or 'com' in desc.lower():
                com_port = p.device
                break
        if not com_port and ports:
            com_port = ports[0].device

    if not com_port:
        return jsonify({"ok": False, "error": "Tidak ada COM port ditemukan. Pastikan printer sudah di-pair di Windows."}), 400

    try:
        data = _build_escpos(inv, items, paper_width=pw)
        with serial.Serial(com_port, baudrate=9600, timeout=3) as ser:
            ser.write(data)
        return jsonify({"ok": True, "port": com_port, "bytes": len(data)})
    except serial.SerialException as e:
        return jsonify({"ok": False, "error": "Serial error: {}".format(str(e))}), 500
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/invoice/<int:invoice_id>/list-ports")
def invoice_list_ports(invoice_id):
    """List available COM ports on server (Windows)."""
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Unauthorized"}), 401
    if not SERIAL_OK:
        return jsonify({"ok": False, "ports": [], "error": "pyserial tidak terinstall"}), 200
    ports = [{"device": p.device, "desc": p.description} for p in serial.tools.list_ports.comports()]
    return jsonify({"ok": True, "ports": ports})


# ==================== RUN ====================
if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=False)

# Init DB on startup
def safe_init_db():
    try:
        if os.getenv('RUN_SCHEMA_ON_REQUEST','').lower()=='true':
            ensure_points_schema()
        ensure_hr_v2_schema()
        init_points_v1()
        ensure_announcements_schema()
        print("DB init OK")
    except Exception as e:
        print("Init error:", e)

# Jangan auto-init saat import di gunicorn.
# Jalankan hanya kalau kamu set env INIT_DB_ON_STARTUP=true
if os.getenv("INIT_DB_ON_STARTUP", "").lower() == "true":
    safe_init_db()

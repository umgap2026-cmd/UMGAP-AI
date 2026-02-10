from flask import Flask, render_template, request, redirect, session, abort
from werkzeug.security import generate_password_hash, check_password_hash
from db import get_conn
import random  # taruh di paling atas file app.py (sekali saja)
import random, time
from flask import jsonify
from flask import abort
from zoneinfo import ZoneInfo
from datetime import datetime
from datetime import date
from functools import wraps
from flask import redirect, session, abort
from datetime import date, timedelta
import calendar
from psycopg2.extras import RealDictCursor
from flask import session, redirect, url_for, request, render_template, flash
import os
from openai import OpenAI
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
from openai import RateLimitError, APIError, AuthenticationError
from dotenv import load_dotenv
load_dotenv()
from decimal import Decimal
from flask import Response, request, redirect, render_template, session, url_for, flash
from flask import Response
from openpyxl import Workbook
from openpyxl.utils import get_column_letter
import io
from psycopg2.extras import RealDictCursor
import re
import ssl
import time
import hmac
import hashlib
import random
import smtplib
from datetime import datetime, timedelta
from email.message import EmailMessage

from authlib.integrations.flask_client import OAuth
from dotenv import load_dotenv
load_dotenv()

from authlib.integrations.flask_client import OAuth
from werkzeug.security import generate_password_hash
import hashlib, time
from authlib.integrations.flask_client import OAuth
import requests



def login_required():
    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            if not session.get("user_id"):
                return redirect(url_for("login"))
            return fn(*args, **kwargs)
        return wrapper
    return decorator

def admin_required():
    # panggil ini DI DALAM route (bukan decorator) biar gampang dipakai di kode lama kamu
    if not session.get("user_id"):
        return redirect(url_for("login"))
    if session.get("role") != "admin":
        flash("Akses ditolak. Hanya admin.", "danger")
        return redirect(url_for("dashboard"))
    return None


def adjust_points_for_attendance_change(cur, user_id: int, old_status: str | None, new_status: str | None):
    old_present = (old_status == "PRESENT")
    new_present = (new_status == "PRESENT")

    if old_present == new_present:
        return

    delta = 1 if new_present else -1

    cur.execute("""
        UPDATE users
        SET points = COALESCE(points, 0) + %s
        WHERE id = %s
    """, (delta, user_id))





def generate_caption_ai(product: str, price: str, style: str, brand: str = "", platform: str = "Instagram", notes: str = "") -> str:
    """
    Generate caption lebih panjang, organik, dan variatif sesuai platform.
    Output: 3 versi (V1-V3) + hashtag.
    """
    product = (product or "").strip()
    price = (price or "").strip()
    style = (style or "Santai").strip()
    brand = (brand or "").strip()
    platform = (platform or "Instagram").strip()
    notes = (notes or "").strip()

    # Force brand usage if provided
    brand_rule = ""
    if brand:
        brand_rule = f'- WAJIB sebut brand "{brand}" minimal 1x di tiap versi (boleh di awal/akhir, natural).\n'

    # Price formatting hint
    price_hint = ""
    if price:
        price_hint = f'- Cantumkan harga "{price}" dengan format yang enak dibaca (contoh: Rp{price}).\n'

    # Platform rules
    platform_rules = {
        "WhatsApp": (
            "Gaya WhatsApp:\n"
            "- Ringkas tapi tetap natural.\n"
            "- 4–7 baris.\n"
            "- CTA chat/wa.\n"
            "- Hashtag maksimal 0–2.\n"
        ),
        "TikTok": (
            "Gaya TikTok:\n"
            "- Wajib ada HOOK 1 baris (bikin penasaran).\n"
            "- 8–14 baris (pakai enter biar enak dibaca).\n"
            "- Ada ajakan komentar (contoh: 'tim jahe atau tim kopi?').\n"
            "- Hashtag 5–9.\n"
        ),
        "Instagram": (
            "Gaya Instagram:\n"
            "- Semi storytelling.\n"
            "- 9–15 baris (pakai enter biar rapi).\n"
            "- CTA DM/komentar.\n"
            "- Hashtag 5–10.\n"
        ),
    }
    plat_rule = platform_rules.get(platform, platform_rules["Instagram"])

    notes_block = f'Catatan pendukung (kalau ada): "{notes}"\n' if notes else ""

    prompt = f"""
Kamu adalah copywriter UMKM Indonesia. Buat caption jualan yang ORGANIK, manusiawi, tidak kaku, tidak terdengar seperti iklan murahan.

DATA:
- Produk: "{product}"
- Platform: "{platform}"
- Tone/Gaya: "{style}"
{notes_block}

ATURAN UMUM:
- Jangan membuat klaim medis/menjanjikan "sehat/menyembuhkan/detox" dsb.
  Boleh pakai kata: "hangat", "nyaman", "bikin mood enak", "pas buat nemenin aktivitas".
{brand_rule}{price_hint}
- Masukkan catatan pendukung secara natural (contoh jam buka, stok, varian, COD, lokasi) jika tersedia.
- Tulis dengan bahasa Indonesia sehari-hari, pakai jeda baris biar mudah dicopy.

ATURAN PLATFORM:
{plat_rule}

OUTPUT WAJIB:
Buat 3 versi yang BENAR-BENAR beda angle:
- V1: fokus manfaat & rasa/experience
- V2: fokus cerita/kejadian sehari-hari + relate
- V3: fokus promo/urgency yang halus (tanpa lebay)

Format persis seperti ini:

V1:
(caption...)

V2:
(caption...)

V3:
(caption...)
"""

    r = client.responses.create(
        model="gpt-4.1-mini",
        input=prompt,
        temperature=0.9,   # lebih variatif
        max_output_tokens=700
    )
    return (r.output_text or "").strip()




# ====== TAMBAHKAN FUNGSI INI (sekali saja) ======
def ensure_points_schema():
    conn = get_conn()
    cur = conn.cursor()

    # kolom users
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS points INTEGER DEFAULT 0;")
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS points_admin INTEGER DEFAULT 0;")

    # log table
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



app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "dev-secret")

app.secret_key = os.getenv("SECRET_KEY", "dev-secret-change-me")
app.config["SESSION_COOKIE_SAMESITE"] = "Lax"



try:
    ensure_points_schema()
except Exception as e:
    # jangan bikin app crash saat deploy; log aja
    print("ensure_points_schema failed:", e)


def is_logged_in():
    return "user_id" in session

def is_admin():
    return session.get("role") == "admin"

def admin_guard():
    """Dipakai DI DALAM route (bukan decorator)."""
    if not is_logged_in():
        return redirect("/login")
    if not is_admin():
        abort(403)
    return None

def _parse_manual_wib_naive(manual_dt: str | None):
    """
    manual_dt format dari <input type="datetime-local"> biasanya: 'YYYY-MM-DDTHH:MM'
    Return datetime naive (nilai WIB) atau None kalau gagal.
    """
    if not manual_dt:
        return None
    manual_dt = manual_dt.strip()
    try:
        # datetime-local biasanya tanpa detik
        dt = datetime.strptime(manual_dt, "%Y-%m-%dT%H:%M")
        # Anggap input itu WIB, simpan sebagai naive WIB
        return dt
    except Exception:
        return None

OPENAI_API_KEY = (os.getenv("OPENAI_API_KEY") or "").strip()
oa_client = OpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None


@app.route("/ai-test")
def ai_test():
    try:
        r = client.responses.create(
            model="gpt-4.1-mini",
            input="Buatkan caption jualan kopi susu yang santai"
        )
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

    return render_template(
        "caption.html",
        ai_result=caption,
        product=product,
        price=price,
        style=style
    )

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
        return jsonify({"ok": False, "error": "AI sedang sibuk / quota bermasalah. Coba lagi."}), 500



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
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            name VARCHAR(120) NOT NULL,
            price INTEGER NOT NULL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)
    conn.commit()
    cur.close()
    conn.close()
    return "OK: tabel products siap."

@app.route("/init-products-v2")
def init_products_v2():
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("ALTER TABLE products ADD COLUMN IF NOT EXISTS is_global BOOLEAN NOT NULL DEFAULT FALSE;")
    conn.commit()
    cur.close()
    conn.close()
    return "OK: products v2 (is_global) siap."


#@app.route("/dashboard")
#def dashboard_redirect():
#   if not is_logged_in():
#        return redirect("/login")

 #   role = session.get("role", "employee")
 #   if role == "admin":
 #       return redirect("/admin/dashboard")

    # user/karyawan arahkan ke halaman kerja utama
#    return redirect("/sales")


# ======================================================================
#  DASHBOARD USER (GANTI route dashboard user kamu jadi ini)
#  - tetap redirect admin ke /admin/dashboard
#  - tambahkan points_admin untuk ditampilkan
# ======================================================================
@app.route("/dashboard")
def dashboard():
    if not is_logged_in():
        return redirect("/login")

    if session.get("role") == "admin":
        return redirect("/admin/dashboard")

    ensure_points_schema()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    # KPI kamu (contoh yang sudah ada)
    cur.execute("SELECT COUNT(*) AS total FROM products WHERE user_id=%s;", (session["user_id"],))
    total_products = (cur.fetchone() or {}).get("total", 0)

    cur.execute("SELECT COUNT(*) AS total FROM content_plans WHERE user_id=%s;", (session["user_id"],))
    total_contents = (cur.fetchone() or {}).get("total", 0)

    cur.execute("SELECT COUNT(*) AS total FROM content_plans WHERE user_id=%s AND is_done=TRUE;", (session["user_id"],))
    total_done = (cur.fetchone() or {}).get("total", 0)

    # poin keaktifan (hanya dari admin)
    cur.execute("""
        SELECT COALESCE(points_admin,0) AS points_admin
        FROM users
        WHERE id=%s
        LIMIT 1;
    """, (session["user_id"],))
    pr = cur.fetchone() or {"points_admin": 0}

    # ringkasan absensi 7 hari terakhir
    cur.execute("""
        SELECT
          COALESCE(SUM(CASE WHEN status='PRESENT' THEN 1 ELSE 0 END),0) AS hadir,
          COALESCE(SUM(CASE WHEN status='SICK' THEN 1 ELSE 0 END),0) AS sakit,
          COALESCE(SUM(CASE WHEN status='LEAVE' THEN 1 ELSE 0 END),0) AS cuti,
          COALESCE(SUM(CASE WHEN status='ABSENT' THEN 1 ELSE 0 END),0) AS absen
        FROM attendance
        WHERE user_id=%s
          AND work_date >= (CURRENT_DATE - INTERVAL '6 days')
          AND work_date <= CURRENT_DATE;
    """, (session["user_id"],))
    attendance_7d = cur.fetchone() or {"hadir": 0, "sakit": 0, "cuti": 0, "absen": 0}

    cur.close()
    conn.close()

    return render_template(
        "dashboard.html",
        user_name=session.get("user_name"),
        notif_count=0,
        total_products=int(total_products or 0),
        total_contents=int(total_contents or 0),
        total_done=int(total_done or 0),
        points_admin=int(pr.get("points_admin") or 0),
        attendance_7d=attendance_7d,  # penting biar ga UndefinedError
    )



@app.route("/")
def landing():
    # kalau sudah login, arahkan ke dashboard sesuai role
    if is_logged_in():
        if session.get("role") == "admin":
            return redirect("/admin/dashboard")
        return redirect("/dashboard")
    # publik lihat landing
    return render_template("landing.html")


@app.route("/api/chat", methods=["POST"])
def api_chat():
    data = request.get_json(silent=True) or {}
    msg = (data.get("message") or "").strip()

    if not msg:
        return jsonify({"ok": False, "error": "Pesan kosong."}), 400
    if not oa_client:
        return jsonify({"ok": False, "error": "OPENAI_API_KEY belum dikonfigurasi."}), 500

    # Simpan history di session biar nyambung (maks 12 pesan terakhir)
    hist = session.get("chat_history") or []
    hist = [h for h in hist if isinstance(h, dict) and h.get("role") and h.get("content")]
    hist = hist[-12:]

    # URL dinamis (biar aman di localhost / Render)
    base_url = request.host_url.rstrip("/")  # contoh: https://umgap-ai.onrender.com
    app_url = base_url  # kamu bisa ganti kalau app utama beda domain

    system_prompt = f"""
Kamu adalah "Asisten UMGAP" untuk UMKM di Salatiga & Jawa Tengah.

TUJUAN UTAMA:
1) Bantu user dengan jawaban praktis,
2) SEKALIGUS arahkan solusi agar user tertarik pakai UMGAP (soft-selling, bukan maksa).

FOKUS FITUR UMGAP YANG HARUS SERING DITAWARKAN (pilih yang relevan):
- Absensi karyawan (rekap rapi, bisa export Excel)
- Monitor/Laporan penjualan (lebih terkontrol)
- AI Caption Generator untuk promosi sosmed (Instagram/TikTok/WhatsApp)
- Kelola karyawan & data usaha dalam satu aplikasi

GAYA JAWAB:
- Bahasa Indonesia yang ramah, terasa “orang lokal”, tidak kaku.
- Tanyakan maks 1–2 pertanyaan klarifikasi kalau info kurang (contoh: jenis usaha, target customer, platform jualan, jumlah karyawan).
- Beri langkah konkret (bullet list pendek).
- Selalu sisipkan 1 CTA yang relevan ke fitur UMGAP + arahkan tombol/fitur yang harus diklik user di web.

ATURAN PENTING:
- Jangan hanya memberi teori umum. Minimal 50% jawaban harus mengaitkan ke UMGAP:
  “Kalau pakai UMGAP, kamu bisa … (fitur) …”
- Akhiri dengan ajakan tindakan yang jelas:
  “Mau aku bantu set up di UMGAP? Buka {app_url}/login atau {app_url}/register”
- Jika user bilang jenis usaha (mis. coffee shop), rekomendasikan flow UMGAP:
  absensi (kalau ada karyawan) + penjualan harian + AI caption untuk promo.
""".strip()

    messages = [{"role": "system", "content": system_prompt}] + hist + [{"role": "user", "content": msg}]

    try:
        resp = oa_client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            messages=messages,
            temperature=0.7,
            max_tokens=450,
        )
        reply = (resp.choices[0].message.content or "").strip()

        hist.append({"role": "user", "content": msg})
        hist.append({"role": "assistant", "content": reply})
        session["chat_history"] = hist[-12:]

        return jsonify({"ok": True, "reply": reply, "app_url": app_url})

    except Exception as e:
        return jsonify({"ok": False, "error": f"Gagal memproses AI: {str(e)}"}), 500









@app.route("/admin")
def admin_home():
    admin_guard()
    return redirect("/admin/dashboard")


@app.route("/admin/users")
def admin_users():
    admin_guard()

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
    SELECT u.id, u.name, u.email, u.role,
            COALESCE(p.daily_salary, 0) AS daily_salary
    FROM users u
    LEFT JOIN payroll_settings p ON p.user_id=u.id
    ORDER BY u.id DESC;
    """)

    rows = cur.fetchall()

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
    cur = conn.cursor()

    # 1) insert user dulu, ambil uid
    cur.execute("""
        INSERT INTO users (name, email, password_hash, role)
        VALUES (%s, %s, %s, %s)
        RETURNING id;
    """, (name, email, pw_hash, role))
    uid = cur.fetchone()["id"]

    # 2) set payroll daily_salary (yang dipakai admin_payroll)
    cur.execute("""
        INSERT INTO payroll_settings (user_id, daily_salary)
        VALUES (%s, %s)
        ON CONFLICT (user_id) DO UPDATE
          SET daily_salary=EXCLUDED.daily_salary, updated_at=CURRENT_TIMESTAMP;
    """, (uid, daily_salary))

    conn.commit()
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

    # simpan daily_salary (sinkron ke admin_payroll)
    cur.execute("""
      INSERT INTO payroll_settings (user_id, daily_salary)
      VALUES (%s, %s)
      ON CONFLICT (user_id) DO UPDATE
        SET daily_salary=EXCLUDED.daily_salary, updated_at=CURRENT_TIMESTAMP;
    """, (uid, daily_salary))

    conn.commit()
    cur.close()
    conn.close()
    return redirect("/admin/users")



@app.route("/admin/users/delete/<int:uid>", methods=["POST"])
def admin_users_delete(uid):

    # cegah admin menghapus dirinya sendiri (biar aman)
    if uid == session.get("user_id"):
        return redirect("/admin/users")

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("DELETE FROM users WHERE id=%s;", (uid,))
    conn.commit()
    cur.close()
    conn.close()
    return redirect("/admin/users")


# ==== MIGRASI HR V2 (AMAN + LENGKAP) ====
@app.route("/init-hr-v2")
def init_hr_v2():
    """
    Jalankan sekali untuk memastikan tabel/kolom yang dipakai fitur absensi + export sudah ada.
    Aman dipanggil berkali-kali (IF NOT EXISTS).
    """
    conn = get_conn()
    cur = conn.cursor()

    # 1) Pastikan payroll_settings ada (kalau belum ada)
    cur.execute("""
      CREATE TABLE IF NOT EXISTS payroll_settings (
        user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        daily_salary INTEGER NOT NULL DEFAULT 0,
        monthly_salary INTEGER NOT NULL DEFAULT 0,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    """)

    # 2) Pastikan kolom daily_salary ada (kalau tabelnya sudah ada tapi kolomnya belum)
    cur.execute("""
      ALTER TABLE payroll_settings
      ADD COLUMN IF NOT EXISTS daily_salary INTEGER NOT NULL DEFAULT 0;
    """)

    # (opsional) monthly_salary kalau kamu pakai di payroll
    cur.execute("""
      ALTER TABLE payroll_settings
      ADD COLUMN IF NOT EXISTS monthly_salary INTEGER NOT NULL DEFAULT 0;
    """)

    # (opsional) updated_at biar ON CONFLICT ... updated_at tidak error
    cur.execute("""
      ALTER TABLE payroll_settings
      ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
    """)

    # 3) attendance butuh arrival_type + checkin_at
    cur.execute("""
      ALTER TABLE attendance
      ADD COLUMN IF NOT EXISTS arrival_type VARCHAR(20) NOT NULL DEFAULT 'ONTIME';
    """)
    cur.execute("""
      ALTER TABLE attendance
      ADD COLUMN IF NOT EXISTS checkin_at TIMESTAMP NULL;
    """)

    conn.commit()
    cur.close()
    conn.close()
    return "OK: HR v2 tables/columns ensured."

def init_points_admin_log(cur):
    cur.execute("""
    CREATE TABLE IF NOT EXISTS points_admin_log (
      id SERIAL PRIMARY KEY,
      user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      admin_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      delta INT NOT NULL,
      note TEXT,
      created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
    );
    """)


def init_points_v1():
    conn = get_conn()
    cur = conn.cursor()

    # Kolom poin (attendance) + poin_admin (manual dari admin)
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS points INTEGER NOT NULL DEFAULT 0;")
    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS points_admin INTEGER NOT NULL DEFAULT 0;")

    # Log perubahan poin manual
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
    print("Points v1 ensured.")






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
        cur = conn.cursor()
        cur.execute(
            "INSERT INTO users (name, email, password_hash) VALUES (%s, %s, %s) RETURNING id;",
            (name, email, pw_hash),
        )
        user_id = cur.fetchone()["id"]
        conn.commit()
        cur.close()
        conn.close()

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
    cur = conn.cursor()
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


@app.route("/products")
def products():
    if not is_logged_in():
        return redirect("/login")

    # ✅ Hanya admin boleh kelola produk
    admin_guard()

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, name, price, user_id, is_global
        FROM products
        ORDER BY id DESC;
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()

    return render_template("products.html", products=rows, error=None)


@app.route("/products/add", methods=["POST"])
def products_add():
    if not is_logged_in():
        return redirect("/login")

    admin_guard()

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
    # ✅ Produk admin = GLOBAL
    cur.execute("""
        INSERT INTO products (user_id, name, price, is_global)
        VALUES (%s, %s, %s, TRUE);
    """, (session["user_id"], name, price_int))
    conn.commit()
    cur.close()
    conn.close()
    return redirect("/products")


@app.route("/products/delete/<int:pid>")
def products_delete(pid):
    if not is_logged_in():
        return redirect("/login")

    admin_guard()

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("DELETE FROM products WHERE id=%s;", (pid,))
    conn.commit()
    cur.close()
    conn.close()
    return redirect("/products")


@app.route("/products/edit/<int:pid>", methods=["GET", "POST"])
def products_edit(pid):
    if not is_logged_in():
        return redirect("/login")

    admin_guard()

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, name, price, user_id, is_global
        FROM products
        WHERE id=%s;
    """, (pid,))
    product = cur.fetchone()

    if not product:
        cur.close()
        conn.close()
        abort(404)

    if request.method == "GET":
        cur.close()
        conn.close()
        return render_template("product_edit.html", product=product, error=None)

    # POST update
    name = (request.form.get("name") or "").strip()
    price = (request.form.get("price") or "0").strip()

    if not name:
        cur.close()
        conn.close()
        return render_template("product_edit.html", product=product, error="Nama produk wajib diisi.")

    try:
        price_int = int(price)
        if price_int < 0:
            price_int = 0
    except ValueError:
        price_int = 0

    cur.execute("""
        UPDATE products
        SET name=%s, price=%s
        WHERE id=%s;
    """, (name, price_int, pid))

    conn.commit()
    cur.close()
    conn.close()
    return redirect("/products")




@app.route("/preview/<name>")
def preview_template(name):
    allowed = {
        "login": "login.html",
        "register": "register.html",
        "dashboard": "dashboard.html",
        "products": "products.html",
    }

    if name not in allowed:
        abort(404)

    dummy = {
        "user_name": "UMKM Demo",
        "total_products": 3,
        "total_contents": 5,
        "total_done": 2,
        "products": [
            {"id": 1, "name": "Kopi Susu", "price": 12000},
            {"id": 2, "name": "Roti Bakar", "price": 15000},
            {"id": 3, "name": "Teh Manis", "price": 6000},
        ],
        "error": None
    }

    return render_template(allowed[name], **dummy)

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


@app.route("/content")
def content():
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        SELECT id, plan_date, platform, content_type, notes, is_done
        FROM content_plans
        WHERE user_id=%s
        ORDER BY plan_date DESC, id DESC;
    """, (session["user_id"],))
    plans = cur.fetchall()
    cur.close()
    conn.close()

    return render_template("content.html", plans=plans, error=None)


@app.route("/content/add", methods=["POST"])
def content_add():
    if not is_logged_in():
        return redirect("/login")

    plan_date = request.form.get("plan_date")
    platform = request.form.get("platform", "").strip()
    content_type = request.form.get("content_type", "").strip()
    notes = request.form.get("notes", "").strip()

    if not plan_date or not platform or not content_type:
        return redirect("/content")

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO content_plans (user_id, plan_date, platform, content_type, notes)
        VALUES (%s, %s, %s, %s, %s);
    """, (session["user_id"], plan_date, platform, content_type, notes))
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
    cur.execute("""
        UPDATE content_plans
        SET is_done=TRUE
        WHERE id=%s AND user_id=%s;
    """, (cid, session["user_id"]))
    conn.commit()
    cur.close()
    conn.close()

    return redirect("/content")


@app.route("/content/undo/<int:cid>")
def content_undo(cid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        UPDATE content_plans
        SET is_done=FALSE
        WHERE id=%s AND user_id=%s;
    """, (cid, session["user_id"]))
    conn.commit()
    cur.close()
    conn.close()

    return redirect("/content")


@app.route("/content/delete/<int:cid>")
def content_delete(cid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("DELETE FROM content_plans WHERE id=%s AND user_id=%s;", (cid, session["user_id"]))
    conn.commit()
    cur.close()
    conn.close()

    return redirect("/content")


def pick(options):
    return random.choice(options)

def rupiah(s):
    try:
        n = int(s)
        return f"Rp {n:,}".replace(",", ".")
    except:
        return f"Rp {s}"

@app.route("/caption", methods=["GET", "POST"])
def caption():
    if not is_logged_in():
        return redirect("/login")

    form = {
        "template": "promo",
        "biz_type": "produk",
        "tone": "santai",
        "product": "",
        "price": "",
        "wa": "",
        "location": "",
        "extra": ""
    }
    caption_text = None

    # Kumpulan variasi kalimat (generik, cocok semua UMKM)
    hooks = {
        "santai": [
            "Lagi cari yang pas buat kamu?",
            "Biar makin gampang, cek ini dulu 👇",
            "Yang ini lagi banyak dicari loh!",
            "Info singkat tapi penting 👇",
        ],
        "formal": [
            "Berikut informasi penawaran kami:",
            "Kami menyediakan layanan/produk berikut:",
            "Informasi terbaru untuk Anda:",
            "Rincian penawaran saat ini:",
        ],
        "sales": [
            "Jangan sampai kelewatan!",
            "Terbatas! Yang cepat dapat duluan!",
            "Hari ini doang — gas sekarang!",
            "Kesempatan bagus, jangan ditunda!",
        ],
    }

    ctas = {
        "santai": ["Chat aja ya 👉", "Langsung DM/WA ya 👉", "Mau tanya dulu juga boleh 👉", "Pesan sekarang 👉"],
        "formal": ["Silakan hubungi:", "Untuk pemesanan, hubungi:", "Informasi lebih lanjut:", "Reservasi/pemesanan:"],
        "sales": ["Klik WA sekarang!", "Order sekarang juga!", "Amankan slot/stok sekarang!", "Langsung checkout via WA!"],
    }

    benefits_produk = [
        "Kualitas terjaga",
        "Cocok untuk kebutuhan harian",
        "Praktis dan mudah digunakan",
        "Bisa untuk hadiah / kebutuhan pribadi",
        "Varian tersedia (tanya admin)",
    ]
    benefits_jasa = [
        "Proses rapi dan profesional",
        "Bisa konsultasi dulu sebelum order",
        "Pengerjaan tepat waktu",
        "Harga transparan",
        "Dikerjakan oleh tenaga berpengalaman",
    ]

    promo_lines = [
        "Harga spesial periode terbatas.",
        "Bisa tanya stok/varian dulu ya.",
        "Tersedia untuk COD/ambil di tempat (jika memungkinkan).",
        "Boleh request sesuai kebutuhan.",
    ]

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
        wa = form["wa"]
        loc = f"\n📍 Lokasi: {form['location']}" if form["location"] else ""
        extra = f"\nℹ️ Catatan: {form['extra']}" if form["extra"] else ""

        # pilih benefit berdasarkan tipe usaha
        benefit = pick(benefits_produk if form["biz_type"] == "produk" else benefits_jasa)

        # pilih hook & CTA sesuai tone
        hook = pick(hooks[form["tone"]])
        cta = pick(ctas[form["tone"]])

        # template caption yang GENERIK
        if form["template"] == "promo":
            caption_text = (
                f"{hook}\n"
                f"🎯 {nama}\n"
                f"💰 Mulai {harga}\n"
                f"✅ {benefit}\n"
                f"📌 {pick(promo_lines)}"
                f"{loc}{extra}\n\n"
                f"{cta} {wa}"
            )

        elif form["template"] == "new":
            caption_text = (
                f"{hook}\n"
                f"✨ Rilis / Tersedia: {nama}\n"
                f"💰 Harga: {harga}\n"
                f"✅ {benefit}"
                f"{loc}{extra}\n\n"
                f"{cta} {wa}"
            )

        elif form["template"] == "testi":
            # testi dibuat generik agar cocok semua usaha
            testis = [
                "“Pelayanannya cepat dan responsif.”",
                "“Hasilnya sesuai ekspektasi, recommended!”",
                "“Harga oke, kualitas juga bagus.”",
                "“Prosesnya mudah, next bakal order lagi.”",
            ]
            caption_text = (
                f"{hook}\n"
                f"⭐ Kata pelanggan tentang {nama}:\n"
                f"{pick(testis)}\n"
                f"💰 Mulai {harga}\n"
                f"✅ {benefit}"
                f"{loc}{extra}\n\n"
                f"{cta} {wa}"
            )

        elif form["template"] == "reminder":
            reminders = [
                "Slot/stok terbatas, amankan dulu ya.",
                "Yang minat bisa booking sekarang.",
                "Jangan nunggu ramai dulu, biar kebagian.",
                "Bisa tanya detail dulu sebelum order.",
            ]
            caption_text = (
                f"{hook}\n"
                f"⏰ Reminder: {nama}\n"
                f"💰 Mulai {harga}\n"
                f"✅ {benefit}\n"
                f"📌 {pick(reminders)}"
                f"{loc}{extra}\n\n"
                f"{cta} {wa}"
            )

    return render_template("caption.html", caption=caption_text, form=form)

def _rupiah(value: str) -> str:
    try:
        n = int(value)
        return f"Rp {n:,}".replace(",", ".")
    except:
        return f"Rp {value}"

def _pick(rng, items):
    return items[rng.randrange(len(items))]

def build_caption(data: dict) -> tuple[str, str]:
    """
    Return (caption, variant_id)
    """
    # RNG dibuat dari time agar regenerate beda
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

    # bank variasi (lebih banyak & generik)
    hooks = {
        "santai": [
            "Lagi cari yang pas? Cek ini dulu 👇",
            "Biar nggak bingung, ini info singkatnya 👇",
            "Yang ini lagi banyak ditanya nih 👇",
            "Info cepat, siapa tau cocok 👇",
            "Gas cek detailnya ya 👇",
        ],
        "formal": [
            "Berikut informasi penawaran kami:",
            "Kami menyediakan layanan/produk berikut:",
            "Informasi layanan/produk untuk Anda:",
            "Rincian penawaran saat ini:",
            "Detail layanan/produk:",
        ],
        "sales": [
            "Jangan sampai kelewatan!",
            "Terbatas! Amankan sekarang!",
            "Yang cepat yang dapat!",
            "Kesempatan bagus—gas sekarang!",
            "Hari ini doang, jangan ditunda!",
        ],
    }

    benefits_produk = [
        "Kualitas terjaga",
        "Bahan/finishing rapi",
        "Cocok untuk kebutuhan harian",
        "Bisa request varian/ukuran (tanya admin)",
        "Praktis & siap pakai",
        "Packing aman",
    ]
    benefits_jasa = [
        "Pengerjaan rapi & profesional",
        "Bisa konsultasi dulu sebelum mulai",
        "Tepat waktu sesuai kesepakatan",
        "Harga transparan",
        "Dikerjakan tenaga berpengalaman",
        "Bisa booking jadwal",
    ]

    ctas = {
        "santai": [
            "Chat aja ya 👉",
            "Langsung WA ya 👉",
            "Mau tanya dulu boleh banget 👉",
            "Siap bantu order 👉",
            "Cus WA sekarang 👉",
        ],
        "formal": [
            "Silakan hubungi:",
            "Untuk informasi/pemesanan:",
            "Reservasi/pemesanan melalui:",
            "Hubungi admin:",
        ],
        "sales": [
            "Order sekarang!",
            "Amankan slot/stok sekarang!",
            "Langsung WA!",
            "Klik WA sekarang juga!",
        ],
    }

    hashtags_general = [
        "#UMKM", "#Promo", "#Diskon", "#LocalBrand", "#Indonesia", "#BisnisLokal",
        "#Jasa", "#Produk", "#OnlineShop", "#KotaKamu"
    ]

    benefit = _pick(rng, benefits_produk if biz_type == "produk" else benefits_jasa)
    hook = _pick(rng, hooks.get(tone, hooks["santai"]))
    cta = _pick(rng, ctas.get(tone, ctas["santai"]))
    tagline = _pick(rng, ["✨", "🔥", "📌", "✅", "💡", "⚡"])

    # variasi struktur (biar nggak monoton)
    structures = [
        "A", "B", "C"
    ]
    s = _pick(rng, structures)

    if template == "promo":
        promo_line = _pick(rng, [
            "Harga spesial periode terbatas.",
            "Bisa tanya detail/varian dulu ya.",
            "Cocok buat yang lagi cari solusi cepat.",
            "Bisa order sekarang, proses mudah.",
            "Bonus/benefit sesuai catatan ya."
        ])
        if s == "A":
            caption = (
                f"{hook}\n\n"
                f"{tagline} {product}\n"
                f"💰 Mulai {price}\n"
                f"✅ {benefit}\n"
                f"{loc_line}{extra_line}"
                f"📌 {promo_line}\n\n"
                f"{cta} {wa}\n"
                f"{_pick(rng, hashtags_general)} {_pick(rng, hashtags_general)} {_pick(rng, hashtags_general)}"
            )
        elif s == "B":
            caption = (
                f"{tagline} PROMO!\n"
                f"{product} (mulai {price})\n"
                f"- {benefit}\n"
                f"- {promo_line}\n"
                f"{loc_line}{extra_line}\n"
                f"{cta} {wa}"
            )
        else:
            caption = (
                f"{hook}\n"
                f"🎯 {product} • {price}\n"
                f"✅ {benefit}\n"
                f"{loc_line}{extra_line}"
                f"⏳ {promo_line}\n"
                f"📲 {cta} {wa}"
            )

    elif template == "new":
        intro = _pick(rng, ["Rilis!", "Baru tersedia!", "Update terbaru!", "New arrival!", "Now available!"])
        if s == "A":
            caption = (
                f"{hook}\n\n"
                f"✨ {intro} {product}\n"
                f"💰 Harga: {price}\n"
                f"✅ {benefit}\n"
                f"{loc_line}{extra_line}"
                f"{cta} {wa}\n"
                f"{_pick(rng, hashtags_general)} {_pick(rng, hashtags_general)}"
            )
        elif s == "B":
            caption = (
                f"✨ {intro}\n"
                f"{product}\n"
                f"Harga {price}\n"
                f"Keunggulan: {benefit}\n"
                f"{loc_line}{extra_line}"
                f"{cta} {wa}"
            )
        else:
            caption = (
                f"{hook}\n"
                f"🆕 {product} — {price}\n"
                f"✅ {benefit}\n"
                f"{loc_line}{extra_line}"
                f"📩 {cta} {wa}"
            )

    elif template == "testi":
        testis = [
            "“Respon cepat, prosesnya gampang.”",
            "“Hasilnya rapi, sesuai harapan.”",
            "“Worth it! Bakal order lagi.”",
            "“Admin ramah, recommended!”",
            "“Kualitas oke, harga masuk.”",
        ]
        testi = _pick(rng, testis)
        if s == "A":
            caption = (
                f"{hook}\n\n"
                f"⭐ Testimoni tentang {product}:\n"
                f"{testi}\n\n"
                f"💰 Mulai {price}\n"
                f"✅ {benefit}\n"
                f"{loc_line}{extra_line}"
                f"{cta} {wa}"
            )
        elif s == "B":
            caption = (
                f"⭐ TESTIMONI\n"
                f"{testi}\n"
                f"Produk/Layanan: {product}\n"
                f"Mulai: {price}\n"
                f"{loc_line}{extra_line}"
                f"{cta} {wa}"
            )
        else:
            caption = (
                f"{hook}\n"
                f"⭐ {testi}\n"
                f"📌 {product} • {price}\n"
                f"✅ {benefit}\n"
                f"{loc_line}{extra_line}"
                f"📲 {cta} {wa}"
            )

    else:  # reminder
        rem = _pick(rng, [
            "Slot/stok terbatas, amankan dulu ya.",
            "Bisa booking sekarang biar kebagian.",
            "Jangan tunggu ramai, takutnya habis.",
            "Kalau minat, bisa chat dulu untuk detail.",
            "Yang butuh cepat, ini waktunya!"
        ])
        if s == "A":
            caption = (
                f"{hook}\n\n"
                f"⏰ Reminder: {product}\n"
                f"💰 Mulai {price}\n"
                f"✅ {benefit}\n"
                f"{loc_line}{extra_line}"
                f"📌 {rem}\n\n"
                f"{cta} {wa}"
            )
        elif s == "B":
            caption = (
                f"⏰ REMINDER\n"
                f"{product} (mulai {price})\n"
                f"- {benefit}\n"
                f"- {rem}\n"
                f"{loc_line}{extra_line}"
                f"{cta} {wa}"
            )
        else:
            caption = (
                f"{hook}\n"
                f"⏰ {product} • {price}\n"
                f"✅ {benefit}\n"
                f"{loc_line}{extra_line}"
                f"📌 {rem}\n"
                f"📲 {cta} {wa}"
            )

    variant_id = hex(seed)[-6:]  # id kecil buat nunjukin beda
    return caption.strip(), variant_id



def _now_wib_naive_from_form():
    """
    Return datetime naive (tanpa tzinfo) tapi nilai waktunya WIB.
    Ini mencegah lari -7 jam saat disimpan ke kolom timestamp without time zone.
    """
    client_ts = request.form.get("client_ts")
    if client_ts and client_ts.isdigit():
        # epoch ms -> convert ke WIB aware
        now_wib_aware = datetime.fromtimestamp(int(client_ts) / 1000, tz=ZoneInfo("Asia/Jakarta"))
    else:
        now_wib_aware = datetime.now(ZoneInfo("Asia/Jakarta"))

    # simpan sebagai naive WIB (tanpa tzinfo)
    return now_wib_aware.replace(tzinfo=None)


# =========================
# USER: VIEW
# =========================
@app.route("/attendance")
def attendance_page():
    if not is_logged_in():
        return redirect("/login")
    if is_admin():
        return redirect("/admin")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        SELECT work_date, arrival_type, status, note, checkin_at
        FROM attendance
        WHERE user_id=%s
        ORDER BY work_date DESC, checkin_at DESC NULLS LAST;
    """, (session["user_id"],))
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("attendance.html", rows=rows)


# =========================
# USER: SUBMIT
# =========================
@app.route("/attendance/add", methods=["POST"])
def attendance_add():
    if not is_logged_in():
        return redirect("/login")

    arrival_type = (request.form.get("arrival_type") or "ONTIME").strip().upper()
    note = (request.form.get("note") or "").strip()

    now = _now_wib_naive_from_form()
    work_date = now.date()
    checkin_at = now

    # mapping status
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

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    # cek apakah sudah pernah absen hari ini (agar poin tidak dobel)
    cur.execute("""
        SELECT 1 FROM attendance
        WHERE user_id=%s AND work_date=%s
        LIMIT 1;
    """, (session["user_id"], work_date))
    already = cur.fetchone() is not None

    # upsert attendance
    # upsert attendance
    cur.execute("""
      INSERT INTO attendance (user_id, work_date, status, arrival_type, note, checkin_at)
      VALUES (%s, %s, %s, %s, %s, %s)
      ON CONFLICT (user_id, work_date)
      DO UPDATE SET
        status=EXCLUDED.status,
        arrival_type=EXCLUDED.arrival_type,
        note=EXCLUDED.note,
        checkin_at=EXCLUDED.checkin_at;
    """, (session["user_id"], work_date, status, arrival_type, note, checkin_at))

    # POIN ABSENSI DIMATIKAN (tidak ada update users.points)
    if not already:
        cur.execute("UPDATE users SET points = COALESCE(points,0) + 1 WHERE id=%s;", (session["user_id"],))


    conn.commit()
    cur.close()
    conn.close()
    return redirect("/attendance")


# =========================
# ADMIN: VIEW
# =========================
@app.route("/admin/attendance")
def admin_attendance():
    r = admin_guard()
    if r:
        return r

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    # list karyawan (role employee)
    cur.execute("""
        SELECT id, name, email
        FROM users
        WHERE role='employee'
        ORDER BY name ASC;
    """)
    employees = cur.fetchall()

    # riwayat absensi terbaru
    cur.execute("""
        SELECT a.work_date, a.arrival_type, a.status, a.note, a.checkin_at,
               u.name AS employee_name
        FROM attendance a
        JOIN users u ON u.id=a.user_id
        ORDER BY a.work_date DESC, a.checkin_at DESC NULLS LAST
        LIMIT 80;
    """)
    rows = cur.fetchall()

    cur.close()
    conn.close()
    return render_template("admin_attendance.html", employees=employees, rows=rows)


# =========================
# ADMIN: SUBMIT
# =========================
@app.route("/admin/attendance/add", methods=["POST"])
def admin_attendance_add():
    deny = admin_required()
    if deny:
        return deny

    user_id = int(request.form["user_id"])
    arrival_type = (request.form.get("arrival_type") or "ONTIME").strip().upper()
    note = (request.form.get("note") or "").strip()

    # mapping arrival_type -> status
    if arrival_type in ("SICK", "LEAVE", "ABSENT"):
        status = arrival_type
    else:
        status = "PRESENT"

    # ==== WAKTU CHECKIN ====
    # Absen saya (admin sendiri) -> wajib live (pakai client_ts)
    # Absen karyawan -> boleh manual_checkin (datetime-local), kalau kosong pakai client_ts/live
    manual_checkin = (request.form.get("manual_checkin") or "").strip()

    if user_id == session.get("user_id"):
        # admin absen dirinya sendiri: live
        now = _now_wib_naive_from_form()
    else:
        # admin absenkan karyawan: boleh manual
        now = _parse_manual_wib_naive(manual_checkin) or _now_wib_naive_from_form()

    work_date = now.date()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    # cek existing (berdasarkan work_date dari waktu yang dipilih)
    cur.execute("""
      SELECT id, status
      FROM attendance
      WHERE user_id=%s AND work_date=%s
      LIMIT 1
    """, (user_id, work_date))
    existing = cur.fetchone()

    if existing:
        att_id = existing["id"]
        cur.execute("""
          UPDATE attendance
          SET status=%s, arrival_type=%s, note=%s, checkin_at=%s
          WHERE id=%s
        """, (status, arrival_type, note, now, att_id))
    else:
        cur.execute("""
          INSERT INTO attendance (user_id, work_date, status, arrival_type, note, created_at, checkin_at)
          VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (user_id, work_date, status, arrival_type, note, now, now))

    conn.commit()
    cur.close()
    conn.close()
    return redirect("/admin/attendance")






#HITUNG GAJI ADMIN#

def sync_user_points_total(user_id: int):
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
      SELECT COALESCE(SUM(CASE WHEN status='PRESENT' THEN 1 ELSE 0 END), 0) AS points
      FROM attendance
      WHERE user_id=%s;
    """, (user_id,))
    points = cur.fetchone()["points"]

    cur.execute("UPDATE users SET points=%s WHERE id=%s;", (points, user_id))
    conn.commit()
    cur.close()
    conn.close()







def count_workdays_only_sunday_off(start_date, end_date):
    # end_date = tanggal bulan berikutnya (exclusive)
    # libur hanya minggu
    d = start_date
    n = 0
    while d < end_date:
        # Monday=0 ... Sunday=6
        if d.weekday() != 6:
            n += 1
        d = d.fromordinal(d.toordinal() + 1)
    return n

@app.route("/admin/payroll")
def admin_payroll():
    deny = admin_required()
    if deny:
        return deny

    month = request.args.get("month")  # YYYY-MM
    if not month:
        today = date.today()
        month = f"{today.year:04d}-{today.month:02d}"

    year = int(month.split("-")[0])
    mon = int(month.split("-")[1])

    start_date = date(year, mon, 1)
    if mon == 12:
        end_date = date(year + 1, 1, 1)
    else:
        end_date = date(year, mon + 1, 1)

    # Minggu libur (Senin–Sabtu kerja)
    WORKDAYS = count_workdays_only_sunday_off(start_date, end_date)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute(
        """
        SELECT
            u.id,
            u.name,
            COALESCE(p.daily_salary, 0)   AS daily_salary,
            COALESCE(p.monthly_salary, 0) AS monthly_salary,

            COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END), 0) AS days_present,
            COALESCE(SUM(CASE WHEN a.status='SICK'    THEN 1 ELSE 0 END), 0) AS days_sick,
            COALESCE(SUM(CASE WHEN a.status='LEAVE'   THEN 1 ELSE 0 END), 0) AS days_leave,
            COALESCE(SUM(CASE WHEN a.status='ABSENT'  THEN 1 ELSE 0 END), 0) AS days_absent
        FROM users u
        LEFT JOIN payroll_settings p ON p.user_id = u.id
        LEFT JOIN attendance a
            ON a.user_id = u.id
            AND a.work_date >= %s
            AND a.work_date < %s
        WHERE u.role = 'employee'
        GROUP BY u.id, u.name, p.daily_salary, p.monthly_salary
        ORDER BY u.name ASC;
        """,
        (start_date, end_date),
    )

    rows = cur.fetchall()
    cur.close()
    conn.close()

    result = []
    for r in rows:
        daily_salary = int(r.get("daily_salary") or 0)
        monthly_salary = int(r.get("monthly_salary") or 0)

        # fallback kalau daily_salary belum diset tapi monthly_salary ada
        if daily_salary == 0 and monthly_salary > 0 and WORKDAYS > 0:
            daily_salary = int(round(monthly_salary / WORKDAYS))

        days_present = int(r.get("days_present") or 0)
        salary_paid = int(daily_salary * days_present)

        result.append({
            "id": r["id"],
            "name": r["name"],
            "daily_salary": int(daily_salary),
            "workdays": int(WORKDAYS),
            "days_present": days_present,
            "days_sick": int(r.get("days_sick") or 0),
            "days_leave": int(r.get("days_leave") or 0),
            "days_absent": int(r.get("days_absent") or 0),
            "salary_paid": salary_paid,
        })

    return render_template(
        "admin_payroll.html",
        month=month,
        rows=result,
        workdays=int(WORKDAYS),
    )









# --- PATCH LOGIN: simpan role ke session ---
# DI DALAM fungsi login() kamu, ganti query SELECT jadi ambil role juga.
# yang sekarang: SELECT id, name, email, password_hash ...
# ubah jadi:
# cur.execute("SELECT id, name, email, password_hash, role FROM users WHERE email=%s;", (email,))

# lalu setelah set session user_id & user_name, tambahkan:
# session["role"] = user.get("role", "user")


# --- PATCH REGISTER: pastikan role default 'user' ---
# Setelah berhasil insert user pada register(), set:
# session["role"] = "user"





# =========================
# USER: SUBMIT SALES
# - Karyawan bisa jual: produk GLOBAL (admin) + produk miliknya sendiri
# - Admin kalau akses /sales -> diarahkan ke /admin/sales
# =========================
@app.route("/sales", methods=["GET", "POST"])
def sales_user():
    if not is_logged_in():
        return redirect("/login")

    # Admin jangan masuk halaman sales user
    if session.get("role") == "admin":
        return redirect("/admin/sales")

    if request.method == "POST":
        product_id = request.form.get("product_id")
        qty = request.form.get("qty") or "0"
        note = (request.form.get("note") or "").strip()

        try:
            product_id = int(product_id)
            qty_int = int(qty)
        except:
            return redirect("/sales")

        if qty_int <= 0:
            return redirect("/sales")

        conn = get_conn()
        cur = conn.cursor()

        # ✅ Validasi: user hanya boleh submit produk GLOBAL (buatan admin)
        cur.execute("""
            SELECT id
            FROM products
            WHERE id=%s AND is_global=TRUE;
        """, (product_id,))
        ok = cur.fetchone()

        if not ok:
            cur.close()
            conn.close()
            return redirect("/sales")

        cur.execute("""
            INSERT INTO sales_submissions (user_id, product_id, qty, note, status)
            VALUES (%s, %s, %s, %s, 'PENDING');
        """, (session["user_id"], product_id, qty_int, note))

        conn.commit()
        cur.close()
        conn.close()
        return redirect("/sales")

    # GET: tampilkan form + riwayat
    conn = get_conn()
    cur = conn.cursor()

    # ✅ Dropdown produk: hanya produk GLOBAL (admin)
    cur.execute("""
        SELECT id, name
        FROM products
        WHERE is_global=TRUE
        ORDER BY id DESC;
    """)
    products = cur.fetchall()

    # riwayat submit user
    cur.execute("""
        SELECT s.id, s.qty, s.note, s.status, s.admin_note, s.created_at,
               COALESCE(p.name, '-') AS product_name
        FROM sales_submissions s
        LEFT JOIN products p ON p.id = s.product_id
        WHERE s.user_id=%s
        ORDER BY s.id DESC
        LIMIT 50;
    """, (session["user_id"],))
    rows = cur.fetchall()

    cur.close()
    conn.close()

    return render_template("sales.html", products=products, rows=rows)



# =========================
# ADMIN: SALES (APPROVAL)
# =========================
@app.route("/admin/sales")
def admin_sales():
    admin_guard()

    conn = get_conn()
    cur = conn.cursor()

    # daftar submit (pending paling atas)
    cur.execute("""
      SELECT
        s.id,
        s.qty,
        s.note,
        s.status,
        s.admin_note,
        s.created_at,
        u.name AS employee_name,
        p.name AS product_name
      FROM sales_submissions s
      JOIN users u ON u.id = s.user_id
      LEFT JOIN products p ON p.id = s.product_id
      ORDER BY
        (CASE WHEN s.status='PENDING' THEN 0 ELSE 1 END),
        s.created_at DESC
      LIMIT 300;
    """)
    rows = cur.fetchall()

    cur.close()
    conn.close()

    return render_template("admin_sales.html", rows=rows)


@app.route("/admin/sales/approve/<int:sid>", methods=["POST"])
def admin_sales_approve(sid):
    admin_guard()
    admin_note = (request.form.get("admin_note") or "").strip()
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
        UPDATE sales_submissions
        SET status='APPROVED',
            admin_note=%s,
            decided_at=CURRENT_TIMESTAMP,
            decided_by=%s
        WHERE id=%s;
    """, (admin_note, session["user_id"], sid))
    conn.commit()
    cur.close(); conn.close()
    return redirect("/admin/sales")



@app.route("/admin/sales/reject/<int:sid>", methods=["POST"])
def admin_sales_reject(sid):
    admin_guard()
    admin_note = (request.form.get("admin_note") or "").strip()

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("""
      UPDATE sales_submissions
      SET status='REJECTED',
          admin_note=%s,
          decided_at=CURRENT_TIMESTAMP,
          decided_by=%s
      WHERE id=%s;
    """, (admin_note, session["user_id"], sid))
    conn.commit()
    cur.close()
    conn.close()

    return redirect("/admin/sales")


# =========================
# ADMIN: SALES (MONITORING)
# =========================
@app.route("/admin/sales/monitor")
def admin_sales_monitor():
    admin_guard()

    conn = get_conn()
    cur = conn.cursor()

    # Rekap per karyawan (total qty)
    cur.execute("""
      SELECT u.id, u.name AS employee_name,
             COALESCE(SUM(s.qty), 0) AS total_qty
      FROM users u
      LEFT JOIN sales_submissions s ON s.user_id = u.id AND s.status='APPROVED'
      WHERE u.role='employee'
      GROUP BY u.id, u.name
      ORDER BY total_qty DESC, u.name ASC;
    """)
    summary = cur.fetchall()

    # Detail submit terbaru (lihat jam+tanggal)
    cur.execute("""
      SELECT s.created_at,
             u.name AS employee_name,
             p.name AS product_name,
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

    cur.close()
    conn.close()

    return render_template("admin_sales_monitor.html", summary=summary, rows=rows)




@app.route("/admin/stats")
def admin_stats():
    admin_guard()

    month = request.args.get("month")  # YYYY-MM
    if not month:
        today = date.today()
        month = f"{today.year:04d}-{today.month:02d}"

    year = int(month.split("-")[0])
    mon = int(month.split("-")[1])

    start_date = date(year, mon, 1)
    if mon == 12:
        end_date = date(year + 1, 1, 1)
    else:
        end_date = date(year, mon + 1, 1)

    conn = get_conn()
    cur = conn.cursor()

    # Rekap absensi per karyawan di bulan itu
    cur.execute("""
      SELECT
        u.id,
        u.name AS employee_name,
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

    # Rekap sales qty per karyawan di bulan itu
    cur.execute("""
      SELECT
        u.id,
        COALESCE(SUM(s.qty), 0) AS sales_qty
      FROM users u
      LEFT JOIN sales_submissions s
        ON s.user_id=u.id
        AND s.created_at >= %s AND s.created_at < %s
      WHERE u.role='employee'
      GROUP BY u.id;
    """, (start_date, end_date))
    sales = cur.fetchall()

    cur.close()
    conn.close()

    # gabungkan hasil
    sales_map = {r["id"]: int(r["sales_qty"] or 0) for r in sales}

    rows = []
    totals = {"present":0,"late":0,"sick":0,"leave":0,"absent":0,"sales":0}
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


from datetime import timedelta

# ======================================================================
#  ADMIN DASHBOARD (GANTI route admin_dashboard kamu jadi ini)
# ======================================================================
@app.route("/admin/dashboard")
def admin_dashboard():
    deny = admin_required()
    if deny:
        return deny

    ensure_points_schema()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    # KPI ringkas
    cur.execute("SELECT COUNT(*) AS total FROM users WHERE role='employee';")
    total_employees = cur.fetchone()["total"]

    today = date.today()
    cur.execute("""
        SELECT COUNT(*) AS total
        FROM attendance
        WHERE work_date=%s
          AND status='PRESENT';
    """, (today,))
    total_attendance_today = cur.fetchone()["total"]

    cur.execute("SELECT COUNT(*) AS total FROM products;")
    total_products = cur.fetchone()["total"]

    # list employee untuk dropdown export (Data section)
    cur.execute("""
        SELECT id, name, email
        FROM users
        WHERE role='employee'
        ORDER BY name ASC;
    """)
    employees = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        "admin_dashboard.html",
        user_name=session.get("user_name","Admin"),
        notif_count=0,
        total_employees=total_employees,
        total_attendance_today=total_attendance_today,
        total_products=total_products,
        employees=employees
    )





# =========================
# EXPORT XLSX (RANGE 1 BULAN, MAX 31 HARI, 6 BULAN TERAKHIR)
# =========================
def _parse_date(s: str | None) -> date | None:
    if not s:
        return None
    try:
        return datetime.strptime(s, "%Y-%m-%d").date()
    except Exception:
        return None

def _validate_range(start: date, end: date) -> tuple[bool, str]:
    if end < start:
        return False, "Tanggal akhir harus >= tanggal awal."
    days = (end - start).days + 1
    if days > 31:
        return False, "Maksimal range 31 hari."

    today = datetime.now(ZoneInfo("Asia/Jakarta")).date()
    if start < (today - timedelta(days=183)):
        return False, "Range hanya boleh dari 6 bulan terakhir."

    # 1 bulan yang sama (biar kalau ganti bulan, rekap bulan lalu otomatis tidak dipakai)
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

def _build_attendance_xlsx(rows_detail: list[dict], recap_rows: list[dict], title: str) -> bytes:
    wb = Workbook()
    ws = wb.active
    ws.title = "Detail"

    ws.append([title])
    ws.append([])
    # ✅ Detail: hapus "Gaji Hari Ini", ganti "Catatan"
    ws.append(["Nama", "Tanggal", "Jam Kehadiran", "Status", "Gaji Harian", "Catatan"])

    for r in rows_detail:
        ws.append([
            r.get("name", ""),
            r.get("work_date", ""),
            r.get("checkin_time", ""),
            r.get("status", ""),
            r.get("daily_salary", 0),
            r.get("note", "")  # ✅ catatan dari attendance.note
        ])

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


def ensure_hr_v2_schema():
    """
    Auto-ensure skema HR v2 sebelum route-route penting jalan.
    Aman dipanggil berkali-kali.
    """
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
        cur.execute("""
          ALTER TABLE payroll_settings
          ADD COLUMN IF NOT EXISTS daily_salary INTEGER NOT NULL DEFAULT 0;
        """)
        cur.execute("""
          ALTER TABLE payroll_settings
          ADD COLUMN IF NOT EXISTS monthly_salary INTEGER NOT NULL DEFAULT 0;
        """)
        cur.execute("""
          ALTER TABLE payroll_settings
          ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
        """)
        cur.execute("""
          ALTER TABLE attendance
          ADD COLUMN IF NOT EXISTS arrival_type VARCHAR(20) NOT NULL DEFAULT 'ONTIME';
        """)
        cur.execute("""
          ALTER TABLE attendance
          ADD COLUMN IF NOT EXISTS checkin_at TIMESTAMP NULL;
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()


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
    SELECT
      u.name,
      COALESCE(p.daily_salary, 0) AS daily_salary,
      a.work_date,
      a.status,
      a.note,         -- ✅ tambah ini
      a.checkin_at
    FROM attendance a
    JOIN users u ON u.id = a.user_id
    LEFT JOIN payroll_settings p ON p.user_id = u.id
    WHERE u.role='employee'
      AND a.work_date >= %s
      AND a.work_date <= %s
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

        checkin_time = ""
        if r["checkin_at"]:
            try:
                checkin_time = r["checkin_at"].strftime("%H:%M:%S")
            except Exception:
                checkin_time = str(r["checkin_at"])

        salary_day = ds if status == "PRESENT" else 0

        detail.append({
            "name": name,
            "work_date": r["work_date"].isoformat() if r["work_date"] else "",
            "checkin_time": checkin_time,
            "status": status,
            "daily_salary": ds,
            "note": (r.get("note") or "").strip(),  # ✅ catatan
        })


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

    return Response(
        xlsx_bytes,
        mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'}
    )

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
        cur.close(); conn.close()
        return "User tidak ditemukan", 404
    user_name = urow["name"]

    cur.execute("""
    SELECT
      COALESCE(p.daily_salary, 0) AS daily_salary,
      a.work_date,
      a.status,
      a.note,         -- ✅ tambah ini
      a.checkin_at
    FROM attendance a
    LEFT JOIN payroll_settings p ON p.user_id = a.user_id
    WHERE a.user_id=%s
      AND a.work_date >= %s
      AND a.work_date <= %s
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

        checkin_time = ""
        if r["checkin_at"]:
            try:
                checkin_time = r["checkin_at"].strftime("%H:%M:%S")
            except Exception:
                checkin_time = str(r["checkin_at"])

        salary_day = ds if status == "PRESENT" else 0

        detail.append({
            "name": user_name,
            "work_date": r["work_date"].isoformat() if r["work_date"] else "",
            "checkin_time": checkin_time,
            "status": status,
            "daily_salary": ds,
            "note": (r.get("note") or "").strip(),  # ✅ catatan
        })


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

    return Response(
        xlsx_bytes,
        mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'}
    )



# ======================================================================
#  INPUT POIN 
# ======================================================================
@app.route("/admin/points")
def admin_points():
    deny = admin_required()
    if deny:
        return deny

    ensure_points_schema()  # punyamu

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    # dropdown + monitor
    cur.execute("""
        SELECT
          id, name, email,
          COALESCE(points, 0) AS points,
          COALESCE(points_admin, 0) AS points_admin
        FROM users
        WHERE role = 'employee'
        ORDER BY name ASC;
    """)
    employees = cur.fetchall()

    # log 50 terakhir
    cur.execute("""
        SELECT
          l.created_at,
          u.name AS user_name,
          l.delta,
          l.note,
          a.name AS admin_name
        FROM points_logs l
        JOIN users u ON u.id = l.user_id
        JOIN users a ON a.id = l.admin_id
        ORDER BY l.created_at DESC
        LIMIT 50;
    """)
    logs = cur.fetchall()

    cur.close()
    conn.close()

    return render_template(
        "input_poin.html",
        user_name=session.get("user_name"),
        notif_count=0,
        employees=employees,
        logs=logs
    )



@app.route("/admin/points/add", methods=["POST"])
def admin_points_add():
    deny = admin_required()
    if deny:
        return deny

    ensure_points_schema()

    user_id = int(request.form["user_id"])
    delta_raw = (request.form.get("delta") or "").strip()
    note = (request.form.get("note") or "").strip()

    try:
        delta = int(delta_raw)
    except:
        return "Delta poin harus angka. Contoh: 10 atau -5", 400

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    # update points_admin (hanya employee biar admin tidak ikut)
    cur.execute("""
        UPDATE users
        SET points_admin = COALESCE(points_admin,0) + %s
        WHERE id=%s AND role='employee';
    """, (delta, user_id))

    # insert log
    cur.execute("""
        INSERT INTO points_logs (user_id, admin_id, delta, note)
        VALUES (%s, %s, %s, %s);
    """, (user_id, session.get("user_id"), delta, note if note else None))

    conn.commit()
    cur.close()
    conn.close()

    return redirect("/admin/points")


# =======================
# EMAIL + OTP HELPERS
# =======================
def _otp_hash(email: str, otp: str) -> str:
    """
    Hash OTP pakai salt biar aman.
    """
    salt = (os.getenv("RESET_OTP_SALT") or "umgap-reset-salt").encode("utf-8")
    msg = (email.lower().strip() + ":" + otp.strip()).encode("utf-8")
    return hashlib.sha256(salt + msg).hexdigest()


def ensure_password_reset_schema():
    """
    Table untuk simpan OTP reset password.
    """
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


def send_email(to_email: str, subject: str, body: str):
    """
    Kirim email OTP via SMTP.
    Set env di Render:
      SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
    """
    host = (os.getenv("SMTP_HOST") or "").strip()
    port = int(os.getenv("SMTP_PORT") or "587")
    user = (os.getenv("SMTP_USER") or "").strip()
    passwd = (os.getenv("SMTP_PASS") or "").strip()
    mail_from = (os.getenv("SMTP_FROM") or user).strip()

    if not host or not user or not passwd:
        raise RuntimeError("SMTP belum dikonfigurasi. Set SMTP_HOST/SMTP_USER/SMTP_PASS.")

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


# =======================
# GOOGLE LOGIN (Authlib) - FINAL
# =======================
from authlib.integrations.flask_client import OAuth

# Pastikan secret key stabil (WAJIB supaya state OAuth aman)
app.secret_key = os.getenv("SECRET_KEY", "dev-secret")

# ===== Session cookie config (OAuth safe) =====
IS_PROD = os.getenv("RENDER") == "true" or os.getenv("FLASK_ENV") == "production"

app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
app.config["SESSION_COOKIE_SECURE"] = True if IS_PROD else False
app.config["PREFERRED_URL_SCHEME"] = "https" if IS_PROD else "http"

app.config["SESSION_COOKIE_HTTPONLY"] = True

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


@app.route("/login/google")
def login_google():
    if not (GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET):
        return "Google OAuth belum dikonfigurasi", 500

    redirect_uri = url_for("google_callback", _external=True)
    return oauth.google.authorize_redirect(redirect_uri)

@app.route("/auth/google/callback")
def google_callback():
    token = oauth.google.authorize_access_token()

    userinfo = token.get("userinfo")
    if not userinfo:
        userinfo = oauth.google.get(
            "https://openidconnect.googleapis.com/v1/userinfo"
        ).json()

    email = userinfo.get("email", "").lower()
    name = userinfo.get("name", "User")

    if not email:
        return "Email Google tidak ditemukan", 400

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute(
        "SELECT id, name, role FROM users WHERE lower(email)=%s LIMIT 1;",
        (email,),
    )
    u = cur.fetchone()

    if not u:
        rand_pw = hashlib.sha256(f"{email}:{time.time()}".encode()).hexdigest()
        pw_hash = generate_password_hash(rand_pw)

        cur.execute(
            """
            INSERT INTO users (name, email, password_hash, role)
            VALUES (%s, %s, %s, %s)
            RETURNING id, name, role;
            """,
            (name, email, pw_hash, "employee"),
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

    # cek user ada
    cur.execute("SELECT id, email FROM users WHERE lower(email)=%s LIMIT 1;", (email,))
    u = cur.fetchone()
    if not u:
        cur.close()
        conn.close()
        # jangan bocorin bahwa email tidak terdaftar (lebih aman)
        return render_template("forgot_password.html", sent=True)

    # buat OTP 6 digit
    otp = f"{random.randint(0, 999999):06d}"
    otp_h = _otp_hash(email, otp)
    expires_at = datetime.utcnow() + timedelta(minutes=10)

    # optional: invalidate OTP lama yang belum dipakai
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
    cur.close()
    conn.close()

    # kirim email
    try:
        send_email(
            to_email=email,
            subject="UMGAP • Kode OTP Reset Password",
            body=(
                f"Halo,\n\n"
                f"Kode OTP reset password kamu: {otp}\n"
                f"Berlaku 10 menit.\n\n"
                f"Jika kamu tidak meminta reset, abaikan email ini.\n"
            ),
        )
    except Exception as e:
        # kalau SMTP error, tampilkan jelas biar gampang debug
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

    # ambil otp terbaru yang belum dipakai
    cur.execute("""
        SELECT id, otp_hash, expires_at, used
        FROM password_reset_otps
        WHERE email=%s AND used=FALSE
        ORDER BY created_at DESC
        LIMIT 1;
    """, (email,))
    row = cur.fetchone()

    if not row:
        cur.close(); conn.close()
        return "OTP tidak ditemukan / sudah dipakai. Minta OTP lagi.", 400

    if datetime.utcnow() > row["expires_at"]:
        # tandai used biar tidak dipakai lagi
        cur.execute("UPDATE password_reset_otps SET used=TRUE WHERE id=%s;", (row["id"],))
        conn.commit()
        cur.close(); conn.close()
        return "OTP sudah kedaluwarsa. Minta OTP lagi.", 400

    if not hmac.compare_digest(row["otp_hash"], otp_h):
        cur.close(); conn.close()
        return "OTP salah.", 400

    # update password
    pw_hash = generate_password_hash(new_password)

    cur.execute("UPDATE users SET password_hash=%s WHERE lower(email)=%s;", (pw_hash, email))
    cur.execute("UPDATE password_reset_otps SET used=TRUE WHERE id=%s;", (row["id"],))

    conn.commit()
    cur.close()
    conn.close()

    return redirect("/login")








@app.route("/api/caption", methods=["POST"])
def api_caption():
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Silakan login dulu."}), 401

    data = request.get_json(silent=True) or {}
    # validasi minimal
    for k in ["template", "biz_type", "tone", "product", "price", "wa"]:
        if not (data.get(k) or "").strip():
            return jsonify({"ok": False, "error": f"Field '{k}' wajib diisi."}), 400

    caption, vid = build_caption(data)
    return jsonify({"ok": True, "caption": caption, "variant_id": vid})


# ✅ app.run HARUS PALING BAWAH
if __name__ == "__main__":
    # Windows + werkzeug reloader sering bikin WinError 10038
    # Matikan reloader supaya tidak run 2x
    app.run(host="127.0.0.1", port=5000, debug=True, use_reloader=False)






try:
    init_db()
    init_hr_v2()
    init_points_v1()
except Exception as e:
    print("Init error:", e)

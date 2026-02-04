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
        return  # tidak ada perubahan poin

    delta = 1 if new_present else -1

    # points_total = akumulasi seumur hidup
    # points = bisa kamu pakai sebagai saldo saat ini (opsional)
    cur.execute("""
        UPDATE users
        SET
          points_total = COALESCE(points_total, 0) + %s,
          points       = COALESCE(points, 0) + %s
        WHERE id = %s
    """, (delta, delta, user_id))




def generate_caption_ai(product, price, style):
    prompt = f"""
Buatkan caption jualan singkat untuk UMKM.

Produk: {product}
Harga: {price}
Gaya: {style}

Gunakan bahasa Indonesia yang mudah dipahami.
Maksimal 2 kalimat + hashtag.
"""

    r = client.responses.create(
        model="gpt-4.1-mini",
        input=prompt
    )
    return r.output_text.strip()





app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "dev-secret")


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

@app.route("/debug-key")
def debug_key():
    k = os.getenv("OPENAI_API_KEY", "")
    if not k:
        return "OPENAI_API_KEY belum terbaca (cek .env & restart app)"
    return f"Key kebaca ✅ (last4: {k[-4:]})"


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

    if not product:
        return jsonify({"ok": False, "error": "Nama produk wajib diisi."}), 400

    try:
        caption = generate_caption_ai(product, price, style)
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


@app.route("/dashboard")
def dashboard_redirect():
    if not is_logged_in():
        return redirect("/login")

    role = session.get("role", "employee")
    if role == "admin":
        return redirect("/admin/dashboard")

    # user/karyawan arahkan ke halaman kerja utama
    return redirect("/sales")


@app.route("/")
@app.route("/dashboard")  # <-- tambah ini
def dashboard():
    if not is_logged_in():
        return redirect("/login")

    # ✅ Admin jangan masuk dashboard user
    if session.get("role") == "admin":
        return redirect("/admin/dashboard")

    conn = get_conn()
    cur = conn.cursor()

    # jumlah produk (untuk user)
    cur.execute("SELECT COUNT(*) AS total FROM products WHERE user_id=%s;", (session["user_id"],))
    total_products = cur.fetchone()["total"]

    # jumlah rencana konten
    cur.execute("SELECT COUNT(*) AS total FROM content_plans WHERE user_id=%s;", (session["user_id"],))
    total_contents = cur.fetchone()["total"]

    # jumlah konten yang sudah selesai
    cur.execute("SELECT COUNT(*) AS total FROM content_plans WHERE user_id=%s AND is_done=TRUE;", (session["user_id"],))
    total_done = cur.fetchone()["total"]

    cur.close()
    conn.close()

    return render_template(
        "dashboard.html",
        user_name=session.get("user_name"),
        total_products=total_products,
        total_contents=total_contents,
        total_done=total_done
    )



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


@app.route("/init-hr")
def init_hr():
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'employee';")

    cur.execute("""
      CREATE TABLE IF NOT EXISTS payroll_settings (
        user_id INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        monthly_salary INTEGER NOT NULL DEFAULT 0,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    """)

    cur.execute("""
      CREATE TABLE IF NOT EXISTS attendance (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        work_date DATE NOT NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'PRESENT',
        note TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, work_date)
      );
    """)

    cur.execute("""
      CREATE TABLE IF NOT EXISTS leave_requests (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        start_date DATE NOT NULL,
        end_date DATE NOT NULL,
        reason TEXT,
        status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
        admin_note TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    """)

    cur.execute("""
      CREATE TABLE IF NOT EXISTS sales_submissions (
        id SERIAL PRIMARY KEY,
        user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        product_id INTEGER REFERENCES products(id) ON DELETE SET NULL,
        qty INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    """)

    conn.commit()
    cur.close()
    conn.close()
    return "OK: HR tables siap."







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

    # === pakai jam dari page (client_ts) supaya sama dengan live ===
    client_ts = request.form.get("client_ts")
    if client_ts and client_ts.isdigit():
        now = datetime.fromtimestamp(int(client_ts) / 1000, tz=ZoneInfo("Asia/Jakarta"))
    else:
        now = datetime.now(ZoneInfo("Asia/Jakarta"))

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

    # upsert attendance (user_id, work_date harus UNIQUE)
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

    # tambah poin hanya jika pertama kali absen hari itu
    if not already:
        cur.execute("UPDATE users SET points = points + 1 WHERE id=%s;", (session["user_id"],))

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

    # list karyawan (yang role employee saja)
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

    # === pakai jam dari page (client_ts) supaya sama dengan live ===
    client_ts = request.form.get("client_ts")
    if client_ts and client_ts.isdigit():
        now = datetime.fromtimestamp(int(client_ts) / 1000, tz=ZoneInfo("Asia/Jakarta"))
    else:
        now = datetime.now(ZoneInfo("Asia/Jakarta"))

    today = now.date()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    # cek existing
    cur.execute("""
      SELECT id, status
      FROM attendance
      WHERE user_id=%s AND work_date=%s
      LIMIT 1
    """, (user_id, today))
    existing = cur.fetchone()

    if existing:
        att_id = existing["id"]
        old_status = existing["status"]

        # update: checkin_at pakai now agar sinkron jam submit
        cur.execute("""
          UPDATE attendance
          SET status=%s, arrival_type=%s, note=%s, checkin_at=%s
          WHERE id=%s
        """, (status, arrival_type, note, now, att_id))

        adjust_points_for_attendance_change(cur, user_id, old_status, status)
    else:
        cur.execute("""
          INSERT INTO attendance (user_id, work_date, status, arrival_type, note, created_at, checkin_at)
          VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (user_id, today, status, arrival_type, note, now, now))

        adjust_points_for_attendance_change(cur, user_id, None, status)

    conn.commit()
    cur.close()
    conn.close()
    return redirect("/admin/attendance")






#HITUNG GAJI ADMIN#

def sync_user_points_total(user_id: int):
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
      SELECT COALESCE(SUM(CASE WHEN status='PRESENT' THEN 1 ELSE 0 END), 0) AS points
      FROM attendance
      WHERE user_id=%s;
    """, (user_id,))
    points = cur.fetchone()["points"]

    cur.execute("UPDATE users SET points_total=%s WHERE id=%s;", (points, user_id))
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

    WORKDAYS = count_workdays_only_sunday_off(start_date, end_date)

    conn = get_conn()
    cur = conn.cursor()  # kalau get_conn kamu sudah RealDictCursor di db.py, ini aman

    # Ambil daily_salary + monthly_salary + rekap attendance
    cur.execute("""
      SELECT
        u.id,
        u.name,

        -- sumber gaji harian: payroll_settings.daily_salary -> users.daily_salary -> fallback dari monthly_salary/workdays
        COALESCE(p.daily_salary, NULL) AS daily_salary_setting,
        COALESCE(u.daily_salary, NULL) AS daily_salary_user,
        COALESCE(p.monthly_salary, 0)  AS monthly_salary,

        COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END), 0) AS days_present,
        COALESCE(SUM(CASE WHEN a.status='SICK'    THEN 1 ELSE 0 END), 0) AS days_sick,
        COALESCE(SUM(CASE WHEN a.status='LEAVE'   THEN 1 ELSE 0 END), 0) AS days_leave,
        COALESCE(SUM(CASE WHEN a.status='ABSENT'  THEN 1 ELSE 0 END), 0) AS days_absent,

        -- poin per bulan = jumlah hadir
        COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END), 0) AS points_earned

      FROM users u
      LEFT JOIN payroll_settings p ON p.user_id = u.id
      LEFT JOIN attendance a ON a.user_id = u.id
        AND a.work_date >= %s AND a.work_date < %s
      WHERE u.role = 'employee'
      GROUP BY u.id, u.name, p.daily_salary, u.daily_salary, p.monthly_salary
      ORDER BY u.name ASC;
    """, (start_date, end_date))

    rows = cur.fetchall()
    cur.close()
    conn.close()

    result = []
    for r in rows:
        # catatan: kalau cursor kamu RealDictCursor, r["..."] bisa dipakai.
        # kalau bukan, berarti r tuple. Tapi sebelumnya kamu memang pakai RealDictCursor.
        monthly_salary = int(r.get("monthly_salary") or 0)

        ds_setting = r.get("daily_salary_setting")
        ds_user = r.get("daily_salary_user")

        # users.daily_salary bertipe numeric → bisa Decimal
        if isinstance(ds_user, Decimal):
            ds_user = int(ds_user)

        daily_rate = None
        if ds_setting is not None:
            daily_rate = int(ds_setting)
        elif ds_user is not None:
            daily_rate = int(ds_user)
        else:
            # fallback dari monthly_salary / WORKDAYS
            daily_rate = int(round((monthly_salary / WORKDAYS))) if WORKDAYS > 0 else monthly_salary

        days_present = int(r.get("days_present") or 0)
        salary_paid = int(daily_rate * days_present)

        result.append({
            "id": r["id"],
            "name": r["name"],
            "daily_salary": int(daily_rate),
            "monthly_salary": monthly_salary,  # opsional buat info
            "workdays": int(WORKDAYS),
            "days_present": days_present,
            "days_sick": int(r.get("days_sick") or 0),
            "days_leave": int(r.get("days_leave") or 0),
            "days_absent": int(r.get("days_absent") or 0),
            "salary_paid": salary_paid,
            "points_earned": int(r.get("points_earned") or 0),
        })

    return render_template(
        "admin_payroll.html",
        month=month,
        rows=result,
        workdays=WORKDAYS
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

@app.route("/admin/dashboard")
def admin_dashboard():
    admin_guard()

    conn = get_conn()
    cur = conn.cursor()

    # ============= KPI Angka Cepat =============
    # total karyawan
    cur.execute("SELECT COUNT(*) AS total FROM users WHERE role='employee';")
    total_employees = cur.fetchone()["total"]

    # absensi hari ini (jumlah record hari ini)
    cur.execute("""
      SELECT COUNT(*) AS total
      FROM attendance
      WHERE work_date = CURRENT_DATE;
    """)
    attendance_today = cur.fetchone()["total"]

    # sales pending
    cur.execute("""
      SELECT COUNT(*) AS total
      FROM sales_submissions
      WHERE status='PENDING';
    """)
    sales_pending = cur.fetchone()["total"]

    # total produk
    cur.execute("SELECT COUNT(*) AS total FROM products;")
    total_products = cur.fetchone()["total"]

    # ============= Grafik 7 hari terakhir =============
    # label tanggal 7 hari terakhir
    days = []
    for i in range(6, -1, -1):
        d = (date.today() - timedelta(days=i))
        days.append(d)

    # attendance per hari (jumlah hadir / record)
    cur.execute("""
      SELECT work_date, COUNT(*) AS total
      FROM attendance
      WHERE work_date >= CURRENT_DATE - INTERVAL '6 days'
      GROUP BY work_date
      ORDER BY work_date ASC;
    """)
    att_rows = cur.fetchall()
    att_map = {r["work_date"]: int(r["total"] or 0) for r in att_rows}
    att_series = [att_map.get(d, 0) for d in days]

    # sales qty per hari (jumlah qty)
    cur.execute("""
      SELECT DATE(created_at) AS d, COALESCE(SUM(qty),0) AS total_qty
      FROM sales_submissions
      WHERE created_at >= NOW() - INTERVAL '6 days'
      GROUP BY DATE(created_at)
      ORDER BY d ASC;
    """)
    sales_rows = cur.fetchall()
    sales_map = {r["d"]: int(r["total_qty"] or 0) for r in sales_rows}
    sales_series = [sales_map.get(d, 0) for d in days]

    # top karyawan bulan ini (qty)
    cur.execute("""
      SELECT u.name AS employee_name, COALESCE(SUM(s.qty),0) AS total_qty
      FROM users u
      LEFT JOIN sales_submissions s ON s.user_id=u.id
        AND DATE_TRUNC('month', s.created_at) = DATE_TRUNC('month', CURRENT_DATE)
      WHERE u.role='employee'
      GROUP BY u.name
      ORDER BY total_qty DESC
      LIMIT 5;
    """)
    top = cur.fetchall()
    top_labels = [r["employee_name"] for r in top]
    top_values = [int(r["total_qty"] or 0) for r in top]

    cur.close()
    conn.close()

    labels = [d.strftime("%d/%m") for d in days]

    return render_template(
        "admin_dashboard.html",
        total_employees=total_employees,
        attendance_today=attendance_today,
        sales_pending=sales_pending,
        total_products=total_products,
        labels=labels,
        att_series=att_series,
        sales_series=sales_series,
        top_labels=top_labels,
        top_values=top_values,
    )




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
    app.run(host="0.0.0.0", port=5000, debug=True)















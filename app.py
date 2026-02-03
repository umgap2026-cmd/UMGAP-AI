from flask import Flask, render_template, request, redirect, session, abort
from werkzeug.security import generate_password_hash, check_password_hash
from db import get_conn
import random  # taruh di paling atas file app.py (sekali saja)
import random, time
from flask import jsonify


app = Flask(__name__)
app.secret_key = "ganti_ini_jadi_string_acak_untuk_ta"


def is_logged_in():
    return "user_id" in session


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


@app.route("/")
def dashboard():
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()

    # jumlah produk
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
    cur.execute("SELECT id, name, email, password_hash FROM users WHERE email=%s;", (email,))
    user = cur.fetchone()
    cur.close()
    conn.close()

    if not user or not check_password_hash(user["password_hash"], password):
        return render_template("login.html", error="Email atau password salah.")

    session["user_id"] = user["id"]
    session["user_name"] = user["name"]
    return redirect("/")


@app.route("/logout")
def logout():
    session.clear()
    return redirect("/login")


@app.route("/products")
def products():
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "SELECT id, name, price FROM products WHERE user_id=%s ORDER BY id DESC;",
        (session["user_id"],)
    )
    rows = cur.fetchall()
    cur.close()
    conn.close()

    return render_template("products.html", products=rows, error=None)


@app.route("/products/add", methods=["POST"])
def products_add():
    if not is_logged_in():
        return redirect("/login")

    name = request.form.get("name", "").strip()
    price = request.form.get("price", "0").strip()

    if not name:
        return redirect("/products")

    try:
        price_int = int(price)
    except ValueError:
        price_int = 0

    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO products (user_id, name, price) VALUES (%s, %s, %s);",
        (session["user_id"], name, price_int),
    )
    conn.commit()
    cur.close()
    conn.close()

    return redirect("/products")


@app.route("/products/delete/<int:pid>")
def products_delete(pid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("DELETE FROM products WHERE id=%s AND user_id=%s;", (pid, session["user_id"]))
    conn.commit()
    cur.close()
    conn.close()

    return redirect("/products")

@app.route("/products/edit/<int:pid>", methods=["GET", "POST"])
def products_edit(pid):
    if not is_logged_in():
        return redirect("/login")

    if request.method == "GET":
        conn = get_conn()
        cur = conn.cursor()
        cur.execute(
            "SELECT id, name, price FROM products WHERE id=%s AND user_id=%s;",
            (pid, session["user_id"])
        )
        product = cur.fetchone()
        cur.close()
        conn.close()

        if not product:
            abort(404)

        return render_template("product_edit.html", product=product, error=None)

    # POST: update
    name = request.form.get("name", "").strip()
    price = request.form.get("price", "0").strip()

    if not name:
        # ambil produk lagi biar form tetap terisi
        conn = get_conn()
        cur = conn.cursor()
        cur.execute(
            "SELECT id, name, price FROM products WHERE id=%s AND user_id=%s;",
            (pid, session["user_id"])
        )
        product = cur.fetchone()
        cur.close()
        conn.close()
        if not product:
            abort(404)
        return render_template("product_edit.html", product=product, error="Nama produk wajib diisi.")

    try:
        price_int = int(price)
        if price_int < 0:
            price_int = 0
    except ValueError:
        price_int = 0

    conn = get_conn()
    cur = conn.cursor()
    cur.execute(
        "UPDATE products SET name=%s, price=%s WHERE id=%s AND user_id=%s;",
        (name, price_int, pid, session["user_id"])
    )
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

def ensure_schema():
    """
    Idempotent schema migrations for Render Postgres.
    Safe to run on every boot.
    """
    try:
        conn = get_conn()
        cur = conn.cursor()

        # USERS: ensure role exists (older DBs)
        cur.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'employee';")

        # PRODUCTS
        cur.execute("""
        CREATE TABLE IF NOT EXISTS products (
            id SERIAL PRIMARY KEY,
            name TEXT NOT NULL,
            price NUMERIC(12,2) NOT NULL DEFAULT 0,
            user_id INT REFERENCES users(id),
            is_global BOOLEAN DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT NOW()
        );
        """)
        cur.execute("ALTER TABLE products ADD COLUMN IF NOT EXISTS is_global BOOLEAN DEFAULT FALSE;")

        # SALES SUBMISSIONS
        cur.execute("""
        CREATE TABLE IF NOT EXISTS sales_submissions (
            id SERIAL PRIMARY KEY,
            user_id INT REFERENCES users(id),
            product_name TEXT,
            qty INT DEFAULT 1,
            price NUMERIC(12,2) DEFAULT 0,
            total NUMERIC(12,2) DEFAULT 0,
            note TEXT,
            status VARCHAR(20) DEFAULT 'pending',
            admin_note TEXT,
            decided_at TIMESTAMP,
            decided_by INT REFERENCES users(id),
            created_at TIMESTAMP DEFAULT NOW()
        );
        """)
        cur.execute("ALTER TABLE sales_submissions ADD COLUMN IF NOT EXISTS admin_note TEXT;")
        cur.execute("ALTER TABLE sales_submissions ADD COLUMN IF NOT EXISTS decided_at TIMESTAMP;")
        cur.execute("ALTER TABLE sales_submissions ADD COLUMN IF NOT EXISTS decided_by INT REFERENCES users(id);")

        # ATTENDANCE
        cur.execute("""
        CREATE TABLE IF NOT EXISTS attendance (
            id SERIAL PRIMARY KEY,
            user_id INT REFERENCES users(id),
            work_date DATE NOT NULL,
            arrival_type VARCHAR(30) DEFAULT 'manual',
            status VARCHAR(20) DEFAULT 'present',
            note TEXT,
            checkin_at TIMESTAMP,
            checkout_at TIMESTAMP,
            checked_at TIMESTAMP DEFAULT NOW(),
            created_at TIMESTAMP DEFAULT NOW()
        );
        """)
        cur.execute("ALTER TABLE attendance ADD COLUMN IF NOT EXISTS arrival_type VARCHAR(30) DEFAULT 'manual';")
        cur.execute("ALTER TABLE attendance ADD COLUMN IF NOT EXISTS checkin_at TIMESTAMP;")
        cur.execute("ALTER TABLE attendance ADD COLUMN IF NOT EXISTS checkout_at TIMESTAMP;")

        conn.commit()
        cur.close()
        conn.close()
        print("✅ ensure_schema: ok")
    except Exception as e:
        # Don't crash boot; just log
        print(f"⚠️ ensure_schema failed: {e}")



# Run lightweight DB migrations on boot
ensure_schema()

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=True)

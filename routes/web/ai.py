import os
import random
from flask import Blueprint, request, jsonify, session
from core import is_logged_in

ai_bp = Blueprint("ai", __name__)


# ── Helper ────────────────────────────────────────────────────────────────────
def _pick(lst):
    return random.choice(lst)

def _rupiah(s):
    try:
        n = int("".join(filter(str.isdigit, str(s))))
        return f"Rp {n:,}".replace(",", ".")
    except Exception:
        return s or ""


# ── Caption generator — 3 variasi ─────────────────────────────────────────────
def _build_captions(product, price, wa, location, notes, template, style):
    harga   = _rupiah(price) if price else ""
    loc_str = f"\n📍 {location}"   if location else ""
    note_str = f"\nℹ️ {notes}"     if notes    else ""
    wa_str   = f" {wa}"           if wa       else ""

    hooks = {
        "Santai":       ["Eh, ada yang menarik nih 👀", "Lagi cari yang pas buat kamu?", "Psst… ini buat kamu 🤫"],
        "Promo":        ["🔥 JANGAN SKIP!", "⚡ Buruan sebelum kehabisan!", "🚨 Promo terbatas!"],
        "Storytelling": ["Cerita di balik produk ini bikin kamu penasaran…", "Ada yang bilang ini beda dari yang lain.", "Bukan sekadar produk — ini cerita."],
        "Serius":       ["Solusi tepat untuk kebutuhan Anda.", "Kualitas yang bicara sendiri.", "Pilihan profesional untuk hasil terbaik."],
    }
    ctas = {
        "Santai":       ["Hubungi kami ya 👉", "Chat sekarang 👉", "DM/WA aja langsung 👉"],
        "Promo":        ["ORDER SEKARANG 👉", "Klaim promo 👉", "Chat kami sebelum kehabisan 👉"],
        "Storytelling": ["Yuk, cerita lebih lanjut 👉", "Mau tau lebih? Hubungi kami 👉", "Temukan cerita lengkapnya 👉"],
        "Serius":       ["Hubungi kami untuk informasi lebih lanjut 👉", "Konsultasikan kebutuhan Anda 👉", "Dapatkan penawaran terbaik 👉"],
    }
    benefits = [
        "✅ Kualitas terjamin",
        "✅ Cocok untuk semua kebutuhan",
        "✅ Praktis & mudah digunakan",
        "✅ Bisa dijadikan hadiah",
        "✅ Stok terbatas, jangan sampai ketinggalan",
        "✅ Sudah dipercaya banyak pelanggan",
    ]

    hook_pool = hooks.get(style, hooks["Santai"])
    cta_pool  = ctas.get(style, ctas["Santai"])

    results = []

    for i in range(3):
        hook    = hook_pool[i % len(hook_pool)]
        cta     = cta_pool[i % len(cta_pool)]
        benefit = benefits[i % len(benefits)]
        hashtags = _hashtags(product, style, i)

        if template == "promo":
            body = (
                f"{hook}\n\n"
                f"🎯 *{product}*\n"
                + (f"💰 Harga: {harga}\n" if harga else "")
                + f"{benefit}{loc_str}{note_str}\n\n"
                f"{cta}{wa_str}\n\n"
                f"{hashtags}"
            )

        elif template == "new":
            body = (
                f"✨ Produk Baru Hadir!\n\n"
                f"🆕 *{product}*\n"
                + (f"💰 {harga}\n" if harga else "")
                + f"{benefit}{loc_str}{note_str}\n\n"
                f"{cta}{wa_str}\n\n"
                f"{hashtags}"
            )

        elif template == "testi":
            testis = [
                "\"Pelayanannya cepat dan responsif, recommended!\"",
                "\"Hasilnya melebihi ekspektasi, worth it banget!\"",
                "\"Sudah order berkali-kali, selalu puas!\""
            ]
            body = (
                f"{hook}\n\n"
                f"⭐ Testimoni pelanggan:\n"
                f"{testis[i % 3]}\n\n"
                f"🛍️ *{product}*\n"
                + (f"💰 Mulai {harga}\n" if harga else "")
                + f"{benefit}{loc_str}{note_str}\n\n"
                f"{cta}{wa_str}\n\n"
                f"{hashtags}"
            )

        else:  # reminder
            body = (
                f"⏰ Jangan lupa!\n\n"
                f"📌 *{product}*\n"
                + (f"💰 Mulai {harga}\n" if harga else "")
                + f"{benefit}\n🔔 Slot/stok terbatas!{loc_str}{note_str}\n\n"
                f"{cta}{wa_str}\n\n"
                f"{hashtags}"
            )

        results.append(body.strip())

    separator = "\n\n" + ("─" * 30) + "\n\n"
    return separator.join([f"[ Versi {i+1} ]\n{r}" for i, r in enumerate(results)])


def _hashtags(product, style, variant):
    base = ["#jualan", "#produk", "#jualanOnline", "#bisnisOnline"]
    style_tags = {
        "Promo":        ["#promoHariIni", "#diskon", "#buruan"],
        "Santai":       ["#rekomen", "#yukOrder", "#cobaDulu"],
        "Storytelling": ["#ceritaProduk", "#behind", "#kisahNyata"],
        "Serius":       ["#profesional", "#terpercaya", "#kualitas"],
    }
    extras = style_tags.get(style, [])
    pool   = base + extras
    chosen = random.sample(pool, min(4, len(pool)))
    return " ".join(chosen)


# ── ROUTE UTAMA ───────────────────────────────────────────────────────────────
@ai_bp.route("/api/caption-ai", methods=["POST"])
def api_caption_ai():
    """
    Dipanggil oleh caption.html via fetch FormData.
    Mengembalikan 3 variasi caption siap pakai.
    """
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Silakan login terlebih dahulu."}), 401

    # ── Baca FormData (bukan JSON) ────────────────────────────────────────────
    product  = (request.form.get("product")  or "").strip()
    price    = (request.form.get("price")    or "").strip()
    wa       = (request.form.get("wa")       or "").strip()
    location = (request.form.get("location") or "").strip()
    notes    = (request.form.get("notes")    or "").strip()
    template = (request.form.get("template") or "promo").strip()
    style    = (request.form.get("style")    or "Santai").strip()

    if not product:
        return jsonify({"ok": False, "error": "Nama produk wajib diisi."}), 400

    try:
        caption = _build_captions(product, price, wa, location, notes, template, style)
        return jsonify({"ok": True, "caption": caption})
    except Exception as e:
        return jsonify({"ok": False, "error": f"Gagal generate: {str(e)}"}), 500


# ── Route lama — tetap ada agar tidak breaking ────────────────────────────────
@ai_bp.route("/api/caption", methods=["POST"])
def api_caption():
    if not is_logged_in():
        return jsonify({"ok": False}), 401
    data    = request.get_json() or {}
    product = data.get("product", "Produk")
    return jsonify({"ok": True, "caption": f"Promo {product}"})


@ai_bp.route("/api/chat", methods=["POST"])
def api_chat():
    data = request.get_json(silent=True) or {}
    msg  = (data.get("message") or "").strip()
    if not msg:
        return jsonify({"ok": False}), 400
    return jsonify({"ok": True, "reply": f"(Mock AI) {msg}"})

from flask import Blueprint, render_template, request, redirect
from core import is_logged_in, rupiah, pick

caption_bp = Blueprint("caption", __name__)


@caption_bp.route("/caption", methods=["GET", "POST"])
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

        benefit = pick([
            "Kualitas terjaga",
            "Cocok untuk kebutuhan harian",
            "Praktis dan mudah digunakan",
            "Bisa untuk hadiah"
        ])

        hook = pick([
            "Lagi cari yang pas buat kamu?",
            "Biar makin gampang, cek ini dulu 👇",
            "Yang ini lagi banyak dicari loh!"
        ])

        cta = pick([
            "Chat aja ya 👉",
            "Langsung DM/WA ya 👉",
            "Pesan sekarang 👉"
        ])

        if form["template"] == "promo":
            caption_text = f"{hook}\n🎯 {nama}\n💰 Mulai {harga}\n✅ {benefit}\n📌 Harga spesial{loc}{extra}\n\n{cta} {form['wa']}"

        elif form["template"] == "new":
            caption_text = f"{hook}\n✨ Rilis: {nama}\n💰 Harga: {harga}\n✅ {benefit}{loc}{extra}\n\n{cta} {form['wa']}"

        elif form["template"] == "testi":
            testi = pick([
                "\"Pelayanannya cepat dan responsif.\"",
                "\"Hasilnya sesuai ekspektasi, recommended!\"",
                "\"Worth it!\""
            ])
            caption_text = f"{hook}\n⭐ Testimoni: {testi}\n💰 Mulai {harga}\n✅ {benefit}{loc}{extra}\n\n{cta} {form['wa']}"

        else:
            caption_text = f"{hook}\n⏰ Reminder: {nama}\n💰 Mulai {harga}\n✅ {benefit}\n📌 Slot terbatas{loc}{extra}\n\n{cta} {form['wa']}"

    return render_template("caption.html", caption=caption_text, form=form)
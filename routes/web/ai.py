import os
import requests
from flask import Blueprint, request, jsonify
from core import is_logged_in, rupiah

ai_bp = Blueprint("ai", __name__)

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")


# ── OpenAI helper ─────────────────────────────────────────────────────────────
def _ask_openai(prompt: str, max_tokens: int = 900) -> str:
    if not OPENAI_API_KEY:
        raise RuntimeError("OPENAI_API_KEY belum diisi di environment.")

    resp = requests.post(
        "https://api.openai.com/v1/chat/completions",
        headers={
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "Content-Type":  "application/json",
        },
        json={
            "model":      "gpt-4o-mini",   # cepat & murah, ganti ke gpt-4o jika mau lebih bagus
            "max_tokens": max_tokens,
            "temperature": 0.85,
            "messages": [
                {
                    "role": "system",
                    "content": (
                        "Kamu adalah copywriter profesional Indonesia yang ahli membuat "
                        "caption media sosial yang engaging, natural, dan mengkonversi. "
                        "Selalu tulis dalam Bahasa Indonesia yang alami, hindari terasa seperti template."
                    ),
                },
                {"role": "user", "content": prompt},
            ],
        },
        timeout=30,
    )

    if resp.status_code != 200:
        raise RuntimeError(f"OpenAI error {resp.status_code}: {resp.text[:200]}")

    data = resp.json()
    return data["choices"][0]["message"]["content"].strip()


# ── Prompt builder ────────────────────────────────────────────────────────────
def _build_prompt(product, price, brand, platform, style, notes):
    harga_str = rupiah(price) if price else ""

    detail_lines = [f"- Nama produk: {product}"]
    if brand:    detail_lines.append(f"- Brand / toko: {brand}")
    if harga_str: detail_lines.append(f"- Harga: {harga_str}")
    if notes:    detail_lines.append(f"- Catatan pendukung: {notes}")

    detail = "\n".join(detail_lines)

    platform_guide = {
        "Instagram": (
            "Instagram — gunakan emoji secukupnya, tambahkan 4–6 hashtag relevan di akhir, "
            "CTA mengarah ke DM atau bio link."
        ),
        "TikTok": (
            "TikTok — hook kuat di baris pertama, singkat dan energetik, "
            "tambahkan #fyp dan hashtag viral, CTA mengarah ke link bio atau kolom komentar."
        ),
        "WhatsApp": (
            "WhatsApp (broadcast/status) — tone personal, tidak pakai hashtag, "
            "CTA langsung chat WA atau telepon."
        ),
    }

    style_guide = {
        "Santai":       "Gaya santai, friendly, seperti ngobrol sama teman.",
        "Promo":        "Gaya promo agresif, urgent, penuh semangat, dorong pembaca beli sekarang.",
        "Storytelling": "Gaya storytelling, bangun emosi dulu baru tawarkan produk secara halus.",
        "Serius":       "Gaya profesional dan terpercaya, tone formal namun tetap hangat.",
    }

    platform_desc = platform_guide.get(platform, platform_guide["Instagram"])
    style_desc    = style_guide.get(style, style_guide["Santai"])

    prompt = f"""Buatkan 3 variasi caption untuk postingan {platform} berdasarkan detail berikut:

{detail}

Platform: {platform_desc}
Gaya penulisan: {style_desc}

Ketentuan:
- Pisahkan setiap variasi dengan baris: ─────────────────────────────────
- Awali setiap variasi dengan label: [ Versi 1 ], [ Versi 2 ], [ Versi 3 ]
- Setiap variasi HARUS berbeda pendekatan (bukan hanya ganti kata)
- Jangan tambahkan penjelasan, langsung tulis 3 caption saja
- Bahasa Indonesia yang natural, tidak kaku
"""
    return prompt


# ── ROUTE UTAMA ───────────────────────────────────────────────────────────────
@ai_bp.route("/api/caption-ai", methods=["POST"])
def api_caption_ai():
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Silakan login terlebih dahulu."}), 401

    # Baca FormData — sesuai field di caption.html
    product  = (request.form.get("product")  or "").strip()
    price    = (request.form.get("price")    or "").strip()
    brand    = (request.form.get("brand")    or "").strip()
    platform = (request.form.get("platform") or "Instagram").strip()
    style    = (request.form.get("style")    or "Santai").strip()
    notes    = (request.form.get("notes")    or "").strip()

    if not product:
        return jsonify({"ok": False, "error": "Nama produk wajib diisi."}), 400

    if not OPENAI_API_KEY:
        return jsonify({
            "ok":    False,
            "error": "OpenAI API key belum dikonfigurasi di server.",
        }), 500

    try:
        prompt  = _build_prompt(product, price, brand, platform, style, notes)
        caption = _ask_openai(prompt)
        return jsonify({"ok": True, "caption": caption})

    except requests.exceptions.Timeout:
        return jsonify({"ok": False, "error": "OpenAI timeout, coba lagi."}), 504

    except Exception as e:
        return jsonify({"ok": False, "error": f"Gagal generate: {str(e)}"}), 500


# ── Route lama (tidak dihapus agar tidak breaking) ────────────────────────────
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

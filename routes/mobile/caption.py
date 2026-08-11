from flask import Blueprint, request

from core import mobile_api_response, mobile_api_login_required

mobile_caption_bp = Blueprint("mobile_caption", __name__)


@mobile_caption_bp.route("/caption-ai", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_caption_ai():
    """
    Generate caption produk pakai AI (OpenAI) -- versi mobile dari
    /api/caption-ai (routes/web/ai.py), pakai prompt-builder & OpenAI
    caller yang SAMA (tidak duplikasi logic).
    Body JSON: {product, price, brand, platform, style, notes}
    Returns: {ok, caption}
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    if request.mobile_user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)

    data     = request.get_json(silent=True) or {}
    product  = (data.get("product")  or "").strip()
    price    = (data.get("price")    or "").strip()
    brand    = (data.get("brand")    or "").strip()
    platform = (data.get("platform") or "Instagram").strip()
    style    = (data.get("style")    or "Santai").strip()
    notes    = (data.get("notes")    or "").strip()

    if not product:
        return mobile_api_response(ok=False, message="Nama produk wajib diisi.", status_code=400)

    from routes.web.ai import _build_prompt, _ask_openai, OPENAI_API_KEY
    import requests as _requests

    if not OPENAI_API_KEY:
        return mobile_api_response(ok=False, message="OpenAI API key belum dikonfigurasi di server.", status_code=500)

    try:
        prompt  = _build_prompt(product, price, brand, platform, style, notes)
        caption = _ask_openai(prompt)
        return mobile_api_response(ok=True, message="OK", data={"caption": caption})
    except _requests.exceptions.Timeout:
        return mobile_api_response(ok=False, message="OpenAI timeout, coba lagi.", status_code=504)
    except Exception as e:
        return mobile_api_response(ok=False, message=f"Gagal generate: {e}", status_code=500)

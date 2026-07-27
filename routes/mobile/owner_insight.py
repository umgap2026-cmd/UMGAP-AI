from flask import Blueprint, request

from core import (
    mobile_api_login_required, mobile_api_response,
    get_owner_health_insight, get_owner_ai_review,
)

mobile_owner_bp = Blueprint("mobile_owner", __name__)


def _access_owner_admin():
    user = getattr(request, "mobile_user", None) or {}
    role = (user.get("role") or "").strip().lower()
    if role not in ("owner", "admin"):
        return mobile_api_response(
            ok=False,
            message="Akses ditolak. Hanya owner / admin.",
            status_code=403,
        )
    return None


@mobile_owner_bp.route("/owner/insight", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def owner_insight():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _access_owner_admin()
    if deny:
        return deny

    try:
        insight = get_owner_health_insight()
        return mobile_api_response(
            ok=True,
            message="Owner insight berhasil dimuat",
            data=insight,
        )
    except Exception as e:
        return mobile_api_response(
            ok=False,
            message=f"Gagal memuat owner insight: {str(e)}",
            status_code=500,
        )


@mobile_owner_bp.route("/owner/ai-review", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def owner_ai_review():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    user = getattr(request, "mobile_user", None) or {}
    role = (user.get("role") or "").strip().lower()

    if role != "owner":
        return mobile_api_response(
            ok=False,
            message="Akses ditolak. Hanya owner.",
            status_code=403,
        )

    try:
        # Dihitung ulang server-side (bukan dari body yg dikirim client) --
        # supaya selalu data terkini & tidak bisa dimanipulasi dari client.
        insight = get_owner_health_insight()
        analysis = get_owner_ai_review(insight)
        return mobile_api_response(
            ok=True,
            message="AI review berhasil dibuat",
            data={"analysis": analysis},
        )
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    except Exception as e:
        return mobile_api_response(
            ok=False,
            message=f"Gagal AI review: {str(e)}",
            status_code=500,
        )

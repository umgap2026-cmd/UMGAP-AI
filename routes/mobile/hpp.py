from flask import Blueprint, request, jsonify
from .middleware import mobile_required

mobile_hpp_bp = Blueprint("mobile_hpp", __name__)


@mobile_hpp_bp.route("/api/mobile/hpp-ai", methods=["POST"])
@mobile_required
def hpp_ai_mobile():
    data = request.json

    # sementara dummy (biar tidak error)
    return jsonify({
        "result": "AI berhasil jalan (dummy)"
    })
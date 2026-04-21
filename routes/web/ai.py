import os
from flask import Blueprint, request, jsonify, session

from core import is_logged_in

ai_bp = Blueprint("ai", __name__)


@ai_bp.route("/api/chat", methods=["POST"])
def api_chat():
    data = request.get_json(silent=True) or {}
    msg = (data.get("message") or "").strip()

    if not msg:
        return jsonify({"ok": False}), 400

    return jsonify({
        "ok": True,
        "reply": f"(Mock AI) {msg}"
    })


@ai_bp.route("/api/caption-ai", methods=["POST"])
def api_caption():
    if not is_logged_in():
        return jsonify({"ok": False}), 401

    data = request.get_json() or {}

    return jsonify({
        "ok": True,
        "caption": f"Promo {data.get('product')}"
    })

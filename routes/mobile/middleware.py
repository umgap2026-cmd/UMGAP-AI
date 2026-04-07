import os
import jwt
from functools import wraps
from flask import request, jsonify

SECRET = os.getenv("SECRET_KEY", "secret123")


def mobile_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "").strip()

        if not auth.startswith("Bearer "):
            return jsonify({"ok": False, "message": "Unauthorized"}), 401

        token = auth.split(" ", 1)[1].strip()

        try:
            payload = jwt.decode(token, SECRET, algorithms=["HS256"])
            request.user = payload
        except Exception:
            return jsonify({"ok": False, "message": "Token invalid"}), 401

        return f(*args, **kwargs)

    return wrapper
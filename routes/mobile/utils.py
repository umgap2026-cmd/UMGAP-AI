import jwt
from functools import wraps
from flask import request, jsonify
import os

SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-change-me")

def success(data=None, message="OK"):
    return jsonify({
        "ok": True,
        "message": message,
        "data": data or {}
    })

def error(message="Error", code=400):
    return jsonify({
        "ok": False,
        "message": message
    }), code


def jwt_required(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            return error("Unauthorized", 401)

        token = auth.split(" ")[1]

        try:
            payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
            request.user = payload
        except Exception as e:
            return error("Token invalid", 401)

        return fn(*args, **kwargs)
    return wrapper
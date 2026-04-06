import jwt
import os
from functools import wraps
from flask import request, jsonify

SECRET = os.getenv("SECRET_KEY", "secret123")

def mobile_required(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth = request.headers.get("Authorization", "")

        if not auth.startswith("Bearer "):
            return jsonify({"message": "Unauthorized"}), 401

        token = auth.split(" ")[1]

        try:
            data = jwt.decode(token, SECRET, algorithms=["HS256"])
            request.user = data
        except Exception:
            return jsonify({"message": "Token invalid"}), 401

        return f(*args, **kwargs)

    return wrapper
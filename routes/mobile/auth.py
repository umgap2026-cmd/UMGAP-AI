import uuid
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from werkzeug.security import check_password_hash

from db import get_conn
from core import (
    mobile_api_response,
    ensure_mobile_api_schema,
    mobile_api_login_required,
)

mobile_auth_bp = Blueprint("mobile_auth", __name__)


@mobile_auth_bp.route("/login", methods=["POST"])
def api_mobile_login():
    ensure_mobile_api_schema()

    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    password = (data.get("password") or "").strip()
    device_name = (data.get("device_name") or "Android").strip()

    if not email or not password:
        return mobile_api_response(False, "Email dan password wajib diisi.", status_code=400)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, name, email, password_hash, role
            FROM users
            WHERE LOWER(email)=LOWER(%s)
            LIMIT 1;
        """, (email,))
        user = cur.fetchone()

        if not user or not check_password_hash(user["password_hash"], password):
            return mobile_api_response(False, "Email atau password salah.", status_code=401)

        token = uuid.uuid4().hex + uuid.uuid4().hex

        cur.execute("""
            INSERT INTO mobile_api_tokens (user_id, token, device_name, is_active)
            VALUES (%s, %s, %s, TRUE);
        """, (user["id"], token, device_name))
        conn.commit()

        return mobile_api_response(
            True,
            "Login berhasil.",
            data={
                "token": token,
                "user": {
                    "id": user["id"],
                    "name": user["name"],
                    "email": user["email"],
                    "role": user["role"],
                }
            }
        )
    finally:
        cur.close()
        conn.close()@app.route("/api/mobile/login", methods=["POST"])
def api_mobile_login():
    ensure_mobile_api_schema()

    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    password = (data.get("password") or "").strip()
    device_name = (data.get("device_name") or "").strip()

    if not email or not password:
        return mobile_api_response(
            ok=False,
            message="Email dan password wajib diisi.",
            status_code=400
        )

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, name, email, password_hash, role
            FROM users
            WHERE LOWER(email)=LOWER(%s)
            LIMIT 1;
        """, (email,))
        user = cur.fetchone()

        if not user or not check_password_hash(user["password_hash"], password):
            return mobile_api_response(
                ok=False,
                message="Email atau password salah.",
                status_code=401
            )

        token = uuid.uuid4().hex + uuid.uuid4().hex

        cur.execute("""
            INSERT INTO mobile_api_tokens (user_id, token, device_name, is_active)
            VALUES (%s, %s, %s, TRUE)
            RETURNING id;
        """, (
            user["id"],
            token,
            device_name or "Android Device"
        ))
        cur.fetchone()
        conn.commit()

        return mobile_api_response(
            ok=True,
            message="Login berhasil.",
            data={
                "token": token,
                "user": {
                    "id": user["id"],
                    "name": user["name"],
                    "email": user["email"],
                    "role": user["role"],
                }
            }
        )
    finally:
        cur.close()
        conn.close()


@mobile_auth_bp.route("/me", methods=["GET"])
@mobile_api_login_required
def api_mobile_me():
    user = request.mobile_user

    return mobile_api_response(
        True,
        "Profil berhasil diambil.",
        data={
            "user": {
                "id": user["id"],
                "name": user["name"],
                "email": user["email"],
                "role": user["role"],
                "points": user.get("points", 0),
                "points_admin": user.get("points_admin", 0),
            }
        }
    )


@mobile_auth_bp.route("/logout", methods=["POST"])
@mobile_api_login_required
def api_mobile_logout():
    token = request.headers.get("Authorization", "").replace("Bearer ", "").strip()

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE mobile_api_tokens
            SET is_active=FALSE
            WHERE token=%s;
        """, (token,))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return mobile_api_response(True, "Logout berhasil.")

import secrets

from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from werkzeug.security import check_password_hash

from db import get_conn
from core import mobile_api_response

mobile_auth_bp = Blueprint("mobile_auth", __name__)


def ensure_mobile_api_schema():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS mobile_api_tokens (
                id SERIAL PRIMARY KEY,
                user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                token TEXT NOT NULL UNIQUE,
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                last_used_at TIMESTAMP
            );
        """)
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_mobile_api_tokens_user_id
            ON mobile_api_tokens(user_id);
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()


@mobile_auth_bp.route("/login", methods=["POST", "OPTIONS"])
def mobile_login():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    ensure_mobile_api_schema()

    data = request.get_json(silent=True) or {}
    email = (data.get("email") or "").strip().lower()
    password = data.get("password") or ""

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
            WHERE lower(email)=%s
            LIMIT 1;
        """, (email,))
        user = cur.fetchone()

        if not user or not check_password_hash(user["password_hash"], password):
            return mobile_api_response(
                ok=False,
                message="Email atau password salah.",
                status_code=401
            )

        cur.execute("""
            UPDATE mobile_api_tokens
            SET is_active=FALSE
            WHERE user_id=%s;
        """, (user["id"],))

        token = secrets.token_urlsafe(48)

        cur.execute("""
            INSERT INTO mobile_api_tokens (user_id, token, is_active, last_used_at)
            VALUES (%s, %s, TRUE, CURRENT_TIMESTAMP);
        """, (user["id"], token))

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
            },
            status_code=200
        )
    except Exception as e:
        conn.rollback()
        return mobile_api_response(
            ok=False,
            message=f"Gagal login: {str(e)}",
            status_code=500
        )
    finally:
        cur.close()
        conn.close()


@mobile_auth_bp.route("/me", methods=["GET", "OPTIONS"])
def mobile_me():
    from core import get_mobile_api_user

    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = get_mobile_api_user()
    if not user:
        return mobile_api_response(
            ok=False,
            message="Unauthorized. Token tidak valid atau belum login.",
            status_code=401
        )

    return mobile_api_response(
        ok=True,
        message="OK",
        data={
            "user": {
                "id": user["user_id"],
                "name": user["name"],
                "email": user["email"],
                "role": user["role"],
                "points": int(user.get("points") or 0),
                "points_admin": int(user.get("points_admin") or 0),
            }
        },
        status_code=200
    )


@mobile_auth_bp.route("/logout", methods=["POST", "OPTIONS"])
def mobile_logout():
    from core import get_bearer_token

    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    token = get_bearer_token()
    if not token:
        return mobile_api_response(ok=True, message="Logout berhasil.", data={}, status_code=200)

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

    return mobile_api_response(ok=True, message="Logout berhasil.", data={}, status_code=200)
from flask import Blueprint, request
from db import get_conn
from core import (
    mobile_api_login_required,
    mobile_api_response,
    ensure_mobile_device_tokens_schema,
)

mobile_device_bp = Blueprint("mobile_device", __name__)

@mobile_device_bp.route("/device/register", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_device_register():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    ensure_mobile_device_tokens_schema()

    user = request.mobile_user
    payload = request.get_json(silent=True) or {}

    fcm_token = (payload.get("fcm_token") or "").strip()
    platform = (payload.get("platform") or "android").strip().lower()

    if not fcm_token:
        return mobile_api_response(
            ok=False,
            message="fcm_token wajib diisi.",
            status_code=400
        )

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO mobile_device_tokens (user_id, fcm_token, platform, is_active, updated_at)
            VALUES (%s, %s, %s, TRUE, CURRENT_TIMESTAMP)
            ON CONFLICT (fcm_token)
            DO UPDATE SET
                user_id = EXCLUDED.user_id,
                platform = EXCLUDED.platform,
                is_active = TRUE,
                updated_at = CURRENT_TIMESTAMP;
        """, (user["user_id"], fcm_token, platform))
        conn.commit()

        return mobile_api_response(
            ok=True,
            message="Token device berhasil didaftarkan.",
            data={},
            status_code=200
        )
    finally:
        cur.close()
        conn.close()
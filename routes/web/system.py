from flask import Blueprint, render_template, redirect, session
from db import get_conn
from core import is_logged_in, ensure_hr_v2_schema

system_bp = Blueprint("system", __name__)

@system_bp.route("/")
def landing():
    if is_logged_in():
        return redirect("/admin/dashboard" if session.get("role") == "admin" else "/dashboard")
    return render_template("landing.html")

@system_bp.route("/db-check")
def db_check():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("SELECT 1 AS ok;")
        row = cur.fetchone()
        return {"ok": row[0] if row else 0}
    finally:
        cur.close()
        conn.close()

@system_bp.route("/init-db")
def init_db():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                email VARCHAR(120) UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                role VARCHAR(20) DEFAULT 'employee',
                points INTEGER NOT NULL DEFAULT 0,
                points_admin INTEGER NOT NULL DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()
    return "OK: tabel users siap."

@system_bp.route("/init-products")
def init_products():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS products (
                id SERIAL PRIMARY KEY,
                user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
                name VARCHAR(120) NOT NULL,
                price INTEGER DEFAULT 0,
                stock INTEGER DEFAULT 0,
                is_global BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()
    return "OK: tabel products siap."

@system_bp.route("/init-hr-v2")
def init_hr_v2():
    ensure_hr_v2_schema()
    return "OK: HR v2 tables/columns ensured."

@system_bp.route("/check-fcm-env")
def check_fcm_env():
    import os
    return {
        "project_id": bool(os.getenv("FIREBASE_PROJECT_ID")),
        "sa_json": bool(os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")),
        "sa_path": bool(os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON_PATH")),
    }
@system_bp.route("/test-fcm")
def test_fcm():
    try:
        from core import get_admin_fcm_tokens, send_fcm_to_tokens
        tokens = get_admin_fcm_tokens()
        if not tokens:
            return {"ok": False, "message": "Tidak ada FCM token admin", "tokens": 0}
        result = send_fcm_to_tokens(
            tokens=tokens,
            title="Test FCM UMGAP",
            body="Notifikasi test dari server berhasil!",
        )
        return {"ok": True, "result": result, "token_count": len(tokens)}
    except Exception as e:
        return {"ok": False, "error": str(e)}
    
@system_bp.route("/clean-fcm-tokens")
def clean_fcm_tokens():
    from db import get_conn
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM mobile_device_tokens;")
        conn.commit()
        return {"ok": True, "message": "Semua token dihapus"}
    finally:
        cur.close()
        conn.close()

@system_bp.route("/test-fcm-detail")
def test_fcm_detail():
    try:
        from core import _get_firebase_access_token, get_admin_fcm_tokens
        import os, requests as req

        token = _get_firebase_access_token()
        project_id = os.getenv("FIREBASE_PROJECT_ID")
        fcm_tokens = get_admin_fcm_tokens()

        if not fcm_tokens:
            return {"ok": False, "message": "Tidak ada token"}

        url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
        payload = {
            "message": {
                "token": fcm_tokens[0],
                "notification": {"title": "Test", "body": "Test FCM"},
                "android": {"priority": "high"}
            }
        }
        resp = req.post(url,
            headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
            json=payload, timeout=15)

        return {
            "ok": resp.status_code == 200,
            "status": resp.status_code,
            "response": resp.json(),
            "project_id": project_id,
        }
    except Exception as e:
        return {"ok": False, "error": str(e)}

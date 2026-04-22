import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

from flask import Flask, request, jsonify
from werkzeug.middleware.proxy_fix import ProxyFix

from core import init_oauth

# ------ WEB -----
from routes.web.system import system_bp
from routes.web.auth import auth_bp
from routes.web.dashboard import dashboard_bp
from routes.web.attendance import attendance_bp
from routes.web.admin import admin_bp
from routes.web.products import products_bp
from routes.web.sales import sales_bp
from routes.web.invoice import invoice_bp
from routes.web.preview import preview_bp
from routes.web.thermal import thermal_bp
from routes.web.stats import stats_bp
from routes.web.announcements import announcements_bp
from routes.web.payroll import payroll_bp
from routes.web.points import points_bp
from routes.web.content import content_bp
from routes.web.caption import caption_bp
from routes.web.hpp import hpp_bp
from routes.web.ai import ai_bp
from routes.web.buy_prices import buy_prices_bp
from routes.web.export import export_bp


# ------ MOBILE -----
from routes.mobile.auth import mobile_auth_bp
from routes.mobile.attendance import mobile_attendance_bp
from routes.mobile.hpp import mobile_hpp_bp
from routes.mobile.dashboard import mobile_dashboard_bp
from routes.mobile.notifications import mobile_notifications_bp
from routes.mobile.products import mobile_products_bp
from routes.mobile.sales import mobile_sales_bp
from routes.mobile.admin_users import mobile_admin_users_bp
from routes.mobile.invoice import mobile_invoice_bp
from routes.mobile.payroll import mobile_payroll_bp
from routes.mobile.stats import mobile_stats_bp
from routes.mobile.points import mobile_points_bp
from routes.mobile.device import mobile_device_bp
from routes.mobile.announcements import mobile_announcements_bp  # ← BARU
from routes.mobile.biofinger import biofinger_bp  # ← BARU
from routes.web.data_cleanup import data_cleanup_bp  # ← BARU
from routes.mobile.stats_export import mobile_stats_export_bp
from routes.mobile.buy_prices import mobile_buy_prices_bp
from routes.mobile.profile import mobile_profile_bp


app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "dev-secret-change-me")

IS_PROD = os.getenv("RENDER") == "true" or os.getenv("FLASK_ENV") == "production"

app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
app.config["SESSION_COOKIE_SECURE"] = True if IS_PROD else False
app.config["SESSION_COOKIE_HTTPONLY"] = True
app.config["PREFERRED_URL_SCHEME"] = "https" if IS_PROD else "http"

app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_port=1)

init_oauth(app)


@app.after_request
def add_mobile_api_headers(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    return response


# ------ REGISTER WEB -----
app.register_blueprint(system_bp)
app.register_blueprint(auth_bp)
app.register_blueprint(dashboard_bp)
app.register_blueprint(attendance_bp)
app.register_blueprint(admin_bp)
app.register_blueprint(products_bp)
app.register_blueprint(sales_bp)
app.register_blueprint(invoice_bp)
app.register_blueprint(preview_bp)
app.register_blueprint(thermal_bp)
app.register_blueprint(stats_bp)
app.register_blueprint(announcements_bp)
app.register_blueprint(payroll_bp)
app.register_blueprint(points_bp)
app.register_blueprint(content_bp)
app.register_blueprint(caption_bp)
app.register_blueprint(hpp_bp)
app.register_blueprint(ai_bp)
app.register_blueprint(export_bp)
app.register_blueprint(buy_prices_bp)

# ------ REGISTER MOBILE -----
app.register_blueprint(mobile_auth_bp,          url_prefix="/api/mobile")
app.register_blueprint(mobile_attendance_bp,    url_prefix="/api/mobile")
app.register_blueprint(mobile_hpp_bp,           url_prefix="/api/mobile")
app.register_blueprint(mobile_dashboard_bp,     url_prefix="/api/mobile")
app.register_blueprint(mobile_notifications_bp, url_prefix="/api/mobile")
app.register_blueprint(mobile_products_bp,      url_prefix="/api/mobile")
app.register_blueprint(mobile_sales_bp,         url_prefix="/api/mobile")
app.register_blueprint(mobile_admin_users_bp,   url_prefix="/api/mobile")
app.register_blueprint(mobile_invoice_bp,       url_prefix="/api/mobile")
app.register_blueprint(mobile_payroll_bp,       url_prefix="/api/mobile")
app.register_blueprint(mobile_stats_bp,         url_prefix="/api/mobile")
app.register_blueprint(mobile_points_bp,        url_prefix="/api/mobile")
app.register_blueprint(mobile_device_bp,        url_prefix="/api/mobile")
app.register_blueprint(mobile_announcements_bp, url_prefix="/api/mobile")  # ← BARU
app.register_blueprint(biofinger_bp, url_prefix="/api/mobile")  # ← BARU
app.register_blueprint(data_cleanup_bp)  # ← BARU
app.register_blueprint(mobile_stats_export_bp, url_prefix="/api/mobile")
app.register_blueprint(mobile_buy_prices_bp, url_prefix="/api/mobile")
app.register_blueprint(mobile_profile_bp, url_prefix="/api/mobile")

@app.route("/api/mobile/send-reminder", methods=["POST"])
def send_daily_reminder():
    key = request.headers.get("X-Internal-Key", "")
    if key != os.getenv("INTERNAL_KEY", "umgap-secret-2026"):
        from flask import jsonify
        return jsonify({"ok": False, "message": "Unauthorized"}), 403

    try:
        from core import send_fcm_to_tokens
        from db import get_conn
        from psycopg2.extras import RealDictCursor
        from flask import jsonify

        conn = get_conn()
        cur  = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("""
            SELECT DISTINCT fcm_token FROM mobile_device_tokens
            WHERE is_active = TRUE AND COALESCE(fcm_token, '') <> '';
        """)
        tokens = [r["fcm_token"] for r in cur.fetchall()]
        cur.close(); conn.close()

        if tokens:
            send_fcm_to_tokens(
                tokens,
                title="⏰ Waktunya Absen!",
                body="Jangan lupa check-in hari ini. Buka UMGAP sekarang.",
                data={"type": "reminder", "screen": "attendance"}
            )
            print(f"[REMINDER] Dikirim ke {len(tokens)} device")

        return jsonify({"ok": True, "sent": len(tokens)})
    except Exception as e:
        from flask import jsonify
        return jsonify({"ok": False, "message": str(e)}), 500

@app.route("/api/mobile/version")
def app_version():
    return jsonify({
        "latest_version": "1.1.0",      # update ini tiap rilis baru
        "min_version": "1.1.0",         # versi minimum yang boleh jalan
        "force_update": True,           # True = wajib update, False = opsional
        "update_url": "https://drive.google.com/file/d/1-wwfCybCskSeujVfs9AwWRuxzsnSjOeA/view?usp=drive_link",
        "message": "Versi baru tersedia! Silakan update aplikasi."
    })

@app.route("/panduan")
def panduan():
    return app.send_static_file("panduan_umgap.html")

if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=not IS_PROD)

import hmac
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from dotenv import load_dotenv
load_dotenv()

from flask import Flask, request, jsonify, session
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
from routes.web.nota import nota_bp
from routes.web.preview import preview_bp
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
from routes.web.finance import finance_bp


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
from routes.web.data_cleanup import data_cleanup_bp  # ← BARU
from routes.mobile.stats_export import mobile_stats_export_bp
from routes.mobile.buy_prices import mobile_buy_prices_bp
from routes.mobile.profile import mobile_profile_bp
from routes.mobile.finance import mobile_finance_bp  # ← FINANCE
from routes.mobile.owner_insight import mobile_owner_bp
from routes.mobile.owner_stats import mobile_owner_stats_bp

app = Flask(__name__)

SECRET_KEY = os.getenv("SECRET_KEY", "").strip()
if not SECRET_KEY:
    raise RuntimeError(
        "SECRET_KEY belum diatur di .env. Isi dengan nilai acak yang kuat, "
        'misalnya: python -c "import secrets; print(secrets.token_urlsafe(32))"'
    )
app.secret_key = SECRET_KEY

INTERNAL_KEY = os.getenv("INTERNAL_KEY", "").strip()

def _internal_key_ok():
    """Bandingkan X-Internal-Key dengan INTERNAL_KEY secara timing-safe.
    Endpoint internal otomatis nonaktif kalau INTERNAL_KEY belum diisi."""
    if not INTERNAL_KEY:
        return False
    supplied = request.headers.get("X-Internal-Key", "")
    return hmac.compare_digest(supplied, INTERNAL_KEY)

from flask_compress import Compress
Compress(app)

IS_PROD = os.getenv("RENDER") == "true" or os.getenv("FLASK_ENV") == "production"

app.config["SESSION_COOKIE_SAMESITE"] = "Lax"
app.config["SESSION_COOKIE_SECURE"] = True if IS_PROD else False
app.config["SESSION_COOKIE_HTTPONLY"] = True
app.config["PREFERRED_URL_SCHEME"] = "https" if IS_PROD else "http"
app.config["MAX_CONTENT_LENGTH"] = 15 * 1024 * 1024  # 15MB — cukup untuk foto selfie/logo

app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1, x_port=1)

init_oauth(app)


@app.errorhandler(500)
def handle_internal_error(e):
    """Tampilkan pesan error asli (bukan halaman generik) ke admin/owner yang
    lagi login, supaya bug production bisa langsung ketahuan penyebabnya
    tanpa perlu akses log server. User biasa tetap lihat halaman generik."""
    import traceback
    original = getattr(e, "original_exception", None) or e
    if session.get("role") in ("admin", "owner"):
        tb = "".join(traceback.format_exception(type(original), original, original.__traceback__))
        return (
            "<pre style='white-space:pre-wrap; font-family:monospace; padding:20px; "
            "background:#1e1e1e; color:#f87171; font-size:13px;'>"
            f"Internal Server Error\n\n{type(original).__name__}: {original}\n\n{tb}"
            "</pre>",
            500,
        )
    return "Internal Server Error", 500


@app.after_request
def add_mobile_api_headers(response):
    # CORS hanya untuk API JSON mobile (Bearer token, bukan cookie session).
    # Rute web (admin/login/dsb pakai session cookie) sengaja tidak diberi
    # header ini supaya tidak bisa dibaca cross-origin oleh situs lain.
    if request.path.startswith("/api/mobile"):
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
app.register_blueprint(nota_bp)
app.register_blueprint(preview_bp)
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
app.register_blueprint(finance_bp)

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
app.register_blueprint(data_cleanup_bp)  # ← BARU
app.register_blueprint(mobile_stats_export_bp, url_prefix="/api/mobile")
app.register_blueprint(mobile_buy_prices_bp, url_prefix="/api/mobile")
app.register_blueprint(mobile_profile_bp, url_prefix="/api/mobile")
app.register_blueprint(mobile_finance_bp, url_prefix="/api/mobile")  # ← FINANCE
app.register_blueprint(mobile_owner_bp, url_prefix="/api/mobile")
app.register_blueprint(mobile_owner_stats_bp, url_prefix="/api/mobile")

@app.route("/api/mobile/send-reminder", methods=["POST"])
def send_daily_reminder():
    if not _internal_key_ok():
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
    

@app.route("/api/mobile/send-daily-summary", methods=["POST"])
def send_daily_summary():
    if not _internal_key_ok():
        return jsonify({"ok": False, "message": "Unauthorized"}), 403

    try:
        from core import send_fcm_to_tokens
        from db import get_conn
        from psycopg2.extras import RealDictCursor
        from datetime import date

        conn  = get_conn()
        cur   = conn.cursor(cursor_factory=RealDictCursor)
        today = date.today()

        cur.execute("""
            SELECT
                COUNT(*) FILTER (WHERE a.status = 'PRESENT')             AS hadir,
                COUNT(*) FILTER (WHERE a.status = 'ABSENT')              AS absen,
                COUNT(*) FILTER (WHERE a.status = 'SICK')                AS sakit,
                COUNT(*) FILTER (WHERE a.status = 'LEAVE')               AS izin,
                COUNT(*) FILTER (WHERE a.arrival_type = 'LATE'
                                   AND a.status = 'PRESENT')             AS terlambat,
                COUNT(DISTINCT u.id)                                      AS total_karyawan
            FROM users u
            LEFT JOIN attendance a ON a.user_id = u.id AND a.work_date = %s
            WHERE u.role = 'employee';
        """, (today,))
        rekap = cur.fetchone()

        hadir     = int(rekap['hadir']          or 0)
        absen     = int(rekap['absen']          or 0)
        sakit     = int(rekap['sakit']          or 0)
        izin      = int(rekap['izin']           or 0)
        terlambat = int(rekap['terlambat']      or 0)
        total     = int(rekap['total_karyawan'] or 0)
        belum     = total - hadir - absen - sakit - izin

        cur.execute("SELECT COUNT(*) AS p FROM sales_submissions WHERE status = 'PENDING';")
        pending = int((cur.fetchone() or {}).get('p', 0))

        cur.execute("""
            SELECT DISTINCT d.fcm_token
            FROM mobile_device_tokens d
            JOIN users u ON u.id = d.user_id
            WHERE u.role = 'admin' AND d.is_active = TRUE
              AND COALESCE(d.fcm_token, '') <> '';
        """)
        tokens = [r["fcm_token"] for r in cur.fetchall()]
        cur.close(); conn.close()

        if not tokens:
            return jsonify({"ok": True, "message": "Tidak ada admin FCM token", "sent": 0})

        lines = [f"✅ Hadir: {hadir}"]
        if terlambat > 0: lines.append(f"⏰ Terlambat: {terlambat}")
        if sakit     > 0: lines.append(f"🤒 Sakit: {sakit}")
        if izin      > 0: lines.append(f"📋 Izin: {izin}")
        if absen     > 0: lines.append(f"❌ Absen: {absen}")
        if belum     > 0: lines.append(f"⚠️ Belum absen: {belum}")

        body = " • ".join(lines)
        if pending > 0:
            body += f"\n📦 {pending} penjualan menunggu approval"

        send_fcm_to_tokens(
            tokens,
            title=f"📊 Rekap Harian — {today.strftime('%d/%m/%Y')}",
            body=body,
            data={"type": "daily_summary", "screen": "attendance", "date": str(today)}
        )

        print(f"[SUMMARY] {today} → {len(tokens)} admin | {body}")
        return jsonify({"ok": True, "sent": len(tokens),
                        "rekap": {"hadir": hadir, "absen": absen, "sakit": sakit,
                                  "izin": izin, "terlambat": terlambat,
                                  "belum": belum, "pending_sales": pending}})
    except Exception as e:
        return jsonify({"ok": False, "message": str(e)}), 500


@app.route("/api/mobile/auto-checkout", methods=["POST"])
def auto_checkout_midnight():
    """Checkout otomatis untuk karyawan yang lupa check-out kemarin/sebelumnya.
    Dipicu cron eksternal ~00:05 WIB — sama seperti send-reminder/send-daily-summary
    di atas, bukan scheduler internal."""
    if not _internal_key_ok():
        return jsonify({"ok": False, "message": "Unauthorized"}), 403

    try:
        from core import auto_checkout_forgotten
        n = auto_checkout_forgotten()
        print(f"[AUTO-CHECKOUT] {n} attendance ditutup otomatis")
        return jsonify({"ok": True, "checked_out": n})
    except Exception as e:
        return jsonify({"ok": False, "message": str(e)}), 500


@app.route("/api/mobile/version")
def app_version():
    return jsonify({
        "latest_version": "1.2.0",      # ← update tiap rilis baru
        "min_version":    "1.2.0",      # versi minimum yang boleh jalan
        "force_update":   True,         # True = wajib update, False = opsional
        "update_url":     "https://github.com/umgap2026-cmd/UMGAP-AI/releases/download/mobile-v1.2.0/umgap-v1.2.0.apk",
        "sha256":         "07fb8b95c31be2f85bd38f10c0793e17b5c586473585e2a00c49053f85dca624",
        "message":        "Versi baru v1.2.0 tersedia!\n• Hapus fitur fingerprint (biofinger)\n• Keamanan reset password diperkuat\n• Bug fix overflow"
    })

@app.route("/ping")
def ping():
    return "ok", 200

@app.route("/panduan")
def panduan():
    return app.send_static_file("panduan_umgap.html")

if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=not IS_PROD)
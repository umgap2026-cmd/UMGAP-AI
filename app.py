import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from flask import Flask
from dotenv import load_dotenv
from werkzeug.middleware.proxy_fix import ProxyFix

from core import init_oauth


#------ WEB -----

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

#------ MOBILE -------
from routes.mobile.auth import mobile_auth_bp
from routes.mobile.attendance import mobile_attendance_bp
from routes.mobile.hpp import mobile_hpp_bp



try:
    from routes.mobile.auth import mobile_auth_bp
except Exception:
    mobile_auth_bp = None

try:
    from routes.mobile.attendance import mobile_attendance_bp
except Exception:
    mobile_attendance_bp = None

load_dotenv()

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



app.register_blueprint(mobile_auth_bp)
app.register_blueprint(mobile_attendance_bp)
app.register_blueprint(mobile_hpp_bp)



if __name__ == "__main__":
    port = int(os.getenv("PORT", "5000"))
    app.run(host="0.0.0.0", port=port, debug=not IS_PROD)

from flask import Blueprint, render_template, abort

preview_bp = Blueprint("preview", __name__)

@preview_bp.route("/preview/<name>")
def preview_template(name):
    allowed = {
        "login": "login.html",
        "register": "register.html",
        "dashboard": "dashboard.html",
        "products": "products.html",
    }
    if name not in allowed:
        abort(404)

    dummy = {
        "user_name": "UMKM Demo",
        "total_products": 3,
        "total_contents": 5,
        "total_done": 2,
        "products": [
            {"id": 1, "name": "Kopi Susu", "price": 12000},
            {"id": 2, "name": "Roti Bakar", "price": 15000},
            {"id": 3, "name": "Teh Manis", "price": 6000},
        ],
        "error": None,
    }
    return render_template(allowed[name], **dummy)
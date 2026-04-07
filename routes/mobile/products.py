from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_products_bp = Blueprint("mobile_products", __name__)


@mobile_products_bp.route("/products", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_products_list():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, name, price, user_id, is_global
            FROM products
            ORDER BY id DESC;
        """)
        rows = [dict(r) for r in cur.fetchall()]
        return mobile_api_response(ok=True, message="OK", data={"products": rows}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_products_bp.route("/products/global", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_products_global():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, name, price
            FROM products
            WHERE is_global=TRUE
            ORDER BY id DESC;
        """)
        rows = [dict(r) for r in cur.fetchall()]
        return mobile_api_response(ok=True, message="OK", data={"products": rows}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_products_bp.route("/products", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_products_add():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    data = request.get_json(silent=True) or {}

    name = (data.get("name") or "").strip()
    price = data.get("price") or 0

    if not name:
        return mobile_api_response(ok=False, message="Nama produk wajib diisi.", status_code=400)

    try:
        price_int = int(price)
        if price_int < 0:
            price_int = 0
    except Exception:
        price_int = 0

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO products (user_id, name, price, is_global)
            VALUES (%s, %s, %s, TRUE);
        """, (user["user_id"], name, price_int))
        conn.commit()
        return mobile_api_response(ok=True, message="Produk berhasil ditambahkan.", data={}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_products_bp.route("/products/<int:pid>", methods=["PUT", "OPTIONS"])
@mobile_api_login_required
def mobile_products_update(pid):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    price = data.get("price") or 0

    if not name:
        return mobile_api_response(ok=False, message="Nama produk wajib diisi.", status_code=400)

    try:
        price_int = int(price)
        if price_int < 0:
            price_int = 0
    except Exception:
        price_int = 0

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE products
            SET name=%s, price=%s
            WHERE id=%s;
        """, (name, price_int, pid))
        conn.commit()
        return mobile_api_response(ok=True, message="Produk berhasil diupdate.", data={}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_products_bp.route("/products/<int:pid>", methods=["DELETE", "OPTIONS"])
@mobile_api_login_required
def mobile_products_delete(pid):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM products WHERE id=%s;", (pid,))
        conn.commit()
        return mobile_api_response(ok=True, message="Produk berhasil dihapus.", data={}, status_code=200)
    finally:
        cur.close()
        conn.close()
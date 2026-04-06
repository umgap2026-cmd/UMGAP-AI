from flask import Blueprint, render_template, redirect, request, session, abort
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import is_logged_in

products_bp = Blueprint("products", __name__)


@products_bp.route("/products")
def products():
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        cur.execute("""
            SELECT id, name, price, user_id, is_global
            FROM products
            ORDER BY id DESC;
        """)
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template("products.html", products=rows, error=None)


@products_bp.route("/products/add", methods=["POST"])
def products_add():
    if not is_logged_in():
        return redirect("/login")

    name = (request.form.get("name") or "").strip()
    price = (request.form.get("price") or "0").strip()

    if not name:
        return redirect("/products")

    try:
        price_int = int(price)
        if price_int < 0:
            price_int = 0
    except:
        price_int = 0

    conn = get_conn()
    cur = conn.cursor()

    try:
        cur.execute("""
            INSERT INTO products (user_id, name, price, is_global)
            VALUES (%s, %s, %s, TRUE);
        """, (session["user_id"], name, price_int))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/products")


@products_bp.route("/products/delete/<int:pid>")
def products_delete(pid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()

    try:
        cur.execute("DELETE FROM products WHERE id=%s;", (pid,))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/products")


@products_bp.route("/products/edit/<int:pid>", methods=["GET", "POST"])
def products_edit(pid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        cur.execute("""
            SELECT id, name, price, user_id, is_global
            FROM products
            WHERE id=%s
            LIMIT 1;
        """, (pid,))
        product = cur.fetchone()

        if not product:
            abort(404)

        if request.method == "GET":
            return render_template("product_edit.html", product=product, error=None)

        name = (request.form.get("name") or "").strip()
        price = (request.form.get("price") or "0").strip()

        if not name:
            return render_template("product_edit.html", product=product, error="Nama wajib")

        try:
            price_int = int(price)
            if price_int < 0:
                price_int = 0
        except:
            price_int = 0

        cur2 = conn.cursor()
        try:
            cur2.execute("""
                UPDATE products
                SET name=%s, price=%s
                WHERE id=%s;
            """, (name, price_int, pid))
            conn.commit()
        finally:
            cur2.close()

        return redirect("/products")

    finally:
        cur.close()
        conn.close()
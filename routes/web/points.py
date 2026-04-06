import os
from flask import Blueprint, render_template, request, redirect, session
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import admin_required

points_bp = Blueprint("points", __name__)


@points_bp.route("/admin/points")
def admin_points():
    deny = admin_required()
    if deny:
        return deny

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("""
        SELECT id, name, email,
        COALESCE(points,0) AS points,
        COALESCE(points_admin,0) AS points_admin
        FROM users WHERE role='employee'
        ORDER BY name ASC;
    """)
    employees = cur.fetchall()

    cur.execute("""
        SELECT l.created_at, u.name AS user_name,
               l.delta, l.note, a.name AS admin_name
        FROM points_logs l
        JOIN users u ON u.id=l.user_id
        JOIN users a ON a.id=l.admin_id
        ORDER BY l.created_at DESC LIMIT 50;
    """)
    logs = cur.fetchall()

    cur.close()
    conn.close()

    return render_template("input_poin.html",
        employees=employees,
        logs=logs
    )


@points_bp.route("/admin/points/add", methods=["POST"])
def admin_points_add():
    deny = admin_required()
    if deny:
        return deny

    user_id = int(request.form["user_id"])
    delta = int(request.form["delta"])
    note = request.form.get("note")

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        UPDATE users
        SET points_admin = COALESCE(points_admin,0)+%s
        WHERE id=%s;
    """, (delta, user_id))

    cur.execute("""
        INSERT INTO points_logs (user_id, admin_id, delta, note)
        VALUES (%s,%s,%s,%s);
    """, (user_id, session["user_id"], delta, note))

    conn.commit()
    conn.close()

    return redirect("/admin/points")
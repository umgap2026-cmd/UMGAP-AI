import os
from flask import Blueprint, render_template, request, redirect, session
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import admin_points_required

points_bp = Blueprint("points", __name__)

POINTS_LOG_PAGE_SIZE = 50


@points_bp.route("/admin/points")
def admin_points():
    deny = admin_points_required()
    if deny:
        return deny

    try:
        log_page = max(1, int(request.args.get("log_page", 1)))
    except (TypeError, ValueError):
        log_page = 1

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
        ORDER BY l.created_at DESC
        LIMIT %s OFFSET %s;
    """, (POINTS_LOG_PAGE_SIZE + 1, (log_page - 1) * POINTS_LOG_PAGE_SIZE))
    logs = cur.fetchall()
    log_has_next = len(logs) > POINTS_LOG_PAGE_SIZE
    logs = logs[:POINTS_LOG_PAGE_SIZE]

    cur.close()
    conn.close()

    return render_template("input_poin.html",
        employees=employees,
        logs=logs,
        log_page=log_page,
        log_has_next=log_has_next,
        log_has_prev=log_page > 1,
    )


@points_bp.route("/admin/points/add", methods=["POST"])
def admin_points_add():
    deny = admin_points_required()
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
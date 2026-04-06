import os
from datetime import date

from flask import Blueprint, render_template, redirect, session
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import is_logged_in
from core import get_notif_count, ensure_points_schema

dashboard_bp = Blueprint("dashboard", __name__)

@dashboard_bp.route("/dashboard")
def dashboard():
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        user_id = session.get("user_id")

        # ambil poin user
        cur.execute("SELECT points_admin, name FROM users WHERE id=%s LIMIT 1;", (user_id,))
        u = cur.fetchone() or {}

        # notifikasi / pengumuman yang belum dibaca user
        cur.execute("""
            SELECT a.id, a.title, a.message, a.created_at
            FROM announcements a
            LEFT JOIN announcement_reads ar
              ON ar.announcement_id = a.id
             AND ar.user_id = %s
            WHERE a.is_active = TRUE
              AND ar.id IS NULL
            ORDER BY a.created_at DESC
            LIMIT 20;
        """, (user_id,))
        announcements = cur.fetchall()

        notif_count = len(announcements)

    finally:
        cur.close()
        conn.close()

    return render_template(
        "dashboard.html",
        user_name=session.get("user_name"),
        points_admin=(u.get("points_admin") or 0),
        notif_count=notif_count,
        announcements=announcements
    )
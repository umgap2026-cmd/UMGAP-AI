from flask import Blueprint, render_template, redirect, session, request, abort
from psycopg2.extras import RealDictCursor

from db import get_conn

notifications_bp = Blueprint("notifications", __name__)


@notifications_bp.route("/notifications")
def notifications():
    if "user_id" not in session:
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("""
        SELECT id, title, message, created_at
        FROM announcements
        WHERE is_active = TRUE
        ORDER BY created_at DESC
        LIMIT 50;
    """)

    announcements = cur.fetchall()
    cur.close()
    conn.close()

    return render_template("notifications.html", announcements=announcements)


@notifications_bp.route("/notifications/read/<int:ann_id>")
def mark_notification_read(ann_id):
    if "user_id" not in session:
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO announcement_reads (announcement_id, user_id)
        VALUES (%s, %s)
        ON CONFLICT DO NOTHING;
    """, (ann_id, session["user_id"]))

    conn.commit()
    conn.close()

    return redirect("/notifications")


# ---------- ADMIN ----------
@notifications_bp.route("/admin/announcements")
def admin_announcements():
    if session.get("role") != "admin":
        return abort(403)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("SELECT * FROM announcements ORDER BY created_at DESC")
    data = cur.fetchall()

    conn.close()

    return render_template("admin_announcements.html", data=data)


@notifications_bp.route("/admin/announcements/add", methods=["POST"])
def add_announcement():
    if session.get("role") != "admin":
        return abort(403)

    title = request.form["title"]
    message = request.form["message"]

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO announcements (title, message, created_by)
        VALUES (%s, %s, %s);
    """, (title, message, session["user_id"]))

    conn.commit()
    conn.close()

    return redirect("/admin/announcements")


@notifications_bp.route("/admin/announcements/delete/<int:id>")
def delete_announcement(id):
    if session.get("role") != "admin":
        return abort(403)

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("DELETE FROM announcements WHERE id=%s", (id,))
    conn.commit()
    conn.close()

    return redirect("/admin/announcements")
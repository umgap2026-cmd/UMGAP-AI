from flask import Blueprint, render_template, redirect, session, request, abort
from psycopg2.extras import RealDictCursor
from db import get_conn

announcements_bp = Blueprint("announcements", __name__)


@announcements_bp.route("/notifications")
def notifications():
    if "user_id" not in session:
        return redirect("/login")
    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, title, message, created_at
            FROM announcements
            WHERE is_active = TRUE
            ORDER BY created_at DESC LIMIT 50;
        """)
        announcements = cur.fetchall()
    finally:
        cur.close(); conn.close()
    return render_template("notifications.html", announcements=announcements)


@announcements_bp.route("/notifications/read/<int:ann_id>")
def mark_notification_read(ann_id):
    if "user_id" not in session:
        return redirect("/login")
    conn = get_conn(); cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO announcement_reads (announcement_id, user_id)
            VALUES (%s, %s)
            ON CONFLICT (announcement_id, user_id) DO NOTHING;
        """, (ann_id, session["user_id"]))
        conn.commit()
    finally:
        cur.close(); conn.close()
    return redirect("/notifications")


@announcements_bp.route("/admin/announcements")
def admin_announcements():
    if session.get("role") != "admin":
        return abort(403)
    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, title, message, body,
                created_at AT TIME ZONE 'UTC' AT TIME ZONE 'Asia/Jakarta' AS created_at,
                created_by, is_active
            FROM announcements 
            WHERE is_active = TRUE 
            ORDER BY created_at DESC;
        """)
        data = cur.fetchall()
    finally:
        cur.close(); conn.close()
    return render_template("admin_announcements.html", data=data)


@announcements_bp.route("/admin/announcements/add", methods=["POST"])
def add_announcement():
    if session.get("role") != "admin":
        return abort(403)

    title   = request.form["title"]
    message = request.form["message"]

    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            INSERT INTO announcements (title, message, body, created_by)
            VALUES (%s, %s, %s, %s)
            RETURNING id;
        """, (title, message, message, session["user_id"]))
        row = cur.fetchone()
        conn.commit()

        # Kirim FCM ke semua device aktif
        import threading
        ann_id = row["id"]
        def _push():
            try:
                from core import send_fcm_to_tokens
                c2 = get_conn(); cu = c2.cursor(cursor_factory=RealDictCursor)
                cu.execute("SELECT DISTINCT fcm_token FROM mobile_device_tokens WHERE is_active=TRUE AND COALESCE(fcm_token,'') <> '';")
                tokens = [r["fcm_token"] for r in cu.fetchall()]
                cu.close(); c2.close()
                if tokens:
                    send_fcm_to_tokens(tokens,
                        title=f"📢 {title}",
                        body=message[:120] + ("..." if len(message) > 120 else ""),
                        data={"type": "announcement", "screen": "notifications"})
                    print(f"[FCM] Web announcement dikirim ke {len(tokens)} device")
            except Exception as ex:
                print(f"[FCM web] {ex}")
        threading.Thread(target=_push, daemon=True).start()

    finally:
        cur.close(); conn.close()

    return redirect("/admin/announcements")


@announcements_bp.route("/admin/announcements/delete/<int:id>")
def delete_announcement(id):
    if session.get("role") != "admin":
        return abort(403)
    conn = get_conn(); cur = conn.cursor()
    try:
        cur.execute("UPDATE announcements SET is_active=FALSE WHERE id=%s;", (id,))
        conn.commit()
    finally:
        cur.close(); conn.close()
    return redirect("/admin/announcements")

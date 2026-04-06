from flask import Blueprint, render_template, request, redirect, session
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import is_logged_in

content_bp = Blueprint("content", __name__)


@content_bp.route("/init-content")
def init_content():
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS content_plans (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            plan_date DATE NOT NULL,
            platform VARCHAR(30) NOT NULL,
            content_type VARCHAR(30) NOT NULL,
            notes TEXT,
            is_done BOOLEAN NOT NULL DEFAULT FALSE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
    """)

    conn.commit()
    cur.close()
    conn.close()

    return "OK"


@content_bp.route("/content", methods=["GET", "POST"])
def content():
    if not is_logged_in():
        return redirect("/login")

    user_id = session.get("user_id")

    if request.method == "POST":
        plan_date = request.form.get("plan_date")
        platform = request.form.get("platform")
        content_type = request.form.get("content_type")
        notes = request.form.get("notes")

        if plan_date and platform and content_type:
            conn = get_conn()
            cur = conn.cursor()

            cur.execute("""
                INSERT INTO content_plans
                (user_id, plan_date, platform, content_type, notes, is_done)
                VALUES (%s,%s,%s,%s,%s,FALSE);
            """, (user_id, plan_date, platform, content_type, notes))

            conn.commit()
            cur.close()
            conn.close()

        return redirect("/content")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("""
        SELECT *
        FROM content_plans
        WHERE user_id=%s
        ORDER BY is_done ASC, plan_date ASC, id DESC;
    """, (user_id,))

    plans = cur.fetchall()
    cur.close()
    conn.close()

    return render_template("content.html", plans=plans)


@content_bp.route("/content/add", methods=["POST"])
def content_add():
    if not is_logged_in():
        return redirect("/login")

    plan_date = request.form.get("plan_date")
    platform = request.form.get("platform")
    content_type = request.form.get("content_type")
    notes = request.form.get("notes")

    if not plan_date or not platform or not content_type:
        return redirect("/content")

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO content_plans
        (user_id, plan_date, platform, content_type, notes)
        VALUES (%s,%s,%s,%s,%s);
    """, (session["user_id"], plan_date, platform, content_type, notes))

    conn.commit()
    cur.close()
    conn.close()

    return redirect("/content")


@content_bp.route("/content/done/<int:cid>")
def content_done(cid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        UPDATE content_plans
        SET is_done=TRUE
        WHERE id=%s AND user_id=%s;
    """, (cid, session["user_id"]))

    conn.commit()
    cur.close()
    conn.close()

    return redirect("/content")


@content_bp.route("/content/undo/<int:cid>")
def content_undo(cid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        UPDATE content_plans
        SET is_done=FALSE
        WHERE id=%s AND user_id=%s;
    """, (cid, session["user_id"]))

    conn.commit()
    cur.close()
    conn.close()

    return redirect("/content")


@content_bp.route("/content/delete/<int:cid>")
def content_delete(cid):
    if not is_logged_in():
        return redirect("/login")

    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        DELETE FROM content_plans
        WHERE id=%s AND user_id=%s;
    """, (cid, session["user_id"]))

    conn.commit()
    cur.close()
    conn.close()

    return redirect("/content")
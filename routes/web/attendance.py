import os
import uuid
from datetime import date

from flask import Blueprint, render_template, redirect, request, session
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import is_logged_in, is_admin, _now_wib_naive_from_form, _public_ip


attendance_bp = Blueprint("attendance", __name__)


@attendance_bp.route("/attendance")
def attendance_page():
    if not is_logged_in():
        return redirect("/login")

    if is_admin():
        return redirect("/admin")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("""
        SELECT work_date, arrival_type, status, note, checkin_at
        FROM attendance
        WHERE user_id=%s
        ORDER BY work_date DESC, checkin_at DESC NULLS LAST;
    """, (session["user_id"],))

    rows = cur.fetchall()
    cur.close()
    conn.close()

    return render_template("attendance.html", rows=rows)


@attendance_bp.route("/attendance/add", methods=["POST"])
def attendance_add():
    if not is_logged_in():
        return redirect("/login")

    arrival_type = (request.form.get("arrival_type") or "ONTIME").upper()
    note = (request.form.get("note") or "").strip()

    now = _now_wib_naive_from_form()
    work_date = now.date()

    device_id = request.form.get("device_id")

    lat = request.form.get("latitude")
    lng = request.form.get("longitude")
    acc = request.form.get("accuracy")

    def to_float(x):
        try:
            return float(x) if x else None
        except:
            return None

    lat = to_float(lat)
    lng = to_float(lng)
    acc = to_float(acc)

    # upload foto
    photo = request.files.get("selfie")
    photo_path = None

    if photo and photo.filename:
        os.makedirs("static/uploads/attendance_user", exist_ok=True)
        filename = f"att_{date.today()}_{uuid.uuid4().hex}.jpg"
        path = os.path.join("static/uploads/attendance_user", filename)
        photo.save(path)
        photo_path = f"uploads/attendance_user/{filename}"

    conn = get_conn()
    cur = conn.cursor()

    try:
        cur.execute("""
            INSERT INTO attendance_pending
            (user_id, work_date, arrival_type, note, name_input,
             device_id, latitude, longitude, accuracy, photo_path,
             ip_address, status, created_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'PENDING',%s)
        """, (
            session["user_id"],
            work_date,
            arrival_type,
            note,
            session["user_name"],
            device_id,
            lat,
            lng,
            acc,
            photo_path,
            _public_ip(),
            now
        ))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/attendance")
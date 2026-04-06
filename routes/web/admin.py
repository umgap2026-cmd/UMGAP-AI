import os
import uuid
from datetime import date

from flask import Blueprint, render_template, redirect, request, session
from psycopg2.extras import RealDictCursor
from werkzeug.security import generate_password_hash

from db import get_conn
from core import admin_guard, admin_required
from core import get_notif_count, ensure_points_schema
from datetime import date
from core import _now_wib_naive_from_form
from core import _parse_manual_wib_naive
from core import _public_ip
from core import _now_wib_naive
from core import is_token_valid

admin_bp = Blueprint("admin", __name__)

@admin_bp.route("/admin")
def admin_home():
    deny = admin_guard()
    if deny:
        return deny
    return redirect("/admin/dashboard")

@admin_bp.route("/admin/dashboard")
def admin_dashboard():
    deny = admin_required()
    if deny:
        return deny

    if os.getenv("RUN_SCHEMA_ON_REQUEST", "").lower() == "true":
        ensure_points_schema()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT COUNT(*) AS total FROM users WHERE role='employee';")
        total_employees = cur.fetchone()["total"]

        today = date.today()
        cur.execute("SELECT COUNT(*) AS total FROM attendance WHERE work_date=%s AND status='PRESENT';", (today,))
        total_attendance_today = cur.fetchone()["total"]

        cur.execute("SELECT COUNT(*) AS total FROM products;")
        total_products = cur.fetchone()["total"]

        cur.execute("SELECT id, name, email FROM users WHERE role='employee' ORDER BY name ASC;")
        employees = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    notif_count = get_notif_count()

    return render_template(
        "admin_dashboard.html",
        user_name=session.get("user_name", "Admin"),
        notif_count=int(notif_count or 0),
        total_employees=total_employees,
        total_attendance_today=total_attendance_today,
        total_products=total_products,
        employees=employees
    )

@admin_bp.route("/admin/users")
def admin_users():
    admin_guard()
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT u.id, u.name, u.email, u.role, COALESCE(p.daily_salary, 0) AS daily_salary
            FROM users u
            LEFT JOIN payroll_settings p ON p.user_id=u.id
            ORDER BY u.id DESC;
        """)
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template("admin_users.html", rows=rows, error=None)

@admin_bp.route("/admin/users/create", methods=["POST"])
def admin_users_create():
    admin_guard()
    name = (request.form.get("name") or "").strip()
    email = (request.form.get("email") or "").strip().lower()
    password = request.form.get("password") or ""
    role = (request.form.get("role") or "employee").strip()
    daily_salary = int(request.form.get("daily_salary") or "0")

    if not name or not email or not password:
        return redirect("/admin/users")

    pw_hash = generate_password_hash(password)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            INSERT INTO users (name, email, password_hash, role)
            VALUES (%s, %s, %s, %s)
            RETURNING id;
        """, (name, email, pw_hash, role))
        row = cur.fetchone() or {}
        uid = row.get("id")

        if uid:
            cur.execute("""
                INSERT INTO payroll_settings (user_id, daily_salary)
                VALUES (%s, %s)
                ON CONFLICT (user_id)
                DO UPDATE SET daily_salary=EXCLUDED.daily_salary, updated_at=CURRENT_TIMESTAMP;
            """, (uid, daily_salary))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/users")

@admin_bp.route("/admin/users/update/<int:uid>", methods=["POST"])
def admin_users_update(uid):
    admin_guard()
    name = (request.form.get("name") or "").strip()
    email = (request.form.get("email") or "").strip().lower()
    role = (request.form.get("role") or "employee").strip()
    daily_salary = int(request.form.get("daily_salary") or "0")
    new_password = (request.form.get("new_password") or "").strip()

    conn = get_conn()
    cur = conn.cursor()
    try:
        if new_password:
            pw_hash = generate_password_hash(new_password)
            cur.execute("""
                UPDATE users
                SET name=%s, email=%s, role=%s, password_hash=%s
                WHERE id=%s;
            """, (name, email, role, pw_hash, uid))
        else:
            cur.execute("""
                UPDATE users
                SET name=%s, email=%s, role=%s
                WHERE id=%s;
            """, (name, email, role, uid))

        cur.execute("""
            INSERT INTO payroll_settings (user_id, daily_salary)
            VALUES (%s, %s)
            ON CONFLICT (user_id)
            DO UPDATE SET daily_salary=EXCLUDED.daily_salary, updated_at=CURRENT_TIMESTAMP;
        """, (uid, daily_salary))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/users")

@admin_bp.route("/admin/users/delete/<int:uid>", methods=["POST"])
def admin_users_delete(uid):
    admin_guard()

    if uid == session.get("user_id"):
        return redirect("/admin/users")

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("DELETE FROM users WHERE id=%s;", (uid,))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/users")

@admin_bp.route("/admin/quick-attendance-links", methods=["GET", "POST"])
def admin_quick_attendance_links():
    deny = admin_required()
    if deny:
        return deny

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        if request.method == "POST":
            action = (request.form.get("action") or "").strip().lower()

            if action == "create":
                label = (request.form.get("label") or "").strip() or "Link Absensi"
                token = uuid.uuid4().hex

                cur.execute("""
                    INSERT INTO attendance_links (token, label, created_by, is_active)
                    VALUES (%s, %s, %s, TRUE);
                """, (token, label, session.get("user_id")))
                conn.commit()

            elif action == "toggle":
                raw_id = (request.form.get("id") or "").strip()
                if raw_id.isdigit():
                    link_id = int(raw_id)

                    cur.execute("""
                        UPDATE attendance_links
                        SET is_active = NOT is_active
                        WHERE id = %s;
                    """, (link_id,))
                    conn.commit()

            elif action == "delete":
                raw_id = (request.form.get("id") or "").strip()
                if raw_id.isdigit():
                    link_id = int(raw_id)

                    cur.execute("""
                        DELETE FROM attendance_links
                        WHERE id = %s;
                    """, (link_id,))
                    conn.commit()

        cur.execute("""
            SELECT
                id,
                token,
                label,
                created_at,
                is_active
            FROM attendance_links
            ORDER BY created_at DESC
            LIMIT 50;
        """)
        links = cur.fetchall()

        base_url = request.host_url.rstrip("/")

        for row in links:
            row["public_url"] = f"{base_url}/quick-attendance/{row['token']}"

        return render_template(
            "admin_quick_attendance_links.html",
            links=links,
            base_url=base_url
        )

    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()
        conn.close()

@admin_bp.route("/quick-attendance/<token>", methods=["GET"])
def quick_attendance_form(token):
    if not is_token_valid(token):
        return render_template("quick_attendance.html", token=token, error="Link absensi tidak valid atau sudah nonaktif."), 404

    return render_template("quick_attendance.html", token=token, error=None, success=None)


@admin_bp.route("/quick-attendance/<token>/submit", methods=["POST"])
def quick_attendance_submit(token):
    if not is_token_valid(token):
        return render_template("quick_attendance.html", token=token, error="Link absensi tidak valid atau sudah nonaktif."), 404

    name_input = (request.form.get("name_input") or "").strip()
    device_id = (request.form.get("device_id") or "").strip()
    latitude = request.form.get("latitude")
    longitude = request.form.get("longitude")
    accuracy = request.form.get("accuracy")

    if not name_input:
        return render_template("quick_attendance.html", token=token, error="Nama wajib diisi.", success=None)

    def to_float(v):
        try:
            return float(v) if v not in (None, "") else None
        except Exception:
            return None

    lat = to_float(latitude)
    lng = to_float(longitude)
    acc = to_float(accuracy)

    photo = request.files.get("selfie")
    photo_path = None

    if photo and photo.filename:
        os.makedirs("static/uploads/quick_attendance", exist_ok=True)
        filename = f"qa_{date.today().strftime('%Y_%m_%d')}_{uuid.uuid4().hex}.jpg"
        save_path = os.path.join("static/uploads/quick_attendance", filename)
        photo.save(save_path)
        photo_path = f"uploads/quick_attendance/{filename}"

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO attendance_pending
            (user_id, work_date, arrival_type, note, name_input,
             device_id, latitude, longitude, accuracy, photo_path,
             ip_address, status, created_at)
            VALUES (NULL, %s, 'ONTIME', %s, %s,
                    %s, %s, %s, %s, %s,
                    %s, 'PENDING', %s);
        """, (
            date.today(),
            f"Quick attendance from token {token}",
            name_input,
            device_id or None,
            lat,
            lng,
            acc,
            photo_path,
            _public_ip(),
            _now_wib_naive()
        ))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return render_template(
        "quick_attendance.html",
        token=token,
        error=None,
        success="Absen berhasil dikirim dan menunggu verifikasi admin."
    )

# ---------- ADMIN: APPROVAL ATTENDANCE ----------
@admin_bp.route("/admin/attendance-approval", methods=["GET"])
def admin_attendance_approval():
    deny = admin_required()
    if deny:
        return deny

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                id,
                name_input,
                user_id,
                work_date,
                arrival_type,
                note,
                device_id,
                latitude,
                longitude,
                accuracy,
                photo_path,
                created_at,
                created_at AS created_at_wib
            FROM attendance_pending
            WHERE status='PENDING'
            ORDER BY created_at DESC
            LIMIT 200;
        """)
        pendings = cur.fetchall()

        cur.execute("""
            SELECT id, name, email
            FROM users
            WHERE role='employee'
            ORDER BY name ASC;
        """)
        employees = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return render_template(
        "admin_attendance_approval.html",
        pendings=pendings,
        employees=employees
    )


@admin_bp.route("/admin/attendance-approval/approve", methods=["POST"])
def admin_attendance_approve():
    deny = admin_required()
    if deny:
        return deny

    pending_id = request.form.get("pending_id")
    user_id_form = request.form.get("user_id")

    if not pending_id:
        return redirect("/admin/attendance-approval")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT *
            FROM attendance_pending
            WHERE id=%s AND status='PENDING'
            LIMIT 1;
        """, (int(pending_id),))
        p = cur.fetchone()

        if not p:
            return redirect("/admin/attendance-approval")

        target_user_id = p.get("user_id") or (int(user_id_form) if user_id_form else None)
        if not target_user_id:
            return redirect("/admin/attendance-approval")

        created_at_wib = p.get("created_at_wib") or p.get("created_at")
        work_date = p.get("work_date") or (created_at_wib.date() if created_at_wib else date.today())

        arrival_type = (p.get("arrival_type") or "ONTIME").upper()

        if arrival_type in ("ONTIME", "LATE"):
            status = "PRESENT"
        elif arrival_type == "SICK":
            status = "SICK"
        elif arrival_type == "LEAVE":
            status = "LEAVE"
        elif arrival_type == "ABSENT":
            status = "ABSENT"
        else:
            status = "PRESENT"

        latv = p.get("latitude")
        lngv = p.get("longitude")
        map_url = f"https://www.google.com/maps?q={latv},{lngv}" if latv and lngv else None

        cur.execute("""
            UPDATE attendance_pending
            SET status='APPROVED',
                approved_user_id=%s,
                approved_by=%s,
                approved_at=NOW()
            WHERE id=%s;
        """, (int(target_user_id), session.get("user_id"), int(pending_id)))

        cur.execute("""
            INSERT INTO attendance
            (user_id, work_date, status, arrival_type, note, checkin_at,
             device_id, latitude, longitude, accuracy, photo_path, map_url)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
            ON CONFLICT (user_id, work_date)
            DO UPDATE SET
                status=EXCLUDED.status,
                arrival_type=EXCLUDED.arrival_type,
                note=EXCLUDED.note,
                checkin_at=EXCLUDED.checkin_at;
        """, (
            int(target_user_id),
            work_date,
            status,
            arrival_type,
            p.get("note"),
            created_at_wib,
            p.get("device_id"),
            latv,
            lngv,
            p.get("accuracy"),
            p.get("photo_path"),
            map_url
        ))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/attendance-approval")


@admin_bp.route("/admin/attendance-approval/reject", methods=["POST"])
def admin_attendance_reject():
    deny = admin_required()
    if deny:
        return deny

    pending_id = request.form.get("pending_id")
    reason = (request.form.get("reason") or "").strip()

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE attendance_pending
            SET status='REJECTED',
                rejected_by=%s,
                rejected_at=NOW(),
                reject_reason=%s
            WHERE id=%s;
        """, (session.get("user_id"), reason, int(pending_id)))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return redirect("/admin/attendance-approval")

@admin_bp.route("/admin/attendance")
def admin_attendance():
    r = admin_guard()
    if r:
        return r

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT id, name, email FROM users WHERE role='employee' ORDER BY name ASC;")
    employees = cur.fetchall()
    cur.execute("""
        SELECT a.work_date, a.arrival_type, a.status, a.note, a.checkin_at, u.name AS employee_name
        FROM attendance a
        JOIN users u ON u.id=a.user_id
        ORDER BY a.work_date DESC, a.checkin_at DESC NULLS LAST
        LIMIT 80;
    """)
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return render_template("admin_attendance.html", employees=employees, rows=rows)

@admin_bp.route("/admin/attendance/add", methods=["POST"])
def admin_attendance_add():
    deny = admin_required()
    if deny:
        return deny

    user_id = int(request.form["user_id"])
    arrival_type = (request.form.get("arrival_type") or "ONTIME").strip().upper()
    note = (request.form.get("note") or "").strip()
    manual_checkin = (request.form.get("manual_checkin") or "").strip()

    if arrival_type in ("SICK", "LEAVE", "ABSENT"):
        status = arrival_type
    else:
        status = "PRESENT"

    if user_id == session.get("user_id"):
        now = _now_wib_naive_from_form()
    else:
        now = _parse_manual_wib_naive(manual_checkin) or _now_wib_naive_from_form()

    work_date = now.date()
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    cur.execute("SELECT id FROM attendance WHERE user_id=%s AND work_date=%s LIMIT 1;", (user_id, work_date))
    existing = cur.fetchone()

    if existing:
        cur.execute("UPDATE attendance SET status=%s, arrival_type=%s, note=%s, checkin_at=%s WHERE id=%s;",
            (status, arrival_type, note, now, existing["id"]))
    else:
        cur.execute("INSERT INTO attendance (user_id, work_date, status, arrival_type, note, created_at, checkin_at) VALUES (%s, %s, %s, %s, %s, %s, %s);",
            (user_id, work_date, status, arrival_type, note, now, now))

    conn.commit()
    cur.close()
    conn.close()
    return redirect("/admin/attendance")
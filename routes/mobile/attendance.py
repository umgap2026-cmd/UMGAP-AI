import os
import uuid
from datetime import date

from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import (
    mobile_api_response,
    mobile_api_login_required,
    _public_ip,
    _now_wib_naive_from_form,
)

mobile_attendance_bp = Blueprint("mobile_attendance", __name__)


def _to_float(v):
    try:
        return float(v) if v not in (None, "") else None
    except Exception:
        return None


def _file_url(rel_path):
    if not rel_path:
        return ""
    return request.host_url.rstrip("/") + "/static/" + str(rel_path).lstrip("/")


def _format_dt(dt):
    if not dt:
        return "-"
    try:
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except Exception:
        return str(dt)


def _format_attendance_row(row):
    item = dict(row)
    item["work_date"] = str(item.get("work_date")) if item.get("work_date") else "-"
    item["checkin_at"] = _format_dt(item.get("checkin_at"))
    item["photo_url"] = _file_url(item.get("photo_path"))
    item["map_url"] = item.get("map_url") or ""
    return item


@mobile_attendance_bp.route("/attendance", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_attendance_list():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        if user.get("role") == "admin":
            cur.execute("""
                SELECT
                    a.id,
                    a.user_id,
                    u.name AS employee_name,
                    a.work_date,
                    a.arrival_type,
                    a.status,
                    a.note,
                    a.checkin_at,
                    a.device_id,
                    a.latitude,
                    a.longitude,
                    a.accuracy,
                    a.photo_path,
                    a.map_url
                FROM attendance a
                JOIN users u ON u.id = a.user_id
                ORDER BY a.work_date DESC, a.checkin_at DESC NULLS LAST
                LIMIT 300;
            """)
        else:
            cur.execute("""
                SELECT
                    id,
                    user_id,
                    work_date,
                    arrival_type,
                    status,
                    note,
                    checkin_at,
                    device_id,
                    latitude,
                    longitude,
                    accuracy,
                    photo_path,
                    map_url
                FROM attendance
                WHERE user_id=%s
                ORDER BY work_date DESC, checkin_at DESC NULLS LAST
                LIMIT 100;
            """, (user["user_id"],))

        rows = [_format_attendance_row(r) for r in cur.fetchall()]
        return mobile_api_response(
            ok=True,
            message="OK",
            data={"attendance": rows},
            status_code=200
        )
    finally:
        cur.close()
        conn.close()


@mobile_attendance_bp.route("/attendance/me", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_attendance_me():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                id,
                user_id,
                work_date,
                arrival_type,
                status,
                note,
                checkin_at,
                device_id,
                latitude,
                longitude,
                accuracy,
                photo_path,
                map_url
            FROM attendance
            WHERE user_id=%s
            ORDER BY work_date DESC, checkin_at DESC NULLS LAST
            LIMIT 100;
        """, (user["user_id"],))

        rows = [_format_attendance_row(r) for r in cur.fetchall()]
        return mobile_api_response(
            ok=True,
            message="OK",
            data={"attendance": rows},
            status_code=200
        )
    finally:
        cur.close()
        conn.close()


@mobile_attendance_bp.route("/attendance", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_attendance_submit():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user

    arrival_type = (request.form.get("attendance_type") or "ONTIME").strip().upper()
    note = (request.form.get("note") or "").strip()
    device_id = (request.form.get("device_id") or "").strip()

    now = _now_wib_naive_from_form()
    work_date = now.date()

    lat = _to_float(request.form.get("latitude"))
    lng = _to_float(request.form.get("longitude"))
    acc = _to_float(request.form.get("accuracy"))

    photo = request.files.get("selfie")
    photo_path = None

    if photo and photo.filename:
        os.makedirs("static/uploads/attendance_user", exist_ok=True)
        filename = f"att_{date.today()}_{uuid.uuid4().hex}.jpg"
        save_path = os.path.join("static/uploads/attendance_user", filename)
        photo.save(save_path)
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
            user["user_id"],
            work_date,
            arrival_type,
            note,
            user.get("name"),
            device_id or "android",
            lat,
            lng,
            acc,
            photo_path,
            _public_ip(),
            now
        ))
        conn.commit()

        return mobile_api_response(
            ok=True,
            message="Absensi berhasil dikirim dan menunggu verifikasi admin.",
            data={},
            status_code=200
        )
    except Exception as e:
        conn.rollback()
        return mobile_api_response(
            ok=False,
            message=f"Gagal kirim absensi: {str(e)}",
            status_code=500
        )
    finally:
        cur.close()
        conn.close()


@mobile_attendance_bp.route("/attendance/pending", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_attendance_pending():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    if user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)

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
        rows = cur.fetchall()

        items = []
        for r in rows:
            item = dict(r)
            item["work_date"] = str(item["work_date"]) if item.get("work_date") else "-"
            item["created_at"] = _format_dt(item.get("created_at"))
            item["created_at_wib"] = _format_dt(item.get("created_at_wib"))
            item["photo_url"] = _file_url(item.get("photo_path"))

            latv = item.get("latitude")
            lngv = item.get("longitude")
            item["map_url"] = f"https://www.google.com/maps?q={latv},{lngv}" if latv and lngv else ""
            items.append(item)

        return mobile_api_response(ok=True, message="OK", data={"attendance": items}, status_code=200)
    finally:
        cur.close()
        conn.close()


@mobile_attendance_bp.route("/attendance/pending/<int:pending_id>/approve", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_attendance_approve(pending_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    if user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)

    payload = request.get_json(silent=True) or {}
    user_id_form = payload.get("user_id")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT *
            FROM attendance_pending
            WHERE id=%s AND status='PENDING'
            LIMIT 1;
        """, (pending_id,))
        p = cur.fetchone()

        if not p:
            return mobile_api_response(ok=False, message="Data pending tidak ditemukan.", status_code=404)

        target_user_id = p.get("user_id") or (int(user_id_form) if user_id_form else None)
        if not target_user_id:
            return mobile_api_response(ok=False, message="User tujuan belum dipilih.", status_code=400)

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
        """, (int(target_user_id), user["user_id"], pending_id))

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

        return mobile_api_response(ok=True, message="Absensi berhasil disetujui.", data={}, status_code=200)
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=f"Gagal approve absensi: {str(e)}", status_code=500)
    finally:
        cur.close()
        conn.close()


@mobile_attendance_bp.route("/attendance/pending/<int:pending_id>/reject", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def mobile_attendance_reject(pending_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user = request.mobile_user
    if user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)

    payload = request.get_json(silent=True) or {}
    reason = (payload.get("reason") or "").strip()

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE attendance_pending
            SET status='REJECTED',
                rejected_by=%s,
                rejected_at=NOW(),
                reject_reason=%s
            WHERE id=%s AND status='PENDING';
        """, (user["user_id"], reason, pending_id))

        if cur.rowcount == 0:
            conn.rollback()
            return mobile_api_response(ok=False, message="Data pending tidak ditemukan.", status_code=404)

        conn.commit()
        return mobile_api_response(ok=True, message="Absensi berhasil ditolak.", data={}, status_code=200)
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=f"Gagal reject absensi: {str(e)}", status_code=500)
    finally:
        cur.close()
        conn.close()
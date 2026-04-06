import os
import uuid
from datetime import date

from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import (
    mobile_api_response,
    mobile_api_login_required,
    admin_required,
    _public_ip,
    _now_wib_naive,
)

mobile_attendance_bp = Blueprint("mobile_attendance", __name__)


def _to_float(v):
    try:
        return float(v) if v not in (None, "", "null") else None
    except Exception:
        return None


@mobile_attendance_bp.route("/attendance", methods=["GET"])
@mobile_api_login_required
def api_mobile_attendance_list():
    user = request.mobile_user

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        if user["role"] == "admin":
            cur.execute("""
                SELECT
                    a.id,
                    a.user_id,
                    u.name AS user_name,
                    a.work_date,
                    a.status,
                    a.arrival_type,
                    a.note,
                    a.checkin_at,
                    a.device_id,
                    a.latitude,
                    a.longitude,
                    a.accuracy,
                    a.photo_path,
                    a.map_url
                FROM attendance a
                LEFT JOIN users u ON u.id = a.user_id
                ORDER BY a.work_date DESC, a.id DESC
                LIMIT 300;
            """)
        else:
            cur.execute("""
                SELECT
                    a.id,
                    a.user_id,
                    u.name AS user_name,
                    a.work_date,
                    a.status,
                    a.arrival_type,
                    a.note,
                    a.checkin_at,
                    a.device_id,
                    a.latitude,
                    a.longitude,
                    a.accuracy,
                    a.photo_path,
                    a.map_url
                FROM attendance a
                LEFT JOIN users u ON u.id = a.user_id
                WHERE a.user_id=%s
                ORDER BY a.work_date DESC, a.id DESC
                LIMIT 100;
            """, (user["id"],))

        rows = cur.fetchall()

        data = []
        for r in rows:
            data.append({
                "id": r["id"],
                "user_id": r["user_id"],
                "user_name": r.get("user_name") or "",
                "work_date": str(r["work_date"] or ""),
                "status": r.get("status") or "",
                "arrival_type": r.get("arrival_type") or "",
                "note": r.get("note") or "",
                "checkin_at": str(r.get("checkin_at") or ""),
                "device_id": r.get("device_id") or "",
                "latitude": r.get("latitude"),
                "longitude": r.get("longitude"),
                "accuracy": r.get("accuracy"),
                "photo_path": r.get("photo_path") or "",
                "map_url": r.get("map_url") or "",
            })

        return mobile_api_response(True, "Riwayat absensi berhasil diambil.", data={"attendance": data})
    finally:
        cur.close()
        conn.close()


@mobile_attendance_bp.route("/attendance/me", methods=["GET"])
@mobile_api_login_required
def api_mobile_attendance_me():
    user = request.mobile_user

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                a.id,
                a.user_id,
                u.name AS user_name,
                a.work_date,
                a.status,
                a.arrival_type,
                a.note,
                a.checkin_at,
                a.device_id,
                a.latitude,
                a.longitude,
                a.accuracy,
                a.photo_path,
                a.map_url
            FROM attendance a
            LEFT JOIN users u ON u.id = a.user_id
            WHERE a.user_id=%s
            ORDER BY a.work_date DESC, a.id DESC
            LIMIT 100;
        """, (user["id"],))
        rows = cur.fetchall()

        data = []
        for r in rows:
            data.append({
                "id": r["id"],
                "user_id": r["user_id"],
                "user_name": r.get("user_name") or "",
                "work_date": str(r["work_date"] or ""),
                "status": r.get("status") or "",
                "arrival_type": r.get("arrival_type") or "",
                "note": r.get("note") or "",
                "checkin_at": str(r.get("checkin_at") or ""),
                "device_id": r.get("device_id") or "",
                "latitude": r.get("latitude"),
                "longitude": r.get("longitude"),
                "accuracy": r.get("accuracy"),
                "photo_path": r.get("photo_path") or "",
                "map_url": r.get("map_url") or "",
            })

        return mobile_api_response(True, "Riwayat absensi saya berhasil diambil.", data={"attendance": data})
    finally:
        cur.close()
        conn.close()


@mobile_attendance_bp.route("/attendance", methods=["POST"])
@mobile_api_login_required
def api_mobile_attendance_submit():
    user = request.mobile_user

    attendance_type = (request.form.get("attendance_type") or request.form.get("arrival_type") or "ONTIME").strip().upper()
    note = (request.form.get("note") or "").strip()
    latitude = _to_float(request.form.get("latitude"))
    longitude = _to_float(request.form.get("longitude"))
    accuracy = _to_float(request.form.get("accuracy"))
    device_id = (request.form.get("device_id") or "android").strip()
    now = _now_wib_naive()
    work_date = now.date()

    selfie = request.files.get("selfie")

    if selfie is None:
        return mobile_api_response(False, "Selfie wajib diupload.", status_code=400)

    photo_path = None
    if selfie and selfie.filename:
        os.makedirs("static/uploads/attendance_user", exist_ok=True)
        filename = f"att_mobile_{date.today()}_{uuid.uuid4().hex}.jpg"
        save_path = os.path.join("static/uploads/attendance_user", filename)
        selfie.save(save_path)
        photo_path = f"uploads/attendance_user/{filename}"

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            INSERT INTO attendance_pending
            (user_id, work_date, arrival_type, note, name_input,
             device_id, latitude, longitude, accuracy, photo_path,
             ip_address, status, created_at)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,'PENDING',%s);
        """, (
            user["id"],
            work_date,
            attendance_type,
            note,
            user["name"],
            device_id,
            latitude,
            longitude,
            accuracy,
            photo_path,
            _public_ip(),
            now
        ))
        conn.commit()

        return mobile_api_response(True, "Absensi berhasil dikirim dan menunggu persetujuan admin.")
    finally:
        cur.close()
        conn.close()


@mobile_attendance_bp.route("/attendance/pending", methods=["GET"])
@mobile_api_login_required
def api_mobile_attendance_pending():
    user = request.mobile_user
    if user["role"] != "admin":
        return mobile_api_response(False, "Hanya admin yang bisa mengakses data ini.", status_code=403)

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
                created_at
            FROM attendance_pending
            WHERE status='PENDING'
            ORDER BY created_at DESC
            LIMIT 200;
        """)
        rows = cur.fetchall()

        data = []
        for r in rows:
            map_url = ""
            if r.get("latitude") and r.get("longitude"):
                map_url = f"https://www.google.com/maps?q={r['latitude']},{r['longitude']}"

            data.append({
                "id": r["id"],
                "name_input": r.get("name_input") or "",
                "user_id": r.get("user_id"),
                "work_date": str(r["work_date"] or ""),
                "arrival_type": r.get("arrival_type") or "",
                "note": r.get("note") or "",
                "device_id": r.get("device_id") or "",
                "latitude": r.get("latitude"),
                "longitude": r.get("longitude"),
                "accuracy": r.get("accuracy"),
                "photo_path": r.get("photo_path") or "",
                "created_at": str(r.get("created_at") or ""),
                "map_url": map_url,
            })

        return mobile_api_response(True, "Pending absensi berhasil diambil.", data={"attendance": data})
    finally:
        cur.close()
        conn.close()


@mobile_attendance_bp.route("/attendance/pending/<int:pending_id>/approve", methods=["POST"])
@mobile_api_login_required
def api_mobile_attendance_approve(pending_id):
    user = request.mobile_user
    if user["role"] != "admin":
        return mobile_api_response(False, "Hanya admin yang bisa approve.", status_code=403)

    data = request.get_json(silent=True) or {}
    user_id_form = data.get("user_id")

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
            return mobile_api_response(False, "Data pending tidak ditemukan.", status_code=404)

        target_user_id = p.get("user_id") or user_id_form
        if not target_user_id:
            return mobile_api_response(False, "User tujuan tidak ditemukan.", status_code=400)

        created_at_wib = p.get("created_at")
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
        """, (int(target_user_id), user["id"], pending_id))

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

        return mobile_api_response(True, "Absensi berhasil disetujui.")
    finally:
        cur.close()
        conn.close()


@mobile_attendance_bp.route("/attendance/pending/<int:pending_id>/reject", methods=["POST"])
@mobile_api_login_required
def api_mobile_attendance_reject(pending_id):
    user = request.mobile_user
    if user["role"] != "admin":
        return mobile_api_response(False, "Hanya admin yang bisa reject.", status_code=403)

    data = request.get_json(silent=True) or {}
    reason = (data.get("reason") or "").strip()

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
        """, (user["id"], reason, pending_id))
        conn.commit()

        return mobile_api_response(True, "Absensi berhasil ditolak.")
    finally:
        cur.close()
        conn.close()
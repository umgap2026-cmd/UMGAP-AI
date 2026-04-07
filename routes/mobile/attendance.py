import os
import uuid
from datetime import date

from flask import Blueprint, request, jsonify
from psycopg2.extras import RealDictCursor

from db import get_conn
from .middleware import mobile_required

mobile_attendance_bp = Blueprint("mobile_attendance", __name__)


def _to_float(v):
    try:
        return float(v) if v not in (None, "", "null") else None
    except Exception:
        return None


def _row_to_attendance_dict(r):
    lat = r.get("latitude")
    lng = r.get("longitude")
    photo_path = r.get("photo_path") or ""
    photo_url = ""
    if photo_path:
        photo_url = request.host_url.rstrip("/") + "/static/" + photo_path

    map_url = r.get("map_url") or ""
    if not map_url and lat is not None and lng is not None:
        map_url = f"https://www.google.com/maps?q={lat},{lng}"

    return {
        "id": r["id"],
        "user_id": r.get("user_id"),
        "user_name": r.get("user_name"),
        "work_date": str(r.get("work_date") or ""),
        "status": r.get("status") or "",
        "arrival_type": r.get("arrival_type") or "",
        "note": r.get("note") or "",
        "device_id": r.get("device_id") or "",
        "latitude": float(lat) if lat is not None else None,
        "longitude": float(lng) if lng is not None else None,
        "accuracy": float(r.get("accuracy")) if r.get("accuracy") is not None else None,
        "photo_path": photo_path,
        "photo_url": photo_url,
        "map_url": map_url,
        "checkin_at": str(r.get("checkin_at") or ""),
        "created_at": str(r.get("created_at") or ""),
    }


@mobile_attendance_bp.route("/attendance", methods=["GET"])
@mobile_required
def api_mobile_attendance_list():
    user_id = request.user["user_id"]
    role = request.user["role"]

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        if role == "admin":
            cur.execute("""
                SELECT
                    a.id,
                    a.user_id,
                    u.name AS user_name,
                    a.work_date,
                    a.status,
                    a.arrival_type,
                    a.note,
                    a.device_id,
                    a.latitude,
                    a.longitude,
                    a.accuracy,
                    a.photo_path,
                    a.map_url,
                    a.checkin_at,
                    a.created_at
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
                    a.device_id,
                    a.latitude,
                    a.longitude,
                    a.accuracy,
                    a.photo_path,
                    a.map_url,
                    a.checkin_at,
                    a.created_at
                FROM attendance a
                LEFT JOIN users u ON u.id = a.user_id
                WHERE a.user_id = %s
                ORDER BY a.work_date DESC, a.id DESC
                LIMIT 100;
            """, (user_id,))
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return jsonify({
        "ok": True,
        "data": {
            "attendance": [_row_to_attendance_dict(r) for r in rows]
        }
    })


@mobile_attendance_bp.route("/attendance/me", methods=["GET"])
@mobile_required
def api_mobile_attendance_me():
    user_id = request.user["user_id"]

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
                a.device_id,
                a.latitude,
                a.longitude,
                a.accuracy,
                a.photo_path,
                a.map_url,
                a.checkin_at,
                a.created_at
            FROM attendance a
            LEFT JOIN users u ON u.id = a.user_id
            WHERE a.user_id = %s
            ORDER BY a.work_date DESC, a.id DESC
            LIMIT 100;
        """, (user_id,))
        rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    return jsonify({
        "ok": True,
        "data": {
            "attendance": [_row_to_attendance_dict(r) for r in rows]
        }
    })


@mobile_attendance_bp.route("/attendance", methods=["POST"])
@mobile_required
def api_mobile_submit_attendance():
    user_id = request.user["user_id"]

    attendance_type = (request.form.get("attendance_type") or "ONTIME").strip().upper()
    note = (request.form.get("note") or "").strip()
    latitude = _to_float(request.form.get("latitude"))
    longitude = _to_float(request.form.get("longitude"))
    accuracy = _to_float(request.form.get("accuracy"))
    device_id = (request.form.get("device_id") or "android").strip()
    selfie = request.files.get("selfie")

    if latitude is None or longitude is None:
        return jsonify({"ok": False, "message": "Latitude dan longitude wajib diisi"}), 400

    if selfie is None:
        return jsonify({"ok": False, "message": "Selfie wajib diupload"}), 400

    os.makedirs("static/uploads/attendance_user", exist_ok=True)
    filename = f"att_mobile_{date.today()}_{uuid.uuid4().hex}.jpg"
    save_path = os.path.join("static/uploads/attendance_user", filename)
    selfie.save(save_path)
    photo_path = f"uploads/attendance_user/{filename}"

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT id, name FROM users WHERE id=%s LIMIT 1;", (user_id,))
        user = cur.fetchone()
        if not user:
            return jsonify({"ok": False, "message": "User tidak ditemukan"}), 404

        cur.execute("""
            INSERT INTO attendance_pending
            (user_id, work_date, arrival_type, note, name_input,
             device_id, latitude, longitude, accuracy, photo_path,
             ip_address, status, created_at)
            VALUES
            (%s, CURRENT_DATE, %s, %s, %s,
             %s, %s, %s, %s, %s,
             %s, 'PENDING', CURRENT_TIMESTAMP)
            RETURNING id;
        """, (
            user_id,
            attendance_type,
            note,
            user["name"],
            device_id,
            latitude,
            longitude,
            accuracy,
            photo_path,
            request.remote_addr
        ))
        row = cur.fetchone()
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return jsonify({
        "ok": True,
        "message": "Absensi berhasil dikirim",
        "data": {
            "pending_id": row["id"]
        }
    })


@mobile_attendance_bp.route("/attendance/pending", methods=["GET"])
@mobile_required
def api_mobile_pending_attendance():
    role = request.user["role"]
    if role != "admin":
        return jsonify({"ok": False, "message": "Forbidden"}), 403

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                id,
                user_id,
                name_input,
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
    finally:
        cur.close()
        conn.close()

    data = []
    for r in rows:
        photo_path = r.get("photo_path") or ""
        photo_url = ""
        if photo_path:
            photo_url = request.host_url.rstrip("/") + "/static/" + photo_path

        lat = r.get("latitude")
        lng = r.get("longitude")
        map_url = ""
        if lat is not None and lng is not None:
            map_url = f"https://www.google.com/maps?q={lat},{lng}"

        data.append({
            "id": r["id"],
            "user_id": r.get("user_id"),
            "name_input": r.get("name_input") or "",
            "work_date": str(r.get("work_date") or ""),
            "arrival_type": r.get("arrival_type") or "",
            "note": r.get("note") or "",
            "device_id": r.get("device_id") or "",
            "latitude": float(lat) if lat is not None else None,
            "longitude": float(lng) if lng is not None else None,
            "accuracy": float(r.get("accuracy")) if r.get("accuracy") is not None else None,
            "photo_path": photo_path,
            "photo_url": photo_url,
            "map_url": map_url,
            "created_at": str(r.get("created_at") or ""),
        })

    return jsonify({
        "ok": True,
        "data": {
            "attendance": data
        }
    })


@mobile_attendance_bp.route("/attendance/pending/<int:pending_id>/approve", methods=["POST"])
@mobile_required
def api_mobile_approve_pending_attendance(pending_id):
    role = request.user["role"]
    admin_id = request.user["user_id"]
    if role != "admin":
        return jsonify({"ok": False, "message": "Forbidden"}), 403

    data = request.get_json(silent=True) or {}
    fallback_user_id = data.get("user_id")

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
            return jsonify({"ok": False, "message": "Data pending tidak ditemukan"}), 404

        target_user_id = p.get("user_id") or fallback_user_id
        if not target_user_id:
            return jsonify({"ok": False, "message": "user_id tidak ditemukan"}), 400

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

        lat = p.get("latitude")
        lng = p.get("longitude")
        map_url = f"https://www.google.com/maps?q={lat},{lng}" if lat is not None and lng is not None else None

        cur.execute("""
            UPDATE attendance_pending
            SET status='APPROVED',
                approved_user_id=%s,
                approved_by=%s,
                approved_at=CURRENT_TIMESTAMP
            WHERE id=%s;
        """, (target_user_id, admin_id, pending_id))

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
            p.get("work_date"),
            status,
            arrival_type,
            p.get("note"),
            p.get("created_at"),
            p.get("device_id"),
            lat,
            lng,
            p.get("accuracy"),
            p.get("photo_path"),
            map_url
        ))

        conn.commit()
    finally:
        cur.close()
        conn.close()

    return jsonify({"ok": True, "message": "Absensi berhasil disetujui"})


@mobile_attendance_bp.route("/attendance/pending/<int:pending_id>/reject", methods=["POST"])
@mobile_required
def api_mobile_reject_pending_attendance(pending_id):
    role = request.user["role"]
    admin_id = request.user["user_id"]
    if role != "admin":
        return jsonify({"ok": False, "message": "Forbidden"}), 403

    data = request.get_json(silent=True) or {}
    reason = (data.get("reason") or "").strip()

    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            UPDATE attendance_pending
            SET status='REJECTED',
                rejected_by=%s,
                rejected_at=CURRENT_TIMESTAMP,
                reject_reason=%s
            WHERE id=%s;
        """, (admin_id, reason, pending_id))
        conn.commit()
    finally:
        cur.close()
        conn.close()

    return jsonify({"ok": True, "message": "Absensi berhasil ditolak"})

"""
routes/mobile/biofinger.py
Webhook dari VPS bridge → mesin fingerprint BioFinger TM-501.
Flow: Mesin → VPS TCP Bridge → POST ke endpoint ini → Simpan DB + FCM
"""
from datetime import datetime
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_response, _safe_int

biofinger_bp = Blueprint("biofinger", __name__)


# ── FCM helpers (lazy import, jalan di thread terpisah) ──────────────

def _get_user_fcm_tokens(user_id: int) -> list:
    try:
        conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
        try:
            cur.execute("""
                SELECT fcm_token FROM mobile_device_tokens
                WHERE user_id=%s AND is_active=TRUE
                  AND COALESCE(fcm_token,'') <> '';
            """, (user_id,))
            return [r["fcm_token"] for r in cur.fetchall()]
        finally:
            cur.close(); conn.close()
    except Exception:
        return []


def _notify_fp(user_id: int, user_name: str, action: str, time_str: str):
    """
    Kirim FCM ke:
    - Admin  : ada check-in/out fingerprint karyawan
    - Karyawan: konfirmasi absensi fingerprint berhasil tercatat
    Dijalankan di background thread agar tidak blocking webhook.
    """
    import threading

    def _send():
        try:
            from core import get_admin_fcm_tokens, send_fcm_to_tokens

            is_ci  = (action == "Check-in")
            emoji  = "✅" if is_ci else "👋"
            action_id = "attendance_checkin" if is_ci else "attendance_checkout"

            # ── Notif ke ADMIN ───────────────────────────────────
            admin_tokens = get_admin_fcm_tokens()
            if admin_tokens:
                send_fcm_to_tokens(
                    admin_tokens,
                    title=f"{emoji} Fingerprint — {user_name}",
                    body=f"{user_name} {action.lower()} via fingerprint pukul {time_str}",
                    data={
                        "type":      "fingerprint",
                        "action":    action,
                        "screen":    "attendance_history",
                        "user_id":   str(user_id),
                        "time":      time_str,
                    }
                )

            # ── Notif ke KARYAWAN ────────────────────────────────
            emp_tokens = _get_user_fcm_tokens(user_id)
            if emp_tokens:
                if is_ci:
                    title = "✅ Check-in Tercatat"
                    body  = f"Check-in kamu pukul {time_str} berhasil direkam via fingerprint."
                else:
                    title = "👋 Check-out Tercatat"
                    body  = f"Check-out kamu pukul {time_str} berhasil direkam via fingerprint."

                send_fcm_to_tokens(
                    emp_tokens,
                    title=title,
                    body=body,
                    data={
                        "type":   action_id,
                        "screen": "attendance_history",
                        "time":   time_str,
                    }
                )
        except Exception as ex:
            print(f"[FCM biofinger] {ex}")

    threading.Thread(target=_send, daemon=True).start()


def _notify_fp_wa(user_id: int, user_name: str, action: str, time_str: str):
    """
    Kirim WA ke semua admin & owner saat fingerprint check-in/out.
    Dijalankan di background thread terpisah.
    """
    import threading, requests as _req

    def _send_wa():
        try:
            WA_BOT_URL = "http://13.140.161.156:3000/send"

            # Ambil nomor HP admin & owner
            conn = get_conn()
            cur  = conn.cursor(cursor_factory=RealDictCursor)
            cur.execute("""
                SELECT phone FROM users
                WHERE role IN ('admin', 'owner')
                  AND COALESCE(phone, '') != '';
            """)
            phones = [r["phone"] for r in cur.fetchall()]
            cur.close(); conn.close()

            if not phones:
                return

            is_ci  = (action == "Check-in")
            emoji  = "✅" if is_ci else "👋"
            label  = "Check-in" if is_ci else "Check-out"

            message = (
                f"{emoji} *Fingerprint {label}*\n\n"
                f"👤 Karyawan: {user_name}\n"
                f"🕐 Waktu: {time_str}\n"
                f"📟 Via: Mesin Fingerprint Gudang\n\n"
                f"_UMGAP — Sistem Manajemen Karyawan_"
            )

            for phone in phones:
                try:
                    # Normalisasi: 0xxx → 62xxx
                    num = phone.strip().replace(" ", "")
                    if num.startswith("0"):
                        num = "62" + num[1:]
                    _req.post(
                        WA_BOT_URL,
                        json={"phone": num, "message": message},
                        timeout=5
                    )
                except Exception as e:
                    print(f"[WA biofinger] Gagal kirim ke {phone}: {e}")

        except Exception as ex:
            print(f"[WA biofinger] Error: {ex}")

    threading.Thread(target=_send_wa, daemon=True).start()


# ── Schema ───────────────────────────────────────────────────────────

def _ensure_schema():
    conn = get_conn(); cur = conn.cursor()
    try:
        cur.execute("ALTER TABLE attendance ADD COLUMN IF NOT EXISTS check_in  TIMESTAMP;")
        cur.execute("ALTER TABLE attendance ADD COLUMN IF NOT EXISTS check_out TIMESTAMP;")
        cur.execute("ALTER TABLE attendance ADD COLUMN IF NOT EXISTS note TEXT DEFAULT '';")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS biofinger_mappings (
                id         SERIAL PRIMARY KEY,
                pin_mesin  VARCHAR(50)  NOT NULL UNIQUE,
                user_id    INTEGER      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                snmesin    VARCHAR(100) DEFAULT '',
                nama_mesin VARCHAR(100) DEFAULT '',
                is_active  BOOLEAN      NOT NULL DEFAULT TRUE,
                created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS biofinger_logs (
                id             SERIAL PRIMARY KEY,
                tran_id        VARCHAR(100) UNIQUE,
                pin_mesin      VARCHAR(50),
                disp_nm        VARCHAR(100),
                snmesin        VARCHAR(100),
                tran_dt        TIMESTAMP,
                stateid        VARCHAR(10) DEFAULT '0',
                verify         VARCHAR(10) DEFAULT '0',
                workcod        VARCHAR(50) DEFAULT '',
                mapped_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
                status         VARCHAR(20) DEFAULT 'PENDING',
                notes          TEXT DEFAULT '',
                received_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
    finally:
        cur.close(); conn.close()


def _parse_tran_dt(s: str):
    try:    return datetime.strptime(s.strip()[:19], "%Y-%m-%d %H:%M:%S")
    except: return datetime.now()

def _is_checkin(stateid: str) -> bool:
    return str(stateid) in ("0", "4")


# ── Webhook utama ─────────────────────────────────────────────────────

@biofinger_bp.route("/biofinger/webhook", methods=["POST", "GET", "OPTIONS"])
def biofinger_webhook():
    if request.method in ("GET", "OPTIONS"):
        return mobile_api_response(ok=True,
            message="UMGAP BioFinger Webhook Active", data={}, status_code=200)

    _ensure_schema()

    payload     = request.get_json(silent=True) or {}
    tran_id     = payload.get("tran_id", "")
    snmesin     = payload.get("snmesin", "")
    tran_dt_str = payload.get("tran_dt", "")
    pin_mesin   = str(payload.get("user_id", "")).strip()
    disp_nm     = payload.get("disp_nm", "")
    stateid     = str(payload.get("stateid", "0")).strip()
    verify      = str(payload.get("verify", "0")).strip()
    workcod     = payload.get("workcod", "") or ""

    if not pin_mesin:
        return mobile_api_response(ok=False, message="user_id kosong",
                                   data={}, status_code=400)

    tran_dt   = _parse_tran_dt(tran_dt_str)
    work_date = tran_dt.date()

    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Cek duplikat tran_id
        if tran_id:
            cur.execute("SELECT id, status FROM biofinger_logs WHERE tran_id=%s LIMIT 1;",
                        (tran_id,))
            existing = cur.fetchone()
            if existing:
                return mobile_api_response(ok=True, message="Sudah diproses.",
                    data={"status": existing["status"]}, status_code=200)

        # Cari mapping PIN → user
        cur.execute("""
            SELECT bm.user_id, u.name AS user_name
            FROM biofinger_mappings bm
            JOIN users u ON u.id = bm.user_id
            WHERE bm.pin_mesin=%s AND bm.is_active=TRUE LIMIT 1;
        """, (pin_mesin,))
        mapping = cur.fetchone()

        if not mapping:
            cur.execute("""
                INSERT INTO biofinger_logs
                    (tran_id, pin_mesin, disp_nm, snmesin, tran_dt,
                     stateid, verify, workcod, status, notes)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'UNMAPPED','PIN belum di-mapping')
                ON CONFLICT (tran_id) DO NOTHING;
            """, (tran_id or None, pin_mesin, disp_nm, snmesin, tran_dt,
                  stateid, verify, workcod))
            conn.commit()
            return mobile_api_response(ok=True,
                message=f"PIN {pin_mesin} ({disp_nm}) belum di-mapping.",
                data={"pin": pin_mesin, "nama": disp_nm}, status_code=200)

        user_id   = mapping["user_id"]
        user_name = mapping["user_name"]
        is_ci     = _is_checkin(stateid)

        # Cek attendance hari ini
        cur.execute("""
            SELECT id, check_in, check_out FROM attendance
            WHERE user_id=%s AND work_date=%s LIMIT 1;
        """, (user_id, work_date))
        att = cur.fetchone()

        if is_ci:
            if att:
                cur.execute("""
                    UPDATE attendance SET
                        check_in = LEAST(COALESCE(check_in,%s), %s),
                        checkin_at = LEAST(COALESCE(checkin_at,%s), %s),
                        note     = CONCAT(COALESCE(note,''), ' | FP-in:', %s)
                    WHERE id=%s;
                """, (tran_dt, tran_dt, tran_dt, tran_dt, tran_dt_str, att["id"]))
            else:
                cur.execute("""
                    INSERT INTO attendance
                        (user_id, work_date, check_in, checkin_at,
                         status, arrival_type, note)
                    VALUES (%s,%s,%s,%s,'PRESENT','ONTIME',%s)
                    ON CONFLICT (user_id, work_date) DO UPDATE SET
                        check_in   = LEAST(COALESCE(attendance.check_in,EXCLUDED.check_in), EXCLUDED.check_in),
                        checkin_at = LEAST(COALESCE(attendance.checkin_at,EXCLUDED.checkin_at), EXCLUDED.checkin_at),
                        arrival_type = 'ONTIME',
                        note = CONCAT(COALESCE(attendance.note,''), ' | FP-in:', %s);
                """, (user_id, work_date, tran_dt, tran_dt,
                      f"Check-in fingerprint {tran_dt_str}", tran_dt_str))
        else:
            if att:
                cur.execute("""
                    UPDATE attendance SET
                        check_out = GREATEST(COALESCE(check_out,%s), %s),
                        note      = CONCAT(COALESCE(note,''), ' | FP-out:', %s)
                    WHERE id=%s;
                """, (tran_dt, tran_dt, tran_dt_str, att["id"]))
            else:
                cur.execute("""
                    INSERT INTO attendance
                        (user_id, work_date, check_in, check_out, checkin_at,
                         status, arrival_type, note)
                    VALUES (%s,%s,%s,%s,%s,'PRESENT','ONTIME',%s)
                    ON CONFLICT (user_id, work_date) DO UPDATE SET
                        check_out = GREATEST(COALESCE(attendance.check_out,EXCLUDED.check_out), EXCLUDED.check_out),
                        note = CONCAT(COALESCE(attendance.note,''), ' | FP-out:', %s);
                """, (user_id, work_date, tran_dt, tran_dt, tran_dt,
                      f"Check-out fingerprint {tran_dt_str}", tran_dt_str))

        # Catat log
        action = "Check-in" if is_ci else "Check-out"
        cur.execute("""
            INSERT INTO biofinger_logs
                (tran_id, pin_mesin, disp_nm, snmesin, tran_dt,
                 stateid, verify, workcod, mapped_user_id, status, notes)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,'RECORDED',%s)
            ON CONFLICT (tran_id) DO NOTHING;
        """, (tran_id or None, pin_mesin, disp_nm, snmesin, tran_dt,
              stateid, verify, workcod, user_id,
              f"{action} fingerprint"))

        conn.commit()

        # ── FCM ke admin + karyawan (background thread) ──────────
        _notify_fp(user_id, user_name, action, tran_dt_str)
        _notify_fp_wa(user_id, user_name, action, tran_dt_str)

        return mobile_api_response(ok=True,
            message=f"{action} {user_name} berhasil ({tran_dt_str})",
            data={"user_id": user_id, "user_name": user_name,
                  "action": action, "time": tran_dt_str}, status_code=200)

    except Exception as e:
        conn.rollback()
        print(f"[BioFinger ERROR] {e}")
        return mobile_api_response(ok=True, message=f"Error: {str(e)}",
                                   data={}, status_code=200)
    finally:
        cur.close(); conn.close()


# ── Unmapped list ─────────────────────────────────────────────────────

@biofinger_bp.route("/biofinger/unmapped", methods=["GET", "OPTIONS"])
def biofinger_unmapped():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)
    _ensure_schema()
    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT pin_mesin, disp_nm, snmesin,
                   MAX(tran_dt) AS last_scan, COUNT(*) AS scan_count
            FROM biofinger_logs WHERE status='UNMAPPED'
            GROUP BY pin_mesin, disp_nm, snmesin ORDER BY last_scan DESC;
        """)
        rows = [dict(r) for r in cur.fetchall()]
        for r in rows:
            if r.get("last_scan"):
                r["last_scan"] = r["last_scan"].strftime("%Y-%m-%d %H:%M:%S")
        return mobile_api_response(ok=True, message="OK",
                                   data={"unmapped": rows}, status_code=200)
    finally:
        cur.close(); conn.close()


# ── CRUD Mapping ──────────────────────────────────────────────────────

@biofinger_bp.route("/biofinger/mapping", methods=["GET", "POST", "DELETE", "OPTIONS"])
def biofinger_mapping():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)
    _ensure_schema()
    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        if request.method == "GET":
            cur.execute("""
                SELECT bm.id, bm.pin_mesin, bm.nama_mesin, bm.snmesin,
                       bm.is_active, bm.created_at,
                       u.id AS user_id, u.name AS user_name, u.email
                FROM biofinger_mappings bm
                JOIN users u ON u.id = bm.user_id ORDER BY u.name ASC;
            """)
            rows = [dict(r) for r in cur.fetchall()]
            for r in rows:
                if r.get("created_at"):
                    r["created_at"] = r["created_at"].strftime("%Y-%m-%d %H:%M:%S")
            cur.execute("""
                SELECT u.id, u.name, u.email FROM users u
                WHERE u.role='employee'
                  AND u.id NOT IN (SELECT user_id FROM biofinger_mappings WHERE is_active=TRUE)
                ORDER BY u.name ASC;
            """)
            unmapped_users = [dict(r) for r in cur.fetchall()]
            return mobile_api_response(ok=True, message="OK",
                data={"mappings": rows, "unmapped_users": unmapped_users}, status_code=200)

        elif request.method == "POST":
            data       = request.get_json(silent=True) or {}
            pin_mesin  = str(data.get("pin_mesin","")).strip()
            user_id    = _safe_int(data.get("user_id"), 0)
            nama_mesin = data.get("nama_mesin","") or ""
            snmesin    = data.get("snmesin","") or ""
            if not pin_mesin or not user_id:
                return mobile_api_response(ok=False,
                    message="pin_mesin dan user_id wajib diisi",
                    data={}, status_code=400)
            cur.execute("""
                INSERT INTO biofinger_mappings (pin_mesin, user_id, nama_mesin, snmesin)
                VALUES (%s,%s,%s,%s)
                ON CONFLICT (pin_mesin) DO UPDATE SET
                    user_id=EXCLUDED.user_id, nama_mesin=EXCLUDED.nama_mesin,
                    snmesin=EXCLUDED.snmesin, is_active=TRUE,
                    updated_at=CURRENT_TIMESTAMP
                RETURNING id;
            """, (pin_mesin, user_id, nama_mesin, snmesin))
            row = cur.fetchone()
            cur.execute("""
                UPDATE biofinger_logs SET status='REMAPPED', mapped_user_id=%s
                WHERE pin_mesin=%s AND status='UNMAPPED';
            """, (user_id, pin_mesin))
            conn.commit()
            return mobile_api_response(ok=True, message="Mapping berhasil disimpan.",
                                       data={"id": row["id"]}, status_code=200)

        elif request.method == "DELETE":
            data       = request.get_json(silent=True) or {}
            mapping_id = _safe_int(data.get("id"), 0)
            if not mapping_id:
                return mobile_api_response(ok=False, message="id wajib diisi",
                                           data={}, status_code=400)
            cur.execute("""
                UPDATE biofinger_mappings SET is_active=FALSE, updated_at=CURRENT_TIMESTAMP
                WHERE id=%s RETURNING id;
            """, (mapping_id,))
            row = cur.fetchone()
            conn.commit()
            if not row:
                return mobile_api_response(ok=False, message="Mapping tidak ditemukan",
                                           data={}, status_code=404)
            return mobile_api_response(ok=True, message="Mapping dihapus.",
                                       data={}, status_code=200)
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), data={}, status_code=500)
    finally:
        cur.close(); conn.close()


# ══════════════════════════════════════════════════════════════
#  ENDPOINT: /api/biofinger/push
#  Menerima data raw dari VPS bridge (ZKTeco binary)
#  Parse PIN + timestamp lalu teruskan ke webhook logic
# ══════════════════════════════════════════════════════════════
@biofinger_bp.route("/biofinger/push", methods=["POST", "OPTIONS"])
def biofinger_push():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    _ensure_schema()
    payload    = request.get_json(silent=True) or {}
    raw_hex    = (payload.get("raw_hex") or "").strip()
    source_ip  = payload.get("source_ip", "")
    recv_at    = payload.get("received_at", "")

    if not raw_hex:
        return mobile_api_response(ok=False, message="raw_hex kosong", data={}, status_code=400)

    try:
        raw = bytes.fromhex(raw_hex)
    except Exception:
        return mobile_api_response(ok=False, message="raw_hex tidak valid", data={}, status_code=400)

    # ── Parse ZKTeco RTLOG binary ──────────────────────────────
    # Format ZKTeco ADMS TCP push:
    # Byte 0   : command (0x81 = RTLOG)
    # Byte 1   : flags
    # Byte 2-3 : length (big-endian)
    # Byte 4+  : payload (XOR encoded dengan key 0x49)
    records = []
    try:
        if len(raw) >= 4 and raw[0] == 0x81:
            # Decode XOR dengan key dari byte ke-3
            key     = raw[3]
            payload_bytes = bytearray()
            for i, b in enumerate(raw[4:]):
                payload_bytes.append(b ^ key ^ i % 256)

            # Coba parse sebagai string untuk cari PIN dan timestamp
            text = payload_bytes.decode('utf-8', errors='ignore')
            import re

            # Cari pola PIN (1-9 digit) dan timestamp
            # ZKTeco attendance log format: PIN	timestamp	type	verify
            lines = text.replace('\r', ' ').replace('\t', ' ').split('\n')
            for i, token in enumerate(lines):
                token = token.strip()
                # PIN biasanya angka 1-9 digit
                if re.match(r"^[0-9]{1,9}$", token) and len(token) >= 1:
                    # Cari timestamp di sekitarnya
                    ts_str = None
                    for j in range(max(0, i-3), min(len(lines), i+4)):
                        t = lines[j].strip()
                        if re.match(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", t):
                            ts_str = t[:19]
                            break
                        if re.match(r"[0-9]{14}", t):  # YYYYMMDDHHmmss
                            ts_str = f"{t[:4]}-{t[4:6]}-{t[6:8]} {t[8:10]}:{t[10:12]}:{t[12:14]}"
                            break

                    if not ts_str:
                        ts_str = recv_at[:19] if recv_at else datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")

                    records.append({"pin": token, "tran_dt": ts_str})
    except Exception as parse_err:
        print(f"[BIO PUSH] Parse error: {parse_err}")

    # Kalau tidak bisa parse, simpan sebagai raw log untuk debug
    if not records:
        conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
        try:
            tran_id = f"RAW_{source_ip}_{recv_at[:19].replace(' ','_').replace(':','')}_{raw_hex[:8]}"
            cur.execute("""
                INSERT INTO biofinger_logs
                    (tran_id, pin_mesin, disp_nm, snmesin, tran_dt,
                     stateid, verify, workcod, status, notes)
                VALUES (%s,'RAW','','', NOW(),'0','0','','UNMAPPED','Raw binary - belum bisa parse PIN')
                ON CONFLICT (tran_id) DO NOTHING;
            """, (tran_id,))
            conn.commit()
        except Exception:
            conn.rollback()
        finally:
            cur.close(); conn.close()

        return mobile_api_response(ok=True, message="Diterima tapi PIN belum bisa diparsing.",
                                   data={"raw_len": len(raw), "records": 0}, status_code=200)

    # ── Proses setiap record yang berhasil di-parse ─────────────
    processed = 0
    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        for rec in records:
            pin_mesin = str(rec["pin"]).strip()
            tran_dt   = _parse_tran_dt(rec["tran_dt"])
            tran_id   = f"PUSH_{pin_mesin}_{tran_dt.strftime('%Y%m%d%H%M%S')}"

            # Cek duplikat
            cur.execute("SELECT id FROM biofinger_logs WHERE tran_id=%s LIMIT 1;", (tran_id,))
            if cur.fetchone():
                continue

            # Cari mapping PIN → user
            cur.execute("""
                SELECT bm.user_id, u.name AS user_name
                FROM biofinger_mappings bm
                JOIN users u ON u.id = bm.user_id
                WHERE bm.pin_mesin=%s AND bm.is_active=TRUE LIMIT 1;
            """, (pin_mesin,))
            mapping = cur.fetchone()

            if not mapping:
                cur.execute("""
                    INSERT INTO biofinger_logs
                        (tran_id, pin_mesin, disp_nm, snmesin, tran_dt,
                         stateid, verify, workcod, status, notes)
                    VALUES (%s,%s,'','', %s,'0','0','','UNMAPPED','PIN belum di-mapping')
                    ON CONFLICT (tran_id) DO NOTHING;
                """, (tran_id, pin_mesin, tran_dt))
                conn.commit()
                continue

            user_id   = mapping["user_id"]
            work_date = tran_dt.date()

            # Insert log
            cur.execute("""
                INSERT INTO biofinger_logs
                    (tran_id, pin_mesin, disp_nm, snmesin, tran_dt, mapped_user_id,
                     stateid, verify, workcod, status, notes)
                VALUES (%s,%s,%s,'', %s,%s,'0','0','','PROCESSED','Via VPS push')
                ON CONFLICT (tran_id) DO NOTHING;
            """, (tran_id, pin_mesin, mapping["user_name"], tran_dt, user_id))

            # Upsert attendance
            cur.execute("""
                INSERT INTO attendance
                    (user_id, work_date, status, arrival_type, note, checkin_at)
                VALUES (%s, %s, 'PRESENT', 'ONTIME', 'Via fingerprint', %s)
                ON CONFLICT (user_id, work_date)
                DO UPDATE SET
                    checkin_at = LEAST(attendance.checkin_at, EXCLUDED.checkin_at);
            """, (user_id, work_date, tran_dt))

            conn.commit()
            processed += 1
            print(f"[BIO PUSH] Processed PIN {pin_mesin} → user {user_id} at {tran_dt}")
    except Exception as e:
        conn.rollback()
        print(f"[BIO PUSH] DB error: {e}")
    finally:
        cur.close(); conn.close()

    return mobile_api_response(
        ok=True,
        message=f"Berhasil proses {processed} dari {len(records)} record.",
        data={"records_found": len(records), "processed": processed},
        status_code=200
    )

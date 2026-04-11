"""
routes/mobile/biofinger.py

Endpoint webhook - menerima data absensi dari VPS bridge
yang terhubung ke mesin fingerprint BioFinger TM-501.

Flow:
  Mesin → VPS TCP Bridge → POST ke endpoint ini → Simpan ke DB
"""

from datetime import datetime
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_response, _safe_int

# FCM - import lazy agar tidak error jika belum setup
def _notify_admin_fp(pin, user_name, action, time_str):
    try:
        from core import get_admin_fcm_tokens, send_fcm_to_tokens
        import threading
        def _send():
            try:
                tokens = get_admin_fcm_tokens()
                if not tokens: return
                emoji = "✅" if action == "Check-in" else "👋"
                send_fcm_to_tokens(tokens,
                    f"{emoji} Fingerprint — {user_name}",
                    f"{user_name} {action.lower()} via fingerprint pukul {time_str}",
                    {"type": "fingerprint", "action": action})
            except Exception as ex:
                print(f"[FCM] {ex}")
        threading.Thread(target=_send, daemon=True).start()
    except Exception as e:
        print(f"[FCM import] {e}")

biofinger_bp = Blueprint("biofinger", __name__)


# ── Buat tabel jika belum ada ─────────────────────────────────────

def _ensure_schema():
    conn = get_conn()
    cur  = conn.cursor()
    try:
        # Pastikan kolom attendance tersedia
        cur.execute("""
            ALTER TABLE attendance
            ADD COLUMN IF NOT EXISTS check_in  TIMESTAMP;
        """)
        cur.execute("""
            ALTER TABLE attendance
            ADD COLUMN IF NOT EXISTS check_out TIMESTAMP;
        """)
        cur.execute("""
            ALTER TABLE attendance
            ADD COLUMN IF NOT EXISTS note TEXT DEFAULT '';
        """)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS biofinger_mappings (
                id          SERIAL PRIMARY KEY,
                pin_mesin   VARCHAR(50)  NOT NULL UNIQUE,
                user_id     INTEGER      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                snmesin     VARCHAR(100) DEFAULT '',
                nama_mesin  VARCHAR(100) DEFAULT '',
                is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
                created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
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
        cur.close()
        conn.close()


def _parse_tran_dt(s: str):
    try:
        return datetime.strptime(s.strip()[:19], "%Y-%m-%d %H:%M:%S")
    except Exception:
        return datetime.now()


def _is_checkin(stateid: str) -> bool:
    return str(stateid) in ("0", "4")


# ── Webhook utama ─────────────────────────────────────────────────

@biofinger_bp.route("/biofinger/webhook", methods=["POST", "GET", "OPTIONS"])
def biofinger_webhook():
    if request.method in ("GET", "OPTIONS"):
        return mobile_api_response(ok=True, message="UMGAP BioFinger Webhook Active", data={}, status_code=200)

    _ensure_schema()

    payload     = request.get_json(silent=True) or {}
    biohook     = payload.get("biohook", "sdatareco")
    tran_id     = payload.get("tran_id", "")
    snmesin     = payload.get("snmesin", "")
    tran_dt_str = payload.get("tran_dt", "")
    pin_mesin   = str(payload.get("user_id", "")).strip()
    disp_nm     = payload.get("disp_nm", "")
    stateid     = str(payload.get("stateid", "0")).strip()
    verify      = str(payload.get("verify", "0")).strip()
    workcod     = payload.get("workcod", "") or ""

    if not pin_mesin:
        return mobile_api_response(ok=False, message="user_id kosong", data={}, status_code=400)

    tran_dt   = _parse_tran_dt(tran_dt_str)
    work_date = tran_dt.date()

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Cek duplikat
        if tran_id:
            cur.execute("SELECT id, status FROM biofinger_logs WHERE tran_id = %s LIMIT 1;", (tran_id,))
            existing = cur.fetchone()
            if existing:
                return mobile_api_response(ok=True, message="Sudah diproses.",
                                           data={"status": existing["status"]}, status_code=200)

        # Cari mapping PIN → user
        cur.execute("""
            SELECT bm.user_id, u.name AS user_name
            FROM biofinger_mappings bm
            JOIN users u ON u.id = bm.user_id
            WHERE bm.pin_mesin = %s AND bm.is_active = TRUE
            LIMIT 1;
        """, (pin_mesin,))
        mapping = cur.fetchone()

        if not mapping:
            # Simpan sebagai UNMAPPED
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
            WHERE user_id = %s AND work_date = %s LIMIT 1;
        """, (user_id, work_date))
        att = cur.fetchone()

        if is_ci:
            if att:
                cur.execute("""
                    UPDATE attendance SET
                        check_in = LEAST(check_in, %s),
                        note     = CONCAT(COALESCE(note,''), ' | FP-in:', %s)
                    WHERE id = %s;
                """, (tran_dt, tran_dt_str, att["id"]))
            else:
                cur.execute("""
                    INSERT INTO attendance
                        (user_id, work_date, check_in, status, arrival_type, note)
                    VALUES (%s,%s,%s,'PRESENT','ONTIME',%s)
                    ON CONFLICT (user_id, work_date) DO UPDATE
                    SET check_in     = LEAST(attendance.check_in, EXCLUDED.check_in),
                        arrival_type = 'ONTIME',
                        note         = CONCAT(COALESCE(attendance.note,''), ' | FP-in:', %s);
                """, (user_id, work_date, tran_dt,
                      f"Check-in fingerprint {tran_dt_str}", tran_dt_str))
        else:
            if att:
                cur.execute("""
                    UPDATE attendance SET
                        check_out = GREATEST(COALESCE(check_out,%s), %s),
                        note      = CONCAT(COALESCE(note,''), ' | FP-out:', %s)
                    WHERE id = %s;
                """, (tran_dt, tran_dt, tran_dt_str, att["id"]))
            else:
                cur.execute("""
                    INSERT INTO attendance
                        (user_id, work_date, check_in, check_out, status, arrival_type, note)
                    VALUES (%s,%s,%s,%s,'PRESENT','ONTIME',%s)
                    ON CONFLICT (user_id, work_date) DO UPDATE
                    SET check_out = GREATEST(COALESCE(attendance.check_out,EXCLUDED.check_out), EXCLUDED.check_out),
                        note      = CONCAT(COALESCE(attendance.note,''), ' | FP-out:', %s);
                """, (user_id, work_date, tran_dt, tran_dt,
                      f"Check-out fingerprint {tran_dt_str}", tran_dt_str))

        # Catat log
        cur.execute("""
            INSERT INTO biofinger_logs
                (tran_id, pin_mesin, disp_nm, snmesin, tran_dt,
                 stateid, verify, workcod, mapped_user_id, status, notes)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,'RECORDED',%s)
            ON CONFLICT (tran_id) DO NOTHING;
        """, (tran_id or None, pin_mesin, disp_nm, snmesin, tran_dt,
              stateid, verify, workcod, user_id,
              f"{'Check-in' if is_ci else 'Check-out'} fingerprint"))

        conn.commit()
        action = "Check-in" if is_ci else "Check-out"
        # Kirim FCM ke admin (background)
        _notify_admin_fp(pin_mesin, user_name, action, tran_dt_str)
        return mobile_api_response(ok=True,
            message=f"{action} {user_name} berhasil ({tran_dt_str})",
            data={"user_id": user_id, "user_name": user_name,
                  "action": action, "time": tran_dt_str}, status_code=200)

    except Exception as e:
        conn.rollback()
        print(f"[BioFinger ERROR] {e}")
        return mobile_api_response(ok=True, message=f"Error: {str(e)}", data={}, status_code=200)
    finally:
        cur.close()
        conn.close()


# ── List PIN belum di-mapping ─────────────────────────────────────

@biofinger_bp.route("/biofinger/unmapped", methods=["GET", "OPTIONS"])
def biofinger_unmapped():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    _ensure_schema()
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT pin_mesin, disp_nm, snmesin,
                   MAX(tran_dt) AS last_scan,
                   COUNT(*) AS scan_count
            FROM biofinger_logs
            WHERE status = 'UNMAPPED'
            GROUP BY pin_mesin, disp_nm, snmesin
            ORDER BY last_scan DESC;
        """)
        rows = [dict(r) for r in cur.fetchall()]
        for r in rows:
            if r.get("last_scan"):
                r["last_scan"] = r["last_scan"].strftime("%Y-%m-%d %H:%M:%S")
        return mobile_api_response(ok=True, message="OK",
                                   data={"unmapped": rows}, status_code=200)
    finally:
        cur.close()
        conn.close()


# ── CRUD Mapping PIN → User ───────────────────────────────────────

@biofinger_bp.route("/biofinger/mapping", methods=["GET", "POST", "DELETE", "OPTIONS"])
def biofinger_mapping():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    _ensure_schema()
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        if request.method == "GET":
            cur.execute("""
                SELECT bm.id, bm.pin_mesin, bm.nama_mesin, bm.snmesin,
                       bm.is_active, bm.created_at,
                       u.id AS user_id, u.name AS user_name, u.email
                FROM biofinger_mappings bm
                JOIN users u ON u.id = bm.user_id
                ORDER BY u.name ASC;
            """)
            rows = [dict(r) for r in cur.fetchall()]
            for r in rows:
                if r.get("created_at"):
                    r["created_at"] = r["created_at"].strftime("%Y-%m-%d %H:%M:%S")

            cur.execute("""
                SELECT u.id, u.name, u.email FROM users u
                WHERE u.role = 'employee'
                  AND u.id NOT IN (SELECT user_id FROM biofinger_mappings WHERE is_active = TRUE)
                ORDER BY u.name ASC;
            """)
            unmapped_users = [dict(r) for r in cur.fetchall()]
            return mobile_api_response(ok=True, message="OK",
                data={"mappings": rows, "unmapped_users": unmapped_users}, status_code=200)

        elif request.method == "POST":
            data       = request.get_json(silent=True) or {}
            pin_mesin  = str(data.get("pin_mesin", "")).strip()
            user_id    = _safe_int(data.get("user_id"), 0)
            nama_mesin = data.get("nama_mesin", "") or ""
            snmesin    = data.get("snmesin", "") or ""

            if not pin_mesin or not user_id:
                return mobile_api_response(ok=False, message="pin_mesin dan user_id wajib diisi",
                                           data={}, status_code=400)
            cur.execute("""
                INSERT INTO biofinger_mappings (pin_mesin, user_id, nama_mesin, snmesin)
                VALUES (%s,%s,%s,%s)
                ON CONFLICT (pin_mesin) DO UPDATE
                SET user_id=EXCLUDED.user_id, nama_mesin=EXCLUDED.nama_mesin,
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
            return mobile_api_response(ok=True, message="Mapping dihapus.", data={}, status_code=200)

    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), data={}, status_code=500)
    finally:
        cur.close()
        conn.close()
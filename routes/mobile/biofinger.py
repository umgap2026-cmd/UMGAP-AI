"""
routes/mobile/biofinger.py

Endpoint webhook dari BioFinger Push SDK API.
Mesin fingerprint TM-501 mengirim data ke endpoint ini setiap kali
karyawan melakukan scan sidik jari.

Setup di BioFinger Dashboard (biofinger.id/pushsdkapi):
  1. Login ke dashboard biofinger.id
  2. Masuk menu Push SDK API
  3. Tambahkan URL Outgoing Webhook:
     https://umgap-ai.onrender.com/api/biofinger/webhook
  4. Pilih BioHook: sdatareco (record presensi)

Format JSON yang diterima (sdatareco):
{
  "biohook":  "sdatareco",
  "tran_id":  "1775788873",        <- ID transaksi unik
  "snmesin":  "COVJ225160001",     <- Serial Number mesin
  "tran_dt":  "2026-04-10 09:41:12", <- Waktu scan (WIB)
  "user_id":  "9337",              <- PIN karyawan di mesin
  "disp_nm":  "ANTON",            <- Nama di mesin
  "stateid":  "0",                 <- 0=masuk, 1=pulang, 4=izin, dll
  "verify":   "0",                 <- 0=fingerprint, 1=password, 4=kartu
  "workcod":  ""                   <- work code (kosong = normal)
}
"""

from datetime import datetime, timedelta
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_response, _safe_int

biofinger_bp = Blueprint("biofinger", __name__)


# ── Schema helper ─────────────────────────────────────────────────

def _ensure_schema():
    """Buat tabel mapping PIN mesin → user UMGAP jika belum ada."""
    conn = get_conn()
    cur  = conn.cursor()
    try:
        # Tabel mapping PIN mesin fingerprint ke user UMGAP
        cur.execute("""
            CREATE TABLE IF NOT EXISTS biofinger_mappings (
                id          SERIAL PRIMARY KEY,
                pin_mesin   VARCHAR(50)  NOT NULL UNIQUE,  -- user_id dari mesin
                user_id     INTEGER      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                snmesin     VARCHAR(100) DEFAULT '',        -- serial number mesin (opsional)
                nama_mesin  VARCHAR(100) DEFAULT '',        -- nama di mesin (disp_nm)
                is_active   BOOLEAN      NOT NULL DEFAULT TRUE,
                created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_bf_pin ON biofinger_mappings(pin_mesin);
        """)

        # Tabel log semua data mentah dari mesin (untuk debugging & audit)
        cur.execute("""
            CREATE TABLE IF NOT EXISTS biofinger_logs (
                id          SERIAL PRIMARY KEY,
                tran_id     VARCHAR(100) UNIQUE,           -- ID transaksi dari mesin
                pin_mesin   VARCHAR(50),
                disp_nm     VARCHAR(100),
                snmesin     VARCHAR(100),
                tran_dt     TIMESTAMP,                     -- waktu scan (WIB)
                stateid     VARCHAR(10) DEFAULT '0',
                verify      VARCHAR(10) DEFAULT '0',
                workcod     VARCHAR(50) DEFAULT '',
                mapped_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
                status      VARCHAR(20) DEFAULT 'PENDING', -- PENDING|RECORDED|UNMAPPED|DUPLICATE
                notes       TEXT DEFAULT '',
                received_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
        cur.execute("""
            CREATE INDEX IF NOT EXISTS idx_bf_log_tran ON biofinger_logs(tran_id);
            CREATE INDEX IF NOT EXISTS idx_bf_log_pin ON biofinger_logs(pin_mesin, tran_dt);
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()


# ── Status mapping (stateid dari mesin) ──────────────────────────

def _parse_stateid(stateid: str) -> str:
    """
    Konversi stateid BioFinger ke arrival_type UMGAP.
    stateid: 0=check-in/masuk, 1=check-out/pulang,
             4=lembur masuk, 5=lembur pulang
    """
    mapping = {
        "0": "ONTIME",   # Check-In / Masuk
        "1": "ONTIME",   # Check-Out / Pulang (dicatat sebagai absen pulang)
        "4": "ONTIME",   # Overtime In
        "5": "ONTIME",   # Overtime Out
    }
    return mapping.get(str(stateid), "ONTIME")


def _is_checkin(stateid: str) -> bool:
    """Return True jika scan adalah check-in (masuk)."""
    return str(stateid) in ("0", "4")


# ── Parse tanggal dari mesin ──────────────────────────────────────

def _parse_tran_dt(tran_dt_str: str):
    """
    Parse tran_dt dari mesin.
    Format: "2026-04-10 09:41:12" (WIB naive)
    """
    try:
        return datetime.strptime(tran_dt_str.strip(), "%Y-%m-%d %H:%M:%S")
    except Exception:
        return datetime.now()


# ── Main Webhook Endpoint ─────────────────────────────────────────

@biofinger_bp.route("/biofinger/webhook", methods=["POST", "GET", "OPTIONS"])
def biofinger_webhook():
    """
    Endpoint utama yang menerima push dari BioFinger.
    BioFinger mengirim HTTP POST dengan Content-Type: application/json.

    Untuk verifikasi awal (GET), balas 200 OK.
    """
    if request.method in ("GET", "OPTIONS"):
        # BioFinger kadang verifikasi dengan GET dulu
        return mobile_api_response(ok=True, message="UMGAP BioFinger Webhook Active", data={}, status_code=200)

    _ensure_schema()

    payload = request.get_json(silent=True) or {}

    biohook = payload.get("biohook", "")
    tran_id = payload.get("tran_id", "")
    snmesin = payload.get("snmesin", "")
    tran_dt_str = payload.get("tran_dt", "")
    pin_mesin = str(payload.get("user_id", "")).strip()
    disp_nm   = payload.get("disp_nm", "")
    stateid   = str(payload.get("stateid", "0")).strip()
    verify    = str(payload.get("verify", "0")).strip()
    workcod   = payload.get("workcod", "") or ""

    # Hanya proses sdatareco (record presensi)
    if biohook != "sdatareco":
        return mobile_api_response(ok=True, message=f"biohook '{biohook}' diabaikan", data={}, status_code=200)

    if not pin_mesin:
        return mobile_api_response(ok=False, message="user_id kosong", data={}, status_code=400)

    tran_dt = _parse_tran_dt(tran_dt_str)
    work_date = tran_dt.date()

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # 1. Cek duplikat tran_id
        if tran_id:
            cur.execute("SELECT id, status FROM biofinger_logs WHERE tran_id = %s LIMIT 1;", (tran_id,))
            existing = cur.fetchone()
            if existing:
                return mobile_api_response(
                    ok=True,
                    message="Transaksi sudah diproses sebelumnya.",
                    data={"status": existing["status"]},
                    status_code=200
                )

        # 2. Cari mapping PIN → user UMGAP
        cur.execute("""
            SELECT bm.user_id, u.name AS user_name
            FROM biofinger_mappings bm
            JOIN users u ON u.id = bm.user_id
            WHERE bm.pin_mesin = %s AND bm.is_active = TRUE
            LIMIT 1;
        """, (pin_mesin,))
        mapping = cur.fetchone()

        if not mapping:
            # PIN belum di-mapping → catat sebagai UNMAPPED untuk review admin
            cur.execute("""
                INSERT INTO biofinger_logs
                    (tran_id, pin_mesin, disp_nm, snmesin, tran_dt,
                     stateid, verify, workcod, status, notes)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,'UNMAPPED',
                        'PIN belum di-mapping ke karyawan UMGAP')
                ON CONFLICT (tran_id) DO NOTHING;
            """, (tran_id, pin_mesin, disp_nm, snmesin, tran_dt,
                  stateid, verify, workcod))
            conn.commit()
            return mobile_api_response(
                ok=True,
                message=f"PIN {pin_mesin} ({disp_nm}) belum di-mapping. Silakan mapping di menu Absensi.",
                data={"pin": pin_mesin, "nama": disp_nm},
                status_code=200
            )

        user_id   = mapping["user_id"]
        user_name = mapping["user_name"]
        arrival_type = _parse_stateid(stateid)
        is_checkin   = _is_checkin(stateid)

        # 3. Cek apakah sudah ada record absensi hari ini
        cur.execute("""
            SELECT id, check_in, check_out
            FROM attendance
            WHERE user_id = %s AND work_date = %s
            LIMIT 1;
        """, (user_id, work_date))
        att_today = cur.fetchone()

        notes_msg = ""

        if is_checkin:
            # ── CHECK-IN ──────────────────────────────
            if att_today:
                # Sudah check-in hari ini → update jika lebih awal
                notes_msg = f"Update check-in dari mesin fingerprint ({disp_nm})"
                cur.execute("""
                    UPDATE attendance
                    SET check_in    = LEAST(check_in, %s),
                        arrival_type = %s,
                        note        = CONCAT(COALESCE(note,''), ' | BF:', %s)
                    WHERE id = %s;
                """, (tran_dt, arrival_type, tran_dt_str, att_today["id"]))
            else:
                # Check-in baru
                notes_msg = f"Check-in dari mesin fingerprint ({disp_nm})"
                cur.execute("""
                    INSERT INTO attendance
                        (user_id, work_date, check_in, status, arrival_type, note, device_id)
                    VALUES (%s, %s, %s, 'PRESENT', %s, %s, 'FINGERPRINT')
                    ON CONFLICT (user_id, work_date) DO UPDATE
                    SET check_in     = LEAST(attendance.check_in, EXCLUDED.check_in),
                        arrival_type = EXCLUDED.arrival_type,
                        note         = CONCAT(COALESCE(attendance.note,''), ' | BF:', %s);
                """, (user_id, work_date, tran_dt, arrival_type,
                      f"Check-in fingerprint {tran_dt_str}", tran_dt_str))
        else:
            # ── CHECK-OUT ─────────────────────────────
            notes_msg = f"Check-out dari mesin fingerprint ({disp_nm})"
            if att_today:
                cur.execute("""
                    UPDATE attendance
                    SET check_out = GREATEST(COALESCE(check_out, %s), %s),
                        note      = CONCAT(COALESCE(note,''), ' | BF-out:', %s)
                    WHERE id = %s;
                """, (tran_dt, tran_dt, tran_dt_str, att_today["id"]))
            else:
                # Check-out tanpa check-in → buat record tetap
                cur.execute("""
                    INSERT INTO attendance
                        (user_id, work_date, check_in, check_out, status, arrival_type, note, device_id)
                    VALUES (%s, %s, %s, %s, 'PRESENT', 'ONTIME', %s, 'FINGERPRINT')
                    ON CONFLICT (user_id, work_date) DO UPDATE
                    SET check_out = GREATEST(COALESCE(attendance.check_out, EXCLUDED.check_out), EXCLUDED.check_out),
                        note      = CONCAT(COALESCE(attendance.note,''), ' | BF-out:', %s);
                """, (user_id, work_date, tran_dt, tran_dt,
                      f"Check-out fingerprint (no check-in) {tran_dt_str}", tran_dt_str))

        # 4. Catat ke log
        cur.execute("""
            INSERT INTO biofinger_logs
                (tran_id, pin_mesin, disp_nm, snmesin, tran_dt,
                 stateid, verify, workcod, mapped_user_id, status, notes)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,'RECORDED',%s)
            ON CONFLICT (tran_id) DO NOTHING;
        """, (tran_id, pin_mesin, disp_nm, snmesin, tran_dt,
              stateid, verify, workcod, user_id, notes_msg))

        conn.commit()

        action = "Check-in" if is_checkin else "Check-out"
        return mobile_api_response(
            ok=True,
            message=f"{action} {user_name} berhasil dicatat ({tran_dt_str})",
            data={
                "user_id":   user_id,
                "user_name": user_name,
                "action":    action,
                "time":      tran_dt_str,
                "work_date": str(work_date),
            },
            status_code=200
        )

    except Exception as e:
        conn.rollback()
        # Tetap balas 200 agar BioFinger tidak retry terus
        print(f"[BioFinger Webhook ERROR] {e}")
        return mobile_api_response(
            ok=True,
            message=f"Error diproses: {str(e)}",
            data={},
            status_code=200
        )
    finally:
        cur.close()
        conn.close()


# ── Endpoint: List unmapped PINs ──────────────────────────────────

@biofinger_bp.route("/biofinger/unmapped", methods=["GET", "OPTIONS"])
def biofinger_unmapped():
    """Ambil daftar PIN yang belum di-mapping, untuk admin."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    # Auth check sederhana via header Authorization
    from core import mobile_api_login_required
    # Pakai manual check agar tidak perlu decorator
    from flask import request as req
    token = (req.headers.get("Authorization") or "").replace("Bearer ", "").strip()
    if not token:
        return mobile_api_response(ok=False, message="Unauthorized", data={}, status_code=401)

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


# ── Endpoint: Mapping PIN → User ──────────────────────────────────

@biofinger_bp.route("/biofinger/mapping", methods=["GET", "POST", "DELETE", "OPTIONS"])
def biofinger_mapping():
    """CRUD mapping PIN mesin → user UMGAP."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    _ensure_schema()
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)

    try:
        if request.method == "GET":
            # List semua mapping
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

            # Juga ambil karyawan yang belum di-mapping
            cur.execute("""
                SELECT u.id, u.name, u.email
                FROM users u
                WHERE u.role = 'employee'
                  AND u.id NOT IN (SELECT user_id FROM biofinger_mappings WHERE is_active = TRUE)
                ORDER BY u.name ASC;
            """)
            unmapped_users = [dict(r) for r in cur.fetchall()]

            return mobile_api_response(ok=True, message="OK",
                                       data={"mappings": rows, "unmapped_users": unmapped_users},
                                       status_code=200)

        elif request.method == "POST":
            # Tambah mapping baru
            data = request.get_json(silent=True) or {}
            pin_mesin  = str(data.get("pin_mesin", "")).strip()
            user_id    = _safe_int(data.get("user_id"), 0)
            nama_mesin = data.get("nama_mesin", "") or ""
            snmesin    = data.get("snmesin", "") or ""

            if not pin_mesin or not user_id:
                return mobile_api_response(ok=False, message="pin_mesin dan user_id wajib diisi",
                                           data={}, status_code=400)

            cur.execute("""
                INSERT INTO biofinger_mappings (pin_mesin, user_id, nama_mesin, snmesin)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (pin_mesin) DO UPDATE
                SET user_id    = EXCLUDED.user_id,
                    nama_mesin = EXCLUDED.nama_mesin,
                    snmesin    = EXCLUDED.snmesin,
                    is_active  = TRUE,
                    updated_at = CURRENT_TIMESTAMP
                RETURNING id;
            """, (pin_mesin, user_id, nama_mesin, snmesin))
            row = cur.fetchone()

            # Update status log UNMAPPED yang cocok jadi RECORDED
            cur.execute("""
                UPDATE biofinger_logs
                SET status = 'REMAPPED', mapped_user_id = %s,
                    notes  = CONCAT(notes, ' | Mapping ditambahkan')
                WHERE pin_mesin = %s AND status = 'UNMAPPED';
            """, (user_id, pin_mesin))

            conn.commit()
            return mobile_api_response(ok=True, message="Mapping berhasil disimpan.",
                                       data={"id": row["id"]}, status_code=200)

        elif request.method == "DELETE":
            # Hapus / nonaktifkan mapping
            data = request.get_json(silent=True) or {}
            mapping_id = _safe_int(data.get("id"), 0)
            if not mapping_id:
                return mobile_api_response(ok=False, message="id mapping wajib diisi",
                                           data={}, status_code=400)

            cur.execute("""
                UPDATE biofinger_mappings
                SET is_active = FALSE, updated_at = CURRENT_TIMESTAMP
                WHERE id = %s
                RETURNING id;
            """, (mapping_id,))
            row = cur.fetchone()
            conn.commit()

            if not row:
                return mobile_api_response(ok=False, message="Mapping tidak ditemukan",
                                           data={}, status_code=404)

            return mobile_api_response(ok=True, message="Mapping dinonaktifkan.",
                                       data={}, status_code=200)

    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), data={}, status_code=500)
    finally:
        cur.close()
        conn.close()
from flask import Blueprint, request, jsonify
from datetime import datetime
import os, traceback
from psycopg2.extras import RealDictCursor
from db import get_conn

biofinger_push_bp = Blueprint("biofinger_push_bp", __name__)
PUSH_KEY = os.getenv("BIOFINGER_PUSH_KEY", "").strip()

DT_FMTS = ("%Y-%m-%d %H:%M:%S", "%Y/%m/%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y/%m/%d %H:%M")

@biofinger_push_bp.route("/api/biofinger/push", methods=["POST"])
def biofinger_push():
    if PUSH_KEY and request.headers.get("X-Bio-Key", "") != PUSH_KEY:
        return jsonify(ok=False, message="unauthorized"), 401

    data = request.get_json(silent=True) or {}
    records = data.get("records") or [data]
    saved = dup = pending = skipped = 0
    errors = []
    conn = get_conn(); cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        for r in records:
            pin    = str(r.get("pin", "")).strip()
            sn     = str(r.get("sn", "")).strip()
            dt_raw = str(r.get("dt", "")).strip()
            inout  = str(r.get("inout", "0")).strip()
            verify = str(r.get("verify", "0")).strip()

            dt = None
            for f in DT_FMTS:
                try: dt = datetime.strptime(dt_raw, f); break
                except ValueError: pass
            if dt is None:
                errors.append(f"bad dt: {dt_raw}"); continue

            try: pin_int = int(pin)
            except ValueError: pin_int = -1
            if pin_int <= 0:
                skipped += 1; continue

            tran_id = f"{sn}-{pin}-{dt.strftime('%Y%m%d%H%M%S')}"
            cur.execute("""
                INSERT INTO biofinger_logs (tran_id, pin_mesin, snmesin, tran_dt, stateid, verify, status)
                VALUES (%s,%s,%s,%s,%s,%s,'PENDING')
                ON CONFLICT (tran_id) DO NOTHING RETURNING id;
            """, (tran_id, pin, sn, dt, inout, verify))
            if cur.fetchone() is None:
                dup += 1; conn.commit(); continue

            cur.execute("""
                SELECT user_id FROM biofinger_mappings
                WHERE is_active=TRUE AND (pin_mesin=%s OR pin_mesin=%s OR pin_mesin=%s) LIMIT 1;
            """, (pin, pin.lstrip('0') or '0', str(pin_int)))
            m = cur.fetchone()
            if not m:
                pending += 1; conn.commit(); continue

            uid = m["user_id"]; wdate = dt.date()
            is_out = inout in ("1", "OUT", "out")
            cur.execute("SELECT id FROM attendance WHERE user_id=%s AND work_date=%s FOR UPDATE;", (uid, wdate))
            att = cur.fetchone()
            if att is None:
                if is_out:
                    cur.execute("""INSERT INTO attendance (user_id,work_date,status,arrival_type,checkout_at,check_out,checkout_auto,timezone_used)
                                   VALUES (%s,%s,'PRESENT','fingerprint',%s,%s,FALSE,'WIB');""", (uid,wdate,dt,dt))
                else:
                    cur.execute("""INSERT INTO attendance (user_id,work_date,status,arrival_type,checkin_at,check_in,timezone_used)
                                   VALUES (%s,%s,'PRESENT','fingerprint',%s,%s,'WIB');""", (uid,wdate,dt,dt))
            else:
                if is_out:
                    cur.execute("""UPDATE attendance SET checkout_at=GREATEST(COALESCE(checkout_at,%s),%s),
                                   check_out=GREATEST(COALESCE(check_out,%s),%s) WHERE id=%s;""", (dt,dt,dt,dt,att["id"]))
                else:
                    cur.execute("""UPDATE attendance SET checkin_at=LEAST(COALESCE(checkin_at,%s),%s),
                                   check_in=LEAST(COALESCE(check_in,%s),%s) WHERE id=%s;""", (dt,dt,dt,dt,att["id"]))

            cur.execute("UPDATE biofinger_logs SET mapped_user_id=%s, status='PROCESSED' WHERE tran_id=%s;", (uid, tran_id))
            conn.commit(); saved += 1

        return jsonify(ok=True, saved=saved, duplicate=dup, pending_unmapped=pending, skipped=skipped, errors=errors)
    except Exception as e:
        conn.rollback(); print("[BIOFINGER PUSH]", traceback.format_exc())
        return jsonify(ok=False, message=str(e)), 500
    finally:
        cur.close(); conn.close()

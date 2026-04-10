"""
routes/web/data_cleanup.py

Fitur: Admin bisa hapus riwayat data dalam rentang tanggal tertentu.
Setiap penghapusan dicatat di tabel admin_delete_logs (audit log).

Daftar data yang bisa dihapus:
  - attendance       : Riwayat absensi
  - sales_submissions: Riwayat penjualan
  - biofinger_logs   : Log fingerprint
  - announcements    : Pengumuman
  - invoice          : Nota/invoice
  - payroll          : Payroll
  - points_logs      : Log poin karyawan
"""

from datetime import date, datetime
from flask import Blueprint, render_template, request, redirect, session, jsonify
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import admin_required, get_notif_count

data_cleanup_bp = Blueprint("data_cleanup", __name__)

# ── Konfigurasi tabel yang boleh dihapus ─────────────────────────
CLEANUP_TARGETS = {
    "attendance": {
        "label":     "Absensi",
        "table":     "attendance",
        "date_col":  "work_date",
        "join":      "",
        "count_col": "id",
    },
    "sales": {
        "label":     "Penjualan",
        "table":     "sales_submissions",
        "date_col":  "created_at",
        "join":      "",
        "count_col": "id",
    },
    "points_logs": {
        "label":     "Log Poin",
        "table":     "points_logs",
        "date_col":  "created_at",
        "join":      "",
        "count_col": "id",
    },
}


# ── Buat tabel audit log ──────────────────────────────────────────
def _ensure_audit_schema():
    conn = get_conn()
    cur  = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS admin_delete_logs (
                id           SERIAL PRIMARY KEY,
                admin_id     INTEGER REFERENCES users(id) ON DELETE SET NULL,
                admin_name   VARCHAR(100),
                target_key   VARCHAR(50)  NOT NULL,
                target_label VARCHAR(100) NOT NULL,
                date_from    DATE NOT NULL,
                date_to      DATE NOT NULL,
                rows_deleted INTEGER NOT NULL DEFAULT 0,
                note         TEXT DEFAULT '',
                deleted_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()


# ── Halaman utama cleanup ─────────────────────────────────────────

@data_cleanup_bp.route("/admin/data-cleanup")
def data_cleanup_page():
    deny = admin_required()
    if deny: return deny

    _ensure_audit_schema()

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT dl.*, u.name AS admin_name_fresh
            FROM admin_delete_logs dl
            LEFT JOIN users u ON u.id = dl.admin_id
            ORDER BY dl.deleted_at DESC
            LIMIT 50;
        """)
        logs = [dict(r) for r in cur.fetchall()]
        for log in logs:
            if log.get("deleted_at"):
                log["deleted_at"] = log["deleted_at"].strftime("%d/%m/%Y %H:%M")
    finally:
        cur.close()
        conn.close()

    # KPI counts
    conn2 = get_conn()
    cur2  = conn2.cursor(cursor_factory=RealDictCursor)
    kpi   = {"absen": 0, "sales": 0, "poin": 0}
    try:
        cur2.execute("SELECT COUNT(*) AS n FROM attendance;")
        kpi["absen"] = (cur2.fetchone() or {}).get("n", 0)
        cur2.execute("SELECT COUNT(*) AS n FROM sales_submissions;")
        kpi["sales"] = (cur2.fetchone() or {}).get("n", 0)
        try:
            cur2.execute("SELECT COUNT(*) AS n FROM points_logs;")
            kpi["poin"] = (cur2.fetchone() or {}).get("n", 0)
        except Exception:
            pass
    finally:
        cur2.close()
        conn2.close()

    return render_template(
        "admin_data_cleanup.html",
        targets     = CLEANUP_TARGETS,
        logs        = logs,
        kpi         = kpi,
        user_name   = session.get("user_name", "Admin"),
        notif_count = get_notif_count(),
    )


# ── Preview: hitung berapa baris yang akan terhapus ──────────────

@data_cleanup_bp.route("/admin/data-cleanup/preview", methods=["POST"])
def data_cleanup_preview():
    deny = admin_required()
    if deny: return jsonify({"ok": False, "message": "Unauthorized"}), 403

    key       = (request.json or {}).get("key", "")
    date_from = (request.json or {}).get("date_from", "")
    date_to   = (request.json or {}).get("date_to", "")

    if key not in CLEANUP_TARGETS:
        return jsonify({"ok": False, "message": "Target tidak valid"})

    try:
        df = datetime.strptime(date_from, "%Y-%m-%d").date()
        dt = datetime.strptime(date_to,   "%Y-%m-%d").date()
        if df > dt:
            return jsonify({"ok": False, "message": "Tanggal awal harus ≤ tanggal akhir"})
    except Exception:
        return jsonify({"ok": False, "message": "Format tanggal tidak valid"})

    cfg   = CLEANUP_TARGETS[key]
    table = cfg["table"]
    col   = cfg["date_col"]

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute(f"""
            SELECT COUNT({cfg['count_col']}) AS total
            FROM {table}
            {cfg['join']}
            WHERE {table}.{col}::date >= %s AND {table}.{col}::date <= %s;
        """, (df, dt))
        total = cur.fetchone()["total"]
        return jsonify({"ok": True, "total": total, "label": cfg["label"]})
    except Exception as e:
        return jsonify({"ok": False, "message": str(e)})
    finally:
        cur.close()
        conn.close()


# ── Eksekusi penghapusan ──────────────────────────────────────────

@data_cleanup_bp.route("/admin/data-cleanup/execute", methods=["POST"])
def data_cleanup_execute():
    deny = admin_required()
    if deny: return jsonify({"ok": False, "message": "Unauthorized"}), 403

    data      = request.json or {}
    key       = data.get("key", "")
    date_from = data.get("date_from", "")
    date_to   = data.get("date_to", "")
    note      = (data.get("note") or "").strip()[:500]
    confirm   = data.get("confirm", "")

    # Double check konfirmasi
    if confirm != "HAPUS":
        return jsonify({"ok": False, "message": "Konfirmasi tidak sesuai. Ketik HAPUS."})

    if key not in CLEANUP_TARGETS:
        return jsonify({"ok": False, "message": "Target tidak valid"})

    try:
        df = datetime.strptime(date_from, "%Y-%m-%d").date()
        dt = datetime.strptime(date_to,   "%Y-%m-%d").date()
        if df > dt:
            return jsonify({"ok": False, "message": "Tanggal tidak valid"})
    except Exception:
        return jsonify({"ok": False, "message": "Format tanggal tidak valid"})

    cfg        = CLEANUP_TARGETS[key]
    table      = cfg["table"]
    col        = cfg["date_col"]
    admin_id   = session.get("user_id")
    admin_name = session.get("user_name", "Admin")

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Hapus data
        cur.execute(f"""
            DELETE FROM {table}
            WHERE {col}::date >= %s AND {col}::date <= %s;
        """, (df, dt))
        rows_deleted = cur.rowcount

        # Catat ke audit log
        cur.execute("""
            INSERT INTO admin_delete_logs
                (admin_id, admin_name, target_key, target_label,
                 date_from, date_to, rows_deleted, note)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s);
        """, (admin_id, admin_name, key, cfg["label"],
              df, dt, rows_deleted, note))

        conn.commit()
        return jsonify({
            "ok":           True,
            "rows_deleted": rows_deleted,
            "label":        cfg["label"],
            "date_from":    str(df),
            "date_to":      str(dt),
        })
    except Exception as e:
        conn.rollback()
        return jsonify({"ok": False, "message": f"Error: {str(e)}"})
    finally:
        cur.close()
        conn.close()


# ── Hapus satu baris audit log ─────────────────────────────────────

@data_cleanup_bp.route("/admin/data-cleanup/log/<int:log_id>/delete", methods=["POST"])
def data_cleanup_delete_log(log_id):
    deny = admin_required()
    if deny: return jsonify({"ok": False}), 403

    conn = get_conn()
    cur  = conn.cursor()
    try:
        cur.execute("DELETE FROM admin_delete_logs WHERE id = %s;", (log_id,))
        conn.commit()
        return jsonify({"ok": True})
    finally:
        cur.close()
        conn.close()

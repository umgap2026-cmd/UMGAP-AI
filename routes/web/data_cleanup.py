"""
routes/web/data_cleanup.py

Fitur: Owner bisa hapus riwayat data dalam rentang tanggal tertentu, ATAU
hapus 1 baris data spesifik saja. Khusus owner (bukan admin) -- aksi ini
permanen & berdampak luas, jadi dipusatkan ke pemilik bisnis.
Setiap penghapusan dicatat di tabel admin_delete_logs (audit log) --
nama kolom tetap admin_id/admin_name apa adanya (dibuat sebelum fitur ini
jadi owner-only) supaya tidak perlu migrasi kolom, cukup diisi data owner.

Daftar data yang bisa dihapus:
  - attendance       : Riwayat absensi
  - sales_submissions: Riwayat penjualan
  - points_logs      : Log poin karyawan
  - announcements    : Pengumuman
  - biofinger_logs   : Log scan fingerprint

Nota/invoice SENGAJA TIDAK ada di sini -- sudah ada alur khusus yang aman
(soft-delete lalu purge permanen satu-per-satu di /nota/deleted) yang ikut
membalik stok & hutang-piutang; hapus massal lewat tabel mentah di sini
akan merusak data itu.
"""

from datetime import date, datetime
from flask import Blueprint, render_template, request, redirect, session, jsonify
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import owner_required, get_notif_count

data_cleanup_bp = Blueprint("data_cleanup", __name__)

# ── Konfigurasi tabel yang boleh dihapus ─────────────────────────
# browse_sql: dipakai fitur "Hapus 1 Data" -- SELECT id + kolom ringkas
# utk ditampilkan & dipilih satu per satu. Selalu ORDER BY terbaru dulu.
CLEANUP_TARGETS = {
    "attendance": {
        "label":     "Absensi",
        "table":     "attendance",
        "date_col":  "work_date",
        "join":      "",
        "count_col": "id",
        "browse_sql": """
            SELECT a.id, u.name AS c1, a.work_date::text AS c2,
                   a.status AS c3, COALESCE(a.arrival_type, '-') AS c4
            FROM attendance a
            JOIN users u ON u.id = a.user_id
            ORDER BY a.work_date DESC, a.id DESC
            LIMIT 200;
        """,
        "browse_headers": ["Karyawan", "Tanggal", "Status", "Tipe Datang"],
    },
    "sales": {
        "label":     "Penjualan",
        "table":     "sales_submissions",
        "date_col":  "created_at",
        "join":      "",
        "count_col": "id",
        "browse_sql": """
            SELECT s.id, u.name AS c1, s.created_at::text AS c2,
                   COALESCE(p.name, '-') AS c3, s.qty::text AS c4
            FROM sales_submissions s
            JOIN users u ON u.id = s.user_id
            LEFT JOIN products p ON p.id = s.product_id
            ORDER BY s.created_at DESC, s.id DESC
            LIMIT 200;
        """,
        "browse_headers": ["Karyawan", "Waktu", "Produk", "Qty"],
    },
    "points_logs": {
        "label":     "Log Poin",
        "table":     "points_logs",
        "date_col":  "created_at",
        "join":      "",
        "count_col": "id",
        "browse_sql": """
            SELECT pl.id, u.name AS c1, pl.created_at::text AS c2,
                   pl.delta::text AS c3, COALESCE(pl.note, '-') AS c4
            FROM points_logs pl
            JOIN users u ON u.id = pl.user_id
            ORDER BY pl.created_at DESC, pl.id DESC
            LIMIT 200;
        """,
        "browse_headers": ["Karyawan", "Waktu", "Perubahan", "Catatan"],
    },
    "announcements": {
        "label":     "Pengumuman",
        "table":     "announcements",
        "date_col":  "created_at",
        "join":      "",
        "count_col": "id",
        "browse_sql": """
            SELECT id, title AS c1, created_at::text AS c2,
                   COALESCE(message, '-') AS c3, '' AS c4
            FROM announcements
            ORDER BY created_at DESC, id DESC
            LIMIT 200;
        """,
        "browse_headers": ["Judul", "Waktu", "Isi", ""],
    },
    "biofinger_logs": {
        "label":     "Log Fingerprint",
        "table":     "biofinger_logs",
        "date_col":  "tran_dt",
        "join":      "",
        "count_col": "id",
        "browse_sql": """
            SELECT bl.id, COALESCE(u.name, '(belum dipetakan)') AS c1,
                   bl.tran_dt::text AS c2, '' AS c3, '' AS c4
            FROM biofinger_logs bl
            LEFT JOIN users u ON u.id = bl.mapped_user_id
            ORDER BY bl.tran_dt DESC, bl.id DESC
            LIMIT 200;
        """,
        "browse_headers": ["Karyawan", "Waktu Scan", "", ""],
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
    deny = owner_required()
    if deny: return deny

    _ensure_audit_schema()

    try:
        log_page = max(1, int(request.args.get("log_page", 1)))
    except (TypeError, ValueError):
        log_page = 1
    log_page_size = 25

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT dl.*, u.name AS admin_name_fresh
            FROM admin_delete_logs dl
            LEFT JOIN users u ON u.id = dl.admin_id
            ORDER BY dl.deleted_at DESC
            LIMIT %s OFFSET %s;
        """, (log_page_size + 1, (log_page - 1) * log_page_size))
        logs = [dict(r) for r in cur.fetchall()]
        log_has_next = len(logs) > log_page_size
        logs = logs[:log_page_size]
        for log in logs:
            if log.get("deleted_at"):
                log["deleted_at"] = log["deleted_at"].strftime("%d/%m/%Y %H:%M")
    finally:
        cur.close()
        conn.close()

    # KPI counts
    conn2 = get_conn()
    cur2  = conn2.cursor(cursor_factory=RealDictCursor)
    kpi   = {"absen": 0, "sales": 0, "poin": 0, "ann": 0, "finger": 0}
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
        try:
            cur2.execute("SELECT COUNT(*) AS n FROM announcements;")
            kpi["ann"] = (cur2.fetchone() or {}).get("n", 0)
        except Exception:
            pass
        try:
            cur2.execute("SELECT COUNT(*) AS n FROM biofinger_logs;")
            kpi["finger"] = (cur2.fetchone() or {}).get("n", 0)
        except Exception:
            pass
    finally:
        cur2.close()
        conn2.close()

    return render_template(
        "admin_data_cleanup.html",
        targets     = CLEANUP_TARGETS,
        logs        = logs,
        log_page    = log_page,
        log_has_next = log_has_next,
        log_has_prev = log_page > 1,
        kpi         = kpi,
        user_name   = session.get("user_name", "Owner"),
        notif_count = get_notif_count(),
    )


# ── Preview: hitung berapa baris yang akan terhapus (mode rentang) ──

@data_cleanup_bp.route("/admin/data-cleanup/preview", methods=["POST"])
def data_cleanup_preview():
    deny = owner_required()
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


# ── Eksekusi penghapusan rentang tanggal ──────────────────────────

@data_cleanup_bp.route("/admin/data-cleanup/execute", methods=["POST"])
def data_cleanup_execute():
    deny = owner_required()
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
    owner_id   = session.get("user_id")
    owner_name = session.get("user_name", "Owner")

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
        """, (owner_id, owner_name, key, cfg["label"],
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


# ── Mode "Hapus 1 Data": browse baris terbaru per kategori ────────

@data_cleanup_bp.route("/admin/data-cleanup/<key>/browse", methods=["POST"])
def data_cleanup_browse(key):
    deny = owner_required()
    if deny: return jsonify({"ok": False, "message": "Unauthorized"}), 403

    if key not in CLEANUP_TARGETS:
        return jsonify({"ok": False, "message": "Target tidak valid"})

    cfg = CLEANUP_TARGETS[key]
    search = ((request.json or {}).get("search") or "").strip().lower()

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute(cfg["browse_sql"])
        rows = [dict(r) for r in cur.fetchall()]
        if search:
            rows = [
                r for r in rows
                if search in " ".join(str(v or "") for v in r.values()).lower()
            ]
        return jsonify({
            "ok": True,
            "rows": rows[:200],
            "headers": cfg["browse_headers"],
            "label": cfg["label"],
        })
    except Exception as e:
        return jsonify({"ok": False, "message": str(e)})
    finally:
        cur.close()
        conn.close()


# ── Mode "Hapus 1 Data": eksekusi hapus 1 baris ───────────────────

@data_cleanup_bp.route("/admin/data-cleanup/<key>/delete-one", methods=["POST"])
def data_cleanup_delete_one(key):
    deny = owner_required()
    if deny: return jsonify({"ok": False, "message": "Unauthorized"}), 403

    if key not in CLEANUP_TARGETS:
        return jsonify({"ok": False, "message": "Target tidak valid"})

    data    = request.json or {}
    row_id  = data.get("id")
    note    = (data.get("note") or "").strip()[:500]
    if not row_id:
        return jsonify({"ok": False, "message": "ID data wajib diisi."})

    cfg        = CLEANUP_TARGETS[key]
    table      = cfg["table"]
    col        = cfg["date_col"]
    owner_id   = session.get("user_id")
    owner_name = session.get("user_name", "Owner")

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute(f"SELECT id, {col} AS d FROM {table} WHERE id = %s LIMIT 1;", (int(row_id),))
        row = cur.fetchone()
        if not row:
            return jsonify({"ok": False, "message": "Data tidak ditemukan (mungkin sudah dihapus)."})

        row_date = row["d"]
        try:
            row_date = row_date.date() if hasattr(row_date, "date") else row_date
        except Exception:
            row_date = date.today()

        cur.execute(f"DELETE FROM {table} WHERE id = %s;", (int(row_id),))
        rows_deleted = cur.rowcount

        cur.execute("""
            INSERT INTO admin_delete_logs
                (admin_id, admin_name, target_key, target_label,
                 date_from, date_to, rows_deleted, note)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s);
        """, (owner_id, owner_name, key, cfg["label"],
              row_date, row_date, rows_deleted,
              (f"Hapus 1 data (ID {row_id})" + (f" — {note}" if note else ""))))

        conn.commit()
        return jsonify({"ok": True, "rows_deleted": rows_deleted, "label": cfg["label"]})
    except Exception as e:
        conn.rollback()
        return jsonify({"ok": False, "message": f"Error: {str(e)}"})
    finally:
        cur.close()
        conn.close()


# ── Hapus satu baris audit log ─────────────────────────────────────

@data_cleanup_bp.route("/admin/data-cleanup/log/<int:log_id>/delete", methods=["POST"])
def data_cleanup_delete_log(log_id):
    deny = owner_required()
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

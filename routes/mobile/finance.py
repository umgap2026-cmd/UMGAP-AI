"""
routes/mobile/finance.py

UMGAP Finance — Fase 1
Kasir Gudang + Stok AVCO + Laporan Harian
"""
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from datetime import date, timedelta, datetime
from decimal import Decimal

from db import get_conn
from core import (
    mobile_api_response, mobile_api_login_required, send_wa as _send_wa,
    _ensure_transaction_cancel_columns,
    list_fin_materials, add_fin_material, edit_fin_material, delete_fin_material,
    add_fin_material_stock,
    create_fin_expense,
    list_fin_debts, pay_fin_debt, get_fin_stock_history,
    get_fin_daily_report, get_fin_weekly_report,
)
import random
import string

mobile_finance_bp = Blueprint("mobile_finance", __name__)


# ── Helper: convert Decimal/str ke float agar JSON bersih ────────────
def _clean(obj):
    """Rekursif konversi Decimal → float agar tidak ada String cast error di Flutter."""
    if isinstance(obj, list):
        return [_clean(i) for i in obj]
    if isinstance(obj, dict):
        return {k: _clean(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        return float(obj)
    return obj


# ── Helper: hanya owner & admin yang bisa akses ───────────────
def _check_access(mobile_user):
    role = (mobile_user.get("role") or "").strip().lower()
    if role not in ("admin", "owner"):
        return mobile_api_response(
            ok=False, message="Akses ditolak.", status_code=403)
    return None


# ── Helper: hitung AVCO dan update stok ──────────────────────
def _update_stock_avco(cur, material_id, qty_kg, price_per_kg,
                       movement_type, transaction_id, note=""):
    """
    AVCO (Average Cost) calculation:
    - IN  : rata-rata baru = (nilai lama + nilai baru) / (qty lama + qty baru)
    - OUT : pakai avg_cost yang ada, qty & nilai berkurang
    """
    # Ambil stok saat ini
    cur.execute("""
        SELECT qty_kg, avg_cost_per_kg, total_value
        FROM fin_stock_summary
        WHERE material_id = %s
        FOR UPDATE;
    """, (material_id,))
    current = cur.fetchone()

    if current:
        old_qty   = float(current['qty_kg']          or 0)
        old_avg   = float(current['avg_cost_per_kg'] or 0)
        old_value = float(current['total_value']     or 0)
    else:
        old_qty = old_avg = old_value = 0.0

    qty      = float(qty_kg)
    price    = float(price_per_kg)

    if movement_type == 'IN':
        new_qty   = old_qty + qty
        new_value = old_value + (qty * price)
        new_avg   = new_value / new_qty if new_qty > 0 else price
    else:  # OUT
        new_qty   = max(0, old_qty - qty)
        new_avg   = old_avg   # avg tidak berubah saat keluar
        new_value = new_qty * new_avg

    # Upsert stock_summary
    cur.execute("""
        INSERT INTO fin_stock_summary
            (material_id, qty_kg, avg_cost_per_kg, total_value, updated_at)
        VALUES (%s, %s, %s, %s, NOW())
        ON CONFLICT (material_id) DO UPDATE SET
            qty_kg          = EXCLUDED.qty_kg,
            avg_cost_per_kg = EXCLUDED.avg_cost_per_kg,
            total_value     = EXCLUDED.total_value,
            updated_at      = NOW();
    """, (material_id, new_qty, new_avg, new_value))

    # Insert ledger
    cur.execute("""
        INSERT INTO fin_stock_ledger
            (material_id, transaction_id, movement_type,
             qty_kg, price_per_kg, avg_cost_after, qty_after, value_after, note)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s);
    """, (material_id, transaction_id, movement_type,
          qty if movement_type == 'IN' else -qty,
          price, new_avg, new_qty, new_value, note))

    return new_avg  # kembalikan HPP rata-rata baru


def _reverse_stock_movement(cur, material_id, qty_kg, transaction_id,
                            original_movement, note=""):
    """
    Membalikkan efek stok dari sebuah nota yang dibatalkan:
    - Nota BELI (movement asal 'IN', stok bertambah)  → dibalik dengan OUT
    - Nota JUAL (movement asal 'OUT', stok berkurang) → dibalik dengan IN
    avg_cost_per_kg TIDAK diutak-atik mundur (replay ledger penuh terlalu
    kompleks untuk kebutuhan ini) — qty & nilai disesuaikan memakai avg
    yang berlaku saat ini, sama seperti perilaku movement OUT/IN biasa.
    """
    cur.execute("""
        SELECT qty_kg, avg_cost_per_kg, total_value
        FROM fin_stock_summary
        WHERE material_id = %s
        FOR UPDATE;
    """, (material_id,))
    current = cur.fetchone()
    old_qty = float(current["qty_kg"]          or 0) if current else 0.0
    old_avg = float(current["avg_cost_per_kg"] or 0) if current else 0.0

    qty          = float(qty_kg)
    reverse_type = 'OUT' if original_movement == 'IN' else 'IN'

    if reverse_type == 'OUT':
        new_qty   = max(0, old_qty - qty)
        new_avg   = old_avg
        new_value = new_qty * new_avg
    else:
        new_qty   = old_qty + qty
        new_value = (old_qty * old_avg) + (qty * old_avg)
        new_avg   = new_value / new_qty if new_qty > 0 else old_avg

    cur.execute("""
        INSERT INTO fin_stock_summary
            (material_id, qty_kg, avg_cost_per_kg, total_value, updated_at)
        VALUES (%s, %s, %s, %s, NOW())
        ON CONFLICT (material_id) DO UPDATE SET
            qty_kg          = EXCLUDED.qty_kg,
            avg_cost_per_kg = EXCLUDED.avg_cost_per_kg,
            total_value     = EXCLUDED.total_value,
            updated_at      = NOW();
    """, (material_id, new_qty, new_avg, new_value))

    cur.execute("""
        INSERT INTO fin_stock_ledger
            (material_id, transaction_id, movement_type,
             qty_kg, price_per_kg, avg_cost_after, qty_after, value_after, note)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s);
    """, (material_id, transaction_id, reverse_type,
          qty if reverse_type == 'IN' else -qty,
          old_avg, new_avg, new_qty, new_value, note))


# ══════════════════════════════════════════════════════════════
#  OTP  ← disimpan di PostgreSQL agar aman di multi-worker
#  Tabel: fin_otp_store (dibuat auto jika belum ada)
#
#  CREATE TABLE IF NOT EXISTS fin_otp_store (
#      otp         CHAR(6)     PRIMARY KEY,
#      user_id     INT         NOT NULL,
#      expires_at  TIMESTAMPTZ NOT NULL,
#      used        BOOLEAN     NOT NULL DEFAULT FALSE
#  );
# ══════════════════════════════════════════════════════════════

def _ensure_otp_table(cur):
    cur.execute("""
        CREATE TABLE IF NOT EXISTS fin_otp_store (
            otp        CHAR(6)     PRIMARY KEY,
            user_id    INT         NOT NULL,
            expires_at TIMESTAMPTZ NOT NULL,
            used       BOOLEAN     NOT NULL DEFAULT FALSE
        );
    """)

def _cleanup_otp(cur):
    """Hapus OTP expired."""
    cur.execute("DELETE FROM fin_otp_store WHERE expires_at < NOW();")

# ── Rate limit percobaan verifikasi/consume OTP finance (anti brute-force) ──
FIN_OTP_VERIFY_MAX_ATTEMPTS = 8
FIN_OTP_VERIFY_WINDOW_MINUTES = 15

def _ensure_fin_otp_throttle_table(cur):
    cur.execute("""
        CREATE TABLE IF NOT EXISTS fin_otp_verify_throttle (
            user_id           INT PRIMARY KEY,
            attempt_count     INT NOT NULL DEFAULT 0,
            window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        );
    """)

def _fin_otp_verify_rate_limited(cur, user_id: int) -> bool:
    """Catat satu percobaan verifikasi/consume OTP untuk user ini, lalu return
    True kalau user tersebut sudah melewati batas percobaan dalam jendela berjalan."""
    _ensure_fin_otp_throttle_table(cur)
    cur.execute("""
        INSERT INTO fin_otp_verify_throttle (user_id, attempt_count, window_started_at)
        VALUES (%s, 1, NOW())
        ON CONFLICT (user_id) DO UPDATE SET
            attempt_count = CASE
                WHEN fin_otp_verify_throttle.window_started_at < NOW() - make_interval(mins => %s)
                    THEN 1
                ELSE fin_otp_verify_throttle.attempt_count + 1
            END,
            window_started_at = CASE
                WHEN fin_otp_verify_throttle.window_started_at < NOW() - make_interval(mins => %s)
                    THEN NOW()
                ELSE fin_otp_verify_throttle.window_started_at
            END
        RETURNING attempt_count;
    """, (user_id, FIN_OTP_VERIFY_WINDOW_MINUTES, FIN_OTP_VERIFY_WINDOW_MINUTES))
    row = cur.fetchone()
    count = row["attempt_count"] if row else 1
    return count > FIN_OTP_VERIFY_MAX_ATTEMPTS

def _consume_otp(cur, otp: str, actor_user_id: int):
    """
    Validasi + tandai OTP sebagai used (atomic via FOR UPDATE).
    Raise ValueError jika tidak valid / expired / sudah dipakai / terlalu banyak percobaan.
    """
    if _fin_otp_verify_rate_limited(cur, actor_user_id):
        raise ValueError("Terlalu banyak percobaan. Coba lagi beberapa menit lagi.")
    cur.execute("""
        SELECT used, expires_at
        FROM fin_otp_store
        WHERE otp = %s
        FOR UPDATE;
    """, (otp,))
    row = cur.fetchone()
    if not row:
        raise ValueError("OTP tidak valid")
    if row["used"]:
        raise ValueError("OTP sudah digunakan")
    if row["expires_at"].replace(tzinfo=None) < datetime.utcnow():
        raise ValueError("OTP sudah kedaluwarsa")
    cur.execute("UPDATE fin_otp_store SET used = TRUE WHERE otp = %s;", (otp,))


# ══════════════════════════════════════════════════════════════
#  OTP ENDPOINTS
# ══════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/otp/request", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def finance_otp_request():
    """
    Generate OTP 6 digit → simpan di DB → kirim WA ke nomor
    user yang sedang login (bukan semua admin).
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    user    = request.mobile_user
    user_id = user["user_id"]

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_otp_table(cur)
        _cleanup_otp(cur)

        # Ambil nomor HP user yang login
        cur.execute("SELECT phone FROM users WHERE id = %s;", (user_id,))
        row = cur.fetchone()
        phone = (row["phone"] or "").strip() if row else ""
        if not phone:
            return mobile_api_response(
                ok=False,
                message="Nomor WhatsApp kamu belum terdaftar di profil.",
                status_code=400
            )

        # Generate OTP unik
        for _ in range(10):
            otp = "".join(random.choices(string.digits, k=6))
            cur.execute("SELECT 1 FROM fin_otp_store WHERE otp = %s;", (otp,))
            if not cur.fetchone():
                break

        cur.execute("""
            INSERT INTO fin_otp_store (otp, user_id, expires_at, used)
            VALUES (%s, %s, NOW() + INTERVAL '5 minutes', FALSE)
            ON CONFLICT (otp) DO UPDATE
                SET user_id = EXCLUDED.user_id,
                    expires_at = EXCLUDED.expires_at,
                    used = FALSE;
        """, (otp, user_id))
        conn.commit()

        msg = (
            f"🔐 *Kode OTP UMGAP*\n\n"
            f"Kode: *{otp}*\n\n"
            f"Berlaku *5 menit*. Jangan bagikan ke siapapun.\n"
            f"Jika tidak merasa meminta OTP, abaikan pesan ini."
        )
        _send_wa(phone, msg)

        return mobile_api_response(ok=True, message="OTP dikirim ke WhatsApp kamu", data={})
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()


@mobile_finance_bp.route("/finance/otp/verify", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def finance_otp_verify():
    """Pre-check OTP — tidak consume, hanya validasi."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}
    otp  = str(data.get("otp", "")).strip()

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_otp_table(cur)
        if _fin_otp_verify_rate_limited(cur, request.mobile_user["user_id"]):
            conn.commit()
            return mobile_api_response(
                ok=False, message="Terlalu banyak percobaan. Coba lagi beberapa menit lagi.",
                status_code=429)
        conn.commit()
        cur.execute("""
            SELECT used, expires_at
            FROM fin_otp_store
            WHERE otp = %s;
        """, (otp,))
        row = cur.fetchone()
        if not row:
            return mobile_api_response(ok=False, message="OTP tidak valid", status_code=400)
        if row["used"]:
            return mobile_api_response(ok=False, message="OTP sudah digunakan", status_code=400)
        if row["expires_at"].replace(tzinfo=None) < datetime.utcnow():
            return mobile_api_response(ok=False, message="OTP sudah kedaluwarsa", status_code=400)
        return mobile_api_response(ok=True, message="OTP valid", data={})
    finally:
        cur.close(); conn.close()


@mobile_finance_bp.route("/finance/materials/<int:material_id>/edit",
                         methods=["PUT", "OPTIONS"])
@mobile_api_login_required
def finance_edit_material(material_id):
    """Edit nama & satuan material. Butuh OTP valid."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}
    otp  = str(data.get("otp", "")).strip()
    name = str(data.get("name", "")).strip()
    unit = str(data.get("unit", "kg")).strip() or "kg"

    if not name:
        return mobile_api_response(ok=False, message="Nama barang wajib diisi", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_otp_table(cur)
        _consume_otp(cur, otp, request.mobile_user["user_id"])   # validasi + consume atomic
        conn.commit()
    except ValueError as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=400)
    finally:
        cur.close(); conn.close()

    try:
        row = edit_fin_material(material_id, name, unit, request.mobile_user["user_id"])
        return mobile_api_response(ok=True, message="Barang berhasil diperbarui", data=row)
    except ValueError as e:
        status = 404 if "tidak ditemukan" in str(e) else 400
        return mobile_api_response(ok=False, message=str(e), status_code=status)


@mobile_finance_bp.route("/finance/materials/<int:material_id>/delete",
                         methods=["DELETE", "OPTIONS"])
@mobile_api_login_required
def finance_delete_material(material_id):
    """
    Hapus material beserta semua data terkait. Butuh OTP valid.
    Urutan DELETE mengikuti foreign key:
      fin_stock_ledger → fin_transaction_items (set null) → fin_stock_summary → fin_materials
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}
    otp  = str(data.get("otp", "")).strip()

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_otp_table(cur)
        _consume_otp(cur, otp, request.mobile_user["user_id"])
        conn.commit()
    except ValueError as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=400)
    finally:
        cur.close(); conn.close()

    try:
        mat_name = delete_fin_material(material_id, request.mobile_user["user_id"])
        return mobile_api_response(
            ok=True, message=f'Barang "{mat_name}" berhasil dihapus', data={})
    except ValueError as e:
        status = 404 if "tidak ditemukan" in str(e) else 400
        return mobile_api_response(ok=False, message=str(e), status_code=status)


# ════════════════════════════════════════════════════════════════
#  MATERIALS
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/materials", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def get_materials():
    """Daftar material aktif beserta stok saat ini"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    rows, total_value = list_fin_materials()
    return mobile_api_response(ok=True, message="OK", data=_clean({
        "materials":   rows,
        "total_value": total_value,
    }))


# ════════════════════════════════════════════════════════════════
#  TAMBAH MATERIAL BARU KE GUDANG
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/materials", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def add_material():
    """
    Buat material baru di fin_materials.
    Opsional: tambah stok awal sekaligus via AVCO.
    Body JSON:
    {
        "name":          "BC",
        "unit":          "kg",          // opsional, default "kg"
        "init_qty":      100.0,         // opsional, stok awal
        "init_price":    185000,        // opsional, HPP awal (wajib jika init_qty > 0)
        "note":          "..."          // opsional
    }
    Returns: { "material_id": ..., "name": "BC" }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()

    try:
        result = add_fin_material(
            name=name,
            unit=data.get("unit"),
            init_qty=data.get("init_qty"),
            init_price=data.get("init_price"),
            note=data.get("note"),
            created_by=request.mobile_user.get("id"),
        )
        return mobile_api_response(ok=True,
            message=f"Barang '{result['name']}' berhasil ditambahkan.",
            data=_clean(result))
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


# ════════════════════════════════════════════════════════════════
#  TAMBAH STOK KE BARANG YANG SUDAH ADA
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/materials/<int:material_id>/add-stock",
                         methods=["POST", "OPTIONS"])
@mobile_api_login_required
def add_material_stock(material_id):
    """
    Tambah stok untuk barang gudang yang sudah ada (mis. stoknya masih 0),
    tanpa lewat alur Nota/Kasir Beli formal ke pemasok.
    Body JSON: { "qty": 10.0, "price": 185000, "note": "..." (opsional) }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}

    try:
        result = add_fin_material_stock(
            material_id,
            qty=data.get("qty"),
            price=data.get("price"),
            note=data.get("note"),
            created_by=request.mobile_user.get("id"),
        )
        return mobile_api_response(ok=True,
            message=f"Stok '{result['name']}' berhasil ditambah.",
            data=_clean(result))
    except ValueError as e:
        status = 404 if "tidak ditemukan" in str(e) else 400
        return mobile_api_response(ok=False, message=str(e), status_code=status)


@mobile_finance_bp.route("/finance/materials/<int:material_id>/opname",
                         methods=["POST", "OPTIONS"])
@mobile_api_login_required
def material_opname(material_id):
    """
    Opname stok: bandingkan stok fisik hasil timbang vs stok buku, sistem
    otomatis catat selisihnya sbg koreksi-tambah atau susut -- mirror
    /finance/materials/<id>/opname web.
    Body JSON: { "actual_qty": 120.5, "note": "..." (opsional), "price": ... (opsional) }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}
    from core import perform_stock_opname
    try:
        result = perform_stock_opname(
            material_id,
            actual_qty=data.get("actual_qty"),
            note=data.get("note"),
            created_by=request.mobile_user.get("id"),
            price=data.get("price"),
        )
        if result["type"] == "sesuai":
            msg = f"Stok '{result['name']}' sudah sesuai, tidak ada penyesuaian."
        elif result["type"] == "koreksi_tambah":
            msg = f"Opname: ditemukan kelebihan {result['diff']:.1f} -- stok dikoreksi tambah."
        else:
            msg = f"Opname: ditemukan susut {abs(result['diff']):.1f}."
        return mobile_api_response(ok=True, message=msg, data=_clean(result))
    except ValueError as e:
        status = 404 if "tidak ditemukan" in str(e) else 400
        return mobile_api_response(ok=False, message=str(e), status_code=status)


# ════════════════════════════════════════════════════════════════
#  BATALKAN NOTA (Jual/Beli) — balikkan stok+HPP & hutang otomatis
# ════════════════════════════════════════════════════════════════
@mobile_finance_bp.route("/finance/transactions/<int:txn_id>/cancel",
                         methods=["POST", "OPTIONS"])
@mobile_api_login_required
def cancel_nota_transaction(txn_id):
    """
    Batalkan nota Jual/Beli dari Riwayat Nota.
    - Stok & HPP gudang dibalikkan otomatis (kebalikan arah movement asal)
    - Hutang/piutang terkait dihapus (ditolak jika sudah ada cicilan)
    - Nota ditandai cancelled_at sehingga hilang dari Riwayat Nota
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    from core import cancel_fin_transaction
    try:
        cancel_fin_transaction(txn_id, request.mobile_user.get("id"))
        return mobile_api_response(
            ok=True,
            message="Nota berhasil dibatalkan, stok & HPP gudang sudah dikembalikan.",
            data={"transaction_id": txn_id})
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


# ════════════════════════════════════════════════════════════════
#  PENGELUARAN OPERASIONAL
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/expense", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def kasir_pengeluaran():
    """
    Input pengeluaran (ongkir, makan, dll).
    Body JSON:
    {
        "items": [
            {"expense_name": "Ongkir", "subtotal": 500000},
            {"expense_name": "Makan",  "subtotal": 150000}
        ],
        "note": "Perjalanan Jakarta"
    }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data  = request.get_json(silent=True) or {}
    items = data.get("items", [])

    try:
        result = create_fin_expense(
            note=data.get("note"),
            items=items,
            created_by=request.mobile_user.get("id"),
        )
        return mobile_api_response(ok=True, message="Pengeluaran dicatat.", data=result)
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


# ════════════════════════════════════════════════════════════════
#  LAPORAN HARIAN
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/report/daily", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def report_daily():
    """
    GET /api/mobile/finance/report/daily?date=2026-04-28
    Laporan keuangan harian.
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    date_str = request.args.get("date", str(date.today()))
    try:
        report_date = date.fromisoformat(date_str)
    except ValueError:
        report_date = date.today()

    return mobile_api_response(ok=True, message="OK", data=get_fin_daily_report(report_date))


# ════════════════════════════════════════════════════════════════
#  LAPORAN MINGGUAN
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/report/weekly", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def report_weekly():
    """GET /api/mobile/finance/report/weekly?week=2026-04-21"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    week_str = request.args.get("week", "")
    try:
        week_start = date.fromisoformat(week_str)
        week_start = week_start - timedelta(days=week_start.weekday())
    except (ValueError, TypeError):
        today      = date.today()
        week_start = today - timedelta(days=today.weekday())
    week_end = week_start + timedelta(days=6)

    return mobile_api_response(
        ok=True, message="OK",
        data=get_fin_weekly_report(week_start, week_end))


# ════════════════════════════════════════════════════════════════
#  HUTANG & PIUTANG
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/debts", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def get_debts():
    """Daftar hutang & piutang yang belum lunas"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    return mobile_api_response(ok=True, message="OK", data=list_fin_debts())


@mobile_finance_bp.route("/finance/debts/<int:debt_id>/pay", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def pay_debt(debt_id):
    """Tandai hutang/piutang sebagai lunas atau sebagian bayar"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data       = request.get_json(silent=True) or {}
    pay_amount = data.get("amount", 0)

    try:
        result = pay_fin_debt(debt_id, pay_amount)
        return mobile_api_response(ok=True,
            message="Lunas! 🎉" if result["is_settled"] else "Pembayaran dicatat.",
            data=result)
    except ValueError as e:
        status = 404 if "tidak ditemukan" in str(e) else 400
        return mobile_api_response(ok=False, message=str(e), status_code=status)


@mobile_finance_bp.route("/finance/debts/add", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def add_debt():
    """Catat hutang/piutang manual (bukan tertaut nota) -- mirror /finance/debts/add web."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}
    from core import create_fin_debt_entry
    try:
        result = create_fin_debt_entry(
            debt_type=data.get("type"),
            party_name=data.get("party_name"),
            amount=data.get("amount"),
            note=data.get("note"),
            entry_date=data.get("date"),
            reason=data.get("reason"),
        )
        return mobile_api_response(ok=True, message="Berhasil dicatat.", data=_clean(result))
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


@mobile_finance_bp.route("/finance/debts/<int:debt_id>/edit", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def edit_debt(debt_id):
    """Ubah nama/jumlah/catatan hutang-piutang -- mirror /finance/debts/<id>/edit web."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}
    from core import edit_fin_debt
    try:
        result = edit_fin_debt(
            debt_id,
            party_name=data.get("party_name"),
            amount=data.get("amount"),
            note=data.get("note"),
        )
        return mobile_api_response(ok=True, message="Berhasil diubah.", data=_clean(result))
    except ValueError as e:
        status = 404 if "tidak ditemukan" in str(e) else 400
        return mobile_api_response(ok=False, message=str(e), status_code=status)


@mobile_finance_bp.route("/finance/debts/<int:debt_id>/delete", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def delete_debt(debt_id):
    """Hapus 1 baris hutang/piutang -- mirror /finance/debts/<id>/delete web."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    from core import delete_fin_debt
    try:
        party_name = delete_fin_debt(debt_id)
        return mobile_api_response(ok=True, message="Berhasil dihapus.", data={"party_name": party_name})
    except ValueError as e:
        status = 404 if "tidak ditemukan" in str(e) else 400
        return mobile_api_response(ok=False, message=str(e), status_code=status)


@mobile_finance_bp.route("/finance/debts/send-reminder", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def send_debts_reminder():
    """
    Kirim pengingat WA utk sekumpulan baris hutang/piutang TERPILIH (1
    atau banyak, boleh campur pihak) -- mirror /finance/debts/send-reminder
    web, cuma body-nya JSON list (bukan comma-separated form).
    Body JSON: { "debt_ids": [1, 2, 3] }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}
    from core import send_fin_debts_wa_reminder
    try:
        result = send_fin_debts_wa_reminder(data.get("debt_ids") or [])
        return mobile_api_response(ok=True, message="OK", data=_clean(result))
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


# ════════════════════════════════════════════════════════════════
#  SALDO MITRA — Master Mitra + pengingat WA
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/mitra", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def get_parties():
    """Daftar Master Mitra + saldo piutang/hutang -- mirror /finance/mitra web."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    from core import list_fin_parties
    return mobile_api_response(ok=True, message="OK", data=_clean(list_fin_parties(search=request.args.get("q"))))


@mobile_finance_bp.route("/finance/mitra/add", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def add_party():
    """Tambah mitra baru -- mirror /finance/mitra/add web."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}
    from core import create_fin_party
    try:
        new_id = create_fin_party(data.get("name"), data.get("phone"), data.get("note"))
        return mobile_api_response(ok=True, message="Mitra berhasil ditambahkan.", data={"id": new_id})
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


@mobile_finance_bp.route("/finance/mitra/<int:party_id>", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def get_party_detail(party_id):
    """Detail 1 mitra + rincian hutang/piutang terbuka -- mirror /finance/mitra/<id> web."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    from core import get_fin_party_detail
    try:
        return mobile_api_response(ok=True, message="OK", data=_clean(get_fin_party_detail(party_id)))
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=404)


@mobile_finance_bp.route("/finance/mitra/<int:party_id>/edit", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def edit_party(party_id):
    """Ubah data mitra -- mirror /finance/mitra/<id>/edit web."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}
    from core import update_fin_party
    try:
        update_fin_party(party_id, data.get("name"), data.get("phone"), data.get("note"))
        return mobile_api_response(ok=True, message="Mitra berhasil diperbarui.", data={})
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


@mobile_finance_bp.route("/finance/mitra/<int:party_id>/delete", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def delete_party(party_id):
    """Hapus mitra -- mirror /finance/mitra/<id>/delete web."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    from core import delete_fin_party
    try:
        delete_fin_party(party_id)
        return mobile_api_response(ok=True, message="Mitra berhasil dihapus.", data={})
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


@mobile_finance_bp.route("/finance/mitra/<int:party_id>/send-reminder", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def send_party_reminder(party_id):
    """Kirim pengingat WA ke SEMUA saldo terbuka 1 mitra -- mirror /finance/mitra/<id>/send-reminder web."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    from core import send_fin_party_wa_reminder
    try:
        send_fin_party_wa_reminder(party_id)
        return mobile_api_response(ok=True, message="Pengingat WA sedang dikirim.", data={})
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


# ════════════════════════════════════════════════════════════════
#  LAPORAN MARGIN & SUSUT
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/margin-report", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def margin_report():
    """GET /api/mobile/finance/margin-report?from=&to= -- mirror /finance/margin-report web."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    today = date.today()
    date_from = request.args.get("from") or today.replace(day=1).isoformat()
    date_to = request.args.get("to") or today.isoformat()

    from core import get_fin_margin_report
    return mobile_api_response(ok=True, message="OK", data=_clean(get_fin_margin_report(date_from, date_to)))


@mobile_finance_bp.route("/finance/shrinkage-report", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def shrinkage_report():
    """GET /api/mobile/finance/shrinkage-report?from=&to= -- mirror /finance/shrinkage-report web."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    today = date.today()
    date_from = request.args.get("from") or today.replace(day=1).isoformat()
    date_to = request.args.get("to") or today.isoformat()

    from core import get_fin_shrinkage_report
    return mobile_api_response(ok=True, message="OK", data=_clean(get_fin_shrinkage_report(date_from, date_to)))


# ════════════════════════════════════════════════════════════════
#  DIAGNOSTIK HPP & PELANGGAN MENGUNTUNGKAN (khusus Owner)
# ════════════════════════════════════════════════════════════════

def _check_owner_access(mobile_user):
    role = (mobile_user.get("role") or "").strip().lower()
    if role != "owner":
        return mobile_api_response(ok=False, message="Khusus Owner.", status_code=403)
    return None


@mobile_finance_bp.route("/finance/hpp-diagnostics", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def hpp_diagnostics():
    """GET /api/mobile/finance/hpp-diagnostics -- mirror /finance/hpp-diagnostics web (owner-only)."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_owner_access(request.mobile_user)
    if deny: return deny

    from core import get_fin_hpp_orphan_report
    return mobile_api_response(ok=True, message="OK", data=_clean(get_fin_hpp_orphan_report()))


@mobile_finance_bp.route("/finance/customer-profitability", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def customer_profitability():
    """GET /api/mobile/finance/customer-profitability?from=&to= -- mirror /finance/customer-profitability web (owner-only)."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_owner_access(request.mobile_user)
    if deny: return deny

    today = date.today()
    date_from = request.args.get("from") or today.replace(day=1).isoformat()
    date_to = request.args.get("to") or today.isoformat()

    from core import get_fin_customer_profitability_report
    return mobile_api_response(ok=True, message="OK", data=_clean(get_fin_customer_profitability_report(date_from, date_to)))


# ════════════════════════════════════════════════════════════════
#  STOK — History per material
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/stock/<int:material_id>/history",
                          methods=["GET", "OPTIONS"])
@mobile_api_login_required
def stock_history(material_id):
    """Riwayat pergerakan stok per material"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    return mobile_api_response(ok=True, message="OK", data=get_fin_stock_history(material_id))

# ════════════════════════════════════════════════════════════════
#  INVOICE — Buat nota dari stok gudang
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/invoice", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def create_invoice():
    """
    Buat invoice dari stok fin_materials (bukan products global).
    Body JSON:
    {
        "header": {
            "customer_name":  "Bu Sari",
            "customer_phone": "081234567890",
            "payment_method": "CASH",
            "notes":          "...",
            "discount":       0,
            "is_paid":        "1",
            "adjustments":    [{"type": "DP"|"ONGKIR", "amount": 0, "mode": "BEBAN"|"POTONGAN", "category": "..."}],
            "credit_applied": 0,
            "nota_date":      "2026-04-28"
        },
        "items": [
            {"material_id": 1, "qty": 2.5, "price": 200000, "note": "...", "is_return": false}
        ]
    }
    Returns: { "invoice_id": ..., "invoice_no": "INV-20260502-0001" }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data   = request.get_json(silent=True) or {}
    header = data.get("header", {})
    items  = data.get("items", [])

    customer_name  = (header.get("customer_name")  or "").strip()
    customer_phone = (header.get("customer_phone") or "").strip()
    payment_method = (header.get("payment_method") or "CASH").strip().upper()
    notes          = (header.get("notes")          or "").strip()
    discount       = float(header.get("discount", 0) or 0)
    is_paid        = str(header.get("is_paid", "1")) == "1"
    adjustments    = header.get("adjustments") or []
    credit_applied = header.get("credit_applied", 0)
    nota_date      = (header.get("nota_date") or "").strip() or None

    from core import create_fin_invoice
    try:
        result = create_fin_invoice(
            customer_name=customer_name,
            customer_phone=customer_phone,
            payment_method=payment_method,
            notes=notes,
            discount=discount,
            is_paid=is_paid,
            items=items,
            created_by=request.mobile_user.get("id"),
            adjustments=adjustments,
            credit_applied=credit_applied,
            nota_date=nota_date,
        )
        return mobile_api_response(ok=True, message="Invoice berhasil dibuat.", data=_clean(result))
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


# ════════════════════════════════════════════════════════════════
#  PURCHASE INVOICE — Nota Beli resmi (nomor BELI-..., adjustments,
#  saldo, tanggal manual) -- simetris dgn create_invoice() di atas.
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/purchase-invoice", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def create_purchase_invoice():
    """
    Buat nota BELI_GUDANG resmi (nomor "BELI-YYYYMMDD-####") dari stok
    fin_materials -- versi mobile dari alur Nota Beli web (create_fin_purchase_invoice).
    Body JSON:
    {
        "header": {
            "supplier_name":  "Pak Budi",
            "supplier_phone": "081234567890",
            "payment_method": "CASH",
            "notes":          "...",
            "is_paid":        "1",
            "adjustments":    [{"type": "DP"|"ONGKIR", "amount": 0, "mode": "BEBAN"|"POTONGAN", "category": "..."}],
            "credit_applied": 0,
            "nota_date":      "2026-04-28"
        },
        "items": [
            {"material_id": 1, "qty": 2.5, "price": 200000, "note": "...", "is_return": false}
        ]
    }
    Returns: { "invoice_id": ..., "invoice_no": "BELI-20260502-0001", ... }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data   = request.get_json(silent=True) or {}
    header = data.get("header", {})
    items  = data.get("items", [])

    supplier_name  = (header.get("supplier_name")  or "").strip()
    supplier_phone = (header.get("supplier_phone") or "").strip()
    payment_method = (header.get("payment_method") or "CASH").strip().upper()
    notes          = (header.get("notes")          or "").strip()
    is_paid        = str(header.get("is_paid", "1")) == "1"
    adjustments    = header.get("adjustments") or []
    credit_applied = header.get("credit_applied", 0)
    nota_date      = (header.get("nota_date") or "").strip() or None

    from core import create_fin_purchase_invoice
    try:
        result = create_fin_purchase_invoice(
            supplier_name=supplier_name,
            supplier_phone=supplier_phone,
            payment_method=payment_method,
            notes=notes,
            discount=0,
            is_paid=is_paid,
            items=items,
            created_by=request.mobile_user.get("id"),
            adjustments=adjustments,
            credit_applied=credit_applied,
            nota_date=nota_date,
        )
        return mobile_api_response(ok=True, message="Nota Beli berhasil dibuat.", data=_clean(result))
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


# ════════════════════════════════════════════════════════════════
#  SALDO HUTANG/PIUTANG PIHAK — dicek saat bikin nota, spy bisa
#  dipotongkan otomatis sbg DP (mirror /nota/check-credit di web).
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/party-balances", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def party_balances():
    """
    Daftar saldo piutang/hutang terbuka digabung per nama pihak -- dipakai
    tampilkan chip "klik utk pilih" di form Nota mobile, mirror open_piutang/
    open_hutang yg dikirim ke templates/invoice_form.html web.
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    debt_type = (request.args.get("type") or "PIUTANG").strip().upper()
    if debt_type not in ("PIUTANG", "HUTANG"):
        debt_type = "PIUTANG"

    reason = (request.args.get("reason") or "").strip().upper() or None
    if reason not in (None, "TITIP_DANA", "HUTANG_BARANG"):
        reason = None

    from core import list_fin_party_balances
    return mobile_api_response(ok=True, message="OK",
        data=_clean(list_fin_party_balances(debt_type, reason=reason)))


@mobile_finance_bp.route("/finance/party-names", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def party_names():
    """Daftar semua nama pihak yg pernah dipakai (nota + hutang/piutang) --
    dipakai LOV "riwayat nama" saat klik field nama di form Nota mobile."""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))
    deny = _check_access(request.mobile_user)
    if deny: return deny

    from core import list_fin_party_names
    return mobile_api_response(ok=True, message="OK", data=_clean(list_fin_party_names()))


@mobile_finance_bp.route("/finance/party-credit", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def party_credit():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    party_name  = request.args.get("party_name") or ""
    credit_type = (request.args.get("type") or "PIUTANG").strip().upper()
    if credit_type not in ("PIUTANG", "HUTANG"):
        credit_type = "PIUTANG"

    from core import find_party_credit
    credit = find_party_credit(party_name, credit_type)
    if not credit:
        return mobile_api_response(ok=True, message="OK", data={"available": 0, "party_name": None})
    return mobile_api_response(ok=True, message="OK", data=_clean(credit))


# ════════════════════════════════════════════════════════════════
#  PROFIL PERUSAHAAN — logo & nama umum (bukan per akun), sumber
#  tunggal dipakai web & mobile bersama (company_profile, 1 baris DB).
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/company-profile", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def company_profile_get():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    from core import get_company_profile
    return mobile_api_response(ok=True, message="OK", data=get_company_profile())


@mobile_finance_bp.route("/finance/company-profile", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def company_profile_set():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data          = request.get_json(silent=True) or {}
    company_name  = (data.get("company_name") or "").strip()
    address       = (data.get("address") or "").strip()
    phone         = (data.get("phone") or "").strip()
    logo_base64   = data.get("logo_base64")
    logo_mime     = (data.get("logo_mime") or "image/png").strip()

    logo_data_uri = None
    if logo_base64:
        if len(logo_base64) > 3_800_000:  # ~2.8MB raw, sama batasnya dgn web
            return mobile_api_response(ok=False, message="Ukuran logo terlalu besar (maks ~2.8MB).", status_code=400)
        logo_data_uri = f"data:{logo_mime};base64,{logo_base64}"

    from core import set_company_profile, get_company_profile
    set_company_profile(
        company_name or None, logo_data_uri, request.mobile_user.get("id"),
        address=address or None, phone=phone or None,
    )
    return mobile_api_response(ok=True, message="Profil perusahaan tersimpan.", data=get_company_profile())


# ════════════════════════════════════════════════════════════════
#  DRAFT NOTA — dibagikan ke SEMUA admin/owner (mirror /nota web),
#  supaya nota yang belum selesai diisi bisa dilanjutkan oleh admin
#  lain, bukan cuma tersimpan lokal di 1 HP.
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/nota-drafts", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def nota_drafts_list():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))
    deny = _check_access(request.mobile_user)
    if deny: return deny

    from core import list_nota_drafts
    return mobile_api_response(ok=True, message="OK", data=_clean(list_nota_drafts()))


@mobile_finance_bp.route("/finance/nota-drafts/save", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def nota_drafts_save():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))
    deny = _check_access(request.mobile_user)
    if deny: return deny

    data       = request.get_json(silent=True) or {}
    nota_type  = data.get("nota_type") or "JUAL"
    draft_name = data.get("draft_name") or ""
    form_data  = data.get("form_data") or {}

    from core import save_nota_draft
    try:
        draft = save_nota_draft(
            user_id=request.mobile_user.get("id"),
            nota_type=nota_type, draft_name=draft_name, form_data=form_data,
        )
        return mobile_api_response(ok=True, message="Draft tersimpan, bisa dilihat semua admin.", data=_clean(draft))
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


@mobile_finance_bp.route("/finance/nota-drafts/<int:draft_id>/delete", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def nota_drafts_delete(draft_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))
    deny = _check_access(request.mobile_user)
    if deny: return deny

    from core import delete_nota_draft
    try:
        delete_nota_draft(draft_id)
        return mobile_api_response(ok=True, message="Draft dihapus.", data={"id": draft_id})
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)


# ════════════════════════════════════════════════════════════════
#  FASE 2 — PERJALANAN JAKARTA
# ════════════════════════════════════════════════════════════════

# ── Buka perjalanan baru ──────────────────────────────────────
@mobile_finance_bp.route("/finance/trips/new", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def trip_new():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_access(request.mobile_user)
    if deny: return deny

    data      = request.get_json(silent=True) or {}
    note      = (data.get("note") or "").strip()
    trip_date = data.get("trip_date") or str(date.today())

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Perjalanan sekarang selalu diinput langsung oleh admin/owner yang
        # login di app (lihat endpoint /finance/trips/<id>/sell,buy,expense,
        # dst di bawah) — tidak ada lagi jalur PIN tanpa-login untuk
        # karyawan lapangan. `pin` tetap diisi acak untuk kompatibilitas
        # kolom (kalau NOT NULL di DB) tapi tidak pernah dikembalikan ke
        # klien / dipakai untuk otorisasi.
        import random as _rand
        pin = ''.join(_rand.choices('0123456789', k=4))

        cur.execute("""
            INSERT INTO fin_trips (trip_date, note, status, created_by, pin)
            VALUES (%s, %s, 'OPEN', %s, %s)
            RETURNING id, trip_date, note, status, created_at;
        """, (trip_date, note or None, request.mobile_user.get("id"), pin))
        trip = _clean(dict(cur.fetchone()))
        conn.commit()
        return mobile_api_response(ok=True, message="Perjalanan dibuka.", data=trip)
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()


# ── List semua perjalanan ─────────────────────────────────────
@mobile_finance_bp.route("/finance/trips", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def trip_list():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_access(request.mobile_user)
    if deny: return deny

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT t.*,
                COUNT(DISTINCT i.id) AS total_items
            FROM fin_trips t
            LEFT JOIN fin_trip_items i ON i.trip_id = t.id
            GROUP BY t.id
            ORDER BY t.created_at DESC
            LIMIT 30;
        """)
        rows = _clean([dict(r) for r in cur.fetchall()])
        return mobile_api_response(ok=True, message="OK", data={"trips": rows})
    finally:
        cur.close(); conn.close()


# ── Detail 1 perjalanan ───────────────────────────────────────
@mobile_finance_bp.route("/finance/trips/<int:trip_id>", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def trip_detail(trip_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_access(request.mobile_user)
    if deny: return deny

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Header
        cur.execute("SELECT * FROM fin_trips WHERE id = %s;", (trip_id,))
        trip = cur.fetchone()
        if not trip:
            return mobile_api_response(ok=False, message="Tidak ditemukan.", status_code=404)

        # Lapak
        cur.execute("""
            SELECT * FROM fin_trip_parties
            WHERE trip_id = %s ORDER BY created_at;
        """, (trip_id,))
        parties = _clean([dict(r) for r in cur.fetchall()])

        # Items
        cur.execute("""
            SELECT i.*, m.name AS material_name,
                   p.name AS party_name
            FROM fin_trip_items i
            LEFT JOIN fin_materials m ON m.id = i.material_id
            LEFT JOIN fin_trip_parties p ON p.id = i.party_id
            WHERE i.trip_id = %s
            ORDER BY i.created_at;
        """, (trip_id,))
        items = _clean([dict(r) for r in cur.fetchall()])

        # Ringkasan
        total_jual    = sum(float(i['subtotal'] or 0) for i in items if i['type'] == 'JUAL')
        total_beli    = sum(float(i['subtotal'] or 0) for i in items if i['type'] == 'BELI')
        total_expense = sum(float(i['subtotal'] or 0) for i in items if i['type'] == 'EXPENSE')
        net           = total_jual - total_beli - total_expense

        return mobile_api_response(ok=True, message="OK", data=_clean({
            "trip":    dict(trip),
            "parties": parties,
            "items":   items,
            "summary": {
                "total_jual":    total_jual,
                "total_beli":    total_beli,
                "total_expense": total_expense,
                "net_result":    net,
            }
        }))
    finally:
        cur.close(); conn.close()


# ── Tambah lapak ──────────────────────────────────────────────
@mobile_finance_bp.route("/finance/trips/<int:trip_id>/party", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def trip_add_party(trip_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_access(request.mobile_user)
    if deny: return deny

    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    if not name:
        return mobile_api_response(ok=False, message="Nama lapak wajib diisi.", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            INSERT INTO fin_trip_parties (trip_id, name, note)
            VALUES (%s, %s, %s) RETURNING *;
        """, (trip_id, name, (data.get("note") or "").strip() or None))
        party = _clean(dict(cur.fetchone()))
        conn.commit()
        return mobile_api_response(ok=True, message="Lapak ditambahkan.", data=party)
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()


# ── Jual ke lapak Jakarta ─────────────────────────────────────
@mobile_finance_bp.route("/finance/trips/<int:trip_id>/sell", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def trip_sell(trip_id):
    """
    {
        "party_id": 1,
        "payment_type": "CASH",   // CASH / TRANSFER / HUTANG
        "party_name": "Lapak A",  // opsional jika party_id ada
        "items": [
            {"material_id": 1, "qty_kg": 50, "price_per_kg": 205000}
        ]
    }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_access(request.mobile_user)
    if deny: return deny

    data         = request.get_json(silent=True) or {}
    party_id     = data.get("party_id")
    payment_type = (data.get("payment_type") or "CASH").upper()
    items        = data.get("items", [])
    note         = (data.get("note") or "").strip()

    if not items:
        return mobile_api_response(ok=False, message="Minimal 1 item.", status_code=400)
    if payment_type not in ("CASH", "TRANSFER", "HUTANG"):
        payment_type = "CASH"

    is_debt = payment_type == "HUTANG"

    from core import _ensure_fin_debts_reason_schema, _ensure_fin_trip_items_cost_column

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        _ensure_fin_debts_reason_schema(cur)
        _ensure_fin_trip_items_cost_column(conn, cur)
        # Pastikan trip masih OPEN
        cur.execute("SELECT status FROM fin_trips WHERE id = %s;", (trip_id,))
        t = cur.fetchone()
        if not t or t["status"] != "OPEN":
            return mobile_api_response(ok=False, message="Perjalanan sudah ditutup.", status_code=400)

        # Auto-buat party jika party_name dikirim tanpa party_id
        if not party_id and data.get("party_name"):
            cur.execute("""
                INSERT INTO fin_trip_parties (trip_id, name)
                VALUES (%s, %s) RETURNING id;
            """, (trip_id, data["party_name"].strip()))
            party_id = cur.fetchone()["id"]

        total = 0.0
        for item in items:
            mat_id   = int(item["material_id"])
            qty      = float(item["qty_kg"])
            price    = float(item["price_per_kg"])
            subtotal = qty * price
            total   += subtotal

            # Ambil HPP rata-rata saat ini untuk hitung laba
            cur.execute("""
                SELECT COALESCE(avg_cost_per_kg, 0) AS avg
                FROM fin_stock_summary WHERE material_id = %s;
            """, (mat_id,))
            row = cur.fetchone()
            avg = float(row["avg"]) if row else 0

            cur.execute("""
                INSERT INTO fin_trip_items
                    (trip_id, party_id, type, material_id,
                     qty_kg, price_per_kg, subtotal,
                     payment_type, is_debt, note, cost_per_kg)
                VALUES (%s, %s, 'JUAL', %s, %s, %s, %s, %s, %s, %s, %s);
            """, (trip_id, party_id, mat_id, qty, price, subtotal,
                  payment_type, is_debt, note or None, avg))

            # Update stok — stok keluar saat dijual
            _update_stock_avco(cur, mat_id, qty, avg, 'OUT', None,
                               note=f"Jual perjalanan trip#{trip_id}")

        # Catat piutang jika hutang
        if is_debt and party_id:
            cur.execute("SELECT name FROM fin_trip_parties WHERE id = %s;", (party_id,))
            prow = cur.fetchone()
            pname = prow["name"] if prow else "Lapak Jakarta"
            cur.execute("""
                INSERT INTO fin_debts
                    (type, party_name, party_type, amount, remaining, note, reason)
                VALUES ('PIUTANG', %s, 'LAPAK_JKT', %s, %s, %s, 'HUTANG_BARANG');
            """, (pname, total, total, f"Jual perjalanan trip#{trip_id}"))

        conn.commit()
        return mobile_api_response(ok=True, message="Penjualan dicatat.", data={"total": total})
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()


# ── Beli barang di Jakarta ────────────────────────────────────
@mobile_finance_bp.route("/finance/trips/<int:trip_id>/buy", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def trip_buy(trip_id):
    """
    {
        "party_name": "Supplier Jakarta",
        "items": [
            {"material_id": 1, "qty_kg": 30, "price_per_kg": 190000}
        ]
    }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_access(request.mobile_user)
    if deny: return deny

    data  = request.get_json(silent=True) or {}
    items = data.get("items", [])
    note  = (data.get("note") or "").strip()

    if not items:
        return mobile_api_response(ok=False, message="Minimal 1 item.", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT status FROM fin_trips WHERE id = %s;", (trip_id,))
        t = cur.fetchone()
        if not t or t["status"] != "OPEN":
            return mobile_api_response(ok=False, message="Perjalanan sudah ditutup.", status_code=400)

        total = 0.0
        for item in items:
            mat_id   = int(item["material_id"])
            qty      = float(item["qty_kg"])
            price    = float(item["price_per_kg"])
            subtotal = qty * price
            total   += subtotal

            cur.execute("""
                INSERT INTO fin_trip_items
                    (trip_id, type, material_id, qty_kg,
                     price_per_kg, subtotal, note)
                VALUES (%s, 'BELI', %s, %s, %s, %s, %s);
            """, (trip_id, mat_id, qty, price, subtotal, note or None))

            # Stok masuk
            _update_stock_avco(cur, mat_id, qty, price, 'IN', None,
                               note=f"Beli Jakarta trip#{trip_id}")

        conn.commit()
        return mobile_api_response(ok=True, message="Pembelian dicatat.", data={"total": total})
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()


# ── Pengeluaran perjalanan ────────────────────────────────────
@mobile_finance_bp.route("/finance/trips/<int:trip_id>/expense", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def trip_expense(trip_id):
    """
    {
        "items": [
            {"expense_name": "Ongkir", "subtotal": 2500000},
            {"expense_name": "Makan",  "subtotal": 300000}
        ]
    }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_access(request.mobile_user)
    if deny: return deny

    data  = request.get_json(silent=True) or {}
    items = data.get("items", [])

    if not items:
        return mobile_api_response(ok=False, message="Minimal 1 pengeluaran.", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT status FROM fin_trips WHERE id = %s;", (trip_id,))
        t = cur.fetchone()
        if not t or t["status"] != "OPEN":
            return mobile_api_response(ok=False, message="Perjalanan sudah ditutup.", status_code=400)

        total = 0.0
        for item in items:
            subtotal = float(item.get("subtotal", 0))
            total   += subtotal
            cur.execute("""
                INSERT INTO fin_trip_items
                    (trip_id, type, expense_name, subtotal)
                VALUES (%s, 'EXPENSE', %s, %s);
            """, (trip_id,
                  (item.get("expense_name") or "Pengeluaran").strip(),
                  subtotal))

        conn.commit()
        return mobile_api_response(ok=True, message="Pengeluaran dicatat.", data={"total": total})
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()


# ── Balikan barang ────────────────────────────────────────────
@mobile_finance_bp.route("/finance/trips/<int:trip_id>/return", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def trip_return(trip_id):
    """
    {
        "items": [
            {
                "material_id": 1,
                "qty_kg": 10,
                "return_to_stock": true,   // false = dibuang
                "note": "barang kotor"
            }
        ]
    }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_access(request.mobile_user)
    if deny: return deny

    data  = request.get_json(silent=True) or {}
    items = data.get("items", [])

    if not items:
        return mobile_api_response(ok=False, message="Minimal 1 item.", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT status FROM fin_trips WHERE id = %s;", (trip_id,))
        t = cur.fetchone()
        if not t or t["status"] != "OPEN":
            return mobile_api_response(ok=False, message="Perjalanan sudah ditutup.", status_code=400)

        for item in items:
            mat_id          = int(item["material_id"])
            qty             = float(item["qty_kg"])
            return_to_stock = bool(item.get("return_to_stock", False))
            note            = (item.get("note") or "").strip()

            # Ambil HPP rata-rata untuk valuasi balikan
            cur.execute("""
                SELECT COALESCE(avg_cost_per_kg, 0) AS avg
                FROM fin_stock_summary WHERE material_id = %s;
            """, (mat_id,))
            row   = cur.fetchone()
            avg   = float(row["avg"]) if row else 0
            value = qty * avg

            cur.execute("""
                INSERT INTO fin_trip_items
                    (trip_id, type, material_id, qty_kg,
                     price_per_kg, subtotal,
                     return_to_stock, note)
                VALUES (%s, 'RETURN', %s, %s, %s, %s, %s, %s);
            """, (trip_id, mat_id, qty, avg, value, return_to_stock, note or None))

            # Jika masuk stok kembali
            if return_to_stock:
                _update_stock_avco(cur, mat_id, qty, avg, 'IN', None,
                                   note=f"Balikan trip#{trip_id}")

        conn.commit()
        return mobile_api_response(ok=True, message="Balikan dicatat.")
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()


# ── Tutup perjalanan ──────────────────────────────────────────
@mobile_finance_bp.route("/finance/trips/<int:trip_id>/close", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def trip_close(trip_id):
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_access(request.mobile_user)
    if deny: return deny

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT * FROM fin_trips WHERE id = %s;", (trip_id,))
        t = cur.fetchone()
        if not t:
            return mobile_api_response(ok=False, message="Tidak ditemukan.", status_code=404)
        if t["status"] == "CLOSED":
            return mobile_api_response(ok=False, message="Perjalanan sudah ditutup.", status_code=400)

        # Hitung total
        cur.execute("""
            SELECT
                COALESCE(SUM(CASE WHEN type='JUAL'    THEN subtotal ELSE 0 END), 0) AS jual,
                COALESCE(SUM(CASE WHEN type='BELI'    THEN subtotal ELSE 0 END), 0) AS beli,
                COALESCE(SUM(CASE WHEN type='EXPENSE' THEN subtotal ELSE 0 END), 0) AS expense
            FROM fin_trip_items WHERE trip_id = %s;
        """, (trip_id,))
        totals = cur.fetchone()

        total_jual    = float(totals["jual"]    or 0)
        total_beli    = float(totals["beli"]    or 0)
        total_expense = float(totals["expense"] or 0)
        net           = total_jual - total_beli - total_expense

        cur.execute("""
            UPDATE fin_trips
            SET status       = 'CLOSED',
                total_income  = %s,
                total_expense = %s,
                net_result    = %s,
                closed_at     = NOW()
            WHERE id = %s;
        """, (total_jual, total_beli + total_expense, net, trip_id))

        conn.commit()
        return mobile_api_response(ok=True, message="Perjalanan ditutup.", data=_clean({
            "total_jual":    total_jual,
            "total_beli":    total_beli,
            "total_expense": total_expense,
            "net_result":    net,
        }))
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()

# ════════════════════════════════════════════════
#  TAMBAHKAN ke finance.py — setelah trip_close
# ════════════════════════════════════════════════
 
@mobile_finance_bp.route("/finance/trips/<int:trip_id>/cancel", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def trip_cancel(trip_id):
    """Batalkan perjalanan (ubah status jadi CANCELLED)"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_access(request.mobile_user)
    if deny: return deny
 
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT status FROM fin_trips WHERE id = %s;", (trip_id,))
        t = cur.fetchone()
        if not t:
            return mobile_api_response(ok=False, message="Tidak ditemukan.", status_code=404)
        if t["status"] == "CLOSED":
            return mobile_api_response(ok=False, message="Tidak bisa batalkan perjalanan yang sudah selesai.", status_code=400)
 
        cur.execute("UPDATE fin_trips SET status = 'CANCELLED' WHERE id = %s;", (trip_id,))
        conn.commit()
        return mobile_api_response(ok=True, message="Perjalanan dibatalkan.")
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()
 
 
@mobile_finance_bp.route("/finance/trips/<int:trip_id>", methods=["DELETE", "OPTIONS"])
@mobile_api_login_required
def trip_delete(trip_id):
    """Hapus perjalanan beserta semua item-nya"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})
    deny = _check_access(request.mobile_user)
    if deny: return deny
 
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Items akan auto-delete karena ON DELETE CASCADE
        cur.execute("DELETE FROM fin_trips WHERE id = %s;", (trip_id,))
        conn.commit()
        return mobile_api_response(ok=True, message="Perjalanan dihapus.")
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()


"""
routes/mobile/finance.py

UMGAP Finance — Fase 1
Kasir Gudang + Stok AVCO + Laporan Harian
"""
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from datetime import date, timedelta
from decimal import Decimal

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_finance_bp = Blueprint("mobile_finance", __name__)


# ── Helper: hanya owner & admin yang bisa akses ───────────────
def _check_access(mobile_user):
    role = mobile_user.get("role", "")
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


# ════════════════════════════════════════════════════════════════
#  MATERIALS
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/materials", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def get_materials():
    """Daftar material aktif beserta stok saat ini"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _check_access(request.mobile_user)
    if deny: return deny

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                m.id, m.name, m.unit, m.sort_order,
                COALESCE(s.qty_kg, 0)          AS qty_kg,
                COALESCE(s.avg_cost_per_kg, 0) AS avg_cost_per_kg,
                COALESCE(s.total_value, 0)     AS total_value,
                s.updated_at
            FROM fin_materials m
            LEFT JOIN fin_stock_summary s ON s.material_id = m.id
            WHERE m.is_active = TRUE
            ORDER BY m.sort_order, m.name;
        """)
        rows = [dict(r) for r in cur.fetchall()]

        # Total nilai gudang
        total_value = sum(float(r['total_value'] or 0) for r in rows)

        return mobile_api_response(ok=True, message="OK", data={
            "materials":   rows,
            "total_value": total_value,
        })
    finally:
        cur.close(); conn.close()


# ════════════════════════════════════════════════════════════════
#  KASIR — BELI DARI ORANG (stok masuk)
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/buy", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def kasir_beli():
    """
    Beli dari orang di gudang.
    Body JSON:
    {
        "party_name": "Pak Budi",
        "is_debt": false,
        "note": "...",
        "items": [
            {"material_id": 1, "qty_kg": 50, "price_per_kg": 195000}
        ]
    }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data       = request.get_json(silent=True) or {}
    party_name = (data.get("party_name") or "").strip()
    is_debt    = bool(data.get("is_debt", False))
    note       = (data.get("note") or "").strip()
    items      = data.get("items", [])

    if not items:
        return mobile_api_response(
            ok=False, message="Minimal 1 item barang.", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:

        total = sum(float(i.get("qty_kg", 0)) * float(i.get("price_per_kg", 0))
                    for i in items)

        # Insert transaksi header
        cur.execute("""
            INSERT INTO fin_transactions
                (type, party_name, party_type, note, is_debt, total_amount, created_by)
            VALUES ('BELI_GUDANG', %s, 'PELANGGAN', %s, %s, %s, %s)
            RETURNING id;
        """, (party_name or None, note or None, is_debt, total,
               request.mobile_user.get("id")))
        txn_id = cur.fetchone()["id"]

        # Insert items + update stok AVCO
        for item in items:
            mat_id    = int(item["material_id"])
            qty       = float(item["qty_kg"])
            price     = float(item["price_per_kg"])
            subtotal  = qty * price

            cur.execute("""
                INSERT INTO fin_transaction_items
                    (transaction_id, material_id, qty_kg, price_per_kg, subtotal)
                VALUES (%s, %s, %s, %s, %s);
            """, (txn_id, mat_id, qty, price, subtotal))

            _update_stock_avco(cur, mat_id, qty, price, 'IN', txn_id,
                               note=f"Beli dari {party_name or 'orang'}")

        # Catat hutang jika perlu
        if is_debt and party_name:
            cur.execute("""
                INSERT INTO fin_debts
                    (type, party_name, party_type, amount, remaining, transaction_id, note)
                VALUES ('HUTANG', %s, 'PELANGGAN', %s, %s, %s, %s);
            """, (party_name, total, total, txn_id,
                  f"Beli barang — belum dibayar"))

        conn.commit()
        return mobile_api_response(ok=True, message="Transaksi beli berhasil.", data={
            "transaction_id": txn_id,
            "total":          total,
        })
    except Exception as e:
        conn.rollback()
        return mobile_api_response(
            ok=False, message=f"Gagal: {str(e)}", status_code=500)
    finally:
        cur.close(); conn.close()


# ════════════════════════════════════════════════════════════════
#  KASIR — JUAL KE ORANG (stok keluar)
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/sell", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def kasir_jual():
    """
    Jual ke orang di gudang.
    Body JSON:
    {
        "party_name": "Bu Sari",
        "is_debt": false,
        "note": "...",
        "items": [
            {"material_id": 1, "qty_kg": 30, "price_per_kg": 215000}
        ]
    }
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data       = request.get_json(silent=True) or {}
    party_name = (data.get("party_name") or "").strip()
    is_debt    = bool(data.get("is_debt", False))
    note       = (data.get("note") or "").strip()
    items      = data.get("items", [])

    if not items:
        return mobile_api_response(
            ok=False, message="Minimal 1 item barang.", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:

        total = sum(float(i.get("qty_kg", 0)) * float(i.get("price_per_kg", 0))
                    for i in items)

        # Cek stok cukup untuk semua item
        for item in items:
            mat_id = int(item["material_id"])
            qty    = float(item["qty_kg"])
            cur.execute("""
                SELECT COALESCE(qty_kg, 0) AS qty, name
                FROM fin_stock_summary s
                JOIN fin_materials m ON m.id = s.material_id
                WHERE s.material_id = %s;
            """, (mat_id,))
            stok = cur.fetchone()
            if not stok or float(stok["qty"]) < qty:
                nama = stok["name"] if stok else f"Material #{mat_id}"
                return mobile_api_response(
                    ok=False,
                    message=f"Stok {nama} tidak cukup. "
                            f"Tersedia: {float(stok['qty']) if stok else 0} kg",
                    status_code=400)

        # Insert transaksi header
        cur.execute("""
            INSERT INTO fin_transactions
                (type, party_name, party_type, note, is_debt, total_amount, created_by)
            VALUES ('JUAL_GUDANG', %s, 'PELANGGAN', %s, %s, %s, %s)
            RETURNING id;
        """, (party_name or None, note or None, is_debt, total,
               request.mobile_user.get("id")))
        txn_id = cur.fetchone()["id"]

        # Insert items + update stok
        hpp_total = 0.0
        for item in items:
            mat_id   = int(item["material_id"])
            qty      = float(item["qty_kg"])
            price    = float(item["price_per_kg"])
            subtotal = qty * price

            cur.execute("""
                SELECT COALESCE(avg_cost_per_kg, 0) AS avg
                FROM fin_stock_summary WHERE material_id = %s;
            """, (mat_id,))
            row = cur.fetchone()
            avg = float(row["avg"]) if row else 0

            hpp_total += qty * avg

            cur.execute("""
                INSERT INTO fin_transaction_items
                    (transaction_id, material_id, qty_kg, price_per_kg, subtotal)
                VALUES (%s, %s, %s, %s, %s);
            """, (txn_id, mat_id, qty, price, subtotal))

            _update_stock_avco(cur, mat_id, qty, avg, 'OUT', txn_id,
                               note=f"Jual ke {party_name or 'orang'}")

        # Catat piutang jika belum bayar
        if is_debt and party_name:
            cur.execute("""
                INSERT INTO fin_debts
                    (type, party_name, party_type, amount, remaining, transaction_id, note)
                VALUES ('PIUTANG', %s, 'PELANGGAN', %s, %s, %s, %s);
            """, (party_name, total, total, txn_id, "Jual barang — belum dibayar"))

        conn.commit()

        laba = total - hpp_total
        return mobile_api_response(ok=True, message="Transaksi jual berhasil.", data={
            "transaction_id": txn_id,
            "total":          total,
            "hpp":            hpp_total,
            "laba":           laba,
        })
    except Exception as e:
        conn.rollback()
        return mobile_api_response(
            ok=False, message=f"Gagal: {str(e)}", status_code=500)
    finally:
        cur.close(); conn.close()


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
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data  = request.get_json(silent=True) or {}
    note  = (data.get("note") or "").strip()
    items = data.get("items", [])

    if not items:
        return mobile_api_response(
            ok=False, message="Minimal 1 item pengeluaran.", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:

        total = sum(float(i.get("subtotal", 0)) for i in items)

        cur.execute("""
            INSERT INTO fin_transactions
                (type, note, total_amount, created_by)
            VALUES ('PENGELUARAN', %s, %s, %s)
            RETURNING id;
        """, (note or None, total, request.mobile_user.get("id")))
        txn_id = cur.fetchone()["id"]

        for item in items:
            cur.execute("""
                INSERT INTO fin_transaction_items
                    (transaction_id, expense_name, subtotal)
                VALUES (%s, %s, %s);
            """, (txn_id,
                  (item.get("expense_name") or "Pengeluaran").strip(),
                  float(item.get("subtotal", 0))))

        conn.commit()
        return mobile_api_response(ok=True, message="Pengeluaran dicatat.", data={
            "transaction_id": txn_id,
            "total":          total,
        })
    except Exception as e:
        conn.rollback()
        return mobile_api_response(
            ok=False, message=f"Gagal: {str(e)}", status_code=500)
    finally:
        cur.close(); conn.close()


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
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _check_access(request.mobile_user)
    if deny: return deny

    date_str = request.args.get("date", str(date.today()))
    try:
        report_date = date.fromisoformat(date_str)
    except ValueError:
        report_date = date.today()

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Semua transaksi hari ini
        cur.execute("""
            SELECT
                t.id, t.type, t.party_name, t.total_amount,
                t.is_debt, t.note, t.created_at,
                json_agg(json_build_object(
                    'material_id',  i.material_id,
                    'expense_name', i.expense_name,
                    'qty_kg',       i.qty_kg,
                    'price_per_kg', i.price_per_kg,
                    'subtotal',     i.subtotal,
                    'material_name', m.name
                )) AS items
            FROM fin_transactions t
            LEFT JOIN fin_transaction_items i ON i.transaction_id = t.id
            LEFT JOIN fin_materials m ON m.id = i.material_id
            WHERE t.created_at::date = %s
            GROUP BY t.id
            ORDER BY t.created_at DESC;
        """, (report_date,))
        transactions = [dict(r) for r in cur.fetchall()]

        # Ringkasan
        pemasukan   = sum(float(t["total_amount"] or 0)
                         for t in transactions
                         if t["type"] in ("JUAL_GUDANG", "BELI_JAKARTA",
                                          "TERIMA_HUTANG"))
        pengeluaran = sum(float(t["total_amount"] or 0)
                         for t in transactions
                         if t["type"] in ("BELI_GUDANG", "PENGELUARAN",
                                          "PEMBAYARAN_DP", "BAYAR_HUTANG"))

        # HPP barang yang terjual hari ini
        cur.execute("""
            SELECT COALESCE(SUM(
                i.qty_kg * s.avg_cost_per_kg
            ), 0) AS hpp_total
            FROM fin_transactions t
            JOIN fin_transaction_items i ON i.transaction_id = t.id
            JOIN fin_stock_summary s ON s.material_id = i.material_id
            WHERE t.created_at::date = %s
              AND t.type = 'JUAL_GUDANG'
              AND i.material_id IS NOT NULL;
        """, (report_date,))
        hpp_total = float((cur.fetchone() or {}).get("hpp_total", 0))

        omzet_jual = sum(float(t["total_amount"] or 0)
                        for t in transactions if t["type"] == "JUAL_GUDANG")
        laba_kotor = omzet_jual - hpp_total

        # Nilai stok gudang saat ini
        cur.execute("""
            SELECT COALESCE(SUM(total_value), 0) AS total
            FROM fin_stock_summary;
        """)
        nilai_stok = float((cur.fetchone() or {}).get("total", 0))

        return mobile_api_response(ok=True, message="OK", data={
            "date":         str(report_date),
            "transactions": transactions,
            "summary": {
                "pemasukan":   pemasukan,
                "pengeluaran": pengeluaran,
                "omzet_jual":  omzet_jual,
                "hpp":         hpp_total,
                "laba_kotor":  laba_kotor,
                "nilai_stok":  nilai_stok,
            }
        })
    finally:
        cur.close(); conn.close()


# ════════════════════════════════════════════════════════════════
#  LAPORAN MINGGUAN
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/report/weekly", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def report_weekly():
    """GET /api/mobile/finance/report/weekly?week=2026-04-21"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

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

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                type,
                SUM(total_amount) AS total,
                COUNT(*) AS count
            FROM fin_transactions
            WHERE created_at::date >= %s AND created_at::date <= %s
            GROUP BY type;
        """, (week_start, week_end))
        by_type = {r["type"]: dict(r) for r in cur.fetchall()}

        def _sum(types):
            return sum(float((by_type.get(t) or {}).get("total", 0)) for t in types)

        omzet    = _sum(["JUAL_GUDANG"])
        modal    = _sum(["BELI_GUDANG"])
        biaya    = _sum(["PENGELUARAN", "PEMBAYARAN_DP"])
        masuk    = _sum(["TERIMA_HUTANG"])

        # HPP minggu ini
        cur.execute("""
            SELECT COALESCE(SUM(i.qty_kg * s.avg_cost_per_kg), 0) AS hpp
            FROM fin_transactions t
            JOIN fin_transaction_items i ON i.transaction_id = t.id
            JOIN fin_stock_summary s ON s.material_id = i.material_id
            WHERE t.created_at::date >= %s AND t.created_at::date <= %s
              AND t.type = 'JUAL_GUDANG' AND i.material_id IS NOT NULL;
        """, (week_start, week_end))
        hpp = float((cur.fetchone() or {}).get("hpp", 0))

        laba_kotor  = omzet - hpp
        laba_bersih = laba_kotor - biaya

        # Rekap per hari
        cur.execute("""
            SELECT
                created_at::date AS hari,
                SUM(CASE WHEN type = 'JUAL_GUDANG'  THEN total_amount ELSE 0 END) AS jual,
                SUM(CASE WHEN type = 'BELI_GUDANG'  THEN total_amount ELSE 0 END) AS beli,
                SUM(CASE WHEN type = 'PENGELUARAN'  THEN total_amount ELSE 0 END) AS biaya
            FROM fin_transactions
            WHERE created_at::date >= %s AND created_at::date <= %s
            GROUP BY hari ORDER BY hari;
        """, (week_start, week_end))
        per_hari = [dict(r) for r in cur.fetchall()]

        return mobile_api_response(ok=True, message="OK", data={
            "week_start":   str(week_start),
            "week_end":     str(week_end),
            "week_label":   f"{week_start.strftime('%d %b')} – {week_end.strftime('%d %b %Y')}",
            "summary": {
                "omzet_jual":   omzet,
                "modal_beli":   modal,
                "hpp":          hpp,
                "laba_kotor":   laba_kotor,
                "biaya_ops":    biaya,
                "laba_bersih":  laba_bersih,
                "piutang_masuk": masuk,
            },
            "per_hari": per_hari,
        })
    finally:
        cur.close(); conn.close()


# ════════════════════════════════════════════════════════════════
#  HUTANG & PIUTANG
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/debts", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def get_debts():
    """Daftar hutang & piutang yang belum lunas"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _check_access(request.mobile_user)
    if deny: return deny

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, type, party_name, amount, paid_amount,
                   remaining, due_date, is_settled, note, created_at
            FROM fin_debts
            WHERE is_settled = FALSE
            ORDER BY type, created_at DESC;
        """)
        rows = [dict(r) for r in cur.fetchall()]

        hutang   = [r for r in rows if r["type"] == "HUTANG"]
        piutang  = [r for r in rows if r["type"] == "PIUTANG"]
        total_hutang  = sum(float(r["remaining"]) for r in hutang)
        total_piutang = sum(float(r["remaining"]) for r in piutang)

        return mobile_api_response(ok=True, message="OK", data={
            "hutang":        hutang,
            "piutang":       piutang,
            "total_hutang":  total_hutang,
            "total_piutang": total_piutang,
        })
    finally:
        cur.close(); conn.close()


@mobile_finance_bp.route("/finance/debts/<int:debt_id>/pay", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def pay_debt(debt_id):
    """Tandai hutang/piutang sebagai lunas atau sebagian bayar"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _check_access(request.mobile_user)
    if deny: return deny

    data       = request.get_json(silent=True) or {}
    pay_amount = float(data.get("amount", 0))

    if pay_amount <= 0:
        return mobile_api_response(
            ok=False, message="Jumlah pembayaran harus lebih dari 0.", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT id, amount, paid_amount, remaining, type, party_name
            FROM fin_debts WHERE id = %s;
        """, (debt_id,))
        debt = cur.fetchone()
        if not debt:
            return mobile_api_response(
                ok=False, message="Data tidak ditemukan.", status_code=404)

        new_paid      = float(debt["paid_amount"]) + pay_amount
        new_remaining = max(0, float(debt["amount"]) - new_paid)
        is_settled    = new_remaining <= 0

        cur.execute("""
            UPDATE fin_debts
            SET paid_amount = %s, remaining = %s, is_settled = %s
            WHERE id = %s;
        """, (new_paid, new_remaining, is_settled, debt_id))
        conn.commit()

        return mobile_api_response(ok=True,
            message="Lunas! 🎉" if is_settled else "Pembayaran dicatat.",
            data={
                "paid":       new_paid,
                "remaining":  new_remaining,
                "is_settled": is_settled,
            })
    except Exception as e:
        conn.rollback()
        return mobile_api_response(
            ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()


# ════════════════════════════════════════════════════════════════
#  STOK — History per material
# ════════════════════════════════════════════════════════════════

@mobile_finance_bp.route("/finance/stock/<int:material_id>/history",
                          methods=["GET", "OPTIONS"])
@mobile_api_login_required
def stock_history(material_id):
    """Riwayat pergerakan stok per material"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _check_access(request.mobile_user)
    if deny: return deny

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT l.*, m.name AS material_name
            FROM fin_stock_ledger l
            JOIN fin_materials m ON m.id = l.material_id
            WHERE l.material_id = %s
            ORDER BY l.created_at DESC
            LIMIT 50;
        """, (material_id,))
        rows = [dict(r) for r in cur.fetchall()]

        cur.execute("""
            SELECT qty_kg, avg_cost_per_kg, total_value
            FROM fin_stock_summary WHERE material_id = %s;
        """, (material_id,))
        summary = dict(cur.fetchone() or {})

        return mobile_api_response(ok=True, message="OK", data={
            "current": summary,
            "history": rows,
        })
    finally:
        cur.close(); conn.close()

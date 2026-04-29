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
        rows = _clean([dict(r) for r in cur.fetchall()])

        # Total nilai gudang
        total_value = sum(float(r['total_value'] or 0) for r in rows)

        return mobile_api_response(ok=True, message="OK", data=_clean({
            "materials":   rows,
            "total_value": total_value,
        }))
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
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

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
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

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
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

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
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

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
        # Semua transaksi kasir gudang hari ini
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

        # Transaksi perjalanan Jakarta hari ini (dari fin_trip_items)
        cur.execute("""
            SELECT
                ti.id, ti.type AS trip_item_type,
                ti.subtotal, ti.qty_kg, ti.expense_name,
                ti.payment_type,
                m.name AS material_name,
                p.name AS party_name,
                t.note AS trip_note,
                t.id   AS trip_id,
                ti.created_at
            FROM fin_trip_items ti
            JOIN fin_trips t ON t.id = ti.trip_id
            LEFT JOIN fin_materials m ON m.id = ti.material_id
            LEFT JOIN fin_trip_parties p ON p.id = ti.party_id
            WHERE ti.created_at::date = %s
            ORDER BY ti.created_at DESC;
        """, (report_date,))
        trip_items = [dict(r) for r in cur.fetchall()]

        # Gabungkan trip items sebagai transaksi virtual
        for ti in trip_items:
            type_map = {
                'JUAL':    'JUAL_TRIP',
                'BELI':    'BELI_TRIP',
                'EXPENSE': 'PENGELUARAN_TRIP',
                'RETURN':  'RETURN_TRIP',
            }
            transactions.append({
                "id":           f"trip-{ti['id']}",
                "type":         type_map.get(ti['trip_item_type'], ti['trip_item_type']),
                "party_name":   ti.get('party_name') or ti.get('trip_note') or f"Trip #{ti['trip_id']}",
                "total_amount": float(ti['subtotal'] or 0),
                "note":         ti.get('expense_name') or ti.get('material_name'),
                "created_at":   str(ti['created_at']),
                "is_trip":      True,
                "items": [],
            })

        # Ringkasan — kasir gudang
        pemasukan   = sum(float(t["total_amount"] or 0)
                         for t in transactions
                         if t["type"] in ("JUAL_GUDANG", "TERIMA_HUTANG"))
        pengeluaran = sum(float(t["total_amount"] or 0)
                         for t in transactions
                         if t["type"] in ("BELI_GUDANG", "PENGELUARAN",
                                          "PEMBAYARAN_DP", "BAYAR_HUTANG"))

        # Ringkasan — trip Jakarta
        trip_jual    = sum(float(t["total_amount"] or 0)
                          for t in transactions if t["type"] == "JUAL_TRIP")
        trip_beli    = sum(float(t["total_amount"] or 0)
                          for t in transactions if t["type"] == "BELI_TRIP")
        trip_expense = sum(float(t["total_amount"] or 0)
                          for t in transactions if t["type"] == "PENGELUARAN_TRIP")

        # HPP barang terjual hari ini (gudang + trip)
        cur.execute("""
            SELECT COALESCE(SUM(i.qty_kg * s.avg_cost_per_kg), 0) AS hpp_total
            FROM fin_transactions t
            JOIN fin_transaction_items i ON i.transaction_id = t.id
            JOIN fin_stock_summary s ON s.material_id = i.material_id
            WHERE t.created_at::date = %s
              AND t.type = 'JUAL_GUDANG'
              AND i.material_id IS NOT NULL;
        """, (report_date,))
        hpp_gudang = float((cur.fetchone() or {}).get("hpp_total", 0))

        # HPP trip jual
        cur.execute("""
            SELECT COALESCE(SUM(ti.qty_kg * s.avg_cost_per_kg), 0) AS hpp_total
            FROM fin_trip_items ti
            JOIN fin_stock_summary s ON s.material_id = ti.material_id
            WHERE ti.created_at::date = %s AND ti.type = 'JUAL';
        """, (report_date,))
        hpp_trip = float((cur.fetchone() or {}).get("hpp_total", 0))

        hpp_total  = hpp_gudang + hpp_trip
        omzet_jual = sum(float(t["total_amount"] or 0)
                        for t in transactions
                        if t["type"] in ("JUAL_GUDANG", "JUAL_TRIP"))
        laba_kotor = omzet_jual - hpp_total - trip_expense

        # Nilai stok gudang saat ini
        cur.execute("SELECT COALESCE(SUM(total_value), 0) AS total FROM fin_stock_summary;")
        nilai_stok = float((cur.fetchone() or {}).get("total", 0))

        return mobile_api_response(ok=True, message="OK", data=_clean({
            "date":         str(report_date),
            "transactions": transactions,
            "summary": {
                "pemasukan":     pemasukan,
                "pengeluaran":   pengeluaran,
                "omzet_jual":    omzet_jual,
                "hpp":           hpp_total,
                "laba_kotor":    laba_kotor,
                "nilai_stok":    nilai_stok,
                "trip_jual":     trip_jual,
                "trip_beli":     trip_beli,
                "trip_expense":  trip_expense,
            }
        }))
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

        return mobile_api_response(ok=True, message="OK", data=_clean({
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
        }))
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
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

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
        rows = _clean([dict(r) for r in cur.fetchall()])

        hutang   = [r for r in rows if r["type"] == "HUTANG"]
        piutang  = [r for r in rows if r["type"] == "PIUTANG"]
        total_hutang  = sum(float(r["remaining"]) for r in hutang)
        total_piutang = sum(float(r["remaining"]) for r in piutang)

        return mobile_api_response(ok=True, message="OK", data=_clean({
            "hutang":        hutang,
            "piutang":       piutang,
            "total_hutang":  total_hutang,
            "total_piutang": total_piutang,
        }))
    finally:
        cur.close(); conn.close()


@mobile_finance_bp.route("/finance/debts/<int:debt_id>/pay", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def pay_debt(debt_id):
    """Tandai hutang/piutang sebagai lunas atau sebagian bayar"""
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

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
        return mobile_api_response(ok=True, message="OK", data=_clean({}))

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
        rows = _clean([dict(r) for r in cur.fetchall()])

        cur.execute("""
            SELECT qty_kg, avg_cost_per_kg, total_value
            FROM fin_stock_summary WHERE material_id = %s;
        """, (material_id,))
        summary = dict(cur.fetchone() or {})

        return mobile_api_response(ok=True, message="OK", data=_clean({
            "current": summary,
            "history": rows,
        }))
    finally:
        cur.close(); conn.close()

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
        cur.execute("""
            INSERT INTO fin_trips (trip_date, note, status, created_by)
            VALUES (%s, %s, 'OPEN', %s)
            RETURNING id, trip_date, note, status, created_at;
        """, (trip_date, note or None, request.mobile_user.get("id")))
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

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
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
                     payment_type, is_debt, note)
                VALUES (%s, %s, 'JUAL', %s, %s, %s, %s, %s, %s, %s);
            """, (trip_id, party_id, mat_id, qty, price, subtotal,
                  payment_type, is_debt, note or None))

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
                    (type, party_name, party_type, amount, remaining, note)
                VALUES ('PIUTANG', %s, 'LAPAK_JKT', %s, %s, %s);
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

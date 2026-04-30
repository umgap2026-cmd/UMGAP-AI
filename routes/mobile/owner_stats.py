"""
routes/mobile/owner_stats.py

Statistik komprehensif untuk owner:
- Keuangan bulanan (omzet, HPP, laba, stok)
- Tren harian 14 hari
- Top material terlaris
- Perjalanan Jakarta
- Hutang & piutang
- Gaji & absensi karyawan
- Perbandingan bulan ini vs bulan lalu
"""
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from datetime import date, timedelta
from decimal import Decimal

from db import get_conn
from core import mobile_api_login_required, mobile_api_response

mobile_owner_stats_bp = Blueprint("mobile_owner_stats", __name__)


def _c(v):
    """Convert Decimal/None → float"""
    if v is None: return 0.0
    if isinstance(v, Decimal): return float(v)
    try: return float(v)
    except: return 0.0


def _table_exists(cur, table):
    cur.execute("""SELECT 1 FROM information_schema.tables
                   WHERE table_name=%s LIMIT 1;""", (table,))
    return cur.fetchone() is not None


def _col_exists(cur, table, col):
    cur.execute("""SELECT 1 FROM information_schema.columns
                   WHERE table_name=%s AND column_name=%s LIMIT 1;""", (table, col))
    return cur.fetchone() is not None


@mobile_owner_stats_bp.route("/owner/stats", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def owner_stats():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    role = (request.mobile_user.get("role") or "").strip().lower()
    if role not in ("owner", "admin"):
        return mobile_api_response(ok=False, message="Akses ditolak.", status_code=403)

    # Parameter bulan
    month = request.args.get("month", "")
    if not month:
        today = date.today()
        month = f"{today.year:04d}-{today.month:02d}"
    try:
        year, mon = int(month.split("-")[0]), int(month.split("-")[1])
        start   = date(year, mon, 1)
        end     = date(year + 1, 1, 1) if mon == 12 else date(year, mon + 1, 1)
        # Bulan lalu
        if mon == 1:
            prev_start = date(year - 1, 12, 1)
            prev_end   = date(year, 1, 1)
        else:
            prev_start = date(year, mon - 1, 1)
            prev_end   = start
    except Exception as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        result = {}

        # ════════════════════════════════════════
        # 1. RINGKASAN KEUANGAN BULAN INI
        # ════════════════════════════════════════
        fin_kasir = {"revenue": 0.0, "buying": 0.0, "expense": 0.0}
        fin_trip  = {"revenue": 0.0, "buying": 0.0, "expense": 0.0}

        if _table_exists(cur, "fin_transactions"):
            cur.execute("""
                SELECT
                    COALESCE(SUM(CASE WHEN type='JUAL_GUDANG' THEN total_amount ELSE 0 END), 0) AS revenue,
                    COALESCE(SUM(CASE WHEN type='BELI_GUDANG' THEN total_amount ELSE 0 END), 0) AS buying,
                    COALESCE(SUM(CASE WHEN type='PENGELUARAN' THEN total_amount ELSE 0 END), 0) AS expense
                FROM fin_transactions
                WHERE created_at::date >= %s AND created_at::date < %s;
            """, (start, end))
            r = cur.fetchone() or {}
            fin_kasir = {k: _c(v) for k, v in r.items()}

        if _table_exists(cur, "fin_trip_items"):
            cur.execute("""
                SELECT
                    COALESCE(SUM(CASE WHEN ti.type='JUAL'    THEN ti.subtotal ELSE 0 END), 0) AS revenue,
                    COALESCE(SUM(CASE WHEN ti.type='BELI'    THEN ti.subtotal ELSE 0 END), 0) AS buying,
                    COALESCE(SUM(CASE WHEN ti.type='EXPENSE' THEN ti.subtotal ELSE 0 END), 0) AS expense
                FROM fin_trip_items ti
                JOIN fin_trips t ON t.id = ti.trip_id
                WHERE ti.created_at::date >= %s AND ti.created_at::date < %s;
            """, (start, end))
            r = cur.fetchone() or {}
            fin_trip = {k: _c(v) for k, v in r.items()}

        total_revenue  = fin_kasir["revenue"] + fin_trip["revenue"]
        total_buying   = fin_kasir["buying"]  + fin_trip["buying"]
        total_expense  = fin_kasir["expense"] + fin_trip["expense"]
        gross_profit   = total_revenue - total_buying
        net_profit_pre = gross_profit - total_expense  # sebelum gaji

        # Stok nilai
        stok_value = 0.0
        if _table_exists(cur, "fin_stock_summary"):
            cur.execute("SELECT COALESCE(SUM(total_value), 0) AS v FROM fin_stock_summary;")
            stok_value = _c((cur.fetchone() or {}).get("v", 0))

        # ════════════════════════════════════════
        # 2. PERBANDINGAN BULAN LALU
        # ════════════════════════════════════════
        prev_revenue = 0.0
        prev_profit  = 0.0
        if _table_exists(cur, "fin_transactions"):
            cur.execute("""
                SELECT
                    COALESCE(SUM(CASE WHEN type='JUAL_GUDANG' THEN total_amount ELSE 0 END), 0) AS revenue,
                    COALESCE(SUM(CASE WHEN type='BELI_GUDANG' THEN total_amount ELSE 0 END), 0) AS buying,
                    COALESCE(SUM(CASE WHEN type='PENGELUARAN' THEN total_amount ELSE 0 END), 0) AS expense
                FROM fin_transactions
                WHERE created_at::date >= %s AND created_at::date < %s;
            """, (prev_start, prev_end))
            r = cur.fetchone() or {}
            prev_revenue = _c(r.get("revenue"))
            prev_profit  = _c(r.get("revenue")) - _c(r.get("buying")) - _c(r.get("expense"))

        def _pct_change(curr, prev):
            if prev == 0: return None
            return round((curr - prev) / prev * 100, 1)

        result["finance_summary"] = {
            "total_revenue":  total_revenue,
            "total_buying":   total_buying,
            "total_expense":  total_expense,
            "gross_profit":   gross_profit,
            "net_profit_pre": net_profit_pre,
            "stok_value":     stok_value,
            "kasir_revenue":  fin_kasir["revenue"],
            "trip_revenue":   fin_trip["revenue"],
            "revenue_vs_prev": _pct_change(total_revenue, prev_revenue),
            "profit_vs_prev":  _pct_change(gross_profit, prev_profit),
        }

        # ════════════════════════════════════════
        # 3. TREN HARIAN 14 HARI TERAKHIR
        # ════════════════════════════════════════
        daily_trend = []
        trend_days  = 14
        today       = date.today()
        trend_start = today - timedelta(days=trend_days - 1)

        if _table_exists(cur, "fin_transactions"):
            cur.execute("""
                SELECT
                    created_at::date AS hari,
                    COALESCE(SUM(CASE WHEN type='JUAL_GUDANG' THEN total_amount ELSE 0 END), 0) AS jual,
                    COALESCE(SUM(CASE WHEN type='BELI_GUDANG' THEN total_amount ELSE 0 END), 0) AS beli,
                    COALESCE(SUM(CASE WHEN type='PENGELUARAN' THEN total_amount ELSE 0 END), 0) AS biaya
                FROM fin_transactions
                WHERE created_at::date >= %s AND created_at::date <= %s
                GROUP BY hari ORDER BY hari;
            """, (trend_start, today))
            rows_kasir = {str(r["hari"]): r for r in cur.fetchall()}

            trip_daily = {}
            if _table_exists(cur, "fin_trip_items"):
                cur.execute("""
                    SELECT
                        ti.created_at::date AS hari,
                        COALESCE(SUM(CASE WHEN ti.type='JUAL' THEN ti.subtotal ELSE 0 END), 0) AS jual
                    FROM fin_trip_items ti
                    WHERE ti.created_at::date >= %s AND ti.created_at::date <= %s
                    GROUP BY hari;
                """, (trend_start, today))
                trip_daily = {str(r["hari"]): _c(r["jual"]) for r in cur.fetchall()}

            for i in range(trend_days):
                d = trend_start + timedelta(days=i)
                ds = str(d)
                row = rows_kasir.get(ds, {})
                daily_trend.append({
                    "date":  ds,
                    "label": f"{d.day}/{d.month}",
                    "jual":  _c(row.get("jual", 0)) + trip_daily.get(ds, 0),
                    "beli":  _c(row.get("beli", 0)),
                    "biaya": _c(row.get("biaya", 0)),
                })

        result["daily_trend"] = daily_trend

        # ════════════════════════════════════════
        # 4. TOP MATERIAL TERLARIS
        # ════════════════════════════════════════
        top_materials = []
        if _table_exists(cur, "fin_transaction_items") and _table_exists(cur, "fin_materials"):
            cur.execute("""
                SELECT
                    m.name,
                    COALESCE(SUM(i.qty_kg), 0)   AS total_kg,
                    COALESCE(SUM(i.subtotal), 0)  AS total_nilai,
                    COUNT(*) AS txn_count
                FROM fin_transaction_items i
                JOIN fin_materials m ON m.id = i.material_id
                JOIN fin_transactions t ON t.id = i.transaction_id
                WHERE t.type = 'JUAL_GUDANG'
                  AND t.created_at::date >= %s AND t.created_at::date < %s
                  AND i.material_id IS NOT NULL
                GROUP BY m.name
                ORDER BY total_nilai DESC
                LIMIT 8;
            """, (start, end))
            top_materials = [{"name": r["name"], "kg": _c(r["total_kg"]),
                              "nilai": _c(r["total_nilai"]), "txn": int(r["txn_count"] or 0)}
                             for r in cur.fetchall()]

            # Tambah dari trip jual
            if _table_exists(cur, "fin_trip_items"):
                cur.execute("""
                    SELECT
                        m.name,
                        COALESCE(SUM(i.qty_kg), 0)   AS total_kg,
                        COALESCE(SUM(i.subtotal), 0)  AS total_nilai
                    FROM fin_trip_items i
                    JOIN fin_materials m ON m.id = i.material_id
                    JOIN fin_trips t ON t.id = i.trip_id
                    WHERE i.type = 'JUAL'
                      AND i.created_at::date >= %s AND i.created_at::date < %s
                    GROUP BY m.name
                    ORDER BY total_nilai DESC
                    LIMIT 8;
                """, (start, end))
                for r in cur.fetchall():
                    found = next((x for x in top_materials if x["name"] == r["name"]), None)
                    if found:
                        found["kg"]    += _c(r["total_kg"])
                        found["nilai"] += _c(r["total_nilai"])
                    else:
                        top_materials.append({"name": r["name"], "kg": _c(r["total_kg"]),
                                              "nilai": _c(r["total_nilai"]), "txn": 0})
                top_materials.sort(key=lambda x: x["nilai"], reverse=True)
                top_materials = top_materials[:8]

        result["top_materials"] = top_materials

        # ════════════════════════════════════════
        # 5. PERJALANAN JAKARTA
        # ════════════════════════════════════════
        trips_summary = {"total_trip": 0, "open_trip": 0, "closed_trip": 0,
                         "total_jual": 0.0, "total_beli": 0.0, "total_expense": 0.0,
                         "net_result": 0.0, "trips": []}
        if _table_exists(cur, "fin_trips"):
            cur.execute("""
                SELECT
                    COUNT(*) AS total,
                    SUM(CASE WHEN status='OPEN'   THEN 1 ELSE 0 END) AS open_count,
                    SUM(CASE WHEN status='CLOSED' THEN 1 ELSE 0 END) AS closed_count,
                    COALESCE(SUM(total_income),  0) AS total_jual,
                    COALESCE(SUM(total_expense), 0) AS total_biaya,
                    COALESCE(SUM(net_result),    0) AS net
                FROM fin_trips
                WHERE created_at::date >= %s AND created_at::date < %s;
            """, (start, end))
            r = cur.fetchone() or {}
            trips_summary.update({
                "total_trip":    int(r.get("total") or 0),
                "open_trip":     int(r.get("open_count") or 0),
                "closed_trip":   int(r.get("closed_count") or 0),
                "total_jual":    _c(r.get("total_jual")),
                "total_expense": _c(r.get("total_biaya")),
                "net_result":    _c(r.get("net")),
            })

            # List trips
            cur.execute("""
                SELECT id, trip_date, note, status,
                       total_income, total_expense, net_result
                FROM fin_trips
                WHERE created_at::date >= %s AND created_at::date < %s
                ORDER BY created_at DESC LIMIT 10;
            """, (start, end))
            trips_summary["trips"] = [
                {"id": r["id"], "date": str(r["trip_date"]),
                 "note": r["note"] or f"Trip #{r['id']}",
                 "status": r["status"],
                 "income":  _c(r["total_income"]),
                 "expense": _c(r["total_expense"]),
                 "net":     _c(r["net_result"])}
                for r in cur.fetchall()
            ]

        result["trips_summary"] = trips_summary

        # ════════════════════════════════════════
        # 6. HUTANG & PIUTANG
        # ════════════════════════════════════════
        debts_summary = {"hutang": 0.0, "piutang": 0.0,
                         "hutang_count": 0, "piutang_count": 0,
                         "oldest_hutang_days": 0, "items": []}
        if _table_exists(cur, "fin_debts"):
            cur.execute("""
                SELECT
                    type, party_name, amount, remaining, created_at,
                    EXTRACT(DAY FROM NOW() - created_at)::int AS age_days
                FROM fin_debts
                WHERE is_settled = FALSE
                ORDER BY created_at ASC;
            """)
            debts = cur.fetchall()
            for d in debts:
                if d["type"] == "HUTANG":
                    debts_summary["hutang"]       += _c(d["remaining"])
                    debts_summary["hutang_count"] += 1
                    debts_summary["oldest_hutang_days"] = max(
                        debts_summary["oldest_hutang_days"], int(d["age_days"] or 0))
                else:
                    debts_summary["piutang"]       += _c(d["remaining"])
                    debts_summary["piutang_count"] += 1
            debts_summary["items"] = [
                {"type": d["type"], "party": d["party_name"],
                 "remaining": _c(d["remaining"]), "age_days": int(d["age_days"] or 0)}
                for d in debts[:10]
            ]

        result["debts_summary"] = debts_summary

        # ════════════════════════════════════════
        # 7. GAJI & ABSENSI KARYAWAN
        # ════════════════════════════════════════
        salary_total = 0
        employees    = []
        if _table_exists(cur, "payroll_settings"):
            has_daily   = _col_exists(cur, "payroll_settings", "daily_salary")
            has_monthly = _col_exists(cur, "payroll_settings", "monthly_salary")

            daily_expr   = "COALESCE(ps.daily_salary,   0)" if has_daily   else "0"
            monthly_expr = "COALESCE(ps.monthly_salary, 0)" if has_monthly else "0"
            join_ps = "LEFT JOIN payroll_settings ps ON ps.user_id = u.id"
            group_ps = (", ps.daily_salary" if has_daily else "") + \
                       (", ps.monthly_salary" if has_monthly else "")

            cur.execute(f"""
                SELECT u.id, u.name,
                    {daily_expr}   AS daily_salary,
                    {monthly_expr} AS monthly_salary,
                    COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END), 0) AS present,
                    COALESCE(SUM(CASE WHEN a.status='ABSENT'  THEN 1 ELSE 0 END), 0) AS absent,
                    COALESCE(SUM(CASE WHEN a.status='SICK'    THEN 1 ELSE 0 END), 0) AS sick,
                    COALESCE(SUM(CASE WHEN a.arrival_type='LATE' THEN 1 ELSE 0 END), 0) AS late
                FROM users u
                {join_ps}
                LEFT JOIN attendance a ON a.user_id = u.id
                    AND a.work_date >= %s AND a.work_date < %s
                WHERE u.role = 'employee'
                GROUP BY u.id, u.name{group_ps}
                ORDER BY u.name;
            """, (start, end))
            rows = cur.fetchall()
            for r in rows:
                daily    = int(_c(r["daily_salary"]))
                monthly  = int(_c(r["monthly_salary"]))
                present  = int(r["present"] or 0)
                absent   = int(r["absent"]  or 0)
                sick     = int(r["sick"]    or 0)
                late     = int(r["late"]    or 0)
                worked   = present + sick + late
                gaji_est = monthly if monthly > 0 else worked * daily
                salary_total += gaji_est
                employees.append({
                    "name": r["name"], "present": present,
                    "absent": absent, "sick": sick, "late": late,
                    "worked": worked, "gaji": gaji_est,
                    "daily_salary": daily, "monthly_salary": monthly,
                })
        else:
            # Fallback: hanya absensi tanpa gaji
            cur.execute("""
                SELECT u.name,
                    COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END), 0) AS present,
                    COALESCE(SUM(CASE WHEN a.status='ABSENT'  THEN 1 ELSE 0 END), 0) AS absent,
                    COALESCE(SUM(CASE WHEN a.status='SICK'    THEN 1 ELSE 0 END), 0) AS sick,
                    COALESCE(SUM(CASE WHEN a.arrival_type='LATE' THEN 1 ELSE 0 END), 0) AS late
                FROM users u
                LEFT JOIN attendance a ON a.user_id = u.id
                    AND a.work_date >= %s AND a.work_date < %s
                WHERE u.role = 'employee'
                GROUP BY u.id, u.name ORDER BY u.name;
            """, (start, end))
            for r in cur.fetchall():
                employees.append({
                    "name": r["name"], "present": int(r["present"] or 0),
                    "absent": int(r["absent"] or 0), "sick": int(r["sick"] or 0),
                    "late": int(r["late"] or 0), "worked": 0, "gaji": 0,
                    "daily_salary": 0, "monthly_salary": 0,
                })

        result["hr_summary"] = {
            "employee_count": len(employees),
            "salary_total":   salary_total,
            "employees":      employees,
        }

        # ════════════════════════════════════════
        # 8. STOK PER MATERIAL
        # ════════════════════════════════════════
        stok_detail = []
        if _table_exists(cur, "fin_stock_summary") and _table_exists(cur, "fin_materials"):
            cur.execute("""
                SELECT m.name, s.qty_kg, s.avg_cost_per_kg, s.total_value
                FROM fin_stock_summary s
                JOIN fin_materials m ON m.id = s.material_id
                WHERE s.qty_kg > 0
                ORDER BY s.total_value DESC;
            """)
            stok_detail = [
                {"name": r["name"], "qty_kg": _c(r["qty_kg"]),
                 "avg_cost": _c(r["avg_cost_per_kg"]),
                 "total_value": _c(r["total_value"])}
                for r in cur.fetchall()
            ]

        result["stok_detail"] = stok_detail
        result["month"]       = month
        result["period_label"] = _period_label(year, mon)

        # Net profit final (setelah gaji)
        result["finance_summary"]["net_profit_final"] = net_profit_pre - salary_total

        return mobile_api_response(ok=True, message="OK", data=result)

    except Exception as e:
        import traceback
        print(f"[owner_stats] ERROR: {e}\n{traceback.format_exc()}")
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close(); conn.close()


def _period_label(year, mon):
    names = ['','Januari','Februari','Maret','April','Mei','Juni',
             'Juli','Agustus','September','Oktober','November','Desember']
    return f"{names[mon]} {year}"
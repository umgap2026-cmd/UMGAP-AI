import os
from datetime import date
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_login_required, mobile_api_response

mobile_owner_bp = Blueprint("mobile_owner", __name__)


def _clean_num(v):
    try:
        return float(v or 0)
    except Exception:
        return 0.0


def _table_exists(cur, table):
    cur.execute("""
        SELECT 1 FROM information_schema.tables
        WHERE table_name=%s LIMIT 1;
    """, (table,))
    return cur.fetchone() is not None


def _col_exists(cur, table, col):
    cur.execute("""
        SELECT 1 FROM information_schema.columns
        WHERE table_name=%s AND column_name=%s LIMIT 1;
    """, (table, col))
    return cur.fetchone() is not None


def _access_owner_admin():
    user = getattr(request, "mobile_user", None) or {}
    role = (user.get("role") or "").strip().lower()
    if role not in ("owner", "admin"):
        return mobile_api_response(
            ok=False,
            message="Akses ditolak. Hanya owner / admin.",
            status_code=403,
        )
    return None


@mobile_owner_bp.route("/owner/insight", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def owner_insight():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    deny = _access_owner_admin()
    if deny:
        return deny

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        today = date.today()

        revenue = 0.0
        buying = 0.0
        expense = 0.0
        stock_value = 0.0
        debt_total = 0.0
        receivable_total = 0.0
        salary_total = 0.0
        quality_score = 0.0

        # =========================
        # FINANCE TRANSACTIONS
        # =========================
        if _table_exists(cur, "fin_transactions"):
            cur.execute("""
                SELECT
                    COALESCE(SUM(CASE
                        WHEN type IN ('JUAL_GUDANG', 'TERIMA_HUTANG')
                        THEN total_amount ELSE 0 END), 0) AS revenue,

                    COALESCE(SUM(CASE
                        WHEN type IN ('BELI_GUDANG')
                        THEN total_amount ELSE 0 END), 0) AS buying,

                    COALESCE(SUM(CASE
                        WHEN type IN ('PENGELUARAN', 'PEMBAYARAN_DP', 'BAYAR_HUTANG')
                        THEN total_amount ELSE 0 END), 0) AS expense
                FROM fin_transactions
                WHERE created_at >= date_trunc('month', CURRENT_DATE);
            """)
            r = cur.fetchone() or {}
            revenue = _clean_num(r.get("revenue"))
            buying = _clean_num(r.get("buying"))
            expense = _clean_num(r.get("expense"))

        # =========================
        # TRIP JAKARTA
        # =========================
        if _table_exists(cur, "fin_trip_items"):
            cur.execute("""
                SELECT
                    COALESCE(SUM(CASE
                        WHEN type='JUAL' THEN subtotal ELSE 0 END), 0) AS trip_revenue,

                    COALESCE(SUM(CASE
                        WHEN type='BELI' THEN subtotal ELSE 0 END), 0) AS trip_buying,

                    COALESCE(SUM(CASE
                        WHEN type='EXPENSE' THEN subtotal ELSE 0 END), 0) AS trip_expense
                FROM fin_trip_items
                WHERE created_at >= date_trunc('month', CURRENT_DATE);
            """)
            r = cur.fetchone() or {}
            revenue += _clean_num(r.get("trip_revenue"))
            buying += _clean_num(r.get("trip_buying"))
            expense += _clean_num(r.get("trip_expense"))

        # =========================
        # STOCK VALUE
        # =========================
        if _table_exists(cur, "fin_stock_summary"):
            cur.execute("""
                SELECT COALESCE(SUM(total_value), 0) AS total
                FROM fin_stock_summary;
            """)
            stock_value = _clean_num((cur.fetchone() or {}).get("total"))

        # =========================
        # HUTANG PIUTANG
        # =========================
        if _table_exists(cur, "fin_debts"):
            cur.execute("""
                SELECT
                    COALESCE(SUM(CASE
                        WHEN type='HUTANG' AND is_settled=FALSE
                        THEN remaining ELSE 0 END), 0) AS hutang,

                    COALESCE(SUM(CASE
                        WHEN type='PIUTANG' AND is_settled=FALSE
                        THEN remaining ELSE 0 END), 0) AS piutang
                FROM fin_debts;
            """)
            r = cur.fetchone() or {}
            debt_total = _clean_num(r.get("hutang"))
            receivable_total = _clean_num(r.get("piutang"))

        # =========================
        # SALARY / GAJI
        # =========================
        if _table_exists(cur, "payroll_settings"):
            has_monthly = _col_exists(cur, "payroll_settings", "monthly_salary")
            has_daily = _col_exists(cur, "payroll_settings", "daily_salary")

            if has_monthly and has_daily:
                cur.execute("""
                    SELECT COALESCE(SUM(
                        CASE
                            WHEN COALESCE(monthly_salary, 0) > 0
                            THEN monthly_salary
                            ELSE COALESCE(daily_salary, 0) * 26
                        END
                    ), 0) AS total_salary
                    FROM payroll_settings;
                """)
            elif has_monthly:
                cur.execute("""
                    SELECT COALESCE(SUM(monthly_salary), 0) AS total_salary
                    FROM payroll_settings;
                """)
            elif has_daily:
                cur.execute("""
                    SELECT COALESCE(SUM(daily_salary * 26), 0) AS total_salary
                    FROM payroll_settings;
                """)
            else:
                cur.execute("SELECT 0 AS total_salary;")

            salary_total = _clean_num((cur.fetchone() or {}).get("total_salary"))

        # =========================
        # QUALITY SCORE ABSENSI
        # =========================
        if _table_exists(cur, "attendance"):
            cur.execute("""
                SELECT
                    COUNT(*) AS total,
                    COALESCE(SUM(CASE WHEN status='PRESENT' THEN 1 ELSE 0 END), 0) AS hadir,
                    COALESCE(SUM(CASE WHEN arrival_type='LATE' THEN 1 ELSE 0 END), 0) AS telat,
                    COALESCE(SUM(CASE WHEN status='ABSENT' THEN 1 ELSE 0 END), 0) AS absen
                FROM attendance
                WHERE work_date >= date_trunc('month', CURRENT_DATE)::date;
            """)
            r = cur.fetchone() or {}
            total = _clean_num(r.get("total"))
            hadir = _clean_num(r.get("hadir"))
            telat = _clean_num(r.get("telat"))
            absen = _clean_num(r.get("absen"))

            if total > 0:
                quality_score = max(0.0, min(100.0, ((hadir / total) * 100) - (telat * 1.5) - (absen * 3)))

        profit = revenue - buying - expense - salary_total

        # Health score sederhana
        health_score = 50.0

        if revenue > 0:
            margin = profit / revenue
            health_score += margin * 40

        if stock_value > 0:
            health_score += 10

        if debt_total > receivable_total and debt_total > 0:
            health_score -= 10

        if quality_score > 0:
            health_score = (health_score * 0.7) + (quality_score * 0.3)

        health_score = max(0.0, min(100.0, health_score))

        return mobile_api_response(
            ok=True,
            message="Owner insight berhasil dimuat",
            data={
                "date": str(today),

                "revenue": revenue,
                "buying": buying,
                "expense": expense,
                "salary_total": salary_total,
                "stock_value": stock_value,
                "debt_total": debt_total,
                "receivable_total": receivable_total,
                "profit": profit,

                "quality_score": round(quality_score, 1),
                "health_score": round(health_score, 1),
            },
        )

    except Exception as e:
        return mobile_api_response(
            ok=False,
            message=f"Gagal memuat owner insight: {str(e)}",
            status_code=500,
        )

    finally:
        cur.close()
        conn.close()


@mobile_owner_bp.route("/owner/ai-review", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def owner_ai_review():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={})

    user = getattr(request, "mobile_user", None) or {}
    role = (user.get("role") or "").strip().lower()

    if role != "owner":
        return mobile_api_response(
            ok=False,
            message="Akses ditolak. Hanya owner.",
            status_code=403,
        )

    data = request.get_json(silent=True) or {}

    try:
        from openai import OpenAI

        api_key = os.getenv("OPENAI_API_KEY")
        model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

        if not api_key:
            return mobile_api_response(
                ok=False,
                message="OPENAI_API_KEY belum diset di server.",
                status_code=500,
            )

        prompt = f"""
Anda adalah konsultan bisnis untuk perusahaan scrap/logam.

Data bulan ini:
- Omzet: Rp {data.get('revenue', 0)}
- Pembelian/modal barang: Rp {data.get('buying', 0)}
- Pengeluaran: Rp {data.get('expense', 0)}
- Gaji karyawan: Rp {data.get('salary', 0)}
- Nilai stok: Rp {data.get('stock', 0)}
- Hutang: Rp {data.get('debt', 0)}
- Piutang: Rp {data.get('receivable', 0)}
- Estimasi profit: Rp {data.get('profit', 0)}
- Skor kualitas: {data.get('quality_score', 0)}
- Skor kesehatan perusahaan: {data.get('health_score', 0)}

Buat review singkat dalam bahasa Indonesia:
1. Kondisi perusahaan saat ini
2. Risiko utama
3. Saran cepat yang harus dilakukan owner
4. Kesimpulan singkat
Gunakan bahasa sederhana dan praktis.
"""

        client = OpenAI(api_key=api_key)

        res = client.chat.completions.create(
            model=model,
            messages=[
                {
                    "role": "system",
                    "content": "Anda adalah konsultan bisnis yang praktis, jelas, dan langsung ke inti.",
                },
                {
                    "role": "user",
                    "content": prompt,
                },
            ],
        )

        analysis = res.choices[0].message.content or ""

        return mobile_api_response(
            ok=True,
            message="AI review berhasil dibuat",
            data={"analysis": analysis},
        )

    except Exception as e:
        return mobile_api_response(
            ok=False,
            message=f"Gagal AI review: {str(e)}",
            status_code=500,
        )

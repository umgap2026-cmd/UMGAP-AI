import os
from datetime import date, timedelta
from decimal import Decimal

from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_owner_insight_bp = Blueprint("mobile_owner_insight", __name__)


def _clean(obj):
    if isinstance(obj, list):
        return [_clean(i) for i in obj]
    if isinstance(obj, dict):
        return {k: _clean(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        return float(obj)
    return obj


def _check_owner_or_admin():
    user = getattr(request, "mobile_user", None) or {}
    role = str(user.get("role") or "").strip().lower()
    if role not in ("owner", "admin"):
        return mobile_api_response(False, "Akses ditolak. Hanya owner/admin.", status_code=403)
    return None


def _safe_float(v):
    try:
        return float(v or 0)
    except Exception:
        return 0.0


def _month_range():
    today = date.today()
    start = today.replace(day=1)
    if start.month == 12:
        end = date(start.year + 1, 1, 1)
    else:
        end = date(start.year, start.month + 1, 1)
    return start, end


def _company_health_score(data):
    """Skor sederhana 0-100 untuk cepat membaca kualitas perusahaan."""
    score = 50

    omzet = data.get("omzet_bulan_ini", 0)
    laba = data.get("laba_bersih_estimasi", 0)
    stok = data.get("nilai_stok", 0)
    hutang = data.get("hutang", 0)
    piutang = data.get("piutang", 0)
    total_gaji = data.get("total_gaji_estimasi", 0)
    hadir_pct = data.get("persentase_kehadiran", 0)

    if omzet > 0:
        margin = laba / omzet
        if margin >= 0.20: score += 18
        elif margin >= 0.10: score += 12
        elif margin >= 0.03: score += 6
        elif margin < 0: score -= 18

        salary_ratio = total_gaji / omzet
        if salary_ratio <= 0.12: score += 8
        elif salary_ratio <= 0.22: score += 4
        else: score -= 8

    if stok > 0: score += 6
    if piutang > hutang: score += 6
    if hutang > omzet and omzet > 0: score -= 10

    if hadir_pct >= 90: score += 10
    elif hadir_pct >= 75: score += 4
    else: score -= 8

    return max(0, min(100, int(round(score))))


@mobile_owner_insight_bp.route("/owner/insight", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def owner_insight():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    deny = _check_owner_or_admin()
    if deny:
        return deny

    start, end = _month_range()
    today = date.today()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Keuangan bulan ini dari tabel finance yang sudah dipakai kasir.
        cur.execute("""
            SELECT
                COALESCE(SUM(CASE WHEN type = 'JUAL_GUDANG' THEN total_amount ELSE 0 END), 0) AS omzet_jual,
                COALESCE(SUM(CASE WHEN type = 'BELI_GUDANG' THEN total_amount ELSE 0 END), 0) AS modal_beli,
                COALESCE(SUM(CASE WHEN type = 'PENGELUARAN' THEN total_amount ELSE 0 END), 0) AS biaya_ops
            FROM fin_transactions
            WHERE created_at::date >= %s AND created_at::date < %s;
        """, (start, end))
        fin = dict(cur.fetchone() or {})

        omzet = _safe_float(fin.get("omzet_jual"))
        modal_beli = _safe_float(fin.get("modal_beli"))
        biaya_ops = _safe_float(fin.get("biaya_ops"))

        # Estimasi HPP penjualan berdasarkan AVCO ledger/stock saat transaksi.
        cur.execute("""
            SELECT COALESCE(SUM(i.qty_kg * COALESCE(l.avg_cost_after, s.avg_cost_per_kg, 0)), 0) AS hpp
            FROM fin_transactions t
            JOIN fin_transaction_items i ON i.transaction_id = t.id
            LEFT JOIN fin_stock_ledger l ON l.transaction_id = t.id AND l.material_id = i.material_id
            LEFT JOIN fin_stock_summary s ON s.material_id = i.material_id
            WHERE t.type = 'JUAL_GUDANG'
              AND t.created_at::date >= %s AND t.created_at::date < %s;
        """, (start, end))
        hpp = _safe_float((cur.fetchone() or {}).get("hpp"))

        laba_kotor = omzet - hpp
        laba_bersih = laba_kotor - biaya_ops

        # Nilai stok gudang.
        cur.execute("SELECT COALESCE(SUM(total_value),0) AS nilai_stok FROM fin_stock_summary;")
        nilai_stok = _safe_float((cur.fetchone() or {}).get("nilai_stok"))

        # Hutang / piutang berjalan.
        cur.execute("""
            SELECT
                COALESCE(SUM(CASE WHEN type='HUTANG' THEN remaining ELSE 0 END),0) AS hutang,
                COALESCE(SUM(CASE WHEN type='PIUTANG' THEN remaining ELSE 0 END),0) AS piutang
            FROM fin_debts
            WHERE is_settled = FALSE;
        """)
        debt = dict(cur.fetchone() or {})
        hutang = _safe_float(debt.get("hutang"))
        piutang = _safe_float(debt.get("piutang"))

        # Gaji & kualitas karyawan bulan ini.
        cur.execute("""
            SELECT
                u.id,
                u.name AS employee_name,
                COALESCE(ps.daily_salary, 0) AS daily_salary,
                COALESCE(ps.monthly_salary, 0) AS monthly_salary,
                COALESCE(ps.salary_type, 'daily') AS salary_type,
                COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END),0) AS present_days,
                COALESCE(SUM(CASE WHEN a.arrival_type='LATE' THEN 1 ELSE 0 END),0) AS late_days,
                COALESCE(SUM(CASE WHEN a.status='SICK' THEN 1 ELSE 0 END),0) AS sick_days,
                COALESCE(SUM(CASE WHEN a.status='LEAVE' THEN 1 ELSE 0 END),0) AS leave_days,
                COALESCE(SUM(CASE WHEN a.status='ABSENT' THEN 1 ELSE 0 END),0) AS absent_days
            FROM users u
            LEFT JOIN payroll_settings ps ON ps.user_id = u.id
            LEFT JOIN attendance a ON a.user_id = u.id
                AND a.work_date >= %s AND a.work_date < %s
            WHERE u.role = 'employee'
            GROUP BY u.id, u.name, ps.daily_salary, ps.monthly_salary, ps.salary_type
            ORDER BY u.name ASC;
        """, (start, end))
        employees = []
        total_gaji = 0.0
        hadir = telat = sakit = izin = absen = 0
        for r in cur.fetchall():
            daily = _safe_float(r.get("daily_salary"))
            monthly = _safe_float(r.get("monthly_salary"))
            present = int(r.get("present_days") or 0)
            late = int(r.get("late_days") or 0)
            sick = int(r.get("sick_days") or 0)
            leave = int(r.get("leave_days") or 0)
            absent = int(r.get("absent_days") or 0)
            worked = present + late + sick + leave
            salary_type = (r.get("salary_type") or "daily")
            gaji = monthly if salary_type == "monthly" and monthly > 0 else worked * daily
            total_gaji += gaji
            hadir += present
            telat += late
            sakit += sick
            izin += leave
            absen += absent
            employees.append({
                "id": r.get("id"),
                "employee_name": r.get("employee_name"),
                "gaji_estimasi": gaji,
                "present_days": present,
                "late_days": late,
                "sick_days": sick,
                "leave_days": leave,
                "absent_days": absent,
                "worked_days": worked,
            })

        total_absensi = hadir + telat + sakit + izin + absen
        persentase_kehadiran = ((hadir + telat) / total_absensi * 100) if total_absensi > 0 else 0

        # Aktivitas hari ini.
        cur.execute("""
            SELECT
                COUNT(*) AS transaksi_hari_ini,
                COALESCE(SUM(CASE WHEN type='JUAL_GUDANG' THEN total_amount ELSE 0 END),0) AS omzet_hari_ini,
                COALESCE(SUM(CASE WHEN type='BELI_GUDANG' THEN total_amount ELSE 0 END),0) AS pembelian_hari_ini,
                COALESCE(SUM(CASE WHEN type='PENGELUARAN' THEN total_amount ELSE 0 END),0) AS biaya_hari_ini
            FROM fin_transactions
            WHERE created_at::date = %s;
        """, (today,))
        daily = dict(cur.fetchone() or {})

        result = {
            "period": f"{start.isoformat()} s.d. {(end - timedelta(days=1)).isoformat()}",
            "omzet_bulan_ini": omzet,
            "modal_beli_bulan_ini": modal_beli,
            "hpp_estimasi": hpp,
            "laba_kotor_estimasi": laba_kotor,
            "biaya_operasional": biaya_ops,
            "laba_bersih_estimasi": laba_bersih,
            "nilai_stok": nilai_stok,
            "hutang": hutang,
            "piutang": piutang,
            "total_gaji_estimasi": total_gaji,
            "jumlah_karyawan": len(employees),
            "persentase_kehadiran": round(persentase_kehadiran, 1),
            "absensi": {
                "hadir": hadir,
                "telat": telat,
                "sakit": sakit,
                "izin": izin,
                "absen": absen,
            },
            "today": _clean(daily),
            "employees": _clean(employees[:10]),
        }
        result["company_health_score"] = _company_health_score(result)

        return mobile_api_response(True, "OK", _clean(result))
    except Exception as e:
        import traceback
        print(f"[owner_insight] ERROR: {e}\n{traceback.format_exc()}")
        return mobile_api_response(False, f"Gagal memuat owner insight: {e}", status_code=500)
    finally:
        cur.close()
        conn.close()


@mobile_owner_insight_bp.route("/owner/ai-review", methods=["POST", "OPTIONS"])
@mobile_api_login_required
def owner_ai_review():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    deny = _check_owner_or_admin()
    if deny:
        return deny

    api_key = os.getenv("OPENAI_API_KEY", "").strip()
    if not api_key:
        return mobile_api_response(False, "OPENAI_API_KEY belum diset di environment server.", status_code=500)

    data = request.get_json(silent=True) or {}
    model = os.getenv("OPENAI_MODEL", "gpt-4o-mini")

    prompt = f"""
Anda adalah konsultan bisnis untuk perusahaan scrap/logam.
Review data perusahaan berikut dalam bahasa Indonesia yang singkat, tajam, dan bisa langsung ditindaklanjuti.

Data:
- Periode: {data.get('period', '-')}
- Omzet bulan ini: Rp {data.get('omzet_bulan_ini', 0)}
- Modal beli bulan ini: Rp {data.get('modal_beli_bulan_ini', 0)}
- HPP estimasi: Rp {data.get('hpp_estimasi', 0)}
- Laba kotor estimasi: Rp {data.get('laba_kotor_estimasi', 0)}
- Biaya operasional: Rp {data.get('biaya_operasional', 0)}
- Laba bersih estimasi: Rp {data.get('laba_bersih_estimasi', 0)}
- Nilai stok: Rp {data.get('nilai_stok', 0)}
- Hutang: Rp {data.get('hutang', 0)}
- Piutang: Rp {data.get('piutang', 0)}
- Total gaji estimasi: Rp {data.get('total_gaji_estimasi', 0)}
- Jumlah karyawan: {data.get('jumlah_karyawan', 0)}
- Kehadiran: {data.get('persentase_kehadiran', 0)}%
- Skor kesehatan perusahaan: {data.get('company_health_score', 0)}/100

Berikan output dengan format:
1. Kesimpulan kondisi perusahaan
2. Risiko terbesar
3. Saran prioritas minggu ini
4. Saran kontrol kualitas perusahaan
5. Target angka yang perlu dipantau owner
"""

    try:
        from openai import OpenAI
        client = OpenAI(api_key=api_key)
        res = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "Jawab sebagai konsultan bisnis yang praktis dan jujur."},
                {"role": "user", "content": prompt},
            ],
            temperature=0.3,
        )
        analysis = res.choices[0].message.content or "Tidak ada hasil analisis."
        return mobile_api_response(True, "OK", {"analysis": analysis})
    except Exception as e:
        return mobile_api_response(False, f"Gagal menjalankan AI Review: {e}", status_code=500)

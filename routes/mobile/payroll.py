from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from datetime import date, timedelta

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_payroll_bp = Blueprint("mobile_payroll", __name__)


# ── Helper ────────────────────────────────────────────────────────────
def count_workdays_only_sunday_off(start_date, end_date):
    d = start_date
    n = 0
    while d < end_date:
        if d.weekday() != 6:
            n += 1
        d = d.fromordinal(d.toordinal() + 1)
    return n


def _get_week_range(week_start_str: str):
    """
    Dari string 'YYYY-MM-DD' (Senin), return (start, end) inclusive Senin–Sabtu.
    Kalau tidak ada parameter, pakai Senin minggu ini.
    """
    if week_start_str:
        try:
            start = date.fromisoformat(week_start_str)
        except ValueError:
            start = None
    else:
        start = None

    if start is None:
        today = date.today()
        # Senin minggu ini
        start = today - timedelta(days=today.weekday())

    # Pastikan selalu Senin
    start = start - timedelta(days=start.weekday())
    end   = start + timedelta(days=5)   # Sabtu
    return start, end


# ── Admin: payroll bulanan (tidak berubah) ───────────────────────────
@mobile_payroll_bp.route("/payroll", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_payroll():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    if request.mobile_user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)

    month = request.args.get("month")
    if not month:
        today = date.today()
        month = f"{today.year:04d}-{today.month:02d}"

    year = int(month.split("-")[0])
    mon  = int(month.split("-")[1])

    start_date = date(year, mon, 1)
    end_date   = date(year + 1, 1, 1) if mon == 12 else date(year, mon + 1, 1)
    workdays   = count_workdays_only_sunday_off(start_date, end_date)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT u.id, u.name,
                COALESCE(p.daily_salary, 0)  AS daily_salary,
                COALESCE(p.monthly_salary, 0) AS monthly_salary,
                COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END), 0) AS days_present,
                COALESCE(SUM(CASE WHEN a.status='SICK'    THEN 1 ELSE 0 END), 0) AS days_sick,
                COALESCE(SUM(CASE WHEN a.status='LEAVE'   THEN 1 ELSE 0 END), 0) AS days_leave,
                COALESCE(SUM(CASE WHEN a.status='ABSENT'  THEN 1 ELSE 0 END), 0) AS days_absent
            FROM users u
            LEFT JOIN payroll_settings p ON p.user_id = u.id
            LEFT JOIN attendance a ON a.user_id = u.id
                AND a.work_date >= %s AND a.work_date < %s
            WHERE u.role = 'employee'
            GROUP BY u.id, u.name, p.daily_salary, p.monthly_salary
            ORDER BY u.name ASC;
        """, (start_date, end_date))
        rows = [dict(r) for r in cur.fetchall()]

        return mobile_api_response(
            ok=True, message="OK",
            data={"month": month, "workdays": workdays, "payroll": rows},
            status_code=200
        )
    finally:
        cur.close()
        conn.close()


# ── Karyawan: slip gaji MINGGUAN (endpoint baru) ─────────────────────
@mobile_payroll_bp.route("/my-payslip", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_my_payslip():
    """
    GET /api/mobile/my-payslip?week=2026-04-21   (Senin minggu tsb)
    Kalau tidak ada ?week, pakai minggu berjalan.
    Mengembalikan slip gaji mingguan untuk user yang sedang login.
    """
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    user_id = request.mobile_user.get("id")
    week_start_str = request.args.get("week", "")
    week_start, week_end = _get_week_range(week_start_str)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # ── Setting gaji karyawan ─────────────────────────────────────
        cur.execute("""
            SELECT
                u.name,
                u.email,
                COALESCE(p.daily_salary,   0) AS daily_salary,
                COALESCE(p.monthly_salary, 0) AS monthly_salary,
                COALESCE(p.salary_type, 'daily') AS salary_type
            FROM users u
            LEFT JOIN payroll_settings p ON p.user_id = u.id
            WHERE u.id = %s
            LIMIT 1;
        """, (user_id,))
        user = cur.fetchone()
        if not user:
            return mobile_api_response(ok=False, message="User tidak ditemukan", status_code=404)

        # ── Rekap absensi minggu ini ──────────────────────────────────
        cur.execute("""
            SELECT
                work_date,
                status,
                arrival_type,
                note,
                checkin_at
            FROM attendance
            WHERE user_id  = %s
              AND work_date >= %s
              AND work_date <= %s
            ORDER BY work_date ASC;
        """, (user_id, week_start, week_end))
        att_rows = cur.fetchall()

        # ── Hitung statistik ──────────────────────────────────────────
        present  = sum(1 for r in att_rows if r['status'] == 'PRESENT')
        sick     = sum(1 for r in att_rows if r['status'] == 'SICK')
        leave    = sum(1 for r in att_rows if r['status'] == 'LEAVE')
        absent   = sum(1 for r in att_rows if r['status'] == 'ABSENT')
        late     = sum(1 for r in att_rows
                       if r['status'] == 'PRESENT' and r['arrival_type'] == 'LATE')

        # Hari kerja minggu ini (Senin–Sabtu = 6 hari)
        workdays_this_week = 6
        # Kalau minggu ini belum selesai, hitung hari yang sudah lewat
        today = date.today()
        if week_end > today:
            passed = (today - week_start).days + 1
            workdays_this_week = min(passed, 6)

        # ── Hitung gaji ───────────────────────────────────────────────
        daily_salary   = int(user['daily_salary']   or 0)
        monthly_salary = int(user['monthly_salary'] or 0)
        salary_type    = user['salary_type'] or 'daily'

        if salary_type == 'monthly' and monthly_salary > 0:
            # Estimasi mingguan dari gaji bulanan (asumsi 26 hari kerja/bulan)
            weekly_estimate = round(monthly_salary / 26 * workdays_this_week)
            salary_per_day  = round(monthly_salary / 26)
        else:
            salary_per_day  = daily_salary
            weekly_estimate = (present + sick + leave) * salary_per_day

        # ── Detail per hari ───────────────────────────────────────────
        att_map = {str(r['work_date']): r for r in att_rows}
        days_detail = []
        for i in range(6):   # Senin–Sabtu
            d = week_start + timedelta(days=i)
            att = att_map.get(str(d))
            days_detail.append({
                "date":         str(d),
                "day_name":     ["Senin","Selasa","Rabu","Kamis","Jumat","Sabtu"][i],
                "status":       att['status']       if att else "BELUM",
                "arrival_type": att['arrival_type'] if att else "-",
                "checkin_at":   str(att['checkin_at']) if att and att['checkin_at'] else "-",
                "note":         att['note']         if att else "",
            })

        return mobile_api_response(
            ok=True, message="OK",
            data={
                "week_start":      str(week_start),
                "week_end":        str(week_end),
                "week_label":      f"{week_start.strftime('%d %b')} – {week_end.strftime('%d %b %Y')}",
                "employee_name":   user['name'],
                "employee_email":  user['email'],
                "salary_type":     salary_type,
                "daily_salary":    salary_per_day,
                "monthly_salary":  monthly_salary,
                "workdays":        workdays_this_week,
                "days_present":    present,
                "days_sick":       sick,
                "days_leave":      leave,
                "days_absent":     absent,
                "days_late":       late,
                "weekly_salary":   weekly_estimate,
                "days_detail":     days_detail,
            },
            status_code=200
        )
    finally:
        cur.close()
        conn.close()

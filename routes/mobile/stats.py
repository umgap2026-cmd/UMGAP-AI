from datetime import date, timedelta, datetime
from calendar import monthrange
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_stats_bp = Blueprint("mobile_stats", __name__)


def _count_workdays(start_date, end_date_exc):
    """Hitung hari kerja Senin–Sabtu (Minggu libur)."""
    d, n = start_date, 0
    while d < end_date_exc:
        if d.weekday() != 6:
            n += 1
        d += timedelta(days=1)
    return n


@mobile_stats_bp.route("/stats", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_stats():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    if request.mobile_user.get("role") != "admin":
        return mobile_api_response(
            ok=False, message="Akses ditolak. Hanya admin.", status_code=403)

    date_from_str = request.args.get("date_from")
    date_to_str   = request.args.get("date_to")
    month         = request.args.get("month")

    try:
        if date_from_str and date_to_str:
            start_date    = datetime.strptime(date_from_str, "%Y-%m-%d").date()
            end_date_inc  = datetime.strptime(date_to_str,   "%Y-%m-%d").date()
            end_date      = end_date_inc + timedelta(days=1)
            period        = f"{date_from_str} s.d. {date_to_str}"
        else:
            if not month:
                today = date.today()
                month = f"{today.year:04d}-{today.month:02d}"
            year       = int(month.split("-")[0])
            mon        = int(month.split("-")[1])
            start_date = date(year, mon, 1)
            end_date   = date(year + 1, 1, 1) if mon == 12 else date(year, mon + 1, 1)
            period     = month
    except Exception as e:
        return mobile_api_response(
            ok=False, message=f"Format tanggal tidak valid: {e}", status_code=400)

    workdays = _count_workdays(start_date, end_date)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # ── Absensi + gaji per karyawan ─────────────────────────────
        cur.execute("""
            SELECT
                u.id,
                u.name                                                   AS employee_name,
                COALESCE(ps.daily_salary,   u.daily_salary, 0)          AS daily_salary,
                COALESCE(ps.monthly_salary, 0)                          AS monthly_salary,
                COALESCE(ps.salary_type, 'daily')                       AS salary_type,
                COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END), 0)      AS present_days,
                COALESCE(SUM(CASE WHEN a.arrival_type='LATE' THEN 1 ELSE 0 END), 0)   AS late_days,
                COALESCE(SUM(CASE WHEN a.status='SICK'    THEN 1 ELSE 0 END), 0)      AS sick_days,
                COALESCE(SUM(CASE WHEN a.status='LEAVE'   THEN 1 ELSE 0 END), 0)      AS leave_days,
                COALESCE(SUM(CASE WHEN a.status='ABSENT'  THEN 1 ELSE 0 END), 0)      AS absent_days
            FROM users u
            LEFT JOIN payroll_settings ps ON ps.user_id = u.id
            LEFT JOIN attendance a
                ON a.user_id = u.id
               AND a.work_date >= %s AND a.work_date < %s
            WHERE u.role = 'employee'
            GROUP BY u.id, u.name, ps.daily_salary, ps.monthly_salary, ps.salary_type,
                     u.daily_salary
            ORDER BY u.name ASC;
        """, (start_date, end_date))
        att = [dict(r) for r in cur.fetchall()]

        # ── Sales per karyawan ─────────────────────────────────────
        cur.execute("""
            SELECT u.id, COALESCE(SUM(s.qty), 0) AS sales_qty
            FROM users u
            LEFT JOIN sales_submissions s
                ON s.user_id = u.id
               AND s.created_at >= %s AND s.created_at < %s
               AND s.status = 'APPROVED'
            WHERE u.role = 'employee'
            GROUP BY u.id;
        """, (start_date, end_date))
        sales_map = {r["id"]: int(r["sales_qty"] or 0) for r in cur.fetchall()}

        # ── Gabungkan & hitung estimasi gaji ──────────────────────
        employees = []
        for emp in att:
            daily    = int(emp["daily_salary"]   or 0)
            monthly  = int(emp["monthly_salary"] or 0)
            sal_type = emp["salary_type"] or "daily"
            present  = int(emp["present_days"] or 0)
            late     = int(emp["late_days"]    or 0)
            sick     = int(emp["sick_days"]    or 0)
            leave    = int(emp["leave_days"]   or 0)
            absent   = int(emp["absent_days"]  or 0)
            worked   = present + late + sick + leave
            gaji_est = monthly if sal_type == "monthly" else worked * daily

            employees.append({
                "id":            emp["id"],
                "employee_name": emp["employee_name"],
                "daily_salary":  daily,
                "monthly_salary":monthly,
                "salary_type":   sal_type,
                "present_days":  present,
                "late_days":     late,
                "sick_days":     sick,
                "leave_days":    leave,
                "absent_days":   absent,
                "worked_days":   worked,
                "gaji_estimasi": gaji_est,
                "sales_qty":     sales_map.get(emp["id"], 0),
            })

        return mobile_api_response(
            ok=True,
            message="OK",
            data={
                "period":    period,
                "workdays":  workdays,
                "employees": employees,
            },
            status_code=200
        )
    finally:
        cur.close()
        conn.close()

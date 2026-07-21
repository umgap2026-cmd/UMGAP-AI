from datetime import date, timedelta

from flask import Blueprint, render_template, request, session, redirect
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import admin_required, is_logged_in


payroll_bp = Blueprint("payroll", __name__)


def count_workdays_only_sunday_off(start_date, end_date):
    d = start_date
    n = 0
    while d < end_date:
        if d.weekday() != 6:
            n += 1
        d = d.fromordinal(d.toordinal() + 1)
    return n


@payroll_bp.route("/admin/payroll")
def admin_payroll():
    deny = admin_required()
    if deny:
        return deny

    month = request.args.get("month")

    if not month:
        today = date.today()
        month = f"{today.year:04d}-{today.month:02d}"

    year = int(month.split("-")[0])
    mon = int(month.split("-")[1])

    start_date = date(year, mon, 1)
    end_date = date(year + 1, 1, 1) if mon == 12 else date(year, mon + 1, 1)

    WORKDAYS = count_workdays_only_sunday_off(start_date, end_date)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    cur.execute("""
        SELECT u.id, u.name,
            COALESCE(p.daily_salary, 0) AS daily_salary,
            COALESCE(p.monthly_salary, 0) AS monthly_salary,
            COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END), 0) AS days_present,
            COALESCE(SUM(CASE WHEN a.status='SICK' THEN 1 ELSE 0 END), 0) AS days_sick,
            COALESCE(SUM(CASE WHEN a.status='LEAVE' THEN 1 ELSE 0 END), 0) AS days_leave,
            COALESCE(SUM(CASE WHEN a.status='ABSENT' THEN 1 ELSE 0 END), 0) AS days_absent
        FROM users u
        LEFT JOIN payroll_settings p ON p.user_id = u.id
        LEFT JOIN attendance a ON a.user_id = u.id
            AND a.work_date >= %s AND a.work_date < %s
        WHERE u.role = 'employee'
        GROUP BY u.id, u.name, p.daily_salary, p.monthly_salary
        ORDER BY u.name ASC;
    """, (start_date, end_date))

    rows = cur.fetchall()
    cur.close()
    conn.close()

    result = []

    for r in rows:
        daily_salary = int(r.get("daily_salary") or 0)
        monthly_salary = int(r.get("monthly_salary") or 0)

        if daily_salary == 0 and monthly_salary > 0 and WORKDAYS > 0:
            daily_salary = int(round(monthly_salary / WORKDAYS))

        days_present = int(r.get("days_present") or 0)

        result.append({
            "id": r["id"],
            "name": r["name"],
            "daily_salary": daily_salary,
            "workdays": int(WORKDAYS),
            "days_present": days_present,
            "days_sick": int(r.get("days_sick") or 0),
            "days_leave": int(r.get("days_leave") or 0),
            "days_absent": int(r.get("days_absent") or 0),
            "salary_paid": int(daily_salary * days_present),
        })

    return render_template(
        "admin_payroll.html",
        month=month,
        rows=result,
        workdays=int(WORKDAYS)
    )


def _week_range(week_start_str):
    """Senin–Sabtu untuk minggu yang mengandung week_start_str (atau minggu berjalan).
    Sama seperti routes/mobile/payroll.py::_get_week_range agar slip gaji web & mobile selaras."""
    start = None
    if week_start_str:
        try:
            start = date.fromisoformat(week_start_str)
        except ValueError:
            start = None
    if start is None:
        today = date.today()
        start = today - timedelta(days=today.weekday())
    start = start - timedelta(days=start.weekday())
    end = start + timedelta(days=5)
    return start, end


@payroll_bp.route("/payslip")
def my_payslip():
    if not is_logged_in():
        return redirect("/login")

    user_id = session.get("user_id")
    week_start, week_end = _week_range(request.args.get("week", ""))

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT
                u.name, u.email,
                COALESCE(p.daily_salary,   0) AS daily_salary,
                COALESCE(p.monthly_salary, 0) AS monthly_salary,
                CASE WHEN COALESCE(p.monthly_salary, 0) > 0 THEN 'monthly' ELSE 'daily' END AS salary_type
            FROM users u
            LEFT JOIN payroll_settings p ON p.user_id = u.id
            WHERE u.id = %s
            LIMIT 1;
        """, (user_id,))
        user = cur.fetchone()

        cur.execute("""
            SELECT work_date, status, arrival_type, note, checkin_at
            FROM attendance
            WHERE user_id = %s AND work_date >= %s AND work_date <= %s
            ORDER BY work_date ASC;
        """, (user_id, week_start, week_end))
        att_rows = cur.fetchall()
    finally:
        cur.close()
        conn.close()

    present = sum(1 for r in att_rows if r["status"] == "PRESENT")
    sick    = sum(1 for r in att_rows if r["status"] == "SICK")
    leave   = sum(1 for r in att_rows if r["status"] == "LEAVE")
    absent  = sum(1 for r in att_rows if r["status"] == "ABSENT")
    late    = sum(1 for r in att_rows if r["status"] == "PRESENT" and r["arrival_type"] == "LATE")

    workdays_this_week = 6
    today = date.today()
    if week_end > today:
        workdays_this_week = min((today - week_start).days + 1, 6)

    daily_salary   = int((user or {}).get("daily_salary")   or 0)
    monthly_salary = int((user or {}).get("monthly_salary") or 0)
    salary_type    = (user or {}).get("salary_type") or "daily"

    if salary_type == "monthly" and monthly_salary > 0:
        weekly_estimate = round(monthly_salary / 26 * workdays_this_week)
        salary_per_day  = round(monthly_salary / 26)
    else:
        salary_per_day  = daily_salary
        weekly_estimate = (present + sick + leave) * salary_per_day

    att_map = {r["work_date"]: r for r in att_rows}
    day_names = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"]
    days_detail = []
    for i in range(6):
        d = week_start + timedelta(days=i)
        att = att_map.get(d)
        days_detail.append({
            "date": d,
            "day_name": day_names[i],
            "status": att["status"] if att else "BELUM",
            "arrival_type": att["arrival_type"] if att else "-",
            "checkin_at": att["checkin_at"] if att and att["checkin_at"] else None,
            "note": att["note"] if att else "",
        })

    return render_template(
        "payslip.html",
        week_start=week_start,
        week_end=week_end,
        prev_week=(week_start - timedelta(days=7)).isoformat(),
        next_week=(week_start + timedelta(days=7)).isoformat(),
        employee_name=(user or {}).get("name") or session.get("user_name"),
        salary_type=salary_type,
        daily_salary=salary_per_day,
        monthly_salary=monthly_salary,
        workdays=workdays_this_week,
        days_present=present,
        days_sick=sick,
        days_leave=leave,
        days_absent=absent,
        days_late=late,
        weekly_salary=weekly_estimate,
        days_detail=days_detail,
    )
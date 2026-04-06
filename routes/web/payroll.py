from datetime import date

from flask import Blueprint, render_template, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import admin_required


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
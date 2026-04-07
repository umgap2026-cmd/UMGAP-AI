from flask import Blueprint, request
from psycopg2.extras import RealDictCursor
from datetime import date

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_payroll_bp = Blueprint("mobile_payroll", __name__)


def count_workdays_only_sunday_off(start_date, end_date):
    d = start_date
    n = 0
    while d < end_date:
        if d.weekday() != 6:
            n += 1
        d = d.fromordinal(d.toordinal() + 1)
    return n


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
    mon = int(month.split("-")[1])

    start_date = date(year, mon, 1)
    end_date = date(year + 1, 1, 1) if mon == 12 else date(year, mon + 1, 1)
    workdays = count_workdays_only_sunday_off(start_date, end_date)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
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
        rows = [dict(r) for r in cur.fetchall()]

        return mobile_api_response(
            ok=True,
            message="OK",
            data={"month": month, "workdays": workdays, "payroll": rows},
            status_code=200
        )
    finally:
        cur.close()
        conn.close()
from datetime import date, timedelta, datetime
from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_stats_bp = Blueprint("mobile_stats", __name__)


@mobile_stats_bp.route("/stats", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_stats():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    if request.mobile_user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)

    # Support date_from/date_to ATAU month
    date_from_str = request.args.get("date_from")
    date_to_str   = request.args.get("date_to")
    month         = request.args.get("month")

    try:
        if date_from_str and date_to_str:
            start_date   = datetime.strptime(date_from_str, "%Y-%m-%d").date()
            end_date_inc = datetime.strptime(date_to_str,   "%Y-%m-%d").date()
            end_date     = end_date_inc + timedelta(days=1)
            period       = f"{date_from_str} s.d. {date_to_str}"
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
        return mobile_api_response(ok=False, message=f"Format tanggal tidak valid: {e}", status_code=400)

    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("""
            SELECT u.id, u.name AS employee_name,
                COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END), 0) AS present_days,
                COALESCE(SUM(CASE WHEN a.arrival_type='LATE' THEN 1 ELSE 0 END), 0) AS late_days,
                COALESCE(SUM(CASE WHEN a.status='SICK' THEN 1 ELSE 0 END), 0) AS sick_days,
                COALESCE(SUM(CASE WHEN a.status='LEAVE' THEN 1 ELSE 0 END), 0) AS leave_days,
                COALESCE(SUM(CASE WHEN a.status='ABSENT' THEN 1 ELSE 0 END), 0) AS absent_days
            FROM users u
            LEFT JOIN attendance a
                ON a.user_id=u.id
                AND a.work_date >= %s AND a.work_date < %s
            WHERE u.role='employee'
            GROUP BY u.id, u.name
            ORDER BY u.name ASC;
        """, (start_date, end_date))
        att = [dict(r) for r in cur.fetchall()]

        cur.execute("""
            SELECT u.id, COALESCE(SUM(s.qty), 0) AS sales_qty
            FROM users u
            LEFT JOIN sales_submissions s
                ON s.user_id=u.id
                AND s.created_at >= %s AND s.created_at < %s
                AND s.status = 'APPROVED'
            WHERE u.role='employee'
            GROUP BY u.id;
        """, (start_date, end_date))
        sales = [dict(r) for r in cur.fetchall()]

        return mobile_api_response(
            ok=True,
            message="OK",
            data={"period": period, "attendance": att, "sales": sales},
            status_code=200
        )
    finally:
        cur.close()
        conn.close()

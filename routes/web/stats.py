from datetime import date

from flask import Blueprint, render_template, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import admin_guard

stats_bp = Blueprint("stats", __name__)


@stats_bp.route("/admin/stats")
def admin_stats():
    admin_guard()

    month = request.args.get("month")
    if not month:
        today = date.today()
        month = f"{today.year:04d}-{today.month:02d}"

    year = int(month.split("-")[0])
    mon = int(month.split("-")[1])

    start_date = date(year, mon, 1)
    end_date = date(year + 1, 1, 1) if mon == 12 else date(year, mon + 1, 1)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

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
        att = cur.fetchall()

        cur.execute("""
            SELECT u.id, COALESCE(SUM(s.qty), 0) AS sales_qty
            FROM users u
            LEFT JOIN sales_submissions s
                ON s.user_id=u.id
                AND s.created_at >= %s AND s.created_at < %s
            WHERE u.role='employee'
            GROUP BY u.id;
        """, (start_date, end_date))
        sales = cur.fetchall()

    finally:
        cur.close()
        conn.close()

    sales_map = {r["id"]: int(r["sales_qty"] or 0) for r in sales}

    rows = []
    totals = {"present": 0, "late": 0, "sick": 0, "leave": 0, "absent": 0, "sales": 0}

    for r in att:
        row = {
            "employee_name": r["employee_name"],
            "present_days": int(r["present_days"] or 0),
            "late_days": int(r["late_days"] or 0),
            "sick_days": int(r["sick_days"] or 0),
            "leave_days": int(r["leave_days"] or 0),
            "absent_days": int(r["absent_days"] or 0),
            "sales_qty": sales_map.get(r["id"], 0),
        }

        totals["present"] += row["present_days"]
        totals["late"] += row["late_days"]
        totals["sick"] += row["sick_days"]
        totals["leave"] += row["leave_days"]
        totals["absent"] += row["absent_days"]
        totals["sales"] += row["sales_qty"]

        rows.append(row)

    return render_template(
        "admin_stats.html",
        month=month,
        rows=rows,
        totals=totals
    )
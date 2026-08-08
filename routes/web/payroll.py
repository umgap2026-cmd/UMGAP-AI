from datetime import date, timedelta

from flask import Blueprint, render_template, request, session, redirect, flash
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import (
    admin_required, is_logged_in, _parse_date,
    get_payroll_report, add_payroll_adjustment, delete_payroll_adjustment,
    record_payroll_payment,
)


payroll_bp = Blueprint("payroll", __name__)


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


@payroll_bp.route("/admin/payroll")
def admin_payroll():
    deny = admin_required()
    if deny:
        return deny

    mode = (request.args.get("mode") or "month").strip().lower()
    if mode not in ("month", "week"):
        mode = "month"

    month = request.args.get("month")
    if not month:
        today = date.today()
        month = f"{today.year:04d}-{today.month:02d}"

    if mode == "week":
        week_start, week_end = _week_range(request.args.get("week", ""))
        start_date = week_start
        end_date = week_end  # inklusif, Senin..Sabtu

        # Minggu berjalan (belum selesai) -> hari kerja cuma sampai hari ini
        # yg ditampilkan di stat pill, sama spt /payslip -- ini murni
        # tampilan, tidak mengubah rumus gaji (mode week selalu /26).
        WORKDAYS_DISPLAY = 6
        today = date.today()
        if week_end > today:
            WORKDAYS_DISPLAY = max(min((today - week_start).days + 1, 6), 0)

        period_label = f"{week_start.strftime('%d %b')} – {week_end.strftime('%d %b %Y')}"
    else:
        year = int(month.split("-")[0])
        mon = int(month.split("-")[1])

        start_date = date(year, mon, 1)
        end_date_exclusive = date(year + 1, 1, 1) if mon == 12 else date(year, mon + 1, 1)
        end_date = end_date_exclusive - timedelta(days=1)  # inklusif

        WORKDAYS_DISPLAY = None  # dihitung dari get_payroll_report di bawah
        week_start = week_end = None
        period_label = month

    result, workdays = get_payroll_report(start_date, end_date)
    if WORKDAYS_DISPLAY is not None:
        workdays = WORKDAYS_DISPLAY

    return render_template(
        "admin_payroll.html",
        mode=mode,
        month=month,
        week_start=week_start,
        week_end=week_end,
        prev_week=(week_start - timedelta(days=7)).isoformat() if week_start else "",
        next_week=(week_start + timedelta(days=7)).isoformat() if week_start else "",
        period_label=period_label,
        start_date=start_date,
        end_date=end_date,
        rows=result,
        workdays=int(workdays),
    )


def _payroll_redirect_url():
    """Balik ke halaman Gaji Karyawan dgn periode (mode/month/week) yg lagi
    dibuka -- dikirim form sbg hidden field spy admin tidak ke-reset ke
    periode default habis nambah penyesuaian / bayar gaji."""
    mode = (request.form.get("mode") or "month").strip().lower()
    if mode == "week":
        week = (request.form.get("week") or "").strip()
        return f"/admin/payroll?mode=week&week={week}"
    month = (request.form.get("month") or "").strip()
    return f"/admin/payroll?mode=month&month={month}"


@payroll_bp.route("/admin/payroll/adjustments/add", methods=["POST"])
def admin_payroll_adjustment_add():
    deny = admin_required()
    if deny:
        return deny

    try:
        user_id = int(request.form.get("user_id"))
    except (TypeError, ValueError):
        flash("Pilih karyawan dulu.", "danger")
        return redirect(_payroll_redirect_url())

    adjustment_date = _parse_date((request.form.get("adjustment_date") or "").strip())
    kind = (request.form.get("kind") or "potongan").strip().lower()
    try:
        amount = abs(float(request.form.get("amount") or 0))
    except ValueError:
        amount = 0

    if kind == "potongan":
        amount = -amount

    try:
        add_payroll_adjustment(
            user_id=user_id,
            adjustment_date=adjustment_date,
            amount=amount,
            note=request.form.get("note"),
            created_by=session.get("user_id"),
        )
        flash("Penyesuaian gaji berhasil dicatat.", "success")
    except ValueError as e:
        flash(str(e), "danger")

    return redirect(_payroll_redirect_url())


@payroll_bp.route("/admin/payroll/adjustments/<int:adjustment_id>/delete", methods=["POST"])
def admin_payroll_adjustment_delete(adjustment_id):
    deny = admin_required()
    if deny:
        return deny

    try:
        delete_payroll_adjustment(adjustment_id)
        flash("Penyesuaian dihapus.", "success")
    except ValueError as e:
        flash(str(e), "danger")

    return redirect(_payroll_redirect_url())


@payroll_bp.route("/admin/payroll/pay", methods=["POST"])
def admin_payroll_pay():
    deny = admin_required()
    if deny:
        return deny

    try:
        user_id = int(request.form.get("user_id"))
        employee_name = request.form.get("employee_name") or "-"
        period_start = _parse_date(request.form.get("period_start"))
        period_end = _parse_date(request.form.get("period_end"))
        amount = float(request.form.get("amount") or 0)
    except (TypeError, ValueError):
        flash("Data pembayaran tidak valid.", "danger")
        return redirect(_payroll_redirect_url())

    try:
        record_payroll_payment(
            user_id=user_id, employee_name=employee_name,
            period_start=period_start, period_end=period_end,
            amount=amount, created_by=session.get("user_id"),
        )
        flash(f"Gaji {employee_name} dicatat sbg Beban di Finance.", "success")
    except ValueError as e:
        flash(str(e), "danger")

    return redirect(_payroll_redirect_url())



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
"""
routes/mobile/stats_export.py

Endpoint:
  GET /api/mobile/stats/export?month=YYYY-MM
  → Download file Excel (.xlsx) laporan statistik bulanan

Package yang dibutuhkan di requirements.txt:
  openpyxl>=3.1.2
"""

from datetime import date
from io import BytesIO

from flask import Blueprint, request, send_file
from psycopg2.extras import RealDictCursor

try:
    import openpyxl
    from openpyxl.styles import (
        Font, PatternFill, Alignment, Border, Side, GradientFill
    )
    from openpyxl.utils import get_column_letter
    HAS_OPENPYXL = True
except ImportError:
    HAS_OPENPYXL = False

from db import get_conn
from core import mobile_api_response, mobile_api_login_required

mobile_stats_export_bp = Blueprint("mobile_stats_export", __name__)


# ── Color palette ────────────────────────────────────────────────
_BLUE_HDR   = "1565C0"   # Header utama
_BLUE_SUBHDR= "1E88E5"   # Sub-header
_BLUE_LIGHT = "E3F0FF"   # Baris genap
_BLUE_MED   = "BBDEFB"   # Summary row
_WHITE      = "FFFFFF"
_GREY_LIGHT = "F5F5F5"
_GREEN      = "2E7D32"
_ORANGE     = "E65100"
_RED        = "C62828"
_PURPLE     = "6A1B9A"
_TEAL       = "00838F"
_DARK       = "0D1B3E"


def _border(style="thin"):
    s = Side(style=style, color="BDBDBD")
    return Border(left=s, right=s, top=s, bottom=s)


def _fill(hex_color):
    return PatternFill("solid", fgColor=hex_color)


def _font(bold=False, color=_DARK, size=10):
    return Font(bold=bold, color=color, size=size, name="Calibri")


def _align(h="left", v="center", wrap=False):
    return Alignment(horizontal=h, vertical=v, wrap_text=wrap)


# ── Fetch data ───────────────────────────────────────────────────
def _fetch_data(start_date, end_date):
    conn = get_conn()
    cur  = conn.cursor(cursor_factory=RealDictCursor)
    try:
        # Absensi per karyawan
        cur.execute("""
            SELECT
                u.id,
                u.name  AS employee_name,
                COALESCE(SUM(CASE WHEN a.status='PRESENT' THEN 1 ELSE 0 END), 0) AS present_days,
                COALESCE(SUM(CASE WHEN a.arrival_type='LATE' THEN 1 ELSE 0 END), 0) AS late_days,
                COALESCE(SUM(CASE WHEN a.status='SICK' THEN 1 ELSE 0 END), 0)    AS sick_days,
                COALESCE(SUM(CASE WHEN a.status='LEAVE' THEN 1 ELSE 0 END), 0)   AS leave_days,
                COALESCE(SUM(CASE WHEN a.status='ABSENT' THEN 1 ELSE 0 END), 0)  AS absent_days
            FROM users u
            LEFT JOIN attendance a
                ON a.user_id = u.id
               AND a.work_date >= %s AND a.work_date < %s
            WHERE u.role = 'employee'
            GROUP BY u.id, u.name
            ORDER BY u.name ASC;
        """, (start_date, end_date))
        att = [dict(r) for r in cur.fetchall()]

        # Sales per karyawan
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
        sales_map = {r["id"]: r["sales_qty"] for r in cur.fetchall()}

        # Gabungkan
        rows = []
        for emp in att:
            rows.append({
                "name":         emp["employee_name"],
                "present":      int(emp["present_days"]  or 0),
                "late":         int(emp["late_days"]     or 0),
                "sick":         int(emp["sick_days"]      or 0),
                "leave":        int(emp["leave_days"]     or 0),
                "absent":       int(emp["absent_days"]    or 0),
                "sales_qty":    int(sales_map.get(emp["id"], 0)),
            })

        return rows
    finally:
        cur.close()
        conn.close()


# ── Build Excel ──────────────────────────────────────────────────
def _build_excel(rows, month_label):
    wb = openpyxl.Workbook()

    # ════ Sheet 1: Rekap Absensi ════
    ws = wb.active
    ws.title = "Rekap Absensi"
    ws.sheet_view.showGridLines = False

    # -- Baris judul utama --
    ws.merge_cells("A1:I1")
    c = ws["A1"]
    c.value    = "UMGAP — Laporan Statistik Bulanan"
    c.font     = _font(bold=True, color=_WHITE, size=14)
    c.fill     = _fill(_BLUE_HDR)
    c.alignment= _align("center")

    ws.merge_cells("A2:I2")
    c2 = ws["A2"]
    c2.value     = f"Periode: {month_label}     |     Dicetak: {date.today().strftime('%d %B %Y')}"
    c2.font      = _font(color=_WHITE, size=10)
    c2.fill      = _fill(_BLUE_SUBHDR)
    c2.alignment = _align("center")

    ws.append([])  # baris 3 kosong

    # -- Header tabel --
    headers = ["No", "Nama Karyawan", "Hadir", "Terlambat", "Sakit", "Izin", "Absen", "Total Kerja", "Kehadiran %"]
    header_colors = [_BLUE_HDR, _BLUE_HDR, _GREEN, _ORANGE, _PURPLE, _TEAL, _RED, _BLUE_SUBHDR, _BLUE_SUBHDR]

    ws.append(headers)
    for col_idx, (hdr, color) in enumerate(zip(headers, header_colors), start=1):
        cell = ws.cell(row=4, column=col_idx)
        cell.value     = hdr
        cell.font      = _font(bold=True, color=_WHITE, size=10)
        cell.fill      = _fill(color)
        cell.alignment = _align("center")
        cell.border    = _border()

    # -- Data rows --
    total_present = total_late = total_sick = total_leave = total_absent = 0

    for i, row in enumerate(rows, start=1):
        r_idx   = 4 + i
        work    = row["present"] + row["late"] + row["sick"] + row["leave"]
        total   = work + row["absent"]
        pct     = round(work / total * 100, 1) if total > 0 else 0
        bg      = _BLUE_LIGHT if i % 2 == 0 else _WHITE

        cells = [
            i,
            row["name"],
            row["present"],
            row["late"],
            row["sick"],
            row["leave"],
            row["absent"],
            work,
            f"{pct}%",
        ]
        col_fmts = [
            (_align("center"), None),
            (_align("left"),   None),
            (_align("center"), _GREEN   if row["present"] > 0 else None),
            (_align("center"), _ORANGE  if row["late"]    > 0 else None),
            (_align("center"), _PURPLE  if row["sick"]    > 0 else None),
            (_align("center"), _TEAL    if row["leave"]   > 0 else None),
            (_align("center"), _RED     if row["absent"]  > 0 else None),
            (_align("center"), None),
            (_align("center"), _GREEN   if pct >= 80 else (_ORANGE if pct >= 60 else _RED)),
        ]

        for col_idx, (val, (aln, fc)) in enumerate(zip(cells, col_fmts), start=1):
            cell           = ws.cell(row=r_idx, column=col_idx, value=val)
            cell.fill      = _fill(bg)
            cell.alignment = aln
            cell.border    = _border()
            cell.font      = _font(bold=(col_idx == 2), color=(fc or _DARK))

        total_present += row["present"]
        total_late    += row["late"]
        total_sick    += row["sick"]
        total_leave   += row["leave"]
        total_absent  += row["absent"]

    # -- Summary row --
    s_row = 4 + len(rows) + 1
    ws.append([])  # spacer

    total_work = total_present + total_late + total_sick + total_leave
    total_all  = total_work + total_absent
    avg_pct    = round(total_work / total_all * 100, 1) if total_all > 0 else 0

    summary = ["", "TOTAL / RATA-RATA", total_present, total_late, total_sick,
               total_leave, total_absent, total_work, f"{avg_pct}%"]
    for col_idx, val in enumerate(summary, start=1):
        cell           = ws.cell(row=s_row + 1, column=col_idx, value=val)
        cell.font      = _font(bold=True, color=_WHITE)
        cell.fill      = _fill(_BLUE_HDR)
        cell.alignment = _align("center")
        cell.border    = _border()

    # -- Legend box --
    legend_start = s_row + 3
    ws.cell(row=legend_start, column=1, value="Keterangan:").font = _font(bold=True)
    legend_items = [
        ("Hijau", "Hadir / Tepat waktu"),
        ("Oranye", "Terlambat"),
        ("Ungu", "Sakit"),
        ("Teal", "Izin / Cuti"),
        ("Merah", "Absen tanpa keterangan"),
        ("Kehadiran % ≥ 80%", "Baik"),
        ("Kehadiran % 60–79%", "Perlu perhatian"),
        ("Kehadiran % < 60%", "Kritis"),
    ]
    for j, (key, val) in enumerate(legend_items):
        ws.cell(row=legend_start + j + 1, column=1, value=f"• {key}:").font = _font(size=9)
        ws.cell(row=legend_start + j + 1, column=2, value=val).font = _font(size=9, color="555555")

    # -- Column widths --
    col_widths = [5, 28, 10, 12, 10, 8, 10, 13, 14]
    for idx, w in enumerate(col_widths, start=1):
        ws.column_dimensions[get_column_letter(idx)].width = w

    # -- Row heights --
    ws.row_dimensions[1].height = 30
    ws.row_dimensions[2].height = 20
    ws.row_dimensions[4].height = 22
    for r in range(5, 5 + len(rows)):
        ws.row_dimensions[r].height = 18

    # ════ Sheet 2: Data Sales ════
    ws2 = wb.create_sheet("Data Sales")
    ws2.sheet_view.showGridLines = False

    ws2.merge_cells("A1:D1")
    c = ws2["A1"]
    c.value     = "UMGAP — Data Sales Karyawan"
    c.font      = _font(bold=True, color=_WHITE, size=13)
    c.fill      = _fill(_TEAL)
    c.alignment = _align("center")

    ws2.merge_cells("A2:D2")
    c2 = ws2["A2"]
    c2.value     = f"Periode: {month_label}"
    c2.font      = _font(color=_WHITE)
    c2.fill      = _fill("00838F")
    c2.alignment = _align("center")

    ws2.append([])

    sales_headers = ["No", "Nama Karyawan", "Total Qty Terjual", "Keterangan"]
    for col_idx, hdr in enumerate(sales_headers, start=1):
        cell           = ws2.cell(row=4, column=col_idx, value=hdr)
        cell.font      = _font(bold=True, color=_WHITE)
        cell.fill      = _fill(_TEAL)
        cell.alignment = _align("center")
        cell.border    = _border()

    rows_sorted = sorted(rows, key=lambda x: x["sales_qty"], reverse=True)
    for i, row in enumerate(rows_sorted, start=1):
        r_idx   = 4 + i
        bg      = "E0F7FA" if i % 2 == 0 else _WHITE
        keterangan = "Top Sales 🏆" if i == 1 and row["sales_qty"] > 0 else (
            "Tinggi" if row["sales_qty"] >= 50 else (
            "Sedang" if row["sales_qty"] >= 20 else (
            "Rendah" if row["sales_qty"] > 0  else "Belum ada")))

        for col_idx, val in enumerate([i, row["name"], row["sales_qty"], keterangan], start=1):
            cell           = ws2.cell(row=r_idx, column=col_idx, value=val)
            cell.fill      = _fill(bg)
            cell.border    = _border()
            cell.alignment = _align("center" if col_idx != 2 else "left")
            cell.font      = _font(bold=(col_idx == 2))

    ws2.column_dimensions["A"].width = 5
    ws2.column_dimensions["B"].width = 28
    ws2.column_dimensions["C"].width = 20
    ws2.column_dimensions["D"].width = 18
    ws2.row_dimensions[1].height = 28
    ws2.row_dimensions[4].height = 20

    # ════ Sheet 3: Ringkasan Eksekutif ════
    ws3 = wb.create_sheet("Ringkasan")
    ws3.sheet_view.showGridLines = False
    ws3.merge_cells("A1:C1")
    c = ws3["A1"]
    c.value     = "Ringkasan Eksekutif"
    c.font      = _font(bold=True, color=_WHITE, size=13)
    c.fill      = _fill(_DARK)
    c.alignment = _align("center")
    ws3.row_dimensions[1].height = 28

    total_emp = len(rows)
    avg_present = round(total_present / total_emp, 1) if total_emp else 0

    summary_items = [
        ("Total Karyawan",            total_emp,    _BLUE_HDR),
        ("Total Hari Hadir",          total_present,_GREEN),
        ("Total Hari Terlambat",      total_late,   _ORANGE),
        ("Total Hari Sakit",          total_sick,   _PURPLE),
        ("Total Hari Izin",           total_leave,  _TEAL),
        ("Total Hari Absen",          total_absent, _RED),
        ("Rata-rata Hadir/Orang",     avg_present,  _BLUE_HDR),
        ("Rata-rata Kehadiran %",     f"{avg_pct}%",_BLUE_HDR),
    ]

    for j, (label, val, color) in enumerate(summary_items, start=2):
        ws3.cell(row=j, column=1, value=label).font = _font(bold=True)
        c = ws3.cell(row=j, column=2, value=val)
        c.font      = _font(bold=True, color=color, size=12)
        c.alignment = _align("center")
        ws3.cell(row=j, column=1).fill = _fill(_GREY_LIGHT if j % 2 == 0 else _WHITE)
        ws3.cell(row=j, column=2).fill = _fill(_GREY_LIGHT if j % 2 == 0 else _WHITE)

    ws3.column_dimensions["A"].width = 28
    ws3.column_dimensions["B"].width = 16

    # ── Freeze panes di semua sheet
    for sheet in [ws, ws2, ws3]:
        sheet.freeze_panes = sheet["A5"] if sheet != ws3 else None

    buf = BytesIO()
    wb.save(buf)
    buf.seek(0)
    return buf


# ── Endpoint ─────────────────────────────────────────────────────

@mobile_stats_export_bp.route("/stats/export", methods=["GET", "OPTIONS"])
@mobile_api_login_required
def mobile_stats_export():
    if request.method == "OPTIONS":
        return mobile_api_response(ok=True, message="OK", data={}, status_code=200)

    if request.mobile_user.get("role") != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak.", status_code=403)

    if not HAS_OPENPYXL:
        return mobile_api_response(
            ok=False,
            message="openpyxl belum terinstall. Jalankan: pip install openpyxl",
            status_code=500,
        )

    from datetime import datetime, timedelta

    # Support date_from/date_to (rentang tanggal) ATAU month (bulan)
    date_from_str = request.args.get("date_from")
    date_to_str   = request.args.get("date_to")
    month         = request.args.get("month")

    try:
        if date_from_str and date_to_str:
            start_date  = datetime.strptime(date_from_str, "%Y-%m-%d").date()
            end_date_inc = datetime.strptime(date_to_str, "%Y-%m-%d").date()
            end_date    = end_date_inc + timedelta(days=1)
            month_label = f"{start_date.strftime('%d %b')} s.d. {end_date_inc.strftime('%d %b %Y')}"
            filename_tag = f"{date_from_str}_sd_{date_to_str}"
        else:
            if not month:
                today = date.today()
                month = f"{today.year:04d}-{today.month:02d}"
            year = int(month.split("-")[0])
            mon  = int(month.split("-")[1])
            start_date = date(year, mon, 1)
            end_date   = date(year + 1, 1, 1) if mon == 12 else date(year, mon + 1, 1)
            month_names = ["","Januari","Februari","Maret","April","Mei","Juni",
                           "Juli","Agustus","September","Oktober","November","Desember"]
            month_label  = f"{month_names[mon]} {year}"
            filename_tag = f"{year}_{mon:02d}"
    except Exception as e:
        return mobile_api_response(ok=False, message=f"Format tanggal tidak valid: {e}", status_code=400)

    rows     = _fetch_data(start_date, end_date)
    buf      = _build_excel(rows, month_label)
    filename = f"UMGAP_Statistik_{filename_tag}.xlsx"

    return send_file(
        buf,
        as_attachment=True,
        download_name=filename,
        mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    )

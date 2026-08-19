from datetime import date

from flask import Blueprint, render_template, request, redirect, session, flash, jsonify

from core import (
    owner_or_admin_required, owner_required, get_notif_count,
    list_fin_materials, add_fin_material, edit_fin_material, delete_fin_material,
    add_fin_material_stock, reduce_fin_material_stock,
    perform_stock_opname, get_fin_shrinkage_report, get_fin_margin_report,
    get_fin_hpp_orphan_report,
    list_fin_debts, pay_fin_debt, create_fin_debt_entry, edit_fin_debt, delete_fin_debt,
    merge_fin_debts,
    list_fin_party_names,
    list_fin_categories, list_fin_activity_log,
    create_fin_expense_entry, list_fin_expenses, list_fin_expense_categories,
    edit_fin_expense_entry, delete_fin_expense_entry,
    create_fin_trip_web, list_fin_trips_web, get_fin_trip_web_detail,
    add_fin_trip_party, record_fin_trip_sell, record_fin_trip_buy,
    record_fin_trip_expense, record_fin_trip_susut,
    edit_fin_trip_item, delete_fin_trip_item,
    close_fin_trip_web, cancel_fin_trip_web,
    delete_fin_trip_web, get_materials_with_stock,
    get_owner_finance_report, get_owner_phone,
)

REDUCE_STOCK_REASONS = {
    "KOTOR": "Kotor/Kontaminasi",
    "SUSUT": "Susut/Menguap",
    "RUSAK": "Rusak",
}

finance_bp = Blueprint("finance", __name__)


@finance_bp.route("/finance")
def finance_dashboard():
    """Satu halaman Finance: ringkasan, barang gudang/stok, dan hutang-piutang."""
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        log_page = max(1, int(request.args.get("log_page", 1)))
    except (TypeError, ValueError):
        log_page = 1
    log_page_size = 50

    materials, total_value = list_fin_materials()
    debts = list_fin_debts()
    categories = list_fin_categories()
    activity_log, log_has_next = list_fin_activity_log(
        limit=log_page_size, offset=(log_page - 1) * log_page_size,
    )
    expenses = list_fin_expenses()
    expense_categories = list_fin_expense_categories()
    expense_total = sum(float(e["total_amount"] or 0) for e in expenses)

    return render_template(
        "finance_dashboard.html",
        materials=materials,
        total_value=total_value,
        debts=debts,
        categories=categories,
        activity_log=activity_log,
        log_page=log_page,
        log_has_next=log_has_next,
        log_has_prev=log_page > 1,
        expenses=expenses,
        expense_categories=expense_categories,
        expense_total=expense_total,
        notif_count=get_notif_count(),
        party_names=list_fin_party_names(),
        owner_phone=get_owner_phone(),
    )


# ---------- BARANG GUDANG (fin_materials) ----------
@finance_bp.route("/finance/materials/add", methods=["POST"])
def finance_materials_add():
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        result = add_fin_material(
            name=request.form.get("name"),
            unit=request.form.get("unit"),
            init_qty=request.form.get("init_qty"),
            init_price=request.form.get("init_price"),
            note=request.form.get("note"),
            created_by=session.get("user_id"),
            category=request.form.get("category"),
        )
        flash(f"Barang '{result['name']}' berhasil ditambahkan.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


@finance_bp.route("/finance/materials/<int:material_id>/edit", methods=["POST"])
def finance_materials_edit(material_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        edit_fin_material(
            material_id,
            request.form.get("name"),
            request.form.get("unit"),
            session.get("user_id"),
            category=request.form.get("category"),
        )
        flash("Barang berhasil diperbarui.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


@finance_bp.route("/finance/materials/<int:material_id>/add-stock", methods=["POST"])
def finance_materials_add_stock(material_id):
    """Tambah stok untuk barang yang sudah ada (mis. stoknya masih 0),
    tanpa lewat alur Nota/Kasir Beli formal ke pemasok."""
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        result = add_fin_material_stock(
            material_id,
            qty=request.form.get("qty"),
            price=request.form.get("price"),
            note=request.form.get("note"),
            created_by=session.get("user_id"),
        )
        flash(f"Stok '{result['name']}' berhasil ditambah.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


@finance_bp.route("/finance/materials/<int:material_id>/reduce-stock", methods=["POST"])
def finance_materials_reduce_stock(material_id):
    """Kurangi stok barang yang sudah ada karena kotor/susut/rusak, tanpa
    lewat penjualan -- HPP & nilai stok ikut disesuaikan otomatis."""
    deny = owner_or_admin_required()
    if deny:
        return deny

    reason_template = (request.form.get("reason_template") or "").strip().upper()
    if reason_template == "LAINNYA":
        reason = (request.form.get("reason_other") or "").strip()
    else:
        reason = REDUCE_STOCK_REASONS.get(reason_template, reason_template)

    try:
        result = reduce_fin_material_stock(
            material_id,
            qty=request.form.get("qty"),
            reason=reason,
            note=request.form.get("note"),
            created_by=session.get("user_id"),
        )
        flash(f"Stok '{result['name']}' berhasil dikurangi.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


@finance_bp.route("/finance/materials/<int:material_id>/opname", methods=["POST"])
def finance_materials_opname(material_id):
    """Opname: bandingkan stok fisik hasil timbang vs stok buku, sistem
    otomatis catat selisihnya sbg koreksi tambah atau susut."""
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        result = perform_stock_opname(
            material_id,
            actual_qty=request.form.get("actual_qty"),
            note=request.form.get("note"),
            created_by=session.get("user_id"),
            price=request.form.get("price"),
        )
        if result["type"] == "sesuai":
            flash(f"Stok '{result['name']}' sudah sesuai, tidak ada penyesuaian.", "success")
        elif result["type"] == "koreksi_tambah":
            flash(f"Opname: ditemukan kelebihan {result['diff']:.1f} — stok '{result['name']}' dikoreksi tambah.", "success")
        else:
            flash(f"Opname: ditemukan susut {abs(result['diff']):.1f} pada '{result['name']}'.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


@finance_bp.route("/finance/shrinkage-report")
def finance_shrinkage_report():
    """Laporan Susut: per barang, total masuk/keluar/susut & % susut dalam
    rentang tanggal."""
    deny = owner_or_admin_required()
    if deny:
        return deny

    today = date.today()
    date_from = request.args.get("from") or today.replace(day=1).isoformat()
    date_to = request.args.get("to") or today.isoformat()

    report = get_fin_shrinkage_report(date_from, date_to)
    return render_template(
        "finance_shrinkage_report.html",
        report=report,
        date_from=date_from,
        date_to=date_to,
        notif_count=get_notif_count(),
        today_iso=today.isoformat(),
        month_start_iso=today.replace(day=1).isoformat(),
    )


@finance_bp.route("/finance/margin-report")
def finance_margin_report():
    """Laporan Margin: per barang, omzet vs HPP (AVCO) & margin dalam
    rentang tanggal -- supaya kelihatan barang yg terjual di bawah HPP."""
    deny = owner_or_admin_required()
    if deny:
        return deny

    today = date.today()
    date_from = request.args.get("from") or today.replace(day=1).isoformat()
    date_to = request.args.get("to") or today.isoformat()

    report = get_fin_margin_report(date_from, date_to)
    return render_template(
        "finance_margin_report.html",
        report=report,
        date_from=date_from,
        date_to=date_to,
        notif_count=get_notif_count(),
        today_iso=today.isoformat(),
        month_start_iso=today.replace(day=1).isoformat(),
    )


@finance_bp.route("/finance/hpp-diagnostics")
def finance_hpp_diagnostics():
    """Diagnostik khusus Owner: cari penjualan yg HPP-nya jatuh ke fallback
    harga rata-rata SAAT INI krn tidak ada catatan biaya di titik waktu
    penjualannya -- bisa bikin laporan HPP historis keliru."""
    deny = owner_required()
    if deny:
        return deny

    result = get_fin_hpp_orphan_report()
    return render_template(
        "finance_hpp_diagnostics.html",
        result=result,
        notif_count=get_notif_count(),
    )


@finance_bp.route("/finance/materials/<int:material_id>/delete", methods=["POST"])
def finance_materials_delete(material_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        mat_name = delete_fin_material(material_id, session.get("user_id"))
        flash(f'Barang "{mat_name}" dinonaktifkan.', "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


# ---------- HUTANG (ke pemasok) & PIUTANG ----------
@finance_bp.route("/finance/debts/add", methods=["POST"])
def finance_debts_add():
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        create_fin_debt_entry(
            debt_type=request.form.get("type"),
            party_name=request.form.get("party_name"),
            amount=request.form.get("amount"),
            note=request.form.get("note"),
            entry_date=request.form.get("date"),
            reason=request.form.get("reason"),
        )
        flash("Berhasil dicatat.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


@finance_bp.route("/finance/debts/<int:debt_id>/edit", methods=["POST"])
def finance_debts_edit(debt_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        edit_fin_debt(
            debt_id,
            party_name=request.form.get("party_name"),
            amount=request.form.get("amount"),
            note=request.form.get("note"),
        )
        flash("Berhasil diperbarui.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


@finance_bp.route("/finance/debts/<int:debt_id>/pay", methods=["POST"])
def finance_debts_pay(debt_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        result = pay_fin_debt(debt_id, request.form.get("amount"))
        flash("Lunas! 🎉" if result["is_settled"] else "Pembayaran dicatat.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


@finance_bp.route("/finance/debts/<int:debt_id>/delete", methods=["POST"])
def finance_debts_delete(debt_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        name = delete_fin_debt(debt_id)
        flash(f'"{name}" berhasil dihapus.', "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


@finance_bp.route("/finance/debts/merge", methods=["POST"])
def finance_debts_merge():
    deny = owner_or_admin_required()
    if deny:
        return deny

    debt_ids = [d for d in (request.form.get("debt_ids") or "").split(",") if d.strip()]
    party_name = request.form.get("party_name")
    # Field catatan SENGAJA selalu dikirim dari form (biar admin bisa edit
    # gabungan otomatis atau ganti total dgn catatan baru) -- kosongkan
    # kalau memang mau kosong, bukan "tidak diisi".
    note = request.form.get("note")

    try:
        result = merge_fin_debts(debt_ids, party_name=party_name, note=note)
        flash(f"{result['merged_count']} baris berhasil digabung jadi 1.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


# ---------- BEBAN (biaya operasional) ----------
@finance_bp.route("/finance/expenses/add", methods=["POST"])
def finance_expenses_add():
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        result = create_fin_expense_entry(
            category=request.form.get("category"),
            amount=request.form.get("amount"),
            note=request.form.get("note"),
            created_by=session.get("user_id"),
            expense_date=request.form.get("date"),
        )
        flash(f"Beban '{result['category']}' berhasil dicatat.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


@finance_bp.route("/finance/expenses/<int:expense_id>/edit", methods=["POST"])
def finance_expenses_edit(expense_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        edit_fin_expense_entry(
            expense_id,
            category=request.form.get("category"),
            amount=request.form.get("amount"),
            note=request.form.get("note"),
        )
        flash("Beban berhasil diperbarui.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


@finance_bp.route("/finance/expenses/<int:expense_id>/delete", methods=["POST"])
def finance_expenses_delete(expense_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        name = delete_fin_expense_entry(expense_id)
        flash(f'Beban "{name}" berhasil dihapus.', "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


# ---------- MODE PERJALANAN ----------
# Catatan: pakai skema fin_trips/fin_trip_items/fin_trip_parties yang sudah
# ada & dipakai fitur mobile "Perjalanan Jakarta" (routes/mobile/finance.py)
# -- BUKAN skema baru. Beli/Jual/Beban di sini tercatat sbg fin_trip_items,
# terpisah dari Nota gudang biasa (fin_transactions).

def _trip_ajax_response(trip_id, ok, message):
    """Sell/buy/expense dipanggil berkali-kali dari cart JS (spt pembuat
    nota -- tambah beberapa baris, baru simpan sekaligus) via fetch(), jadi
    butuh JSON supaya error per-baris (mis. stok tidak cukup) bisa dideteksi
    -- redirect+flash lama tidak bisa dibaca fetch() krn ikut di-follow jadi
    200 apapun hasilnya. Form-post biasa (non-JS) tetap redirect spt semula."""
    if request.headers.get("X-Requested-With") == "fetch":
        return jsonify({"ok": ok, "message": message})
    flash(message, "success" if ok else "danger")
    return redirect(f"/finance/trips/{trip_id}")
@finance_bp.route("/finance/trips")
def finance_trips():
    deny = owner_or_admin_required()
    if deny:
        return deny

    trips = list_fin_trips_web()
    return render_template(
        "finance_trips.html",
        trips=trips,
        notif_count=get_notif_count(),
    )


@finance_bp.route("/finance/trips/add", methods=["POST"])
def finance_trips_add():
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        result = create_fin_trip_web(
            note=request.form.get("note"),
            trip_date=request.form.get("trip_date"),
            created_by=session.get("user_id"),
        )
        flash("Perjalanan dibuka.", "success")
        return redirect(f"/finance/trips/{result['id']}")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance/trips")


@finance_bp.route("/finance/trips/<int:trip_id>")
def finance_trip_detail(trip_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        trip = get_fin_trip_web_detail(trip_id)
    except ValueError as e:
        flash(str(e), "danger")
        return redirect("/finance/trips")

    materials, _total = list_fin_materials()
    return render_template(
        "finance_trip_detail.html",
        trip=trip,
        materials=materials,
        notif_count=get_notif_count(),
    )


@finance_bp.route("/finance/trips/<int:trip_id>/party", methods=["POST"])
def finance_trip_add_party(trip_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        add_fin_trip_party(
            trip_id,
            name=request.form.get("name"),
            note=request.form.get("note"),
        )
        flash("Lapak ditambahkan.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect(f"/finance/trips/{trip_id}")


@finance_bp.route("/finance/trips/<int:trip_id>/sell", methods=["POST"])
def finance_trip_sell(trip_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        record_fin_trip_sell(
            trip_id,
            material_id=request.form.get("material_id"),
            qty_kg=request.form.get("qty_kg"),
            price_per_kg=request.form.get("price_per_kg"),
            party_id=request.form.get("party_id") or None,
            party_name=request.form.get("party_name"),
            payment_type=request.form.get("payment_type"),
            note=request.form.get("note"),
            created_by=session.get("user_id"),
        )
        return _trip_ajax_response(trip_id, True, "Penjualan dicatat.")
    except ValueError as e:
        return _trip_ajax_response(trip_id, False, str(e))


@finance_bp.route("/finance/trips/<int:trip_id>/buy", methods=["POST"])
def finance_trip_buy(trip_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        record_fin_trip_buy(
            trip_id,
            material_id=request.form.get("material_id"),
            qty_kg=request.form.get("qty_kg"),
            price_per_kg=request.form.get("price_per_kg"),
            note=request.form.get("note"),
        )
        return _trip_ajax_response(trip_id, True, "Pembelian dicatat.")
    except ValueError as e:
        return _trip_ajax_response(trip_id, False, str(e))


@finance_bp.route("/finance/trips/<int:trip_id>/expense", methods=["POST"])
def finance_trip_add_expense(trip_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        record_fin_trip_expense(
            trip_id,
            expense_name=request.form.get("expense_name"),
            subtotal=request.form.get("subtotal"),
        )
        return _trip_ajax_response(trip_id, True, "Beban perjalanan dicatat.")
    except ValueError as e:
        return _trip_ajax_response(trip_id, False, str(e))


@finance_bp.route("/finance/trips/<int:trip_id>/susut", methods=["POST"])
def finance_trip_add_susut(trip_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        record_fin_trip_susut(
            trip_id,
            material_id=request.form.get("material_id"),
            qty_kg=request.form.get("qty_kg"),
            note=request.form.get("note"),
            created_by=session.get("user_id"),
        )
        return _trip_ajax_response(trip_id, True, "Susut barang dicatat.")
    except ValueError as e:
        return _trip_ajax_response(trip_id, False, str(e))


@finance_bp.route("/finance/trips/<int:trip_id>/items/<int:item_id>/edit", methods=["POST"])
def finance_trip_item_edit(trip_id, item_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        edit_fin_trip_item(
            item_id,
            qty_kg=request.form.get("qty_kg"),
            price_per_kg=request.form.get("price_per_kg"),
            subtotal=request.form.get("subtotal"),
            expense_name=request.form.get("expense_name"),
            note=request.form.get("note"),
        )
        return _trip_ajax_response(trip_id, True, "Item berhasil diperbarui.")
    except ValueError as e:
        return _trip_ajax_response(trip_id, False, str(e))


@finance_bp.route("/finance/trips/<int:trip_id>/items/<int:item_id>/delete", methods=["POST"])
def finance_trip_item_delete(trip_id, item_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        delete_fin_trip_item(item_id)
        return _trip_ajax_response(trip_id, True, "Item berhasil dihapus.")
    except ValueError as e:
        return _trip_ajax_response(trip_id, False, str(e))


@finance_bp.route("/finance/trips/<int:trip_id>/close", methods=["POST"])
def finance_trip_close(trip_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        close_fin_trip_web(trip_id)
        flash("Perjalanan ditutup.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect(f"/finance/trips/{trip_id}")


@finance_bp.route("/finance/trips/<int:trip_id>/cancel", methods=["POST"])
def finance_trip_cancel(trip_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        cancel_fin_trip_web(trip_id)
        flash("Perjalanan dibatalkan.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect(f"/finance/trips/{trip_id}")


@finance_bp.route("/finance/trips/<int:trip_id>/delete", methods=["POST"])
def finance_trip_delete(trip_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        delete_fin_trip_web(trip_id)
        flash("Perjalanan dihapus.", "success")
    except ValueError as e:
        flash(str(e), "danger")
        return redirect(f"/finance/trips/{trip_id}")
    return redirect("/finance/trips")


# ---------- LAPORAN KEUANGAN OWNER (read-only, khusus role owner) ----------
@finance_bp.route("/owner/finance")
def owner_finance_report():
    deny = owner_required()
    if deny:
        return deny

    today = date.today()
    date_from = request.args.get("from") or today.replace(day=1).isoformat()
    date_to = request.args.get("to") or today.isoformat()

    report = get_owner_finance_report(date_from, date_to)
    return render_template(
        "owner_finance.html",
        report=report,
        notif_count=get_notif_count(),
        today_iso=today.isoformat(),
        month_start_iso=today.replace(day=1).isoformat(),
        year_start_iso=today.replace(month=1, day=1).isoformat(),
    )

from flask import Blueprint, render_template, request, redirect, session, flash

from core import (
    owner_or_admin_required, get_notif_count,
    list_fin_materials, add_fin_material, edit_fin_material, delete_fin_material,
    add_fin_material_stock, reduce_fin_material_stock,
    list_fin_debts, pay_fin_debt, create_fin_debt_entry, edit_fin_debt, delete_fin_debt,
    list_fin_categories, list_fin_activity_log,
    create_fin_expense_entry, list_fin_expenses, list_fin_expense_categories,
    edit_fin_expense_entry, delete_fin_expense_entry,
    create_fin_trip_web, list_fin_trips_web, get_fin_trip_web_detail,
    add_fin_trip_party, record_fin_trip_sell, record_fin_trip_buy,
    record_fin_trip_expense, close_fin_trip_web, cancel_fin_trip_web,
    delete_fin_trip_web, get_materials_with_stock,
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

    materials, total_value = list_fin_materials()
    debts = list_fin_debts()
    categories = list_fin_categories()
    activity_log = list_fin_activity_log()
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
        expenses=expenses,
        expense_categories=expense_categories,
        expense_total=expense_total,
        notif_count=get_notif_count(),
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
        flash("Penjualan dicatat.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect(f"/finance/trips/{trip_id}")


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
        flash("Pembelian dicatat.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect(f"/finance/trips/{trip_id}")


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
        flash("Beban perjalanan dicatat.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect(f"/finance/trips/{trip_id}")


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

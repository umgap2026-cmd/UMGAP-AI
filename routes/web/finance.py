from flask import Blueprint, render_template, request, redirect, session, flash

from core import (
    owner_or_admin_required,
    list_fin_materials, add_fin_material, edit_fin_material, delete_fin_material,
    list_fin_debts, pay_fin_debt,
)

finance_bp = Blueprint("finance", __name__)


@finance_bp.route("/finance")
def finance_dashboard():
    """Satu halaman Finance: ringkasan, barang gudang/stok, dan hutang-piutang."""
    deny = owner_or_admin_required()
    if deny:
        return deny

    materials, total_value = list_fin_materials()
    debts = list_fin_debts()

    return render_template(
        "finance_dashboard.html",
        materials=materials,
        total_value=total_value,
        debts=debts,
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
        edit_fin_material(material_id, request.form.get("name"), request.form.get("unit"))
        flash("Barang berhasil diperbarui.", "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


@finance_bp.route("/finance/materials/<int:material_id>/delete", methods=["POST"])
def finance_materials_delete(material_id):
    deny = owner_or_admin_required()
    if deny:
        return deny

    try:
        mat_name = delete_fin_material(material_id)
        flash(f'Barang "{mat_name}" dinonaktifkan.', "success")
    except ValueError as e:
        flash(str(e), "danger")
    return redirect("/finance")


# ---------- HUTANG (ke pemasok) & PIUTANG ----------
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

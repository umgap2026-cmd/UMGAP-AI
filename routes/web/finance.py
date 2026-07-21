from flask import Blueprint, render_template, request, redirect, session, flash
import json

from core import (
    owner_or_admin_required,
    list_fin_materials, add_fin_material, edit_fin_material, delete_fin_material,
    create_fin_purchase,
    list_fin_debts, pay_fin_debt,
)

finance_bp = Blueprint("finance", __name__)


@finance_bp.route("/finance")
def finance_dashboard():
    deny = owner_or_admin_required()
    if deny:
        return deny

    materials, total_value = list_fin_materials()
    debts = list_fin_debts()

    return render_template(
        "finance_dashboard.html",
        material_count=len(materials),
        total_value=total_value,
        debts=debts,
    )


# ---------- BARANG GUDANG (fin_materials) ----------
@finance_bp.route("/finance/materials", methods=["GET", "POST"])
def finance_materials():
    deny = owner_or_admin_required()
    if deny:
        return deny

    if request.method == "POST":
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
        return redirect("/finance/materials")

    materials, total_value = list_fin_materials()
    return render_template(
        "finance_materials.html", materials=materials, total_value=total_value
    )


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
    return redirect("/finance/materials")


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
    return redirect("/finance/materials")


# ---------- KASIR BELI (dari pemasok/orang, hutang & DP) ----------
@finance_bp.route("/finance/buy", methods=["GET", "POST"])
def finance_buy():
    deny = owner_or_admin_required()
    if deny:
        return deny

    if request.method == "POST":
        try:
            items = json.loads(request.form.get("items_json") or "[]")
        except Exception:
            items = []

        is_debt = str(request.form.get("is_debt") or "").strip() in (
            "1", "true", "True", "on", "yes",
        )

        try:
            create_fin_purchase(
                party_name=request.form.get("party_name"),
                is_debt=is_debt,
                note=request.form.get("note"),
                discount=request.form.get("discount") or 0,
                items=items,
                created_by=session.get("user_id"),
            )
            flash("Transaksi beli berhasil dicatat.", "success")
            return redirect("/finance/debts" if is_debt else "/finance/materials")
        except ValueError as e:
            flash(str(e), "danger")
            return redirect("/finance/buy")

    materials, _ = list_fin_materials()
    return render_template("finance_buy.html", materials=materials)


# ---------- HUTANG (ke pemasok) & PIUTANG ----------
@finance_bp.route("/finance/debts")
def finance_debts():
    deny = owner_or_admin_required()
    if deny:
        return deny

    return render_template("finance_debts.html", debts=list_fin_debts())


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
    return redirect("/finance/debts")

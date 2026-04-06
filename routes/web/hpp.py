import os
import json
from flask import Blueprint, render_template, request, redirect, jsonify
from openai import OpenAI

from core import is_logged_in, is_admin

hpp_bp = Blueprint("hpp", __name__)

OPENAI_API_KEY = (os.getenv("OPENAI_API_KEY") or "").strip()
oa_client = OpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None


def _parse_materials(materials_raw):
    if isinstance(materials_raw, str):
        try:
            materials_raw = json.loads(materials_raw)
        except Exception:
            materials_raw = []

    if not isinstance(materials_raw, list):
        materials_raw = []

    rows = []
    total = 0

    for m in materials_raw:
        name = str(m.get("name") or "").strip()
        unit = str(m.get("unit") or "").strip()
        cost = int(m.get("cost") or 0)

        if cost < 0:
            cost = 0

        total += cost
        rows.append({
            "name": name,
            "unit": unit,
            "cost": cost,
        })

    return rows, total


def _hpp_calculate(product_name, materials_raw, labor_cost_raw, overhead_cost_raw, output_qty_raw):
    labor_cost = max(0, int(labor_cost_raw or 0))
    overhead_cost = max(0, int(overhead_cost_raw or 0))
    output_qty = max(1, int(output_qty_raw or 1))

    material_rows, total_material_cost = _parse_materials(materials_raw)

    total_cost = total_material_cost + labor_cost + overhead_cost
    hpp_per_unit = round(total_cost / output_qty)

    return {
        "product_name": product_name,
        "materials": material_rows,
        "total_material_cost": total_material_cost,
        "labor_cost": labor_cost,
        "overhead_cost": overhead_cost,
        "output_qty": output_qty,
        "total_cost": total_cost,
        "hpp_per_unit": hpp_per_unit,
    }


def _hpp_ai_prompt(data):
    mat_lines = "\n".join(
        f"- {m.get('name','-')} ({m.get('unit','-')}): Rp {int(m.get('cost', 0)):,}".replace(",", ".")
        for m in (data.get("materials") or [])
    ) or "- Tidak ada bahan baku"

    return f"""
Data HPP yang disubmit user:
Produk: "{data['product_name']}"
Bahan baku:
{mat_lines}
Biaya tenaga kerja (per batch): Rp {int(data['labor_cost']):,}
Biaya overhead (per batch): Rp {int(data['overhead_cost']):,}
Jumlah produk jadi: {int(data['output_qty'])} unit
Total biaya produksi: Rp {int(data['total_cost']):,}
HPP per unit: Rp {int(data['hpp_per_unit']):,}

Tugasmu:
1. Analisis kelengkapan dan keakuratan input.
2. Sebutkan biaya yang mungkin terlewat (contoh: kemasan, ongkir bahan, penyusutan alat, biaya air/listrik, gas, minyak, bumbu tambahan, dsb.).
3. Evaluasi apakah HPP per unit terlihat realistis untuk jenis produk tersebut.
4. Berikan saran harga jual yang optimal beserta alasannya.
5. Jika ada potensi efisiensi biaya, sebutkan.

Format jawaban WAJIB:
- Analisis: [2-3 kalimat evaluasi keseluruhan]
- Yang kurang spesifik:
  - ...
- Biaya yang mungkin terlewat:
  - ...
- Saran:
  - ...

Jawab dalam Bahasa Indonesia yang ramah dan mudah dipahami pelaku UMKM. Maksimal 350 kata.
""".strip()


@hpp_bp.route("/hpp-ai", methods=["GET", "POST"])
def hpp_ai_page():
    if not is_logged_in():
        return redirect("/login")

    if not is_admin():
        return redirect("/dashboard")

    result = None
    ai_notes = None
    form_data = {
        "product_name": "",
        "labor_cost": "",
        "overhead_cost": "",
        "output_qty": "1",
        "materials_json": "[]",
    }

    if request.method == "POST":
        product_name = (request.form.get("product_name") or "").strip()
        labor_cost_raw = (request.form.get("labor_cost") or "0").strip()
        overhead_raw = (request.form.get("overhead_cost") or "0").strip()
        qty_raw = (request.form.get("output_qty") or "1").strip()
        mats_json = (request.form.get("materials_json") or "[]").strip()

        form_data = {
            "product_name": product_name,
            "labor_cost": labor_cost_raw,
            "overhead_cost": overhead_raw,
            "output_qty": qty_raw,
            "materials_json": mats_json,
        }

        if not product_name:
            return render_template(
                "hpp_ai.html",
                result=None,
                ai_notes=None,
                form_data=form_data,
                error="Nama produk wajib diisi."
            )

        result = _hpp_calculate(
            product_name,
            mats_json,
            labor_cost_raw,
            overhead_raw,
            qty_raw,
        )

        if oa_client:
            try:
                prompt = _hpp_ai_prompt(result)
                resp = oa_client.chat.completions.create(
                    model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
                    messages=[{"role": "user", "content": prompt}],
                    temperature=0.35,
                    max_tokens=500,
                )
                ai_notes = (resp.choices[0].message.content or "").strip()
            except Exception as ex:
                ai_notes = f"AI tidak tersedia saat ini ({type(ex).__name__}). Hasil HPP tetap valid."

    return render_template(
        "hpp_ai.html",
        result=result,
        ai_notes=ai_notes,
        form_data=form_data,
    )


@hpp_bp.route("/api/hpp-calculate", methods=["POST"])
def api_hpp_calculate():
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Silakan login dulu."}), 401

    if not is_admin():
        return jsonify({"ok": False, "error": "forbidden"}), 403

    data = request.get_json(silent=True) or {}

    try:
        result = _hpp_calculate(
            product_name=(data.get("product_name") or "").strip(),
            materials_raw=data.get("materials") or [],
            labor_cost_raw=data.get("labor_cost") or 0,
            overhead_cost_raw=data.get("overhead_cost") or 0,
            output_qty_raw=data.get("output_qty") or 1,
        )
        return jsonify({"ok": True, "result": result})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@hpp_bp.route("/api/hpp-ai-review", methods=["POST"])
def api_hpp_ai_review():
    if not is_logged_in():
        return jsonify({"ok": False, "error": "Silakan login dulu."}), 401

    if not is_admin():
        return jsonify({"ok": False, "error": "forbidden"}), 403

    data = request.get_json(silent=True) or {}

    if not oa_client:
        return jsonify({"ok": False, "error": "OPENAI_API_KEY belum diatur di .env"}), 503

    try:
        result = _hpp_calculate(
            product_name=(data.get("product_name") or "").strip(),
            materials_raw=data.get("materials") or [],
            labor_cost_raw=data.get("labor_cost") or 0,
            overhead_cost_raw=data.get("overhead_cost") or 0,
            output_qty_raw=data.get("output_qty") or 1,
        )

        prompt = _hpp_ai_prompt(result)
        resp = oa_client.chat.completions.create(
            model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"),
            messages=[{"role": "user", "content": prompt}],
            temperature=0.35,
            max_tokens=500,
        )
        review = (resp.choices[0].message.content or "").strip()

        return jsonify({
            "ok": True,
            "review": review,
            "result": result,
        })
    except Exception as e:
        return jsonify({"ok": False, "error": f"{type(e).__name__}: {str(e)}"}), 500
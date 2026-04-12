import os
import json
from flask import Blueprint, request
from openai import OpenAI

from core import mobile_api_response
from .middleware import mobile_required

mobile_hpp_bp = Blueprint("mobile_hpp", __name__)

OPENAI_API_KEY = (os.getenv("OPENAI_API_KEY") or "").strip()
OPENAI_MODEL = (os.getenv("OPENAI_MODEL") or "gpt-4o-mini").strip()
oa_client = OpenAI(api_key=OPENAI_API_KEY) if OPENAI_API_KEY else None


def _safe_int(value, default=0):
    try:
        if value is None:
            return default
        return int(float(str(value).strip() or default))
    except Exception:
        return default



def _is_admin_mobile():
    user = getattr(request, "mobile_user", None) or {}
    return str(user.get("role") or "").strip().lower() == "admin"



def _require_admin_mobile():
    if not _is_admin_mobile():
        return mobile_api_response(
            ok=False,
            message="Akses ditolak. Hanya admin.",
            status_code=403,
        )
    return None



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

    for raw in materials_raw:
        item = raw if isinstance(raw, dict) else {}
        name = str(item.get("name") or "").strip()
        unit = str(item.get("unit") or "").strip()
        qty = max(0, _safe_int(item.get("qty"), 0))
        price = max(0, _safe_int(item.get("price"), 0))
        cost = item.get("cost")

        if cost is None:
            cost = qty * price
        cost = max(0, _safe_int(cost, 0))

        total += cost
        rows.append(
            {
                "name": name,
                "unit": unit,
                "qty": qty,
                "price": price,
                "cost": cost,
            }
        )

    return rows, total



def _hpp_calculate(
    product_name,
    materials_raw,
    labor_cost_raw,
    overhead_cost_raw,
    output_qty_raw,
    packaging_cost_raw=0,
    misc_cost_raw=0,
    target_margin_pct_raw=30,
):
    product_name = str(product_name or "").strip()
    if not product_name:
        raise ValueError("Nama produk wajib diisi.")

    labor_cost = max(0, _safe_int(labor_cost_raw, 0))
    overhead_cost = max(0, _safe_int(overhead_cost_raw, 0))
    packaging_cost = max(0, _safe_int(packaging_cost_raw, 0))
    misc_cost = max(0, _safe_int(misc_cost_raw, 0))
    output_qty = max(1, _safe_int(output_qty_raw, 1))
    target_margin_pct = max(0, _safe_int(target_margin_pct_raw, 30))

    material_rows, total_material_cost = _parse_materials(materials_raw)

    total_cost = total_material_cost + labor_cost + overhead_cost + packaging_cost + misc_cost
    hpp_per_unit = round(total_cost / output_qty)
    recommended_price = round(hpp_per_unit * (1 + (target_margin_pct / 100)))
    estimated_profit_per_unit = max(0, recommended_price - hpp_per_unit)
    estimated_profit_batch = estimated_profit_per_unit * output_qty

    return {
        "product_name": product_name,
        "materials": material_rows,
        "total_material_cost": total_material_cost,
        "labor_cost": labor_cost,
        "overhead_cost": overhead_cost,
        "packaging_cost": packaging_cost,
        "misc_cost": misc_cost,
        "output_qty": output_qty,
        "total_cost": total_cost,
        "hpp_per_unit": hpp_per_unit,
        "target_margin_pct": target_margin_pct,
        "recommended_price": recommended_price,
        "estimated_profit_per_unit": estimated_profit_per_unit,
        "estimated_profit_batch": estimated_profit_batch,
    }



def _hpp_ai_prompt(data):
    mat_lines = "\n".join(
        (
            f"- {m.get('name', '-') or '-'}"
            f" | qty: {int(m.get('qty', 0) or 0)}"
            f" | unit: {m.get('unit', '-') or '-'}"
            f" | harga: Rp {int(m.get('price', 0) or 0):,}".replace(",", ".")
            + f" | subtotal: Rp {int(m.get('cost', 0) or 0):,}".replace(",", ".")
        )
        for m in (data.get("materials") or [])
    ) or "- Tidak ada bahan baku"

    return f"""
Data HPP yang disubmit user:
Produk: "{data['product_name']}"
Bahan baku:
{mat_lines}
Biaya tenaga kerja (per batch): Rp {int(data['labor_cost']):,}
Biaya overhead (per batch): Rp {int(data['overhead_cost']):,}
Biaya kemasan (per batch): Rp {int(data['packaging_cost']):,}
Biaya lain-lain (per batch): Rp {int(data['misc_cost']):,}
Jumlah produk jadi: {int(data['output_qty'])} unit
Total biaya bahan baku: Rp {int(data['total_material_cost']):,}
Total biaya produksi: Rp {int(data['total_cost']):,}
HPP per unit: Rp {int(data['hpp_per_unit']):,}
Target margin: {int(data['target_margin_pct'])}%
Rekomendasi harga jual saat ini: Rp {int(data['recommended_price']):,}

Tugasmu:
1. Analisis kelengkapan dan keakuratan input HPP.
2. Sebutkan biaya yang mungkin masih terlewat.
3. Nilai apakah HPP per unit terlihat realistis.
4. Berikan saran harga jual yang optimal dan alasan singkat.
5. Berikan saran efisiensi biaya yang aman.
6. Tulis insight yang praktis untuk admin/owner UMKM.

Format jawaban WAJIB JSON valid tanpa markdown:
{{
  "analysis": "...",
  "missing_items": ["..."],
  "possible_overlooked_costs": ["..."],
  "pricing_suggestions": ["..."],
  "efficiency_tips": ["..."],
  "risks": ["..."]
}}

Gunakan Bahasa Indonesia yang ramah, singkat, jelas, dan praktis.
""".strip()



def _fallback_review(result):
    missing_items = []
    overlooked = []
    pricing = []
    efficiency = []
    risks = []

    if not result.get("materials"):
        missing_items.append("Daftar bahan baku masih kosong, sehingga HPP belum mencerminkan biaya produksi riil.")

    if result.get("packaging_cost", 0) <= 0:
        overlooked.append("Biaya kemasan belum dimasukkan. Untuk produk jualan, ini sering memengaruhi margin.")
    if result.get("overhead_cost", 0) <= 0:
        overlooked.append("Biaya overhead seperti listrik, gas, air, dan penyusutan alat belum terlihat.")
    if result.get("misc_cost", 0) <= 0:
        overlooked.append("Biaya lain-lain seperti transport bahan, bumbu tambahan, atau kehilangan produksi bisa dipertimbangkan.")

    pricing.append(
        f"Dengan target margin {result['target_margin_pct']}%, harga jual awal bisa diuji di sekitar Rp {result['recommended_price']:,}.".replace(",", ".")
    )
    pricing.append(
        "Bandingkan dengan harga pasar lokal agar margin tetap sehat tanpa membuat produk sulit bersaing."
    )

    efficiency.append("Cek bahan baku dengan porsi biaya terbesar, lalu cari supplier atau ukuran pembelian yang lebih efisien.")
    efficiency.append("Pisahkan biaya batch dan biaya per unit agar penyesuaian harga lebih cepat saat volume berubah.")

    if result["output_qty"] <= 1:
        risks.append("Output per batch sangat kecil. Sedikit perubahan biaya bisa membuat HPP per unit melonjak.")
    if result["hpp_per_unit"] >= result["recommended_price"]:
        risks.append("Margin sangat tipis atau nol. Harga jual perlu ditinjau ulang.")

    analysis = (
        "Perhitungan HPP dasar sudah terbentuk dan bisa dipakai sebagai titik awal evaluasi. "
        "Namun, akurasi akhir tetap sangat bergantung pada kelengkapan komponen biaya seperti kemasan, overhead, dan biaya tak langsung lainnya."
    )

    return {
        "analysis": analysis,
        "missing_items": missing_items,
        "possible_overlooked_costs": overlooked,
        "pricing_suggestions": pricing,
        "efficiency_tips": efficiency,
        "risks": risks,
    }



def _normalize_ai_payload(text, result):
    raw = (text or "").strip()
    if not raw:
        return _fallback_review(result)

    try:
        return json.loads(raw)
    except Exception:
        pass

    start = raw.find("{")
    end = raw.rfind("}")
    if start != -1 and end != -1 and end > start:
        try:
            return json.loads(raw[start : end + 1])
        except Exception:
            pass

    fallback = _fallback_review(result)
    fallback["analysis"] = raw[:1200]
    return fallback


@mobile_hpp_bp.route("/hpp-calculate", methods=["POST"])
@mobile_required
def hpp_calculate_mobile():
    forbidden = _require_admin_mobile()
    if forbidden:
        return forbidden

    data = request.get_json(silent=True) or {}

    try:
        result = _hpp_calculate(
            product_name=(data.get("product_name") or "").strip(),
            materials_raw=data.get("materials") or [],
            labor_cost_raw=data.get("labor_cost") or 0,
            overhead_cost_raw=data.get("overhead_cost") or 0,
            output_qty_raw=data.get("output_qty") or 1,
            packaging_cost_raw=data.get("packaging_cost") or 0,
            misc_cost_raw=data.get("misc_cost") or 0,
            target_margin_pct_raw=data.get("target_margin_pct") or 30,
        )
        return mobile_api_response(
            ok=True,
            message="Perhitungan HPP berhasil.",
            data={"result": result},
        )
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)
    except Exception as e:
        return mobile_api_response(ok=False, message=f"Gagal menghitung HPP: {e}", status_code=500)


@mobile_hpp_bp.route("/hpp-ai-review", methods=["POST"])
@mobile_required
def hpp_ai_review_mobile():
    forbidden = _require_admin_mobile()
    if forbidden:
        return forbidden

    data = request.get_json(silent=True) or {}

    try:
        result = _hpp_calculate(
            product_name=(data.get("product_name") or "").strip(),
            materials_raw=data.get("materials") or [],
            labor_cost_raw=data.get("labor_cost") or 0,
            overhead_cost_raw=data.get("overhead_cost") or 0,
            output_qty_raw=data.get("output_qty") or 1,
            packaging_cost_raw=data.get("packaging_cost") or 0,
            misc_cost_raw=data.get("misc_cost") or 0,
            target_margin_pct_raw=data.get("target_margin_pct") or 30,
        )
    except ValueError as e:
        return mobile_api_response(ok=False, message=str(e), status_code=400)
    except Exception as e:
        return mobile_api_response(ok=False, message=f"Gagal menghitung HPP: {e}", status_code=500)

    if not oa_client:
        return mobile_api_response(
            ok=True,
            message="OPENAI_API_KEY belum diatur. Menampilkan insight lokal.",
            data={
                "result": result,
                "review": _fallback_review(result),
                "source": "fallback",
            },
        )

    try:
        prompt = _hpp_ai_prompt(result)
        resp = oa_client.chat.completions.create(
            model=OPENAI_MODEL,
            messages=[
                {
                    "role": "system",
                    "content": "Kamu adalah analis HPP UMKM yang teliti, praktis, dan hemat kata.",
                },
                {"role": "user", "content": prompt},
            ],
            temperature=0.35,
            max_tokens=700,
        )
        content = ((resp.choices or [None])[0].message.content if resp.choices else "") or ""
        review = _normalize_ai_payload(content, result)
        return mobile_api_response(
            ok=True,
            message="Analisis HPP AI berhasil.",
            data={
                "result": result,
                "review": review,
                "source": "openai",
                "model": OPENAI_MODEL,
            },
        )
    except Exception as e:
        return mobile_api_response(
            ok=True,
            message=f"AI sedang tidak tersedia ({type(e).__name__}). Menampilkan insight lokal.",
            data={
                "result": result,
                "review": _fallback_review(result),
                "source": "fallback",
            },
        )


@mobile_hpp_bp.route("/hpp-ai", methods=["POST"])
@mobile_required
def hpp_ai_mobile_compat():
    """
    Compatibility endpoint untuk frontend lama.
    Tetap menerima request lama, tapi diarahkan ke alur review AI baru.
    """
    return hpp_ai_review_mobile()

from datetime import date

from flask import Blueprint, render_template, jsonify

from core import (
    owner_required, get_notif_count,
    get_owner_health_insight, get_owner_ai_review,
    get_owner_finance_report,
)

owner_bp = Blueprint("owner", __name__)


@owner_bp.route("/owner/dashboard")
def owner_dashboard():
    """Halaman utama Owner: ringkasan kesehatan perusahaan (keuangan +
    absensi hari ini) + akses ke Laporan Keuangan & Kelola Data. Murni
    read-only -- tidak ada tombol edit/hapus apa pun di halaman ini."""
    deny = owner_required()
    if deny:
        return deny

    try:
        insight = get_owner_health_insight()
    except Exception:
        insight = None

    today = date.today()
    try:
        laba_bersih_bulan_ini = get_owner_finance_report(
            today.replace(day=1).isoformat(), today.isoformat()
        )["laba_bersih"]
    except Exception:
        laba_bersih_bulan_ini = None

    return render_template(
        "owner_dashboard.html",
        insight=insight,
        notif_count=get_notif_count(),
        today_iso=today.isoformat(),
        laba_bersih_bulan_ini=laba_bersih_bulan_ini,
    )


@owner_bp.route("/owner/dashboard/ai-review", methods=["POST"])
def owner_dashboard_ai_review():
    """AJAX: minta analisa/saran AI berdasarkan data kesehatan perusahaan
    terkini. Dipanggil manual lewat tombol (bukan auto-load) krn perlu
    beberapa detik & memanggil OpenAI API."""
    deny = owner_required()
    if deny:
        return jsonify({"ok": False, "message": "Unauthorized"}), 403

    try:
        insight = get_owner_health_insight()
        analysis = get_owner_ai_review(insight)
        return jsonify({"ok": True, "analysis": analysis})
    except ValueError as e:
        return jsonify({"ok": False, "message": str(e)})
    except Exception as e:
        return jsonify({"ok": False, "message": f"Gagal memuat analisa AI: {e}"})

from flask import Blueprint, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import mobile_api_login_required, mobile_api_response

mobile_buy_prices_bp = Blueprint("mobile_buy_prices", __name__)


# =========================
# HELPERS
# =========================

def ensure_buy_prices_schema():
    conn = get_conn()
    cur = conn.cursor()
    try:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS buy_prices (
                id SERIAL PRIMARY KEY,
                material VARCHAR(100) NOT NULL,
                grade VARCHAR(150) NOT NULL DEFAULT '',
                unit VARCHAR(20) NOT NULL DEFAULT 'kg',
                price NUMERIC(10,2) NOT NULL DEFAULT 0,
                note TEXT,
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                sort_order INTEGER NOT NULL DEFAULT 0,
                updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()
        conn.close()


def _admin_or_owner():
    user = getattr(request, "mobile_user", None) or {}
    role = str(user.get("role") or "").lower()

    if role not in ("admin", "owner"):
        return mobile_api_response(
            ok=False,
            message="Akses ditolak. Hanya admin/owner.",
            status_code=403
        )
    return None


def _row_payload(r):
    return {
        "id": int(r["id"]),
        "material": r["material"],
        "grade": r["grade"],
        "unit": r["unit"],
        "price": float(r["price"]),
        "note": r["note"] or "",
        "is_active": bool(r["is_active"]),
        "updated_at": r["updated_at"].strftime("%d/%m/%Y %H:%M") if r["updated_at"] else "-"
    }


# =========================
# GET LIST
# =========================

@mobile_buy_prices_bp.route("/buy-prices", methods=["GET"])
@mobile_api_login_required
def mobile_buy_prices_list():
    deny = _admin_only()
    if deny:
        return deny

    ensure_buy_prices_schema()

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        cur.execute("""
            SELECT id, material, grade, unit, price, note, is_active, updated_at
            FROM buy_prices
            ORDER BY sort_order ASC, id ASC;
        """)
        rows = [_row_payload(r) for r in cur.fetchall()]

        return mobile_api_response(
            ok=True,
            message="Data harga berhasil dimuat",
            data={"rows": rows}
        )
    finally:
        cur.close()
        conn.close()


# =========================
# ADD
# =========================

@mobile_buy_prices_bp.route("/buy-prices", methods=["POST"])
@mobile_api_login_required
def mobile_buy_prices_add():
    deny = _admin_only()
    if deny:
        return deny

    ensure_buy_prices_schema()

    data = request.get_json() or {}

    material = (data.get("material") or "").strip()
    grade = (data.get("grade") or "").strip()
    unit = (data.get("unit") or "kg").strip()
    note = (data.get("note") or "").strip()
    price = max(0.0, float(data.get("price") or 0))
    is_active = bool(data.get("is_active", True))

    if not material:
        return mobile_api_response(False, "Material wajib diisi", status_code=400)

    if not grade:
        return mobile_api_response(False, "Grade wajib diisi", status_code=400)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        cur.execute("""
            INSERT INTO buy_prices (material, grade, unit, price, note, is_active, sort_order)
            VALUES (%s,%s,%s,%s,%s,%s,(SELECT COALESCE(MAX(sort_order),0)+1 FROM buy_prices))
            RETURNING *;
        """, (material, grade, unit, price, note, is_active))

        row = cur.fetchone()
        conn.commit()

        return mobile_api_response(
            ok=True,
            message="Berhasil ditambahkan",
            data={"row": _row_payload(row)}
        )

    except Exception as e:
        conn.rollback()
        return mobile_api_response(False, str(e), status_code=500)

    finally:
        cur.close()
        conn.close()


# =========================
# UPDATE
# =========================

@mobile_buy_prices_bp.route("/buy-prices/<int:pid>", methods=["PUT"])
@mobile_api_login_required
def mobile_buy_prices_update(pid):
    deny = _admin_only()
    if deny:
        return deny

    data = request.get_json() or {}

    material = (data.get("material") or "").strip()
    grade = (data.get("grade") or "").strip()
    unit = (data.get("unit") or "kg").strip()
    price = max(0.0, float(data.get("price") or 0))
    note = (data.get("note") or "").strip()
    is_active = bool(data.get("is_active", True))

    if not material:
        return mobile_api_response(False, "Material wajib diisi", status_code=400)

    if not grade:
        return mobile_api_response(False, "Grade wajib diisi", status_code=400)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        cur.execute("""
            UPDATE buy_prices
            SET material=%s,
                grade=%s,
                unit=%s,
                price=%s,
                note=%s,
                is_active=%s,
                updated_at=CURRENT_TIMESTAMP
            WHERE id=%s
            RETURNING *;
        """, (material, grade, unit, price, note, is_active, pid))

        row = cur.fetchone()
        conn.commit()

        if not row:
            return mobile_api_response(False, "Data tidak ditemukan", 404)

        return mobile_api_response(
            ok=True,
            message="Berhasil diupdate",
            data={"row": _row_payload(row)}
        )

    except Exception as e:
        conn.rollback()
        return mobile_api_response(False, str(e), 500)

    finally:
        cur.close()
        conn.close()


# =========================
# DELETE
# =========================

@mobile_buy_prices_bp.route("/buy-prices/<int:pid>", methods=["DELETE"])
@mobile_api_login_required
def mobile_buy_prices_delete(pid):
    deny = _admin_only()
    if deny:
        return deny

    conn = get_conn()
    cur = conn.cursor()

    try:
        cur.execute("DELETE FROM buy_prices WHERE id=%s", (pid,))
        conn.commit()

        return mobile_api_response(True, "Berhasil dihapus")

    except Exception as e:
        conn.rollback()
        return mobile_api_response(False, str(e), 500)

    finally:
        cur.close()
        conn.close()

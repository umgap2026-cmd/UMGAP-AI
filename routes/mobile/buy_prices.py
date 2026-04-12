from flask import Blueprint, jsonify, Response, render_template, request
from psycopg2.extras import RealDictCursor

from db import get_conn
from core import admin_required, mobile_api_login_required, mobile_api_response

buy_prices_bp = Blueprint("buy_prices", __name__)


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

        for col_sql in [
            "ALTER TABLE buy_prices ADD COLUMN IF NOT EXISTS note TEXT;",
            "ALTER TABLE buy_prices ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;",
            "ALTER TABLE buy_prices ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0;",
            "ALTER TABLE buy_prices ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;",
            "ALTER TABLE buy_prices ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP;",
        ]:
            try:
                cur.execute(col_sql)
            except Exception:
                conn.rollback()

        cur.execute("SELECT COUNT(*) AS n FROM buy_prices;")
        if cur.fetchone()[0] == 0:
            defaults = [
                ("Tembaga", "TM", "kg", 205, 10),
                ("Tembaga", "TS / TS Halus", "kg", 202, 11),
                ("Tembaga", "BC", "kg", 198.5, 12),
                ("Tembaga", "Telkom / TB Pipa", "kg", 197.5, 13),
                ("Tembaga", "TB / TB Bakar", "kg", 189, 14),
                ("Tembaga", "TB Putih Lidi", "kg", 189, 15),
                ("Tembaga", "TB Putih", "kg", 184, 16),
                ("Tembaga", "DD", "kg", 182, 17),
                ("Tembaga", "Gram TB", "kg", 150, 18),
                ("Tembaga", "Gram TB Lembut", "kg", 140, 19),
                ("Tembaga", "Jarum TB Putih", "kg", 147.5, 20),
                ("Tembaga", "Jarum TB Hitam", "kg", 150.5, 21),
                ("Tembaga", "RD TB", "kg", 165, 22),
                ("Tembaga", "TB Kotak", "kg", 122, 23),
                ("Tembaga", "TB Bakau Super", "kg", 90, 24),
                ("Kuningan", "Bron", "kg", 169, 30),
                ("Kuningan", "Bron Putih", "kg", 164, 31),
                ("Kuningan", "Plat KN", "kg", 125, 32),
                ("Kuningan", "Patrum Bersih", "kg", 128, 33),
                ("Kuningan", "KN Kasar", "kg", 122, 34),
                ("Kuningan", "KN Rosok / KN Puler", "kg", 119, 35),
                ("Kuningan", "KN Kipas", "kg", 121, 36),
                ("Kuningan", "KN Rambut", "kg", 120, 37),
                ("Kuningan", "KN Gelang", "kg", 107, 38),
                ("Kuningan", "AISI", "kg", 123, 39),
                ("Kuningan", "AISI Kawul", "kg", 120, 40),
                ("Kuningan", "RD KN", "kg", 115, 41),
                ("Kuningan", "RD KN Lepas", "kg", 110, 42),
                ("Kuningan", "KN Totok", "kg", 115, 43),
                ("Kuningan", "KN Paten", "kg", 103, 44),
                ("Kuningan", "KN Tanjek", "kg", 103, 45),
                ("Kuningan", "Gram ME", "kg", 118, 46),
                ("Kuningan", "Gram Merah Lembut", "kg", 113, 47),
                ("Kuningan", "Gram KN As", "kg", 106, 48),
                ("Kuningan", "Gram Kemprotok", "kg", 108, 49),
                ("Kuningan", "Gram KN Kawul", "kg", 103, 50),
                ("Kuningan", "Gram Juwana", "kg", 100, 51),
                ("Kuningan", "Awon KN", "kg", 77, 52),
                ("Aluminium", "AK", "kg", 50, 60),
                ("Aluminium", "AK Bakar", "kg", 49, 61),
                ("Aluminium", "Kusen", "kg", 47.5, 62),
                ("Aluminium", "Siku", "kg", 43, 63),
                ("Aluminium", "Siku Cat", "kg", 42, 64),
                ("Aluminium", "Plat Koran", "kg", 48, 65),
                ("Aluminium", "Plat KPU", "kg", 43.5, 66),
                ("Aluminium", "Plat A", "kg", 42.5, 67),
                ("Aluminium", "Pelek Mobil", "kg", 44, 68),
                ("Aluminium", "Pelek Mobil Krom", "kg", 43.5, 69),
                ("Aluminium", "Seker", "kg", 40, 70),
                ("Aluminium", "Blok", "kg", 39.5, 71),
                ("Aluminium", "Blok 2", "kg", 36, 72),
                ("Aluminium", "Blok Parabola", "kg", 32.5, 73),
                ("Aluminium", "Kampas B", "kg", 35.5, 74),
                ("Aluminium", "Kampas K", "kg", 27.5, 75),
                ("Aluminium", "Plat B", "kg", 38, 76),
                ("Aluminium", "Plat Nomor", "kg", 39.5, 77),
                ("Aluminium", "Plat Lembutan", "kg", 31, 78),
                ("Aluminium", "Plat Jeruk", "kg", 34.5, 79),
                ("Aluminium", "Parfum B", "kg", 39.5, 80),
                ("Aluminium", "Parfum Kotor", "kg", 18.5, 81),
                ("Aluminium", "Nium Dinamo", "kg", 31.5, 82),
                ("Aluminium", "RD N Utuh", "kg", 34, 83),
                ("Aluminium", "RD N Lepas", "kg", 31, 84),
                ("Aluminium", "Panci LPK", "kg", 37.5, 85),
                ("Aluminium", "PC", "kg", 37, 86),
                ("Aluminium", "PC Silitan Bersih", "kg", 33, 87),
                ("Aluminium", "Kaleng", "kg", 36, 88),
                ("Aluminium", "Wajan", "kg", 31, 89),
                ("Aluminium", "Elemen", "kg", 25.5, 90),
                ("Aluminium", "Kerey", "kg", 24, 91),
                ("Aluminium", "Gram Nium", "kg", 19.5, 92),
                ("Aluminium", "Gram Nium Kemprotok", "kg", 21, 93),
                ("Aluminium", "Lelehan Nium", "kg", 16, 94),
                ("Aluminium", "Ring", "kg", 21.5, 95),
                ("Aluminium", "Tutup", "kg", 15, 96),
                ("Aluminium", "Nium Api", "kg", 15, 97),
                ("Aluminium", "Foil", "kg", 11, 98),
                ("Stainless", "Monel", "kg", 15.5, 110),
                ("Stainless", "Monel Cat", "kg", 15, 111),
                ("Stainless", "India", "kg", 6, 112),
                ("Timah & Aki", "Timah KPL", "kg", 29, 120),
                ("Timah & Aki", "Nium KPL", "kg", 25, 121),
                ("Timah & Aki", "Budeng", "kg", 30, 122),
                ("Timah & Aki", "Lakson", "kg", 32, 123),
                ("Timah & Aki", "Lakson RBS", "kg", 15.5, 124),
                ("Timah & Aki", "Aki Bersih Bebas Air", "kg", 16.4, 125),
            ]
            for mat, grade, unit, price, sort in defaults:
                cur.execute(
                    """
                    INSERT INTO buy_prices (material, grade, unit, price, sort_order)
                    VALUES (%s,%s,%s,%s,%s);
                    """,
                    (mat, grade, unit, price, sort),
                )

        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()
        conn.close()


def _buy_price_row_payload(r):
    return {
        "id": int(r["id"]),
        "material": str(r["material"] or ""),
        "grade": str(r["grade"] or ""),
        "unit": str(r["unit"] or "kg"),
        "price": float(r["price"]) if r["price"] is not None else 0.0,
        "note": str(r["note"] or ""),
        "is_active": bool(r["is_active"]) if r.get("is_active") is not None else True,
        "sort_order": int(r["sort_order"]) if r.get("sort_order") is not None else 0,
        "updated_at": r["updated_at"].strftime("%d/%m/%Y") if r.get("updated_at") else "-",
        "updated_at_str": r["updated_at"].strftime("%d/%m/%Y %H:%M") if r.get("updated_at") else "-",
    }


def _fetch_buy_price_rows(active_only=False):
    ensure_buy_prices_schema()
    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        if active_only:
            cur.execute(
                """
                SELECT id, material, grade, unit, price, note, is_active, sort_order, updated_at
                FROM buy_prices
                WHERE is_active = TRUE
                ORDER BY sort_order ASC, id ASC;
                """
            )
        else:
            cur.execute(
                """
                SELECT id, material, grade, unit, price, note, is_active, sort_order, updated_at
                FROM buy_prices
                ORDER BY sort_order ASC, id ASC;
                """
            )
        return [_buy_price_row_payload(r) for r in cur.fetchall()]
    finally:
        cur.close()
        conn.close()


def _group_buy_prices(items):
    groups = {}
    for it in items:
        groups.setdefault(it["material"], []).append(it)
    return [{"material": material, "items": rows} for material, rows in groups.items()]


def _mobile_admin_guard():
    user = getattr(request, "mobile_user", None) or {}
    if str(user.get("role") or "").strip().lower() != "admin":
        return mobile_api_response(ok=False, message="Akses ditolak. Hanya admin.", status_code=403)
    return None


@buy_prices_bp.route("/api/buy-prices", methods=["GET", "OPTIONS"])
def api_buy_prices():
    if request.method == "OPTIONS":
        resp = Response("", status=200)
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type"
        return resp

    items = _fetch_buy_price_rows(active_only=True)
    resp = jsonify({"ok": True, "groups": _group_buy_prices(items)})
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    resp.headers["Cache-Control"] = "public, max-age=300"
    return resp


@buy_prices_bp.route("/api/mobile/buy-prices", methods=["GET"])
@mobile_api_login_required
def mobile_buy_prices_list():
    deny = _mobile_admin_guard()
    if deny:
        return deny
    items = _fetch_buy_price_rows(active_only=False)
    return mobile_api_response(
        ok=True,
        message="Data harga beli berhasil dimuat.",
        data={
            "rows": items,
            "groups": _group_buy_prices(items),
            "landing_page_api": "/api/buy-prices",
        },
    )


@buy_prices_bp.route("/api/mobile/buy-prices", methods=["POST"])
@mobile_api_login_required
def mobile_buy_prices_add():
    deny = _mobile_admin_guard()
    if deny:
        return deny

    ensure_buy_prices_schema()
    data = request.get_json(silent=True) or {}
    material = (data.get("material") or "").strip()
    grade = (data.get("grade") or "").strip()
    unit = (data.get("unit") or "kg").strip() or "kg"
    note = (data.get("note") or "").strip()
    price = max(0.0, float(data.get("price") or 0))
    is_active = bool(data.get("is_active", True))

    if not material:
        return mobile_api_response(ok=False, message="Kategori material wajib diisi.", status_code=400)
    if not grade:
        return mobile_api_response(ok=False, message="Nama barang / grade wajib diisi.", status_code=400)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute(
            """
            INSERT INTO buy_prices (material, grade, unit, price, note, is_active, sort_order)
            VALUES (%s,%s,%s,%s,%s,%s,(SELECT COALESCE(MAX(sort_order),0)+1 FROM buy_prices))
            RETURNING id, material, grade, unit, price, note, is_active, sort_order, updated_at;
            """,
            (material, grade, unit, price, note, is_active),
        )
        row = cur.fetchone()
        conn.commit()
        payload = _buy_price_row_payload(row)
        return mobile_api_response(ok=True, message="Harga beli berhasil ditambahkan.", data={"row": payload})
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close()
        conn.close()


@buy_prices_bp.route("/api/mobile/buy-prices/<int:pid>", methods=["PUT"])
@mobile_api_login_required
def mobile_buy_prices_update(pid):
    deny = _mobile_admin_guard()
    if deny:
        return deny

    ensure_buy_prices_schema()
    data = request.get_json(silent=True) or {}
    price = max(0.0, float(data.get("price") or 0))
    note = (data.get("note") or "").strip()
    is_active = bool(data.get("is_active", True))
    material = (data.get("material") or "").strip()
    grade = (data.get("grade") or "").strip()
    unit = (data.get("unit") or "kg").strip() or "kg"

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("SELECT id, material, grade, unit FROM buy_prices WHERE id=%s LIMIT 1;", (pid,))
        existing = cur.fetchone()
        if not existing:
            return mobile_api_response(ok=False, message="Data tidak ditemukan.", status_code=404)

        material = material or existing["material"]
        grade = grade or existing["grade"]
        unit = unit or existing["unit"] or "kg"

        cur.execute(
            """
            UPDATE buy_prices
            SET material=%s, grade=%s, unit=%s, price=%s, note=%s, is_active=%s, updated_at=CURRENT_TIMESTAMP
            WHERE id=%s
            RETURNING id, material, grade, unit, price, note, is_active, sort_order, updated_at;
            """,
            (material, grade, unit, price, note, is_active, pid),
        )
        row = cur.fetchone()
        conn.commit()
        return mobile_api_response(ok=True, message="Harga beli berhasil diperbarui.", data={"row": _buy_price_row_payload(row)})
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close()
        conn.close()


@buy_prices_bp.route("/api/mobile/buy-prices/<int:pid>", methods=["DELETE"])
@mobile_api_login_required
def mobile_buy_prices_delete(pid):
    deny = _mobile_admin_guard()
    if deny:
        return deny

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)
    try:
        cur.execute("DELETE FROM buy_prices WHERE id=%s RETURNING id;", (pid,))
        row = cur.fetchone()
        conn.commit()
        if not row:
            return mobile_api_response(ok=False, message="Data tidak ditemukan.", status_code=404)
        return mobile_api_response(ok=True, message="Harga beli berhasil dihapus.")
    except Exception as e:
        conn.rollback()
        return mobile_api_response(ok=False, message=str(e), status_code=500)
    finally:
        cur.close()
        conn.close()


@buy_prices_bp.route("/admin/buy-prices")
def admin_buy_prices():
    deny = admin_required()
    if deny:
        return deny

    rows = _fetch_buy_price_rows(active_only=False)
    return render_template("admin_buy_prices.html", rows=rows)


@buy_prices_bp.route("/admin/buy-prices/save", methods=["POST"])
def admin_buy_prices_save():
    deny = admin_required()
    if deny:
        return deny

    ensure_buy_prices_schema()
    data = request.get_json(silent=True) or {}
    action = data.get("action", "")

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        if action == "update":
            pid = int(data.get("id", 0))
            price = max(0.0, float(data.get("price", 0) or 0))
            note = (data.get("note") or "").strip()
            is_active = bool(data.get("is_active", True))

            cur.execute(
                """
                UPDATE buy_prices
                SET price=%s, note=%s, is_active=%s, updated_at=CURRENT_TIMESTAMP
                WHERE id=%s
                RETURNING id, material, grade, unit, price, note, is_active, sort_order, updated_at;
                """,
                (price, note, is_active, pid),
            )
            row = cur.fetchone()
            conn.commit()

            if not row:
                return jsonify({"ok": False, "error": "Not found"}), 404

            return jsonify({"ok": True, "row": _buy_price_row_payload(row)})

        elif action == "add":
            material = (data.get("material") or "").strip()
            grade = (data.get("grade") or "").strip()
            unit = (data.get("unit") or "kg").strip()
            price = max(0.0, float(data.get("price", 0) or 0))
            note = (data.get("note") or "").strip()

            if not material:
                return jsonify({"ok": False, "error": "Material wajib diisi"}), 400

            cur.execute(
                """
                INSERT INTO buy_prices (material, grade, unit, price, note, sort_order)
                VALUES (%s,%s,%s,%s,%s,(SELECT COALESCE(MAX(sort_order),0)+1 FROM buy_prices))
                RETURNING id, material, grade, unit, price, note, is_active, sort_order, updated_at;
                """,
                (material, grade, unit, price, note),
            )
            row = cur.fetchone()
            conn.commit()

            return jsonify({"ok": True, "row": _buy_price_row_payload(row)})

        elif action == "delete":
            pid = int(data.get("id", 0))
            cur.execute("DELETE FROM buy_prices WHERE id=%s;", (pid,))
            conn.commit()
            return jsonify({"ok": True})

        else:
            return jsonify({"ok": False, "error": "Unknown action"}), 400

    except Exception as e:
        conn.rollback()
        return jsonify({"ok": False, "error": str(e)}), 500
    finally:
        cur.close()
        conn.close()

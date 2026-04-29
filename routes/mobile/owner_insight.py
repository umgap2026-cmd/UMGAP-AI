@mobile_owner_bp.route("/owner/insight", methods=["GET"])
@mobile_api_login_required
def owner_insight():

    user = request.mobile_user
    if user.get("role") not in ("owner", "admin"):
        return mobile_api_response(False, "Akses ditolak", 403)

    conn = get_conn()
    cur = conn.cursor(cursor_factory=RealDictCursor)

    try:
        # Total gaji bulan ini
        cur.execute("""
            SELECT COALESCE(SUM(monthly_salary),0) AS total_salary
            FROM payroll_settings;
        """)
        salary = cur.fetchone()["total_salary"]

        # Total nilai stok
        cur.execute("""
            SELECT COALESCE(SUM(total_value),0) AS total_stock
            FROM fin_stock_summary;
        """)
        stock = cur.fetchone()["total_stock"]

        # Total transaksi bulan ini
        cur.execute("""
            SELECT COALESCE(SUM(total_amount),0) AS total_revenue
            FROM fin_transactions
            WHERE created_at >= date_trunc('month', CURRENT_DATE);
        """)
        revenue = cur.fetchone()["total_revenue"]

        # KPI sederhana
        profit_est = revenue - salary

        return mobile_api_response(True, "OK", {
            "salary_total": float(salary),
            "stock_value": float(stock),
            "revenue": float(revenue),
            "profit_estimation": float(profit_est),
        })

    finally:
        cur.close()
        conn.close()
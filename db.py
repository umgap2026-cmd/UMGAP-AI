import os
import psycopg2
from psycopg2.extras import RealDictCursor
from urllib.parse import urlparse

def get_conn():
    db_url = os.getenv("DATABASE_URL")
    if db_url:
        # Pastikan sslmode ada (Render external biasanya butuh)
        if "sslmode=" not in db_url:
            joiner = "&" if "?" in db_url else "?"
            db_url = db_url + f"{joiner}sslmode=require"

        return psycopg2.connect(db_url, cursor_factory=RealDictCursor)

    # fallback lama (kalau kamu tetap mau pakai env satu-satu)
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        database=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER") or os.getenv("DB_USERNAME"),
        password=os.getenv("DB_PASSWORD") or os.getenv("DB_PASS"),
        port=os.getenv("DB_PORT") or 5432,
        sslmode=os.getenv("DB_SSLMODE") or "require",
        cursor_factory=RealDictCursor,
    )

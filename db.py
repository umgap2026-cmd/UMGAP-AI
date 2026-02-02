import os
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from pathlib import Path

# lokal: baca .env kalau ada
env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=env_path, override=False)

def get_conn():
    # 1) Paling enak di Render: pakai DATABASE_URL
    db_url = os.getenv("DATABASE_URL")
    if db_url:
        # kalau belum ada sslmode, tambahkan (Render sering butuh SSL untuk external URL)
        if "sslmode=" not in db_url:
            sep = "&" if "?" in db_url else "?"
            db_url = f"{db_url}{sep}sslmode=require"
        return psycopg2.connect(db_url, cursor_factory=RealDictCursor)

    # 2) fallback: pakai env terpisah
    host = os.getenv("DB_HOST")
    port = os.getenv("DB_PORT", "5432")
    dbname = os.getenv("DB_NAME")
    user = os.getenv("DB_USER")
    password = os.getenv("DB_PASSWORD") or os.getenv("DB_PASS")  # support dua nama

    # kalau host external render, pakai SSL
    use_ssl = host and ("render.com" in host)
    if use_ssl:
        return psycopg2.connect(
            host=host, port=port, dbname=dbname, user=user, password=password,
            sslmode="require", cursor_factory=RealDictCursor
        )

    return psycopg2.connect(
        host=host, port=port, dbname=dbname, user=user, password=password,
        cursor_factory=RealDictCursor
    )

import os
import psycopg2
from psycopg2.extras import RealDictCursor

def get_conn():
    db_url = os.getenv("DATABASE_URL")

    if db_url:
        # Render Postgres biasanya butuh SSL
        if "sslmode=" not in db_url:
            joiner = "&" if "?" in db_url else "?"
            db_url = db_url + f"{joiner}sslmode=require"

        return psycopg2.connect(db_url, cursor_factory=RealDictCursor)

    # fallback kalau DATABASE_URL belum diset
    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASS"),
        sslmode=os.getenv("DB_SSLMODE", "require"),
        cursor_factory=RealDictCursor,
    )

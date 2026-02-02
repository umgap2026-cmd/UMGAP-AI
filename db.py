import os
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv

load_dotenv()

def get_conn():
    # Prioritas: DATABASE_URL (Render)
    db_url = os.getenv("DATABASE_URL")

    if db_url:
        # pastikan sslmode=require (Render biasanya perlu)
        if "sslmode=" not in db_url:
            joiner = "&" if "?" in db_url else "?"
            db_url = db_url + f"{joiner}sslmode=require"

        return psycopg2.connect(db_url, cursor_factory=RealDictCursor)

    # Fallback: pecahan env (local)
    db_password = os.getenv("DB_PASSWORD") or os.getenv("DB_PASS")

    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=db_password,
        sslmode=os.getenv("DB_SSLMODE", "prefer"),
        cursor_factory=RealDictCursor,
    )

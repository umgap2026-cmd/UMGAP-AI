import os
import psycopg2
from psycopg2.extras import RealDictCursor

def get_conn():
    dsn = os.getenv("DATABASE_URL")
    if dsn:
        # kalau external butuh SSL
        if "sslmode=" not in dsn and os.getenv("PGSSLMODE") == "require":
            dsn = dsn + ("&" if "?" in dsn else "?") + "sslmode=require"
        return psycopg2.connect(dsn, cursor_factory=RealDictCursor)

    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASS"),
        cursor_factory=RealDictCursor,
    )

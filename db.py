import os
import psycopg2
from psycopg2.extras import RealDictCursor
from urllib.parse import urlparse

def get_conn():
    database_url = os.getenv("DATABASE_URL")

    # ✅ Render recommended: DATABASE_URL
    if database_url:
        # Pastikan support postgres:// atau postgresql://
        if database_url.startswith("postgres://"):
            database_url = database_url.replace("postgres://", "postgresql://", 1)

        sslmode = os.getenv("DB_SSLMODE", "require")  # render external butuh ssl
        return psycopg2.connect(database_url, sslmode=sslmode, cursor_factory=RealDictCursor)

    # ✅ Fallback: pakai DB_* (untuk lokal / custom)
    host = os.getenv("DB_HOST")
    dbname = os.getenv("DB_NAME")
    user = os.getenv("DB_USER")
    password = os.getenv("DB_PASS")
    port = os.getenv("DB_PORT", "5432")

    sslmode = os.getenv("DB_SSLMODE")  # boleh kosong kalau lokal
    kwargs = dict(
        host=host,
        dbname=dbname,
        user=user,
        password=password,
        port=port,
        cursor_factory=RealDictCursor,
    )
    if sslmode:
        kwargs["sslmode"] = sslmode

    return psycopg2.connect(**kwargs)

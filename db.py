import os
import atexit
import psycopg2
from psycopg2.extras import RealDictCursor
from psycopg2.pool import ThreadedConnectionPool
from dotenv import load_dotenv
from pathlib import Path
from contextlib import contextmanager

# paksa baca .env dari folder project (root)
env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=env_path)

_POOL = None

def _init_pool():
    """
    Buat pool koneksi sekali saja.
    Ini jauh lebih cepat daripada connect tiap request.
    """
    global _POOL
    if _POOL is not None:
        return _POOL

    minconn = int(os.getenv("DB_POOL_MIN", "1"))
    maxconn = int(os.getenv("DB_POOL_MAX", "6"))

    _POOL = ThreadedConnectionPool(
        minconn=minconn,
        maxconn=maxconn,
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),

        # bikin koneksi lebih stabil di Render
        connect_timeout=8,
        keepalives=1,
        keepalives_idle=30,
        keepalives_interval=10,
        keepalives_count=5,
        sslmode=os.getenv("DB_SSLMODE", "require"),
    )

    return _POOL

@contextmanager
def db_conn():
    """
    Pakai ini di app.py:
        with db_conn() as conn:
            cur = conn.cursor(cursor_factory=RealDictCursor)
            ...
    """
    pool = _init_pool()
    conn = pool.getconn()
    try:
        yield conn
        # commit dilakukan manual di app (lebih aman), tapi kalau lupa tetap bisa
    finally:
        # rollback kalau ada transaksi nyangkut
        try:
            if conn and conn.status != psycopg2.extensions.STATUS_READY:
                conn.rollback()
        except Exception:
            pass
        pool.putconn(conn)

def close_pool():
    global _POOL
    if _POOL is not None:
        try:
            _POOL.closeall()
        finally:
            _POOL = None

atexit.register(close_pool)

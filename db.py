import os
import atexit
from contextlib import contextmanager

import psycopg2
from psycopg2.pool import ThreadedConnectionPool
from dotenv import load_dotenv
from pathlib import Path

# Load .env (project root)
env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=env_path)

_POOL = None

def _build_dsn():
    # Prefer DATABASE_URL (Render)
    database_url = (os.getenv("DATABASE_URL") or "").strip()
    if database_url:
        return database_url

    host = os.getenv("DB_HOST")
    port = os.getenv("DB_PORT") or "5432"
    dbname = os.getenv("DB_NAME")
    user = os.getenv("DB_USER")
    password = os.getenv("DB_PASSWORD")
    sslmode = os.getenv("DB_SSLMODE", "require")

    parts = []
    if host: parts.append(f"host={host}")
    if port: parts.append(f"port={port}")
    if dbname: parts.append(f"dbname={dbname}")
    if user: parts.append(f"user={user}")
    if password: parts.append(f"password={password}")
    if sslmode: parts.append(f"sslmode={sslmode}")
    parts.append("connect_timeout=8")
    return " ".join(parts)

def _init_pool():
    global _POOL
    if _POOL is not None:
        return _POOL

    minconn = int(os.getenv("DB_POOL_MIN", "1"))
    maxconn = int(os.getenv("DB_POOL_MAX", "6"))

    dsn = _build_dsn()
    _POOL = ThreadedConnectionPool(
        minconn=minconn,
        maxconn=maxconn,
        dsn=dsn,
        keepalives=1,
        keepalives_idle=30,
        keepalives_interval=10,
        keepalives_count=5,
    )
    return _POOL

class PooledConn:
    __slots__ = ("_pool", "_conn", "_closed")

    def __init__(self, pool, conn):
        self._pool = pool
        self._conn = conn
        self._closed = False

    def __getattr__(self, name):
        return getattr(self._conn, name)

    def close(self):
        # Return to pool (NOT real close)
        if self._closed:
            return
        try:
            try:
                if self._conn and self._conn.status != psycopg2.extensions.STATUS_READY:
                    self._conn.rollback()
            except Exception:
                pass
        finally:
            self._pool.putconn(self._conn)
            self._closed = True

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        self.close()
        return False

def db_conn():
    pool = _init_pool()
    conn = pool.getconn()
    return PooledConn(pool, conn)

@contextmanager
def db_conn_ctx():
    conn = db_conn()
    try:
        yield conn
    finally:
        conn.close()

def close_pool():
    global _POOL
    if _POOL is not None:
        try:
            _POOL.closeall()
        finally:
            _POOL = None

atexit.register(close_pool)

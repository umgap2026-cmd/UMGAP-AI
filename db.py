import os
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv
from pathlib import Path

# paksa baca .env dari folder project (root)
env_path = Path(__file__).resolve().parent / ".env"
load_dotenv(dotenv_path=env_path)

def get_conn():
    password = os.getenv("DB_PASSWORD") or os.getenv("DB_PASS")
    user = os.getenv("DB_USER") or os.getenv("DB_USERNAME")

    return psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=user,
        password=password,
        cursor_factory=RealDictCursor,
    )



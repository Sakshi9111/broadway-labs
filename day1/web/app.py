import os
import time

import psycopg2
from flask import Flask, jsonify, render_template, request

app = Flask(__name__)

DB_CONFIG = {
    "host": os.environ.get("DB_HOST", "db"),
    "port": os.environ.get("DB_PORT", "5432"),
    "dbname": os.environ.get("DB_NAME", "appdb"),
    "user": os.environ.get("DB_USER", "appuser"),
    "password": os.environ.get("DB_PASSWORD", "apppassword"),
}


def get_connection(retries=10, delay=2):
    """Retry connecting to Postgres while it finishes starting up."""
    last_error = None
    for _ in range(retries):
        try:
            return psycopg2.connect(**DB_CONFIG)
        except psycopg2.OperationalError as exc:
            last_error = exc
            time.sleep(delay)
    raise last_error


def init_db():
    conn = get_connection()
    try:
        with conn, conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS messages (
                    id SERIAL PRIMARY KEY,
                    content TEXT NOT NULL,
                    created_at TIMESTAMPTZ DEFAULT NOW()
                );
                """
            )
    finally:
        conn.close()


@app.route("/")
def index():
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT id, content, created_at FROM messages ORDER BY id DESC;")
            rows = cur.fetchall()
    finally:
        conn.close()
    return render_template("index.html", messages=rows)


@app.route("/messages", methods=["POST"])
def add_message():
    content = request.form.get("content", "").strip()
    if content:
        conn = get_connection()
        try:
            with conn, conn.cursor() as cur:
                cur.execute("INSERT INTO messages (content) VALUES (%s);", (content,))
        finally:
            conn.close()
    return index()


@app.route("/health")
def health():
    try:
        conn = get_connection(retries=1)
        conn.close()
        db_status = "ok"
    except Exception as exc:  # noqa: BLE001
        db_status = f"error: {exc}"
    return jsonify(status="ok", database=db_status)


if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)
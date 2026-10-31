"""Tiny 2-tier demo app: Flask UI + JSON API on top of PostgreSQL."""
import os

import psycopg2
import psycopg2.extras
from flask import Flask, jsonify, request, send_from_directory

app = Flask(__name__)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

DB = dict(
    host=os.environ["DB_HOST"],
    dbname=os.environ["DB_NAME"],
    user=os.environ["DB_USER"],
    password=os.environ["DB_PASSWORD"],
    connect_timeout=3,
)


def get_conn():
    return psycopg2.connect(**DB)


def table_exists(cur):
    cur.execute("SELECT to_regclass('public.notes') IS NOT NULL")
    return cur.fetchone()[0]


@app.get("/")
def index():
    return send_from_directory(BASE_DIR, "index.html")


@app.get("/health")
def health():
    # Used by the ALB. Always 200 so the app stays in service even if the DB is not ready yet.
    return "ok", 200


@app.get("/api/status")
def status():
    try:
        with get_conn() as conn, conn.cursor() as cur:
            cur.execute("SELECT version()")
            version = cur.fetchone()[0]
            return jsonify(connected=True, host=DB["host"], version=version,
                           table_exists=table_exists(cur))
    except Exception as exc:  # noqa: BLE001 - demo app, report any failure
        return jsonify(connected=False, host=DB["host"], error=str(exc)), 200


@app.post("/api/table")
def create_table():
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute(
            """CREATE TABLE IF NOT EXISTS notes (
                   id SERIAL PRIMARY KEY,
                   title TEXT NOT NULL,
                   created_at TIMESTAMPTZ NOT NULL DEFAULT now()
               )"""
        )
    return jsonify(ok=True)


@app.delete("/api/table")
def drop_table():
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("DROP TABLE IF EXISTS notes")
    return jsonify(ok=True)


@app.get("/api/notes")
def list_notes():
    with get_conn() as conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        if not table_exists(cur):
            return jsonify(error="Table 'notes' does not exist. Click 'Create table' first."), 404
        cur.execute("SELECT id, title, created_at FROM notes ORDER BY id")
        return jsonify(cur.fetchall())


@app.post("/api/notes")
def add_note():
    title = (request.get_json(silent=True) or {}).get("title", "").strip()
    if not title:
        return jsonify(error="title is required"), 400
    with get_conn() as conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        if not table_exists(cur):
            return jsonify(error="Table 'notes' does not exist. Click 'Create table' first."), 404
        cur.execute("INSERT INTO notes (title) VALUES (%s) RETURNING id, title, created_at", (title,))
        return jsonify(cur.fetchone()), 201


@app.put("/api/notes/<int:note_id>")
def update_note(note_id):
    title = (request.get_json(silent=True) or {}).get("title", "").strip()
    if not title:
        return jsonify(error="title is required"), 400
    with get_conn() as conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        cur.execute("UPDATE notes SET title = %s WHERE id = %s RETURNING id, title, created_at",
                    (title, note_id))
        row = cur.fetchone()
        return (jsonify(row), 200) if row else (jsonify(error="not found"), 404)


@app.delete("/api/notes/<int:note_id>")
def delete_note(note_id):
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("DELETE FROM notes WHERE id = %s", (note_id,))
        return jsonify(deleted=cur.rowcount)


@app.errorhandler(psycopg2.Error)
def db_error(exc):
    return jsonify(error=str(exc).strip()), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

"""2-tier demo app: Flask UI + JSON API on top of PostgreSQL.

Lets you create your own tables (name + typed columns), list databases/tables,
insert rows and delete rows, to show the app can talk to Postgres.
"""
import os
import re

import psycopg2
import psycopg2.extras
from flask import Flask, jsonify, request, send_from_directory
from psycopg2 import sql
from werkzeug.exceptions import HTTPException

app = Flask(__name__)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

DB = dict(
    host=os.environ["DB_HOST"],
    dbname=os.environ["DB_NAME"],
    user=os.environ["DB_USER"],
    password=os.environ["DB_PASSWORD"],
    connect_timeout=3,
)

IDENT = re.compile(r"^[a-z_][a-z0-9_]{0,39}$")
TYPES = {
    "text": "TEXT",
    "integer": "INTEGER",
    "numeric": "NUMERIC",
    "boolean": "BOOLEAN",
    "date": "DATE",
    "timestamp": "TIMESTAMP",
}
MAX_COLUMNS = 20


class BadRequest(Exception):
    pass


def get_conn():
    return psycopg2.connect(**DB)


def valid_ident(value, what):
    value = (value or "").strip().lower()
    if not IDENT.match(value):
        raise BadRequest(f"Invalid {what} '{value}': use lowercase letters, digits and underscores, "
                         "starting with a letter or underscore (max 40 chars).")
    return value


def user_columns(cur, table):
    """Column list of a public table, or None if the table does not exist."""
    cur.execute(
        """SELECT column_name, data_type FROM information_schema.columns
           WHERE table_schema = 'public' AND table_name = %s
           ORDER BY ordinal_position""",
        (table,),
    )
    out = []
    for r in cur.fetchall():
        # Works with both normal and dict cursors
        if isinstance(r, dict):
            out.append({"name": r["column_name"], "type": r["data_type"]})
        else:
            out.append({"name": r[0], "type": r[1]})
    return out or None


def require_table(cur, name):
    table = valid_ident(name, "table name")
    cols = user_columns(cur, table)
    if cols is None:
        raise BadRequest(f"Table '{table}' does not exist")
    return table, cols


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
            return jsonify(connected=True, host=DB["host"], version=version)
    except Exception as exc:  # noqa: BLE001 - demo app, report any failure
        return jsonify(connected=False, host=DB["host"], error=str(exc)), 200


@app.get("/api/dbinfo")
def db_info():
    """Like 'show databases' and 'show tables' for this connection."""
    with get_conn() as conn, conn.cursor() as cur:
        cur.execute("SELECT datname FROM pg_database WHERE NOT datistemplate ORDER BY datname")
        databases = [r[0] for r in cur.fetchall()]
        cur.execute("SELECT current_database()")
        current = cur.fetchone()[0]
        cur.execute(
            """SELECT table_name FROM information_schema.tables
               WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
               ORDER BY table_name"""
        )
        tables = []
        for (name,) in cur.fetchall():
            cur.execute(sql.SQL("SELECT count(*) FROM {}").format(sql.Identifier(name)))
            tables.append({"name": name, "rows": cur.fetchone()[0],
                           "columns": user_columns(cur, name)})
    return jsonify(current=current, databases=databases, tables=tables)


@app.post("/api/tables")
def create_table():
    body = request.get_json(silent=True) or {}
    table = valid_ident(body.get("name"), "table name")
    cols = body.get("columns") or []
    if len(cols) > MAX_COLUMNS:
        raise BadRequest(f"At most {MAX_COLUMNS} columns")

    defs = [sql.SQL("id SERIAL PRIMARY KEY")]
    seen = {"id"}
    for col in cols:
        name = valid_ident(col.get("name"), "column name")
        ctype = TYPES.get((col.get("type") or "").lower())
        if name in seen:
            raise BadRequest(f"Duplicate column name '{name}' (an 'id' column is added automatically)")
        if not ctype:
            raise BadRequest(f"Unsupported type for column '{name}'")
        seen.add(name)
        defs.append(sql.SQL("{} {}").format(sql.Identifier(name), sql.SQL(ctype)))

    with get_conn() as conn, conn.cursor() as cur:
        if user_columns(cur, table) is not None:
            raise BadRequest(f"Table '{table}' already exists")
        cur.execute(sql.SQL("CREATE TABLE {} ({})").format(
            sql.Identifier(table), sql.SQL(", ").join(defs)))
    return jsonify(ok=True, message=f"Table '{table}' created successfully"), 201


@app.delete("/api/tables/<name>")
def drop_table(name):
    with get_conn() as conn, conn.cursor() as cur:
        table, _ = require_table(cur, name)
        cur.execute(sql.SQL("DROP TABLE {}").format(sql.Identifier(table)))
    return jsonify(ok=True, message=f"Table '{table}' dropped")


@app.get("/api/tables/<name>/rows")
def list_rows(name):
    with get_conn() as conn, conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
        table, cols = require_table(name=name, cur=cur)
        cur.execute(sql.SQL("SELECT * FROM {} ORDER BY id LIMIT 500").format(sql.Identifier(table)))
        rows = cur.fetchall()
    return jsonify(table=table, columns=cols, rows=rows)


@app.post("/api/tables/<name>/rows")
def insert_row(name):
    values = (request.get_json(silent=True) or {}).get("values") or {}
    with get_conn() as conn, conn.cursor() as cur:
        table, cols = require_table(cur, name)
        names = [c["name"] for c in cols if c["name"] != "id"]
        # Empty input becomes NULL; Postgres casts the text to the column type.
        data = {n: (values.get(n) if values.get(n) not in ("", None) else None) for n in names}
        if names:
            cur.execute(
                sql.SQL("INSERT INTO {} ({}) VALUES ({})").format(
                    sql.Identifier(table),
                    sql.SQL(", ").join(sql.Identifier(n) for n in names),
                    sql.SQL(", ").join(sql.Placeholder() for _ in names)),
                [data[n] for n in names])
        else:
            cur.execute(sql.SQL("INSERT INTO {} DEFAULT VALUES").format(sql.Identifier(table)))
    return jsonify(ok=True, message=f"Row added to '{table}'"), 201


@app.delete("/api/tables/<name>/rows/<int:row_id>")
def delete_row(name, row_id):
    with get_conn() as conn, conn.cursor() as cur:
        table, _ = require_table(cur, name)
        cur.execute(sql.SQL("DELETE FROM {} WHERE id = %s").format(sql.Identifier(table)), (row_id,))
        deleted = cur.rowcount
    return jsonify(ok=True, deleted=deleted, message=f"Deleted {deleted} row(s) from '{table}'")


@app.errorhandler(BadRequest)
def bad_request(exc):
    return jsonify(error=str(exc)), 400


@app.errorhandler(psycopg2.DataError)
def data_error(exc):
    # e.g. text typed into an INTEGER column
    return jsonify(error=str(exc).strip().split("\n")[0]), 400


@app.errorhandler(Exception)
def any_error(exc):
    # Return JSON so the UI shows the real message instead of "Internal Server Error"
    if isinstance(exc, HTTPException):
        return jsonify(error=exc.description), exc.code
    app.logger.exception("Unhandled error")
    return jsonify(error=f"{type(exc).__name__}: {str(exc).strip()}"), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
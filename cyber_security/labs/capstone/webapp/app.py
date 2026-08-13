#!/usr/bin/env python3
"""Capstone target: "Northwind Ops Portal" -- a small internal web app with
TWO independent bug pairs on purpose, each pair a self-contained sub-chain
to the same eventual objective (full host compromise + stolen cloud
creds). See content/day20-capstone-attack.md's Concept section for why
that independence matters, and content/day21-capstone-defend.md for why
fixing only one pair still leaves the other wide open.

Sub-chain A -- broken access control + command injection (no SQL
injection needed at all):
  1. POST /register -- open to anyone, no approval, role="user" always.
  2. GET /admin/diagnostics?host=... -- BUG (broken access control): only
     checks that *some* session exists (`"user" in session`), never that
     its role is "admin". Any registered "user" account reaches it.
  3. That same endpoint has a SECOND, independent bug: it builds a shell
     command by directly interpolating the "host" parameter into
     `subprocess.getoutput(...)`, which always runs via `/bin/sh -c`.
     Shell metacharacters in "host" (";", "|", backticks, "$()") are not
     stripped or escaped at all -- classic OS command injection.

Sub-chain B -- SQL injection to admin, then admin-gated SSRF:
  1. POST /login -- builds its query with an f-string, not a parameterized
     placeholder: `SELECT ... WHERE username='{username}' AND
     password='{password}'`. A username of `admin' -- ` (with anything as
     the password) comments out the password check entirely in SQLite,
     logging the attacker in as the real "admin" row with no password
     knowledge at all.
  2. GET /admin/fetch?url=... -- CORRECTLY checks `role == "admin"` (this
     endpoint's access control is not the bug) but performs the fetch
     with zero URL validation: no scheme allowlist, no block on
     link-local/internal ranges. A real SSRF, usable to reach anything
     `webapp` itself can reach on ANY of its networks -- including the
     169.254.169.254 metadata address on the `imds` network, which
     `attacker` itself can never reach directly.

Nothing here needs a database server: a single on-disk SQLite file is
created fresh on every container start (no persistent volume), exactly
matching this lab's "throwaway, rebuild to reset" pattern from earlier
days. The seed admin password is generated randomly at startup and never
written anywhere or logged -- nobody, including whoever wrote this app,
is meant to know it. That is the whole point of sub-chain B: the ONLY way
in as admin is the SQL injection, not a guessable/leaked password.
"""
import logging
import os
import secrets
import sqlite3
import subprocess
import time

import requests
from flask import Flask, jsonify, request, session

app = Flask(__name__)
app.secret_key = secrets.token_hex(32)

DB_PATH = "/tmp/northwind.db"

OPS_HOST = os.environ.get("OPS_HOST", "host")
OPS_USER = os.environ.get("OPS_USER", "opsuser")

# --- access logging, used by the Day 21 detection drill --------------------
ACCESS_LOG_PATH = "/var/log/webapp/access.log"
access_logger = logging.getLogger("webapp.access")
access_logger.setLevel(logging.INFO)
try:
    _handler = logging.FileHandler(ACCESS_LOG_PATH)
    _handler.setFormatter(logging.Formatter("%(asctime)s %(message)s"))
    access_logger.addHandler(_handler)
except OSError:
    # /var/log/webapp not writable (e.g. bind mount not created yet) --
    # degrade to stderr rather than crash the whole app.
    access_logger.addHandler(logging.StreamHandler())


@app.before_request
def log_request():
    user = session.get("user", "-")
    role = session.get("role", "-")
    access_logger.info(
        "ip=%s user=%s role=%s method=%s path=%s query=%s",
        request.remote_addr,
        user,
        role,
        request.method,
        request.path,
        dict(request.args),
    )


def get_db():
    db = sqlite3.connect(DB_PATH)
    db.row_factory = sqlite3.Row
    return db


def init_db():
    db = get_db()
    db.execute(
        "CREATE TABLE IF NOT EXISTS users "
        "(username TEXT PRIMARY KEY, password TEXT NOT NULL, role TEXT NOT NULL)"
    )
    admin_password = secrets.token_urlsafe(24)  # never logged, never exposed
    db.execute(
        "INSERT OR IGNORE INTO users (username, password, role) VALUES (?, ?, ?)",
        ("admin", admin_password, "admin"),
    )
    db.commit()
    db.close()


@app.route("/")
def index():
    return (
        "<h1>Northwind Ops Portal</h1>"
        "<p>Routes: POST /register, GET/POST /login, GET /logout, "
        "GET /admin/diagnostics, GET /admin/fetch, GET /api/whoami</p>"
    )


@app.route("/register", methods=["POST"])
def register():
    username = request.form.get("username", "")
    password = request.form.get("password", "")
    if not username or not password:
        return jsonify({"error": "username and password required"}), 400
    db = get_db()
    try:
        db.execute(
            "INSERT INTO users (username, password, role) VALUES (?, ?, 'user')",
            (username, password),
        )
        db.commit()
    except sqlite3.IntegrityError:
        return jsonify({"error": "username already exists"}), 409
    finally:
        db.close()
    return jsonify({"status": "registered", "username": username, "role": "user"})


@app.route("/login", methods=["POST"])
def login():
    username = request.form.get("username", "")
    password = request.form.get("password", "")

    # --- VULNERABLE ON PURPOSE: f-string SQL, not a parameterized query ---
    # Day 21's Defense Lab replaces this with a `?`-placeholder query and
    # re-runs the exact same injection payload to prove it now fails.
    query = (
        f"SELECT username, role FROM users "
        f"WHERE username='{username}' AND password='{password}'"
    )
    db = get_db()
    try:
        row = db.execute(query).fetchone()
    except sqlite3.OperationalError as e:
        return jsonify({"error": f"query error: {e}"}), 400
    finally:
        db.close()

    if row is None:
        return jsonify({"error": "invalid username or password"}), 401

    session["user"] = row["username"]
    session["role"] = row["role"]
    return jsonify({"status": "logged in", "username": row["username"], "role": row["role"]})


@app.route("/logout")
def logout():
    session.clear()
    return jsonify({"status": "logged out"})


@app.route("/api/whoami")
def whoami():
    if "user" not in session:
        return jsonify({"user": None, "role": None}), 401
    return jsonify({"user": session["user"], "role": session["role"]})


@app.route("/admin/diagnostics")
def diagnostics():
    # BUG 1 (broken access control): should require session["role"] ==
    # "admin" and does not -- ANY logged-in user reaches this.
    if "user" not in session:
        return "login required", 401

    host = request.args.get("host", "127.0.0.1")

    # --- Defense Lab (Day 21): replace this whole block with
    # subprocess.run(["ping", "-c", "1", "-W", "2", host], ...) -- a real
    # argument LIST, never a shell string -- and re-run the exact same
    # payload below to prove it no longer chains a second command. ------
    result = subprocess.getoutput(f"ping -c 1 -W 2 {host}")
    # ------------------------------------------------------------------

    return f"<pre>{result}</pre>"


@app.route("/admin/fetch")
def admin_fetch():
    # This check IS correct -- role is verified, unlike /admin/diagnostics
    # above. The bug here is a completely different one: SSRF, not broken
    # access control.
    if session.get("role") != "admin":
        return jsonify({"error": "admin role required"}), 403

    url = request.args.get("url")
    if not url:
        return jsonify({"error": "missing url parameter"}), 400

    # --- VULNERABLE ON PURPOSE: no scheme allowlist, no block on
    # link-local/internal ranges (day09's SSRF lesson, replayed here).
    # Day 21 does not need to change this code at all -- flipping
    # fake-imds's IMDS_MODE to "v2" is enough to break the metadata-theft
    # payload specifically, without touching this endpoint's logic.
    try:
        r = requests.get(url, timeout=3)
        return (r.text, r.status_code)
    except requests.RequestException as e:
        return jsonify({"error": f"fetch failed: {e}"}), 502


if __name__ == "__main__":
    init_db()
    # give fake-imds / host a moment on a cold `docker compose up`
    time.sleep(1)
    app.run(host="0.0.0.0", port=5000)

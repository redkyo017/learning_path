#!/usr/bin/env python3
"""Day 11 target: one small Flask app carrying THREE earlier attack surfaces
at once, all instrumented with structured JSON logging so the `detection`
container has something real to detect against.

1. Port 5000 itself -- scannable exactly like Day 1/Day 2's targets. Today's
   attack lab replays `nmap -sS target` (Day 2's SYN-scan technique) against
   it; the `detection` container's Suricata rule watches for that exact
   SYN-burst pattern.

2. POST /login -- a weak, unlimited login with NO rate limiting and NO
   lockout, the same shape as Day 4's brute-force target (deliberately
   simplified back down to plain-form creds here, no JWT layer -- today's
   focus is detecting the brute force, not re-teaching JWT forging).

3. GET /search -- a classic UNION-based-SQLi-vulnerable product search.
   Day 8 ("Web attacks I: injection & XSS") hasn't shipped yet in this
   path's build order, so rather than pretend to "reuse" a target that
   doesn't exist, this lab builds its own minimal injection surface here --
   an honest scope note, named precisely in content/day11-detection.md
   Section 2 rather than glossed over.

Every request to /login or /search appends ONE JSON line to
/var/log/webapp/access.log, in a FIXED field order:
    {"ts": ..., "event": ..., "src_ip": ..., ...}
That fixed order is load-bearing: the `detection` container's fail2ban
filter (rules/fail2ban/target-bruteforce-filter.conf) and its jq-based SQLi
watcher (detection/sqli_watch.sh) both pattern-match against it directly.
"""
import json
import sqlite3
from datetime import datetime, timezone

from flask import Flask, request, jsonify

app = Flask(__name__)

LOG_PATH = "/var/log/webapp/access.log"

# --- deliberately weak: one hardcoded account, no lockout, no rate limit --
USERS = {"admin": "hunter2"}

# --- seed data for the SQLi-vulnerable /search endpoint -------------------
# `products` is the table the app's UI is "supposed" to expose; `users`
# holds the secret an attacker exfiltrates via UNION SELECT, exactly the
# shape of Day 8's planned SQLi lab.
_db = sqlite3.connect(":memory:", check_same_thread=False)
_db.execute("CREATE TABLE products (id INTEGER PRIMARY KEY, name TEXT, price TEXT)")
_db.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, username TEXT, password TEXT)")
_db.executemany(
    "INSERT INTO products (name, price) VALUES (?, ?)",
    [
        ("firewall appliance", "199.99"),
        ("managed network switch", "89.50"),
        ("USB hardware security key", "25.00"),
    ],
)
_db.executemany(
    "INSERT INTO users (username, password) VALUES (?, ?)",
    [
        ("admin", "S3cr3t-Admin-PW!"),
        ("svc_backup", "b4ckup-service-2024"),
    ],
)
_db.commit()


def log_event(fields: dict) -> None:
    """Append one JSON line. `ts` is always first, then exactly the fields
    the caller passes, IN THE ORDER GIVEN -- both downstream detectors
    (fail2ban's filter, sqli_watch.sh's jq query) depend on this fixed
    shape, not just "some JSON with these keys somewhere"."""
    entry = {"ts": datetime.now(timezone.utc).isoformat()}
    entry.update(fields)
    with open(LOG_PATH, "a") as f:
        f.write(json.dumps(entry) + "\n")


@app.route("/")
def index():
    return (
        "<h1>cyberlab-day11-target</h1>"
        "<p>Routes: POST /login, GET /search?q=...</p>"
        "<p>Every request to /login and /search is logged as structured "
        "JSON to /var/log/webapp/access.log.</p>"
    )


@app.route("/login", methods=["GET"])
def login_form():
    return (
        "<form method='POST' action='/login'>"
        "<input name='username'><input name='password' type='password'>"
        "<button type='submit'>Login</button></form>"
    )


@app.route("/login", methods=["POST"])
def login():
    username = request.form.get("username", "")
    password = request.form.get("password", "")
    ok = USERS.get(username) == password
    outcome = "success" if ok else "fail"

    # Fixed field order: ts, event, src_ip, username, outcome -- the
    # fail2ban filter (rules/fail2ban/target-bruteforce-filter.conf) is
    # written against exactly this shape.
    log_event(
        {
            "event": "login_attempt",
            "src_ip": request.remote_addr,
            "username": username,
            "outcome": outcome,
        }
    )

    if ok:
        return jsonify({"status": "ok"}), 200
    return jsonify({"status": "invalid credentials"}), 401


@app.route("/search")
def search():
    q = request.args.get("q", "")

    # Deliberately vulnerable: q is interpolated directly into the SQL
    # string, not bound as a parameter. This is Day 8's planned lesson
    # (injection = mixing data and code) built here as a self-contained
    # stand-in -- see the module docstring's scope note.
    query = f"SELECT id, name, price FROM products WHERE name LIKE '%{q}%'"
    try:
        rows = _db.execute(query).fetchall()
        status = 200
    except sqlite3.Error:
        rows = []
        status = 500

    log_event(
        {
            "event": "search_query",
            "src_ip": request.remote_addr,
            "query": q,
            "status": status,
        }
    )

    return jsonify({"results": rows}), status


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

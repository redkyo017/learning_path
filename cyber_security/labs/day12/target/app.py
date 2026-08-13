#!/usr/bin/env python3
"""Day 12 target -- the Phase 2 web-consolidation mini-CTF box.

Chains two live bugs, each individually the subject of an earlier Phase 2
day, onto ONE box, plus an offline log-analysis stage (Day 11's class):

1. POST /login -- SQL injection auth bypass (Day 8's injection class).
   The query is built by raw string formatting, on purpose, with zero
   parameterization:

       SELECT id, username, role FROM users
       WHERE username = '<username>' AND password = '<password>'

   Every real password in the `users` table is a random, undocumented
   32-hex-char string generated at startup -- nobody, including this
   file's author, could log in with a REAL password. The only way in is
   breaking the query's own syntax (e.g. username = admin' -- , which
   comments out the AND password=... clause and matches on username
   alone). Flag 1 -- the "foothold" -- is returned on ANY successful
   login, because on this box a successful login IS proof of injection.

2. GET /notes/<id> -- broken access control / IDOR (Day 9's access-
   control class), completely independent of WHICH account Step 1
   landed you as. It requires a valid session (any of them) but never
   checks that the requested note's owner_id matches the session's own
   user id. Note id=2 belongs to admin and holds Flag 2 -- reachable by
   ANY logged-in session, including alice's, because the ownership
   check that should gate it was simply never written.

3. ../logs/access.log + ../logs/alerts.log -- a detection challenge
   (Day 11's class), entirely OFFLINE: no live detector runs in this
   lab. The logs are a recorded capture of exactly this attack chain
   plus decoy/normal traffic and a couple of false-positive alerts.
   Flag 3 lives on the one true-positive alert whose evidence actually
   correlates against access.log -- see content/day12-ctf-web.md Stage 3
   and this lab's SOLUTION.md for the full answer.
"""
import os
import sqlite3
import uuid

from flask import Flask, jsonify, make_response, request

app = Flask(__name__)

DB_PATH = "/tmp/day12.db"


def init_db():
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    conn = sqlite3.connect(DB_PATH)
    conn.execute(
        "CREATE TABLE users ("
        " id INTEGER PRIMARY KEY,"
        " username TEXT NOT NULL,"
        " password TEXT NOT NULL,"
        " role TEXT NOT NULL"
        ")"
    )
    conn.execute(
        "CREATE TABLE notes ("
        " id INTEGER PRIMARY KEY,"
        " owner_id INTEGER NOT NULL,"
        " content TEXT NOT NULL"
        ")"
    )
    # Passwords are random and undocumented -- nobody can log in with a
    # REAL password. The only way in is the SQL injection in login().
    conn.execute(
        "INSERT INTO users (id, username, password, role) VALUES (?, ?, ?, ?)",
        (1, "alice", uuid.uuid4().hex, "user"),
    )
    conn.execute(
        "INSERT INTO users (id, username, password, role) VALUES (?, ?, ?, ?)",
        (2, "admin", uuid.uuid4().hex, "admin"),
    )
    conn.execute(
        "INSERT INTO notes (id, owner_id, content) VALUES (?, ?, ?)",
        (1, 1, "Reminder: renew the lab TLS cert before it expires. Nothing "
               "secret here."),
    )
    conn.execute(
        "INSERT INTO notes (id, owner_id, content) VALUES (?, ?, ?)",
        (2, 2, "Admin-only: rotate the DB service-account credentials this "
               "week. CTF{idor-reaches-admins-private-note}"),
    )
    conn.commit()
    conn.close()


def db():
    return sqlite3.connect(DB_PATH)


# session_id -> username. In-memory, like Day 4's target -- no expiry, no
# rotation; not the point of this lab.
SESSIONS = {}


def current_user():
    sid = request.cookies.get("sid")
    return SESSIONS.get(sid)


@app.route("/")
def index():
    return (
        "<h1>cyberlab-day12-target</h1>"
        "<p>Routes: GET/POST /login, GET /notes/&lt;id&gt;, GET /api/whoami</p>"
        "<p>Known accounts: <code>alice</code> (role: user), "
        "<code>admin</code> (role: admin). Nobody's real password is "
        "documented anywhere -- find another way in.</p>"
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

    # --- deliberately vulnerable: raw string formatting, no
    # parameterization, no escaping at all. This is Day 8's injection
    # class, live. -------------------------------------------------------
    query = (
        "SELECT id, username, role FROM users "
        f"WHERE username = '{username}' AND password = '{password}'"
    )
    conn = db()
    try:
        row = conn.execute(query).fetchone()
    except sqlite3.Error as exc:
        conn.close()
        return jsonify({"error": "query failed", "detail": str(exc)}), 400
    conn.close()

    if row is None:
        return jsonify({"error": "invalid username or password"}), 401

    _user_id, real_username, _role = row
    sid = str(uuid.uuid4())
    SESSIONS[sid] = real_username
    resp = make_response(jsonify({
        "message": f"Login successful. Welcome, {real_username}! "
                   "(No real password was ever checked to get here.)",
        "flag": "CTF{sqli-auth-bypass-no-password-needed}",
    }))
    resp.set_cookie("sid", sid)
    return resp


@app.route("/api/whoami")
def whoami():
    user = current_user()
    if user is None:
        return jsonify({"error": "not logged in"}), 401
    return jsonify({"user": user})


@app.route("/notes/<int:note_id>")
def notes(note_id):
    user = current_user()
    if user is None:
        return jsonify({"error": "not logged in"}), 401
    # --- deliberately vulnerable: broken access control / IDOR. No check
    # at all that `note_id`'s owner matches the logged-in session's own
    # user. Day 9's access-control class, live. -------------------------
    conn = db()
    row = conn.execute(
        "SELECT owner_id, content FROM notes WHERE id = ?", (note_id,)
    ).fetchone()
    conn.close()
    if row is None:
        return jsonify({"error": "no such note"}), 404
    _owner_id, content = row
    return jsonify({"note_id": note_id, "content": content})


init_db()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

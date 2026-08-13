#!/usr/bin/env python3
"""Day 4 target: a deliberately weak auth app, two vulnerabilities on purpose.

1. POST /login -- a classic HTML-form login with NO rate limiting and NO
   account lockout in the baseline. Any number of guesses, from any client,
   at any speed, are accepted -- exactly what makes an online password
   brute-force attack (hydra) practical against this endpoint. It also
   REUSES a client-supplied session cookie instead of always issuing a
   fresh one on successful login -- a session-fixation bug, described in
   content/day04-auth.md's Concept section (not separately hands-on
   attacked by this lab's Attack section, named honestly rather than
   glossed over).

2. POST /api/token + GET /api/admin -- a JSON API that issues a real,
   standards-shaped compact JWT (header.payload.signature, all base64url,
   HS256) signed with a short, guessable secret (JWT_SECRET below).
   Anyone who FINDS that secret can forge a NEW token claiming any role
   they want, including "admin", without ever knowing a real admin's
   password.

Nothing here uses a third-party JWT library on purpose -- the encode/
decode logic below is the ~20 lines of real HMAC-SHA256 + JSON + base64url
work a compact JWT actually is, written out so it's inspectable, not a
black box. verify_jwt() also hardcodes HS256 rather than trusting an
"alg" field read out of the token itself -- so this specific target is
NOT vulnerable to the historical alg:none forgery trick (see
content/day04-auth.md Concept + Drill 3 for why that trick works against
code that DOES trust the token's own alg field).
"""
import base64
import hashlib
import hmac
import json
import time
import uuid

from flask import Flask, request, jsonify, make_response

app = Flask(__name__)

# --- deliberately weak: a short, dictionary-word secret -------------------
# Change this (Defense Lab, Defense 2) to a long random value to see the
# JWT-forging attack stop working against the exact same verify_jwt() code.
JWT_SECRET = "cyberlab"

USERS = {
    "admin": {"password": "letmein", "role": "user"},
}

# In-memory session store: session_id -> username. No expiry, no rotation
# on login -- see the session-fixation note above and in the content file.
SESSIONS = {}

# Failed-login tracking. Populated but NEVER CHECKED in the baseline lab
# on purpose -- Defense Lab, Defense 1 asks you to uncomment the check
# inside login() below that actually enforces a lockout, then rebuild.
FAILED_ATTEMPTS = {}
LOCKOUT_THRESHOLD = 3
LOCKOUT_WINDOW_SECONDS = 60


def b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def b64url_decode(s: str) -> bytes:
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def make_jwt(payload: dict, secret: str = JWT_SECRET) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    header_b64 = b64url(json.dumps(header, separators=(",", ":")).encode())
    payload_b64 = b64url(json.dumps(payload, separators=(",", ":")).encode())
    signing_input = f"{header_b64}.{payload_b64}".encode()
    signature = hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()
    return f"{header_b64}.{payload_b64}.{b64url(signature)}"


def verify_jwt(token: str, secret: str = JWT_SECRET):
    """Verify a compact JWT. Deliberately hardcodes HS256 -- it never reads
    the token's own "alg" header to decide how to verify it, so alg:none
    forgery (Drill 3) has no foothold against this specific implementation."""
    try:
        header_b64, payload_b64, sig_b64 = token.split(".")
    except ValueError:
        return None
    signing_input = f"{header_b64}.{payload_b64}".encode()
    expected_sig = hmac.new(secret.encode(), signing_input, hashlib.sha256).digest()
    try:
        given_sig = b64url_decode(sig_b64)
    except Exception:
        return None
    if not hmac.compare_digest(expected_sig, given_sig):
        return None
    payload = json.loads(b64url_decode(payload_b64))
    if payload.get("exp", 0) < time.time():
        return None
    return payload


@app.route("/")
def index():
    return (
        "<h1>cyberlab-day04-target</h1>"
        "<p>Routes: GET/POST /login, POST /api/token, GET /api/whoami, "
        "GET /api/admin</p>"
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

    # --- Defense Lab, Defense 1: uncomment to enforce a lockout ----------
    # now = time.time()
    # recent = [t for t in FAILED_ATTEMPTS.get(username, [])
    #           if now - t < LOCKOUT_WINDOW_SECONDS]
    # FAILED_ATTEMPTS[username] = recent
    # if len(recent) >= LOCKOUT_THRESHOLD:
    #     return "Account locked: too many failed attempts. Try again later.", 429
    # -----------------------------------------------------------------------

    user = USERS.get(username)
    if user is None or user["password"] != password:
        FAILED_ATTEMPTS.setdefault(username, []).append(time.time())
        return "Invalid username or password.", 200

    # Session fixation, on purpose: if the client already presented a
    # session cookie, REUSE it instead of issuing a fresh one now that
    # login succeeded. See content/day04-auth.md Concept section.
    sid = request.cookies.get("session") or str(uuid.uuid4())
    SESSIONS[sid] = username
    resp = make_response(f"Login successful. Welcome, {username}!")
    resp.set_cookie("session", sid)
    return resp


@app.route("/api/token", methods=["POST"])
def api_token():
    data = request.get_json(silent=True) or {}
    username = data.get("username", "")
    password = data.get("password", "")
    user = USERS.get(username)
    if user is None or user["password"] != password:
        return jsonify({"error": "invalid credentials"}), 401
    token = make_jwt({
        "sub": username,
        "role": user["role"],
        "exp": int(time.time()) + 3600,
    })
    return jsonify({"token": token})


def _bearer_token():
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    return auth[len("Bearer "):]


@app.route("/api/whoami")
def api_whoami():
    token = _bearer_token()
    if not token:
        return jsonify({"error": "missing bearer token"}), 401
    payload = verify_jwt(token)
    if payload is None:
        return jsonify({"error": "invalid or expired token"}), 401
    return jsonify(payload)


@app.route("/api/admin")
def api_admin():
    token = _bearer_token()
    if not token:
        return jsonify({"error": "missing bearer token"}), 401
    payload = verify_jwt(token)
    if payload is None:
        return jsonify({"error": "invalid or expired token"}), 401
    if payload.get("role") != "admin":
        return jsonify({"error": "admin role required"}), 403
    return jsonify({"flag": "CTF{jwt-forged-with-a-guessable-secret}"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

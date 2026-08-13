#!/usr/bin/env python3
"""Capstone fake-imds: simulates EC2 instance metadata at the real,
literal link-local address 169.254.169.254 (see docker-compose.yml's
`imds` network -- this container is the ONLY thing on it besides
`webapp`). Every credential value returned here is synthetic and clearly
labeled fake; nothing here ever talks to real AWS.

IMDS_MODE controls the exact real-world behavior being simulated:

  IMDS_MODE=v1 (default -- Day 20 baseline, vulnerable): every
    /latest/meta-data/... GET is served unconditionally, no token
    required. This matches real IMDSv1, and is why a plain SSRF (one
    attacker-controlled URL, no attacker-controlled headers) is enough to
    steal role credentials from a real EC2 instance that hasn't enforced
    IMDSv2.

  IMDS_MODE=v2 (Day 21 hardening): the SAME /latest/meta-data/... GETs
    now require a valid `X-aws-ec2-metadata-token` header, obtainable
    only via a separate PUT to /latest/api/token. This matches real
    IMDSv2 enforcement (`aws ec2 modify-instance-metadata-options
    --http-tokens required`). The webapp SSRF endpoint (app.py's
    /admin/fetch) only ever issues a plain GET with no custom headers --
    it cannot also perform the PUT+token dance -- so flipping this one
    env var breaks the Day 20 metadata-theft payload with ZERO changes
    to webapp's code at all. That is IMDSv2's actual real-world value:
    it does not "fix" a general SSRF, it makes a generic GET-only SSRF
    insufficient to reach credentials.
"""
import os
import secrets
import time

from flask import Flask, Response, jsonify, request

app = Flask(__name__)

IMDS_MODE = os.environ.get("IMDS_MODE", "v1")
ROLE_NAME = os.environ.get("FAKE_ROLE_NAME", "lab-capstone-role")
ACCESS_KEY_ID = os.environ.get("FAKE_ACCESS_KEY_ID", "AKIA_FAKE_CAPSTONE_LAB01")
SECRET_ACCESS_KEY = os.environ.get(
    "FAKE_SECRET_ACCESS_KEY", "FAKEfakeSecretForLabPurposesOnly1234567890"
)
SESSION_TOKEN = os.environ.get("FAKE_SESSION_TOKEN", "FAKE-SESSION-TOKEN-CAPSTONE")

TOKENS = {}  # session-token -> expiry epoch (IMDSv2 mode only)


def _valid_session_token() -> bool:
    if IMDS_MODE != "v2":
        return True
    tok = request.headers.get("X-aws-ec2-metadata-token")
    if not tok:
        return False
    expiry = TOKENS.get(tok)
    return expiry is not None and expiry > time.time()


def _unauthorized():
    return Response(
        "401 Unauthorized -- a valid IMDSv2 session token is required "
        "(PUT /latest/api/token first, then send it back as "
        "X-aws-ec2-metadata-token). See content/day21-capstone-defend.md.\n",
        status=401,
    )


@app.route("/")
def index():
    return (
        "cyberlab-capstone fake-imds -- simulated EC2 instance metadata, "
        f"authorized-sandbox-only. IMDS_MODE={IMDS_MODE}\n"
    )


@app.route("/latest/api/token", methods=["PUT"])
def issue_token():
    ttl = int(request.headers.get("X-aws-ec2-metadata-token-ttl-seconds", "21600"))
    ttl = max(1, min(ttl, 21600))
    token = secrets.token_hex(20)
    TOKENS[token] = time.time() + ttl
    return Response(token, mimetype="text/plain")


@app.route("/latest/meta-data/iam/security-credentials/")
def list_roles():
    if not _valid_session_token():
        return _unauthorized()
    return Response(ROLE_NAME + "\n", mimetype="text/plain")


@app.route("/latest/meta-data/iam/security-credentials/<role_name>")
def role_credentials(role_name):
    if not _valid_session_token():
        return _unauthorized()
    if role_name != ROLE_NAME:
        return Response("404 - no such role\n", status=404)
    return jsonify(
        {
            "Code": "Success",
            "LastUpdated": "2026-01-01T00:00:00Z",
            "Type": "AWS-HMAC",
            "AccessKeyId": ACCESS_KEY_ID,
            "SecretAccessKey": SECRET_ACCESS_KEY,
            "Token": SESSION_TOKEN,
            "Expiration": "2099-01-01T00:00:00Z",
        }
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)

"""
Tiny lab app for the AWS Security Mastery workload.

This app is DELIBERATELY VULNERABLE BY DESIGN. It exists so the Day 8/11
lab has a real server-side-request-forgery (SSRF) endpoint to exploit
against the learner's OWN deployed workload — never point this at anything
you do not own. Do not deploy this app outside this learning-path context.

Endpoints:
  GET /            health check (used by the ALB target group)
  GET /fetch?url=  server-side fetch of an arbitrary caller-supplied URL,
                    returned verbatim. This is the SSRF endpoint. On ECS
                    Fargate, an attacker can point `url` at the task
                    metadata endpoint (read from AWS_CONTAINER_CREDENTIALS_
                    RELATIVE_URI) to steal the task role's temporary
                    credentials — the Day 8/11 lesson.
  GET /whoami       returns the task role's STS caller identity, so the
                    break->harden signal (before/after Day 1 tightening,
                    before/after Day 8/11) is directly observable.
"""

import os

import boto3
import requests
from flask import Flask, jsonify, request

app = Flask(__name__)

APP_BUCKET = os.environ.get("APP_BUCKET", "")
APP_TABLE = os.environ.get("APP_TABLE", "")
APP_SECRET_ARN = os.environ.get("APP_SECRET_ARN", "")


@app.get("/")
def health():
    return "ok", 200


@app.get("/fetch")
def fetch():
    """Deliberately vulnerable: fetches whatever URL the caller supplies,
    with no allow-list, no scheme restriction, and no block on link-local
    addresses. This is the SSRF bug the Day 8/11 lab exploits."""
    url = request.args.get("url")
    if not url:
        return jsonify(error="pass ?url=<target>"), 400
    try:
        resp = requests.get(url, timeout=5)
        return (resp.text, resp.status_code)
    except requests.RequestException as exc:
        return jsonify(error=str(exc)), 502


@app.get("/whoami")
def whoami():
    """Returns the identity the task role currently resolves to — useful to
    show, before and after a fix, exactly which credentials the app (and
    therefore an SSRF attacker) is holding."""
    sts = boto3.client("sts")
    identity = sts.get_caller_identity()
    return jsonify(
        account=identity.get("Account"),
        arn=identity.get("Arn"),
        app_bucket=APP_BUCKET,
        app_table=APP_TABLE,
        app_secret_arn=APP_SECRET_ARN,
    )


if __name__ == "__main__":
    # Flask's built-in server is fine for this lab's traffic level.
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))

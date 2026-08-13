#!/usr/bin/env python3
"""Capstone fake-s3: simulates a single internet-reachable AWS S3-style
bucket. Deliberately reachable directly from `attacker` (see
../docker-compose.yml) -- real S3 is reachable from anywhere on the
internet too; what protects a real object is the credential check, not
network placement. This is the payoff step: once you hold the (fake)
credentials fake-imds handed out, use them here exactly like you would
use real stolen AWS credentials against the real S3 API -- no further
pivot, no further SSRF, just the right header.
"""
import os

from flask import Flask, Response, request

app = Flask(__name__)

ACCESS_KEY_ID = os.environ.get("FAKE_ACCESS_KEY_ID", "AKIA_FAKE_CAPSTONE_LAB01")
BUCKET = os.environ.get("FAKE_BUCKET", "lab-capstone-bucket")

OBJECTS = {
    "confidential/findings.txt": (
        "Q3 internal pentest findings -- CONFIDENTIAL, DO NOT DISTRIBUTE\n"
        "CTF{capstone-cloud-creds-stolen-via-ssrf-imdsv1}\n"
    ),
}


@app.route("/")
def index():
    return "cyberlab-capstone fake-s3 -- simulated S3 endpoint, authorized-sandbox-only\n"


@app.route("/fake-s3/<bucket>/<path:key>")
def get_object(bucket, key):
    if bucket != BUCKET:
        return Response("404 - NoSuchBucket\n", status=404)
    supplied_key = request.headers.get("X-Amz-Access-Key-Id")
    if supplied_key != ACCESS_KEY_ID:
        return Response("403 - AccessDenied: invalid or missing credentials\n", status=403)
    body = OBJECTS.get(key)
    if body is None:
        return Response("404 - NoSuchKey\n", status=404)
    return Response(body, mimetype="text/plain")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)

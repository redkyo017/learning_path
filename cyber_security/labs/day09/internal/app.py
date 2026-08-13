#!/usr/bin/env python3
"""Day 9 internal target: a small, dependency-free HTTP service that plays the
role of "the thing SSRF is dangerous *because* it exists" -- a service an
attacker can never reach directly (it is not on the shared `cyberlab`
network `attacker` lives on; see ../docker-compose.yml), but that the *app*
(juiceshop, dual-homed onto both networks) can reach fine, since it lives on
the same private `day09-app` network.

The address this container is pinned to is not arbitrary: 169.254.169.254 is
the REAL link-local address every major cloud provider (AWS, GCP, Azure)
uses for their Instance Metadata Service (IMDS) -- the thing Day 15's SSRF
attack steals real temporary IAM credentials from, against a real AWS
sandbox. This container is a safe, local stand-in for that exact address and
that exact category of target, so today's pivot technique -- reach an
address you have no direct route to, by making a *different*, network-
privileged process fetch it for you -- transfers directly to Day 15 with
nothing new to learn about the SSRF mechanic itself, only the destination
changes from "toy flag" to "real cloud credentials."

Routes:
  GET /                                                        -- identity banner
  GET /flag                                                     -- the toy CTF flag (simplest possible proof SSRF reached here)
  GET /latest/meta-data/iam/security-credentials/               -- lists a fake role name (mirrors real IMDSv1 shape)
  GET /latest/meta-data/iam/security-credentials/<role>         -- fake temporary credentials for that role

None of this requires authentication to answer -- exactly like real IMDSv1
(no token header required), which is the actual, historically real defense
gap Day 15's "enforce IMDSv2" fix closes. This target does not implement
that fix; it is deliberately IMDSv1-shaped throughout, since today's job is
demonstrating the SSRF *pivot*, not the metadata-service hardening itself
(that is Day 15's Defense section).
"""
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

ROLE_NAME = "cyberlab-day09-role"

FAKE_CREDENTIALS = {
    "Code": "Success",
    "LastUpdated": "2026-08-12T00:00:00Z",
    "Type": "AWS-HMAC",
    "AccessKeyId": "FAKEAKIACYBERLAB0DAY09",
    "SecretAccessKey": "FAKEsecretDoNotUseThisIsALabValue1234567890",
    "Token": "FAKEtokenThisIsNotARealCredentialLabOnly==",
    "Expiration": "2026-08-13T00:00:00Z",
}


class Handler(BaseHTTPRequestHandler):
    server_version = "cyberlab-day09-internal/1.0"

    def _send(self, status, body_bytes, content_type="text/plain"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body_bytes)))
        self.end_headers()
        self.wfile.write(body_bytes)

    def do_GET(self):
        path = self.path.rstrip("/")

        if path == "":
            self._send(
                200,
                b"cyberlab-day09-internal -- reachable ONLY from the day09-app "
                b"network, not from the attacker container directly. If you can "
                b"read this, something on THIS network fetched it for you.",
            )
            return

        if path == "/flag":
            self._send(
                200,
                json.dumps(
                    {"flag": "CTF{ssrf-reached-the-internal-only-service}"}
                ).encode(),
                "application/json",
            )
            return

        if path == "/latest/meta-data/iam/security-credentials":
            self._send(200, (ROLE_NAME + "\n").encode())
            return

        if path == f"/latest/meta-data/iam/security-credentials/{ROLE_NAME}":
            self._send(200, json.dumps(FAKE_CREDENTIALS).encode(), "application/json")
            return

        self._send(404, b"not found")

    def log_message(self, fmt, *args):
        # Keep container logs readable during the lab; default BaseHTTPRequestHandler
        # logging is fine as-is, this override just documents that logging is
        # intentionally left on (helps confirm, from `docker compose logs internal`,
        # that a request from juiceshop actually arrived).
        super().log_message(fmt, *args)


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", 80), Handler).serve_forever()

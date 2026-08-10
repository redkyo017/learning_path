#!/usr/bin/env bash
set -euo pipefail
#
# Capstone 09 -- reproduction asset. Serves the REAL example.local cert
# from a plain openssl s_server -- no OCSP stapling configured at all
# (s_server's default; there is no -status_file passed) -- then queries
# it with -status, the flag that asks the peer to staple an OCSP response.
#
# There is no real OCSP responder anywhere in this lab (see Day 5's
# theory), so this does not simulate an actual revocation -- it isolates
# the SOFT-FAIL blind spot itself: a handshake completing successfully
# while zero revocation information was ever exchanged.
#
# Run from labs/:
#   docker compose run --rm toolbox bash /work/drills/capstone/capstone-09/repro.sh

if [ ! -f /work/ca/intermediate/certs/example.local.cert.pem ]; then
  echo "ERROR: run Day 2's guided lab first (need example.local.cert.pem)." >&2
  exit 1
fi

openssl s_server -accept 8600 \
    -cert /work/ca/intermediate/certs/example.local.cert.pem \
    -key  /work/ca/intermediate/private/example.local.key.pem \
    -naccept 1 -quiet -www &
SERVER_PID=$!
sleep 1

openssl s_client -connect 127.0.0.1:8600 -servername example.local \
    -CAfile /work/ca/intermediate/certs/ca-chain.cert.pem \
    -status </dev/null 2>/dev/null \
    | grep -E "OCSP|Verify return code"

wait "${SERVER_PID}" || true

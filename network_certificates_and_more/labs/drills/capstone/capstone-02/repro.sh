#!/usr/bin/env bash
set -euo pipefail
#
# Capstone 02 -- reproduction asset. Serves the REAL example.local cert
# (Day 2), but the client connects using a DIFFERENT name that is not in
# that cert's SAN list.
#
# Run from labs/:
#   docker compose run --rm toolbox bash /work/drills/capstone/capstone-02/repro.sh

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

curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --connect-to portal.example.local:8600:127.0.0.1:8600 \
     https://portal.example.local:8600/ || true

wait "${SERVER_PID}" || true

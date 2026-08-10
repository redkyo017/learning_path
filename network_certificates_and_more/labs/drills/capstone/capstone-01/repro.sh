#!/usr/bin/env bash
set -euo pipefail
#
# Capstone 01 -- reproduction asset. Issues a fresh leaf from the REAL
# intermediate CA, serves ONLY that leaf (no chain), and connects with a
# CA file that only has the ROOT -- not the intermediate either.
#
# Run from labs/:
#   docker compose run --rm toolbox bash /work/drills/capstone/capstone-01/repro.sh

if [ ! -f /work/ca/intermediate/certs/intermediate.cert.pem ]; then
  echo "ERROR: run Day 2's guided lab first (need ca/intermediate/)." >&2
  exit 1
fi

bash /work/ca/issue-server-cert.sh reports.local reports.local >/dev/null

openssl s_server -accept 8600 \
    -cert /work/ca/intermediate/certs/reports.local.cert.pem \
    -key  /work/ca/intermediate/private/reports.local.key.pem \
    -naccept 1 -quiet -www &
SERVER_PID=$!
sleep 1

curl --cacert /work/ca/root/certs/ca.cert.pem \
     --connect-to reports.local:8600:127.0.0.1:8600 \
     https://reports.local:8600/ || true

wait "${SERVER_PID}" || true

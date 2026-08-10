#!/usr/bin/env bash
set -euo pipefail
#
# Capstone 05 -- reproduction asset. Server is pinned to TLS 1.2 exactly
# (so cipher-suite naming's key-type coupling from Day 3 actually applies)
# and presents only an RSA-keyed certificate (example.local). Client
# insists on an ECDHE-ECDSA-* suite family, which requires an ECDSA
# certificate the server does not have.
#
# Run from labs/:
#   docker compose run --rm toolbox bash /work/drills/capstone/capstone-05/repro.sh

if [ ! -f /work/ca/intermediate/certs/example.local.cert.pem ]; then
  echo "ERROR: run Day 2's guided lab first (need example.local.cert.pem)." >&2
  exit 1
fi

openssl s_server -accept 8600 -tls1_2 \
    -cert /work/ca/intermediate/certs/example.local.cert.pem \
    -key  /work/ca/intermediate/private/example.local.key.pem \
    -naccept 1 -quiet -www &
SERVER_PID=$!
sleep 1

curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --connect-to example.local:8600:127.0.0.1:8600 \
     --tlsv1.2 --tls-max 1.2 \
     --ciphers ECDHE-ECDSA-AES128-GCM-SHA256 \
     https://example.local:8600/ || true

wait "${SERVER_PID}" || true

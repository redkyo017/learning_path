#!/usr/bin/env bash
set -euo pipefail
#
# Capstone 04 -- reproduction asset. Server floor is raised to TLS 1.3
# ONLY (everything below 1.3 explicitly disabled). Client is an older
# integration capped at TLS 1.2 maximum. This is drill-09's mechanism run
# in the opposite direction: a modern, hardened server against a legacy
# client, instead of a legacy server against a modern client.
#
# Run from labs/:
#   docker compose run --rm toolbox bash /work/drills/capstone/capstone-04/repro.sh

if [ ! -f /work/ca/intermediate/certs/example.local.cert.pem ]; then
  echo "ERROR: run Day 2's guided lab first (need example.local.cert.pem)." >&2
  exit 1
fi

openssl s_server -accept 8600 \
    -cert /work/ca/intermediate/certs/example.local.cert.pem \
    -key  /work/ca/intermediate/private/example.local.key.pem \
    -no_ssl3 -no_tls1 -no_tls1_1 -no_tls1_2 -naccept 1 -quiet -www &
SERVER_PID=$!
sleep 1

curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --connect-to example.local:8600:127.0.0.1:8600 \
     --tls-max 1.2 \
     https://example.local:8600/ || true

wait "${SERVER_PID}" || true

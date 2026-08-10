#!/usr/bin/env bash
# Drill 09 — minimal reproduction asset.
#
# Starts a throwaway TLS test server, on its own port, that refuses
# anything below TLS 1.2 (a floor of "1.2 and up" — NOT the same as
# openssl's own -tls1_2 flag, which would pin it to *exactly* 1.2).
# Then immediately drives a client at it that is capped at TLS 1.1 max.
#
# Both processes run inside the SAME toolbox container, talking over its
# own loopback — this does not touch nginx, docker-compose.yml, or any
# other day's service config.
#
# Run from labs/:
#   docker compose run --rm toolbox bash /work/drills/drill-09/repro.sh
set -euo pipefail

openssl s_server -accept 8444 \
  -cert /work/ca/intermediate/certs/example.local.cert.pem \
  -key  /work/ca/intermediate/private/example.local.key.pem \
  -no_ssl3 -no_tls1 -no_tls1_1 -naccept 1 -quiet &
SERVER_PID=$!

sleep 1

curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --resolve example.local:8444:127.0.0.1 \
     --tlsv1.0 --tls-max 1.1 \
     https://example.local:8444/ || true

wait "${SERVER_PID}" || true

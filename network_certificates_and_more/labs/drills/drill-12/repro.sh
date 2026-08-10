#!/usr/bin/env bash
# Drill 12 — minimal reproduction asset.
#
# Starts a throwaway TLS test server, on its own port, configured to only
# accept the ALPN protocol "h2". The client then offers only "http/1.1".
# Per RFC 7301 section 3.2, when a server has ALPN protocols configured
# and none of them appear in the client's offered list, the server MUST
# send a fatal no_application_protocol alert and abort the handshake.
#
# Both processes run inside the SAME toolbox container, talking over its
# own loopback — this does not touch nginx, docker-compose.yml, or any
# other day's service config.
#
# Run from labs/:
#   docker compose run --rm toolbox bash /work/drills/drill-12/repro.sh
set -euo pipefail

openssl s_server -accept 8445 \
  -cert /work/ca/intermediate/certs/example.local.cert.pem \
  -key  /work/ca/intermediate/private/example.local.key.pem \
  -alpn h2 -naccept 1 -quiet &
SERVER_PID=$!

sleep 1

openssl s_client -connect 127.0.0.1:8445 -servername example.local \
    -CAfile /work/ca/intermediate/certs/ca-chain.cert.pem \
    -alpn http/1.1 </dev/null || true

wait "${SERVER_PID}" || true

#!/usr/bin/env bash
set -euo pipefail
#
# Capstone 10 -- reproduction asset. Issues secure-api.local, records its
# pubkey pin (as if a client had hardcoded it months ago), then issues
# secure-api.local AGAIN -- a routine, legitimate key rotation, not an
# attack -- and shows the OLD pin failing against the NEW, equally valid
# certificate.
#
# Uses a dedicated CN (secure-api.local) so it never touches
# example.local, client01, or any other day's shared cert state.
#
# Run from labs/:
#   docker compose run --rm toolbox bash /work/drills/capstone/capstone-10/repro.sh

if [ ! -f /work/ca/intermediate/certs/intermediate.cert.pem ]; then
  echo "ERROR: run Day 2's guided lab first (need ca/intermediate/)." >&2
  exit 1
fi

bash /work/ca/issue-server-cert.sh secure-api.local secure-api.local >/dev/null

OLD_PIN=$(openssl x509 -in /work/ca/intermediate/certs/secure-api.local.cert.pem -pubkey -noout \
    | openssl pkey -pubin -outform der \
    | openssl dgst -sha256 -binary \
    | base64)
echo "Pin recorded months ago by a monitoring dashboard: sha256//${OLD_PIN}"

# Routine rotation: issue-server-cert.sh generates a brand-new keypair
# every time it's called for a CN (see its own header comment) -- this is
# a normal renewal, nobody attacked anything.
bash /work/ca/issue-server-cert.sh secure-api.local secure-api.local >/dev/null

openssl s_server -accept 8600 \
    -cert /work/ca/intermediate/certs/secure-api.local.cert.pem \
    -key  /work/ca/intermediate/private/secure-api.local.key.pem \
    -naccept 1 -quiet -www &
SERVER_PID=$!
sleep 1

curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --pinnedpubkey "sha256//${OLD_PIN}" \
     --connect-to secure-api.local:8600:127.0.0.1:8600 \
     https://secure-api.local:8600/ || true

wait "${SERVER_PID}" || true

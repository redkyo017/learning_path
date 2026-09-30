#!/usr/bin/env bash
set -euo pipefail
#
# Capstone 06 -- reproduction asset. A throwaway "imposter" CA (NOT ca/)
# mints a lookalike client01 identity -- same CN, different issuer
# entirely. The server (openssl s_server, standing in for Day 4's mTLS
# nginx) requires and verifies client certs against the REAL ca-chain.
# -verify_return_error makes s_server abort the handshake on a verify
# error; without it, s_server only logs the error and serves the page.
#
# Run from labs/:
#   docker compose run --rm toolbox bash /work/drills/capstone/capstone-06/repro.sh

if [ ! -f /work/ca/intermediate/certs/example.local.cert.pem ]; then
  echo "ERROR: run Day 2's guided lab first (need example.local.cert.pem)." >&2
  exit 1
fi

WD=/work/drills/capstone/capstone-06/tmp
mkdir -p "${WD}"
cd "${WD}"

openssl genrsa -out imposter-ca.key.pem 4096 2>/dev/null
openssl req -x509 -new -key imposter-ca.key.pem -sha256 -days 3650 -batch \
    -subj "/O=Definitely Not TLS Mastery Lab/CN=Imposter Testing CA" \
    -out imposter-ca.cert.pem

openssl genrsa -out client01-imposter.key.pem 2048 2>/dev/null
openssl req -new -key client01-imposter.key.pem -batch \
    -subj "/O=Definitely Not TLS Mastery Lab/CN=client01" \
    -out client01-imposter.csr.pem
# clientAuth EKU, like a real client cert, so the ONLY thing wrong with this
# identity is who signed it.
printf 'basicConstraints=CA:FALSE\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=clientAuth\n' \
    > client01-imposter.ext
openssl x509 -req -in client01-imposter.csr.pem \
    -CA imposter-ca.cert.pem -CAkey imposter-ca.key.pem -CAcreateserial \
    -days 375 -sha256 -extfile client01-imposter.ext \
    -out client01-imposter.cert.pem

openssl s_server -accept 8600 \
    -cert /work/ca/intermediate/certs/example.local.cert.pem \
    -key  /work/ca/intermediate/private/example.local.key.pem \
    -CAfile /work/ca/intermediate/certs/ca-chain.cert.pem \
    -Verify 1 -verify_return_error -naccept 1 -quiet -www &
SERVER_PID=$!
sleep 1

curl -sS --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --cert "${WD}/client01-imposter.cert.pem" \
     --key  "${WD}/client01-imposter.key.pem" \
     --connect-to example.local:8600:127.0.0.1:8600 \
     https://example.local:8600/ || true

wait "${SERVER_PID}" || true

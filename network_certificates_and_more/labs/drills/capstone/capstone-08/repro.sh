#!/usr/bin/env bash
set -euo pipefail
#
# Capstone 08 -- reproduction asset. Builds a rogue root CA and a rogue
# leaf for a NEW host (vault.internal.local -- deliberately not
# example.local, so this doesn't read as a rerun of the guided attack lab
# in labs/attack/), installs the rogue root into THIS container's trust
# store, then connects with curl WITHOUT any --cacert at all.
#
# Everything runs in one container invocation -- see labs/attack/README.md's
# "Why everything has to run in ONE container invocation" for why.
#
# Run from labs/:
#   docker compose run --rm toolbox bash /work/drills/capstone/capstone-08/repro.sh

WD=/work/drills/capstone/capstone-08/tmp
mkdir -p "${WD}"
cd "${WD}"

openssl genrsa -out rogue-root.key.pem 4096 2>/dev/null
openssl req -x509 -new -key rogue-root.key.pem -sha256 -days 3650 -batch \
    -subj "/O=SecureVault Trust Services/CN=SecureVault Trust Root G2" \
    -out rogue-root.cert.pem

openssl genrsa -out vault.internal.local.key.pem 2048 2>/dev/null
openssl req -new -key vault.internal.local.key.pem -batch \
    -subj "/O=SecureVault Trust Services/CN=vault.internal.local" \
    -out vault.internal.local.csr.pem
cat > ext.cnf <<'EOF'
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:vault.internal.local
EOF
openssl x509 -req -in vault.internal.local.csr.pem \
    -CA rogue-root.cert.pem -CAkey rogue-root.key.pem -CAcreateserial \
    -days 375 -sha256 -extfile ext.cnf -out vault.internal.local.cert.pem

cp rogue-root.cert.pem /usr/local/share/ca-certificates/secure-vault-root.crt
update-ca-certificates >/dev/null

openssl s_server -accept 8600 \
    -cert vault.internal.local.cert.pem -key vault.internal.local.key.pem \
    -naccept 1 -quiet -www &
SERVER_PID=$!
sleep 1

curl -v --connect-to vault.internal.local:8600:127.0.0.1:8600 \
     https://vault.internal.local:8600/ 2>&1 \
     | grep -E "subject:|issuer:|SSL certificate verify (ok|result)|HTTP/"

wait "${SERVER_PID}" || true

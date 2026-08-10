#!/usr/bin/env bash
set -euo pipefail
#
# Day 6 — guided attack lab: rogue-CA MITM, then the pinning defense.
#
# Run from labs/:
#   docker compose run --rm toolbox bash /work/attack/rogue-mitm-demo.sh
#
# This must run as ONE container invocation (see README.md's "Why
# everything has to run in ONE container invocation") — do not try to
# split these steps across separate `docker compose run --rm` calls, the
# installed rogue root would not survive between them.
#
# Requires Day 2's CA + example.local cert to already exist. This script
# reads ca/intermediate/certs/example.local.cert.pem ONLY to extract its
# public key for the defense step (step 6) — it never modifies your real
# CA or your real example.local key/cert.
#
# NOTE: authored without a live Docker session available (see the task
# report). Every command below is reasoned through against openssl's and
# curl's documented behavior, but treat the first live run as your own
# verification pass, exactly as Day 5 asked you to.

if [ ! -f /work/ca/intermediate/certs/example.local.cert.pem ]; then
  echo "ERROR: run Day 2's guided lab first (need ca/intermediate/certs/example.local.cert.pem)." >&2
  exit 1
fi

WORKDIR=/work/attack/rogue
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

ATTACK_PORT=8543

echo "==> [1/6] Building a rogue root CA -- NOT ca/, an entirely separate keypair and root."
openssl genrsa -out rogue-root.key.pem 4096 2>/dev/null
openssl req -x509 -new -key rogue-root.key.pem -sha256 -days 3650 -batch \
    -subj "/C=XX/O=Rogue Attacker CA (attack lab, NOT real)/CN=Rogue Attacker Root CA" \
    -out rogue-root.cert.pem

echo "==> [2/6] Issuing a rogue leaf for example.local, signed by the rogue root."
echo "    Correct name, correct SAN -- checks 1-3 will pass perfectly against THIS root."
openssl genrsa -out rogue-example.local.key.pem 2048 2>/dev/null
openssl req -new -key rogue-example.local.key.pem -batch \
    -subj "/C=XX/O=Rogue Attacker CA (attack lab, NOT real)/CN=example.local" \
    -out rogue-example.local.csr.pem
cat > rogue-example.local.ext.cnf <<'EOF'
basicConstraints=CA:FALSE
keyUsage=digitalSignature,keyEncipherment
extendedKeyUsage=serverAuth
subjectAltName=DNS:example.local
EOF
openssl x509 -req -in rogue-example.local.csr.pem \
    -CA rogue-root.cert.pem -CAkey rogue-root.key.pem -CAcreateserial \
    -days 375 -sha256 -extfile rogue-example.local.ext.cnf \
    -out rogue-example.local.cert.pem

echo "==> [3/6] Presenting the rogue cert -- openssl s_server plays the attacker's endpoint."
openssl s_server -accept "${ATTACK_PORT}" \
    -cert rogue-example.local.cert.pem -key rogue-example.local.key.pem \
    -naccept 3 -quiet -www &
SERVER_PID=$!
sleep 1

echo "==> [4/6] BEFORE: curl with this container's ORDINARY trust store (rogue root not installed yet)."
echo "    --connect-to redirects example.local:8443 to the rogue s_server on 127.0.0.1:${ATTACK_PORT}"
echo "    -- SNI and Host still say example.local, exactly as a real DNS-hijack MITM would look."
curl --connect-to example.local:8443:127.0.0.1:"${ATTACK_PORT}" \
     https://example.local:8443/ || true
echo "    (expect FAIL here -- 'Rogue Attacker Root CA' is not trusted by anything yet, same"
echo "     as any unknown CA on any day before this one.)"

echo "==> [5/6] Installing the rogue root into THIS container's trust store."
cp rogue-root.cert.pem /usr/local/share/ca-certificates/rogue-root.crt
update-ca-certificates >/dev/null
echo "    Same curl command as step 4. Nothing else has changed:"
curl --connect-to example.local:8443:127.0.0.1:"${ATTACK_PORT}" \
     https://example.local:8443/
echo "    <<< THE AHA: curl now TRUSTS the attacker's example.local cert."
echo "    Checks 1-3 were always fine -- correct signature under its own (rogue) root,"
echo "    current dates, correct SAN. Only check 4 ever stood between you and this."

echo "==> [6/6] DEFENSE: pin the REAL example.local leaf's public key, then retry against the SAME attacker."
REAL_PIN=$(openssl x509 -in /work/ca/intermediate/certs/example.local.cert.pem -pubkey -noout \
    | openssl pkey -pubin -outform der \
    | openssl dgst -sha256 -binary \
    | base64)
echo "    Real example.local pubkey pin: sha256//${REAL_PIN}"
curl --pinnedpubkey "sha256//${REAL_PIN}" \
     --connect-to example.local:8443:127.0.0.1:"${ATTACK_PORT}" \
     https://example.local:8443/ || true
echo "    <<< Expect FAIL now, even though the rogue cert is still 'trusted' by check 4."
echo "    Pinning never asks 'do I trust the issuer' -- it asks 'is this the exact key I"
echo "    already know about', and the rogue leaf's key is a different keypair entirely."

kill "${SERVER_PID}" 2>/dev/null || true
wait "${SERVER_PID}" 2>/dev/null || true

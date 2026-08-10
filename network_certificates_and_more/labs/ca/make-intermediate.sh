#!/usr/bin/env bash
set -euo pipefail
#
# make-intermediate.sh — build the intermediate CA, signed by the root.
#
# Run from labs/:
#   docker compose run --rm toolbox bash ca/make-intermediate.sh
#
# Requires the root CA to already exist (run make-root.sh first).
#
# Produces:
#   ca/intermediate/private/intermediate.key.pem   RSA 4096 intermediate key.
#   ca/intermediate/certs/intermediate.cert.pem     Signed by the root, valid 10 years.
#   ca/intermediate/certs/ca-chain.cert.pem         intermediate + root, concatenated
#                                                    (what clients that only trust the
#                                                    root, not the intermediate, need).
#
# Idempotent: if the intermediate cert/key already exist, they are not
# regenerated (that would invalidate every leaf cert issued under them) —
# but the chain file is always rebuilt, since that's cheap and side-effect-free.

ROOT_DIR="ca/root"
INT_DIR="ca/intermediate"
ROOT_CONF="ca/openssl-root.cnf"
INT_CONF="ca/openssl-intermediate.cnf"

if [ ! -f "${ROOT_DIR}/certs/ca.cert.pem" ] || [ ! -f "${ROOT_DIR}/private/ca.key.pem" ]; then
  echo "ERROR: root CA not found under ${ROOT_DIR}. Run make-root.sh first." >&2
  exit 1
fi

echo "==> Creating intermediate CA directory layout under ${INT_DIR}"
mkdir -p "${INT_DIR}/certs" "${INT_DIR}/crl" "${INT_DIR}/newcerts" "${INT_DIR}/private" "${INT_DIR}/csr"
chmod 700 "${INT_DIR}/private"

touch "${INT_DIR}/index.txt"
echo "unique_subject = no" > "${INT_DIR}/index.txt.attr"
if [ ! -f "${INT_DIR}/serial" ]; then
  echo 1000 > "${INT_DIR}/serial"
fi

if [ -f "${INT_DIR}/private/intermediate.key.pem" ] && [ -f "${INT_DIR}/certs/intermediate.cert.pem" ]; then
  echo "==> Intermediate CA already exists at ${INT_DIR} — leaving it in place."
else
  echo "==> Generating intermediate CA private key (RSA 4096)"
  openssl genrsa -out "${INT_DIR}/private/intermediate.key.pem" 4096
  chmod 600 "${INT_DIR}/private/intermediate.key.pem"

  echo "==> Creating intermediate CSR"
  openssl req -config "${INT_CONF}" \
      -key "${INT_DIR}/private/intermediate.key.pem" \
      -new -sha256 \
      -subj "/C=US/ST=CA/O=TLS Mastery Lab/OU=Intermediate CA/CN=TLS Mastery Intermediate CA" \
      -batch \
      -out "${INT_DIR}/csr/intermediate.csr.pem"

  echo "==> Signing intermediate CSR with the root CA (v3_intermediate_ca extensions)"
  openssl ca -config "${ROOT_CONF}" \
      -extensions v3_intermediate_ca -days 3650 -notext -md sha256 \
      -in "${INT_DIR}/csr/intermediate.csr.pem" \
      -out "${INT_DIR}/certs/intermediate.cert.pem" \
      -batch
fi

echo "==> Building certificate chain (intermediate + root)"
cat "${INT_DIR}/certs/intermediate.cert.pem" "${ROOT_DIR}/certs/ca.cert.pem" \
    > "${INT_DIR}/certs/ca-chain.cert.pem"

echo "==> Intermediate CA ready:"
echo "    key:   ${INT_DIR}/private/intermediate.key.pem"
echo "    cert:  ${INT_DIR}/certs/intermediate.cert.pem"
echo "    chain: ${INT_DIR}/certs/ca-chain.cert.pem"

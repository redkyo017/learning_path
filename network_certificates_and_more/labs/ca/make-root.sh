#!/usr/bin/env bash
set -euo pipefail
#
# make-root.sh — build the self-signed root CA.
#
# Run from labs/ (this is what the toolbox container's CWD, /work, maps to):
#   docker compose run --rm toolbox bash ca/make-root.sh
#
# Produces:
#   ca/root/private/ca.key.pem   RSA 4096 root private key.
#                                 (4096 for the root/intermediate signing
#                                 keys since they're generated once and used
#                                 for years; leaf keys use 2048 for speed —
#                                 see issue-server-cert.sh.)
#   ca/root/certs/ca.cert.pem    Self-signed root certificate, valid 20 years.
#
# Idempotent: if the root already exists, this exits without regenerating it
# (regenerating would invalidate every cert already issued under it).

CA_DIR="ca/root"
CONF="ca/openssl-root.cnf"

echo "==> Creating root CA directory layout under ${CA_DIR}"
mkdir -p "${CA_DIR}/certs" "${CA_DIR}/crl" "${CA_DIR}/newcerts" "${CA_DIR}/private" "${CA_DIR}/csr"
chmod 700 "${CA_DIR}/private"

touch "${CA_DIR}/index.txt"
echo "unique_subject = no" > "${CA_DIR}/index.txt.attr"
if [ ! -f "${CA_DIR}/serial" ]; then
  echo 1000 > "${CA_DIR}/serial"
fi

if [ -f "${CA_DIR}/private/ca.key.pem" ] && [ -f "${CA_DIR}/certs/ca.cert.pem" ]; then
  echo "==> Root CA already exists at ${CA_DIR} — leaving it in place."
  exit 0
fi

echo "==> Generating root CA private key (RSA 4096)"
openssl genrsa -out "${CA_DIR}/private/ca.key.pem" 4096
chmod 600 "${CA_DIR}/private/ca.key.pem"

echo "==> Self-signing root certificate (20 years, v3_ca extensions)"
openssl req -config "${CONF}" \
    -key "${CA_DIR}/private/ca.key.pem" \
    -new -x509 -days 7300 -sha256 -extensions v3_ca \
    -subj "/C=US/ST=CA/O=TLS Mastery Lab/OU=Root CA/CN=TLS Mastery Root CA" \
    -batch \
    -out "${CA_DIR}/certs/ca.cert.pem"

echo "==> Root CA ready:"
echo "    key:  ${CA_DIR}/private/ca.key.pem"
echo "    cert: ${CA_DIR}/certs/ca.cert.pem"

#!/usr/bin/env bash
set -euo pipefail
#
# issue-server-cert.sh <cn> [san...]
#
# Issues a leaf (end-entity) server certificate signed by the intermediate
# CA. subjectAltName is populated from <cn> plus any extra SAN args; each
# arg is classified as an IP address (IPv4 dotted-quad or anything
# containing ':' for IPv6) or a DNS name automatically.
#
# Run from labs/:
#   docker compose run --rm toolbox bash ca/issue-server-cert.sh example.local example.local
#   docker compose run --rm toolbox bash ca/issue-server-cert.sh example.local example.local 127.0.0.1
#
# Requires the intermediate CA to already exist (run make-intermediate.sh first).
#
# Produces:
#   ca/intermediate/certs/<cn>.cert.pem    RSA 2048 leaf cert, valid ~13 months.
#   ca/intermediate/private/<cn>.key.pem   RSA 2048 leaf private key.
#
# Safe to run repeatedly for different <cn> values: ca/intermediate/index.txt
# and ca/intermediate/serial are created once by make-intermediate.sh and
# each invocation here only appends to them via `openssl ca`. Re-running for
# the SAME <cn> also works (overwrites that CN's key/cert/CSR) because
# unique_subject=no is set in ca/intermediate/index.txt.attr.

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <cn> [san...]" >&2
  exit 1
fi

CN="$1"
shift
SANS=("$@")
if [ "${#SANS[@]}" -eq 0 ]; then
  SANS=("${CN}")
fi

INT_DIR="ca/intermediate"
INT_CONF="ca/openssl-intermediate.cnf"

if [ ! -f "${INT_DIR}/certs/intermediate.cert.pem" ] || [ ! -f "${INT_DIR}/private/intermediate.key.pem" ]; then
  echo "ERROR: intermediate CA not found under ${INT_DIR}. Run make-intermediate.sh first." >&2
  exit 1
fi

mkdir -p "${INT_DIR}/certs" "${INT_DIR}/private" "${INT_DIR}/csr"

KEY="${INT_DIR}/private/${CN}.key.pem"
CSR="${INT_DIR}/csr/${CN}.csr.pem"
CERT="${INT_DIR}/certs/${CN}.cert.pem"
EXT_CONF="${INT_DIR}/csr/${CN}.ext.cnf"

echo "==> Generating server key (RSA 2048) for CN=${CN}"
openssl genrsa -out "${KEY}" 2048
chmod 600 "${KEY}"

echo "==> Creating CSR for CN=${CN}"
openssl req -config "${INT_CONF}" \
    -key "${KEY}" \
    -new -sha256 \
    -subj "/C=US/ST=CA/O=TLS Mastery Lab/OU=Servers/CN=${CN}" \
    -batch \
    -out "${CSR}"

echo "==> Rewriting [ alt_names ] from args: ${SANS[*]}"
# Copy everything up to (not including) the "[ alt_names ]" placeholder
# section from the shared intermediate config, then append a freshly
# generated [ alt_names ] block built from this call's <cn>/SAN args. This
# never mutates ca/openssl-intermediate.cnf itself.
sed '/^\[ alt_names \]/,$d' "${INT_CONF}" > "${EXT_CONF}"
{
  echo "[ alt_names ]"
  dns_i=1
  ip_i=1
  for san in "${SANS[@]}"; do
    if [[ "${san}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || [[ "${san}" == *:* ]]; then
      echo "IP.${ip_i} = ${san}"
      ip_i=$((ip_i + 1))
    else
      echo "DNS.${dns_i} = ${san}"
      dns_i=$((dns_i + 1))
    fi
  done
} >> "${EXT_CONF}"

echo "==> Signing certificate with intermediate CA (server_cert extensions)"
openssl ca -config "${EXT_CONF}" \
    -extensions server_cert -days 375 -notext -md sha256 \
    -in "${CSR}" \
    -out "${CERT}" \
    -batch

echo "==> Issued:"
echo "    key:  ${KEY}"
echo "    cert: ${CERT}"

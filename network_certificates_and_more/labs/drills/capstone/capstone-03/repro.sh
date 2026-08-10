#!/usr/bin/env bash
set -euo pipefail
#
# Capstone 03 -- reproduction asset. Issues a leaf from the REAL
# intermediate CA whose entire validity window is already in the past
# (both -startdate and -enddate override -days and are set behind today),
# then verifies it the same way Day 1's drill-04 verified a pre-baked
# expired fixture.
#
# Run from labs/:
#   docker compose run --rm toolbox bash /work/drills/capstone/capstone-03/repro.sh

if [ ! -f /work/ca/intermediate/certs/intermediate.cert.pem ]; then
  echo "ERROR: run Day 2's guided lab first (need ca/intermediate/)." >&2
  exit 1
fi

KEY=/work/ca/intermediate/private/old-report.local.key.pem
CSR=/work/ca/intermediate/csr/old-report.local.csr.pem
CERT=/work/ca/intermediate/certs/old-report.local.cert.pem
EXT=/work/ca/intermediate/csr/old-report.local.ext.cnf

openssl genrsa -out "${KEY}" 2048 2>/dev/null

openssl req -config /work/ca/openssl-intermediate.cnf -key "${KEY}" \
    -new -sha256 \
    -subj "/C=US/ST=CA/O=TLS Mastery Lab/OU=Servers/CN=old-report.local" \
    -batch -out "${CSR}"

sed '/^\[ alt_names \]/,$d' /work/ca/openssl-intermediate.cnf > "${EXT}"
printf '[ alt_names ]\nDNS.1 = old-report.local\n' >> "${EXT}"

# -startdate/-enddate override -days entirely: this cert is born already
# expired, three months of validity that both ended nearly two years ago.
openssl ca -config "${EXT}" -extensions server_cert -notext -md sha256 \
    -startdate 20230101000000Z -enddate 20230401000000Z \
    -in "${CSR}" -out "${CERT}" -batch

openssl verify -CAfile /work/ca/intermediate/certs/ca-chain.cert.pem "${CERT}"

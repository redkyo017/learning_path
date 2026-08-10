#!/usr/bin/env bash
# Drill 10 — minimal reproduction asset.
#
# Reuses the already-running Day 2 nginx (example.local:8443) — its only
# certificate is RSA (issued by ca/issue-server-cert.sh, which generates
# RSA 2048 leaf keys). This client restricts itself to TLS 1.2 and to
# cipher suites that require an ECDSA-keyed certificate for
# authentication. No suite in that list can ever be satisfied by an
# RSA-keyed server, regardless of what else the server is willing to
# negotiate.
#
# Run from labs/, with nginx already up (docker compose up -d nginx):
#   docker compose run --rm toolbox bash /work/drills/drill-10/repro.sh
set -euo pipefail

curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --connect-to example.local:8443:nginx:443 \
     --tlsv1.2 --tls-max 1.2 \
     --ciphers ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES128-GCM-SHA256 \
     https://example.local:8443/

#!/usr/bin/env bash
# Drill 11 — minimal reproduction asset.
#
# Reuses the already-running Day 2 nginx (example.local:8443), which has
# exactly one server block (example.local). This client deliberately sends
# an SNI ("wrong.local") that does not match any server_name nginx knows.
# With only one server block defined, nginx serves it regardless of SNI
# (it's the only certificate it has to offer) — the handshake itself
# succeeds, but the certificate that comes back is for example.local,
# not wrong.local, so the client's own hostname check fails afterward.
#
# Run from labs/, with nginx already up (docker compose up -d nginx):
#   docker compose run --rm toolbox bash /work/drills/drill-11/repro.sh
set -euo pipefail

curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --connect-to wrong.local:8443:nginx:443 \
     https://wrong.local:8443/

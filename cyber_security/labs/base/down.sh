#!/usr/bin/env bash
# Tear down the shared attacker toolbox + cyberlab network + volumes.
set -euo pipefail
cd "$(dirname "$0")"

echo "[*] Stopping and removing attacker container, network, and volumes..."
docker compose down -v

echo "[*] Done. Note: any day-lab still attached to the 'cyberlab' network"
echo "    (declared as 'external: true') must be torn down first, or this"
echo "    network removal will be skipped by Docker until they are."

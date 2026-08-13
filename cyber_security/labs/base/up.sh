#!/usr/bin/env bash
# Build and start the shared attacker toolbox + cyberlab network.
#
# AUTHORIZED USE ONLY: this toolbox is for attacking the containers
# provided by this learning path (on the `cyberlab` docker network) or
# your own AWS sandbox account. Never point it at systems you do not own
# or have explicit written authorization to test.
set -euo pipefail
cd "$(dirname "$0")"

echo "[*] Building attacker image (kalilinux/kali-rolling + tools — this can take a while the first time)..."
docker compose build

echo "[*] Starting attacker container on the 'cyberlab' network..."
docker compose up -d

echo "[*] Done. Shell into the attacker container with:"
echo "      docker compose exec attacker bash"
echo "[*] Loot volume is mounted at /loot inside the container ($(pwd)/loot on the host)."

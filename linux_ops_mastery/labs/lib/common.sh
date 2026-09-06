#!/usr/bin/env bash
# Shared helpers for every labs/dayNN/{break,verify}.sh script.
# Sourced, never executed directly. Host-side only.
#
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
#
# Exports: compose, in_ws, in_app, in_slim, symptom, require_fleet.
set -euo pipefail

LABS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLEET_FILE="${LABS_DIR}/fleet/docker-compose.yml"
PROJECT="linuxops"

compose() { docker compose -p "$PROJECT" -f "$FLEET_FILE" "$@"; }
in_ws()   { compose exec -T ws   bash -c "$1"; }
in_app()  { compose exec -T app  sh   -c "$1"; }
in_slim() { compose exec -T slim sh   -c "$1"; }

symptom() { printf '\nSYMPTOM: %s\n\nNothing else will be explained.\n' "$1"; }

require_fleet() {
  if ! compose ps --status running --quiet ws >/dev/null 2>&1 \
     || [ -z "$(compose ps --status running --quiet ws)" ]; then
    echo "Fleet is not running. Start it with:" >&2
    echo "  cd ${LABS_DIR}/fleet && docker compose -p linuxops up -d --build" >&2
    exit 1
  fi
}

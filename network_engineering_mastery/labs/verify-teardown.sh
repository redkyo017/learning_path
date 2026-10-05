#!/usr/bin/env bash
# verify-teardown.sh -- prove the netlab container is gone.
#
#   ./labs/verify-teardown.sh
#
# Exits 0 when no container belongs to the `netlab` compose project. Exits 1
# and prints the command that cleans up when one is still there. Exits 2 when
# Docker itself is not reachable.
#
# Host side (macOS). Read only: this script reports, it never deletes.
set -uo pipefail

NETLAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/netlab" && pwd)"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not on PATH; nothing to verify." >&2
  exit 2
fi
if ! docker info >/dev/null 2>&1; then
  echo "The Docker daemon is not reachable. Start Docker Desktop (or" >&2
  echo "\`colima start\`) and run this again -- a stopped daemon is not" >&2
  echo "the same thing as a clean teardown." >&2
  exit 2
fi

echo "note: inside netlab, 'ip netns list' should be empty after topo.sh down"

running="$(cd "${NETLAB_DIR}" && docker compose -p netlab ps -q 2>/dev/null)"
if [ -z "${running}" ]; then
  echo "CLEAN: no netlab container is running."
  exit 0
fi

echo "LEFT netlab container running — docker compose -p netlab down"
echo "  (run it from ${NETLAB_DIR})"
exit 1

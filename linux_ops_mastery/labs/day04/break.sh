#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

compose exec -T app sh -c 'wget -qO- "http://127.0.0.1:8080/burn?seconds=45" &' || true
sleep 2
compose exec -T app sh -c 'wget -qO- "http://127.0.0.1:8080/balloon?mb=120&child=1"' >/dev/null 2>&1 || true
symptom "Requests are slow, and something inside the container was killed."

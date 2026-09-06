#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

in_app 'dd if=/dev/zero of=/var/log/bloat.log bs=1M 2>/dev/null || true'
in_app 'setsid sh -c "exec tail -f /var/log/bloat.log >/dev/null 2>&1" &'
sleep 1
in_app 'rm -f /var/log/bloat.log'
symptom "Writes to /var/log on the app container are failing with ENOSPC."

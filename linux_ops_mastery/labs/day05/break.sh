#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

# Day 5 is the only day that needs the sysd overlay. compose_sysd/in_sysd are
# defined here, not in ../lib/common.sh, so the other six days never see the
# extra -f and never depend on the sysd container being up.
compose_sysd() {
  docker compose -p linuxops \
    -f "${LABS_DIR}/fleet/docker-compose.yml" \
    -f "${LABS_DIR}/fleet/docker-compose.sysd.yml" "$@"
}
in_sysd() { compose_sysd exec -T sysd bash -c "$1"; }

require_sysd() {
  if [ -z "$(compose_sysd ps --status running --quiet sysd 2>/dev/null)" ]; then
    echo "sysd is not running. Bring up the Day 5 overlay first:" >&2
    echo "  cd ${LABS_DIR}/fleet" >&2
    echo "  docker compose -p linuxops -f docker-compose.yml \\" >&2
    echo "    -f docker-compose.sysd.yml up -d --build sysd" >&2
    echo "If it exits immediately, read the fleet README's Colima fallback." >&2
    exit 1
  fi
}
require_sysd

# Incident 1: create a file, then set its own mode and its parent
# directory's mode.
in_sysd 'mkdir -p /srv/reports && echo "quarterly numbers" > /srv/reports/q3.txt'
in_sysd 'chmod 777 /srv/reports/q3.txt && chmod 600 /srv/reports'
in_sysd 'id -u appuser >/dev/null 2>&1 || useradd -m appuser'

# Incident 2: install a stub binary, a labs-db.service unit, and the
# labs-api.service unit shipped in units/labs-api.service; reload and start.
in_sysd 'install -m 0755 /dev/stdin /usr/local/bin/labs-apid <<"EOF"
#!/bin/sh
echo "labs-api listening"; exec sleep infinity
EOF'
in_sysd 'printf "[Unit]\nDescription=Labs DB\n[Service]\nType=simple\nExecStart=/bin/sleep infinity\n[Install]\nWantedBy=multi-user.target\n" > /etc/systemd/system/labs-db.service'
in_sysd 'cp /labs/day05/units/labs-api.service /etc/systemd/system/labs-api.service'
in_sysd 'systemctl daemon-reload && systemctl start labs-api.service' || true

symptom "appuser cannot read /srv/reports/q3.txt (mode 777), and labs-api.service will not start."

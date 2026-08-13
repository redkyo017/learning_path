#!/usr/bin/env bash
# Capstone detection pass (Day 21, Defense fix #5: "add detection").
#
# Reads webapp's access log (populated by app.py's before_request logger,
# bind-mounted to ../logs/webapp/access.log) and flags three attack
# signatures by pattern-matching the logged path+query -- the same
# signature-based approach Day 11 introduces for the earlier days'
# attacks. This is intentionally simple (grep-based, not a real SIEM
# rule engine) -- see content/day21-capstone-defend.md's Concept section
# for why fidelity-vs-noise still matters even at this scale.
#
# Usage:
#   ./detect.sh                       # scan the default log path once
#   ./detect.sh /path/to/access.log   # scan an arbitrary log file
#
# Exit code: 0 if the log was readable (regardless of whether anything
# fired -- this is a report, not a gate). Non-zero only if the log file
# itself could not be read at all.

set -euo pipefail

LOG_FILE="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/logs/webapp/access.log}"

if [[ ! -r "${LOG_FILE}" ]]; then
  echo "detect.sh: cannot read log file: ${LOG_FILE}" >&2
  echo "detect.sh: has webapp been started at least once? (docker compose up -d webapp)" >&2
  exit 1
fi

echo "== Capstone detection pass =="
echo "Log file: ${LOG_FILE}"
echo

FOUND_ANY=0

echo "--- [SQLI] SQL-injection-shaped /login attempts (quote/comment/UNION markers) ---"
if grep -E "path=/login" "${LOG_FILE}" | grep -E "('|--|UNION|OR 1=1|OR '1'='1)" ; then
  FOUND_ANY=1
else
  echo "(none)"
fi
echo

echo "--- [CMDI] command-injection-shaped /admin/diagnostics requests (shell metacharacters in host=) ---"
if grep -E "path=/admin/diagnostics" "${LOG_FILE}" | grep -E "(;|\\||\`|\\\$\\()" ; then
  FOUND_ANY=1
else
  echo "(none)"
fi
echo

echo "--- [SSRF] SSRF-to-metadata /admin/fetch requests (target is the link-local metadata address) ---"
if grep -E "path=/admin/fetch" "${LOG_FILE}" | grep -F "169.254.169.254" ; then
  FOUND_ANY=1
else
  echo "(none)"
fi
echo

echo "--- [ACCESS] non-admin sessions reaching /admin/* (broken-access-control indicator) ---"
if grep -E "path=/admin/" "${LOG_FILE}" | grep -v "role=admin" | grep -v "role=-" ; then
  FOUND_ANY=1
else
  echo "(none)"
fi
echo

if [[ "${FOUND_ANY}" -eq 1 ]]; then
  echo "DETECT_OK -- at least one attack signature fired against this log."
else
  echo "DETECT_CLEAN -- log scanned successfully, no signatures fired (attack the lab first if you expected a hit, or check the log path)."
fi

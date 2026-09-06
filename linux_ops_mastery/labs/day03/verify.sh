#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

# Two independent deliverables (see README.md): the held file released,
# and /tmp/answer on `app` proving the triage found the right req_id.
# Neither alone is proof; both together are. The expected req_id is never
# hard-coded here or in break.sh -- it is generated per run and stashed
# in /tmp/.day03-needle on `app`; this script reads that file and compares
# it against /tmp/answer, but never prints either value.

fail=0

echo "== held file (deleted-but-open under /var/log) =="
held="$(in_app 'ls -l /proc/[0-9]*/fd/* 2>/dev/null \
  | grep "(deleted)" | grep "/var/log" || true')"
if [ -n "${held}" ]; then
  echo "STILL HELD:"
  echo "${held}"
  fail=1
else
  echo "ok: no deleted file open under /var/log"
fi

echo
echo "== /tmp/answer on app =="
needle="$(in_app 'cat /tmp/.day03-needle 2>/dev/null || true')"
answer="$(in_app 'cat /tmp/answer 2>/dev/null || true')"
if [ -n "${needle}" ] && printf '%s' "${answer}" | grep -qF "${needle}"; then
  echo "ok: /tmp/answer contains the recovered req_id"
else
  echo "MISSING: /tmp/answer does not contain the recovered req_id"
  fail=1
fi

echo
if [ "${fail}" -eq 0 ]; then
  echo "PASS: held file released and req_id recorded in /tmp/answer."
  exit 0
fi

echo "FAIL: see above."
exit 1

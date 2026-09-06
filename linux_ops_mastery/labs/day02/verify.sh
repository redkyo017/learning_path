#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

# Every pgrep pattern below is bracketed on one character so that the
# pgrep command's own /proc/PID/cmdline (which contains the literal
# search text) cannot match its own pattern. Without the bracket,
# `pgrep -f "sleep 100000"` always finds at least the wrapper shell
# running this very check, and `sleepers` could never reach 0.
stopped=$(in_app 'grep -l "^State:.T" /proc/[0-9]*/status 2>/dev/null | wc -l')
zombies=$(in_app 'grep -l "^State:.Z" /proc/[0-9]*/status 2>/dev/null | wc -l')
trapped=$(in_app 'pgrep -f "sleep 10000[0]" | wc -l')
paused=$(in_app 'pgrep -f "sleep 20000[0]" | wc -l')
spawner=$(in_app 'pgrep -f "os[.]fork" | wc -l')

if [ "$stopped" -eq 0 ] && [ "$zombies" -eq 0 ] && [ "$trapped" -eq 0 ] \
  && [ "$paused" -eq 0 ] && [ "$spawner" -eq 0 ]; then
  echo "PASS: no stopped, zombie, trapped, or spawner processes remain."
else
  echo "FAIL: stopped=$stopped zombies=$zombies trapped=$trapped" \
       "paused=$paused spawner=$spawner" >&2
  exit 1
fi

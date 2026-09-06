#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

# (a) a process that traps SIGTERM and refuses to leave
in_app 'setsid sh -c "trap \"\" TERM; exec sleep 100000" >/dev/null 2>&1 &'
# (b) zombies: a spawner with the ordinary (non-ignored) SIGCHLD
# disposition that forks constantly and never reaps -- unlike app.py,
# which sets SIGCHLD to SIG_IGN and so never manufactures its own.
in_app 'setsid python3 -c "
import os, time
while True:
    if os.fork() == 0:
        os._exit(0)
    time.sleep(2)
" >/dev/null 2>&1 &'
# (c) a stopped process that looks alive and leaves TERM pending.
# A different duration than (a) so the two are individually addressable
# with no reliance on /proc readdir order.
in_app 'setsid sh -c "exec sleep 200000" >/dev/null 2>&1 &'
sleep 1
# Bracketed pattern: the pgrep command's own cmdline contains the literal
# text "sleep 20000[0]" (with brackets), which does not match the regex
# "sleep 20000[0]" itself -- only the real "sleep 200000" cmdline does.
in_app 'kill -STOP $(pgrep -f "sleep 20000[0]")'
symptom "Three processes on app will not exit. One ignores SIGTERM, one is stopped, one is multiplying."

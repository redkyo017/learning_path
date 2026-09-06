#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

# Idempotent guard: re-running this without teardown would otherwise stack
# a second held copy on top of the first, walking /var/log toward its
# 24 MiB ceiling. Release any already-held deleted file and reset the live
# log (and last run's needle/answer) before injecting the incident again.
in_app '
  for p in /proc/[0-9]*/fd/*; do
    t=$(readlink "$p" 2>/dev/null) || continue
    case "$t" in
      /var/log/*"(deleted)")
        pid=${p#/proc/}; pid=${pid%%/*}
        kill "$pid" 2>/dev/null || true
        ;;
    esac
  done
  rm -f /var/log/app.log.1 /tmp/.day03-needle /tmp/answer
  : > /var/log/app.log
' 2>/dev/null

# A fresh 8-hex-digit needle every run, generated at runtime rather than
# hard-coded in this source file -- a learner who reads break.sh should
# not get to read the answer off it. Stored under a dot-file, the same
# convention Day 6 uses for its own fault number: readable by verify.sh,
# unlikely to be stumbled over while poking around /tmp.
in_app 'od -An -tx1 -N4 /dev/urandom | tr -d " \n" > /tmp/.day03-needle' \
  2>/dev/null

in_app 'sh /labs/fleet/seed/gen-logs.sh 100000 \
  --needle "$(cat /tmp/.day03-needle)" 2>/dev/null'
in_app 'cp /var/log/app.log /var/log/app.log.1 && : > /var/log/app.log'
in_app 'setsid sh -c "exec tail -f /var/log/app.log.1 >/dev/null 2>&1" &'
in_app 'rm -f /var/log/app.log.1'
symptom "One request failed in the last rotation, and /var/log keeps filling after rotation."

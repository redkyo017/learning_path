#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

# This lab's deliverable is a diagnosis, not a repair -- app recovers on its
# own. Grading reads the learner's /tmp/findings on app and compares it,
# byte for byte, against a fresh read of the live cgroup files. See
# README.md for the exact contract.

findings="$(in_app 'cat /tmp/findings 2>/dev/null' || true)"

if [ -z "$findings" ]; then
  echo "FAIL: /tmp/findings not found (or empty) on app." >&2
  echo "  Write two lines there first: oom_kill=<n> and nr_throttled=<n>." >&2
  echo "  See labs/day04/README.md for the exact format." >&2
  exit 1
fi

got_oom="$(printf '%s\n' "$findings" | grep '^oom_kill=' | tail -n1 | cut -d= -f2)"
got_thr="$(printf '%s\n' "$findings" | grep '^nr_throttled=' | tail -n1 | cut -d= -f2)"

if [ -z "$got_oom" ] || [ -z "$got_thr" ]; then
  echo "FAIL: /tmp/findings must contain a line 'oom_kill=<n>' and a line" >&2
  echo "  'nr_throttled=<n>', each with a literal integer value." >&2
  exit 1
fi

live_oom="$(in_app 'grep "^oom_kill " /sys/fs/cgroup/memory.events | cut -d" " -f2' || true)"
live_thr="$(in_app 'grep "^nr_throttled " /sys/fs/cgroup/cpu.stat | cut -d" " -f2' || true)"

if [ -z "$live_oom" ] || [ -z "$live_thr" ]; then
  echo "FAIL: could not read memory.events or cpu.stat on app." >&2
  exit 1
fi

# A nonzero floor, not just a match: a freshly-recreated (or never-broken)
# app has both counters at 0, and 0 == 0 would otherwise pass trivially
# without break.sh ever having run.
if [ "$live_oom" -le 0 ] 2>/dev/null || [ "$live_thr" -le 0 ] 2>/dev/null; then
  echo "FAIL: live cgroup files show no incident yet:" >&2
  echo "  oom_kill=$live_oom nr_throttled=$live_thr" >&2
  echo "  Run break.sh first, then re-read the files before writing" >&2
  echo "  /tmp/findings." >&2
  exit 1
fi

if [ "$got_oom" = "$live_oom" ] && [ "$got_thr" = "$live_thr" ]; then
  echo "PASS: findings match live cgroup files (both nonzero)"
  echo "  oom_kill=$live_oom nr_throttled=$live_thr"
  exit 0
fi

echo "FAIL: findings do not match the live cgroup files." >&2
echo "  findings: oom_kill=$got_oom nr_throttled=$got_thr" >&2
echo "  live:     oom_kill=$live_oom nr_throttled=$live_thr" >&2
exit 1

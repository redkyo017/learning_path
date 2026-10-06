#!/usr/bin/env bash
# Shared helpers for the practice-track workbooks (labs/practice/<wb>/{setup,check}.sh).
# Sourced after labs/lib/common.sh, never executed. Host-side only (the Mac).
#
#   source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
#   source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
#   require_fleet
#   drills=$(arg_drills "${1:-}" 12) || exit 2   # NOT inside "for ... in $(...)": exit there only leaves the subshell
#   for n in $drills; do
#     f="$(drill_dir fileops "$n")/out.txt"
#     if ws_file_eq "$f" $'alpha\nbeta'; then pass "d$(printf %02d "$n")" "out.txt ok"
#     else fail "d$(printf %02d "$n")" "out.txt differs (diff above)"; fi
#   done
#   finish          # prints "N/M passed", exits 1 if any FAIL
#
# API (all safe under set -euo pipefail; pass/fail/ws_file_eq never trip errexit):
#   drill_dir <wb> <N>        print /root/practice/<wb>/dNN (path inside ws). wb must match
#                             ^[a-z_]+$ and N be a positive integer, else message + return 2
#   reset_drill <wb> <N>      in ws: rm -rf then mkdir -p that dir (idempotent)
#   arg_drills <arg> <max>    print drill numbers one per line: "all" -> 1..max, or a
#                             single number 1..max; anything else -> message + return 2.
#                             Call as drills=$(arg_drills "${1:-}" 12) || exit 2
#   pass <id> <msg>           print "PASS <id> <msg>", count it
#   fail <id> <msg>           print "FAIL <id>: <msg>", count it (never exits)
#   finish                    print "N/M passed"; return 1 if any fail OR if no drill ran
#                             (use as the last line of the script)
#   ws_file_eq [-n] <path> <expected>
#                             exact byte compare of ws:<path> with <expected> PLUS one
#                             trailing newline (so a $(...)/heredoc value, whose trailing
#                             newlines the shell strips, matches a normal text file).
#                             -n: no trailing newline appended (compare exactly).
#                             Returns 0 equal; 1 differ (unified diff, "expected" vs path,
#                             on stdout); 2 file missing/unreadable or diff trouble (message on stdout).
#                             A docker/compose failure may surface as 1 or 2; either is a FAIL.
#                             Expected text travels on stdin, so $ ' " \ and tabs are safe.
set -euo pipefail

PRACTICE_ROOT="/root/practice"
_PASSED=0
_TOTAL=0

drill_dir() {
  if ! [[ "${1:-}" =~ ^[a-z_]+$ ]] || ! [[ "${2:-}" =~ ^[0-9]+$ ]] || [ $((10#$2)) -lt 1 ]; then
    echo "drill_dir: bad workbook '${1:-}' or drill '${2:-}'" >&2
    return 2
  fi
  printf '%s/%s/d%02d\n' "$PRACTICE_ROOT" "$1" $((10#$2))
}

reset_drill() {
  local d
  d="$(drill_dir "$1" "$2")" || return 2
  in_ws "rm -rf '$d' && mkdir -p '$d'"
}

arg_drills() {
  local arg="$1" max="$2" i
  if [ "$arg" = all ]; then
    for ((i = 1; i <= max; i++)); do echo "$i"; done
  elif [[ "$arg" =~ ^[0-9]+$ ]] && [ $((10#$arg)) -ge 1 ] && [ $((10#$arg)) -le "$max" ]; then
    echo $((10#$arg))
  else
    echo "usage: <N|all>  (N is 1..${max})" >&2
    return 2
  fi
}

pass() { _TOTAL=$((_TOTAL + 1)); _PASSED=$((_PASSED + 1)); printf 'PASS %s %s\n' "$1" "$2"; }
fail() { _TOTAL=$((_TOTAL + 1)); printf 'FAIL %s: %s\n' "$1" "$2"; }

finish() {
  if [ "$_TOTAL" -eq 0 ]; then
    echo "0/0 passed (no drills ran)"
    return 1
  fi
  printf '%d/%d passed\n' "$_PASSED" "$_TOTAL"
  [ "$_PASSED" -eq "$_TOTAL" ]
}

ws_file_eq() {
  local nl=1
  if [ "${1:-}" = "-n" ]; then nl=0; shift; fi
  local path="$1" expected="$2" rc=0
  if ! in_ws "test -r '$path'" >/dev/null 2>&1; then
    echo "missing or unreadable: $path"
    return 2
  fi
  {
    printf '%s' "$expected"
    [ "$nl" -eq 1 ] && printf '\n'
    true
  } | compose exec -T ws bash -c 'diff -u --label expected --label "$1" - "$1"' _ "$path" || rc=$?
  [ "$rc" -eq 0 ] && return 0
  [ "$rc" -eq 1 ] && return 1
  echo "diff/exec trouble (rc=$rc) on $path"
  return 2
}

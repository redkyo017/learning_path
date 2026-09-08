#!/usr/bin/env bash
set -euo pipefail

# labs/lib/common.sh
#
# Shared shell library. Consumers: every labs/dayNN/verify.sh and
# labs/dayNN/break.sh in this course. Source it, do not execute it:
#   # shellcheck source=../lib/common.sh
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../lib/common.sh"
#
# Public function names below are a fixed API. break.sh and verify.sh scripts
# across all eight days call them by these exact names -- do not rename,
# alias, wrap, or add a prefix to any of them:
#   require_stack, in_pg, in_my, in_mongo, answer_check, say_symptom,
#   pass, fail
#
# Exit-flag convention: fail() sets FAILED=1 in the caller's shell (this file
# is sourced, so the assignment is not local to a subshell). Every verify.sh
# must end with:
#   exit "${FAILED:-0}"

COMPOSE_PROJECT="dbmastery"

# require_stack confirms all four dbmastery services are up, and that
# MongoDB's replica set has actually been initiated, before a lab script
# tries to talk to them. If any service is missing, or rs0 has never been
# initiated, it prints the exact bring-up commands documented in
# labs/stack/README.md and exits 1, rather than letting later commands fail
# with a confusing connection error (or, worse, a multi-document transaction
# error much later on Day 5).
require_stack() {
  local running_services svc
  running_services="$(docker compose -p "$COMPOSE_PROJECT" ps --status running --services 2>/dev/null || true)"
  for svc in pg my mongo ws; do
    if ! grep -qx "$svc" <<<"$running_services"; then
      echo "The dbmastery stack is not fully up (service '$svc' is not running)." >&2
      echo "Bring it up with:" >&2
      echo "  cd database_mastery/labs/stack && docker compose -p dbmastery up -d --build" >&2
      echo "Then, one time only -- after a first bring-up or after a 'down -v' reset --" >&2
      echo "initiate MongoDB's replica set:" >&2
      echo "  docker compose -p dbmastery exec mongo mongosh --quiet --eval 'rs.initiate()'" >&2
      exit 1
    fi
  done

  # All four containers can report "running" while MongoDB's replica set
  # rs0 has never been initiated -- "docker compose ps" cannot see that.
  # rs.status() fails until rs.initiate() has run, so check it directly:
  # cheap (one more mongosh round trip), read-only, and it catches the
  # missing step here instead of as a confusing transaction error on Day 5.
  if ! docker compose -p "$COMPOSE_PROJECT" exec -T mongo \
      mongosh --quiet --eval 'rs.status().ok' 2>/dev/null | grep -qx '1'; then
    echo "MongoDB's replica set (rs0) has not been initiated." >&2
    echo "Run this one-time step, then re-run your command:" >&2
    echo "  docker compose -p dbmastery exec mongo mongosh --quiet --eval 'rs.initiate()'" >&2
    exit 1
  fi
}

# in_pg runs SQL against the pg service as user dbm on database payments,
# tuples-only and unaligned, so callers can consume the output directly.
in_pg() {
  docker compose -p "$COMPOSE_PROJECT" exec -T pg \
    psql -U dbm -d payments -tAX -c "$1"
}

# in_my runs SQL against the my service as user dbm on database payments,
# batch mode with no column headers, so callers can consume the output
# directly.
in_my() {
  docker compose -p "$COMPOSE_PROJECT" exec -T my \
    mysql -u dbm -pdbmastery --batch --skip-column-names payments -e "$1"
}

# in_mongo runs a JS expression against the mongo service on database
# payments in quiet mode, so callers can consume the output directly.
in_mongo() {
  docker compose -p "$COMPOSE_PROJECT" exec -T mongo \
    mongosh --quiet payments --eval "$1"
}

# answer_check is the property that keeps every diagnostic lab honest.
# It reads the per-run value break.sh stashed at <stash_path>, compares it
# against the learner's answer, case-insensitively after trimming leading
# and trailing whitespace, and returns 0 on a match, 1 otherwise.
#
# The two files are deliberately read from different containers -- this is
# not a bug, it is the contract every day author relies on:
#   - the stash follows the pathology: it lives in <container>, whichever
#     engine (pg, my, mongo) break.sh planted the fault in.
#   - the answer follows the learner: /tmp/answer is ALWAYS read from ws,
#     because ws is the one container every day's lab work happens in
#     (the repo is mounted at /work there), regardless of which engine the
#     day's diagnosis targets. A single, constant answer location means a
#     learner never has to remember "which container does today's lab use"
#     under time pressure, and it is the only sane arrangement for a lab
#     like Day 8's gauntlet that spans three engines in one exercise.
#
# It must never print either value, on success or on failure. A learner who
# can read the expected answer out of a failing verify run has been handed
# the lesson instead of earning it -- do not add debug output here, even
# temporarily.
answer_check() {
  local stash_path="$1" container="$2" expected actual

  expected="$(docker compose -p "$COMPOSE_PROJECT" exec -T "$container" cat "$stash_path" 2>/dev/null || true)"
  actual="$(docker compose -p "$COMPOSE_PROJECT" exec -T ws cat /tmp/answer 2>/dev/null || true)"

  expected="$(printf '%s' "$expected" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')"
  actual="$(printf '%s' "$actual" | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')"

  [[ -n "$actual" && "$expected" == "$actual" ]]
}

# say_symptom prints exactly one line describing what the learner would
# observe before they know the cause -- the starting point for a diagnostic
# lab. Nothing else goes on this line.
say_symptom() {
  echo "SYMPTOM: $*"
}

# pass reports one successful verify.sh check.
pass() {
  echo "ok: $*"
}

# fail reports one failed verify.sh check and sets the exit-flag convention
# every verify.sh relies on: FAILED=1, checked at the end via
# exit "${FAILED:-0}".
fail() {
  echo "FAIL: $*"
  FAILED=1
}

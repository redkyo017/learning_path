#!/usr/bin/env bash
# verify.sh -- objective pass/fail on the Day 7 gauntlet's repairs.
#
#   ./verify.sh {1|2|3|4|5}   -- check one incident, exit 0 (fixed) or 1
#   ./verify.sh all           -- run all five checks, print a scorecard,
#                                 exit 0 only if every one of them passed
#
# Every check reads a kernel-owned file or does a real end-to-end request --
# no check trusts a summary tool's word for it. See ANSWERS.md for why each
# specific file was chosen.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

TIMES_FILE=/tmp/.gauntlet-times

usage() {
  echo "Usage: $(basename "$0") {1|2|3|4|5|all}" >&2
  exit 1
}

# --- incident 1: tmpfs reclaimed, no deleted-but-open fd under /var/log ----
check_1() {
  local pct deleted
  pct="$(in_app 'df /var/log | tail -1 | awk "{print \$5}"')"
  pct="${pct%\%}"
  deleted="$(in_app 'for p in /proc/[0-9]*/fd; do ls -l "$p" 2>/dev/null; done | grep "/var/log" | grep -c "(deleted)"')"
  [ "${pct:-100}" -lt 50 ] && [ "${deleted:-1}" -eq 0 ]
}

# --- incident 2: python is not stopped, and actually answers requests -----
check_2() {
  local pypid state
  pypid="$(in_app 'pgrep -f "/srv/app[.]py" | tail -1')"
  [ -n "${pypid}" ] || return 1
  state="$(in_app "awk -F') ' '{print \$2}' /proc/${pypid}/stat | cut -d' ' -f1")"
  [ "${state}" != "T" ] && [ "${state}" != "t" ] || return 1
  in_ws 'curl -sf -m 3 http://app:8080/healthz >/dev/null'
}

# --- incident 3: a burst of concurrent requests all succeed ---------------
# Ten real concurrent requests from ws, launched as ten separate
# background `docker compose exec` calls so they actually overlap on the
# wire, not ten calls issued one after another. One or two flaky timeouts
# are tolerated -- Docker Desktop's own exec overhead, not the cgroup, is
# the usual source of a stray failure here.
check_3() {
  local pids=() p fail=0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    in_ws 'curl -sf -m 3 http://app:8080/healthz >/dev/null 2>&1' &
    pids+=("$!")
  done
  for p in "${pids[@]}"; do
    wait "${p}" || fail=$((fail + 1))
  done
  [ "${fail}" -le 2 ]
}

# --- incident 4: the service account can read the deployed config ---------
check_4() {
  local mode
  mode="$(in_app 'stat -c "%a" /srv/conf.d/app.conf 2>/dev/null')"
  [ -n "${mode}" ] || return 1
  [ "$(( 8#${mode} & 8#040 ))" -ne 0 ] || return 1
  in_app "su -s /bin/sh svcuser -c 'cat /srv/conf.d/app.conf >/dev/null'"
}

# --- incident 5: db listens wide, and proxy's hosts file is clean ---------
check_5() {
  local listen hosts_status=0
  listen="$(compose exec -T db sh -c \
    "awk '\$2 ~ /:1538\$/ {print \$2}' /proc/net/tcp" | tr -d '\r')"
  echo "${listen}" | grep -q "^00000000:1538" || return 1
  compose exec -T proxy sh -c "grep -w db /etc/hosts" >/dev/null 2>&1 \
    && hosts_status=1
  [ "${hosts_status}" -eq 0 ]
}

get_start() {
  local n="$1"
  in_ws "touch ${TIMES_FILE}; awk -v n=${n} \
'\$1==\"START\" && \$2==n {t=\$3} END{print t+0}' ${TIMES_FILE}"
}

elapsed_for() {
  local n="$1" start now
  start="$(get_start "${n}")"
  if [ "${start}" = "0" ]; then
    echo "n/a"
    return
  fi
  now="$(in_ws 'date +%s')"
  echo "$((now - start))s"
}

run_check() {
  local n="$1"
  case "${n}" in
    1) check_1 ;;
    2) check_2 ;;
    3) check_3 ;;
    4) check_4 ;;
    5) check_5 ;;
    *) usage ;;
  esac
}

main() {
  local arg="${1:-}"
  case "${arg}" in
    1|2|3|4|5)
      if run_check "${arg}"; then
        echo "incident ${arg}: PASS"
        exit 0
      else
        echo "incident ${arg}: FAIL"
        exit 1
      fi
      ;;
    all)
      local failures=0 n result elapsed
      printf '%-9s %-7s %s\n' "incident" "passed" "elapsed"
      for n in 1 2 3 4 5; do
        elapsed="$(elapsed_for "${n}")"
        if run_check "${n}"; then
          result="y"
        else
          result="n"
          failures=$((failures + 1))
        fi
        printf '%-9s %-7s %s\n' "${n}" "${result}" "${elapsed}"
      done
      [ "${failures}" -eq 0 ]
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"

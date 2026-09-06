#!/usr/bin/env bash
# gauntlet.sh -- Day 7's break.sh: five unseen incidents, one at a time.
#
#   ./gauntlet.sh {1|2|3|4|5|all}
#
# Host side (macOS + docker), same as every other day's break.sh. Injects
# the incident(s) and prints exactly one symptom line each -- no hint, no
# path, no command suggestion -- then exits 0.
#
# `all` differs from a normal break.sh on purpose: there is no single
# incident today, so it runs the five in sequence, pausing after each one
# for you to write the chain and apply the fix, then calling this
# directory's verify.sh itself before moving on. A plain `./gauntlet.sh N`
# behaves exactly like every prior day's break.sh: inject, print, exit.
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Elapsed-time ledger, kept inside the long-lived `ws` container (not on the
# host) so it survives across separate invocations of this script and of
# verify.sh. Format, one line per event: "START <n> <epoch>" using ws's own
# clock -- see verify.sh, which reads this same file for the scorecard.
TIMES_FILE=/tmp/.gauntlet-times

usage() {
  echo "Usage: $(basename "$0") {1|2|3|4|5|all}" >&2
  exit 1
}

record_start() {
  # $1 = incident number. The leading \$ is escaped so `date` runs inside
  # ws, not on the host -- see the note in common.sh about in_ws/in_app/
  # in_slim taking a single string that is evaluated by the container.
  in_ws "echo \"START $1 \$(date +%s)\" >> ${TIMES_FILE}"
}

# --- incident 1: app -- Days 1 + 3 recombined -------------------------------
# A background process fills the 24m tmpfs on /var/log to ENOSPC, unlinks
# the file while still holding it open (Day 1's mount-tree trick, replayed
# on tmpfs instead of a real disk), then re-execs itself under a misleading
# argv0 via `exec -a` before settling into `sleep infinity`. `ps`'s COMMAND
# column reads argv, so it shows the fake name forever; /proc/PID/comm and
# /proc/PID/exe do not, because neither is derived from argv0.
break_1() {
  in_app '
    exec -a app-healthcheck sh -c "
      exec 9>/var/log/.spool
      dd if=/dev/zero of=/proc/self/fd/9 bs=1M >/dev/null 2>&1
      rm -f /var/log/.spool
      exec -a app-healthcheck sleep infinity
    " >/tmp/incident1.out 2>&1 &
  '
  symptom "app: GET /log?n=5 answers 507 (write failed, no space left on \
device); df on /var/log shows 100% used; nothing visible under /var/log \
is anywhere near large enough to explain it."
}

# --- incident 2: app -- Day 2 recombined ------------------------------------
# SIGSTOP freezes the python process without touching PID 1 (the wrapping
# `sh -c`, per app/Dockerfile). The container looks perfectly healthy from
# the outside -- Docker only tracks whether PID 1 is alive.
break_2() {
  local pypid
  pypid="$(in_app 'pgrep -f "/srv/app[.]py" | tail -1')"
  in_app "kill -STOP ${pypid}"
  symptom "app: 'docker compose ps' shows it Up; every GET request to it \
hangs until the client gives up."
}

# --- incident 3: app -- Day 4 recombined ------------------------------------
# One /burn call pins a background thread against the 0.2-CPU quota for 15
# minutes. A single low-rate probe often still lands in an unthrottled
# instant; a burst of concurrent requests shares the same throttled quota
# and mostly stalls. No memory is touched, so there is no OOM kill.
break_3() {
  in_app 'wget -q -O /dev/null "http://127.0.0.1:8080/burn?seconds=900"'
  symptom "app: one request to /healthz at a time succeeds instantly; a \
burst of 20 back-to-back requests times out for most of them. No restart, \
no OOM kill in the logs."
}

# --- incident 4: app -- Day 5 recombined ------------------------------------
# A setgid directory correctly assigns the group to new files; a umask of
# 077 at creation time still strips the group-read bit the setgid group
# ownership was supposed to grant. root (who ran the deploy) can read the
# file fine, which is exactly why this ships unnoticed.
break_4() {
  in_app '
    addgroup appgrp >/dev/null 2>&1
    adduser -D -H -G appgrp svcuser >/dev/null 2>&1
    mkdir -p /srv/conf.d
    chgrp appgrp /srv/conf.d
    chmod 2770 /srv/conf.d
    (umask 077; printf "db_host=db\ndb_port=5432\n" > /srv/conf.d/app.conf)
  '
  symptom "app: /srv/conf.d/app.conf was written by the last deploy step; \
the service account svcuser gets Permission denied reading it. root can \
read it fine."
}

# --- incident 5: proxy + db -- Day 6 recombined, deliberately two faults ---
# Fault A: listen_addresses is overridden to localhost-only at the end of
# postgresql.conf (Postgres applies the last occurrence of a setting), and
# db is restarted so the postmaster-context change takes effect -- nothing
# outside db's own loopback can reach it any more.
# Fault B, independent of A: a manual /etc/hosts entry on proxy for `db`
# (musl, proxy's libc, always checks /etc/hosts before DNS) points at an
# address that was never db's real one. Fixing A alone changes nothing
# observable, because B still resolves `db` to the wrong place -- that is
# the point of this incident, not a bug in it.
break_5() {
  compose exec -T db sh -c \
    "printf 'listen_addresses = localhost\n' >> /var/lib/postgresql/data/postgresql.conf"
  compose restart db >/dev/null
  compose exec -T proxy sh -c "printf '10.255.255.10 db\n' >> /etc/hosts"
  symptom "proxy: app is reachable and healthy; every attempt to reach db \
from proxy fails, before and after a restart of db."
}

run_one() {
  local n="$1"
  in_ws "touch ${TIMES_FILE}"
  record_start "$n"
  echo "=== incident ${n} ==="
  "break_${n}"
}

main() {
  local arg="${1:-}"
  case "$arg" in
    1|2|3|4|5)
      run_one "$arg"
      ;;
    all)
      for n in 1 2 3 4 5; do
        run_one "$n"
        echo
        read -r -p "Incident ${n}: write the chain, fix it, then press Enter to verify > " _
        "${HERE}/verify.sh" "$n" || true
        echo
      done
      ;;
    *)
      usage
      ;;
  esac
}

main "$@"

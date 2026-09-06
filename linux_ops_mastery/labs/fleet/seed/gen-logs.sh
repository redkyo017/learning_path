#!/bin/sh
# gen-logs.sh -- build a log fixture. RUNS INSIDE THE `app` CONTAINER.
#
#   docker compose -p linuxops exec app sh /labs/fleet/seed/gen-logs.sh 5000 \
#     --needle 4f2a91be
#
# app is Alpine: /bin/sh is busybox ash and awk is busybox awk. Everything
# below is POSIX -- no bash, no GNU awk, no `date -d`.
#
# Usage:
#   gen-logs.sh [LINES] [-n LINES] [--needle REQ_ID] [-o OUT] [--append]
#
#   LINES     how many lines to write            (default 2000)
#   --needle  the request id that gets the one
#             status=500 line                    (default: random 8 hex)
#   -o        output file                        (default: $LOG_PATH, or
#                                                 /var/log/app.log)
#   --append  append instead of truncating
#
# Every line has the same six fields, so `awk '{print $4}'` means the same
# thing on every one of them:
#
#   2026-09-06T12:00:00Z INFO req_id=4f2a91be status=200 latency_ms=37 path=/x
#    $1                   $2   $3             $4         $5             $6
#
# Exactly one line carries status=500, and it carries the needle request id.
# The needle is echoed on stderr, never stdout, so a lab script can capture it
# without it landing in the fixture.
set -eu

LINES=""
NEEDLE=""
OUT=""
APPEND=0

usage() {
  echo "usage: gen-logs.sh [LINES] [-n LINES] [--needle REQ_ID] [-o OUT] [--append]"
}

die() {
  echo "gen-logs: $1" >&2
  exit 2
}

need_value() {
  # $1 = option name, $2 = number of args still on the line
  [ "$2" -ge 2 ] || die "$1 needs a value"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--lines)  need_value "$1" $#; LINES="$2";  shift 2 ;;
    --needle)    need_value "$1" $#; NEEDLE="$2"; shift 2 ;;
    -o|--out)    need_value "$1" $#; OUT="$2";    shift 2 ;;
    -a|--append) APPEND=1; shift ;;
    -h|--help)   usage; exit 0 ;;
    --)          shift ;;
    -*)          usage >&2; die "unknown option: $1" ;;
    *)
      [ -z "$LINES" ] || die "too many positional arguments: $1"
      LINES="$1"
      shift
      ;;
  esac
done

[ -n "$LINES" ] || LINES=2000
case "$LINES" in
  ''|*[!0-9]*) die "line count must be a positive integer, got: $LINES" ;;
esac
[ "$LINES" -gt 0 ] || die "line count must be greater than zero"

[ -n "$OUT" ] || OUT="${LOG_PATH:-/var/log/app.log}"

if [ -z "$NEEDLE" ]; then
  NEEDLE=$(dd if=/dev/urandom bs=4 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
  [ -n "$NEEDLE" ] || die "could not generate a random request id"
fi
case "$NEEDLE" in
  *[!0-9a-f]*) echo "gen-logs: warning: needle is not lowercase hex" >&2 ;;
esac

OUTDIR=$(dirname "$OUT")
[ -d "$OUTDIR" ] || mkdir -p "$OUTDIR" || die "cannot create directory $OUTDIR"

# Clock arithmetic in the shell, because busybox awk has no strftime and
# busybox date has no `-d @epoch` on every build. Strip leading zeros or the
# shell reads 08 as a bad octal literal.
DAY=$(date -u +%Y-%m-%d)
HMS=$(date -u +%H:%M:%S)
HH=${HMS%%:*}
REST=${HMS#*:}
MM=${REST%%:*}
SS=${REST##*:}
SOD=$(( ${HH#0} * 3600 + ${MM#0} * 60 + ${SS#0} ))
# One line per second, ending about now.
START=$(( SOD - LINES + 8640000 ))
SEED=$(( $(date -u +%s) + $$ ))

generate() {
  awk -v n="$LINES" -v needle="$NEEDLE" -v day="$DAY" \
      -v start="$START" -v seed="$SEED" '
    function hex8(   s, i) {
      s = ""
      for (i = 0; i < 8; i++) s = s sprintf("%x", int(rand() * 16))
      return s
    }
    BEGIN {
      srand(seed)
      mark = int(rand() * n) + 1
      for (i = 1; i <= n; i++) {
        t = (start + i) % 86400
        ts = sprintf("%sT%02d:%02d:%02dZ", day,
                     int(t / 3600), int((t % 3600) / 60), t % 60)
        if (i == mark) {
          printf "%s INFO req_id=%s status=500 latency_ms=%d path=/x\n", \
                 ts, needle, 900 + int(rand() * 1500)
        } else {
          id = hex8()
          while (id == needle) { id = hex8() }
          printf "%s INFO req_id=%s status=200 latency_ms=%d path=/x\n", \
                 ts, id, 1 + int(rand() * 250)
        }
      }
    }'
}

if [ "$APPEND" -eq 1 ]; then
  generate >> "$OUT" || die "cannot append to $OUT"
else
  generate > "$OUT" || die "cannot write $OUT"
fi

echo "gen-logs: wrote $LINES lines to $OUT" >&2
echo "gen-logs: needle=$NEEDLE" >&2

#!/bin/bash
# Day 11 detection: the "structured JSON logs + jq" half of the lightweight
# log stack. Tails target's access log and, for every `search_query` line
# whose `query` field matches a classic SQLi payload shape (UNION SELECT,
# a trailing SQL comment, or a tautology like OR 1=1), appends a
# normalized ALERT line to /var/log/detect.log.
#
# This is deliberately NOT the same mechanism as fail2ban/Suricata below --
# it is a plain log-query loop, the simplest possible "lightweight ELK"
# stand-in the Global Constraints ask for (rsyslog/structured JSON + jq).
# Content file Drill 4 asks you to classify this one as signature-based or
# anomaly-based -- read the pattern below before you answer.

set -u

LOG=/var/log/webapp/access.log
OUT=/var/log/detect.log

mkdir -p "$(dirname "$LOG")"
touch "$LOG" "$OUT"

echo "[sqli_watch] watching $LOG for SQLi-shaped queries..." >&2

tail -n0 -F "$LOG" 2>/dev/null | while IFS= read -r line; do
  match=$(printf '%s' "$line" | jq -r '
    select(.event == "search_query") |
    select(
      (.query | test("(?i)union\\s+select")) or
      (.query | test("--")) or
      (.query | test("(?i)\\bor\\b\\s*1\\s*=\\s*1"))
    ) | .query
  ' 2>/dev/null)

  if [ -n "$match" ]; then
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "${ts} ALERT [injection] SQLi-shaped query on /search: ${match}" >> "$OUT"
  fi
done

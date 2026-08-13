#!/bin/bash
# Day 11 `detection` container entrypoint. Starts all three detectors and
# one consolidator, so the learner has a single file to grep at the end:
# /var/log/detect.log.
#
#   1. Suricata, loaded with ONLY rules/suricata/local.rules (the
#      port-scan rule) -- signature-based, network-layer.
#   2. fail2ban, loaded with the target-bruteforce jail/filter (mounted
#      into /etc/fail2ban/...) -- signature-based, log-layer; its own ban
#      action edits THIS namespace's iptables, which is target's real
#      namespace (see docker-compose.yml's `network_mode: service:target`
#      comment for why that's the point, not an accident).
#   3. sqli_watch.sh -- the jq-based structured-log query for the
#      injection replay.
#
# Each detector writes to its OWN native log; this script tails each of
# those and normalizes hits into the one consolidated /var/log/detect.log
# the lab's verify command (and Drill 3) actually greps.

set -u

mkdir -p /var/log/webapp /var/log/suricata
touch /var/log/webapp/access.log /var/log/detect.log

echo "[detection] starting suricata (scan detection: rules/suricata/local.rules)..."
suricata -c /etc/suricata/suricata.yaml \
  -S /etc/suricata/rules/local.rules \
  -i eth0 -l /var/log/suricata --runmode=single &

echo "[detection] starting fail2ban (brute-force detection: target-bruteforce jail)..."
fail2ban-server -xf start &

echo "[detection] starting SQLi log-query watcher (jq over structured JSON logs)..."
/sqli_watch.sh &

echo "[detection] starting alert consolidator -> /var/log/detect.log..."

# Suricata's fast.log gets one plain-text line per alert.
(
  touch /var/log/suricata/fast.log
  tail -n0 -F /var/log/suricata/fast.log 2>/dev/null | while IFS= read -r line; do
    echo "ALERT [scan] $line" >> /var/log/detect.log
  done
) &

# fail2ban's own log names the jail and the banned IP on every ban.
(
  touch /var/log/fail2ban.log
  tail -n0 -F /var/log/fail2ban.log 2>/dev/null | grep --line-buffered -i "Ban " | while IFS= read -r line; do
    echo "ALERT [bruteforce] $line" >> /var/log/detect.log
  done
) &

echo "[detection] up. Alerts consolidate into /var/log/detect.log."

# Keep the container alive as long as ANY one of the background jobs is
# still running (matches other labs' "one long-lived process" pattern).
wait -n

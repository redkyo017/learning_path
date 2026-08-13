# Day 19 target: a deliberately PRE-COMPROMISED Debian host --
# "prod-web01" -- representing a box that already got popped before you
# (the incident responder) arrived. Unlike every earlier day's target,
# this one is not something you attack: every IOC below is planted at
# BUILD time, baked into the image, so the incident already happened and
# your job is triage, not exploitation. See content/day19-ir-forensics.md
# Section 2 and this lab's README.md/SOLUTION.md for the full walkthrough
# and the grep-checks that confirm each IOC below is actually present.
#
# Incident narrative (all timestamps are fixed, planted evidence, not
# live container clock -- see fixtures/*):
#   1. Attacker (203.0.113.77) exploits an unrestricted upload endpoint,
#      drops a webshell (IOC:WEBSHELL), and uses it to run commands.
#   2. Via the webshell, the attacker installs persistence: a disguised
#      cron job (IOC:PERSISTENCE-CRON) that runs a self-healing script
#      (IOC:PERSISTENCE-SCRIPT) which maintains a backdoor account
#      (svc-monitor) and an attacker SSH key in root's authorized_keys.
#   3. The attacker also trojanizes /bin/true (IOC:TROJANIZED-BINARY) --
#      functionally identical, but no longer the original file, which a
#      hash comparison against a pre-tampering baseline will catch.
#   4. root's recovered bash_history and auth.log corroborate the same
#      timeline from two independent sources.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        cron \
        sudo \
        procps \
        coreutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# --- Baseline hashes, captured BEFORE any tampering below. This is what
# a real "known-good" baseline (a package manifest, a prior known-clean
# snapshot, a file-integrity monitor's stored hash) gives you -- something
# to compare the CURRENT state of the host against during triage. ---
RUN mkdir -p /opt/evidence && \
    sha256sum /bin/true /bin/ls /usr/bin/whoami > /opt/evidence/baseline-hashes.txt

# --- IOC:WEBSHELL + initial-access log lines ---
RUN mkdir -p /var/www/html/uploads /var/log/app
COPY fixtures/shell.php /var/www/html/uploads/shell.php
COPY fixtures/access.log /var/log/app/access.log

# --- IOC:TROJANIZED-BINARY (baseline above predates this overwrite) ---
COPY fixtures/trojan-true.sh /bin/true
RUN chmod 755 /bin/true

# --- IOC:PERSISTENCE-SCRIPT + IOC:PERSISTENCE-CRON ---
COPY fixtures/sysmon-check.sh /usr/local/bin/sysmon-check
COPY fixtures/sysmon-check.cron /etc/cron.d/sysmon-check
RUN chmod 755 /usr/local/bin/sysmon-check && chmod 644 /etc/cron.d/sysmon-check

# --- IOC:BACKDOOR-ACCOUNT -- the persistence script's target account,
# already created here so the host reflects "sysmon-check has already run
# at least once" rather than starting from a not-yet-compromised state ---
RUN useradd -m -s /bin/bash svc-monitor && \
    mkdir -p /etc/sudoers.d && \
    echo 'svc-monitor ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/svc-monitor && \
    chmod 440 /etc/sudoers.d/svc-monitor

# --- IOC:SSH-KEY -- likewise already planted, matching the narrative that
# sysmon-check has already run once by the time you start investigating ---
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh
COPY fixtures/authorized_keys /root/.ssh/authorized_keys
RUN chmod 600 /root/.ssh/authorized_keys

# --- Corroborating evidence: recovered shell history + auth.log ---
COPY fixtures/bash_history /root/.bash_history
COPY fixtures/auth.log /var/log/auth.log

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]

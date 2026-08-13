#!/bin/sh
# Simulates forensic ACQUISITION: at boot, copies a read-only snapshot of
# every planted IOC off this "compromised host" into the shared /loot
# volume that the `attacker` container (reused here as the analyst's
# workstation, per this lab's README) also has bind-mounted -- so triage
# happens on a COPY of the evidence, never on the live system itself.
# That is the chain-of-custody principle content/day19-ir-forensics.md's
# Concept section teaches, made concrete: a real responder images the
# disk or snapshots the volume before poking at anything; this container
# does the equivalent with a plain recursive copy at startup.
set -e

EVIDENCE=/loot/day19/evidence
mkdir -p "$EVIDENCE"

cp -a /var/log/app/access.log "$EVIDENCE/access.log"
cp -a /var/log/auth.log "$EVIDENCE/auth.log"
cp -a /etc/cron.d/sysmon-check "$EVIDENCE/sysmon-check.cron"
cp -a /usr/local/bin/sysmon-check "$EVIDENCE/sysmon-check.sh"
cp -a /root/.bash_history "$EVIDENCE/root_bash_history"
cp -a /root/.ssh/authorized_keys "$EVIDENCE/root_authorized_keys"
cp -a /var/www/html/uploads/shell.php "$EVIDENCE/shell.php"
cp -a /etc/passwd "$EVIDENCE/passwd"
cp -a /opt/evidence/baseline-hashes.txt "$EVIDENCE/baseline-hashes.txt"
sha256sum /bin/true /bin/ls /usr/bin/whoami > "$EVIDENCE/current-hashes.txt"

chmod -R a+r "$EVIDENCE"

# Also starts cron for real, so anyone who chooses to exec directly into
# `target` (documented as an optional, secondary path in README.md) can
# watch the persistence mechanism actually fire on its own schedule --
# the acquired copy above is the primary, chain-of-custody-respecting
# path; this is just live realism for the curious.
cron
exec tail -f /dev/null

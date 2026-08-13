# Day 5 target: a deliberately-vulnerable Debian host with THREE separate
# planted privilege-escalation vectors -- see content/day05-privesc.md
# and this lab's README.md for which is primary. Unlike earlier days'
# `target` containers (attacked purely over the network from `attacker`),
# this one is attacked LOCALLY: the lab assumes you already have a
# low-privilege foothold shell as `lowpriv` (today's focus is privesc,
# not initial access -- that's Days 1/7-9's job), reached with
# `docker compose exec target su - lowpriv` run from THIS directory
# (labs/day05), not from labs/base.
#
# Vector 1 (PRIMARY, hands-on in the Attack Lab) -- a SUID `find` binary.
#   GTFOBins: https://gtfobins.github.io/gtfobins/find/
# Vector 2 (secondary, hands-on) -- a passwordless sudo rule for `vim`.
#   GTFOBins: https://gtfobins.github.io/gtfobins/vim/
# Vector 3 (tertiary, hands-on) -- a world-writable script run by root's
#   cron every minute.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        sudo \
        cron \
        findutils \
        vim \
        procps \
        curl \
        auditd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# The foothold account -- represents "you already landed here," not an
# attack surface itself. A weak/guessable password is fine: this lab
# does not attack the login, it starts past it.
RUN useradd -m -s /bin/bash lowpriv && \
    echo 'lowpriv:lowpriv' | chpasswd

# --- Vector 1 (PRIMARY): SUID bit on find ---
# `find` is not supposed to be SUID; a real system's `find /usr/bin/find`
# shows no `s` in its permission bits. Planting this bit turns `find`'s
# already-existing `-exec` feature (used every day, harmlessly, by real
# sysadmins) into an arbitrary-command-as-root primitive, because `-exec`
# runs its command with find's OWN effective privileges, not the caller's.
RUN chmod u+s /usr/bin/find

# --- Vector 2 (secondary): sudo misconfig ---
# lowpriv can run vim as root, no password, no restriction on what vim
# does once it's running -- and vim can trivially shell out.
RUN mkdir -p /etc/sudoers.d && \
    echo 'lowpriv ALL=(root) NOPASSWD: /usr/bin/vim' > /etc/sudoers.d/lowpriv && \
    chmod 440 /etc/sudoers.d/lowpriv

# --- Vector 3 (tertiary): world-writable script on root's crontab ---
# A real ops team might genuinely run a "nightly backup" job as root via
# cron; the bug here isn't that root has a cron job, it's that the SCRIPT
# the job invokes is writable by anyone (mode 777), so any local user can
# rewrite what root will execute on the next tick.
RUN mkdir -p /opt/scripts && \
    printf '#!/bin/sh\n# nightly backup placeholder -- world-writable on purpose (Vector 3)\ntouch /var/log/backup.log\n' \
        > /opt/scripts/backup.sh && \
    chmod 777 /opt/scripts/backup.sh && \
    echo '* * * * * root /opt/scripts/backup.sh' > /etc/cron.d/backup-job && \
    chmod 644 /etc/cron.d/backup-job

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]

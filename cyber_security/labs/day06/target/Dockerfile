# Day 6 consolidation CTF target: a single box chaining three stages —
# web/enum recon (flag1), a crackable password hash (flag2), and a
# classic SUID-`find` privilege escalation to root (flag3). See
# content/day06-ctf-fundamentals.md for the full chain and hints ladder,
# and SOLUTION.md for the exact commands that reproduce all three flags.
#
# Nothing here is a new technique — every stage reinforces something a
# Phase-1 day already taught (Day 1 recon/enum, Day 3 hash cracking,
# Day 5 privilege escalation). This box just chains them into one run.
FROM alpine:3.20

RUN apk add --no-cache openssh sudo findutils shadow bash nginx openssl \
    && ssh-keygen -A

# --- low-priv foothold user ---
# Password below is real and deliberately weak/wordlist-guessable — that
# weakness is the whole point of stage 2. The learner never sees this
# plaintext directly; they discover its MD5 (web/creds.txt) via stage 1's
# enum, then crack it themselves with a wordlist.
RUN adduser -D -h /home/intern -s /bin/bash intern \
    && echo "intern:sk8board99" | chpasswd \
    && passwd -l root

# --- sshd: password auth on (needed for the cracked-password login),
#     direct root login off (root has no usable password anyway) ---
RUN sed -i \
      -e 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' \
      -e 's/^#\?PermitRootLogin.*/PermitRootLogin no/' \
      /etc/ssh/sshd_config

# --- stage 1: recon/enum surface ---
RUN mkdir -p /var/www/html/backup
COPY web/index.html  /var/www/html/index.html
COPY web/robots.txt   /var/www/html/robots.txt
COPY web/flag1.txt    /var/www/html/backup/flag1.txt
COPY web/creds.txt    /var/www/html/backup/creds.txt
COPY nginx.conf       /etc/nginx/nginx.conf

# --- stage 2 payoff: only readable once intern has actually logged in
#     with the cracked password (not exposed over the web) ---
COPY web/flag2.txt /home/intern/flag2.txt
RUN chown intern:intern /home/intern/flag2.txt && chmod 600 /home/intern/flag2.txt

# --- stage 3: the privesc vector + its payoff ---
# Alpine's `findutils` package installs a real GNU `find` binary at
# /usr/bin/find, replacing busybox's limited multi-call version — making
# it SUID root here is the classic, still-current GTFOBins `find` vector:
#   find . -exec /bin/sh -p \; -quit
# spawns a shell that keeps root's effective UID instead of dropping to
# the caller's real UID. `intern` has no sudo rights (verify with
# `sudo -l` — deliberately, so the SUID path is the only way up).
RUN chmod u+s /usr/bin/find
COPY web/flag3.txt /root/flag3.txt
RUN chmod 600 /root/flag3.txt

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22 80
ENTRYPOINT ["/entrypoint.sh"]

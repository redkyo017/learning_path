# Capstone internal host: the Linux box `webapp` was never supposed to
# expose to the internet-facing side of the network at all. Deliberately
# vulnerable: SSH accepts a weak, leaked-by-design password (planted in
# webapp/Dockerfile's ops-notes.txt, discovered via Stage 2's command
# injection), and `opsuser` has a passwordless sudo rule on `python3`
# (GTFOBins: https://gtfobins.github.io/gtfobins/python/) -- a realistic
# leftover from a retired automation script nobody cleaned up.
#
# NOT on the shared `cyberlab` network at all (see docker-compose.yml) --
# `attacker` has no direct route here. The only way in is pivoting
# through `webapp`'s own shell (Stage 3, lateral movement).
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        openssh-server \
        sudo \
        python3 \
        procps \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

ARG OPS_PASSWORD=Fall2024-Temp!

RUN useradd -m -s /bin/bash opsuser && \
    echo "opsuser:${OPS_PASSWORD}" | chpasswd

# Planted misconfig: passwordless sudo on the entire python3 interpreter.
# Anything opsuser can script in Python, root can now run unrestricted --
# GTFOBins' python3 sudo escalation is a one-liner.
RUN mkdir -p /etc/sudoers.d && \
    echo 'opsuser ALL=(root) NOPASSWD: /usr/bin/python3' > /etc/sudoers.d/opsuser && \
    chmod 440 /etc/sudoers.d/opsuser

# Proof-of-root artifact, root-only readable -- confirms the escalation
# actually happened, not just that the sudo rule exists.
RUN printf 'CTF{host-root-via-sudo-python3-gtfobins}\n' > /root/flag_host_root.txt && \
    chmod 600 /root/flag_host_root.txt

# sshd hardening baseline (password auth ON -- intentionally, that's the
# lab's vulnerability; root login OFF and pubkey OFF are just realistic
# defaults so the ONLY way in is the leaked opsuser password).
RUN mkdir -p /run/sshd && \
    ssh-keygen -A && \
    { echo "PasswordAuthentication yes"; \
      echo "PermitRootLogin no"; \
      echo "PubkeyAuthentication no"; \
      echo "UsePAM no"; } >> /etc/ssh/sshd_config

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D", "-e"]

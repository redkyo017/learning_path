# Attacker toolbox — Kali-style container reused by every day-lab.
#
# NOTE ON SIZE: kalilinux/kali-rolling plus this toolset produces a LARGE
# image (multiple GB). The build pulls a full package set (nmap, hashcat,
# john, hydra, sqlmap, tshark, etc.) via apt, so the first build is slow
# and disk-hungry. This is expected and is a one-time cost per machine —
# `docker compose build` caches layers, so subsequent builds are fast
# unless the package list changes.
#
# Fallback: if kalilinux/kali-rolling is unavailable in your environment
# (registry blocked, arch mismatch, etc.), swap the FROM line below for
# `debian:bookworm-slim` and keep the same apt-get install line — every
# package in TOOLS is present in Debian's repos, so the fallback still
# gives a working (if less "Kali-branded") toolbox.
FROM kalilinux/kali-rolling

ENV DEBIAN_FRONTEND=noninteractive

# Kali's rolling repos can be flaky/incomplete for a subset of packages on
# some mirrors; retry once on failure before giving up.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        nmap \
        tcpdump \
        tshark \
        netcat-traditional \
        curl \
        dnsutils \
        john \
        hashcat \
        hydra \
        sqlmap \
        gobuster \
        whatweb \
        jq \
        git \
        openssl \
        iproute2 \
        iputils-ping \
        vim \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work

# Shared output volume — every lab writes findings/captures here so they
# survive `docker compose down` and are inspectable from the host.
VOLUME ["/loot"]

CMD ["sleep", "infinity"]

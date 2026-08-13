# Day 11 `detection` container -- the whole blue-team half of today's lab
# in one lightweight image: Suricata (network-layer signature detection),
# fail2ban (log-layer brute-force detection + ban), and jq (structured
# JSON log queries). No ELK, no Kafka, no heavyweight SIEM -- see
# content/day11-detection.md Section 1 and this lab's README "Resource
# notes" for why that's a deliberate choice, not a shortcut.
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        suricata \
        fail2ban \
        jq \
        curl \
        iproute2 \
        iptables \
        procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/log/suricata /var/log/webapp

COPY sqli_watch.sh /sqli_watch.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /sqli_watch.sh /entrypoint.sh

CMD ["/entrypoint.sh"]

# Day 2 target half #1: `server` runs the plaintext LegacyAuth service
# that `victim` logs into on a loop. `server` is dual-homed: it sits on
# the shared `cyberlab` network (so the attacker container can enumerate
# it directly, same as every other day's target) AND on `day02-mitm`,
# the isolated segment where its cleartext exchange with `victim`
# actually happens. See ../docker-compose.yml for the network wiring.
FROM python:3.12-alpine

# iptables: used only by entrypoint.sh to apply the Day 2 defense-lab
# scan-detection rule (Section 3, Defense 2) before the service starts.
RUN apk add --no-cache iptables

COPY server.py /server.py
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 2121

ENTRYPOINT ["/entrypoint.sh"]

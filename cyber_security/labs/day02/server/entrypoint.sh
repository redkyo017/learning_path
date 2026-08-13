#!/bin/sh
# Day 2 target entrypoint. Baseline (as shipped) applies no firewall
# rule at all -- `server` is wide open to the scan pattern from
# content/day02-networking.md Section 2. The Day 2 defense lab
# (Section 3, Defense 2) asks you to add an iptables scan-detection
# rule right here, then rebuild and re-verify. `iptables` is already
# installed in this image (see Dockerfile) so you only need to add the
# rule itself -- no rebuild-the-base-image step required, just
# `docker compose up -d --build` after editing this file.
#
# Example rule to add above the `exec` line (also in SOLUTION.md, with
# confirmed before/after log output):
#
#   iptables -A INPUT -p tcp --dport 2121 -m conntrack --ctstate NEW \
#     -m recent --name day02scan --set
#   iptables -A INPUT -p tcp --dport 2121 -m conntrack --ctstate NEW \
#     -m recent --name day02scan --update --seconds 10 --hitcount 5 \
#     -j LOG --log-prefix "day02-scan-detect: "
set -eu

exec python3 /server.py

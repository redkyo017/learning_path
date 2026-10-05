# Environment probe — results

Probed 2026-10-05 on Docker Desktop 29.8.0, LinuxKit kernel 7.0.12, arm64 (Apple
Silicon), with `bash labs/netlab/probe.sh` inside the `netlab` container.

| # | Feature | Result | Used by |
|---|---|---|---|
| 1 | netns + veth + ping | OK | every day |
| 2 | bridge with `vlan_filtering` + a VLAN on a port | OK | Day 1 |
| 3 | VXLAN pair, ping across the overlay | OK | Day 6 |
| 4 | nft `ip nat` with masquerade | OK | Days 3, 4, 7 |
| 5 | `conntrack -L` inside a namespace | OK | Days 3, 4 |
| 6 | `tc netem` delay | OK | Day 3 |
| 7 | FRR per netns (zebra + bgpd, pathspace = ns), eBGP Established | OK (`frr_up` chowns its pid and pathspace dirs to `frr`) | Days 5, 7 |
| 8 | unbound in a namespace answering `dig` | OK | Days 6, 7 |
| 9 | `ip xfrm` static ESP SA | OK | Day 6 |
| 10 | `/etc/netns/<ns>/resolv.conf` bind | OK | Days 6, 7 |
| 11 | policy-routing tables (VRF-lite) | FALLBACK: policy-routing tables (VRF-lite) — see below | Day 5 `vrf.sh` |
| 12 | GENEVE pair, ping across | OK | Day 6 `geneve.sh` |
| 13 | per-netns `nf_conntrack_tcp_loose` / established-timeout sysctls | OK | Day 3 `lb` |

## Fallbacks in force

- **VRF devices: unavailable.** The kernel config has `# CONFIG_NET_VRF is not set`, so
  `ip link add … type vrf` fails with `Unknown device type` and no module can be loaded.
  Day 5's "TGW in a box" uses policy-routing tables instead (`ip rule iif <attachment>
  lookup <table>`). That is VRF-lite, and it maps onto TGW association and propagation
  one to one.

No other fallback is needed. The FRR compose overlay, the GRE-instead-of-VXLAN path
and the `dig @server` path were not required.

## Review Focus checks (controller, live)

- `topo_down` twice in a row: no error.
- `require_topo 01` with nothing up: prints the `topo.sh up` hint, exit 2.
- `require_netlab` on the macOS host: prints the enter-container commands, exit 2.
- `labs/verify-teardown.sh`: exit 1 while netlab runs, exit 0 after `docker compose -p netlab down`.

## Verification log

Whole-course live re-run, 2026-10-05, after `docker compose -p netlab build --no-cache`:

| Lab | Healthy / broken / fixed (verify exit codes) |
|---|---|
| Day 1–6 `topo.sh` + `break.sh` + SOLUTION fixes | 0 / 1 / 0 for every day |
| Day 4 `inspection.sh` | asym → curl FAILED (fwb invalid > 0); appliance → HTTP 200 |
| Day 5 `vrf.sh` | after `leak`: prod↔dev ✗, prod/dev ↔ shared ✓ |
| Day 6 `geneve.sh` | 3/3 pings through the GENEVE appliance |
| Day 7 gauntlet incidents 1–5 | `check` 1 after `start`, 0 after the ANSWERS fix, for all five |
| Leftovers after teardown | 0 namespaces, 0 zebra/bgpd/unbound/python3 |
| `probe.sh` | 13/13 OK |

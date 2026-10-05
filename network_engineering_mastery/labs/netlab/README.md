# netlab — the lab box

Every lab in this course runs inside one container named `netlab`. Inside it, each
topology is a set of bare Linux network namespaces (hosts, routers, switches) that the
day's `topo.sh` builds and `topo.sh down` removes. You never touch your Mac's network, and nothing else on your Mac changes, except the course
folder, which is bind-mounted read-write at /course.

## Bring it up and down

From the host:

```bash
cd network_engineering_mastery/labs/netlab
docker compose -p netlab up -d --build     # first build takes a few minutes
docker compose -p netlab exec netlab bash  # you land in /course
docker compose -p netlab down              # when you are done for the day
```

After `down`, run `bash labs/verify-teardown.sh` on the host. It exits 0 when no netlab
container is left.

## Why the container is privileged

`ip netns add` mounts files under `/run/netns` and remounts `/sys` for each namespace.
`nft`, `tc`, `conntrack` and `ip xfrm` need `NET_ADMIN` inside every namespace you
create. A normal container has neither. `privileged: true` grants both; the blast radius
is the container's own network stack and the Docker VM, not your Mac, except the course
folder, which is bind-mounted read-write at /course.

## What is in the image

`iproute2`, `tcpdump`, `tshark`, `nftables`, `conntrack`, `iperf3`, `curl`, `dig`, `traceroute`, FRR, `unbound`, and, for Day 0, `dnsmasq` (DHCP server and DNS forwarder) and `dhcpcd` (DHCP client). The list is in the `Dockerfile`.

## Where commands run

All lab commands run inside the container, from `/course`. `/course` is the course root
(`network_engineering_mastery/`) bind-mounted from your Mac, so your `journal.md` and the
scripts are the same files on both sides. A script started on the Mac prints the two
commands to enter the container and exits 2.

## State files in `/run/netlab/`

| File | Written by | Meaning |
|---|---|---|
| `dayNN.up` | `topo.sh up` | Topology for day NN is built; `break.sh` and `verify.sh` require it |
| `dayNN.fault` | `break.sh` | Which fault set is injected (`none` when absent) |
| `NAME.pid`, `NAME.log` | `bg` | PID and output of a daemon started inside a namespace |
| `frr-NS/` | `frr_up` | FRR pid files for namespace NS |

`topo_down` deletes every namespace, kills every process inside one, and empties this
directory. It is safe to run twice.

## The probe failed

Run the probe after the first build:

```bash
docker compose -p netlab exec -T netlab bash labs/netlab/probe.sh
```

You want thirteen `OK` lines and exit 0. A `MISSING` line means your Docker host's
kernel lacks that feature (Docker Desktop and Colima ship different kernels). Open
`PROBE.md` in this folder: for each feature it records `OK` or `FALLBACK: <what to do>`,
and the day files follow those fallbacks.

## Features the kernel may not have

VRF devices (`ip link add ... type vrf`) are unavailable on Docker Desktop's kernel
(`CONFIG_NET_VRF` is not set). The course uses per-table policy routing instead
(`ip route ... table 10` plus `ip rule ... lookup 10`), also called VRF-lite. The probe
checks that this works.

## Apple Silicon (arm64)

Every package in the Dockerfile is published for both amd64 and arm64, so the image
builds natively on an M-series Mac. No emulation flags are needed.

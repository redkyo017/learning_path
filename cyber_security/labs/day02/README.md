# Day 2 Lab — Enumerate, Capture, and MITM `server`/`victim`

## Authorized use only

This lab's `server` and `victim` containers exist only to be enumerated, captured, and
ARP-spoofed by the shared `attacker` toolbox, and only over the `cyberlab` network and
this lab's private `day02-mitm` segment. ARP spoofing is disruptive and, against a
network you don't own or don't have explicit written authorization to test, illegal.
Only ever run any of this against containers this learning path starts, or your own AWS
sandbox account (Phase 3+).

## What this lab is

`labs/day02/docker-compose.yml` adds two services. It does **not** redefine the
`attacker` service — that container is shared infrastructure, already running from
Day 0 (`labs/base`).

- **`server`** ([`server/`](server)) — a tiny Python service on port 2121 speaking a
  deliberately plaintext protocol ("LegacyAuth": banner → `USER` → `331` → `PASS` →
  `230`, the same shape as real FTP's control channel). `server` is **dual-homed**: it
  sits on both `cyberlab` (so the attacker can enumerate it directly, the same as every
  other day's target) and `day02-mitm`.
- **`victim`** ([`victim/`](victim)) — logs into `server`'s LegacyAuth service on a
  5-second loop, sending a real username and password in cleartext each time.
  `victim` is on **`day02-mitm` only** — it is not reachable from `cyberlab` at all.

### The isolated segment (`day02-mitm`)

`day02-mitm` is a bridge network created by this lab's compose file — **not**
`external: true`, **not** shared with any other day. `server`+`victim`'s cleartext
exchange happens entirely inside it, and nothing on it is reachable from outside this
compose project. The shared `attacker` container is **not** on `day02-mitm` by
default — it only has `cyberlab`, inherited from `labs/base`. This is deliberate: the
lab wants "I can enumerate a host on cyberlab" and "I'm on the same L2 segment as its
private traffic" to be two distinct, visible steps rather than one.

To reach `day02-mitm` at all — required for the ARP-spoof/MITM demo, not for the
plain nmap enumeration — connect the attacker container to it manually:

```sh
docker network connect cyberlab-day02-mitm cyberlab-attacker
```

(Reverse it when you're done: `docker network disconnect cyberlab-day02-mitm
cyberlab-attacker`.)

## Setup

**Prerequisite:** the shared toolbox must already be up (Day 0):

```sh
cd cyber_security/labs/base
./up.sh
```

Then bring up today's targets:

```sh
cd cyber_security/labs/day02
docker compose up -d --build
```

## Running `docker compose exec` for this lab

`attacker` is defined in `labs/base/docker-compose.yml`, not in this lab's compose
file. In this environment, `docker compose exec attacker ...` only resolves reliably
when run **from `labs/base`** (running it from `labs/day02` returned `service
"attacker" is not running`, since Compose was looking for an `attacker` service inside
day02's own project). Run every `docker compose exec attacker ...` command below from
`labs/base`:

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "..."
```

## Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "nmap -sS server > /loot/day02.txt && grep -q open /loot/day02.txt && echo ATTACK_OK"
```

**Expected output:** `ATTACK_OK`, and `/loot/day02.txt` (inside the attacker container;
`labs/base/loot/day02.txt` on the host) contains the scan.

## Walkthrough

1. Bring up `labs/base` and `labs/day02` as above.
2. From `labs/base`, work through Section 2 of
   [`content/day02-networking.md`](../../content/day02-networking.md) in order:
   - Step 1 — full enumeration: `nmap -sS server` then `nmap -sS -sV -sC server`
     (the second one legitimately takes over two minutes — see the content file for
     why).
   - Step 2 — capture the scan itself with `tcpdump`/`tshark` and read the
     SYN → SYN-ACK → RST pattern.
   - Step 3 — `docker network connect cyberlab-day02-mitm cyberlab-attacker`, then find
     `server`'s and `victim`'s addresses **on `day02-mitm` specifically**.
   - Step 4 — install `dsniff` ad hoc, ARP-spoof both directions, capture, and read the
     cleartext `USER`/`PASS` exchange out of the pcap.
3. Run the verify command above and confirm `ATTACK_OK`.
4. Read Section 3 (defense) and try the `iptables` scan-detection rule yourself before
   checking `SOLUTION.md`.
5. Clean up: kill the `arpspoof`/`tcpdump` processes inside the attacker container and
   `docker network disconnect cyberlab-day02-mitm cyberlab-attacker` — full commands in
   `SOLUTION.md`. Leaving the attacker permanently attached to `day02-mitm` defeats the
   point of the segment being isolated by default.

Full expected output for every command above, plus the defense-lab rule and its
confirmed log output: [`labs/day02/SOLUTION.md`](SOLUTION.md).

## Teardown

```sh
cd cyber_security/labs/day02
docker compose down -v
```

This removes only `server` and `victim` (and the `day02-mitm` network) — `labs/base`'s
`attacker` container and the `cyberlab` network are untouched, since they're shared
infrastructure other days depend on too. If you connected the attacker to
`day02-mitm` and haven't already disconnected it, do so before or after tearing this
lab down: `docker network disconnect cyberlab-day02-mitm cyberlab-attacker` (harmless
to run even after `day02-mitm` itself is gone — it will simply no-op/error, since there
is nothing left to disconnect from). Tear down `labs/base` separately (`cd ../base &&
./down.sh`) only once you're done with the whole session.

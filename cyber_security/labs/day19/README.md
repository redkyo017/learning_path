# Day 19 Lab — Triage a Pre-Compromised Host

## Authorized use only

This lab's `target` container ("prod-web01") is a deliberately pre-compromised Debian
host, built with every indicator of compromise (IOC) baked in on purpose, for learning
incident response and basic host forensics. Only ever run the commands below against
this lab's own `target` container on the `cyberlab` docker network — never against a
real host, a shared machine, or any system you don't own or don't have explicit
written authorization to investigate. Nothing in this lab is a live, network-reachable
exploit: every IOC is a static artifact planted at build time for you to find, not a
service you attack.

## What this lab is

`labs/day19/docker-compose.yml` adds a single `target` service to the shared
`cyberlab` network created by [`labs/base`](../base/README.md). It does **not**
redefine the `attacker` service — that container is shared infrastructure, already
running from Day 0.

`target` (see [`target/Dockerfile`](target/Dockerfile)) simulates a public web server,
"prod-web01", that was already compromised before you arrived. Every IOC below is
baked into the image at build time, so the incident has already happened by the time
you start — your job is triage and forensics, not exploitation:

- **Initial access** — an unrestricted upload endpoint let an attacker
  (`203.0.113.77`) drop a webshell ([`shell.php`](target/fixtures/shell.php),
  `IOC:WEBSHELL`), logged in [`access.log`](target/fixtures/access.log)
  (`IOC` request lines against `/uploads.php` and `/uploads/shell.php`).
- **Persistence — self-healing cron** — a disguised cron entry
  ([`/etc/cron.d/sysmon-check`](target/fixtures/sysmon-check.cron),
  `IOC:PERSISTENCE-CRON`) runs a script
  ([`sysmon-check`](target/fixtures/sysmon-check.sh), `IOC:PERSISTENCE-SCRIPT`) every
  5 minutes that re-creates a backdoor account and re-adds an attacker SSH key if
  either is ever removed.
- **Persistence — backdoor account + SSH key** — a `svc-monitor` account with
  passwordless `sudo`, and an attacker public key
  ([`authorized_keys`](target/fixtures/authorized_keys), `mallory@c2`) in root's
  `authorized_keys`.
- **Defense evasion — a trojanized binary** — `/bin/true` was silently replaced
  (`IOC:TROJANIZED-BINARY`) with a functionally-identical file that is nevertheless
  not the original — only a hash comparison against a pre-tampering baseline catches
  it.
- **Corroborating evidence** — root's recovered `.bash_history` and
  [`auth.log`](target/fixtures/auth.log) independently confirm the same timeline.

Full IOC-by-IOC detail, exact file paths, and a scripted `grep` check for each one:
[`SOLUTION.md`](SOLUTION.md).

No ports are published to the host — this is a forensics lab, not a network-attack
one.

## How evidence reaches you: acquisition, not live poking

`target` bind-mounts the **same** host loot directory the `attacker` container already
has at `/loot` (`labs/base/loot`). At boot, `target`'s
[`entrypoint.sh`](target/entrypoint.sh) copies every planted IOC into
`/loot/day19/evidence/` — simulating a forensic **acquisition**: a real responder
images the disk or snapshots the volume before touching anything; this container does
the equivalent with a plain recursive copy at startup. That copy is what you
investigate, never the live `target` filesystem directly — the same chain-of-custody
principle [`content/day19-ir-forensics.md`](../../content/day19-ir-forensics.md)'s
Concept section teaches.

## Setup

**Prerequisite:** the shared toolbox must already be up (Day 0):

```sh
cd cyber_security/labs/base
./up.sh
```

Then bring up today's target:

```sh
cd cyber_security/labs/day19
docker compose up -d --build
```

Both `labs/base` (the `attacker` toolbox + the `cyberlab` network) and `labs/day19`
(`target`) need to be up together — `target` joins the same `cyberlab` network as
every other day's lab, even though today's investigation doesn't use it for network
traffic.

## Running `docker compose exec` for this lab

**Primary path — investigate from `attacker`, exactly like every network-facing day:**
`attacker` is defined in `labs/base/docker-compose.yml`, not in this lab's compose
file. Run every command below **from `labs/base`**, reading the acquired evidence
copy, not `target` itself:

```sh
cd cyber_security/labs/base
docker compose exec attacker bash
```

Inside that shell:

```sh
ls -la /loot/day19/evidence
```

**Optional secondary path — live exploration of `target` itself:** if you want to see
the persistence mechanism actually fire on its schedule (cron really runs inside
`target`), you can exec into `target` directly, but you must run it **from
`labs/day19`** (this directory), not from `labs/base` — the mirror image of Day 4's
"wrong directory" gotcha:

```sh
cd cyber_security/labs/day19
docker compose exec target bash
```

Treat this as read-only reconnaissance, not your investigation record — the acquired
copy under `/loot/day19/evidence` is what the incident report and this lab's
`SOLUTION.md` are built from, precisely because a real investigation shouldn't rely on
notes taken by poking at a live, potentially-still-compromised box.

## Verify

Static validation only — this confirms the compose file is well-formed, it does not
build or start anything:

```sh
cd cyber_security/labs/day19
docker compose config -q
```

**Expected output:** nothing (a silent, zero-exit-code pass is `docker compose
config -q`'s success signal).

To confirm the IOCs are actually present in a built image (build required), see the
scripted `grep` checks in [`SOLUTION.md`](SOLUTION.md).

## Walkthrough

1. Bring up `labs/base` and `labs/day19`, as above.
2. From `labs/base`, exec into `attacker` and look at `/loot/day19/evidence/` — this
   is your acquired evidence set. Work through Section 2 of
   [`content/day19-ir-forensics.md`](../../content/day19-ir-forensics.md):
   - Read `access.log` to find the initial-access request(s).
   - Read `auth.log` and `root_bash_history` to corroborate what happened after.
   - Read `sysmon-check.cron` and `sysmon-check.sh` to identify the persistence
     mechanism.
   - Compare `current-hashes.txt` against `baseline-hashes.txt` to catch the
     trojanized binary.
   - Build a timeline from everything above.
3. Copy [`incident-report-template.md`](incident-report-template.md) and fill it in
   with your findings (timeline, initial access, persistence, IOCs, evidence
   preserved).
4. Read Section 3 of the content file (Defense/Eradication) and map each finding to a
   containment + eradication step before checking `SOLUTION.md`.

Full expected findings, every IOC with its exact location, and a filled-in example
incident report: [`SOLUTION.md`](SOLUTION.md).

## Teardown

```sh
cd cyber_security/labs/day19
docker compose down
```

This removes only `target` — `labs/base`'s `attacker` container, the `cyberlab`
network, and the acquired evidence under `labs/base/loot/day19/` are untouched, since
they're shared infrastructure (and your investigation record) other days/sessions
don't need wiped. Tear down `labs/base` separately (`cd ../base && ./down.sh`) only
once you're done with the whole session.

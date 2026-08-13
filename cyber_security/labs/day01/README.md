# Day 1 Lab — Recon the `target` Container

## Authorized use only

This lab's `target` container is deliberately leaky (a stock nginx version banner, a
disclosive HTML comment, and a fake legacy-service banner on port 2121). It runs
nothing exploitable beyond information disclosure. Only ever point the attacker
toolbox at containers this learning path starts on the `cyberlab` docker network — here
or in any other day's lab — or your own AWS sandbox account (Phase 3+). Never target a
system you don't own or don't have explicit written authorization to test.

## What this lab is

`labs/day01/docker-compose.yml` adds a single `target` service to the shared
`cyberlab` network created by [`labs/base`](../base/README.md). It does **not**
redefine the `attacker` service — that container is shared infrastructure, already
running from Day 0.

`target` (see [`target/Dockerfile`](target/Dockerfile)) runs:

- **nginx on port 80** — stock `nginx:1.21-alpine` config, so it reports its real
  version in the `Server` response header. `target/index.html` also carries an HTML
  `<head>` comment naming a fictional CMS/version and an admin email address.
- **A "legacy" service on port 2121** — a background loop (`entrypoint.sh`) that uses
  `busybox nc -l` to accept a connection and immediately send the contents of
  `banner.txt` (a fake, outdated SMTP-style banner), then closes and listens again.

No ports are published to the host — everything is reached container-to-container, by
service name, from the `attacker` container over `cyberlab`.

## Setup

**Prerequisite:** the shared toolbox must already be up (Day 0):

```sh
cd cyber_security/labs/base
./up.sh
```

Then bring up today's target:

```sh
cd cyber_security/labs/day01
docker compose up -d --build
```

## Verify

Run the exact command below (this is the Day 1 lab verify from the implementation
plan), from `cyber_security/labs/base` (where the `attacker` service is defined):

```sh
docker compose exec attacker sh -c "nmap -sV target | tee /loot/day01.txt | grep -q open && echo ATTACK_OK"
```

**Expected output:** `ATTACK_OK`, and `/loot/day01.txt` (inside the attacker container;
`labs/base/loot/day01.txt` on the host) contains the full nmap scan.

## Walkthrough

1. Bring up `labs/base` (if not already running) and `labs/day01` as above.
2. Shell into the attacker container (from `cyber_security/labs/base`): `docker compose exec attacker bash`.
3. Work through the four recon techniques from
   [`content/day01-recon.md`](../../content/day01-recon.md) Section 2, in order:
   - Banner grab: `curl -sI http://target/` and `nc -w2 target 2121`
   - Fingerprint: `whatweb http://target/`
   - DNS: `dig target +short` and `host target`
   - Port sweep: `nmap -sV target`
4. Run the verify command above and confirm `ATTACK_OK`.
5. Read the results as an attack-surface map (Section 2's table) before moving on to
   the defense lab (Section 3) — try applying the three attack-surface-reduction
   changes yourself before checking `SOLUTION.md`.

Full expected output for every command above, plus the defense-lab before/after diffs:
[`labs/day01/SOLUTION.md`](SOLUTION.md).

## Teardown

```sh
cd cyber_security/labs/day01
docker compose down -v
```

This removes only the `target` container (and its image, if you also `docker rmi
cyberlab/day01-target`) — `labs/base`'s `attacker` container and the `cyberlab` network
are untouched, since they're shared infrastructure other days depend on too. Tear down
`labs/base` separately (`cd ../base && ./down.sh`) only once you're done with the whole
session, not just today's lab.

# Day 6 Lab — Consolidation Mini-CTF: the `box` Container

## Authorized use only

`box` is a deliberately vulnerable container built for this learning path: a leaky web
directory, a weak/crackable password hash, and a planted SUID privilege-escalation
vector. Only ever point the attacker toolbox at containers this learning path starts on
the `cyberlab` docker network — here or in any other day's lab — or your own AWS
sandbox account (Phase 3+). Never target a system you don't own or don't have explicit
written authorization to test.

## What this lab is

`labs/day06/docker-compose.yml` adds two services on top of the shared infrastructure
from [`labs/base`](../base/README.md):

- **`box`** — the CTF target (see [`target/Dockerfile`](target/Dockerfile)). A single
  Alpine container running nginx (port 80) and sshd (port 22), with three staged
  artifacts chained together:
  - an nginx-autoindexed `/backup/` directory (named in `robots.txt` but not linked
    from the site) containing `flag1.txt` and `creds.txt` — the recon/enum stage;
  - `creds.txt` holds an MD5 hash for the low-privileged user `intern`, crackable
    against the wordlist this lab stages — the hash-cracking stage; a successful login
    reveals `flag2.txt` in `intern`'s home directory;
  - `/usr/bin/find` has its SUID bit set (Alpine's `findutils` package, not busybox's
    limited version) — a classic, still-current GTFOBins privilege-escalation vector to
    root, where `flag3.txt` lives.
- **`loot-loader`** — a one-shot service (same pattern as
  [`labs/day03`](../day03/docker-compose.yml)) that copies `wordlist.txt` into the
  shared `./loot` bind mount from `labs/base`, so the attacker container can crack
  `creds.txt` against it without you needing to build a wordlist yourself.

This does **not** redefine the `attacker` service — that container is shared
infrastructure, already running from Day 0. No ports are published to the host;
everything is reached container-to-container, by service name, from the `attacker`
container over `cyberlab`.

## Setup

**Prerequisite:** the shared toolbox must already be up:

```sh
cd cyber_security/labs/base
./up.sh
```

Then bring up today's target and stage the wordlist:

```sh
cd cyber_security/labs/day06
docker compose up -d --build
```

(`loot-loader` exits 0 after copying `wordlist.txt` — that's success, not a crash;
there's no long-running process for it to keep alive. `box` stays up as the target.)

## Shell into the attacker toolbox

```sh
cd cyber_security/labs/base
docker compose exec attacker bash
```

## Verify (static, no live run required)

The task-level verification for this lab is config validation only — it does not
require bringing any container up:

```sh
cd cyber_security/labs/day06
docker compose config -q && echo COMPOSE_OK
```

Expected: `COMPOSE_OK`.

## Walkthrough

The CTF itself — capturing `flag1`, `flag2`, and `flag3` unaided — is the drill.
[`content/day06-ctf-fundamentals.md`](../../content/day06-ctf-fundamentals.md) Section
2 gives a hints ladder (nudge → bigger nudge → answer) per flag; try each stage from
the nudge alone before reaching for the next rung. This file's
[`SOLUTION.md`](SOLUTION.md) is the full staged walkthrough with exact commands and
expected output for all three flags — use it to check your work afterward, not as a
shortcut instead of trying.

## Teardown

```sh
cd cyber_security/labs/day06
docker compose down -v
```

This removes only `box` and `loot-loader` (and `box`'s image, if you also `docker rmi
cyberlab/day06-box`) — `labs/base`'s `attacker` container and the `cyberlab` network are
untouched, since they're shared infrastructure other days depend on too. Tear down
`labs/base` separately (`cd ../base && ./down.sh`) only once you're done with the whole
session, not just today's lab.

# Day 5 Lab — Escalate to Root on a Misconfigured Linux Host

## Authorized use only

This lab's `target` container is a deliberately-vulnerable Debian host with three
planted local-privilege-escalation vectors, on purpose, for learning. Only ever run
these commands against the `target` container this lab starts on the `cyberlab`
docker network — never against a real host, a shared machine, or any system you don't
own or don't have explicit written authorization to test. Everything here is a *local*
attack: it assumes you already have a low-privilege shell on the box (today's subject
is privilege **escalation**, not gaining initial access — Days 1, 7, 8, and 9 cover
that).

## What this lab is

`labs/day05/docker-compose.yml` adds a single `target` service to the shared
`cyberlab` network created by [`labs/base`](../base/README.md). It does **not**
redefine the `attacker` service — that container is shared infrastructure, already
running from Day 0.

`target` (see [`target/Dockerfile`](target/Dockerfile)) is a Debian `bookworm-slim`
host with a `lowpriv` user (password `lowpriv`) representing an already-landed
foothold, and three planted vectors:

1. **SUID `find`** (**primary vector**, the Attack Lab's hands-on focus) — `find` has
   its SUID bit set (`chmod u+s /usr/bin/find`), so its already-existing `-exec` flag
   becomes an arbitrary-command-as-root primitive. [GTFOBins:
   find](https://gtfobins.github.io/gtfobins/find/).
2. **Sudo misconfig** (secondary vector) — `/etc/sudoers.d/lowpriv` grants `lowpriv`
   passwordless `sudo` on `/usr/bin/vim`, and vim can shell out with no restriction on
   what it does once running as root. [GTFOBins:
   vim](https://gtfobins.github.io/gtfobins/vim/).
3. **World-writable root cron script** (tertiary vector) — `/etc/cron.d/backup-job`
   runs `/opt/scripts/backup.sh` as root every minute; that script is mode `777`, so
   any local user can rewrite what root executes on the next tick.

No ports are published to the host — this container is reached only via
`docker compose exec`, exactly like every earlier day's target.

## Setup

**Prerequisite:** the shared toolbox must already be up (Day 0):

```sh
cd cyber_security/labs/base
./up.sh
```

Then bring up today's target:

```sh
cd cyber_security/labs/day05
docker compose up -d --build
```

Then (optional but recommended) fetch `linpeas.sh` into the shared loot directory —
see [`tools/README.md`](tools/README.md) for the exact command and why it isn't
vendored in this repo. `target` bind-mounts the same host loot directory `attacker`
does, so once it's downloaded it's immediately visible inside `target` too, with no
extra copy step.

## Running `docker compose exec` for this lab — read this, it differs from Day 4

Every earlier day-lab's attack commands ran `docker compose exec attacker ...` **from
`labs/base`**, reaching `target` only over the network (`curl target:PORT/...`,
`hydra ... target ...`). **Today is different, on purpose:** privilege escalation
happens *locally, on the box you've already landed on* — there's no network hop to
make. So today's foothold and exploitation commands instead run
`docker compose exec target ...`, **from `labs/day05`** (this directory), because
`target` is a service in *this* compose project, not in `labs/base`'s. Running
`docker compose exec target ...` from `labs/base` fails with `service "target" is not
running` — the mirror image of Day 4's `attacker`-from-the-wrong-directory gotcha.

You will still use `attacker` (from `labs/base`) for exactly one thing: downloading
`linpeas.sh`, since `target` has no outbound network access configured and doesn't
need any for this lab's local vectors.

Get your foothold shell:

```sh
cd cyber_security/labs/day05
docker compose exec target su - lowpriv
```

Everything from here on runs inside that shell, as `lowpriv`, unless stated otherwise.

## Verify

```sh
cd cyber_security/labs/day05
docker compose exec target sh -c "test -u /usr/bin/find && echo VULN_PRESENT"
```

**Expected output:** `VULN_PRESENT` — confirms Vector 1 (the SUID bit on `find`) is
actually planted in a freshly built image, independent of whether you've exploited it
yet. `test -u <path>` succeeds exactly when the file has its setuid bit set.

## Walkthrough

1. Bring up `labs/base` and `labs/day05`, and (optionally) fetch `linpeas.sh`, as
   above.
2. Run the verify command and confirm `VULN_PRESENT`.
3. Get your foothold shell (`docker compose exec target su - lowpriv`, from
   `labs/day05`) and work through Section 2 of
   [`content/day05-privesc.md`](../../content/day05-privesc.md):
   - Enumerate by hand (`find / -perm -4000 -type f 2>/dev/null`, `sudo -l`,
     `ls -la /etc/cron.d/ /opt/scripts/`) and/or run `linpeas.sh` if you fetched it.
   - Exploit Vector 1 (SUID `find`) to get a root shell — the primary, fully
     walked-through path.
   - Exploit Vector 2 (sudo `vim`) to get a second, independent root shell.
   - Exploit Vector 3 (writable cron script) to get a third, independent root
     shell — this one takes up to 60 seconds for cron's next tick.
4. Read Section 3 (defense) and apply the fixes yourself (remove the SUID bit, tighten
   or remove the sudo rule, fix the script's permissions) before checking
   `SOLUTION.md`.

Full expected commands and output for every step above, plus the exact
`auditd`-monitoring note: [`labs/day05/SOLUTION.md`](SOLUTION.md).

## Teardown

```sh
cd cyber_security/labs/day05
docker compose down
```

This removes only `target` — `labs/base`'s `attacker` container, the `cyberlab`
network, and anything staged under `labs/base/loot/day05/` are untouched, since
they're shared infrastructure other days depend on too. Tear down `labs/base`
separately (`cd ../base && ./down.sh`) only once you're done with the whole session.

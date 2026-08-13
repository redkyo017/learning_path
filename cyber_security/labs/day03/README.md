# Day 3 Lab — Identify, Crack, and Watch Crypto Leak

## Authorized use only

This lab's `hashes.txt`, `wordlist.txt`, and demo scripts exist only to be attacked
offline, inside the shared `attacker` toolbox, on this machine. Nothing here targets any
network or external system. Only ever run `john`/`hashcat`/cracking tooling against
hashes you own or have explicit written authorization to test — never against a real
password database that isn't yours.

## What this lab is

Unlike Day 1/Day 2, today has **no live network target** — no `target`/`victim`/`server`
container to scan or MITM. This is a crypto/offline-cracking day: the "target" is a
small, fixed set of files, and the tools that attack them (`john`, `hashcat`, `openssl`,
`python3`) already live in the shared `attacker` toolbox from `labs/base`.

- **[`hashes.txt`](hashes.txt)** — five `username:hash` lines: three unsalted MD5
  hashes, two unsalted SHA-1 hashes, of four short, weak plaintext words (one word is
  reused under both algorithms, deliberately — see `content/day03-crypto.md` Drill 2).
- **[`wordlist.txt`](wordlist.txt)** — a small wordlist (20 entries) containing every
  correct plaintext plus common decoy passwords, sized for instant cracking rather than
  for realism.
- **[`ecb_cbc_demo.sh`](ecb_cbc_demo.sh)** — encrypts a fixed, deliberately-repetitive
  plaintext under AES-128-ECB and AES-128-CBC with the same key and hex-dumps both,
  16 bytes per line, so ECB's pattern leakage is visible directly.
- **[`padding_oracle_demo.py`](padding_oracle_demo.py)** — a self-contained,
  dependency-free Python script that runs a real CBC padding-oracle attack loop against
  a toy (non-AES) stand-in cipher, recovering a secret plaintext byte-by-byte using only
  a valid/invalid padding signal. See the script's own docstring for exactly what this
  does and doesn't prove.

### How the shared toolbox sees these files (no `attacker` redefinition)

`docker-compose.yml` in this directory does **not** define an `attacker` service — the
`attacker` container is shared infrastructure defined ONLY in
[`labs/base/docker-compose.yml`](../base/docker-compose.yml), already running since
Day 0. Instead, this lab's compose file defines a single one-shot `loot-loader`
container that:

1. Mounts this directory (`labs/day03/`) read-only.
2. Mounts `labs/base/loot/` (the SAME host directory the already-running `attacker`
   container has mounted at `/loot`) writable.
3. Copies `hashes.txt`, `wordlist.txt`, and both scripts into
   `labs/base/loot/day03/`, sets the right permissions, prints a confirmation line, and
   exits `0`.

Because `attacker` already has that same host directory mounted at `/loot`, the files
show up inside the running `attacker` container at `/loot/day03/` — without the
`attacker` service ever being touched, restarted, or redefined.

## Setup

**Prerequisite:** the shared toolbox must already be up (Day 0):

```sh
cd cyber_security/labs/base
./up.sh
```

Then stage today's lab data:

```sh
cd cyber_security/labs/day03
docker compose up
```

**Expected output:** a handful of `Network`/`Container` creation lines, then
`cyberlab-day03-loot-loader | staged day03 lab data in /loot/day03 on the host at
labs/base/loot/day03`, then `cyberlab-day03-loot-loader exited with code 0`. That exit
code `0` is success — there's no long-running service for this lab.

## Running `docker compose exec` for this lab

Exactly like Day 2: `attacker` is defined in `labs/base/docker-compose.yml`, not in this
lab's compose file. Run every `docker compose exec attacker ...` command **from
`labs/base`**, not from `labs/day03` (running it from `labs/day03` fails with `service
"attacker" is not running`, since Compose looks for an `attacker` service inside this
lab's own project, and there isn't one):

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "ls -la /loot/day03"
```

## Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "john --format=Raw-MD5 --wordlist=/loot/day03/wordlist.txt /loot/day03/hashes.txt >/dev/null 2>&1; john --format=Raw-SHA1 --wordlist=/loot/day03/wordlist.txt /loot/day03/hashes.txt >/dev/null 2>&1; (john --show --format=Raw-MD5 /loot/day03/hashes.txt; john --show --format=Raw-SHA1 /loot/day03/hashes.txt) | grep -q ':' && echo ATTACK_OK"
```

**Expected output:** `ATTACK_OK`.

**Note on `--format`:** running plain `john --wordlist=... hashes.txt` with no
`--format` flag cracks **nothing** here, even though the hashes are trivially weak —
`john`'s default hash-type autodetection guesses the old Windows `LM` format for
32-hex-character hashes in `user:hash` form, ahead of `Raw-MD5`. This is a real tool
quirk, not a lab bug — see `content/day03-crypto.md` Section 2, Step 2 for the full
explanation, and always specify `--format` explicitly once you know the hash length.

## Walkthrough

1. Bring up `labs/base` and `labs/day03` as above.
2. From `labs/base`, work through Section 2 of
   [`content/day03-crypto.md`](../../content/day03-crypto.md) in order:
   - Step 1 — identify each hash's algorithm from its hex length.
   - Step 2 — crack them with `john --format=Raw-MD5` / `--format=Raw-SHA1`, and see
     why the naive no-`--format` command cracks nothing.
   - Step 3 — run `ecb_cbc_demo.sh` and see ECB's repeated ciphertext blocks directly.
   - Step 4 — run `padding_oracle_demo.py` and read its docstring for what the
     conceptual demo does and doesn't prove.
3. Run the verify command above and confirm `ATTACK_OK`.
4. Read Section 3 (defense) and try the salted-bcrypt comparison and the
   counter-mode/GCM comparison yourself before checking `SOLUTION.md`.

Full expected output for every command above, including the cracked plaintexts:
[`labs/day03/SOLUTION.md`](SOLUTION.md).

## Teardown

```sh
cd cyber_security/labs/day03
docker compose down
```

This removes only the (already-exited) `loot-loader` container and its network —
`labs/base`'s `attacker` container, the `cyberlab` network, and the staged files under
`labs/base/loot/day03/` are untouched (the loot files are host-side and gitignored,
same as every other day's `loot/` output). Tear down `labs/base` separately (`cd
../base && ./down.sh`) only once you're done with the whole session.

# Day 3 Lab — Solution / Verify Walkthrough

## Authorized use only

Same notice as [`README.md`](README.md): every command below runs entirely offline,
inside the shared `attacker` toolbox, against the fixed files this lab ships. Nothing
targets a network or an external system. Only ever run this against hashes you own or
have explicit written authorization to test.

## The cracked plaintexts (spoiler)

| User | Hash algorithm | Hash | Plaintext |
|---|---|---|---|
| `alice` | MD5 | `8621ffdbc5698829397d97767ac13db3` | `dragon` |
| `bob` | MD5 | `0571749e2ac330a7455809c6b0e7af90` | `sunshine` |
| `eve` | MD5 | `5fcfd41e547a12215b173ff47fdd3739` | `trustno1` |
| `carol` | SHA-1 | `af8978b1797b72acfff9595a5a2a373ec3d9106d` | `dragon` |
| `dave` | SHA-1 | `b7a875fc1ea228b9061041b7cec4bd3c52ab3ce3` | `letmein` |

Note `alice` and `carol` share the same underlying password (`dragon`) hashed with two
different algorithms — the point made in `content/day03-crypto.md` Drill 2: the hash
type never hides what the plaintext actually was.

## Step-by-step, with actual verified output

All output below was captured from a real run of this lab (`labs/base` up, then
`labs/day03` staged with `docker compose up`). Every `docker compose exec attacker ...`
command below was run **from `labs/base`** — see the README's note on why running it
from `labs/day03` fails with `service "attacker" is not running`.

### 0. Stage the lab data

```sh
cd cyber_security/labs/day03
docker compose up
```

Confirmed output:

```
 Network cyberlab-day03_default  Created
 Container cyberlab-day03-loot-loader  Created
Attaching to cyberlab-day03-loot-loader
 Container cyberlab-day03-loot-loader  Started
cyberlab-day03-loot-loader  | staged day03 lab data in /loot/day03 on the host at labs/base/loot/day03
cyberlab-day03-loot-loader exited with code 0
```

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "ls -la /loot/day03"
```

Confirmed:

```
-rwxr-xr-x 1 root root 2012 ... ecb_cbc_demo.sh
-rw-r--r-- 1 root root  206 ... hashes.txt
-rwxr-xr-x 1 root root 6700 ... padding_oracle_demo.py
-rw-r--r-- 1 root root  162 ... wordlist.txt
```

### 1. Identify the hash types

```sh
docker compose exec attacker sh -c "cat /loot/day03/hashes.txt"
```

Confirmed:

```
alice:8621ffdbc5698829397d97767ac13db3
bob:0571749e2ac330a7455809c6b0e7af90
carol:af8978b1797b72acfff9595a5a2a373ec3d9106d
dave:b7a875fc1ea228b9061041b7cec4bd3c52ab3ce3
eve:5fcfd41e547a12215b173ff47fdd3739
```

`alice`/`bob`/`eve` are 32 hex characters (16 bytes) → MD5. `carol`/`dave` are 40 hex
characters (20 bytes) → SHA-1.

### 2. Crack them with `john`

**The naive command first, to see the real gotcha:**

```sh
docker compose exec attacker sh -c "john --wordlist=/loot/day03/wordlist.txt /loot/day03/hashes.txt"
```

Confirmed output (abbreviated — a long block of `Warning: detected hash type "LM" ...`
lines precedes this):

```
Loaded 6 password hashes with no different salts (LM [DES 128/128 ASIMD])
Warning: poor OpenMP scalability for this hash type, consider --fork=14
Warning: Only 10 candidates left, minimum 1792 needed for performance.
0g 0:00:00:00 DONE (...) 0g/s 1000p/s 1000c/s 6000C/s ...
Session completed.
```

**Zero cracked.** `john` guessed `LM` (an old Windows hash format that also happens to
be 32 hex characters when written `user:hash`) ahead of `Raw-MD5`, and never even
attempted the two 40-character SHA-1 lines under that guess. This is the exact gotcha
`content/day03-crypto.md` names in Section 2, Step 2 — not a broken lab.

**With `--format` specified, as Step 1's hash-length identification tells you to:**

```sh
docker compose exec attacker sh -c "john --format=Raw-MD5 --wordlist=/loot/day03/wordlist.txt /loot/day03/hashes.txt"
```

Confirmed output:

```
Using default input encoding: UTF-8
Loaded 3 password hashes with no different salts (Raw-MD5 [MD5 128/128 ASIMD 4x2])
Warning: no OpenMP support for this hash type, consider --fork=14
Press Ctrl-C to abort, or send SIGUSR1 to john process for status
dragon           (alice)
sunshine         (bob)
trustno1         (eve)
3g 0:00:00:00 DONE (...) 300.0g/s 1000p/s 1000c/s 3000C/s password..iloveyou
Use the "--show --format=Raw-MD5" options to display all of the cracked passwords reliably
Session completed.
```

```sh
docker compose exec attacker sh -c "john --format=Raw-SHA1 --wordlist=/loot/day03/wordlist.txt /loot/day03/hashes.txt"
```

Confirmed output:

```
Loaded 2 password hashes with no different salts (Raw-SHA1 [SHA1 128/128 ASIMD 4x])
Using default input encoding: UTF-8
Warning: no OpenMP support for this hash type, consider --fork=14
Press Ctrl-C to abort, or send SIGUSR1 to john process for status
dragon           (carol)
letmein          (dave)
2g 0:00:00:00 DONE (...) 200.0g/s 800.0p/s 800.0c/s 1200C/s letmein..monkey
Use the "--show --format=Raw-SHA1" options to display all of the cracked passwords reliably
Session completed.
```

All five cracked instantly, matching the table above.

**Show everything cracked so far:**

```sh
docker compose exec attacker sh -c "john --show --format=Raw-MD5 /loot/day03/hashes.txt; john --show --format=Raw-SHA1 /loot/day03/hashes.txt"
```

Confirmed:

```
alice:dragon
bob:sunshine
eve:trustno1

3 password hashes cracked, 0 left
carol:dragon
dave:letmein

2 password hashes cracked, 0 left
```

### 3. ECB vs CBC pattern leakage

```sh
docker compose exec attacker sh -c "/loot/day03/ecb_cbc_demo.sh"
```

Confirmed output:

```
Plaintext, 16 bytes (one AES block) per line:
AAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAA
BBBBBBBBBBBBBBBB

== AES-128-ECB ciphertext (same key, no IV) ==
dd4b1a0b47daa7067d0b59d95d58a6ae
dd4b1a0b47daa7067d0b59d95d58a6ae
dd4b1a0b47daa7067d0b59d95d58a6ae
dd4b1a0b47daa7067d0b59d95d58a6ae
87f815ad0e513346e0afe99814b1a504

== AES-128-CBC ciphertext (same key, fixed IV) ==
b324ef9405e222f1a18c698c96040954
5afd9d1800443dd2d0d41424912b584d
856cb1c0662a33b1ac15ab8bb7a65913
02590c31dc3a41151babbd65ebf1cd95
936aceecebdd00900c2066be55e30788
```

(Note: each ciphertext line as printed by the script is 32 hex characters / 16 bytes —
some lines above may visually wrap depending on your viewer's width, but every line is
exactly one AES block.)

The four identical `AAAAAAAAAAAAAAAA` plaintext blocks produce **four byte-for-byte
identical** ECB ciphertext lines — visible without the key. Every CBC line differs
despite the same repeated plaintext structure.

### 4. Padding-oracle attack (conceptual)

```sh
docker compose exec attacker sh -c "python3 /loot/day03/padding_oracle_demo.py"
```

Confirmed output:

```
Secret plaintext (attacker does NOT get this):
  b'padding-oracles leak plaintext without ever needing the key!'

Ciphertext the attacker DOES have (64 bytes):
  b9aaadaba0a5aeeab6a9b8bcb5beaae7d4cdcfc485d3c583d6cdc7d5c0c48580bcbba4aff5a1e2eea9a2bef9a3afeff4d4d7c08b84cf80c6cbcdccd4aaa5e4e0

Recovering plaintext one block, one byte, at a time -- using ONLY
the oracle's valid/invalid padding signal (no key, no real decrypt):

  block 0: b'padding-oracles '
  block 1: b'leak plaintext w'
  block 2: b'ithout ever need'
  block 3: b'ing the key!\x04\x04\x04\x04'

Fully recovered plaintext:
  b'padding-oracles leak plaintext without ever needing the key!'

Matches the real secret exactly -- recovered with zero knowledge of the key.
```

The trailing `\x04\x04\x04\x04` in block 3 is the PKCS#7 padding itself (4 padding bytes,
each with value `4`) — stripped correctly by the script's final `pkcs7_unpad_or_raise`
call before printing the fully recovered plaintext.

### 5. Verify command

```sh
docker compose exec attacker sh -c "john --format=Raw-MD5 --wordlist=/loot/day03/wordlist.txt /loot/day03/hashes.txt >/dev/null 2>&1; john --format=Raw-SHA1 --wordlist=/loot/day03/wordlist.txt /loot/day03/hashes.txt >/dev/null 2>&1; (john --show --format=Raw-MD5 /loot/day03/hashes.txt; john --show --format=Raw-SHA1 /loot/day03/hashes.txt) | grep -q ':' && echo ATTACK_OK"
```

**Confirmed output:** `ATTACK_OK`

## Defense lab — with confirmed output

### Defense 1 — Salted KDF hashing

```sh
docker compose exec attacker sh -c "apt-get update -qq && apt-get install -y --no-install-recommends python3-bcrypt"
docker compose exec attacker sh -c "python3 -c \"import bcrypt; h1=bcrypt.hashpw(b'dragon', bcrypt.gensalt()); h2=bcrypt.hashpw(b'dragon', bcrypt.gensalt()); print(h1); print(h2); print('different:', h1 != h2)\""
```

Confirmed output:

```
b'$2b$12$NrAvyTTpn7k/evvm78sTrev9yoTL3C9utP4djSqy3iTucRkMiqw/m'
b'$2b$12$8V6ALGoTn9TqXyzlKkIDuODYDWlF8bh3IpCHV/GBNH/BqkJ20kKJ.'
different: True
```

Two completely different stored hashes for the identical password `dragon` — the salt
(embedded in bcrypt's own `$2b$12$...` output format, visible as the characters right
after the cost factor `12$`) guarantees this. Today's `john --wordlist` attack, run
against hashes like these, would have to pay bcrypt's deliberately expensive
computation once per guess per hash, instead of hashing the wordlist once and comparing
for free against every target — the entire reason MD5/SHA-1 (Section 2) were crackable
in milliseconds and this would not be.

### Defense 2 — Counter-mode confidentiality (the mechanism GCM/AEAD builds on)

```sh
docker compose exec attacker sh -c "printf 'confidential business data, repeated: confidential business data, repeated' | openssl enc -aes-128-gcm -K 000102030405060708090a0b0c0d0e0f -iv 00112233445566778899aabb"
```

Confirmed: `openssl enc` **refuses** this outright —

```
enc: AEAD ciphers not supported
enc: Use -help for summary.
```

confirming the content file's note that the plain `enc` CLI subcommand has no path to
GCM/AEAD (it needs separate authentication-tag handling that `enc` was never built for).
The confidentiality half of GCM — its underlying counter-mode keystream — **is**
demonstrable via CLI:

```sh
docker compose exec attacker sh -c "printf 'confidential business data, repeated: confidential business data, repeated' | openssl enc -aes-128-ctr -K 000102030405060708090a0b0c0d0e0f -iv 00112233445566778899aabbccddeeff | od -An -tx1 -v"
```

Confirmed output (no repeating structure at all, despite the deliberately repeated
plaintext):

```
 0a ab 8e be 03 1f 61 5e ac a4 d6 ec 50 d6 b0 29
 b4 16 e2 4e d9 7d e3 99 90 f6 92 d5 33 7b be 57
 f7 04 76 db 21 31 0f 22 57 4e dd d9 06 cb 5a e9
 18 cf b9 6f de 4e 55 7f 2b db 06 de 9c 7b 9a 16
 69 d1 22 78 49 e0 34 24 da df
```

### Defense 3 — TLS hardening checklist

Not re-run as a command (no live TLS endpoint in this lab) — apply the checklist in
`content/day03-crypto.md` Section 3, Defense 3 directly against a real server, ideally
one from this path's earlier TLS/certificate content if you completed it.

## If something doesn't match

- **`john` cracks nothing at all, even with a wall of warnings:** you omitted
  `--format=Raw-MD5`/`Raw-SHA1` — see Section 2 above; this is expected behavior of the
  no-`--format` command, not a broken lab.
- **`docker compose exec attacker ...` fails with `service "attacker" is not
  running`:** you're running it from `labs/day03`. Run it from `labs/base` instead.
- **`ls /loot/day03` shows nothing:** `labs/day03`'s `docker compose up` hasn't been run
  yet (or was run from the wrong directory) — see Setup in `README.md`.
- **`openssl enc -aes-128-gcm ...` fails with `AEAD ciphers not supported`:** expected —
  see Defense 2 above; use the `-aes-128-ctr` command instead for the CLI-demonstrable
  half of GCM's confidentiality mechanism.
- **`pip3`/`pip` not found:** the attacker toolbox doesn't ship pip by default; use
  `apt-get install python3-bcrypt` (Defense 1) rather than `pip install bcrypt`.

## Answers reused from the content file

All three drills and their solution sketches for Day 3 live in
[`content/day03-crypto.md`](../../content/day03-crypto.md) Section 4.

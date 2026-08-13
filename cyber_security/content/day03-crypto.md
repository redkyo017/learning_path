# Day 3 — Cryptography for Security

## Objectives

By the end of today you should be able to:

- Explain the difference between **hashing** and **encryption** precisely enough to say
  which one you'd use for password storage versus which one you'd use for a message you
  need to read again later — and why using the wrong one for either job is a real,
  common vulnerability class, not a style choice.
- Identify a hash's algorithm from its raw form (length in hex characters) well enough to
  pick the right cracking tool, and know why a cracking tool's own default guess can
  still be wrong.
- Crack unsalted MD5/SHA-1 hashes with `john` given a wordlist, and say in one sentence
  why the exact same attack does nothing useful against a modern, salted, KDF-hashed
  password database.
- Demonstrate — not just describe — why **ECB** mode leaks plaintext structure, using
  your own eyes on real ciphertext bytes.
- Walk through, conceptually, how a **padding-oracle** attack recovers plaintext from
  CBC-mode ciphertext without ever learning the key, and why that's a real historical
  attack class and not just a textbook curiosity.
- Name the specific fix for each weakness attacked today — salted KDF hashing, AEAD
  encryption, and a TLS-hardening checklist — and say honestly which of those today's
  lab actually re-verifies versus which is described and left to apply yourself.

## 1. Concept — Hashing vs. Encryption, and Where Real Systems Break

### Two different jobs, constantly confused

**Hashing** and **encryption** solve two different problems, and using the wrong one for
a job is one of the most common real-world crypto mistakes:

| | Hashing | Encryption |
|---|---|---|
| **Direction** | One-way — there is no "unhash" | Two-way — decrypt gets you the original back |
| **Answers the question** | "Does this match what I expect?" (integrity, password checks) | "Can only the intended party read this?" (confidentiality) |
| **Needs a key?** | No (a **KDF**, covered below, adds a per-user **salt**, which is *not* secret) | Yes — the whole point is that only the key holder can reverse it |
| **Right tool for passwords** | A slow **KDF** (bcrypt/argon2) — see below | Never — you should never be able to "decrypt" a password back to plaintext at all |
| **Right tool for "send this so only Bob can read it"** | Never — hashing can't be reversed even by the legitimate recipient | Yes — symmetric or asymmetric, depending on the situation (next section) |

A **hash** takes input of any size and produces a fixed-size **digest**, deterministically
(same input → same digest, always) and unpredictably (a one-character change in the
input produces a wildly different digest, with no way to predict how). A good
cryptographic hash also has no known way to go backward from digest to input, and no
known way to find two different inputs that produce the same digest (a **collision**).
MD5 and SHA-1 — today's targets — are both cryptographically **broken** for collision
resistance (real, practical attacks exist), but that's not actually why they're wrong
for *password* storage; they're wrong for that job because they're **fast**, and fast is
exactly the property an attacker wants when brute-forcing billions of guesses per
second. That's the gap Section 2 exploits directly.

### Symmetric vs. asymmetric — and the bridge to what you already know

If you've been through this path's TLS/certificate content already, you've seen both of
these ideas in action inside a real handshake; today names them explicitly as
primitives on their own:

- **Symmetric encryption** (e.g. AES) uses the *same* key to encrypt and decrypt. Fast,
  simple — and it requires both parties to already share that key through some secure
  channel, which is a hard problem on its own.
- **Asymmetric encryption** (public-key encryption, e.g. RSA/ECC) uses a *key pair*: a
  public key anyone can use to encrypt (or verify a signature), and a private key only
  the owner holds, used to decrypt (or sign). It solves the key-distribution problem —
  no secret has to travel anywhere — but it's dramatically slower per byte.

Real protocols use both, playing to each one's strength: a TLS handshake uses
asymmetric operations (certificates, key exchange) *only* to establish a shared secret,
then switches to fast symmetric encryption (AES-GCM, in modern TLS) for the actual data.
Today's lab lives entirely in the symmetric-encryption half of that picture — the ECB/CBC
modes below are exactly what "the actual data" gets encrypted with once a symmetric key
exists.

### Where crypto actually breaks in practice

Real-world crypto failures are almost never "someone broke AES." They're almost always
one of these four, and today's lab attacks the first two directly:

1. **Weak or unsalted hashes for passwords** — using MD5/SHA-1 (fast, general-purpose)
   instead of a KDF, and/or skipping the per-user **salt**. Section 2's crack lab.
2. **ECB mode, or another pattern-leaking construction** — encrypting structured data
   block-by-block with no chaining, so repeated plaintext structure shows up directly in
   the ciphertext. Section 2's ECB-vs-CBC demo.
3. **Bad randomness** — a predictable or reused **IV** (initialization vector), or a key
   generated from a weak random-number source. CBC specifically needs an
   unpredictable IV per message; reusing one leaks the XOR of two plaintexts' first
   blocks to anyone comparing two ciphertexts.
4. **Key reuse / key management failures** — using one key for far more than it was
   scoped for, never rotating it, or storing it next to the data it protects. This is
   the single most common real-world root cause behind crypto-adjacent breaches, and it's
   an operational discipline problem more than a math problem — Section 3 names concrete
   practices for it.

### KDFs: the actual fix for password hashing

A **KDF** (Key Derivation Function) — **bcrypt**, **scrypt**, **argon2** — is a function
purpose-built to turn a password into key material *slowly and expensively on purpose*,
using a tunable **work factor** (iterations, memory cost) that you dial up as hardware
gets faster. A KDF also incorporates a per-user **salt** automatically. The result: an
attacker who steals a KDF-hashed password database still has to pay that same expensive
cost *per guess, per user* — cracking one password no longer cracks every account that
reused it (no salt collision), and the total attack cost against the whole database
scales with the number of accounts, not the speed of a GPU.

### AEAD/GCM: the actual fix for pattern leakage and tampering

**AEAD** (Authenticated Encryption with Associated Data) — most commonly **GCM**
(Galois/Counter Mode) in practice — gives you confidentiality *and* built-in
integrity/authenticity in one pass: any tampering with the ciphertext is detected at
decryption time, without needing to bolt on a separate MAC the way older CBC-based
constructions require. GCM also has **no padding at all** (it's a stream-cipher-style
construction under the hood), which means the padding-oracle attack class Section 2
demonstrates conceptually against CBC simply doesn't apply to it. This is why
`AES-256-GCM` (or `ChaCha20-Poly1305`) is the default recommendation in TLS 1.3 and
essentially every modern protocol: it closes both the ECB pattern-leak problem and the
CBC padding-oracle problem in one primitive.

## 2. Attack Lab — Identify, Crack, and Watch Crypto Leak

**Authorized use only:** everything below runs entirely inside the shared `attacker`
container against files provided in this lab — no network target, no external system.
Never run cracking tools against a real password database you don't own or don't have
explicit written authorization to test.

### What you're attacking

Today's lab is different from Day 2's: there's no `target`/`victim`/`server` container
to scan or MITM. The "target" is a small set of files —
[`labs/day03/hashes.txt`](../labs/day03/hashes.txt),
[`labs/day03/wordlist.txt`](../labs/day03/wordlist.txt), and two demo scripts — that get
staged into the shared `loot` volume and attacked entirely offline with tools already in
the attacker toolbox (`john`, `hashcat`, `openssl`, `python3`).

Bring both labs up (after `labs/base/up.sh` if you haven't already):

```sh
cd cyber_security/labs/base
./up.sh
cd ../day03
docker compose up
```

`labs/day03/docker-compose.yml` does **not** define an `attacker` service — it defines a
one-shot `loot-loader` container that copies today's files into `labs/base/loot/day03/`
(the same host directory the already-running `attacker` container has mounted at
`/loot`) and then exits. Seeing `loot-loader exited with code 0` is success, not a
failure — there's nothing else for this lab to keep running. Full detail on why it's
built this way, and why it deliberately does not touch the `attacker` service, is in
[`labs/day03/README.md`](../labs/day03/README.md).

### Step 1 — Identify the hash types

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "cat /loot/day03/hashes.txt"
```

**What you should see:** five `username:hash` lines. Look at the **length** of each hash
in hex characters — that alone identifies the algorithm family, before you crack
anything:

| Hex length | Bytes | Algorithm |
|---|---|---|
| 32 | 16 | MD5 |
| 40 | 20 | SHA-1 |
| 64 | 32 | SHA-256 |

`alice`, `bob`, and `eve`'s hashes are 32 characters (MD5); `carol` and `dave`'s are 40
characters (SHA-1). This length-based identification is the first real skill here — a
tool like `hashid` or hashcat's `--identify` automates it, but knowing the raw byte
lengths means you're never stuck if only `openssl` is available.

### Step 2 — Crack them with `john` (and the gotcha that makes Step 1 matter)

The naive command is the obvious one:

```sh
docker compose exec attacker sh -c "john --wordlist=/loot/day03/wordlist.txt /loot/day03/hashes.txt"
```

**What you should see:** a wall of `Warning: detected hash type "LM", but the string is
also recognized as ...` messages, `Loaded 6 password hashes ... (LM ...)`, and — after it
finishes — **zero cracked passwords**. This is not a bug in the lab, and it's the whole
reason Step 1 matters: a 32-hex-character hash in `user:hash` form is *also* a valid
shape for an old Windows **LM** hash, and `john`'s default autodetection picks LM over
Raw-MD5 whenever both are plausible for the same input — silently cracking the wrong
thing. Force the correct format explicitly, once per hash type, using what Step 1 told
you:

```sh
docker compose exec attacker sh -c "john --format=Raw-MD5 --wordlist=/loot/day03/wordlist.txt /loot/day03/hashes.txt"
docker compose exec attacker sh -c "john --format=Raw-SHA1 --wordlist=/loot/day03/wordlist.txt /loot/day03/hashes.txt"
```

**What you should see:** `Loaded 3 password hashes ... (Raw-MD5 ...)` cracking `alice`,
`bob`, and `eve` instantly, then `Loaded 2 password hashes ... (Raw-SHA1 ...)` cracking
`carol` and `dave` instantly — all five plaintexts recovered in well under a second,
because unsalted hashes plus a small wordlist give an attacker essentially free wins.
Full confirmed output (including the cracked plaintexts) is in
[`labs/day03/SOLUTION.md`](../labs/day03/SOLUTION.md).

To see everything cracked so far, per format (`--show` without `--format` has the same
LM-guessing problem as cracking does):

```sh
docker compose exec attacker sh -c "john --show --format=Raw-MD5 /loot/day03/hashes.txt; john --show --format=Raw-SHA1 /loot/day03/hashes.txt"
```

### Step 3 — See ECB leak a pattern with your own eyes

```sh
docker compose exec attacker sh -c "/loot/day03/ecb_cbc_demo.sh"
```

This encrypts a fixed plaintext — four identical 16-byte blocks followed by one
different block — under AES-128 in both ECB and CBC mode with the *same key*, then
prints each mode's ciphertext one 16-byte block per line.

**What you should see:** under `AES-128-ECB`, the first **four ciphertext lines are
byte-for-byte identical** — direct visual proof that identical plaintext blocks produce
identical ciphertext blocks, with no key or plaintext knowledge required to notice it.
Under `AES-128-CBC`, all five lines differ, even though the underlying plaintext
structure (four identical blocks) is exactly the same. This is the same leak that makes
the famous "ECB penguin" image demo work — an encrypted bitmap's flat-color regions
(repeating byte patterns) stay visible as repeating ciphertext blocks — just without
needing an image viewer to see it. Confirmed sample output: SOLUTION.md.

### Step 4 — Padding-oracle attack, conceptually, against a real oracle loop

```sh
docker compose exec attacker sh -c "python3 /loot/day03/padding_oracle_demo.py"
```

Read the script's docstring first — it's explicit about what this is and isn't: the
"cipher" inside is a toy XOR stand-in, **not** real AES, chosen so the script has zero
external dependencies. What's real is the **attack loop**: it recovers the entire secret
plaintext one byte at a time, using *only* a valid/invalid padding signal from a
`padding_oracle()` function — never the key, never a real decrypt. Swap the toy
`block_transform` for real AES-128 decryption and the identical attack loop recovers
real AES-CBC plaintext just as completely; the technique depends only on CBC's
block-chaining structure and a leaky oracle, not on how strong the underlying cipher is.

**What you should see:** the script prints the real secret plaintext first (for you to
compare against), then recovers it block by block purely from oracle queries, and
asserts the recovered result matches exactly. This is not a hypothetical: the 2002
Vaudenay padding-oracle attack, and tools like PadBuster built on it, used exactly this
technique against real CBC-mode systems that leaked padding-validity through a
distinguishable error message.

### Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "john --format=Raw-MD5 --wordlist=/loot/day03/wordlist.txt /loot/day03/hashes.txt >/dev/null 2>&1; john --format=Raw-SHA1 --wordlist=/loot/day03/wordlist.txt /loot/day03/hashes.txt >/dev/null 2>&1; (john --show --format=Raw-MD5 /loot/day03/hashes.txt; john --show --format=Raw-SHA1 /loot/day03/hashes.txt) | grep -q ':' && echo ATTACK_OK"
```

Expected: `ATTACK_OK`. Full walkthrough with real captured output for every step above is
in [`labs/day03/SOLUTION.md`](../labs/day03/SOLUTION.md), including the cracked
plaintexts.

## 3. Defense Lab — Salted KDFs, AEAD, and a TLS Hardening Checklist

Three fixes, mapped directly to what Section 2 broke — one you can verify with a
one-line comparison, two that are described precisely enough to apply for real but
aren't re-run as a live verify command in this lab (named honestly, not glossed over).

### Defense 1 — Salted KDF hashing (conceptually re-verified, not a new container)

The direct fix for Step 1–2's crack is never storing a fast, unsalted general-purpose
hash for a password in the first place. Compare, conceptually, what changes:

```
Today's targets (broken):  MD5("dragon")           -> same digest every time, for everyone
A KDF-hashed password:     bcrypt("dragon", salt)   -> different digest per user, even for
                                                         the identical password, and
                                                         deliberately slow to compute
```

`python3-bcrypt` isn't in the attacker toolbox by default — installing it is the same
"add a tool this session needs" pattern Day 2 used for `dsniff`:

```sh
docker compose exec attacker sh -c "apt-get update -qq && apt-get install -y --no-install-recommends python3-bcrypt"
docker compose exec attacker sh -c "python3 -c \"import bcrypt; h1=bcrypt.hashpw(b'dragon', bcrypt.gensalt()); h2=bcrypt.hashpw(b'dragon', bcrypt.gensalt()); print(h1); print(h2); print('different:', h1 != h2)\""
```

**What you should see:** two completely different-looking hashes for the *same*
password `dragon` — proof the salt is doing its job — and both would defeat today's
`john --wordlist` attack outright: john would have to run the (deliberately slow) bcrypt
computation once **per guess, per hash**, instead of hashing each wordlist entry once and
comparing it against every target hash for free.

### Defense 2 — AEAD (GCM) instead of ECB/plain-CBC

The direct fix for Step 3–4 is never using ECB, and preferring AEAD (GCM) over plain CBC
for anything new. `openssl enc` (the CLI subcommand used throughout this lab) doesn't
support AEAD ciphers directly — GCM needs its authentication tag handled separately,
which the plain `enc` interface was never built for (try `-aes-128-gcm` yourself and
confirm it refuses with `AEAD ciphers not supported`). What CLI **can** show you
directly is GCM's underlying confidentiality mechanism — a counter-mode keystream, which
is exactly what makes it immune to Step 3's leak in the first place:

```sh
docker compose exec attacker sh -c "printf 'confidential business data, repeated: confidential business data, repeated' | openssl enc -aes-128-ctr -K 000102030405060708090a0b0c0d0e0f -iv 00112233445566778899aabbccddeeff | od -An -tx1 -v"
```

**What you should see:** ciphertext with no repeating pattern at all despite the
deliberately repeated plaintext — counter mode never encrypts two blocks the same way
twice, even when their content is identical, because each block's keystream depends on
its position (the counter), not just the key. GCM is built on exactly this same
counter-mode idea for confidentiality, then adds an authentication tag on top (which
plain `openssl enc` has no CLI path to demonstrate — a full AEAD demo needs a library
like `cryptography`, not shipped in this toolbox) so any tampering with the ciphertext is
also detected. Because GCM has no padding at all, the padding-oracle technique from
Step 4 has no foothold against it either: there's no padding-validity signal to leak in
the first place.

### Defense 3 — TLS configuration hardening checklist

If you completed this path's earlier TLS/certificate content, this closes the loop
between "the primitives today" and "the protocol that uses them everywhere in
practice." A concrete, applyable checklist, named precisely rather than left vague:

- **Disable TLS 1.0/1.1** — both predate AEAD ciphers being mandatory and have known
  padding-oracle-adjacent weaknesses (e.g. BEAST, against CBC-mode TLS 1.0).
- **Prefer TLS 1.3**, which *removed* CBC-mode ciphers from the protocol entirely —
  only AEAD ciphers (`AES-GCM`, `ChaCha20-Poly1305`) are allowed, closing today's
  Step 3/4 attack classes at the protocol level rather than trusting every
  implementation to avoid them.
- **Disable weak cipher suites** (anything using RC4, 3DES, or export-grade ciphers) in
  server config (`ssl_ciphers` in nginx, `SSLCipherSuite` in Apache).
- **Verify certificate chain and expiry monitoring** are in place — a correct cipher
  suite doesn't help if the certificate itself is the weak point (this path's earlier
  TLS content covers that side in depth).
- **Rotate keys and secrets on a schedule**, and immediately on any suspected exposure —
  the "key reuse" failure mode from Section 1 is an operational habit, not a one-time
  config setting.

Nothing above is re-verified with a lab command today (no live TLS endpoint exists in
this lab) — it's named precisely enough to apply directly against a real server, which
is a different, honest scope than Defenses 1–2's direct comparisons above.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Match algorithms to use-cases

For each scenario below, name the *category* of primitive that fits (hash / KDF /
symmetric encryption / asymmetric encryption / AEAD) and say briefly why:

1. Storing user passwords in a database.
2. Verifying a downloaded file hasn't been corrupted or tampered with in transit.
3. Encrypting a large video file so only someone with a shared secret key can watch it.
4. Establishing that shared secret key between two parties who've never met, over an
   untrusted network.
5. Encrypting API request/response bodies so tampering is detected automatically,
   without a separate integrity check.

**Hint:** the "why" for each should name the *specific property* that primitive has and
the others don't (one-way + slow; one-way + fast; shared key + fast; key pair +
distribution; built-in integrity).

**Solution sketch:**

1. **KDF** (bcrypt/argon2) — needs to be one-way (never recoverable) *and* deliberately
   slow, so a stolen database is expensive to brute-force per guess.
2. **Hash** (e.g. SHA-256) — needs to be one-way and fast; you're not defending against
   brute-forcing a secret, you're just detecting any change, so speed is fine and even
   desirable here.
3. **Symmetric encryption** (AES) — large data, needs to be fast, and a shared key
   already exists (or can be distributed) between the two parties.
4. **Asymmetric encryption** / key exchange — the exact problem it solves: no secret has
   to already exist between the two parties beforehand.
5. **AEAD** (AES-GCM) — the "tampering is detected automatically, without a separate
   integrity check" phrasing is a direct description of what AEAD adds over plain
   symmetric encryption.

### Drill 2 — Crack 3 provided hashes

Using `labs/day03/hashes.txt` and `labs/day03/wordlist.txt`, crack **any 3** of the five
provided hashes with `john`, identifying the correct `--format` for each yourself from
the hash length (Section 2, Step 1) rather than copying the command from this file.

**Hint:** if you get zero cracks and a wall of `LM` warnings, you skipped the
`--format` flag — that's the exact gotcha Section 2 Step 2 named, not a broken lab.

**Solution sketch:** all five crack instantly against the provided wordlist. Full
confirmed output and every cracked plaintext: [`labs/day03/SOLUTION.md`](../labs/day03/SOLUTION.md).
As a spoiler-free self-check: `alice` and `carol`'s underlying passwords are identical
to each other despite having completely different-looking hashes — a direct, concrete
example of "hash type doesn't hide the plaintext" from Section 1, and a preview of why
Drill 3's ECB pattern-leak and Defense 1's salting matter for the same underlying reason
(sameness in the input can still be detected or exploited without breaking the crypto
itself).

### Drill 3 — Explain why ECB leaks

In two or three sentences: explain *specifically* why ECB mode allows an observer to
detect that two plaintext blocks were identical, without knowing the key, and name the
one property CBC adds that fixes it.

**Hint:** name what ECB does to each block (independently vs. chained) — that's the
entire answer — and don't just say "it's insecure," name the actual mechanism, the same
way Section 1 insists on for every concept.

**Solution sketch:** ECB encrypts each fixed-size block of plaintext **independently**,
using the same key for every block and nothing else as input — so `encrypt(key, block)`
is a pure function of the block's content alone, meaning identical plaintext blocks
*must* produce identical ciphertext blocks, every time, for anyone holding the
ciphertext to see directly (Section 2 Step 3 showed this as four identical lines). CBC
fixes this by XORing each plaintext block with the *previous ciphertext block* before
encrypting — so a block's ciphertext depends on everything that came before it in the
message, not just its own content, and two identical plaintext blocks at different
positions produce different ciphertext as long as anything preceding them differs (which
is also why CBC needs a random, non-repeating IV to protect even the very first block).

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name specifically what you cracked (which hashes, which
  algorithm each turned out to be) versus what you only demonstrated conceptually (the
  ECB pattern leak, the padding-oracle recovery) — these were different depths of
  "attack" and it's worth being precise about which was which.
- **How:** walk through identifying the hash types by length, hitting the `LM`
  misdetection gotcha (or avoiding it, if you specified `--format` from the start), and
  running the ECB/CBC and padding-oracle scripts — which single moment made "crypto
  breaks in specific, nameable ways" click hardest for you?
- **What defended it:** of today's three defenses (salted KDF hashing, AEAD/GCM, TLS
  hardening checklist), which did you actually run a command for and see the effect of,
  versus which is a checklist you'd need to apply against a real server to confirm?
- **What confused me:** anything about *why* the padding-oracle attack works without
  ever touching the key, or about why a hash's length alone is enough to identify its
  algorithm, that didn't click on first pass.
- **One thing to revisit:** pick one term from today (hash, salt, KDF, ECB, CBC, GCM,
  AEAD, padding oracle) to re-explain from memory before Day 4, without looking back at
  this file.

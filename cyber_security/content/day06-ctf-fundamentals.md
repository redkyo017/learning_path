# Day 6 — Consolidation Mini-CTF (Fundamentals)

## Objectives

By the end of today you should be able to:

- Approach a box you know nothing about with a repeatable process, instead of randomly
  trying tools.
- Chain four Phase-1 skills into one unaided run: **recon → enumeration → hash cracking
  → privilege escalation**.
- Keep notes disciplined enough, mid-CTF, that you could hand them to someone else and
  they'd know exactly what you'd tried and found.
- Name, for each flag you capture, the single control that would have stopped you —
  turning today's offense back into today's defense reflection.

## 1. Concept — How to Approach an Unknown Box

Every day so far handed you the vulnerability up front (Day 1's leaky banner, Day 3's
`hashes.txt`, Day 4's weak login). Today doesn't. `box` is a single container and you
get nothing but its address on `cyberlab` — the same starting position as walking up to
any unfamiliar target, CTF or real engagement.

The process is the same four steps every day already taught you, run back-to-back
without a content section telling you which one comes next:

1. **Recon/enum first, always.** Don't guess at exploits before you know what's
   actually running. Day 1's lesson — passive/active recon, attack-surface
   enumeration — is the entire first move here, not a warm-up you can skip.
2. **Follow every lead to a file, not a vibe.** "There's probably something in
   `/backup/`" is a hypothesis; `curl`-ing it and reading the response is the
   confirmation. A CTF box hides *artifacts* (files, hashes, credentials) — your job is
   to keep converting hunches into artifacts.
3. **Crack what you find, don't stare at it.** A hash by itself is not a flag. Day 3's
   skill — matching a hash format to a cracking tool and wordlist — is what turns a
   discovered artifact into access.
4. **Enumerate for privesc before you assume you're stuck.** Getting a low-privileged
   shell is progress, not the goal. Day 5's habit — checking `sudo -l`, SUID binaries,
   writable crons — is what turns "I'm in" into "I'm root."

**Note-taking during a CTF** is not optional busywork — it's what makes step 2 above
actually work. Keep a running scratch file (or use `/loot/day06/notes.txt` inside the
attacker container) with three columns as you go: **what I tried**, **what came back**,
**what it suggests I try next**. The value shows up the moment you get stuck: instead
of re-running commands from memory, you re-read what you already know and the next
step is usually already sitting in your own notes.

## 2. The CTF — Three Staged Flags on One Box

**Authorized use only:** everything below targets only the `box` container this lab
starts on `cyberlab`. Never point any of this at a network you don't own or don't have
explicit written authorization to test.

### Toolbox setup

```sh
cd cyber_security/labs/base && docker compose exec attacker bash
```

(Prerequisite, if not already running: `cd cyber_security/labs/base && ./up.sh`, then
separately `cd cyber_security/labs/day06 && docker compose up -d --build` to bring up
`box` and stage the cracking wordlist into `/loot/day06/`. Both `base` and `day06` must
be up on the shared `cyberlab` network — this lab does not redefine the `attacker`
service.)

From inside that shell, every command below targets `box` by its service name.

### Stage 1 — Recon & enumeration → `flag1`

You know nothing about `box` yet except that it's reachable. Start exactly like Day 1
and Day 2: what's open, and what's actually being served.

**Hints ladder:**
- *Nudge:* what does a full-service nmap scan tell you is running on `box`, and which
  of those services is worth reading more closely, not just noting as "open"?
- *Bigger nudge:* one of the two open services is a web server. Web servers can point
  you at paths *they* know about even when nothing on the visible page links to them —
  where do crawlers, and therefore you, learn about paths a site owner wanted hidden
  from search engines but didn't actually protect?
- *Answer:* `nmap -sV box` shows ports 22 (ssh) and 80 (http) open. `curl -s
  http://box/robots.txt` returns `Disallow: /backup/` — a path nobody linked to, but
  named anyway. Requesting it directly (`curl -s http://box/backup/`) returns an
  nginx-autoindexed directory listing containing `flag1.txt` and `creds.txt`.
  `curl -s http://box/backup/flag1.txt` prints `flag1`.

**Defense reflection:** `robots.txt` is a *convention*, not an access control — it
tells well-behaved crawlers not to index a path, but enforces nothing. The actual fix
is either not exposing `/backup/` at all (it shouldn't be under the web root), or
putting real authentication in front of it. `robots.txt` naming a sensitive path is
itself a small attack-surface leak, same lesson as Day 1's version banners: anything
that describes your own infrastructure to an unauthenticated requester is disclosure.

### Stage 2 — Crack the discovered hash → `flag2`

`creds.txt` from Stage 1 is an artifact, not a flag. Turn it into access.

**Hints ladder:**
- *Nudge:* look at the format of what `creds.txt` actually contains — a username, a
  colon, then a string of hex characters. What does the *length* of that hex string
  tell you about which hashing algorithm produced it, and which day already covered
  exactly this identification step?
- *Bigger nudge:* Day 3's cracking pattern was `john`/`hashcat` plus a wordlist against
  a hash of this same format. This lab already staged a wordlist for you at
  `/loot/day06/wordlist.txt` when you brought the lab up — you don't need to build one.
  Once you have the plaintext, what does an account with a *username* and a newly-known
  *password* let you do that `curl` alone doesn't?
- *Answer:* `creds.txt` contains `intern:ec2c4fb3751e98ce1e5f0ab59d82af6d` — a 32-hex
  string, i.e. MD5. Save it locally and crack it:
  ```sh
  echo 'intern:ec2c4fb3751e98ce1e5f0ab59d82af6d' > /loot/day06/creds.txt
  john --format=raw-md5 --wordlist=/loot/day06/wordlist.txt /loot/day06/creds.txt
  john --show --format=raw-md5 /loot/day06/creds.txt
  ```
  This cracks to `intern:sk8board99`. The username+password pair is a login, not just a
  fact — install an SSH client for this session (the attacker toolbox doesn't ship one
  by default, same reasoning as Day 2's on-demand `dsniff` install) and use it:
  ```sh
  apt-get update -qq && apt-get install -y --no-install-recommends openssh-client
  ssh intern@box   # password: sk8board99
  cat flag2.txt
  ```
  `flag2.txt` sits in `intern`'s home directory and is only readable once you're
  actually logged in as `intern` — it was never exposed over the web.

**Defense reflection:** the control that stops this stage isn't "don't use MD5" in
isolation — it's that `intern`'s password was guessable from a small wordlist at all.
A slow, salted KDF (Day 3: bcrypt/argon2) makes offline cracking far more expensive per
guess, but a weak/short/dictionary password loses eventually regardless of hash
strength. The real fix is enforcing password strength at creation time, not just
hashing better after the fact.

### Stage 3 — Privilege escalation to root → `flag3`

You have a shell as `intern` — a real foothold, and also exactly where an unaided CTF
run tends to stall. Enumerate before assuming you're stuck; this is Day 5's habit.

**Hints ladder:**
- *Nudge:* two of the classic Day 5 privesc checks are "can I run anything as root via
  `sudo`?" and "does any binary have its SUID bit set that shouldn't?" Run both checks
  as `intern` — which one actually turns something up?
- *Bigger nudge:* once you've found a SUID binary that isn't normally SUID, the
  question is whether that specific binary has a documented privilege-escalation
  technique. GTFOBins (gtfobins.github.io) catalogs exactly this, indexed by binary
  name, for the SUID case specifically.
- *Answer:*
  ```sh
  sudo -l                       # intern is not in sudoers -- dead end, correctly ruled out
  find / -perm -4000 -type f 2>/dev/null
  ```
  The second command lists `/usr/bin/find` itself among the SUID binaries — unusual;
  `find` is not SUID by default. GTFOBins' `find` entry gives the standard escape for
  exactly this case:
  ```sh
  find . -exec /bin/sh -p \; -quit
  id            # euid=0(root) -- the shell kept root's effective UID
  cat /root/flag3.txt
  ```
  `-p` tells the shell to keep its effective UID instead of dropping to the caller's
  real UID — the one flag that turns "a shell spawned by a root-owned SUID binary"
  into "an actual root shell."

**Defense reflection:** least privilege, directly — nothing should carry the SUID bit
unless it specifically needs to run with the file owner's privileges, and `find` never
needs that. The fix is `chmod u-s /usr/bin/find` (or removing/replacing whichever
binary was mis-permissioned); `auditd` monitoring SUID-binary execution and privileged
process spawns would additionally have *logged* this escalation as it happened, giving
a detection layer even where the misconfiguration itself briefly went unnoticed.

### Verify

```sh
cd cyber_security/labs/day06
docker compose config -q && echo COMPOSE_OK
```

Expected: `COMPOSE_OK`. This confirms the compose file itself is well-formed; the full
staged walkthrough reproducing all three flags with exact commands and expected output
is in [`labs/day06/SOLUTION.md`](../labs/day06/SOLUTION.md).

## 3. Drills

**The CTF above is the drill.** There is no separate exercise set today — capturing
`flag1`, `flag2`, and `flag3` unaided, using only the hints ladder (nudge → bigger
nudge → answer) per stage if you get stuck, is the full Day 6 drill. Attempt each
stage's *nudge* first, then the *bigger nudge* only if the nudge alone doesn't move you
forward, and only read the *answer* once you've genuinely tried both — the value of a
consolidation day is in doing the chaining yourself, not in reading someone else's
chain. [`labs/day06/SOLUTION.md`](../labs/day06/SOLUTION.md) is the complete staged
walkthrough for checking your work afterward, not a shortcut to use instead of trying.

## 4. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** `box` — name specifically what you found at each of the three
  stages (the hidden path, the cracked credential, the privesc vector) rather than
  just "I got all three flags."
- **How:** walk through the four-step process from Section 1 (recon/enum → follow the
  lead → crack → privesc-enumerate) and say honestly which stage you solved from the
  *nudge* alone, which needed the *bigger nudge*, and which needed the *answer* —
  that's a more useful signal than the flags themselves for what to revisit.
- **What defended it:** pick the one defense-reflection point (of the three) you find
  most convincing as an actual control you'd apply on a real system, and say why the
  other two feel comparatively weaker or more conceptual to you right now.
- **What confused me:** anything about *why* `-p` matters for the SUID shell, or about
  why `robots.txt` felt like it should be a security control but isn't, that didn't
  fully click.
- **One thing to revisit:** pick one skill from Days 1–5 (recon, network enum, hash
  cracking, or privesc) that this CTF exposed as your weakest link, and name one
  concrete thing you'll do before Day 12's web CTF to shore it up.

**Phase 1 retro, before moving on:** this is the end of Phase 1 (Days 0–6). Before
starting Phase 2, add a second, larger entry to `journal.md` answering: *of everything
from threat modeling through privilege escalation, which single skill do you trust
yourself to do again today, unaided, with no notes — and which one would you still
need to look up?* Naming the gap honestly now is cheaper than discovering it mid-attack
later.

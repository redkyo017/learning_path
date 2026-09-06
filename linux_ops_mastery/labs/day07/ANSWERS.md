> **SPOILERS.** Do not read until your five chains are written.

This file mirrors `journal.md`'s chain template exactly, one full chain per
incident, so you can compare your own chain against a model one claim by
claim rather than just checking a final pass/fail. Every chain closes with
one extra line `ANSWERS.md` adds beyond the template: the one command that
would have told you most, soonest — the shortest path to the same
diagnosis, in hindsight.

## Incident 1 — tmpfs full, ps lies about who

**Symptom (verbatim, no interpretation):**
`app: GET /log?n=5 answers 507 (write failed, no space left on device); df
on /var/log shows 100% used; nothing visible under /var/log is anywhere
near large enough to explain it.`

**Resource class:** mount tree (Day 1), with the proof landing in the fd
table (Day 3) — the same combination `journal.md`'s own Day 1 example uses,
here on a 24 MiB tmpfs instead of a real disk.

**Chain of evidence:**
1. Claim: `/var/log` really is full, not just slow. | Proof: `docker
   compose exec app df /var/log` → `tmpfs  24.0M  24.0M  0  100% /var/log`.
2. Claim: no named file accounts for it. | Proof: `docker compose exec app
   du -sh /var/log` → a few KB, nowhere near 24 MiB — `du` only walks named
   directory entries, `df` reads the filesystem's live block accounting.
3. Claim: some process holds a deleted file open on this mount, and tmpfs
   will not release those blocks until the last fd on it closes. | Proof:
   `docker compose exec app sh -c 'for p in /proc/[0-9]*/fd; do ls -l "$p"
   2>/dev/null; done | grep "/var/log"'` → one line, `9 -> /var/log/.spool
   (deleted)`, under some PID's fd directory.
4. Claim: that PID is a legitimate healthcheck process, so it's safe to
   leave alone. | Proof this claim is FALSE: `docker compose exec app ps`
   shows that PID's COMMAND as `{sleep} app-healthcheck infinity`. The
   readable part, `app-healthcheck infinity`, is read straight from
   `/proc/PID/cmdline` — argv — and argv0 is exactly what `exec -a`
   overwrites. Nothing there has been proved; it has only been made to
   look proved.
   Note the `{sleep}` prefix, and note that you only get it here by luck.
   busybox `ps` compares the kernel's `comm` (taken from the exec'd
   binary's basename, which `exec -a` cannot touch) against argv0's
   basename, and brackets `comm` when they disagree — so busybox hands you
   the discrepancy for free. Run the same `ps` on `ws`, where procps-ng
   `ps` is installed, and the COMMAND column reads a clean
   `app-healthcheck infinity` with no warning at all. The tool that is
   "better" is the one that hides the lie. Do not build the habit of
   trusting a process name because one implementation happened to flag it;
   build the habit of step 5.
5. Claim: the process is not what its name claims. | Proof:
   `docker compose exec app readlink /proc/<PID>/exe` → `/bin/busybox`.
   `/proc/PID/exe` is a kernel-maintained symlink to the actual executed
   file; it is not populated from argv and `exec -a` cannot touch it. A
   process named "app-healthcheck" that resolves to plain busybox is not a
   healthcheck at all.

**Diagnosis:**
A process launched with `exec -a app-healthcheck` opened `/var/log/.spool`,
filled it to `ENOSPC` with `dd`, unlinked the name while keeping the fd
open, then re-exec'd itself under the same fake name into `sleep infinity`.
The unlink removed the only path pointing at the inode, so `du` and a plain
`ls /var/log` see nothing, but tmpfs still bills every block to the
filesystem as long as fd 9 stays open on it — the exact mechanism from
`journal.md`'s Day 1 entry, on a memory-backed filesystem instead of a
block device. `ps` cannot be trusted to name the holder because its
COMMAND column is argv, and argv0 is attacker- or script-controlled;
`/proc/PID/exe` cannot be spoofed the same way because it is not sourced
from argv at all.

**Fix applied:**
`kill <PID>` on the process holding fd 9. Killing it closes every fd it
held, including the deleted one, and the kernel releases the tmpfs blocks
at that point — no separate "clean the disk" step is needed once the last
reference closes.

**Proof the fix worked (same file re-read):**
`docker compose exec app df /var/log` → back near `0%` used. `docker
compose exec app sh -c 'for p in /proc/[0-9]*/fd; do ls -l "$p" 2>/dev/null;
done | grep "/var/log"'` now returns nothing.

**What I would check first next time:**
Whether anything else on the box was launched with a spoofed argv0 before
trusting `ps` output for identity again — this incident is evidence that at
least one thing in this environment already does that.

**The one command that would have told you most, soonest:**
`docker compose exec app sh -c 'for p in /proc/[0-9]*/fd; do ls -l "$p"
2>/dev/null; done | grep deleted'` — it names the exact fd, the exact
deleted path, and the exact PID in one line, before `ps` ever gets a chance
to mislead you.

## Incident 2 — active per the supervisor, stopped per the kernel

**Symptom (verbatim, no interpretation):**
`app: 'docker compose ps' shows it Up; every GET request to it hangs until
the client gives up.`

**Resource class:** process table (Day 2).

**Chain of evidence:**
1. Claim: the container itself is running. | Proof: `docker compose ps
   app` → `Up`. Docker only tracks whether PID 1 is alive; this proves
   nothing about PID 1's children.
2. Claim: python (not PID 1 — see `app/Dockerfile`'s note on shell-form
   entrypoints) is not making progress. | Proof: `docker compose exec app
   sh -c 'pgrep -f "/srv/app[.]py" | tail -1'` → a PID, then `docker compose
   exec app cat /proc/<PID>/stat | awk -F') ' '{print $2}' | cut -d' ' -f1`
   → `T`. Field 3 of `/proc/PID/stat` is process state; `T` is stopped by a
   job-control signal, distinct from `D` (uninterruptible I/O sleep) or `Z`
   (zombie). The bracket in `app[.]py` is load-bearing, not decoration: the
   `sh -c '...'` wrapper running this very `pgrep` also has `/srv/app.py`
   in its own `/proc/PID/cmdline` (it's sitting right there in the pattern
   string), an unbracketed pattern matches that wrapper too, the wrapper
   started last so it has the higher PID, and `tail -1` would silently
   hand back the wrapper instead of python — the same false-positive shape
   as `ps aux | grep "[p]ython"`.
3. Claim: nothing else on the box is also stuck — this is one process, not
   a system-wide stall. | Proof: `docker compose exec app cat /proc/1/stat
   | awk -F') ' '{print $2}' | cut -d' ' -f1` → `S`, PID 1's own shell is
   sleeping normally, waiting on its child exactly as it should be.

**Diagnosis:**
Something sent `SIGSTOP` to the python process directly. `SIGSTOP` cannot
be caught, blocked, or ignored — `app.py`'s own `SIGTERM` handler is
irrelevant here, because the process was frozen by the kernel before any
handler ever ran. The container's supervisor-level health (Docker's own
"is PID 1 alive" check) has no visibility into this at all, which is
exactly why it kept reporting `Up`.

**Fix applied:**
`kill -CONT <PID>` on the same PID. `SIGCONT` resumes a stopped process
exactly where it left off — no restart, no lost state, no dropped requests
beyond whatever was already queued past its accept backlog while stopped.

**Proof the fix worked (same file re-read):**
`docker compose exec app cat /proc/<PID>/stat | awk -F') ' '{print $2}' |
cut -d' ' -f1` → `S` or `R`. `curl -sf -m 3 http://app:8080/healthz` from
`ws` → `healthy`.

**What I would check first next time:**
Whether the stop was deliberate (a debugger attach, `Ctrl-Z` from an
interactive shell left in the container) or accidental — the fix is
identical either way, but the root cause of *why* something sent `SIGSTOP`
is a different, unanswered question this incident does not close.

**The one command that would have told you most, soonest:**
`awk -F') ' '{print $2}' /proc/<PID>/stat | cut -d' ' -f1` the moment you
have any candidate PID — one character, `T`, rules out every hypothesis
except "this process was stopped," before you spend a minute checking
sockets, logs, or the app's own code.

## Incident 3 — throttled, not crashed

**Symptom (verbatim, no interpretation):**
`app: one request to /healthz at a time succeeds instantly; a burst of 20
back-to-back requests times out for most of them. No restart, no OOM kill
in the logs.`

**Resource class:** cgroup boundary (Day 4) — CPU, not memory.

**Chain of evidence:**
1. Claim: the container was not OOM-killed. | Proof: `docker compose exec
   app cat /sys/fs/cgroup/memory.events` → `oom_kill 0`. This rules out
   Day 4's other failure mode in one line before chasing the wrong one.
2. Claim: the container's CPU quota is being exhausted, not just the box
   being generally busy. | Proof: `docker compose exec app cat
   /sys/fs/cgroup/cpu.stat` → `nr_throttled` is large and still climbing
   between two reads a few seconds apart, and `throttled_usec` is growing
   with it.
3. Claim: the quota itself is small on purpose, not misconfigured. | Proof:
   `docker compose exec app cat /sys/fs/cgroup/cpu.max` → `20000 100000`,
   i.e. 0.2 CPU — matches `cpus: 0.20` in `docker-compose.yml`, so this is
   the fleet's real limit being hit, not a broken limit.
4. Claim: something is continuously consuming CPU inside the container
   right now, not just occasional request load. | Proof: `docker compose
   exec app cat /proc/<python PID>/stat`, read twice a couple of seconds
   apart, shows the utime/stime fields (fields 14/15) climbing at a rate
   close to real elapsed time — a thread is spinning.

**Diagnosis:**
A `/burn` call started a background thread that busy-loops the CPU clock
for its requested duration. Under the container's 0.2-CPU quota,
`cpu.max`'s enforcement throttles the whole cgroup once it exceeds 20% of
each 100 ms accounting period — one low-rate probe often lands in a window
that wasn't throttled yet and succeeds instantly, while a burst of
concurrent requests shares the same throttled quota with the burning
thread and mostly stalls waiting for CPU time that isn't being handed out.
Nothing was OOM-killed because this incident never touches memory.

**Fix applied:**
`docker compose restart app`. There is no endpoint to cancel an in-flight
`/burn`; the thread lives inside the python process's own address space,
so the only clean way to clear it is to replace the process.

**Proof the fix worked (same file re-read):**
`docker compose exec app cat /sys/fs/cgroup/cpu.stat`, read twice a few
seconds apart, now shows `nr_throttled` and `throttled_usec` unchanged
between the two reads. Ten concurrent `curl` calls from `ws` to
`/healthz` all return `200` within a second or two.

**What I would check first next time:**
Whether `/burn` (or whatever the real production equivalent of it is) has
any caller-side limit at all — this incident's actual root cause is a
missing guard on a dangerous endpoint, not the cgroup, which did exactly
what it was configured to do.

**The one command that would have told you most, soonest:**
`cat /sys/fs/cgroup/memory.events` followed immediately by `cat
/sys/fs/cgroup/cpu.stat` — two files, one line each, and they immediately
separate "OOM" from "throttled" before a single minute is spent guessing
between the two from symptoms alone.

## Incident 4 — setgid did its job, umask undid it

**Symptom (verbatim, no interpretation):**
`app: /srv/conf.d/app.conf was written by the last deploy step; the
service account svcuser gets Permission denied reading it. root can read it
fine.`

**Resource class:** the permission model (Day 5) — not one of the four
kernel-file truths on its own, but read the same way: every claim traced to
a stat, not a guess.

**Chain of evidence:**
1. Claim: `svcuser` really cannot read the file, and it's not a typo in the
   path. | Proof: `su -s /bin/sh svcuser -c 'cat /srv/conf.d/app.conf'` →
   `Permission denied`; `cat /srv/conf.d/app.conf` as root → the file's
   contents print fine.
2. Claim: the directory is setgid, so new files should inherit its group.
   | Proof: `stat -c '%A %U:%G' /srv/conf.d` → mode starts with `drwxrws--`
   — the `s` in the group execute position is the setgid bit — owned
   `root:appgrp`.
3. Claim: the file's group ownership did inherit correctly. | Proof: `stat
   -c '%U:%G' /srv/conf.d/app.conf` → `root:appgrp`, matching the
   directory's group exactly as setgid promises.
4. Claim: despite that, the file's permission bits still block the group.
   | Proof: `stat -c '%a' /srv/conf.d/app.conf` → `600` — owner
   read/write, nothing for group or other, even though the group is
   correctly `appgrp` and `svcuser` is a member of it.
5. Claim: a restrictive umask at creation time, not a bad `chmod`
   afterward, produced this. | Proof: no single file proves a umask after
   the fact — the mode `600` is consistent with a file created under
   `umask 077` (which strips all group and other bits regardless of
   setgid) and is not consistent with any of the deploy tooling's
   documented default modes. This is the point where the chain would need
   the actual deploy script's `umask` call to become a proof rather than an
   inference — recorded here as the honest edge of what these three files
   can show on their own.

**Diagnosis:**
The setgid bit on `/srv/conf.d` worked exactly as designed: the new file's
*group owner* became `appgrp`, the group `svcuser` belongs to. Setgid only
controls group ownership of new entries, though — it has no say over the
permission bits a process requests at creation time, and those bits are
still `requested_mode & ~umask`. Whatever ran the deploy step had `umask
077` in effect, which strips every group and other bit no matter what mode
was asked for, so the file landed at `600` despite the directory's setgid
promise. Root could read it throughout, which is precisely why a deploy
that "looked fine" (verified by whoever ran it, as root) shipped broken for
the actual service account.

**Fix applied:**
`chmod 640 /srv/conf.d/app.conf` restores group-read on the existing file.
The durable fix — not exercised by this incident's `verify.sh`, but the
one that actually matters — is correcting the deploy tooling's umask (e.g.
`umask 027`) so every future file in this setgid directory lands
group-readable without a manual `chmod` after the fact.

**Proof the fix worked (same file re-read):**
`stat -c '%a' /srv/conf.d/app.conf` → `640` (or similar, group-read bit
set). `su -s /bin/sh svcuser -c 'cat /srv/conf.d/app.conf'` now prints the
file instead of failing.

**What I would check first next time:**
The umask actually in effect for the deploy pipeline (`umask` with no
arguments, run in the same context the deploy runs in) before touching any
individual file's mode — chmod-ing one file fixes that file and leaves the
next deploy to reproduce the exact same incident.

**The one command that would have told you most, soonest:**
`stat -c '%U:%G %a' /srv/conf.d/app.conf` — one line, and the mismatch
between "group ownership is correct" and "group bits are zero" is visible
immediately, which is what points straight at umask instead of a wrong
`chown`.

## Incident 5 — two faults, and fixing the first one changes nothing

**Symptom (verbatim, no interpretation):**
`proxy: app is reachable and healthy; every attempt to reach db from proxy
fails, before and after a restart of db.`

**Resource class:** mount tree / process table's network cousin — sockets
and name resolution (Day 6), stacked two faults deep.

**Chain of evidence:**
1. Claim: `app` really is reachable from `proxy`, so this is not a
   general network-namespace failure. | Proof: from `proxy`,
   `wget -qO- http://app:8080/healthz` → `healthy`.
2. Claim: `db`'s listener is the first problem. | Proof: `docker compose
   exec db cat /proc/net/tcp | awk '$2 ~ /:1538$/ {print $2}'` (port 5432
   is `0x1538`) → `0100007F:1538`, i.e. bound to `127.0.0.1` only, not
   `00000000:1538` (all interfaces). Nothing outside `db`'s own network
   namespace can reach a loopback-only listener.
3. Claim: fixing the listener alone resolves the incident. | Proof this
   claim is FALSE, and proving it false is the actual work of this
   incident: after correcting `listen_addresses` and restarting `db`, `cat
   /proc/net/tcp` on `db` now shows `00000000:1538` — the listener is
   genuinely fixed — and yet `wget` from `proxy` to `db:5432` still fails
   exactly as before.
4. Claim: `proxy` is not resolving `db` to `db`'s real address at all. |
   Proof: `docker compose exec proxy getent hosts db` (or `cat
   /etc/hosts`) → a line for `db` pointing at `10.255.255.10`. `docker
   compose exec db hostname -i` (or checking the network the compose
   project actually assigned) shows `db`'s real address is something else
   entirely on `linuxops_net`. Alpine's musl libc resolver checks
   `/etc/hosts` before DNS, unconditionally, and this is a manually-added
   entry — Docker's embedded DNS never populates other services' names
   into `/etc/hosts` on a user-defined bridge network in the first place.

**Diagnosis:**
Two independent faults, not one masquerading as two symptoms. Fault A:
`db` was reconfigured to `listen_addresses = 'localhost'`, so it refused
every connection arriving on its container interface regardless of who was
asking. Fault B: `proxy`'s `/etc/hosts` carries a stale manual override for
`db` pointing at an address that was never `db`'s real one, so even a
correctly-listening `db` would still be unreachable from `proxy`, because
the name never resolves to the right place to begin with. Either fault
alone fully explains the symptom; both were present at once, and fixing
only fault A produces a `db` that would accept the connection if the
connection were even attempted at the right address — which, because of
fault B, it never is.

**Fix applied:**
Fault A: correct `listen_addresses` back to `*` (or remove the appended
override entirely, restoring the image's default) and restart `db`. Fault
B: remove the injected line from `proxy`'s `/etc/hosts` so resolution falls
through to Docker's embedded DNS, which has always had the right answer.

**Proof the fix worked (same file re-read):**
`docker compose exec db cat /proc/net/tcp | awk '$2 ~ /:1538$/ {print
$2}'` → `00000000:1538`. `docker compose exec proxy getent hosts db` (or
`grep db /etc/hosts`) → no manual override line; resolution now goes
through DNS. `wget -qO- http://db:5432` from `proxy` (or a real client
against port 5432) now connects instead of failing.

**What I would check first next time:**
Recognizing a two-fault situation, stated explicitly because it is the
hardest lesson in this path: fixing one cause and seeing zero improvement
is *not* evidence the diagnosis was wrong. It is exactly as consistent
with "there is a second, independent fault still masking the first fix" as
it is with "the first diagnosis was mistaken" — and most operators
abandon a correct diagnosis at precisely this moment, because a fix that
visibly does nothing feels like proof of failure. The discipline that
actually resolves this: after a fix that should matter produces no visible
change, re-verify the fix itself at the source of truth (step 3's
`/proc/net/tcp` re-read, done *before* touching anything else) rather than
either reverting it or abandoning the theory. A fix confirmed correct at
its own source, paired with zero end-to-end improvement, is the specific
signature of a second fault — not a wrong first one.

**The one command that would have told you most, soonest:**
`getent hosts db` on `proxy`, run in the very first minute alongside the
`/proc/net/tcp` check on `db` — resolution and the listener are two
independent claims, and checking only one of them is exactly how a
two-fault incident gets misread as a one-fault incident that "didn't
fix."

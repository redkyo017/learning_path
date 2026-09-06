# Day 5 — Identity, permission, and service management

**Truth of the day:** process table — identity is a property of a process,
not of a file, and a service manager's job is to keep the right process
alive with the right identity.
**Budget:** 3 h — 1 h identity and permission model, 1 h systemd, 1 h lab.

## Why this matters

"Permission denied" on a file that is already `0777` is the single most
disorienting failure in this path, because every instinct says the mode
bits are the whole story and they are not — the denial usually lives one
or more directories up the path, invisible to `ls -l` on the file itself.
The reflex under pressure is `chmod 777` on whatever is nearby, which
sometimes clears the symptom by accident while leaving the real cause
undiagnosed. The second half of today, systemd, fails just as silently: a
unit with a plausible-looking `Requires=` line starts in the wrong order
every time, and nothing about the unit file's syntax warns you.

## Read the file first

`/etc/passwd`, one line per user, seven colon-separated fields:

```
appuser:x:1001:1001::/home/appuser:/bin/sh
```

`name:password-placeholder:uid:gid:gecos:home:shell` — field 2 is always
`x` on a modern system, meaning "the real hash lives in `/etc/shadow`."
`/etc/group` mirrors it for groups: `name:x:gid:comma,separated,members`.

`/proc/PID/status` carries the same identity, per process, on two lines:

```
Uid:    1001    1001    1001    1001
Gid:    1001    1001    1001    1001
CapEff: 0000000000000000
```

Four values, always in this order: real, effective, saved-set, and
filesystem. Almost every process has all four equal; a `setuid` binary
mid-execution is the case where they diverge, and that divergence is the
entire mechanism worth understanding (see Core concepts, below). `CapEff`
is a hex bitmask, not a UID — its worked decode lives in the primer, cited
in Strip the toolbox.

`stat -c '%A %U %G %a' <file>` prints the same mode two ways in one line:

```
-rwxr-x---  root  appgroup  750
```

Read the ten `%A` characters left to right: file-type (`-`, `d`, `l`, …),
then three r/w/x triads for owner, group, other. `%a` is the same three
triads re-expressed as one octal digit each: `7` = `rwx`, `5` = `r-x`,
`0` = `---`. Neither format adds information the other lacks; `%a` is
just what you type into `chmod`, and `%A` is what you read at a glance.

## Derive the tool

`id` is a formatter over the `/proc/PID/status` `Uid:`/`Gid:` lines you
just read, printing the current shell's identity as `uid=1001(appuser)
gid=1001(appuser) groups=1001(appuser)` instead of four bare integers.

`ls -l` is a formatter over `stat()`'s mode field, same ten characters as
`%A` above, with owner and group names resolved from `/etc/passwd` and
`/etc/group` instead of printed as raw numbers.

`getcap <path>` reads a file's **stored** capabilities (an extended
attribute on the inode, set by `setcap`) — a different thing from a
running process's `CapEff`, and the tool behind Exercise 4 below.

`capsh --decode=<hex>` turns a raw `CapEff` value into a comma-separated
capability list, when it is installed — it ships in `libcap2-bin`, which
is not part of `ws`'s guaranteed toolbox (only `bsdmainutils`, `dnsutils`,
and `ltrace` are attempted best-effort, and none of those pull it in).
**Stated fallback, everywhere this tool is mentioned:** if
`command -v capsh` fails, read `CapEff` from `/proc/PID/status` directly
and decode it by hand, exactly as Strip the toolbox does below — the hand
decode is never optional, `capsh` only saves you the arithmetic when it
happens to be present.

## Core concepts

**Real vs. effective UID.** The real UID says who invoked the process; the
effective UID (`euid`) says whose permissions the kernel checks on every
access. They are equal for almost every process you will ever run by
hand. A `setuid` binary — mode bit `4000`, shown as `s` in the owner's `x`
slot — changes only the **effective** UID at `exec()` to the file owner's
UID, leaving the real UID as the calling user. `/usr/bin/passwd` is the
canonical example: any user runs it (real UID stays theirs), but it
executes with `euid=0` (root) because it must write `/etc/shadow`, which
ordinary users cannot open at all.

**Mode bits and the directory execute bit.** Every file and directory
carries three r/w/x triads. On a **directory**, `x` does not mean
"execute" in the program sense — it means "may have its contents looked
up by name," i.e. traversal. This is **the most common invisible
denial**: without the execute bit on a directory, path lookup fails for
**every** unprivileged user regardless of the target file's own mode —
owner included. A file at `0777` sitting inside a directory at `0644` is
unreachable to any unprivileged caller, owner or not, because `0644` has
no `x` in any triad and reaching the file requires `x` on every directory
in the path; only root gets past this, and only by bypassing the check
entirely (`CAP_DAC_READ_SEARCH`), not because root has some `x` bit the
file lacks. `ls -l` on the file shows nothing wrong; the file is
innocent. This is exactly today's lab.

**Setgid on directories.** A directory with the setgid bit (`2000`,
shown as `s` in the group `x` slot) makes every file created inside it
inherit the *directory's* group, not the creating user's primary group —
the standard fix for a shared team directory where uploads keep landing
with the wrong group ownership.

**The sticky bit.** On a directory (`1000`, shown as `t` in the other `x`
slot), it restricts deletion and renaming of an entry to that entry's
owner (or root), regardless of the directory's own write permission.
`/tmp` is `1777` for exactly this reason: everyone needs to write into
it, but no one should be able to delete another user's files just because
the directory itself is world-writable.

**`umask` applies at creation, not afterward.** The kernel starts from a
requested mode (`666` for a new file, `777` for a new directory) and
clears whatever bits the umask sets, once, at `open()`/`mkdir()` time.
Changing `umask` never touches a file that already exists — only `chmod`
does that. `/etc/shadow` at `0640 root:shadow` is a hand-set exception,
not a umask artifact: shadow's password hashes must be unreadable to
everyone but root and the trusted `shadow` group (`chage`, login, and
friends), so the file is deliberately narrower than any default umask
would produce.

**`sudo` and its audit trail.** `sudo` runs one command as another user
(root by default) after checking `/etc/sudoers`, and every invocation is
logged — normally to `/var/log/auth.log` on Debian/Ubuntu or via
`journalctl -u sudo` — with the calling user, the target user, and the
full command line. This is the whole reason incident response prefers
`sudo <cmd>` over sharing the root password: `su -` gives you root with
no per-command record of what happened once you were in.

**Capabilities: root, decomposed.** Historically a process was either
root (UID 0, every check bypassed) or not. Capabilities split root's
power into ~40 independent bits, each grantable on its own, so a process
can get exactly the slice of root it needs. Three worth knowing by name:

| Capability | Grants | Seen where |
|---|---|---|
| `CAP_NET_RAW` | Open raw sockets (ICMP, packet capture) | `ping`, `tcpdump` |
| `CAP_NET_BIND_SERVICE` | Bind TCP/UDP ports below 1024 | nginx on port 80 |
| `CAP_SYS_PTRACE` | Attach to and inspect other processes | `strace`, granted to `ws` |

**ACLs, briefly.** The classic owner/group/other model has exactly one
slot per category — no way to grant a second user or group access without
changing ownership. POSIX ACLs (`getfacl`, `setfacl`) add arbitrary extra
user/group entries to a single file or directory; their presence is the
only visible trace in a plain `ls -l`, which appends a `+` after the mode
string (`-rwxr-x---+`) whenever ACL entries exist beyond the base three.

**systemd unit anatomy.** A unit file has up to three sections:
`[Unit]` (metadata and dependency directives), `[Service]` (how to run
it — this section is absent for non-service unit types), and `[Install]`
(what enabling the unit wires it into, e.g. `WantedBy=multi-user.target`).

**`Type=`.** `simple` (the default) means "the process named by
`ExecStart=` *is* the service; systemd considers it started the moment
`fork()`+`exec()` succeeds." `oneshot` means "run to completion, then
exit — systemd considers the unit active based on that exit code, not on
a still-running process," used for one-off setup tasks. `notify` means
"wait for the process itself to call `sd_notify(READY=1)` before
considering it started," used when 'the process exists' and 'the process
is actually ready to serve traffic' are different moments.

**`After=` orders; `Requires=` requires.** This is the single most common
systemd unit bug. `After=unit-b.service` tells systemd only about
*sequence*: if both units are going to start, start this one after
`unit-b`. It does not pull `unit-b` in as a dependency at all — if nothing
else wants `unit-b`, `After=` alone never starts it. `Requires=unit-b`
tells systemd only about *presence*: this unit will not be considered
satisfied unless `unit-b` is also active (and if `unit-b` fails, this unit
is stopped too) — but `Requires=` alone says nothing about which one
starts first, so both can be dispatched at the same instant. The fix that
actually works is both directives together, one for presence and one for
order; today's broken unit ships with `Requires=` and no `After=` for
exactly this reason.

**`systemctl` verbs, what each actually does.** `status` reads the
current state and the last several journal lines for one unit — read
only, changes nothing. `start`/`stop` act on the running unit for this
boot only. `enable`/`disable` only edit the symlinks under
`/etc/systemd/system/*.wants/` that wire a unit into a target — they do
not start or stop anything themselves. `daemon-reload` re-parses every
unit file from disk into systemd's in-memory unit graph; it is required
after editing any `.service` file, because systemd does not watch
`/etc/systemd/system/` for changes and will otherwise keep running
against its old, cached copy of the unit.

**`journalctl` filters.** `-u <unit>` scopes to one unit's log lines;
`-b` scopes to the current boot only; `--since "10 min ago"` (or an
absolute timestamp) bounds the time window; `-p err` filters to priority
`err` and worse, cutting through routine `info` noise during an incident.

**Targets and the boot sequence.** A target is a named synchronization
point with no code of its own — just a bundle of `Wants=`/`Requires=`
pointing at the units that must be up to consider that milestone reached.
`multi-user.target` (normal multi-user boot, no GUI) and
`graphical.target` (adds a display manager) are the two you'll see most;
`systemctl get-default` reports which one boot targets.

**Timers vs. cron.** A `.timer` unit pairs with a same-named `.service`
unit and is scheduled, started, and logged exactly like every other unit
— `systemctl list-timers`, `journalctl -u <name>.service` for output, and
`OnCalendar=` syntax for scheduling. `cron` is simpler and has no systemd
dependency, but its job output only reaches you if you configured mail or
redirected it yourself, and a missed run leaves no trace unless you built
one.

**The contrast that matters — what replaces a systemd responsibility
inside a container:**

| systemd responsibility | what replaces it in a container |
|---|---|
| Supervision (`Restart=on-failure`) | The orchestrator's restart policy (ECS `desiredCount` + task-level restart) |
| Logging (`journalctl`) | stdout/stderr, collected by the container's log driver (`awslogs`) |
| Dependency ordering (`After=`/`Requires=`) | `dependsOn` in the task definition, or an application-level readiness check |
| Environment (`Environment=` in the unit) | The task definition's `environment`/`secrets` block |
| PID 1 reaping zombie children | `tini`, or ECS's `initProcessEnabled: true` |

## Lab

See `labs/day05/`. Two incidents on the one container that boots real
systemd: a file at mode `0777` that still yields permission denied, and a
unit, `labs-api.service`, that will not start. Success signal: `verify.sh`
exits `0` and reports `3/3 checks passed`. Run `break.sh`, write the chain
for **both** incidents in `journal.md` before touching anything.

## Strip the toolbox

Repeat the `CapEff` read inside `slim`, where `capsh` does not exist and
`getcap`/`setcap` are not installed either — only `cat` and busybox
`grep` are available, exactly the fallback path called out in Derive the
tool, above.

```
$ cat /proc/self/status | grep CapEff
CapEff: 00000000________
```

Whatever hex value actually comes back for `slim` is what you decode —
this section fixes the *procedure*, not the number. This is the same
technique Day 2 established for decoding `SigCgt` in the `##
/proc/PID/status` primer (`content/primers/proc-field-reference.md`) —
read each hex digit as a 4-bit nibble, then read off which bit positions
are `1` — applied here to capabilities instead of signals. Do not
re-derive the technique; cite it and reuse it. Bit position, capability
name, and the `CapEff` row itself are all in that primer.

**The rule, stated exactly, because getting it backwards is worse than
not trying:** number hex digits from the right, starting at 0. Digit `N`
(0-indexed, from the right) covers bits `4N` through `4N+3`. The
rightmost digit is always bits 0-3; the next one left is always bits
4-7; there is no shortcut that skips counting digit positions from the
right first.

Worked example — decoding Docker's well-known default capability set,
`a80425fb`, as practice; treat the value only as an exercise, not as a
claim about what `slim` shows:

```
digit (right to left):   b    f    5    2    4    0    8    a
digit index N:            0    1    2    3    4    5    6    7
bit range 4N..4N+3:      0-3  4-7  8-11 12-15 16-19 20-23 24-27 28-31
```

`CAP_NET_RAW` is bit 13, which falls in the range `12-15` — digit index
3, counting from the right, which is the digit `2`. Expand `2` to 4 bits:
`0010`, read as bit15,bit14,bit13,bit12 left to right: `0,0,1,0`. Bit 13
is `1`: `CAP_NET_RAW` is set.

Cross-check against `capsh --decode=a80425fb` — the **full** eight-digit
value, not a truncated low group; truncating drops every capability
sitting in a higher nibble (`CAP_MKNOD` at bit 27, `CAP_SETFCAP` at bit
31, both above the digits kept by a 4-digit truncation) — on a box where
`capsh` happens to be installed, and confirm `cap_net_raw` appears in its
name list. The point of doing it by hand is that the answer no longer
depends on that tool being there.

## Exercises

1. A file is mode `0777` and its owning directory is mode `0644`. A
   non-owner, non-group user gets "permission denied" reading it. Explain
   why, and name the exact bit responsible. — **Hint:** re-read "Mode bits
   and the directory execute bit," above; the file's own mode is a red
   herring. — **Solution sketch:** the directory lacks the execute
   (traversal/search) bit for "other." Traversing a path requires `x` on
   every directory component, independent of the target file's mode; the
   directory's other-triad here is `4` (`r--`), no `x`, so lookup by name
   fails before the file's own permissions are ever checked.
2. Predict the mode of a file created by a process running under
   `umask 027`. — **Hint:** the kernel starts from the file's requested
   mode, `666`, and clears bits the umask sets. — **Solution sketch:**
   `666 & ~027 = 640` (`rw-r-----`). Owner keeps `rw-`; group loses the
   write bit (`rw-` → `r--`); other loses everything. Notice this is the
   same `0640` mode `/etc/shadow` ships at — not a coincidence, `640` is
   the standard "owner writes, one trusted group reads, no one else"
   shape.
3. Find every setuid binary on the system and explain the risk of one of
   them. — **Hint:** the setuid bit shows as `4000` in octal, or `s` in
   the owner's execute slot in `ls -l`; `find` can search by permission
   bits directly. — **Solution sketch:** `find / -perm -4000 -type f
   2>/dev/null` lists them; `/usr/bin/passwd` is near-universal. Its risk:
   it runs with `euid=0` for every caller regardless of who invoked it, so
   any exploitable bug in it (buffer overflow, unsafe environment
   handling, a symlink race while writing `/etc/shadow`) is a direct path
   from an unprivileged shell to root — the file's own correctness is the
   entire security boundary, with no sandbox behind it.
4. Explain how unprivileged `ping` works on a modern distro, given that
   opening a raw socket has historically required root. — **Hint:**
   `getcap` the binary rather than guessing. — **Solution sketch:**
   `getcap /bin/ping` shows `cap_net_raw=ep` stored as a file capability —
   `setcap` was run on the binary once, at packaging time, so it launches
   with exactly `CAP_NET_RAW` in its effective set and nothing else,
   instead of the old design of making the whole binary `setuid root`.
   (Some distros instead widen `net.ipv4.ping_group_range` to permit an
   unprivileged `SOCK_DGRAM` ICMP socket for allowed GIDs with no
   capability at all — `getcap` returning nothing is the signal to check
   that sysctl next.)
5. A unit starts before its database is ready. Given only
   `Requires=labs-db.service` in `[Unit]`, write the correct
   `After=`/`Requires=` pair and explain why one alone is insufficient.
   — **Hint:** one directive is about presence, the other about sequence
   — see "`After=` orders; `Requires=` requires," above. — **Solution sketch:**
   keep `Requires=labs-db.service` and add
   `After=labs-db.service` beside it. `Requires=` alone guarantees
   `labs-db` is up but not that it starts first — both can be dispatched
   together; `After=` alone would order them correctly *if* something
   else pulls `labs-db` in, but adds no dependency of its own, so
   `labs-db` might never start at all. Only the pair guarantees both
   "it's there" and "it's there first."
6. Name what replaces each of three systemd responsibilities when the
   same service runs as an ECS task instead. — **Hint:** see "The
   contrast that matters," above. — **Solution sketch:** supervision →
   the orchestrator's restart policy (ECS `desiredCount`); logging →
   stdout/stderr through the `awslogs` log driver, no journal to query;
   dependency ordering → `dependsOn` in the task definition, or an
   application-level readiness check, since there is no `After=`/
   `Requires=` inside a single container.

## Anti-patterns / Common mistakes

- Mistake 6 — reaching for `chmod 777` the moment a permission denial
  appears, instead of reading the denial (`namei -l`, the directory chain,
  the actual owner/group) and applying the narrowest fix that addresses
  it. `777` frequently "works" by coincidence and leaves the real cause —
  here, a missing directory execute bit — ready to recur on the very next
  directory the same deploy process creates.
- Mistake 2 — trusting `ls -l` on the file alone to explain access.
  `ls -l` describes exactly one inode; it says nothing about the
  directories above it, the caller's supplementary groups, an ACL entry,
  or a dropped capability, any one of which can deny access that the
  file's own mode line promises.

## Where this shows up in AWS

A container that runs perfectly as root on a laptop and then fails the
moment its ECS task definition sets a non-root `user:` is this same lab,
relocated: the image's files and mounted volumes were never checked
against the new UID, so a directory that "worked" only because root
bypasses permission checks entirely now denies the actual runtime user.
Bind-mounted EFS access hits the identical wall — EFS enforces POSIX
permissions from the NFS client's UID/GID exactly like a local disk, so a
task running as UID 1000 against a directory owned by UID 0 fails no
differently than `appuser` did against `/srv/reports` today. Dropping a
container from root to a non-root user also breaks a port-80 listener
outright, because binding ports below 1024 needs `CAP_NET_BIND_SERVICE`
and a non-root process has none of root's capabilities by default; the
fix is never "run as root again" — it's granting that one capability
explicitly (`setcap` in the image, or the task definition's
`linuxParameters.capabilities.add`) or simply listening on a high port
and letting the load balancer or target group do the low-port mapping
instead.

## Teardown

See `labs/day05/teardown.md` — Day 5 is the only day with an extra
container to remove, from the `sysd` overlay.

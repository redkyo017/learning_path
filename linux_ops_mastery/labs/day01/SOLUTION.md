# Day 1 — SOLUTION

Full chain of evidence, in `journal.md`'s chain template. Compare your own
chain against this one claim by claim before reading the fix.

### Day 1 — `/var/log` full on `app`, `du` shows near zero

**Symptom (verbatim, no interpretation):**
`Writes to /var/log on the app container are failing with ENOSPC.`

**Resource class:** mount tree (with the proof landing in the fd table)

**Chain of evidence:**
1. Claim: `/var/log` is a distinct tmpfs mount inside `app`, not just a
   directory on the root filesystem. | Proof: `cat /proc/mounts | grep
   /var/log` → `tmpfs /var/log tmpfs rw,relatime,size=24576k,mode=1777 0 0`
2. Claim: the mount is genuinely full, not merely near-full. | Proof:
   `df -h /var/log` → `24.0M   24.0M      0 100% /var/log`
3. Claim: no named file on the tree accounts for that usage. | Proof:
   `du -sh /var/log` → `4.0K    /var/log` (or similarly near-zero)
4. Claim: the gap is bytes still billed to the tmpfs but unnamed by any
   directory entry — the same mechanism as `journal.md`'s Day 1 example. |
   Proof: no single command proves this yet; it's the hypothesis the next
   step tests.
5. Claim: some process holds a deleted file open on this tmpfs. | Proof:
   `ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep '(deleted)'` →
   `lr-x------ 1 root root 64 Sep 6 10:00 /proc/4211/fd/3 -> /var/log/bloat.log (deleted)`
   (read-only mode bits, `lr-x`, because `tail -f` only ever opens the
   file for reading; globbing the fd *files* — `/proc/[0-9]*/fd/*` —
   rather than the fd *directories* is what puts `/proc/4211/fd/3` on the
   matched line at all: pointed at the directories, `ls -l` prints a
   `/proc/PID/fd:` header above each process's entries, and `grep` never
   sees that header, only the entry line, so the PID would be lost)
6. Claim: PID 4211 is the holder. | Proof: the PID is already in the path
   from the line above; `cat /proc/4211/cmdline` decodes to
   `tail -f /var/log/bloat.log`, matching the `setsid ... tail -f` line
   `break.sh` launched.

**Diagnosis:**
`break.sh` wrote `/var/log/bloat.log` until the 24 MiB tmpfs was full,
started a detached `tail -f` on it (kept alive past its launching shell
by `setsid`), then unlinked the name with `rm`. The directory entry is
gone; the tmpfs still bills every page because `tail`'s fd 3 keeps the
inode referenced. tmpfs pages are anonymous/shmem pages charged to the
mount itself, with no block device and no background reclaim path behind
them, so nothing frees them on its own — they stay billed for exactly as
long as that one descriptor stays open.

**Fix applied:**
Two valid fixes exist, with different trade-offs. Both pass `verify.sh`,
because it checks that reclaimed space is real, not that the deleted
descriptor entry has vanished — see the note below on why those are not
the same check.

- **Kill the holder:** `kill <PID>` (or `kill -9 <PID>` if it ignores
  `SIGTERM`, which busybox `tail` does not, but a real service might).
  The process exits, its last reference to the inode drops, and the
  kernel frees the blocks outright — the `(deleted)` entry disappears
  from `/proc/[0-9]*/fd/*` because the fd itself no longer exists. Space
  returns immediately, but the process dies, which is unacceptable
  against a real service mid-incident.
- **Truncate through the descriptor (used here):** `: > /proc/<PID>/fd/3`.
  This does not reopen or touch the process at all; it truncates the file
  the descriptor already points at, in place, via the same path the
  kernel uses for every open file. The tmpfs pages are freed and space
  returns immediately, and the process keeps running untouched — it
  simply sees an empty file from this point forward. This is the one to
  reach for in production: it repairs the resource without taking the
  workload down.

**Proof the fix worked (same file re-read):**
`df -h /var/log` → usage back under 20% either way (e.g. `24.0M     0
24.0M   0% /var/log`). The two fixes differ in what
`ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep '(deleted)'` shows afterward,
and that difference is expected, not a bug: after **kill**, it returns
nothing — the fd is gone. After **truncate**, the same
`/proc/<PID>/fd/3 -> /var/log/bloat.log (deleted)` line can still appear,
because truncating through a descriptor frees the file's *data* without
re-linking its name — the dentry stays gone, `tail` still holds fd 3 open
on the (now zero-length) inode. That lingering entry is harmless: it
holds zero bytes, costs nothing, and disappears the moment `tail` exits
or reopens the file. The check that actually matters, and the one
`verify.sh` runs, is `stat -Lc %s` on the descriptor path (e.g.
`stat -Lc %s /proc/<PID>/fd/3` → `0`) — size zero, whether or not the
`(deleted)` line itself is still present. The `-L` is required, not
cosmetic: `/proc/<PID>/fd/3` is itself a symlink, so a plain `stat`
(which `lstat(2)`s by default, same as `ls -l`) reports the *symlink's*
own size — the 64 bytes visible in the chain-of-evidence line above —
never the size of the file it points at; `-L` follows the link and
`stat`s the target instead.

**What I would check first next time:**
Whether the real application reopens its log file on `SIGHUP` or a
rotation signal, and whether the deployed log-rotation config actually
sends one — an unlinked-fd leak like this recurs on every service that
ignores reload signals and has no `copytruncate`-style rotation, exactly
as `journal.md`'s Day 1 example concludes.

## Strip-the-toolbox note (`slim`)

`slim` has no live incident of its own to diagnose (its role today is
practising the technique, per `content/day01.md`'s "Strip the toolbox"
section), but the identification command is identical either way and is
the busybox-safe form used throughout this file and `verify.sh`:

```sh
ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep '(deleted)'
```

No `lsof`, no `fuser`, no GNU-only `grep` flags — plain pattern matching
against busybox `grep`, which is all `slim` and `app` have. The glob is
`/proc/[0-9]*/fd/*`, not `/proc/*/fd`: pointing `ls -l` at the fd
directories prints a `/proc/PID/fd:` header line per process above its
entries, and `grep` matches only the entry line, losing the PID —
globbing the fd files themselves keeps the full `/proc/PID/fd/N` path on
every matched line.

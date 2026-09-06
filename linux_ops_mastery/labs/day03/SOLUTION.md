# Day 3 solution — rotated log still growing after rotation

Chain written in `journal.md`'s exact template, so it can be compared
claim by claim against what you wrote before reading this.

Every command below runs inside `app` (`docker compose -p linuxops exec
app sh -c '...'`), which is `python:3.12-alpine` — busybox `sh`, `grep`,
`awk`, `ls`, `kill`. Nothing here uses a GNU-only flag or `lsof`, because
`app` has neither, and that is deliberate (see `content/day03.md`,
"Derive the tool"). Where a natural non-busybox habit would apply
instead, a note calls it out explicitly.

**The req_id below is a worked example, not a fixed answer.**
`break.sh` generates a fresh 8-hex-digit id at runtime on every run (it is
never hard-coded in that script), so the value your own run produces will
differ from `437`'s PID or `deadbeef`'s req_id shown throughout this
chain. If your `grep`/`awk` pipeline turns up a different 8-hex string
where this document shows `deadbeef`, that is expected, not a sign the
lab is broken — check your own `/tmp/.day03-needle` on `app` if you want
to confirm what your run's target actually is before you finish.

### Day 3 — rotated log still growing after rotation

**Symptom (verbatim, no interpretation):**
`SYMPTOM: One request failed in the last rotation, and /var/log keeps
filling after rotation.`

**Resource class:** fd table (first observed through the mount tree)

**Chain of evidence:**

1. Claim: `/var/log` usage did not drop after the rotation ran. | Proof:
   `df /var/log` reports used space still close to what it was before
   the live log was truncated — a tmpfs that a rotation was supposed to
   shrink is not shrinking.
2. Claim: the visible files do not account for that usage — the same
   `df`/`du` split Day 1 taught. | Proof: `ls -la /var/log` shows only
   `app.log`, and it is empty (the rotation's `: > app.log` truncated
   it); nothing on the visible directory listing is large enough to
   explain the `df` figure.
3. Claim: some process holds a deleted file open under `/var/log`. |
   Proof (Day 1's technique, applied here, with the trailing `/*` that
   keeps the owning PID on the same line as its target — a bare
   `/proc/[0-9]*/fd` prints the PID only in a separate header line, which
   `grep` then discards):
   `ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep '(deleted)'` →
   `lr-x------ 1 app app 64 09:00 /proc/437/fd/3 ->
   /var/log/app.log.1 (deleted)`
4. Claim: the holder is a `tail -f`, not the app itself. | Proof: the fd
   path from claim 3 already names the PID; `cat /proc/437/comm` →
   `tail`, and `tr '\0' ' ' < /proc/437/cmdline` →
   `tail -f /var/log/app.log.1`.
5. Claim: `fdinfo` shows how much of the vanished file this fd already
   consumed, one level past Day 1's plain `(deleted)` marker. | Proof:
   `cat /proc/437/fdinfo/3` → `pos:` sitting at the file's end-of-size
   (~7-8 MiB), showing `tail -f` read the whole rotated file before its
   name was removed. `pos` is static now — nothing appends to an
   unlinked inode — and it is the still-open fd itself, not this offset,
   that keeps the kernel from freeing the blocks.
6. Claim: the content is still readable through that fd, even though no
   path names it any more. | Proof:
   `grep -n 'status=500' /proc/437/fd/3` → exactly one matching line.
7. Claim: that line's `req_id` is the incident's answer. | Proof:
   `grep 'status=500' /proc/437/fd/3 | awk -F'req_id=' '{print $2}' \
   | awk '{print $1}'` → `deadbeef`

**Diagnosis:**
Rotation copied `app.log` to `app.log.1`, truncated the live `app.log`
in place, then a `tail -f app.log.1` that had been started against the
pre-rotation content was left running while `app.log.1`'s name was
removed. `tail` still holds fd 3 open on the now-nameless inode, so the
kernel keeps every block of that file allocated against the 24 MiB
`/var/log` tmpfs for as long as fd 3 stays open — the rotation "worked"
(the name is gone) but reclaimed nothing, because reclaiming blocks
needs the last open fd on the inode to close, not just the last
directory entry to be removed.

**Fix applied:**
Recovered the `req_id` first, while the fd was still open — it becomes
unreadable the moment the holder closes it:

```
in-app$ grep 'status=500' /proc/<PID>/fd/3 \
  | awk -F'req_id=' '{print $2}' | awk '{print $1}' > /tmp/answer
```

Then released the file by terminating the holder:

```
in-app$ kill <PID>
```

Busybox `kill` sends `SIGTERM` by default, and busybox `tail -f` exits on
`SIGTERM` (it has no special handler), which closes its only fd on the
deleted inode and lets the kernel free the blocks immediately.

> Note, not a correction of habit: busybox `pgrep` does support `-f`
> (`pgrep -f 'tail -[f]'` finds it — bracket a character so the
> pattern cannot match the command line of the shell running pgrep) — what busybox `pgrep` actually lacks
> is `-c` and `-n`. Either way, the fd-path walk above already names the
> PID directly (`/proc/437/fd/3`), so there is nothing left to search for.

**Proof the fix worked (same file re-read):**
`ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep '(deleted)'` now returns
nothing, and `df /var/log` reports usage back down near the size of the
(still empty) live `app.log` — the same file used in claim 1 and 3,
re-read to close the loop.

**What I would check first next time:**
Whether the process reading a rotated log reopens the target by name or
a reload signal after `copytruncate`-style rotation, versus keeping its
original fd across a rename-based one — the recurring failure is any
reader with no reopen hook, and it is exactly the CloudWatch agent /
Fluent Bit trap named in `content/day03.md`'s AWS section.

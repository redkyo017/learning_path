# Journal — diagnosis chains

One entry per lab, written **before** the fix is attempted (see
`STRATEGY.md`, The daily loop, step 5). Copy the chain template below for
each new incident; every `SOLUTION.md` in `labs/dayNN/` mirrors this exact
skeleton, so a diagnosis written here should read the same as one you'd
find there.

## Chain template

```markdown
### Day N — <incident in five words>
**Symptom (verbatim, no interpretation):**
**Resource class:** mount tree | process table | fd table | cgroup boundary
**Chain of evidence:**
1. Claim: … | Proof: `<command>` → `<the output line that proves it>`
2. Claim: … | Proof: …
**Diagnosis:**
**Fix applied:**
**Proof the fix worked (same file re-read):**
**What I would check first next time:**
```

## Day 1 — example entry

### Day 1 — disk full but du shows 40%

**Symptom (verbatim, no interpretation):**
`df -h /data` reports `Use% 100%`. `du -sh /data` reports `4.1G` on a
40 GB volume. The application is failing writes with `ENOSPC`.

**Resource class:** mount tree (with the proof landing in the fd table)

**Chain of evidence:**
1. Claim: `/data` is a distinct mount, not just a directory. | Proof:
   `cat /proc/mounts | grep /data` → `/dev/sdb1 /data ext4 rw,relatime 0 0`
2. Claim: `df` and `du` are reading different accounting. | Proof:
   `df -h /data` → `40G 40G 0 100% /data` vs. `du -sh /data` → `4.1G /data`
3. Claim: the gap is bytes still billed to the filesystem but unnamed by
   any path. | Proof: no single command proves this yet — it is the
   hypothesis the next step tests.
4. Claim: some process holds a deleted file open, and the kernel will not
   reclaim its blocks until the last fd on it closes. | Proof:
   `for p in /proc/[0-9]*/fd; do ls -l $p 2>/dev/null; done | grep deleted`
   → `l-wx------ 1 app app 64 ... 7 -> /data/app.log (deleted)`
5. Claim: PID 4211 is the holder. | Proof: the fd path above resolves as
   `/proc/4211/fd/7`, and `/proc/4211/comm` → `app-server`.

**Diagnosis:**
`app-server` (PID 4211) opened `/data/app.log`, logrotate unlinked the
name without signalling the process to reopen it, and the kernel keeps
the blocks allocated as long as fd 7 stays open. `du` only walks named
directory entries, so it never sees these blocks; `df` reads the
filesystem's live block accounting, which still counts them. The 36 GB
gap is exactly this file's accumulated size since the unlink.

**Fix applied:**
Sent `SIGHUP` to PID 4211 to make it reopen its log file at the
(correctly rotated) path, per its documented reload behaviour. Confirmed
no other deleted-but-open large files existed before considering the
incident closed.

**Proof the fix worked (same file re-read):**
`for p in /proc/[0-9]*/fd; do ls -l $p 2>/dev/null; done | grep deleted`
now returns nothing. `df -h /data` → `40G 4.3G 34G 11% /data`, matching
`du -sh /data` within the expected write buffer.

**What I would check first next time:**
Whether the deployed logrotate config uses `copytruncate` or a
post-rotate reload hook for this service — the unlinked-fd failure mode
recurs on every service that ignores `SIGHUP` and has no reload hook
wired up, and that config is the actual root cause, not just this
instance of it.

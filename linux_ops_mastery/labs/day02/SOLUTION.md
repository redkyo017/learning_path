# Day 2 — SOLUTION

Three separate causes under one symptom. Each gets its own chain, in the
`journal.md` template, because `break.sh` deliberately does not say
which process has which problem — that is the diagnosis, not the setup.

First, the shared starting move for all three: enumerate every state on
`app` before guessing at any one process.

```
docker compose -p linuxops exec app sh -c \
  'for f in /proc/[0-9]*/status; do grep -H "^State:" "$f"; done'
```

This turns up (paraphrased) four non-`S` rows worth noticing: a `sleep
100000` that never exits (a), a `sleep 200000` in `T` state (c), and one
or more `Z` rows whose parent is a still-running `python3` process, not
PID 1 (b). Three causes, three chains. Every `pgrep` below is written
with a bracketed character class around one character of its pattern —
`sleep 10000[0]`, not `sleep 100000` — so that the `pgrep` command's own
`/proc/PID/cmdline` (which contains the search text you typed) cannot
match its own pattern; without the bracket, `pgrep` finds itself, and
depending on the exact command, either inflates a count by one or hands
`kill -STOP` its own wrapper shell.

---

### Day 2a — sleep ignores SIGTERM after exec

**Symptom (verbatim, no interpretation):**
"Three processes on app will not exit. One ignores SIGTERM, one is
stopped, one is multiplying." One of the three is a `sleep 100000` in
`S` state that a plain `kill <pid>` does not remove.

**Resource class:** process table

**Chain of evidence:**
1. Claim: this `sleep 100000` was launched through `setsid sh -c
   "trap \"\" TERM; exec sleep 100000"`, so any signal disposition the
   shell set before `exec` may have carried across. | Proof:
   `pgrep -f "sleep 10000[0]"` → one pid; `cat /proc/<pid>/cmdline | tr
   '\0' ' '` → `sleep 100000` (the shell itself is gone — `exec`
   replaced it, same PID).
2. Claim: `TERM` is not caught by a handler, it is explicitly ignored,
   alongside two signals the shell ignored automatically. | Proof:
   `grep -E "^Sig(Ign|Cgt):" /proc/<pid>/status` →
   `SigIgn: 0000000000004006` and `SigCgt: 0000000000000000`. Bit 14
   (signal 15, `SIGTERM`) is the one this incident is about; bits 1 and
   2 (`SIGINT`, `SIGQUIT`) are set too, because a non-job-control shell
   ignores both automatically for anything it runs with `&` — expected
   background noise, not part of this diagnosis.
3. Claim: `SIG_IGN` survives `exec`, so `sleep` — a binary with no
   signal-handling code of its own — inherited the shell's ignore
   before the shell's own image was replaced. | Proof: this is a
   property of `execve(2)`, not something `/proc` shows directly; the
   `SigIgn` bit on the *current* `sleep` binary, which never calls
   `signal()`, is the observable consequence.
4. Claim: `SIGKILL` is not subject to any disposition, so it is the
   only signal guaranteed to remove this process. | Proof:
   `primers/proc-field-reference.md#/proc/PID/status`'s `SigCgt` note —
   `SIGKILL`'s bit never appears in `SigCgt`/`SigIgn` because it cannot
   be caught or ignored in the first place.

**Diagnosis:**
The launcher shell ran `trap "" TERM` (ignore, not catch) before
`exec sleep 100000`. `exec` preserves an ignored disposition across the
image swap, so the resulting `sleep` process — despite having zero
signal-handling code — silently discards every `SIGTERM` it receives.
No amount of plain `kill` will touch it; only `SIGKILL` bypasses
disposition entirely.

**Fix applied:**
`kill -9 <pid>` on the `sleep 100000` found via `pgrep -f
"sleep 10000[0]"`.

**Proof the fix worked (same file re-read):**
`ls /proc/<pid>` → `No such file or directory`; the enumeration script
from the top of this file no longer lists this PID at all, and
`pgrep -f "sleep 10000[0]"` returns nothing.

**What I would check first next time:**
Whether `SigIgn` or `SigCgt` has the bit set before reaching for `-9` —
an ignored `TERM` and a caught-but-buggy `TERM` handler look identical
from the outside ("nothing happened") but only one of them might
actually respond to a second, more patient signal.

---

### Day 2b — zombies from a spawner with no SIGCHLD handling

**Symptom (verbatim, no interpretation):**
"...one is multiplying." One or more processes with `comm` unrelated to
`sleep` show `State: Z (zombie)` in `/proc/<pid>/status`, and the count
does not go down on its own.

**Resource class:** process table

**Chain of evidence:**
1. Claim: a zombie is not running code and cannot be signaled into
   leaving — it is already dead, waiting only to be collected. | Proof:
   `cat /proc/<pid>/status | grep State` → `State:\tZ (zombie)`;
   `kill -9 <pid>` on this PID changes nothing, because there is no
   running process left to receive the signal, only a table entry.
2. Claim: the zombie's parent is a live `python3` process, not PID 1 —
   this is a direct parent that never reaped, not (yet) a reparenting
   story. | Proof: `grep PPid /proc/<pid>/status` →
   `PPid:\t<spawner-pid>`, and `cat /proc/<spawner-pid>/cmdline | tr
   '\0' ' '` → `python3 -c import os, time while True: ...` — a plain
   inline script, still running.
3. Claim: the spawner forks roughly every 2 seconds and never calls
   `os.wait()`/`os.waitpid()` for any child it creates — unlike `app.py`
   itself, which sets `SIGCHLD` to `SIG_IGN` and so never manufactures
   a zombie of its own; this spawner's `SIGCHLD` is left at the
   ordinary Python default, which does not auto-reap. | Proof:
   `pgrep -f "os[.]fork"` → the spawner's pid; re-running the
   enumeration script from the top of this file twice, a few seconds
   apart, shows the `Z` count rising by roughly one each time.
4. Claim: the zombies cannot be collected while the spawner stays
   alive, because nothing else is watching for *its* children; once the
   spawner itself dies, its already-dead children reparent to `app`'s
   real PID 1, which is a different case — PID 1 here sits blocked
   waiting on python via a generic wait, not a wait targeted at one
   pid, so it reaps *any* child that lands on it, adopted or not. |
   Proof: this is the hypothesis the fix step next confirms or kills.

**Diagnosis:**
The `python3` spawner is "the parent that forks and never waits": every
loop iteration forks a child that exits immediately, and the spawner
never collects it. Killing an already-dead zombie directly is
impossible — it holds no code to signal — so the fix has to target the
live process that is still producing more of them, and rely on `app`'s
own PID 1 to finish the job once that live process is gone.

**Fix applied:**
Found the spawner with `pgrep -f "os[.]fork"`, then `kill <spawner-pid>`
(plain `SIGTERM` — the script installs no handler of its own) — the
live spawner, never a zombie PID.

**Proof the fix worked (same file re-read):**
The enumeration script from the top of this file, re-run a few seconds
after the kill, shows zero `State:\tZ` lines, and a second check a few
seconds after that confirms the count stays at zero rather than merely
dipping.

**What I would check first next time:**
Whether the zombie count is still climbing (a live producer, still to
be found and killed) or static-but-nonzero (the producer is already
gone and the remaining zombies are mid-reparent, worth one more check
before assuming anything is stuck) — and, separately, that `kill -9 1`
run from inside `app` is not a shortcut here: `SIGKILL` only forces PID 1
of a namespace to terminate when sent from an ancestor namespace (the
host, or `docker kill`), never from inside the container's own shell,
so it would not have cleared anything and would not have taken the
container down either.

---

### Day 2c — a stopped process that looks alive

**Symptom (verbatim, no interpretation):**
"...one is stopped..." A `sleep 200000` process is present in `/proc`
and does not respond to `kill -TERM`, but also does not match Day 2a's
`SigIgn`/`SigCgt` evidence.

**Resource class:** process table

**Chain of evidence:**
1. Claim: this process's state is `T`, not `S` — it is not merely
   ignoring the signal, it is not being scheduled at all. | Proof:
   `pgrep -f "sleep 20000[0]"` → one pid; `grep State
   /proc/<pid>/status` → `State:\tT (stopped)`.
2. Claim: `TERM`'s bit is not set in either `SigIgn` or `SigCgt` on
   this pid, ruling out Day 2a's cause for this process specifically —
   the two signals set here are the same automatic-background pair,
   not `TERM`. | Proof: `grep -E "^Sig(Ign|Cgt):" /proc/<pid>/status` →
   `SigIgn: 0000000000000006` (bits 1, 2 — `SIGINT`, `SIGQUIT`, from
   the same non-job-control backgrounding as Day 2a) and
   `SigCgt: 0000000000000000`.
3. Claim: a stopped process cannot act on a merely-pending signal —
   `TERM`'s effect (its default disposition here, since neither ignore
   nor a handler applies) requires the process to actually run, and `T`
   state means the scheduler will not run it until `SIGCONT`; `SIGKILL`
   is the one documented exception, not relevant to the `kill -TERM`
   already tried. | Proof:
   `primers/proc-field-reference.md#/proc/PID/status`'s `SigPnd` field
   — a repeated `kill -TERM <pid>` shows `SigPnd`'s bit 14 set and
   staying set, never clearing, while `State` stays `T`.

**Diagnosis:**
`SIGSTOP` moved this process to `T`. A stopped process is not merely
"slow to respond" — the kernel will not schedule it at all, so `TERM`
sits pending and inert. The process is not misbehaving; it is doing
exactly what `T` state means.

**Fix applied:**
`kill -CONT <pid>` to resume scheduling, then `kill -TERM <pid>` to
deliver the signal to a process that can now actually act on it — pid
found via `pgrep -f "sleep 20000[0]"`.

**Proof the fix worked (same file re-read):**
Immediately after `CONT`, `State` reads `S (sleeping)`; after `TERM`,
`/proc/<pid>` stops existing at all — `ls /proc/<pid>` →
`No such file or directory`, and `pgrep -f "sleep 20000[0]"` returns
nothing.

**What I would check first next time:**
`State` before reaching for a stronger signal — a `T` process and a
process that has caught-and-ignored `TERM` both "don't respond" to a
first `kill -TERM`, but only one of the two needs `SIGCONT` before
anything else will help; sending `-9` blind works for both (it is the
one signal a stopped process acts on immediately, no `SIGCONT`
required), but skips learning which one you actually had.

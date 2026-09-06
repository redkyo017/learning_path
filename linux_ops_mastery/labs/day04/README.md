# Day 4 lab — resources and the cgroup boundary

## Goal

Diagnose two boundary failures on `app` — a memory kill and a CPU throttle
— using only the cgroup v2 files (`memory.events`, `cpu.stat`), never
`free` or `top`.

## Success signal

`bash labs/day04/verify.sh` exits `0`.

## This lab's deliverable is a diagnosis, not a repair

Read this section twice before running anything. `app`'s own container
never goes down: `break.sh` kills a background *child* process inside
`app` via a cgroup OOM, not `app`'s own PID 1, so its cgroup — and its
counters — stay right where you can read them. There is nothing here to
fix, and running `verify.sh` in the seconds right after `break.sh` will not
pass, because you have not produced anything yet. The lab's actual output
is two numbers, read from two live files, written to a specific place in a
specific format.

1. Read `oom_kill` out of `/sys/fs/cgroup/memory.events` inside `app`.
2. Read `nr_throttled` out of `/sys/fs/cgroup/cpu.stat` inside `app`.
3. On `app`, write **exactly** two lines to `/tmp/findings` — order does
   not matter, and blank lines are fine, but each of these two lines must
   appear literally, with the real integer in place of `<n>`:

   ```
   oom_kill=<n>
   nr_throttled=<n>
   ```

`verify.sh` re-reads both cgroup files itself, at the moment it runs, and
compares them against your two lines **byte for byte**. It passes only on
an exact match: `oom_kill=1` matches a file reading `1`; `oom_kill= 1`,
`oom_kill=01`, or a number left over from an earlier `break.sh` run does
not. If you re-run `break.sh` after writing `/tmp/findings`, re-read both
files and rewrite it before calling `verify.sh` again.

`nr_throttled` keeps climbing for the full ~45 seconds the burn runs, so a
`/tmp/findings` written while it's still live will already be stale by the
time `verify.sh` re-reads `cpu.stat`. Either wait for the burn to finish
before recording your findings, or re-read `cpu.stat` and rewrite
`/tmp/findings` right before running `verify.sh`. A mismatch here means
you sampled a moving counter, not that your diagnosis was wrong.

`verify.sh` also rejects both counters at `0` even if your two lines match
them exactly — a container that was never broken, or was just recreated,
reads `0` on both files, and that must not pass. The incident has to have
actually happened.

## How to run

```bash
cd linux_ops_mastery/labs/fleet && docker compose -p linuxops up -d --build
bash ../day04/break.sh
```

Then, before touching anything else: write your numbered chain of evidence
into `journal.md`, in the format shown there — symptom, resource class,
claim-by-claim evidence, diagnosis. Only after the chain is written, read
the two cgroup files described above and write `/tmp/findings` on `app` in
the exact form shown above. Then:

```bash
bash ../day04/verify.sh
```

How you read the two files — which command, which flags — is the exercise
itself and is not spoiled here; `content/day04.md`'s **Read the file
first** and **Core concepts** sections give you everything you need.

## No spoilers

If you have not read `content/day04.md`, do that first — in particular
**Read the file first**, **Derive the tool**, and **Core concepts**.
`SOLUTION.md` in this directory holds a full model diagnosis chain; open it
only after your own attempt, or after `verify.sh` fails in a way you
cannot explain from the files alone.

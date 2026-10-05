# Day 4 lab — resources and the cgroup boundary

**At a glance:**
- **Run from:** repo root — `bash labs/day04/break.sh`, `bash labs/day04/verify.sh`.
- **Environment:** Docker fleet must be up (`labs/fleet/`:
  `docker compose -p linuxops up -d --build`); diagnose inside `app`.
- **Journal:** write your chain into the repo-root `journal.md`
  (`linux_ops_mastery/journal.md`), not a file inside this directory.
- **This day's loop deviates:** DIAGNOSIS ONLY — there is nothing to fix
  and no restart. Read two cgroup files, write `/tmp/findings` on `app`
  in the exact format shown below, then verify. See "This lab's
  deliverable is a diagnosis, not a repair" below before running anything.

## Start here — plain steps

1. **Start the lab:** on your Mac, from `linux_ops_mastery/`, make sure the fleet (the lab's Docker containers) is up (`docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d`), then run `bash labs/day04/break.sh`. It runs a 45-second CPU burn and a memory balloon inside the `app` container. There is nothing to fix this day; you diagnose and write down two numbers.
2. **Get a shell in the container:** on your Mac, in `linux_ops_mastery/`, run `docker compose -p linuxops exec app sh`. Do the reading and writing in this shell; run `verify.sh` back on your Mac. Do not restart `app`.
3. **Look at the symptom (in the `app` shell):** read the two cgroup (the container's resource-limit boundary) files named under Goal below, using `cat`. Do not use `free` or `top`; they show the host, not the container.
4. **Write your reasoning in `journal.md` before writing the findings.** Edit it on your Mac, in your editor. Copy the chain template (the claim-and-proof outline) at the top of that file; its Day 1 example shows the style.
5. **Write `/tmp/findings` exactly as shown under "This lab's deliverable is a diagnosis, not a repair" below,** in the `app` shell. Wait until the burn has finished (about 45 seconds after `break.sh`), re-read both files, then write two lines with the real numbers: `oom_kill=<n>` and `nr_throttled=<n>`. For example: `printf 'oom_kill=1\nnr_throttled=300\n' > /tmp/findings` (use your own numbers).
6. **Check your work:** back on your Mac in `linux_ops_mastery/` (type `exit` first if you are still inside `app`), run `bash labs/day04/verify.sh` and wait for `PASS: findings match live cgroup files (both nonzero)`. If the numbers differ, the counter moved: re-read and rewrite.
7. **Strip-the-toolbox drill:** on your Mac, run `docker compose -p linuxops exec slim sh`, then paste the snippet from "Strip the toolbox" in `content/day04.md` inside it. It computes CPU use from `/proc/stat` with only busybox (the tiny toolset in `slim`).
8. **Tidy up:** on your Mac, follow `labs/day04/teardown.md`. It recreates `app` to reset the counters, which is fine now that the lab is over.

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

## Stuck? Hints

Open one at a time. Try for 10 minutes before opening the next. Each failure has its own ladder.

### Failure 1 — the memory kill

<details><summary>Hint 1 — where to look</summary>

Something inside the container was killed, but the container itself kept running. `free` will not help: it shows the host's memory, not this container's. The container has its own limit, and the kernel keeps counters for it in cgroup files (cgroup means the container's resource-limit boundary).
</details>

<details><summary>Hint 2 — what proves it</summary>

`cat /sys/fs/cgroup/memory.events` shows `oom_kill` above 0 (OOM means out of memory). `cat /sys/fs/cgroup/memory.max` shows the ceiling: `67108864` bytes, which is 64 MiB.
</details>

<details><summary>Hint 3 — almost there</summary>

A forked child process tried to hold 120 MiB inside a 64 MiB limit with no swap to spill into. The container's own memory killer removed that child. The container's main process survived, so the counter stayed readable.
</details>

### Failure 2 — the CPU throttle

<details><summary>Hint 1 — where to look</summary>

Requests were slow, yet the machine did not look busy. Memory is not the cause of this one. Look for a limit on CPU time, and for a counter that records how often the container was made to wait.
</details>

<details><summary>Hint 2 — what proves it</summary>

`cat /sys/fs/cgroup/cpu.max` shows `20000 100000`: a quota of 20,000 microseconds per 100,000. `cat /sys/fs/cgroup/cpu.stat` shows `nr_throttled`. Read it twice, a few seconds apart, while the burn runs; it keeps climbing.
</details>

<details><summary>Hint 3 — almost there</summary>

The container is allowed only 20% of one CPU. A busy loop uses its slice early in each 100 ms period and is then forced to wait. That makes it slow even though the load average stays low.
</details>

Still stuck: read `SOLUTION.md`.

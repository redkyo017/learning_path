# Day 4 — model diagnosis chain

Follows `journal.md`'s chain template, claim by claim. Compare your own
chain against this one before or after `verify.sh` — not as a copy to
paste into `/tmp/findings`, since the actual counts depend on the live
timing of your own `break.sh` run.

### Day 4 — app's cgroup OOM-kills a child, then throttles

**Symptom (verbatim, no interpretation):**
"Requests are slow, and something inside the container was killed."

**Resource class:** cgroup boundary

**Chain of evidence — memory thread:**
1. Claim: `app`'s own container never went down — PID 1 is still the same
   process it was before `break.sh` ran. | Proof: `docker compose -p
   linuxops ps app` shows a continuous `Up` status with no restart, and
   `docker inspect --format '{{.State.Pid}}' <container>` returns the same
   PID before and after.
2. Claim: something inside the container was nonetheless killed by signal
   9. | Proof: `docker compose -p linuxops exec app cat
   /sys/fs/cgroup/memory.events` → `oom_kill 1` (nonzero) — read from the
   *same* cgroup the whole time, since the container never restarted and
   so never got a fresh one.
3. Claim: it was the cgroup's own OOM killer, not the host's global one. |
   Proof: the host had multiple GB of RAM free at the same moment — a
   global OOM killer does not fire with that much headroom — so the kill
   came from `app`'s own `memory.max` boundary instead.
4. Claim: the process the cgroup killed was a child of the balloon
   handler, not `app.py`'s own main thread. | Proof:
   `/balloon?mb=120&child=1` forks before allocating, so the memory is
   held by the child, not the parent; `docker compose -p linuxops exec app
   ps` shows `app.py`'s own PID unchanged and no lingering balloon child —
   it is the one that is gone.
5. Claim: the container reached its 64 MiB ceiling before that kill. |
   Proof: `cat /sys/fs/cgroup/memory.max` → `67108864` (64 MiB); a
   `memory.current` sample taken right after the `/balloon` request sits
   at or near that same ceiling — 120 MiB could never fit inside a 64 MiB
   limit with swap disabled, so reclaim ran, failed to free enough, and
   the kill followed.
6. Claim: `free` inside the container is not evidence either way. | Proof:
   `docker compose -p linuxops exec app free -m` reports the **host's**
   total and available memory (multiple GB), because `free` formats
   `/proc/meminfo`, a file that has never heard of `app`'s cgroup limit.

**Diagnosis (memory thread):**
`/balloon?mb=120&child=1` asked a forked child to hold 120 MiB of
non-zero-filled, never-collected memory inside a cgroup capped at
`memory.max = 64 MiB` with `memswap_limit` equal to `mem_limit` (swap
disabled, so there is nowhere to push a page that doesn't fit). The
kernel tried reclaim first — evicting what little page cache this
container holds — then, unable to satisfy the allocation, the cgroup's
own OOM killer fired and sent `SIGKILL` to the child. Because the victim
was a child and not `app.py`'s own PID 1, the container's cgroup survived
the kill intact, and `memory.events` still shows the count instead of
resetting to `0` — see `content/day04.md`'s **When the kill takes PID 1,
the evidence dies with it** for the harder case where it doesn't. `free`
never saw any of this either way, because it reads a file the cgroup
boundary does not touch.

**Chain of evidence — CPU thread:**
7. Claim: requests were slow throughout the incident, and the cause is
   CPU, not memory. | Proof: `cat /sys/fs/cgroup/cpu.max` → `20000
   100000` — a 20,000/100,000 microsecond quota, i.e. 0.20 of one CPU.
8. Claim: the `/burn?seconds=45` loop ran its full duration throttled,
   not truncated by any restart. | Proof: `cat /sys/fs/cgroup/cpu.stat`,
   sampled a few times across the burn, shows `nr_periods` climbing
   roughly once per 100 ms and `nr_throttled` climbing in step across the
   whole window, with `throttled_usec` accumulating — because the
   container never restarted this time, the counters were never reset
   mid-burn the way a PID-1-level OOM would have reset them.
9. Claim: this happened even though load average looked trivial. | Proof:
   a single busy thread never needs load above ~1.0 to be throttled —
   `cpu.max` is a wall-clock ceiling per period, not a function of how
   many other things are runnable.

**Diagnosis (CPU thread):**
The burst was capped to 20% of one core by `cpu.max`, so it ran in short
slices separated by forced waits; every request the same process handled
competed for those same slices, producing the sustained slowness. None of
this required a high load average to be true, and none of it was cut
short, because this incident's OOM killed a child rather than `app`'s own
PID 1.

**Fix applied:**
None — this lab's deliverable is a written diagnosis, not a repair. The
balloon's child process is already gone (the cgroup OOM killer removed
it); `app` itself never stopped, so there is nothing to restart or
repair. The only action that closes the incident is recording the two
counts below.

**Proof the fix worked (same file re-read):**
Not applicable in the repair sense. The proof required here is
`/tmp/findings` on `app`, written as `oom_kill=<n>` and
`nr_throttled=<n>`, matching a *fresh* read of `memory.events` and
`cpu.stat` at the moment `verify.sh` runs — and both greater than zero,
since a container that never experienced the incident reads `0` on both.

**What I would check first next time:**
Whether the ECS task definition backing this service sets `memory` (hard)
or only `memoryReservation` (soft, unenforced); whether its CPU units
leave headroom above the busiest single-threaded burst the task actually
produces; and, separately, whether the process an OOM is likely to take
is the task's own PID 1 — if so, the task restarts into a fresh cgroup and
the very counters that would prove the kill happened reset to zero before
anyone reads them.

**ECS mapping (the two settings, one per symptom):**
The memory symptom maps to task-definition `memory` — a hard `memory.max`
equivalent: breach triggers reclaim first, and the kill follows only once
reclaim can't keep up, exactly like this cgroup. The throttle symptom maps
to task-definition CPU units, which become a `cpu.max` quota (on Fargate,
or on EC2 with a hard per-container CPU limit) — throttling, not killing,
and invisible to CloudWatch's averaged `CPUUtilization` unless `cpu.stat`
is read directly.

# Day 4 — Resources and the Cgroup Boundary

**Truth of the day:** cgroup / namespace boundary
**Budget:** 3 h — 1 h read the file + derive the tool; 1 h core concepts and
the AWS tie-in; 1 h lab, strip the toolbox, and exercises

## Why this matters

A container dies with no application stack trace, or a request pipeline gets
slow under a load average that looks trivial, and the reflex is to blame "a
memory leak" or "the box must be busy." Neither claim is checkable without a
specific file. This day gives you the two files that settle both arguments in
seconds — `memory.events` and `cpu.stat` — and the reason every summary tool
you already know (`free`, `top`, `uptime`) can be technically correct and
still describe a system that no longer exists from where the container sits.
A cgroup enforces its own ceiling, silently, and most of the tools an
operator reaches for were never told the ceiling exists.

## Read the file first

`/proc/loadavg` and `/proc/meminfo` are decoded field by field in
`content/primers/proc-field-reference.md`, under `## /proc/loadavg` and
`## /proc/meminfo`. Read both before continuing — this section does not
repeat those tables, only the fields that primer doesn't cover.

`/proc/stat`'s first line is the system-wide CPU counter the primer omits:

```
cpu  201845 47 55621 4032918 8321 0 1233 0 0 0
```

Whitespace-separated, fields after the literal `cpu` label, in this fixed
order: `user nice system idle iowait irq softirq steal guest guest_nice`.
Two facts matter more than the field names:

- Every number is a **cumulative count of jiffies since boot** — USER_HZ
  ticks, usually 100 per second (`getconf CLK_TCK` confirms it on the box in
  question; never assume). A single read is a running total, not a rate.
- A rate — "percent busy over the last second" — requires **two samples**
  and a subtraction: `(Δtotal − Δidle) / Δtotal`, where `idle` is `idle +
  iowait` and `total` is the sum of all eight fields. This is exactly the
  calculation **Strip the toolbox** below asks you to write by hand.

`/proc/pressure/{cpu,io,memory}` — Pressure Stall Information, one file per
resource:

```
some avg10=0.00 avg60=0.00 avg300=0.00 total=0
full avg10=0.00 avg60=0.00 avg300=0.00 total=0
```

`some` means at least one task was stalled waiting on that resource; `full`
means every non-idle task was stalled at once. Since Linux 5.13,
`/proc/pressure/cpu` does carry a `full` line, but at the system level it
always reads zero — every non-idle task stalled on CPU at once means the
CPU is idle by definition, a contradiction at that level, so the number
that would express it can only ever be `0`. `avgN` is a percentage of
wall-clock time, averaged over a decaying `N`-second window; `total` is a
running microsecond counter, same cumulative-since-boot shape as
`/proc/stat`.

Then the cgroup v2 files this day is really about — `memory.current`,
`memory.max`, `memory.events`, `cpu.max`, `cpu.stat` — are all covered under
`## /sys/fs/cgroup (v2)` in the same primer, including that `memory.events`'
`oom_kill` field and `cpu.stat`'s `nr_throttled`/`throttled_usec` fields are
the two counters this whole day pivots on. Read that table now if you
haven't; the rest of this page assumes it.

## Derive the tool

`uptime` prints the three `/proc/loadavg` averages plus the clock and a
logged-in-user count — nothing else. `free -m` is a formatter over
`/proc/meminfo` that converts kB to MiB and *computes* `available` from
several fields rather than echoing one (see `MemAvailable` below). `top`'s
header line repeats `/proc/loadavg`; its per-process `%CPU` column is
computed the same way `ps` computes cumulative CPU time — two
`/proc/PID/stat` `utime+stime` samples, divided by elapsed wall time.
`vmstat 1` samples `/proc/stat` (and `/proc/meminfo`) twice, one second
apart, and prints the delta — precisely the arithmetic **Strip the toolbox**
below has you reproduce with `awk` and no `vmstat` at all.

Say this one precisely, because it is the entire reason this lab's symptom
is confusing: **`free`, run inside a container, reads the **host's**
`/proc/meminfo`.** Containers namespace PIDs, mounts, and network, but there
is no per-container `/proc/meminfo` — every container on the same Docker
Desktop VM sees the identical host-wide totals. Run `free -m` inside `app`
at the exact instant its 64 MiB memory cgroup is about to OOM-kill it, and
it will report several gigabytes of host RAM as free and available. That is
not a bug in `free`; it is faithfully printing the only file the kernel
exposes at that path, and that file has never heard of `app`'s cgroup limit.

## Core concepts

### Load average is a queue, not a CPU gauge

The primer's `/proc/loadavg` table already states the mechanism: the first
three fields count tasks in state `R` (runnable) **plus** state `D`
(uninterruptible sleep, usually blocked on disk or network I/O) — not CPU
demand. The consequence is the one that bites in an incident: a box pegged
on a slow NFS mount or a failing EBS volume reports a high load average with
a bored CPU, because every stuck `D`-state task adds to the count the same
way a CPU-bound `R`-state task does. Load average answers "how many things
are waiting for something," never "what is the CPU doing" — that second
question is `%iowait` and `%CPU`, read separately.

### `%iowait` is idle time, not work

`/proc/stat`'s `iowait` field is time the CPU spent **idle** while at least
one I/O request was outstanding. It is bucketed with idle for a reason: the
CPU did nothing during it. A high `%iowait` says "something is waiting on a
device," not "the CPU is busy" — treating it as CPU load produces the same
wrong incident call as trusting load average alone.

### RSS, shared memory, page cache, and `MemAvailable`

A process's `VmRSS` (`/proc/PID/status`) splits into three parts: `RssAnon`
(heap and stack — genuinely owned by this process alone), `RssFile` (mapped
files and shared libraries — often mapped by many processes at once, so
summing RSS across processes overcounts real physical usage), and
`RssShmem` (shared memory **and tmpfs pages this process has faulted in**
— the exact accounting the next section depends on: a process that has
merely written into a `tmpfs`-mounted directory carries that memory here,
not in `RssAnon`, and it counts against the cgroup all the same).

System-wide, `Cached` in `/proc/meminfo` is the kernel's page cache for
file contents: reclaimable under pressure, and a *full* cache is a sign of
a healthy system using spare RAM well, not a leak. `MemFree` is not usable
memory — it excludes every reclaimable page. `MemAvailable` already
accounts for what the kernel could reclaim without swapping, which is why
it is the only number worth quoting when someone asks "how much memory can
a new process actually get."

### tmpfs is memory, and it is charged to a cgroup

This is new: a `tmpfs` mount is backed by `shmem` — RAM, not disk — and its
pages are charged to **whichever memory cgroup faults them in**, exactly
like heap or file-cache pages. Writing to a `tmpfs`-mounted directory
consumes the *writer's* memory budget, invisibly, with no `df`-visible disk
behind it at all.

This fleet is the worked example. `app`'s `/var/log` is a 24 MiB `tmpfs`
inside a 64 MiB `mem_limit` — deliberately 24, not 64. With swap disabled
(`memswap_limit` equal to `mem_limit`, so there is nowhere to push a page
that won't fit), a 64 MiB `tmpfs` inside a 64 MiB limit would let a log
write alone consume the entire cgroup budget and OOM-kill the container —
and the symptom would look like Day 1's "disk full" incident (`dd`/log
writes failing) when the true cause is Day 4's resource class entirely. 24
MiB leaves headroom for the Python interpreter's own resident memory
alongside the log volume.

The AWS-shaped version of this mistake is common and easy to miss: an ECS
task with a `tmpfs` volume mount can be OOM-killed while every
application-level memory metric — heap size, RSS as reported by an APM
agent that only tracks the process's own allocations — looks nearly idle.
The tmpfs bytes never show up in "how much memory did my code allocate,"
but they count in full against the task's cgroup limit, and the OOM killer
does not care which subsystem asked for the page.

### The OOM killer: score, adjustment, cgroup versus global

The **global** OOM killer fires when the whole host is critically short of
free memory and swap; it scans every process on the machine, computes an
`oom_score` from each one's memory footprint adjusted by `oom_score_adj`
(a per-process bias, `/proc/PID/oom_score_adj`, range −1000 to 1000; −1000
means "never kill this one"), and kills the highest-scoring process to free
memory system-wide.

The **cgroup** OOM killer is scoped to one cgroup and fires independently of
host-wide memory pressure: when an allocation inside that cgroup would push
`memory.current` past `memory.max` and reclaim inside the cgroup cannot free
enough to satisfy it, the kernel kills a process **inside that cgroup only**
— chosen by the same `oom_score` ranking, restricted to that cgroup's
members. A container can be cgroup-OOM-killed while the host it runs on has
gigabytes of memory to spare, because the global OOM killer was never
consulted at all.

### Exceeding `memory.max` does not mean dead — yet

State this precisely, because it is the difference between "we are over the
limit" and "we are dead," and it is this day's central nuance: hitting
`memory.max` does **not** trigger an immediate kill. The kernel first tries
direct reclaim on that allocation — evicting the cgroup's own page cache,
reclaiming what it can — and the allocating thread stalls while this
happens, which is functionally a throttle: forward progress slows or
briefly stops while the kernel works. Only if reclaim cannot free enough to
satisfy the allocation does the cgroup's OOM killer step in and send
`SIGKILL`. A cgroup can sit right at its ceiling, under sustained reclaim
pressure, without anything dying — "over the limit" and "about to be
killed" are different states, and `memory.events`' `oom_kill` counter is
the only field that tells you the second one actually happened.

### When the kill takes PID 1, the evidence dies with it

If the process the cgroup OOM killer picks is the container's PID 1 (or the
only thing keeping its entrypoint alive — here, `sh -c "python
/srv/app.py; exit $?"`), the container itself exits, and a restart policy
typically brings it back as a **new task with a brand-new leaf cgroup**.
That fresh cgroup's `memory.events` and `cpu.stat` start back at `0` — the
exact counters that would have proven the kill happened are destroyed by
the kill itself. Read `memory.events` a minute later and you'll see
`oom_kill 0`, which looks exactly like nothing happened.

This is why operators fall back to evidence that lives **outside** the
cgroup that died: the container's own exit code (`137` = `128 + SIGKILL`),
`docker inspect`'s `.State.OOMKilled` boolean, and, in ECS, the task's
stopped reason plus whatever CloudWatch captured before the restart. None
of that evidence lives inside the cgroup the kernel just tore down, so
none of it is destroyed by the event it describes.

It is also why this day's graded lab kills a **child** process of `app`
instead of its PID 1: the child's death lets `app`'s own cgroup — and its
counters — survive to be read, which is the only way a lab can ask you to
prove an OOM from `memory.events` at all. A PID-1-level OOM, the kind that
erases its own evidence, is exactly the harder case this subsection just
described, and it is the case a real incident hands you far more often
than a conveniently-surviving cgroup.

### cgroup v2: hierarchy and delegation

cgroup v2 is a single unified tree rooted at `/sys/fs/cgroup`, with one set
of controllers (`memory`, `cpu`, `io`, `pids`, …) attached per node instead
of v1's one-tree-per-controller sprawl. A container is a cgroup (or a small
subtree of one) that the container runtime creates and manages; the
container's own cgroup namespace makes that cgroup *appear* as the root of
`/sys/fs/cgroup` from inside the container, so a process in `app` can read
`/sys/fs/cgroup/memory.max` directly and see only its own limit — never a
sibling container's cgroup, and never the host's root cgroup. That
visibility boundary, delegated by the runtime, is what "namespace boundary"
means in this day's title as much as the resource limits do.

### CPU quota: `quota/period`, and why 0.20 CPUs throttles one thread

`cpu.max` reads as two space-separated microsecond values, `QUOTA PERIOD`
(or the literal word `max` for quota, meaning unlimited). This fleet's `app`
is configured with `cpus: 0.20`, which Docker expresses as a `cpu.max` of
`20000 100000` — 20,000 out of every 100,000 microsecond period, i.e. 20% of
one CPU. A single thread that only ever wants one core will burn its 20 ms
allotment early in each 100 ms period and then be scheduled off by the
kernel until the next period starts — regardless of how many *other*
threads or processes are runnable at the time. This is why a completely
single-threaded burst throttles even at a trivial load average: quota is a
wall-clock ceiling per period, not a function of contention.

### PSI: saturation, not utilisation

Utilisation asks "how much of the resource is in use." PSI asks a sharper
question: "is anything actually stuck waiting for it." `some avg10=45.0`
for `io` means that, averaged over the trailing 10 seconds, at least one
task was stalled on I/O for 45% of that window — a severe, sustained
queueing condition, independent of whether the device itself reports low
raw throughput. PSI is the metric that answers "is this saturation or just
utilisation" precisely because a resource can be lightly utilised and still
badly saturated (one slow disk, many waiters) or heavily utilised and not
saturated at all (many fast, independent operations).

## Lab

See `labs/day04/`. The goal: produce a diagnosis of two boundary failures on
`app` — one memory, one CPU — using only the cgroup v2 files, never `free`
or `top`. Success signal: `bash labs/day04/verify.sh` exits `0`.
Run `break.sh`, then write your numbered chain of evidence into
`journal.md` **before** you write your findings file — this lab's
deliverable is a diagnosis, not a repair; see `labs/day04/README.md` for the
exact contract `verify.sh` grades against. The memory incident kills a
child process of `app`, not its PID 1, so `app`'s own cgroup — and its
counters — survive for you to read; see **When the kill takes PID 1, the
evidence dies with it** above for why that distinction matters.

## Strip the toolbox

In `slim` — busybox `sh` and busybox `awk`, no `top`, no `vmstat` — compute a
1-second CPU utilisation rate from two raw `/proc/stat` samples:

```sh
read -r _ u1 n1 s1 i1 io1 irq1 sq1 st1 _ < /proc/stat
sleep 1
read -r _ u2 n2 s2 i2 io2 irq2 sq2 st2 _ < /proc/stat
awk -v u1="$u1" -v n1="$n1" -v s1="$s1" -v i1="$i1" -v io1="$io1" \
    -v irq1="$irq1" -v sq1="$sq1" -v st1="$st1" \
    -v u2="$u2" -v n2="$n2" -v s2="$s2" -v i2="$i2" -v io2="$io2" \
    -v irq2="$irq2" -v sq2="$sq2" -v st2="$st2" 'BEGIN {
  idle1 = i1 + io1; idle2 = i2 + io2
  tot1 = u1+n1+s1+i1+io1+irq1+sq1+st1
  tot2 = u2+n2+s2+i2+io2+irq2+sq2+st2
  dtot = tot2 - tot1; didle = idle2 - idle1
  printf "cpu busy: %.1f%%\n", (1 - didle / dtot) * 100
}'
```

Every step here is POSIX `sh` `read` and busybox `awk` with `-v` bindings —
no arrays, no bash-only features, nothing `slim` doesn't ship. The same
`Δtotal`/`Δidle` arithmetic is what `top`, `vmstat`, and `mpstat` all run
internally; you're just no longer trusting a binary to have run it for you.

## Exercises

1. From two `/proc/stat` samples taken 1 second apart, compute the busy
   percentage for `cpu0` specifically — the first per-CPU line, not the
   aggregate `cpu` line. **Hint:** per-CPU lines (`cpu0`, `cpu1`, …) sit
   below the aggregate `cpu` line and share its exact eight-field order.
   **Solution sketch:** apply the same `(1 − Δidle/Δtotal) × 100` formula
   from **Strip the toolbox**, reading `cpu0`'s fields instead of `cpu`'s.

2. A box reports `load average: 8.0, 7.9, 7.5` while CPU utilisation sits
   at 5%. Explain how both numbers can be true at once. **Hint:**
   `/proc/loadavg`'s first three fields count two process states, not one.
   **Solution sketch:** most of the ~8 counted tasks are in state `D`
   (uninterruptible I/O sleep — a slow NFS mount or a failing volume are
   classic causes), not `R`; `D`-state tasks inflate load average without
   ever touching the CPU, so `%CPU` stays low while load stays high.

3. From `memory.events`, prove that a cgroup OOM occurred and state how
   many times. **Hint:** the file has more than one counter with "oom" in
   the name — only one of them counts an actual kill.
   **Solution sketch:** read the `oom_kill` line, e.g. `oom_kill 2`; a
   nonzero value proves this cgroup's own OOM killer fired, and the number
   itself is the count of processes it killed — distinct from `oom` (a
   near-limit event that need not have killed anything) and from the
   host's separate, global OOM killer.

4. Given `cpu.max` reads `20000 100000`, compute the effective CPU limit
   and predict `cpu.stat`'s behaviour during a sustained single-threaded
   burst. **Hint:** `cpu.max` is `QUOTA PERIOD`, both microseconds.
   **Solution sketch:** `20000 / 100000 = 0.20` CPUs. A thread wanting a
   full core burns its 20 ms allotment early in each 100 ms period, then
   is parked; `nr_periods` climbs roughly ten times per second, `nr_throttled`
   climbs in step with it, and `throttled_usec` accumulates the parked time.

5. Explain why `free` reports many gigabytes available inside a container
   whose `mem_limit` is 64 MiB. **Hint:** `free` has exactly one file to
   read, and that file is not namespaced per container.
   **Solution sketch:** `free` formats `/proc/meminfo`, which is the
   **host's** memory, full stop — there is no per-cgroup `/proc/meminfo`.
   The real ceiling lives at `/sys/fs/cgroup/memory.max`, a file `free`
   never opens.

6. PSI reports `some avg10=45.0` for `io`. State precisely what that means
   for user-visible latency. **Hint:** "some" and `avg10` are both exact
   definitions, not "45% of requests were slow."
   **Solution sketch:** over the trailing 10-second window, at least one
   task was stalled waiting on I/O for an average of 45% of the time — a
   sustained, severe queueing condition on that resource. It says nothing
   about which requests were affected or by how much, only that the
   resource itself was saturated for nearly half of every recent second.

## Anti-patterns / Common mistakes

- **Mistake 2** (trusting the summary tool): quoting `free`'s "free" column
  as available memory, or reading load average as a CPU gauge. Both are
  exactly the folk readings this day's core concepts correct, and both
  produce a wrong incident call under pressure — scaling compute for a
  memory-reporting artifact, or blaming the CPU for a stuck volume.
- **Mistake 4** (practising on a healthy box): running `free`, `top`, or
  `cpu.stat` against a system with nothing wrong builds recognition, not
  diagnosis — every field returns a plausible-looking value and none of
  them is falsifiable. This day's lab exists so you've watched a real
  cgroup OOM and a real CPU throttle with your own eyes before an incident
  forces the question at 2 a.m.

## Where this shows up in AWS

ECS task definitions carry two memory settings that map directly onto what
you just diagnosed. `memory` becomes this task's `memory.max` — a hard
cgroup ceiling. Breaching it triggers reclaim first, exactly as described
in **Exceeding `memory.max` does not mean dead — yet** above, and the kill
follows only once reclaim can't satisfy the allocation — the same sequence
as `app`'s 64 MiB limit, just with less headroom to make the reclaim
window visible. `memoryReservation` is a *soft* value used only for
bin-packing tasks onto hosts; on its own it enforces nothing, and a task
with only a `memoryReservation` can grow until it starves the host. When a
task dies this way, ECS reports `ECS task stopped: OutOfMemoryError` with
**no application stack trace**, because the kill is a `SIGKILL` delivered
by the kernel's cgroup OOM path from *outside* the process — there is no
signal handler, no exception to catch, nothing for the runtime to log on
the way down. The only evidence is exactly `memory.events`' `oom_kill`
counter, which ECS is summarising as that string — and if the kill took
the task's own PID 1, the restarted task's counter is back at zero, per
**When the kill takes PID 1, the evidence dies with it** above.

CPU units in a task definition (1024 units = 1 vCPU) become a `cpu.max`
quota the same way this fleet's `cpus: 0.20` became `20000 100000` — true
on Fargate, and on EC2 whenever a hard per-container CPU limit is set; on
EC2 without one, the same units instead become `cpu.shares`/`cpu.weight`,
a scheduling priority rather than a ceiling, which never throttles on an
otherwise-idle host. Where the quota does apply, a task given 256 CPU
units gets a `25000 100000` quota — 0.25 CPUs — and a single-threaded
burst above that throttles exactly like Exercise 4, producing a p99
latency cliff on individual requests. CloudWatch's `CPUUtilization` metric
is an *average* over its reporting period, so a task throttled hard for
200 ms out of every second can still show a modest, unremarkable average
value — the counters that would actually show it, `nr_throttled` and
`throttled_usec` from `cpu.stat`, are not something CloudWatch surfaces by
default; reading them means exec-ing into the task.

## Teardown

Full checklist: `labs/day04/teardown.md`. In short: force-recreate `app` so
its cgroup counters and in-memory balloon reset to zero before Day 5,
confirm `journal.md` has today's entry, and leave the rest of the fleet
running — full multi-day teardown is `bash labs/verify-teardown.sh`, run
only when the whole path is finished.

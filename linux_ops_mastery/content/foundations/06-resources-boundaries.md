# Foundations 06 — Resources and boundaries

**Prepares you for:** Days 4 and 6.
**Time:** about 45 minutes with the try-it steps.

Day 4 asks why a container died while `free` showed spare memory;
Day 6 why a service is unreachable from its neighbour. Both are
boundaries: how much a process may use, and how much it may see.

## What you'll be able to explain

- Every process sees its own private address space. RSS is the part
  actually sitting in RAM now, and shared pages are counted in each
  process that maps them.
- Spare RAM is used as a page cache for file data, so "free" is
  normally low. `MemAvailable` is the number that says what a new
  process could really get.
- The OOM killer picks a victim when memory runs out, either for the
  whole machine or for one cgroup. Going over a cgroup's `memory.max`
  first forces reclaim, and the kill comes only if reclaim fails.
- Load average is a count of tasks that are running, waiting to run
  or stuck in `D`. It is not a CPU percentage.
- A cgroup is a directory of limit files that caps a group of
  processes. A namespace gives a process its own view of one thing.
  Docker is ordinary processes plus both, plus overlay, on one kernel.

## The mental model

### Virtual memory: every process gets its own map

A process never touches RAM addresses directly. The kernel gives it a
private **address space** of **virtual addresses** that the hardware
translates to physical RAM on every access. Two processes can both use
address `0x1000` and never collide, since each maps to different
physical **pages** (fixed chunks, typically 4 KiB). A page gets real
RAM only when first touched, so a program can reserve far more address
space than it uses; that total is its **virtual size**, and it says
little about real usage.

What matters is the **RSS** (resident set size): how many of the
process's pages are in physical RAM right now. Different processes can
map the same physical page, for example every program that loads the
same shared library. Each of them counts that page in its own RSS, so
adding up RSS across all processes **overcounts** real memory. Day 4
splits RSS into anonymous (no file behind it), file and shared parts.

### Where RAM goes: process memory, page cache, free

Physical RAM is not simply "used" or "free". It has three parts that
matter:

```
  physical RAM
  +-------------------+----------------------+-----------------+
  | process memory    | page cache           | free            |
  | heap and stack,   | file data kept for   | untouched,      |
  | no file behind it | reuse; reclaimable   | truly empty     |
  +-------------------+----------------------+-----------------+
                      \__ MemAvailable: reclaimable cache plus free __/
```

The **page cache** is the kernel keeping recently read or written file
data in spare RAM so the next read skips the disk. Chapter 04's read
and write system calls usually go through it. The cache is
**reclaimable**: when a process needs memory the kernel drops cache
pages first, instantly for clean ones, with no loss.

On a healthy, busy machine the page cache grows until "free" looks
tiny. That is the kernel using spare RAM well, not a leak. `MemFree` in
`/proc/meminfo` counts only the untouched part. **`MemAvailable`**
estimates how much a new process could get without swapping, counting
reclaimable cache. To answer "how much memory is left", quote
`MemAvailable`, not "free".

**Swap** is disk space where the kernel can park pages a process has
not touched lately. Reading them back is far slower than RAM. With swap
switched off, as in Day 4's `app` container, there is nowhere to push
such a page, so the OOM killer (next) is more likely to fire.

`tmpfs` (chapter 01) lives in RAM, so writing to it **consumes memory**,
and it is not reclaimable like clean cache; only swap can move it.
The cgroup that first touches a `tmpfs` page is charged for it.

### The OOM killer: when memory truly runs out

If the kernel cannot satisfy a memory request even after dropping cache
(and swapping, if enabled), it picks a process and ends it with
`SIGKILL` (chapter 03), freeing its memory. This is the **OOM killer**
(out-of-memory killer). There are two cases:

- **Global**: the whole machine is short; all processes are candidates.
- **Cgroup**: one cgroup hit its own `memory.max` limit (cgroups
  below) though the machine has plenty; only its processes are candidates.

Either way each candidate gets an **`oom_score`**, higher for a bigger
memory footprint, and the highest score is killed. A per-process
**`oom_score_adj`** nudges the score up or down. It is a number from
-1000 to 1000, and -1000 means "never kill this one". Both live in
`/proc/PID/`. Day 4 goes further on scoring.

The kill arrives from outside, with no exception or stack trace. An
OOM-killed container often leaves only exit status `137`, which is 128
plus 9, the number of `SIGKILL` (chapter 03).

### Exceeding `memory.max` does not mean dead, yet

This one is easy to get wrong. A cgroup that touches its limit is **not
killed on the spot**. First the kernel **reclaims**: it tries to free
memory inside that cgroup, mostly by dropping its own page cache. The
thread that asked for memory waits while this happens, so the program
slows down or briefly stalls. Only when reclaim cannot free enough does
the cgroup OOM killer step in. A cgroup can sit pinned at its ceiling,
reclaiming constantly, without anything dying.

So "over the limit" and "killed" differ. The counter proving a kill
happened is `oom_kill` in the cgroup's `memory.events` file.

### CPU: the scheduler, run queue and load average

A CPU core runs one task at a time. The **scheduler** is the kernel
code that decides which **runnable** task (state `R`, chapter 02) gets
a core next and for how long, then switches to another after a short
slice. With more runnable tasks than cores, the extra ones wait in
line. That line is the **run queue**.

**Load average** is the kernel's smoothed count of tasks that want to
run: those running or waiting for a core (`R`) **plus** those stuck in
uninterruptible sleep (`D`), usually waiting on a disk or network
filesystem. It is reported as three numbers, averaged over roughly 1,
5 and 15 minutes.

Two consequences, which Day 4 builds on:

- It is **not a percentage** and not CPU utilisation. A load of 4 on a
  4-core machine means about four tasks wanting service, not 4% busy.
- It includes `D`. An idle CPU with eight processes stuck on a dead
  network disk reports a load near 8. This matches chapter 02: load
  average counts `R` and `D`. It never says what tasks wait for.

### cgroups: limits on a group of processes

A **cgroup** (control group) is a group of processes that the kernel
accounts and limits together. **cgroup v2**, the current version, is a
single tree of directories rooted at `/sys/fs/cgroup`. Like `/proc`
(chapter 00), it is a view the kernel generates, not files on a disk.
Each directory is one cgroup; **limits are values in files** inside it.

```
  /sys/fs/cgroup                       (host root: no limit files)
  |-- cgroup.procs, cgroup.controllers ...
  `-- system.slice/docker-<id>.scope/   <- a container's cgroup
        |-- cgroup.procs    <- PIDs in this group
        |-- memory.max      <- memory ceiling: "max" or bytes
        |-- memory.current  <- memory used now
        |-- memory.events   <- counters: oom_kill, ...
        |-- cpu.max         <- "QUOTA PERIOD" in microseconds
        `-- cpu.stat        <- counters: nr_throttled, ...
```

The host's root cgroup has no limit files; inside a container the
cgroup namespace makes the container's own (non-root) cgroup look like
the root, which is why `cat /sys/fs/cgroup/memory.max` works in `ws`.

A process belongs to exactly one cgroup, and a child it forks (chapter
02) starts in the same one. Chapter 05 explains that systemd runs each
service in its own cgroup; a container runtime makes one per container too.

The two limits to know:

- **`memory.max`** is the memory ceiling in bytes, or the word `max`
  for no limit. Past it, reclaim and then the cgroup OOM kill, as above.
  `memory.current` is the live usage. Page cache and `tmpfs` pages
  count toward it, so a cgroup full of log files in a `tmpfs` can be
  killed while the application's own heap is small.
- **`cpu.max`** is two numbers, `QUOTA PERIOD`, in microseconds, or
  `max` for unlimited quota. `20000 100000` means: in each 100,000 us
  (100 ms) window the group may use 20,000 us (20 ms) of CPU, which
  is 0.20 of one core.

When the group spends its quota early in a period, the kernel stops
scheduling it until the next period begins. This is **throttling**. It
is a hard wall-clock ceiling, not a response to contention. A single
thread that wants a full core burns its 20 ms in the first fifth of
every window and then waits, even on an otherwise idle machine, which
is why load average can look trivial during a throttle. Counters in
`cpu.stat` (`nr_throttled`, `throttled_usec`) record it.

### PSI: are tasks stuck waiting?

Utilisation says how much of a resource is in use. **PSI** (pressure
stall information) asks sharper: how much of the time were tasks stuck
waiting for it? The kernel exposes it in `/proc/pressure/cpu`,
`/proc/pressure/memory` and `/proc/pressure/io`, and per cgroup as
`cpu.pressure`, `memory.pressure` and `io.pressure`.

For example `some avg10=45.00` on `io` means that over the last 10
seconds, at least one task was stalled on I/O for 45% of the time. A
device can look lightly used yet be saturated (one slow disk, many
waiters), or busy yet not saturated. Day 4 goes further on PSI.

### Namespaces: walls on what a process can see

A **namespace** gives a process its own private view of one kind of
system thing. Processes in different namespaces see different
versions of that one thing, while the kernel stays one. Linux has
several kinds:

| Namespace | The process gets its own... |
|---|---|
| `pid` | process numbering (chapter 02): the first process is PID 1 |
| `net` | network interfaces, addresses and routes (chapter 07) |
| `mnt` | mount table (chapter 01): what is mounted where |
| `uts` | hostname |
| `ipc` | shared-memory and message-queue objects between processes |
| `user` | mapping of user and group numbers (chapter 05 explains users) |
| `cgroup` | view of the cgroup tree: its own cgroup looks like the root |

Each namespace is a kernel object with an inode number. Every process
has links to its namespaces in `/proc/PID/ns/`, one per type. For
example `net -> 'net:[4026532555]'`: the number in brackets is the
namespace's inode. **Two processes with the same number for a type
share that namespace; different numbers mean separate ones.** That one
comparison settles "are these two processes in the same network
namespace?" (Day 6 uses it).

A child made by `fork` (chapter 02) starts in its parent's namespaces;
the runtime gives a container's first process a fresh set, so everything
it spawns shares the same walls.

Two namespaces carry lessons for later:

- **`net`**: each has its own interfaces, including its own loopback
  `127.0.0.1` (chapter 07). A service on loopback in one container is
  reachable only from that same namespace. Day 6 goes further on this.
- **`cgroup`**: inside a container, `/sys/fs/cgroup` shows the
  container's **own** cgroup as the root. So `memory.max` there is the
  container's own limit (`max` if none was set). From inside you cannot
  see sibling containers or the host's root cgroup.

One more Day 4 point: `free` and `/proc/meminfo` are not namespaced,
so inside a container they still show the **host's** memory. The real
ceiling is `memory.max`, a file `free` never opens.

### Docker, in one picture

A container is ordinary processes with three things around them:
namespaces (walls), cgroups (limits) and an overlay root filesystem
(chapter 01), all on one shared kernel.

```
  +------------------------------------------------------------+
  |                        host kernel                         |
  |  one scheduler, one page cache, one set of device drivers  |
  |                                                            |
  |  +-----------------------+    +-----------------------+    |
  |  | container "app"       |    | container "db"        |    |
  |  | pid ns:   own PIDs    |    | pid ns:   own PIDs    |    |
  |  | net ns:   own eth0    |    | net ns:   own eth0    |    |
  |  | mnt ns:   own mounts  |    | mnt ns:   own mounts  |    |
  |  |  (overlay root)       |    |  (overlay root)       |    |
  |  | cgroup:   memory.max  |    | cgroup:   memory.max  |    |
  |  |           cpu.max     |    |           cpu.max     |    |
  |  +-----------------------+    +-----------------------+    |
  +------------------------------------------------------------+
```

There is no virtual machine and no second kernel. Anything not
namespaced, such as the kernel version, is shared.

## How it connects

- **Chapter 00's `/proc` and `/sys`** hold all of this: `meminfo`,
  `loadavg`, `pressure/*`, `PID/ns/*` and `/sys/fs/cgroup`.
- **Chapter 01's `tmpfs` and `overlay`**: `tmpfs` bytes are memory
  charged to a cgroup; a container's `/` is overlay in a mount namespace.
- **Chapters 02 and 03**: `R`/`D` states feed load average, the PID
  namespace makes a container's first process PID 1, and `SIGKILL` is how
  the OOM killer ends its victim.
- **Chapter 05** (explains users and systemd): systemd uses a cgroup per service.
- **Day 4** builds on cgroups, PSI, OOM and throttling; **Day 6** on
  the network namespace (chapter 07 supplies the network vocabulary).

## See it yourself

Use the `ws` container: from `labs/fleet`, run
`docker compose -p linuxops exec ws bash`. Every step only observes.

```bash
head -8 /proc/meminfo; free -m
```

**What to look for:** `MemTotal`, `MemFree`, `MemAvailable` and
`Cached` (page cache, tmpfs included). `MemFree` is usually well below
`MemAvailable`. These are the **host VM's** numbers, not a limit on `ws`.

```bash
cat /proc/loadavg; nproc
```

**What to look for:** the first three numbers are the 1, 5 and 15
minute load averages; compare to the core count from `nproc`. The
fourth field is `running/total` tasks (a count).
It is a count of tasks, not a percentage.

```bash
cat /proc/self/cgroup; ls /sys/fs/cgroup | head -30
```

**What to look for:** under cgroup v2 one line starting `0::`. In a
container with its own cgroup namespace the path is `/`, since your own
cgroup is shown as the root. The listing shows `cgroup.*`, `memory.*`,
`cpu.*` and `io.*` files: the control surface.

```bash
cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/cpu.max 2>&1
```

**What to look for:** either a number of bytes or the word `max`
(no limit) from `memory.max`, and `QUOTA PERIOD` (or `max 100000`)
from `cpu.max`. This is the limit of `ws`'s own cgroup, since a
container sees its own cgroup as the root.

```bash
ls -l /proc/self/ns; ls -l /proc/1/ns/pid /proc/$$/ns/pid
```

**What to look for:** at least these seven types (`cgroup`, `ipc`,
`mnt`, `net`, `pid`, `user`, `uts`), each pointing to `type:[number]`;
newer kernels also show `time`, `pid_for_children` and
`time_for_children`, which you can ignore here.
`/proc/1/ns/pid` and `/proc/$$/ns/pid` carry the same number: same
namespace.

```bash
cat /proc/$$/oom_score /proc/$$/oom_score_adj
```

**What to look for:** `oom_score` is the kernel's ranking for your
shell; compare it with other processes (in a container even small ones
can score high). `oom_score_adj` is its bias, usually `0`, -1000 to 1000.

## Words you'll meet in the course

- **load average** — Day 2, *Process states and load average* ([glossary](../GLOSSARY.md))
- **RSS** — Day 4, *RSS, shared memory, page cache, and `MemAvailable`* ([glossary](../GLOSSARY.md))
- **page cache** — Day 4, *RSS, shared memory, page cache, and `MemAvailable`* ([glossary](../GLOSSARY.md))
- **MemAvailable** — Day 4, *RSS, shared memory, page cache, and `MemAvailable`* ([glossary](../GLOSSARY.md))
- **oom_score_adj** — Day 4, *The OOM killer: score, adjustment, cgroup versus global* ([glossary](../GLOSSARY.md))
- **memory.max** — Day 4, *Exceeding `memory.max` does not mean dead — yet* ([glossary](../GLOSSARY.md))
- **quota/period** — Day 4, *CPU quota: `quota/period`, and why 0.20 CPUs throttles one thread* ([glossary](../GLOSSARY.md))
- **PSI** — Day 4, *PSI: saturation, not utilisation* ([glossary](../GLOSSARY.md))
- **cgroup namespace** — Day 4, *cgroup v2: hierarchy and delegation* ([glossary](../GLOSSARY.md))
- **network namespace** — Day 6, *Listening on `127.0.0.1` versus `0.0.0.0`* ([glossary](../GLOSSARY.md))

## Self-check

1. `free` inside a 64 MiB container reports gigabytes available, yet
   the container is OOM-killed. Why do both hold?
2. A process reaches its cgroup's `memory.max` and slows to a crawl,
   but `oom_kill` is still `0`. What is the kernel doing, and when
   would `oom_kill` become non-zero?
3. A server shows load average 9 on 4 cores, but `top` shows the CPU
   mostly idle. Which task states could explain that? Is load average
   a percentage?
4. A single-threaded program in a cgroup with `cpu.max` of
   `20000 100000` stutters on an idle machine. Why? What is the limit
   as a fraction of a core?
5. You run `ls -l /proc/self/ns` in two containers and the `net`
   numbers differ, while `uts` numbers match. What does each fact tell
   you? Can one container's loopback reach the other's service?
6. Describe a Docker container in one sentence using the words
   namespace, cgroup, overlay and kernel. Why is `memory.max` visible
   at `/sys/fs/cgroup` inside it, and what does `max` there mean?

<details><summary>Answers</summary>

1. `free` formats `/proc/meminfo`, which is not namespaced per
   container, so it reports the host's memory. The kill is decided by
   the container's own cgroup limit, `memory.max`, which `free` never
   reads. The global OOM killer is not involved at all.
2. The kernel is reclaiming: dropping the cgroup's page cache and
   making the allocating thread wait. `oom_kill` becomes non-zero only
   if reclaim fails to free enough, and then the cgroup OOM killer
   sends `SIGKILL` to a process inside that cgroup.
3. Load average counts `R` and `D`. If many tasks sit in `D`, waiting
   on a slow or hung disk or network filesystem, load is high with an
   idle CPU. It is a count of tasks, not a percentage.
4. Throttling. The group may use 20 ms of CPU per 100 ms period, which
   is 0.20 of a core. The thread burns it early and is parked until the
   next period, even if no one else wants the CPU.
5. Different `net` numbers mean separate network namespaces, with their
   own interfaces and loopback; equal `uts` numbers mean they share a
   hostname namespace. A service on loopback in one is unreachable via
   the other's loopback.
6. A container is ordinary processes on the host kernel, walled by
   namespaces, limited by a cgroup and rooted in an overlay filesystem.
   The cgroup namespace shows the container's own cgroup as the root,
   so `memory.max` is its own limit; `max` means none was set.

</details>

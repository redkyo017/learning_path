# /proc field reference

Read this when the tool you'd normally reach for (`ps`, `free`, `netstat`,
`systemd-cgtop`) is missing from the container, or when you need the raw
number the tool is summarizing. Every section names the tool it replaces —
learn the field, not just the shortcut.

## /proc/PID/stat

Single line, space-separated, `comm` (field 2) wrapped in parens and the only
field that can itself contain spaces or parens — parse from the right of the
last `)` if you're scripting this with `awk`.

| Field # | Name | Meaning | Why an operator cares |
|---|---|---|---|
| 1 | pid | Process ID | Join key into status/fd/cgroup for this PID |
| 2 | comm | Exe name, truncated to 15 bytes | Long names get silently cut |
| 3 | state | R/S/D/Z/T/t single char | D = uninterruptible I/O sleep |
| 4 | ppid | Parent PID | Walk process tree without pstree |
| 10 | minflt | Minor page faults (no disk I/O) | Rising fast = RSS is growing |
| 12 | majflt | Major page faults (disk I/O) | Sustained = memory pressure or swap |
| 14 | utime | Ticks in user mode | Divide by sysconf(_SC_CLK_TCK), usu. 100 |
| 15 | stime | Ticks in kernel mode | High = syscall-heavy or lock-contended |
| 20 | num_threads | Live thread count | Runaway thread creation shows here first |
| 23 | vsize | Virtual mem size, bytes | Includes unmapped space, not real usage |
| 24 | rss | Resident set size, in **pages** | Must multiply by page size — see below |

**The field-24 trap:** `rss` is a page count. To get bytes you must multiply
by the page size — `getconf PAGESIZE` is 4096 on x86_64, but **arm64 varies
by kernel/distro build**: 4096, 16384, and 65536 all ship in the wild (RHEL
on aarch64 uses 64K pages). Never assume; always run `getconf PAGESIZE` on
the box in question before multiplying:

```
rss=2048                          # field 24, as read from /proc/PID/stat
page_size=4096                    # getconf PAGESIZE
bytes = 2048 * 4096 = 8388608     # = 8192 KiB = 8 MiB
```

Read `rss` as a raw integer and report it as bytes without multiplying and
you'll be off by three orders of magnitude — always cross-check against
`VmRSS` in `/proc/PID/status`, which is already reported in kB.

The tool that formats this:
`ps -o pid,comm,stat,ppid,min_flt,maj_flt,cputime,nlwp,vsz,rss`
covers fields 1-4/10/12/20/23/24 plus cumulative CPU time. `ps` has no
per-field utime/stime split (`utime` isn't a valid `-o` specifier at all,
and `stime` means process START time, not kernel-mode CPU) — for the raw
per-mode tick counts in fields 14/15, read `/proc/PID/stat` directly.

## /proc/PID/status

Same data as `stat`, but line-per-field, human-labeled, and easier to `grep`
or read by hand. This is the file to reach for interactively.

| Field | Meaning | Why an operator cares |
|---|---|---|
| State | R/S/D/Z single char | Same states as stat field 3, spelled out |
| Tgid | Thread group ID = PID of group leader | What ps/top call "PID" |
| PPid | Parent PID | Same as stat field 4, labeled |
| Threads | Thread count | Same as stat field 20, labeled |
| VmRSS | Resident set size, already in kB | Cross-check vs stat field 24 x page size |
| RssAnon | Anonymous (heap/stack) mem, kB | Process-owned, not file-backed |
| RssFile | File-backed resident memory, kB | Mapped libs/files, often reclaimable |
| SigQ | Queued/max real-time signals for this user | Full queue drops signals silently |
| SigPnd | Pending-signal mask, hex bitmask | Delivered, not yet handled by this thread |
| SigBlk | Blocked-signal mask, hex bitmask | Signals explicitly masked off |
| SigIgn | Ignored-signal mask, hex bitmask | Set to SIG_IGN, a silent no-op always |
| SigCgt | Caught-signal mask, hex bitmask | Has a handler — decode to debug delivery |
| CapEff | Effective capabilities, hex bitmask | What the process can do right now |

**Worked example — decoding `SigCgt`:** each bit position `N-1` (0-indexed)
in the mask corresponds to signal number `N`. Given:

```
SigCgt: 0000000000004003
```

Convert hex to binary and read off the set bits:

```
0x4003 = 0100 0000 0000 0011 (binary)
        bit 0 set  -> signal 1  (SIGHUP)
        bit 1 set  -> signal 2  (SIGINT)
        bit 14 set -> signal 15 (SIGTERM)
```

So this process has installed handlers for `SIGHUP`, `SIGINT`, and
`SIGTERM` — it will **not** die from a plain `kill <pid>` (which sends
`SIGTERM`), because its handler runs instead of the default terminate
action. If the handler doesn't call `exit()`, the process survives and you
need `kill -9` (`SIGKILL`, bit 8, which is never maskable and never appears
in `SigCgt`) to remove it. This is exactly the shape of a "SIGTERM did
nothing" incident: check `SigCgt` before reaching for `-9`.

The tool that formats this:
`ps -o pid,caught,ignored,blocked,pending`
(canonical names `sigcatch`/`sigignore`/`sigmask`/`sig`) prints these same
four hex masks. Decoding the raw mask by hand is still the skill worth
having — `ps` hands you the same hex `SigCgt` value, not a decoded signal
list, so the bit-to-signal conversion above is still yours to do.

## /proc/meminfo

System-wide, not per-process. All values in kB unless noted.

| Field | Meaning | Why an operator cares |
|---|---|---|
| MemTotal | Total installed RAM | Static ceiling for everything below |
| MemFree | Completely unused RAM | Not "usable memory" — see box below |
| MemAvailable | Estimated RAM available w/o swapping | This is "usable memory" |
| Buffers | Raw block-device I/O caching | Small, rarely worth chasing |
| Cached | Page cache for file contents | Reclaimable; full cache is healthy |
| Dirty | Page cache not yet flushed to disk | Rising = writeback falling behind |
| SwapTotal / SwapFree | Configured swap, unused swap | Total minus Free = swap in use |

> **`MemFree` is not "memory you can use." `MemAvailable` is.** The kernel
> keeps free RAM low on purpose — unused pages hold cached files and
> reclaimable buffers. `MemAvailable` already accounts for what can be
> reclaimed without swapping; `MemFree` does not. Alerting on low
> `MemFree` alone produces false positives on every healthy box.

The tool that formats this: `free -h` (or `free -h -w` for the wide form
that splits `Buffers`/`Cache`).

## /proc/loadavg

```
0.52 0.61 0.58 2/458 23107
```

| Field # | Name | Meaning | Why an operator cares |
|---|---|---|---|
| 1 | load1 | 1-minute decayed average | Most reactive, noisiest |
| 2 | load5 | 5-minute decayed average | The usual "is this box busy" number |
| 3 | load15 | 15-minute decayed average | Trend over the last quarter hour |
| 4 | runnable/total | Runnable / total tasks, live count | Not an average |
| 5 | last_pid | Most recently created PID | Cheap fork-bomb detector |

**The sentence that matters most:** the first three fields count tasks in
state `R` (runnable) **plus** state `D` (uninterruptible sleep, usually
waiting on disk or network I/O) — not just CPU-runnable tasks. This is why
a box can show `load average: 24.00` while `%CPU` sits near zero: the load
is coming from processes blocked on I/O, not from CPU contention. Always
correlate `loadavg` against `%CPU` in `top` and the per-process `state`
field (`D` in `stat`/`status`) before assuming CPU pressure.

The tool that formats this: `uptime` (or `w`, which adds per-user context).

## /proc/net/tcp

One line per TCP socket. This is the slow, text-based interface — the
kernel also exposes the same sockets over netlink `SOCK_DIAG`, which is
what modern `ss` uses (see below) and is much faster on a box with tens of
thousands of connections. This file's only advantage is that `cat` can
read it with no tooling at all. Addresses are hex, and the byte order
trips everyone up once.

Whitespace-separated and positional; field numbers below are 1-indexed,
counting the leading `sl` (`N:`) entry as field 1:

| Field # | Field | Meaning | Why an operator cares |
|---|---|---|---|
| 2 | local_address | IP:port, both hex | Listening/local side of the connection |
| 3 | rem_address | IP:port, both hex | Peer; 00000000:0000 on a listening socket |
| 4 | st | Connection state, hex byte | See the state table below |
| 10 | inode | Socket inode number | Joins to an fd in /proc/PID/fd/* — see below |

**Worked example — decoding `0100007F:1F90`:**

The IP is 4 bytes written **little-endian** (least-significant byte first);
the port is 2 bytes written **big-endian** (network byte order, no reversal
needed). Split and reverse the IP bytes only:

```
0100007F:1F90
   |        |
   |        +-- port, big-endian: 0x1F90 = 1*4096 + 15*256 + 9*16 + 0
   |                              = 4096 + 3840 + 144 = 8080
   |
   +-- IP, little-endian bytes as written: 01 00 00 7F
       reverse byte order to read the address: 7F 00 00 01
       7F=127  00=0  00=0  01=1  ->  127.0.0.1
```

Result: `0100007F:1F90` → `127.0.0.1:8080`. The port needs no byte-swap;
only the address does — mixing that up is the most common mistake reading
this file by hand.

`st` state codes (hex):

| st | State |
|---|---|
| 01 | ESTABLISHED |
| 02 | SYN_SENT |
| 03 | SYN_RECV |
| 04 | FIN_WAIT1 |
| 05 | FIN_WAIT2 |
| 06 | TIME_WAIT |
| 07 | CLOSE |
| 08 | CLOSE_WAIT |
| 09 | LAST_ACK |
| 0A | LISTEN |

`inode` joins to `/proc/PID/fd/*`: for each PID, `readlink` every fd; a
socket fd resolves to `socket:[<inode>]`. Match that inode number against
this table's `inode` column to find which process owns a given connection
— the manual equivalent of the inode-to-process join that `ss -p` and
`lsof -i` automate for you.

The tool that formats this: `netstat -tn`, which parses exactly these lines.
Modern `ss -tn` answers the same question over netlink (SOCK_DIAG) instead,
because parsing text out of /proc did not scale to hosts with hundreds of
thousands of sockets - which is why `ss` is faster, why its output can differ
in detail from this file, and why this file remains the fallback when
neither tool is installed.

## /sys/fs/cgroup (v2)

Unified hierarchy; one file per metric, directly in the cgroup's directory.
For the `memory.*` files, no units suffix means bytes and `max` means
unlimited; `cpu.max`/`cpu.stat` are microseconds and `pids.current` is a
plain count — check each row below, don't assume bytes file-wide.

| File | Meaning | Why an operator cares |
|---|---|---|
| memory.current | Current memory usage, bytes | What systemd-cgtop shows live |
| memory.max | Hard memory limit, bytes or max | Reclaim first; OOM if reclaim fails |
| memory.events | low/high/max/oom/oom_kill counters | oom_kill>0 = already lost a proc |
| cpu.max | QUOTA PERIOD in usec, or max PERIOD | 50000 100000 = 0.5 CPU; throttle risk |
| cpu.stat | usage_usec, nr_throttled, throttled_usec | nr_throttled>0 hurts latency |
| pids.current | Current process/thread count | Compare vs pids.max, catch fork bombs |
| cgroup.procs | PIDs currently in this cgroup | Membership list, joins /proc/PID |

Hitting `memory.max` is not an instant kill: the kernel reclaims
(evicting page cache, reclaiming what it can) first, and usage can sit
right at the ceiling under reclaim pressure without anything dying. The
cgroup OOM killer only fires once reclaim can't free enough to satisfy an
allocation. `memory.events`' `oom_kill` field is the one to alert on: a
nonzero value means reclaim already failed and the kernel killed a process
in this cgroup, independent of whether the *host* is under memory
pressure — this is how a container dies with plenty of free RAM on the
node.

The tool that formats this: `systemd-cgtop`, which reads these cgroupfs
files directly on the host. `docker stats` shows the same numbers for a
container but does not read this path itself - it queries the Docker
daemon's API, and the daemon is what reads these files on the host and
maps them back to the container's cgroup.

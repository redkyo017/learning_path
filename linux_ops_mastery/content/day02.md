# Day 2 — The process table and the syscall boundary

**Truth of the day:** process table
**Budget:** 3 h — 45m read the file, 30m derive the tool, 1h core concepts,
45m lab, 20m strip the toolbox

## Why this matters

Every process on the box is a row the kernel keeps in `/proc`, and every
signal you send is a message the kernel delivers to that row, not a
guarantee the target acts on it. Operators who never read the row past
`ps`'s summary get surprised, over and over, by processes that "won't
die" — and the surprise always resolves to one of four kernel-documented
states. This day builds the model that removes the surprise: what a
signal actually is, what a process state actually means, and why the one
process most operators never look at — PID 1 — has rules no other
process follows.

## Read the file first

`/proc/PID/stat` is one line, space-separated, and only field 2 (`comm`)
can itself contain spaces or parens — see
`primers/proc-field-reference.md#/proc/PID/stat` for the full field
table and the right-of-the-last-`)` parsing rule. Today's fields:

- **1 pid, 2 comm, 3 state, 4 ppid** — identity, name, one-character
  state, and the parent to walk the tree without `pstree`.
- **14 utime, 15 stime** — ticks in user mode and kernel mode; divide by
  `sysconf(_SC_CLK_TCK)` (usually 100) for seconds.
- **20 num_threads** — live thread count; a runaway `fork`/thread loop
  shows here before it shows anywhere else.
- **24 rss** — resident pages, not bytes; see the primer's field-24 trap
  before multiplying by anything.

`/proc/PID/status` restates the same data, one label per line, plus what
`stat` does not carry: **State** (spelled out, `R (running)` etc.),
**PPid**, **Threads**, and four signal bitmasks — `SigPnd`, `SigBlk`,
`SigIgn`, `SigCgt`. See
`primers/proc-field-reference.md#/proc/PID/status` for the full table
and the worked `SigCgt` decode; this day reuses that exact procedure
against `SigIgn`, not `SigCgt`, for reasons the lab makes concrete.

Three more files, all symlinks, all worth reading directly rather than
trusting a summary:

- `/proc/PID/cmdline` — the exact argv the process was started with,
  **NUL-separated**, not space-separated: `cat cmdline | tr '\0' ' '` to
  read it, or the NULs render as nothing and two arguments look like one.
- `/proc/PID/exe` — a symlink to the running binary on disk (`(deleted)`
  suffix if the file was removed after the process started it).
- `/proc/PID/cwd` — a symlink to the process's current working directory.
- `/proc/PID/environ` — NUL-separated `KEY=VALUE` pairs, same `tr` trick;
  readable only by the owning uid or root, because it can hold secrets.

## Derive the tool

`ps -eo pid,ppid,state,comm` is four columns, and each one is a field you
just read by hand: `pid` is `stat` field 1, `ppid` is field 4, `state` is
field 3, `comm` is field 2. `ps` is not a separate source of truth — it
opens the same `/proc/PID/stat` (and `status`) for every PID and prints
selected fields with a header. Nothing in its output exists that isn't
in the file.

`pstree -p` renders exactly the `ppid` field as a tree instead of a flat
table — walk `/proc/*/stat` yourself, build a pid-to-ppid map, and you
have reimplemented `pstree` with a shell loop and no library.

## Core concepts

**fork, exec, and the gap between them.** `fork()` duplicates the
calling process — same code, same open descriptors, same signal
dispositions, a new PID — copy-on-write, not a real memory copy.
`exec()` replaces the process image in place: same PID, new code, new
memory map, argv and envp reset. They are separate syscalls on purpose:
the gap between `fork` and `exec` is where a shell sets up redirection —
`dup2` a file onto descriptor 1 in the child, then `exec` the target —
without ever touching the parent's descriptors. Collapse the two into
one syscall and redirection has nowhere to happen.

**What survives `exec`.** Open descriptors survive (unless marked
`FD_CLOEXEC`), the working directory survives, the uid/gid survive. Of
the three signal dispositions, two survive and one does not: a signal
set to **ignore** (`SIG_IGN`) stays ignored, a signal left at **default**
stays default, but a signal with a **caught handler** is reset to
default — the old handler's code address means nothing in the new image.
This is why a shell can `trap "" TERM` (ignore, not catch) and then
`exec` a plain binary like `sleep`, and the resulting process — which
never wrote one line of signal-handling code — silently ignores
`SIGTERM` for the rest of its life. The disposition rode across the
`exec`; the binary never asked for it.

**wait, the reaping contract, and PID 1.** A process that calls `exit()`
does not vanish: the kernel keeps its exit status in the process table
until the parent calls `wait()`/`waitpid()` to collect it. Until then it
is a **zombie** — dead, but still a row. If a parent dies before
collecting a child, the kernel reparents the orphan, walking up for the
nearest ancestor that registered itself as a "child subreaper"
(`prctl(PR_SET_CHILD_SUBREAPER)`); finding none, the orphan lands on
PID 1 of its PID namespace — the namespace's `init`, whether or not that
process is a real init system. A plain shell running as PID 1 accepts
these orphans without ever asking to, and if it only ever calls
`waitpid()` for the one child it explicitly launched, an adopted orphan
that later dies sits as a zombie the shell never collects. That is the
reaping contract failing silently, and it is a second, independent way
the "won't die" family shows up.

PID 1 carries one more rule most operators never learn: the kernel does
not deliver a signal whose default action would terminate or stop the
process to PID 1 of a PID namespace **unless that process has explicitly
installed a handler for that exact signal**. Even `SIGKILL` and `SIGSTOP`
are not exceptions from inside that same namespace — per
`man 7 pid_namespaces`, they only force PID 1 to terminate when sent
from an **ancestor** namespace (the host, or `docker kill`, both of
which act from outside the container); `kill -9 1` typed inside the
container's own shell does nothing at all. A shell running as PID 1
with no `SIGTERM` handler does not merely "fail to forward" `SIGTERM`
to its child; the kernel discards the signal at PID 1 itself before the
shell's own logic ever runs.

**Proving the ENTRYPOINT trap on `app` itself, and the two ways to kill
something in it.** `docker stop app` only ever signals PID 1 — the
`sh`, never python — so the only way to reach python directly is to
send the signal to it by name, from inside the container:

```
docker compose -p linuxops exec app sh -c 'kill -TERM $(pgrep -f "/srv/app[.]py")'
```

The bracket around the dot is not decoration: without it, the pattern
`/srv/app.py` also matches the `pgrep` command's own `/proc/PID/cmdline`
(it literally contains that text), so `pgrep` would find itself
alongside python. `[.]` makes the dot match only a literal `.`, and the
wrapper's own cmdline contains the literal bracket characters, not a
match for the pattern — the same bracketing trick this lab's own
`break.sh`/`verify.sh` use throughout.

This is the distinction that matters every time you kill something in
this container: a signal to a **child process** (a stray `sleep`, say)
leaves PID 1 untouched and the container keeps running; a signal that
reaches **python itself** removes the one process `sh -c "python
/srv/app.py; exit $?"` was waiting on, so `sh`'s wait returns, `sh` runs
`exit $?`, and PID 1 exits — taking the whole container down with it.
`app` carries `restart: unless-stopped`, so Docker restarts it within
about a second: with the default `IGNORE_SIGTERM=0`, python logs `got
SIGTERM, shutting down`, calls `os._exit(0)`, and the command above
ends with your `exec` session dropping and a fresh process table —
new PID 1, new everything — on reconnect. That is the restart policy
doing its job, not a bug, and it is the same mechanism Day 4 relies on
to bring `app` back after an OOM kill.

Set `IGNORE_SIGTERM=1` in `docker-compose.yml` and recreate `app` (this
exploration is outside the graded incident below, so the lab's "don't
restart `app`" rule does not apply to it) and repeat the same command:
python logs `ignoring SIGTERM` and keeps serving — nothing exits,
nothing restarts. One signal, two outcomes, decided entirely by a flag
the application checks once it actually receives the signal — and this
is the *only* place in the whole fleet where `IGNORE_SIGTERM` has any
observable effect. `docker stop app` never exercises it either way,
because `docker stop` signals PID 1, and PID 1 has no `SIGTERM` handler
and forwards nothing, regardless of what `IGNORE_SIGTERM` says.

**Process states and load average.** `R` runnable, `S` interruptible
sleep, `D` uninterruptible sleep, `Z` zombie, `T` stopped. Only `R` and
`D` count toward `/proc/loadavg` (see
`primers/proc-field-reference.md#/proc/loadavg`) — a box can show a high
load average with an idle CPU if enough processes sit in `D`, waiting on
disk or network I/O rather than running. `Z` and `T` consume no CPU and
add nothing to load average; they are invisible to that number and only
visible in the process table itself.

**The "won't die" family, all four members.** A process ignoring
`SIGTERM` (disposition problem, `SIG_IGN` or a handler that never exits).
A `T`-stopped process (scheduling problem — see below). Zombie
accumulation under a negligent reaper (contract problem, above).
And the fourth, **not reproduced in this lab**: D state (`D` in `stat`
field 3), uninterruptible sleep inside a kernel driver waiting on a device or a
network filesystem — an unresponsive NFS server, a failing EBS volume,
a device timeout. No signal, not even `SIGKILL`, can reach a process
mid-syscall in `D` state, because the kernel only checks for pending
signals at specific safe points, and a driver stuck waiting on hardware
never reaches one. The process is not ignoring `SIGKILL`; the kernel has
not yet had a chance to deliver it. `D` state cannot be induced reliably
or safely inside Docker Desktop on macOS, which is why this lab
reproduces only the three members above — but the fourth is real, and
"the box has processes stuck in `D`" is a real EBS-and-NFS incident, not
a theoretical one.

**Signals an operator must know cold.** `TERM` (15, ask nicely, default
terminate, catchable), `INT` (2, Ctrl-C, default terminate, catchable),
`HUP` (1, hangup — historically terminal-disconnect, now "reload
config" by convention, catchable), `QUIT` (3, terminate plus core dump,
catchable), `KILL` (9, terminate, **cannot** be caught, blocked, or
ignored), `STOP` (19 on Linux, suspend, **cannot** be caught, blocked, or
ignored), `CONT` (18, resume a stopped process, catchable), `CHLD` (17,
sent to a parent when a child stops or terminates, default ignore,
catchable — this is the signal a real reaper listens for). `KILL` and
`STOP` are the two an operator can always rely on, because the kernel
refuses to let a process override either one.

**Stopped means not scheduled.** `SIGSTOP`/`SIGTSTP` move a process to
`T` state, and `T` means the kernel will not schedule it — no code runs,
and no pending signal is acted on, until `SIGCONT` reschedules it.
`SIGKILL` is the sole, deliberate exception: the kernel force-wakes a
stopped task specifically for `SIGKILL`, so `kill -9` on a `T`-stopped
process removes it immediately with no `SIGCONT` required. Every other
signal does not get this treatment — including a plain `SIGTERM` at its
ordinary default (terminate) disposition — it simply joins `SigPnd` in
`/proc/PID/status` and sits there, un-acted-upon, however "fatal" its
disposition would otherwise be, until `SIGCONT` lets the process run
again. The safe operational habit is `SIGCONT` first, always, for
anything other than `SIGKILL` — you rarely know in advance which
disposition the target has installed, and only `SIGKILL` skips the
question entirely.

**Process groups, sessions, controlling terminals.** A session groups
one or more process groups and, usually, one controlling terminal; a
process group is the unit a shell sends `^C`/`^Z` to as a whole.
`nohup` makes a specific signal (`SIGHUP`) ignored and redirects output,
but the process stays in the same session. `setsid` goes further: it
starts the process as the leader of a brand-new session with **no**
controlling terminal at all, which is why every process this lab starts
in the background is wrapped in `setsid` — without it, the process would
still belong to the `docker exec` session that launches it, and would be
signaled (or hung up) when that session ends.

**`strace -f -p PID`.** Attaches to a running process (and, with `-f`,
every thread and child it forks) and prints each syscall as it happens:
name, arguments, and return value — or, if the syscall has not returned
yet, the call with no closing `)` and no `= result`, which is exactly
how you read a syscall that is currently blocking. `ws` is the only
container in this fleet where `strace` works at all — it carries
`cap_add: SYS_PTRACE`, without which `strace` fails at attach with
`ptrace(PTRACE_SEIZE): Operation not permitted`, a kernel refusal, not a
missing package.

## Lab

See `labs/day02/`. Three processes on `app` will not exit: one traps and
ignores `SIGTERM`, one is stopped and leaves `SIGTERM` pending until
`SIGCONT`, and one keeps multiplying because its spawner forks
constantly and never reaps. Goal: name each of the three causes, in the
journal, before touching anything, then repair `app` back to a clean
process table **without restarting it**. Success signal:
`labs/day02/verify.sh` exits 0. Run `break.sh`, write the chain in
`journal.md` before fixing anything. None of the three fixes here ever
touch python or PID 1 — two target `sleep` PIDs, one targets a
`python3` spawner process that is not `app`'s own service — which is
exactly why the container never restarts mid-lab. Apply the
child-versus-service distinction from Core concepts and be sure of
which process a given `pgrep`/`kill` actually lands on before you run
it.

## Strip the toolbox

`slim` runs busybox: its `ps` takes no `-o`/`-eo` field selection at
all (the columns `ps -eo pid,ppid,state,comm` gave us above are simply
unavailable as flags), there is no `pstree`, and its `pgrep` has
neither `-c` nor `-n` — but every field above is still sitting in
`/proc`, plain text, readable with nothing but a shell:

```sh
for p in /proc/[0-9]*; do
  [ -r "$p/stat" ] || continue
  read -r pid comm state _ < "$p/stat"
  echo "$pid $state $comm"
done
```

This reads `stat` fields 1–3 directly with the shell's own `read`
builtin — no external tool at all. It assumes `comm` has no embedded
space, true for every process name in this fleet; a `comm` with a space
needs the right-of-the-last-`)` parse from the primer instead.

Finding every process in one specific state — `T`, here — without
`ps -eo state` and without `pgrep`'s missing `-c`/`-n`, reading
`status` directly instead:

```sh
for p in /proc/[0-9]*/status; do
  grep -q "^State:.T" "$p" 2>/dev/null && echo "${p%/status} is stopped"
done
```

## Exercises

1. Given `SigCgt: 0000000000014003` from a process's `/proc/PID/status`,
   decode which signals it has installed handlers for. — **Hint:**
   convert to binary and read bit `N-1` as signal `N`, exactly as
   `primers/proc-field-reference.md#/proc/PID/status` works through
   `0x4003`. — **Solution sketch:** `0x14003` sets bits 0, 1, 14, and
   16 → signals 1, 2, 15, 17 → `SIGHUP`, `SIGINT`, `SIGTERM`, `SIGCHLD`
   — a well-behaved daemon that reloads on `HUP`, exits cleanly on `INT`
   and `TERM`, and reaps children on `CHLD`.
2. A process survives a plain `kill <pid>` (`SIGTERM`). Using only
   `/proc/PID/status`, explain why. — **Hint:** check `SigIgn` as well
   as `SigCgt` — they are different dispositions, and only one of them
   is what `trap "" SIGNAL` in a shell actually sets. —
   **Solution sketch:** if bit 14 is set in `SigIgn`, the signal is
   explicitly ignored (`SIG_IGN`), not caught by a handler; `SIG_IGN`
   survives `exec`, so a shell that ignores `TERM` and then `exec`s a
   plain binary hands it that immunity even though the binary itself
   never touches signal handling.
3. Produce a zombie deliberately, then reap it. — **Hint:** background a
   child, `kill` it, and delay the parent's `wait` long enough to
   observe `Z` in `ps`/`/proc`. — **Solution sketch:**
   `sleep 100 & child=$!; kill "$child"; sleep 1; ps -o pid,stat -p
   "$child"` shows `Z`; running `wait "$child"` afterward collects the
   exit status and the row disappears — proving reaping is an explicit
   act, not a timeout.
4. `kill -9` is sent to a `T`-stopped process. Explain precisely whether
   it takes effect immediately or waits for `SIGCONT`, and why the
   common belief about this case is often wrong. — **Hint:** the
   exception that lets a signal reach a stopped task is specific to
   `SIGKILL` itself, not to any signal whose disposition happens to be
   "terminate" — a plain `SIGTERM` at its default disposition is not
   covered by it. — **Solution sketch:** `SIGKILL` alone force-wakes a
   stopped task; every other signal, even one whose default disposition
   is also "terminate" (a plain `SIGTERM`), stays pending in `SigPnd`
   until `SIGCONT` runs the process again. So `kill -9` on a `T`-stopped
   process removes it immediately with no `SIGCONT` needed — the common
   "you must `CONT` before `KILL`" belief is a myth, usually born from
   confusing `T` (stopped, `KILL` works fine) with `D` (uninterruptible
   sleep, where `KILL` genuinely cannot act until the blocking syscall
   returns).
5. Given this `strace -f -p` output, name the syscall that is currently
   blocking:
   ```
   strace: Process 5190 attached
   read(3, "GET / HTTP/1.1\r\n", 4096) = 16
   futex(0x55b1a2c3e9d0, FUTEX_WAIT_PRIVATE, 0, NULL
   ```
   — **Hint:** the completed calls have a closing `)` and a `= result`;
   the blocking one does not. — **Solution sketch:** `futex(...)` is the
   last line and has neither — the process is parked in the kernel
   inside that `futex` wait, most likely a lock or condition variable
   another thread hasn't released yet.
6. What changes about PID 1's obligations once a process runs inside a
   container? — **Hint:** think about both signal delivery and
   reaping, not just one of them. — **Solution sketch:** PID 1 of a PID
   namespace is immune to any signal whose default action would
   terminate or stop it unless it explicitly installs a handler for
   that exact signal — even `SIGKILL`/`SIGSTOP` only force it to
   terminate when sent from an ancestor namespace (the host, or
   `docker kill`), never from a `kill -9 1` run inside the container's
   own shell; and PID 1 inherits every orphan in the namespace with no
   ancestor above it to fall back on, so it must actively reap
   (`wait(-1, ...)` in a loop, or delegate via
   `PR_SET_CHILD_SUBREAPER`) or every unreaped grandchild becomes a
   permanent zombie for the container's whole life.

## Anti-patterns / Common mistakes

- Memorising `kill -9`, `kill -HUP`, `kill -1` as flags to try in order,
  rather than the signal model — the default disposition, what a
  handler can override, and the two signals nothing can override
  (Mistake 1, STRATEGY.md). A flag mnemonic never explains why one
  process dies to `TERM` and its neighbor does not.
- Never having run `strace` against a live process, which leaves the
  syscall boundary a diagram you've read instead of a thing you've
  watched happen (Mistake 5, STRATEGY.md). Reading exercise 5's sample
  output is not the same skill as attaching `strace -f -p` to a real
  process in `ws` and finding the blocking call yourself.

## Where this shows up in AWS

An ECS task built from a Dockerfile with a shell-form `ENTRYPOINT` —
`ENTRYPOINT sh -c "start.sh"` or the equivalent — puts `/bin/sh` at
PID 1 inside the task's container, exactly like `app` in this fleet.
When ECS stops the task, it sends `SIGTERM` to PID 1 and starts the
`stopTimeout` clock. PID 1 is a non-interactive shell with no `SIGTERM`
handler of its own, so — per the PID 1 signal rule above — the kernel
does not even deliver the signal in a way the shell's default action
would act on; the real application process, one level down in the
process tree, never sees `SIGTERM` at all. It keeps serving requests
mid-drain until `stopTimeout` expires and ECS escalates to `SIGKILL`,
which every process must obey. The task's connections are cut cold
instead of drained, and every deploy silently eats the full
`stopTimeout` for no operational reason.

Two fixes, both named directly at the Dockerfile: switch to **exec-form
`ENTRYPOINT`** (`ENTRYPOINT ["python", "app.py"]`, no shell in between,
so the application itself is PID 1 and receives `SIGTERM` directly), or
keep the shell-form image but run it under a tiny init —
`initProcessEnabled: true` in the ECS task definition, or bundle `tini`
as the true PID 1 — either way giving PID 1 correct reaping and signal
semantics without touching the application at all.

## Teardown

See `labs/day02/teardown.md`.

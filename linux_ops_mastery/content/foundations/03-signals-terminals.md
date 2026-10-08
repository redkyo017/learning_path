# Foundations 03 — Signals and terminals

**Prepares you for:** Days 2 and 9.
**Time:** about 45 minutes, including the try-it steps.

Chapter 02 left "signal" and "handler" for this chapter. By the end
you should be able to say what happens between pressing Ctrl-C and a
program dying, why `kill` sometimes appears to do nothing, and which
processes a terminal talks to. Day 2 uses this for the "won't die"
family; Day 9 uses it for traps.

## What you'll be able to explain

- A signal is a small numbered notification the kernel delivers to a
  process. For each signal a process has a disposition: take the
  default action, ignore it, or catch it with its own handler.
- Blocking a signal is different from ignoring it: a blocked signal
  waits as pending; an ignored one is thrown away.
- `SIGKILL` and `SIGSTOP` cannot be caught, blocked, or ignored. `SIGTERM`
  can, which is why `kill` on its own sometimes "doesn't work".
- A stopped process (`T`) is not dead, and a process in `D` does not act
  on `SIGKILL` until its uninterruptible wait ends.
- The terminal driver sends Ctrl-C's `SIGINT` to the whole foreground
  process group of the terminal's session.
- The shell's `trap` catches signals for a script, and
  `/proc/PID/status` shows signal masks as hex.

## The mental model

### What a signal is

A **signal** is a small numbered notification that the kernel delivers
to a process. It carries no data beyond its number. Something asks for
it: a user pressing a key, another process calling `kill`, or the kernel
itself (a child exited, a program touched memory it should not). The
kernel records it against the target process and, when that process is
next about to run, acts on it.

Signals have names starting with `SIG` and numbers. These are the ones
an operator needs, numbered as on Linux x86_64 and arm64 (other CPU
types number some differently):

| Signal | No. | Default action | Typical source or meaning |
|---|---|---|---|
| `SIGHUP` | 1 | terminate | terminal went away; by convention "reload config" |
| `SIGINT` | 2 | terminate | Ctrl-C |
| `SIGQUIT` | 3 | terminate and dump core (save a memory image to a file) | Ctrl-backslash |
| `SIGKILL` | 9 | terminate | `kill -9`; cannot be caught, blocked, ignored |
| `SIGTERM` | 15 | terminate | plain `kill PID`; "please shut down" |
| `SIGCHLD` | 17 | ignore | sent to a parent when a child stops or exits |
| `SIGCONT` | 18 | resume if stopped | `kill -CONT`; `fg`, `bg` |
| `SIGSTOP` | 19 | stop | cannot be caught, blocked, ignored |
| `SIGTSTP` | 20 | stop | Ctrl-Z; the catchable cousin of `SIGSTOP` |

`kill -l` prints the full list. The `kill` command sends *any* signal,
and most signals are not fatal by default.

### Three dispositions: default, ignore, catch

For every signal, each process has a **disposition**: what to do when
that signal arrives. There are three.

- **Default action.** The kernel does what the table above says:
  terminate, stop, resume, or ignore. A program that never wrote any
  signal code is in this state for every signal.
- **Ignore.** The process tells the kernel "drop this signal". It
  arrives and nothing happens.
- **Catch.** The process registers a **handler**: a function of its own.
  When the signal arrives the kernel interrupts the program, runs the
  handler, and then lets the program carry on. This is how a server
  closes its connections cleanly on `SIGTERM`, or reloads its config on
  `SIGHUP`. Catching is also called *handling* a signal.

Day 2 goes further on what survives `exec`: ignored stays ignored
and default stays default, but a caught handler is reset to default,
because the old handler's code is gone.

### Block versus ignore, and pending

There is a fourth thing a process can do, and it is easy to confuse with
ignoring. A process can **block** a signal, also called putting it in
its **signal mask**. A blocked signal is not delivered. It is held as
**pending** until the process unblocks it. Then the normal rules apply.

An ignored signal is dropped at once and is gone for good. A blocked
one is kept and delivered later.

Programs block signals briefly around code that must not be interrupted
halfway. A process with pending signals is not "ignoring" you; it has
not been allowed to look yet. Day 2 shows this with a stopped process.

### What the kernel decides when a signal arrives

```
  signal N sent to process P
           |
           v
  is N SIGKILL or SIGSTOP? ---- yes ---> kernel acts (terminate/stop)
           |                             at its next safe point.
           no                            (No handler, mask or ignore
           |                              can intercept these two.)
           v
  is N blocked in P's mask?  ---- yes ---> keep as PENDING;
           |                               re-check when unblocked
           no
           v
  is N ignored by P?  ---------- yes ---> drop it
           |
           no
           v
  does P have a handler for N? -- yes ---> run the handler,
           |                               then resume the program
           no
           v
  do the DEFAULT action for N
  (terminate / dump core / stop / resume / ignore)
```

(Chapter 02's PID 1 rule changes the first and last boxes: for PID 1
of a PID namespace, a signal that would terminate or stop it is
discarded unless PID 1 has a handler for that exact signal. That
includes `SIGKILL` and `SIGSTOP` sent from inside the namespace; only
those sent from an ancestor namespace, such as the host, bypass it.
Chapter 06 explains namespaces.)

### Why `kill` sometimes "doesn't work"

`kill PID` sends `SIGTERM`, number 15. That is a request, not an
order: the process may catch it, ignore it, or block it. `SIGKILL` is
not a request: the kernel refuses to let any process catch, block, or
ignore `SIGKILL` or `SIGSTOP`, so these are the two an operator can
always rely on. Four situations make "it won't die" feel real; Day 2
calls them the "won't die" family:

1. **The process ignores or handles `SIGTERM`** and does not exit. Send
   `SIGKILL` if it will not shut down on request, at the cost of cleanup:
   no handler runs, buffers are not flushed, temporary files stay.
2. **The process is stopped (`T`).** A stopped process is not scheduled:
   no code runs, so nothing can act on a signal. A `SIGTERM` sent to it
   waits as pending until `SIGCONT` lets it run. `SIGKILL` is the one
   signal the kernel acts on even then, to remove it. For anything else,
   send `SIGCONT` first.
3. **The process is a zombie (`Z`).** It is already dead and has nothing
   left to signal (chapter 02). Only the parent's `wait` removes it.
4. **The process is in `D`.** It is not ignoring `SIGKILL`; the kernel
   has not had a chance to deliver it. A process in `D` does not act on
   `SIGKILL` until the uninterruptible wait ends, and if a disk or
   network filesystem never answers, that can be never (chapter 02).

### Terminals, sessions, and process groups

A **terminal** is where a person types: a window or an `ssh`
connection. The kernel presents one as a **tty** device (such as
`/dev/pts/0`), and a process has at most one **controlling terminal**.
The kernel's terminal driver sits between your keyboard and the
processes, and when it sees Ctrl-C or Ctrl-Z it turns them into
signals.

To know *who* gets that signal, Linux groups processes in two levels.

- A **process group** is a set of processes that are signalled
  together. Each group has a number, the **PGID**. A shell makes one
  group per job: a pipeline such as `a | b | c` (chapter 04 explains
  pipes) is one group of three processes.
- A **session** is a set of process groups, with a **session ID**
  (SID). A terminal window starts a session; its shell is the **session
  leader**, and the terminal is the session's controlling terminal.

At any moment exactly one process group in the session is the
**foreground** process group: the one allowed to read the keyboard and
the one that receives keyboard-generated signals. The others are
**background** groups (jobs started with `&`, or stopped ones).

```
 terminal /dev/pts/0   (controlling terminal)
      |
 session SID 400   (leader: the shell, PID 400)
      |
      +-- process group 400   shell itself            (idle)
      |
      +-- process group 612   BACKGROUND job:  sleep 300 &
      |       `-- sleep (612)
      |
      +-- process group 640   FOREGROUND job:  a | b | c
              |-- a (640)  <---- Ctrl-C: the terminal driver sends
              |-- b (641)  <---- SIGINT to EVERY process in the
              `-- c (642)  <---- foreground process group (640)

 The shell (400) and the background job (612) do not receive it.
```

**Ctrl-C sends `SIGINT` to the whole foreground process group**, not
just one process. All three of `a`, `b`, and `c` get it. Each then uses
its own disposition: by default it dies, but a program that caught
`SIGINT` can ignore the key press, and a shell script running in the
foreground may be one member of the group. Day 9 relies on this: Ctrl-C
reaches the script and its pipeline children together, and each one
reacts on its own.

The same driver does the others:

- **Ctrl-Z** sends `SIGTSTP` to the foreground group. The processes go
  to `T` and the shell regains the keyboard. `fg` sends `SIGCONT` and
  puts the group back in the foreground; `bg` sends `SIGCONT` and leaves
  it in the background. `SIGTSTP` can be caught; `SIGSTOP` cannot.
- **Closing the terminal** (closing the window, or an `ssh` drop)
  makes the kernel send `SIGHUP` to the session leader, which is the
  shell. An interactive shell then passes `SIGHUP` on to its jobs.

Two tools change these relationships, and Day 2 uses both. `nohup` makes
`SIGHUP` ignored (and sends output to a file; chapter 04 explains
redirection) but leaves the process in the same session. `setsid` starts
a process as leader of a brand-new session with **no** controlling
terminal, so no terminal event can reach it. Day 2 goes further on both.

### The shell and signals: `trap`

A shell is a process like any other and has dispositions too. An
interactive shell handles `SIGINT` itself (so Ctrl-C at the prompt
does not close it) and ignores `SIGTERM`, `SIGQUIT`, and `SIGTSTP`,
while the commands it starts get the defaults.

`trap` is the shell command that sets the shell's own handler for a
signal. The shell lets you write the handler as a command string:

```
trap 'echo bye' TERM       # catch SIGTERM: run this, don't die
trap '' INT                # ignore SIGINT
trap - INT                 # restore the default
trap 'cleanup' EXIT        # EXIT: runs when the shell exits
```

`trap -p` lists the traps now set. `EXIT` is a shell pseudo-signal that
fires when the shell leaves for any reason. A trap belongs to the shell
process that set it: a subshell (a child the shell forks for `( ... )`
or for each stage of a pipeline) does not run the parent's `EXIT` trap.
Day 9 shows a cleanup trap that runs but finds nothing to clean (the state
was set in a subshell) and a signal trap that forgets to `exit`.

### Reading signal masks in `/proc/PID/status`

Chapter 02 showed that `/proc/PID/status` is a generated text file. Five
of its lines are signal sets, each a **bitmask** written in hexadecimal
with 16 digits: a row of bits, one per signal, where a 1 means "this
signal is in the set". Signal number *n* is bit *n - 1*, counting from
the right, which is the lowest bit.

Pending signals show in `ShdPnd` (process-wide; `kill` lands here) or
`SigPnd` (per-thread). `SigBlk`: blocked, `SigIgn`: ignored, `SigCgt`:
caught. When a signal seems stuck, look at `ShdPnd` first (Day 2 does).

Worked decode of a made-up value, `SigCgt: 0000000000010002`:

```
 hex digits, right to left:  2  0  0  0  1  0 ...
 each hex digit = 4 bits:   bits 0-3, 4-7, 8-11, 12-15, 16-19, ...

 digit "2" (lowest)   = binary 0010  -> bit 1  is set -> signal 1+1  =  2 (SIGINT)
 digit "1" (5th from right) = 0001   -> bit 16 is set -> signal 16+1 = 17 (SIGCHLD)

 so this process has handlers for SIGINT and SIGCHLD.
```

The trick is the off-by-one: bit 0 is signal 1. The lowest hex digit
holds signals 1-4 (its values 1, 2, 4, 8 are `SIGHUP`, `SIGINT`,
`SIGQUIT`, and signal 4). The same method reads `SigIgn`; Day 2 reuses
it. A signal in `ShdPnd` is either blocked (also in `SigBlk`) and
waiting to be unblocked, or the process is stopped and waiting for
`SIGCONT`.

## How it connects

- **Chapter 02's states** meet signals here. `T` is what `SIGSTOP` or
  `SIGTSTP` produces; `D` is the state in which signals cannot be
  delivered yet; `Z` has nothing left to signal. `SIGCHLD` is how a
  parent is told a child exited, so it can `wait` and reap it.
- **Chapter 04** explains file descriptors, which wire pipelines
  together and connect a process to its tty.
- **Day 2** builds on this chapter: the signal table, the "won't die"
  family, stopped processes, and sessions. **Day 9** builds on the
  process-group idea and on `trap`.

## See it yourself

Use the `ws` container: from `labs/fleet`, run
`docker compose -p linuxops exec ws bash`. Every step only observes; no
signal is sent.

```bash
kill -l
```

**What to look for:** the numbered signal list. Find `HUP`, `INT`,
`QUIT`, `KILL`, `TERM`, `CHLD`, `CONT`, `STOP`, and `TSTP` and compare
each number with the table in this chapter.

```bash
grep -E 'Sig(Pnd|Blk|Ign|Cgt)|ShdPnd' /proc/$$/status
```

**What to look for:** five 16-digit hex values. `SigPnd` and `ShdPnd`
are most likely zeros. `SigBlk` may show one bit (bash blocks `SIGCHLD`
at moments). `SigIgn` and `SigCgt` are nonzero: the shell ignores some
signals, catches others. Decode a digit at a time.

```bash
cat /proc/1/status | grep Sig
```

**What to look for:** the `Sig...` lines for PID 1 of the container.
Compare its `SigCgt` with your shell's. If bit 14 (signal 15,
`SIGTERM`) is clear in `SigCgt`, PID 1 has no `SIGTERM` handler, the
situation behind chapter 02's `docker stop` story.

```bash
ps -o pid,pgid,sid,tty,stat,cmd
```

**What to look for:** your shell and `ps`. They share the same `SID`
(session) and `TTY`, but `ps` has its own `PGID`, usually its own PID:
the shell made a new process group for this job. A `+` in `STAT` means
"in the foreground process group".

```bash
sleep 5 | cat &
ps -o pid,pgid,sid,tty,stat,cmd
wait
```

**What to look for:** a background pipeline whose two processes
(`sleep`, `cat`) share one `PGID`. `STAT` has no `+`: the group is in
the background, so Ctrl-C would not reach it. `wait` ends it in 5 s.

```bash
trap -p; trap 'echo hi' USR1; trap -p
```

**What to look for:** the first `trap -p` prints nothing (or only
defaults); the second prints the handler you just set for `SIGUSR1`.
It lives only in this shell; exit the shell to discard it.

## Words you'll meet in the course

- **signal** — Day 2, *Signals an operator must know cold*
- **SIGKILL** — Day 2, *Stopped means not scheduled*
- **SIGSTOP** — Day 2, *Stopped means not scheduled*
- **SIGCHLD** (`CHLD`) — Day 2, *Signals an operator must know cold*
- **SIGTSTP** — Day 2, *Stopped means not scheduled*
- **process group** — Day 2, *Process groups, sessions, controlling terminals*
- **session** — Day 2, *Process groups, sessions, controlling terminals*
- **controlling terminal** — Day 2, *Process groups, sessions, controlling terminals*
- **SigCgt** — Day 2, *Read the file first*
- **trap** — Day 9, *Breaking it down* ([glossary](../GLOSSARY.md))
- **subshell** — Day 9, *The underlying truth* ([glossary](../GLOSSARY.md))

## Self-check

1. A program is writing a log file and ignores `kill PID`, but dies
   at once with `kill -9 PID`. Why did the first fail, and what did
   you give up by using the second?
2. `kill PID` does nothing to a process in state `T` that has no
   handler. Where is the signal, and what makes it act?
3. What is the difference between a signal that is blocked and one that
   is ignored? Which one shows up as pending?
4. You run `a | b | c` in the foreground and press Ctrl-C. Which
   processes receive `SIGINT`, who sends it, and why does your shell
   survive?
5. `SigCgt: 0000000000004002`. Which signals has this process handled?
6. A process stuck reading from a dead NFS server is in `D`. Why does
   `kill -9` not remove it, and what does that tell you about
   "SIGKILL always works"?

<details><summary>Answers</summary>

1. The first sent `SIGTERM`, which a process may catch or ignore, and
   this one did. `SIGKILL` cannot be caught, blocked, or ignored, so the
   kernel ended it. You gave up cleanup: no handler ran, so buffers were
   not flushed.
2. It is pending: a stopped process is not scheduled, so nothing runs to
   act on it. It is delivered after `SIGCONT` resumes the process.
   `SIGKILL` is the exception, as the kernel acts on it even for a
   stopped process.
3. A blocked signal is held as pending and is delivered when unblocked.
   An ignored signal is dropped and is gone. A blocked signal shows up in
   `ShdPnd` while it waits; an ignored one never does.
4. All three, because Ctrl-C goes to the foreground process group. The
   terminal driver sends it, not the shell. The shell is in a different
   process group, so it does not receive the signal.
5. `0x4002` is the digit `4` in the fourth position and `2` in the
   first. `2` is bit 1, so signal 2 (`SIGINT`). `4` in the fourth digit
   (bits 12-15) is bit 14, so signal 15 (`SIGTERM`). It handles `SIGINT`
   and `SIGTERM`.
6. The process is inside a kernel operation that must finish in one
   piece, and the kernel only delivers signals at safe points it never
   reaches while the server stays silent. It has not ignored `SIGKILL`;
   delivery waits until the wait ends. "Cannot be ignored" does not mean
   "acts immediately in any state". The fix is the storage, not the
   process.

</details>

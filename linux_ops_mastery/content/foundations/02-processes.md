# Foundations 02 — Processes

**Prepares you for:** Day 2.
**Time:** about 45 minutes, including the try-it steps.

By the end of this chapter you can read a process listing, say why a
dead process can still appear in it, and explain why a container's first
process is special: the ideas Day 2 starts from.

## What you'll be able to explain

- A program is a file on disk; a process is one running instance of it,
  with its own memory, registers, open files, and credentials.
- Every new process is made by `fork` (copy the caller) and usually
  followed by `exec` (replace the copy's program). The shell does this
  for every command you type.
- Processes form a tree. When a process exits it becomes a zombie until
  its parent collects its exit status with `wait`; orphans are adopted
  by PID 1.
- PID 1 has a job (reaping orphans) and a special rule: in a container
  it ignores `SIGTERM` unless it installed a handler for it (chapter 03
  explains signals).
- The five states you will see, `R S D T Z`, and why a process in `D`
  cannot be interrupted.
- What the kernel shows about a process in `/proc/PID/`.

## The mental model

### Program versus process

A **program** is a file on disk: instructions and data, doing nothing.
`/bin/ls` is a program. A **process** is a running instance of a
program. The kernel gives each process:

- its own **memory**: code, data, and a private view of addresses that
  other processes cannot touch;
- its own **registers**: the CPU's scratch values, saved and restored
  each time the kernel switches between processes;
- its own list of **open files** (chapter 04 explains this list);
- its **credentials**: which user and group it acts as (chapter 05
  explains them);
- a **working directory** and an **environment**, described below.

Run `ls` in two terminals and you have one program and two processes.
Each has a number, its **PID** (process ID), which the kernel assigns
when the process is created and which names it in every tool.

### How processes are born: fork, then exec

Chapter 00 listed `fork` and `exec` as two system calls. Here is what
each does.

**`fork`** makes a near-exact copy of the calling process. The copy
is the **child**; the caller is the **parent**. The child has a new PID
and a new **PPID** (parent PID) that holds the parent's PID. It runs
the same code from the same point, with the same open files and the same
working directory. The only difference the program sees is the return
value: the parent is told the child's PID, the child is told zero. The
kernel does not copy all the memory up front; it shares it and copies
pieces only when one side changes them, so `fork` is cheap.

**`exec`** replaces the program running inside the *same* process. The
PID stays the same, but the code and memory are thrown away and the new
program is loaded in their place. Nothing is created and nothing is
returned: if `exec` works, the old program is simply gone. Some things
carry across, because they belong to the process and not to the program:
the PID, the working directory, the credentials, and the open files
(unless a file was marked to close on `exec`; chapter 04 explains
descriptors). Day 2 goes further on exactly what survives.

Alone, `fork` only gives a second copy and `exec` destroys its caller.
Together they are how Linux starts everything:

```
 time ->

 shell (PID 400)  ----- fork() -------------------- wait() ----> prompt
                           \                           ^
                            \                          | exit status
                             v                         |
 child (PID 612)             [copy of the shell] -- exec("ls") -> [ls runs] -- exit
                                                     ^
                              gap: child can set up  |
                              things before exec     |
```

The shell reads `ls`, calls `fork`, and then the parent waits. The
child, still a copy of the shell, calls `exec` to become `ls`. When `ls`
finishes, it exits and the parent's wait returns.

Why two steps and not one "start this program" call? Because of the
gap between them. After `fork` and before `exec`, the child is still
running shell code, so it can change its own surroundings, such as
pointing its output at a file, and the change then carries over into the
new program. The parent is never touched. That is how `ls > out.txt`
works; chapter 04 explains redirection. Day 2 returns to this gap.

### The process tree

Because every process except the first was made by `fork` from another,
the processes form a tree. Your shell is a child of a terminal or login
process; the `ls` you run is a child of your shell. The **process
table** is the kernel's record of every process: its PID, its PPID, its
state, which program it runs, and (once it exits) its exit status.

The very first process the kernel starts is **PID 1**, called **init**.
Inside a namespace all processes descend from its PID 1, except ones
injected from outside (a `docker exec` shell shows PPID 0). On a
server PID 1 is systemd (chapter 05 explains it); in a container it is
just its start command (see below).

### Exit, zombie, wait, and reaping

When a process finishes it calls `exit`, giving a small number, its
**exit status**. By convention 0 means success and anything else means
failure; chapter 04 covers how shells use it. A finished process does
not vanish at once. The kernel frees its memory and closes its files,
but keeps one small row in the process table holding the PID and the
exit status, because the parent may want to ask how the child ended.

That left-over row is a **zombie**: dead, but still listed. The parent
removes it by calling `wait`, which returns the exit status and frees the
row. Collecting a dead child this way is called **reaping** it.

```
 parent                          child
   |                               |
   |--- fork() ------------------->| (running, state R/S)
   |                               |
   |  (parent keeps doing work)    |--- exit(0) ---> ZOMBIE (state Z)
   |                               |      memory freed, files closed;
   |                               |      only the table row remains
   |--- wait() ------------------->|
   |<-- exit status 0 -------------|      row freed: child is gone
   v
```

Three accuracy points matter in practice:

- A zombie holds no memory, only its process-table entry and exit
  status. A few cost almost nothing; the harm of many is that each keeps
  its PID, and PIDs are a limited pool (`pid_max`, or a container's
  `pids.max`).
- A zombie cannot be killed, only reaped. It is already dead, so there
  is nothing left to stop; sending it a signal (chapter 03 explains
  signals) changes nothing. Only the parent's `wait` removes the row.
- A zombie that stays means the parent is alive but never calls `wait`.
  Fix or end the parent (next section).

### Orphans and PID 1

What if the parent exits first? The child is now an **orphan**. The
kernel does not leave it parentless. It **re-parents** the orphan to a
new parent: the nearest ancestor that has registered itself as a "child
subreaper" (a process that asked to adopt orphans below it), or, if
there is none, PID 1.

So PID 1 has a duty no other process has: it will be handed orphans, and
it must call `wait` for them when they die, or they remain zombies
forever. A real init system does this. A program that was never written
to be PID 1 often does not, which is one cause of zombie piles in
containers.

When the zombie's parent itself exits, the zombie is re-parented to PID 1
too, and PID 1 reaps it. That is why ending a negligent parent cures a
zombie problem.

### PID 1 in a container

Chapter 00 said a container is an ordinary process with walls. One wall
is a **PID namespace** (chapter 06 explains namespaces): inside it, PIDs
start again from 1. The first process started in the container sees
itself as PID 1, even though the host sees a large number for it. So in
a container, "PID 1" is not an init system. It is just your command, for
example `sh -c "python /srv/app.py; exit $?"`, as in Day 2.

PID 1 gets a special rule. For any other process, a signal with no
handler gets the default action, which for `SIGTERM` is to terminate.
For PID 1 of a PID namespace the kernel does not apply the default
action. A signal that would normally kill it is discarded unless the
process has installed its own handler for that exact signal. So PID 1
ignores `SIGTERM` unless it installed a handler. (What a signal and a
handler are is chapter 03; here, remember only the rule.)

The consequence: `docker stop` sends `SIGTERM` to the container's PID 1.
A plain shell that never set a handler simply does not die and does not
pass the signal on, and Docker waits and then force-kills it. Day 2's
ENTRYPOINT trap section shows this on the `app` container. Day 2 also
explains the one exception: only `SIGKILL` and `SIGSTOP` sent from an
ancestor namespace (such as Docker's force-kill from the host) bypass
the rule. Other signals from outside, such as a host `kill -TERM`, are
still dropped unless PID 1 has a handler.

### Process states

At any moment each process is in one state. `ps` shows it as the first
letter of the `STAT` column:

| State | Name | Meaning |
|---|---|---|
| `R` | Running or runnable | On a CPU now, or ready and waiting for its turn |
| `S` | Interruptible sleep | Waiting for something (input, a timer, a child). A signal can wake it |
| `D` | Uninterruptible sleep | Waiting inside the kernel, usually for disk, network filesystem, or device. A signal cannot wake it |
| `T` | Stopped | Paused by a signal, for example Ctrl-Z. It will not run until resumed |
| `Z` | Zombie | Exited; waiting for its parent to reap it |

Most processes on a quiet machine are `S`.

Why can't `D` be interrupted? Signals are only looked at by the kernel at
safe points. A process in `D` is partway through a kernel operation
that must finish in one piece, such as waiting for a disk to answer or
for an NFS (a network filesystem) server to reply. If the hardware or
server never replies, the process never reaches a safe point. It is not
ignoring `SIGKILL`; the kernel has not yet had a chance to deliver it.
This is why a hung network disk can leave processes that no signal
removes. Day 2 goes further on this.

**Load average** is a number the kernel keeps for how many tasks want to
run. On Linux it counts tasks in `R` and tasks in `D`, so a machine with
an idle CPU can still show a high load average if many processes sit in
`D` waiting on slow I/O. Zombies (`Z`) and stopped tasks (`T`) add
nothing. Day 4 goes further on reading load average.

### Environment and working directory

Two more things belong to each process.

The **working directory** is the directory that relative paths are
read from (chapter 01 mentioned it). Each process has its own; `cd` in
your shell changes the shell's only. A child starts in its parent's,
and the working directory survives `exec`.

The **environment** is a list of `NAME=value` strings the process was
started with, such as `HOME=/root` or `PATH=/usr/bin:/bin`. A child gets
a copy of its parent's environment when it is created, and can add or
change entries in its own copy; the parent's does not change. At `exec`
the environment is whatever the caller passes in, normally a copy of its
own (Day 2 goes further). Programs read it to find settings, and the
shell uses `PATH` to find where `ls` lives.

### `/proc/PID/`: the process table as files

Chapter 00 said `/proc` is made of files the kernel generates when you
read them. Each process has a directory `/proc/PID/`, and these are the
entries to know:

| Entry | What it shows |
|---|---|
| `status` | Name, state, PID, PPID, memory totals, user IDs; readable text |
| `cmdline` | The command and arguments, separated by NUL bytes, not spaces |
| `exe` | A symlink to the program file the process is running |
| `cwd` | A symlink to the process's working directory |
| `environ` | The environment, NUL-separated |
| `fd/` | One entry per open file (chapter 04 explains descriptors) |

They are generated on each read, so always current; `ps` itself just
reads them. `$$` in the shell is the shell's own PID, and
`/proc/self` always means "the process reading it".

## How it connects

- **Chapter 01's deleted-but-open file** is a process holding a file
  through `fd/`; `exe` and `cwd` are the same kind of link. A deleted
  program can still be running because the process holds it open.
- **Chapter 03** explains the signals mentioned here: what a handler is
  and why some signals cannot be caught.
- **Chapter 04** explains the `fd/` entries, redirection in the
  fork-exec gap, and how exit status is used.
- **Chapters 05 and 06** explain credentials and PID namespaces.
- **Day 2** builds directly on this: the process table, fork and exec
  and what survives them, reaping, PID 1 in `app`, and process states.

## See it yourself

Use the `ws` container: from `labs/fleet`, run
`docker compose -p linuxops exec ws bash`. Every step only reads.

```bash
echo $$
ps -o pid,ppid,stat,cmd
```

**What to look for:** the first line is your shell's PID. The shell
appears with that PID, and `ps` is its child (PPID equals that PID). The
shell's own PPID is likely `0`: `docker exec` starts it from outside. In
`STAT` the first letter is the state (suffixes like `s`, `+` follow):
the shell is `S`, `ps` is `R`.

```bash
ps -ef --forest | head -20
pstree -p 2>/dev/null | head
```

**What to look for:** indentation draws the tree. Your shell tops its own
small tree (PPID 0), apart from PID 1, since `docker exec` started it from
outside. PID 1 is the container's first process; not a real init system.

```bash
cat /proc/$$/status | head -12
```

**What to look for:** `Name`, `State` (a letter and a word, such as
`S (sleeping)`), `Pid`, and `PPid`. Compare `Pid` with `echo $$` and
`PPid` with the PPID `ps` showed.

```bash
ls -l /proc/$$/cwd /proc/$$/exe
```

**What to look for:** two symlinks. `cwd` points at your current
directory and `exe` at the shell program file. Now `cd /tmp` and run it
again: `cwd` changes, `exe` does not.

```bash
tr '\0' '\n' < /proc/$$/environ | head
```

**What to look for:** one `NAME=value` per line, the environment this
shell was started with. Entries such as `HOME` and `PATH` should be
there. The file separates entries with NUL bytes; `tr` turns them into
newlines so you can read them.

```bash
cat /proc/1/cmdline | tr '\0' ' '; echo
ps -o pid,ppid,stat,cmd -p 1
```

**What to look for:** the command line of PID 1 in this container. That
single process is the one that receives `docker stop`'s signal and is
the adopter of any orphan. Its PPID is 0, meaning it has no parent
inside this namespace.

```bash
ps -eo pid,ppid,stat,cmd | awk '$3 ~ /^[DZT]/ || NR==1'
```

**What to look for:** only stopped, zombie, or `D` processes plus the
header; on a healthy `ws` probably nothing else. A `Z` shows as
`<defunct>`; its PPID is the parent failing to reap it.

## Words you'll meet in the course

- **zombie** — Day 2, *wait, the reaping contract, and PID 1* ([glossary](../GLOSSARY.md))
- **reaping** — Day 2, *wait, the reaping contract, and PID 1* ([glossary](../GLOSSARY.md))
- **PID 1** — Day 2, *wait, the reaping contract, and PID 1* ([glossary](../GLOSSARY.md))
- **fork** — Day 2, *fork, exec, and the gap between them*
- **exec** — Day 2, *fork, exec, and the gap between them*
- **child subreaper** — Day 2, *wait, the reaping contract, and PID 1*
- **D state** — Day 2, *The "won't die" family, all four members* ([glossary](../GLOSSARY.md))
- **load average** — Day 2, *Process states and load average*

## Self-check

1. Why does the shell `fork` and then `exec` rather than just `exec`
   the command? What would you lose if `exec` replaced the shell
   itself?
2. A process calls `exit` but its parent is busy and never calls
   `wait`. What does the process table show, and what memory does the
   dead process still hold?
3. `ps` shows a `Z` process. Someone proposes sending it a signal to
   remove it. Why will that not work, and what actually would?
4. A parent exits while two of its children are still running. What
   happens to them, and what must the process that adopts them do
   later?
5. A container's command is `sh -c "python app.py; exit $?"`. Why might
   `docker stop` fail to stop it promptly? Which process is PID 1
   there?
6. A server shows load average 12 but the CPUs are idle. Which states
   might explain it, and why can you not just kill the culprits?

<details><summary>Answers</summary>

1. After `fork` and before `exec`, the child is still shell code, so it
   can rearrange its own surroundings (such as where output goes) and
   then become the program; the parent is untouched. If `exec` replaced
   the shell, the shell would be gone after one command and you would
   have no prompt.
2. A zombie: one row with the PID and exit status. Its memory is already
   freed and its files closed; only the table entry remains until the
   parent calls `wait`.
3. The process is already dead, so there is nothing to stop; a signal
   (chapter 03 explains signals) changes nothing. Only the parent's
   `wait` reaps it. If the parent will never wait, end the parent: the
   zombie is then re-parented to PID 1, which reaps it.
4. They become orphans and are re-parented to the nearest child
   subreaper, or to PID 1. That process must `wait` for them when they
   exit, or they will become permanent zombies.
5. The shell is PID 1 inside the container's PID namespace (chapter 06
   explains namespaces). PID 1 ignores `SIGTERM` unless it installed a
   handler, and this shell stays alive waiting for python (the trailing
   `exit $?` stops it from replacing itself with python), has no handler
   and does not forward the signal, so the container does not stop until
   Docker force-kills it after its timeout.
6. Tasks in `D` (and `R`) count toward load average, so many processes
   waiting in `D` on slow disk or network storage raise it without using
   CPU. They cannot be killed because they are inside a kernel operation
   that does not reach a point where signals are examined; the fix is
   the storage, not the process.

</details>

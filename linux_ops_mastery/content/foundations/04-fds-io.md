# Foundations 04 — File descriptors and I/O

**Prepares you for:** Days 3, 8, 9 and 10.
**Time:** about 45 minutes, including the try-it steps.

Earlier chapters promised this one. By the end you should be able to
say what `2>&1` really does, why `a | b` runs both sides at once, and
how success or failure travels back to the shell.

## What you'll be able to explain

- A file descriptor is a number in a per-process table, pointing at an
  open file description (with the offset), which points at an inode.
- Descriptors 0, 1 and 2 (stdin, stdout, stderr) are a convention the
  shell sets up, not a kernel rule.
- Redirection is the shell rewiring descriptors between `fork` and
  `exec`, and `2>&1` copies where fd 1 points *now*, which is why order
  matters.
- A pipe is a kernel buffer with a write end and a read end; both sides
  of `a | b` run at the same time.
- Children inherit copies of the parent's descriptors across `fork` and
  `exec`, unless a descriptor is marked close-on-exec.
- `/proc/PID/fd/` shows each descriptor as a symlink, and a target
  ending in `(deleted)` is a file that is gone by name but still held.
- Exit status is 0-255; `$?` is the last command's; a pipeline reports
  its last command's status unless `pipefail` is set.
- Arguments are fixed at start; stdin is a stream read while running.

## The mental model

### Three layers: table, description, inode

When a process opens a file, the kernel hands back a **file descriptor**
(fd): a small non-negative integer such as 3. The number is only a
handle. Behind it are three layers.

1. The **fd table**, one per process. Its slots are numbered 0, 1, 2, 3,
   and so on, and each slot points at something in layer 2 (or is
   empty). This is the "list of open files" from chapter 02.
2. The **open file description**: a kernel record created each time a
   file is opened. It holds the **file offset** (the position in the
   file where the next read or write happens), the access mode
   (read-only, write-only, read-write) and flags such as append. It
   points at an inode. These records live in the kernel, not in any one
   process.
3. The **inode** (chapter 01): the file's real identity and data.

Two different slots, in one process or two, can point at the *same* open
file description. They then share one offset: a write through either
moves the position for both. Opening the same path twice instead makes
two descriptions with two independent offsets, both pointing at the same
inode.

`fork` (chapter 02) copies the parent's fd table for the child, but
only the table. The slots in the child point at the *same*
open file descriptions as the parent's. The offset is not copied; it
lives in the shared description. So a parent and child writing to the
same inherited fd take turns advancing one position and do not overwrite
each other.

```
  parent (PID 400)                         child (PID 401, after fork)
  fd table                                 fd table
  fd 1 ---------+                    +-------- fd 1
                |                    |
                v                    v
        +-------------------------------------+
        | description A: terminal, read-write |   <- one object
        +-------------------------------------+
  fd 3 ---------+                    +-------- fd 3
                |                    |
                v                    v
        +-------------------------------------+
        | description B: log.txt, write,      |   <- one object,
        | append, offset 4096                 |      one shared offset
        +-------------------------------------+
                          |
                          v
                   inode 8123 (log.txt)

  Parent fd 3 and child fd 3 are two slots naming ONE description, so
  a write through either moves the offset for both.
```

This explains a chapter 01 puzzle. Deleting a file removes a name. The
kernel frees the inode's blocks only when the link count is zero *and*
no open file description still points at it. So a process that keeps
the file open holds disk space that `du` cannot see, as no name leads
there. See "Looking inside" below.

### Descriptors 0, 1, 2 are a convention

By convention a program reads input from fd 0 (**stdin**, standard
input), writes normal output to fd 1 (**stdout**) and error messages to
fd 2 (**stderr**). `cat` with no arguments reads fd 0; `ls` writes its
listing to fd 1. The kernel does not enforce this. Fd 1 does not have to
be writable text; it is only that programs agree to write there and that
the shell arranges for new processes to find a terminal, a file or a pipe
at those numbers. Day 3 says: "That is all 'stdin', 'stdout', and
'stderr' ever mean."

Keeping errors on their own fd lets output go to a file or the next
program while error messages still reach your eyes.

### Redirection: the shell rewires fds before exec

**Redirection** means changing where one of a command's descriptors
points. A program does not do this; the shell does it for the program,
between `fork` and `exec` (chapter 02). The shell forks a child, and in
that child, before `exec`, it opens files and rearranges the fd table.
Then `exec` loads the new program, which finds its fds already wired and
never knows. So commands need no redirection code of their own.

The operators:

- `cmd >file` opens `file` for writing, creating or **truncating** it
  (emptying it), and points fd 1 at it.
- `cmd >>file` opens it for **appending**: every write goes to the end.
- `cmd <file` points fd 0 at `file`; `cmd 2>file` does `>` for fd 2.
- `cmd 2>&1` means "make fd 2 point at whatever fd 1 points at *right
  now*". The underlying call is **`dup`** (more exactly `dup2`), which
  makes one slot a copy of another: both slots then share one open file
  description. It is a one-time copy, not a permanent tie between fds.

Because redirections are applied left to right, order changes the
result. Take `cmd >out 2>&1`. Here is the child's fd table at each step:

```
 start (inherited from shell)   after  >out        after  2>&1
 fd 0 --> tty                   fd 0 --> tty       fd 0 --> tty
 fd 1 --> tty                   fd 1 --> out       fd 1 --> out
 fd 2 --> tty                   fd 2 --> tty       fd 2 --> out
                                                    ^ copied from fd 1,
                                                      which is now out
 result: stdout AND stderr both go to the file "out"
```

Reverse it: `cmd 2>&1 >out`. First `2>&1` copies where fd 1 points,
which is still the terminal, so fd 2 stays on the terminal. Then `>out`
moves only fd 1. Result: stdout goes to the file and errors still appear
on screen. Same two pieces, opposite meaning, because `2>&1` copies a
target and does not link the fds. Day 3 works this through as well.

One more consequence: `>out` truncates the file when the shell sets it
up, before the command runs. `sort data >data` empties `data` first and
sorts nothing.

### Pipes: two fds around a kernel buffer

A **pipe** is a one-way channel inside the kernel. It is a buffer, a few
tens of kilobytes on Linux (typically 64 KiB), with two ends: a write fd
and a read fd. Data written in at one end comes out of the other in
order. It never touches a disk and has no name in any directory.

For `a | b`, the shell creates the pipe, then forks two children. In `a`
it points fd 1 at the write end; in `b` it points fd 0 at the read end;
then each `exec`s its program.

```
   a | b

   +-------------+                             +-------------+
   | process  a  |   fd 1 (write end)          | process  b  |
   |             |-------+                +----|  fd 0 (read)|
   +-------------+       |                |    +-------------+
                         v                |
   ======================================================== kernel
                    +------------------------+
                    |      pipe buffer       |
                    |  bytes in, bytes out   |
                    +------------------------+
   (the pipe carries only a's stdout; both fd 2s stay on the terminal)
```

Both processes start at once and run concurrently. They are not
"first `a`, then `b`". The buffer coordinates them:

- If the buffer is **full**, `a`'s `write` blocks (waits) until `b`
  reads some. This **backpressure** slows the fast side to the slow
  side's speed, so the stream never needs to fit in memory.
- If it is **empty**, `b`'s `read` blocks until `a` writes.
- When every write end is closed, `b`'s `read` returns zero bytes:
  **end of file** (EOF). A stuck pipeline often means something still
  holds the write end open.
- If every read end is closed and `a` writes, `a` gets the signal
  `SIGPIPE` (chapter 03 explains signals), which ends it by default:
  that is how `yes | head -1` stops.

Each stage is a **subshell** (chapter 03): a child the shell forks, so a
variable set inside a pipeline stage is gone afterwards. Day 9 goes
further on this.

### Inheritance across `fork` and `exec`

Children **inherit** the parent's descriptors: `fork` copies the table
(sharing the descriptions, as above) and `exec` keeps the table as it
is. That is the chain that makes redirection and pipes work: the shell
sets descriptors up, the child keeps them through `exec`.

The exception is **close-on-exec**: a flag on a descriptor slot that
tells the kernel to close that slot automatically when the process
`exec`s. Without it, a parent leaks open files into every program it
starts. A leaked descriptor can hold a deleted file open or keep a
pipe's write end open so a reader never sees EOF. Day 2 goes further on
what survives `exec`.

### Looking inside: `/proc/PID/fd`

Chapter 02 introduced `/proc` as generated files. Two places show
descriptors.

`/proc/PID/fd/` has one entry per open descriptor, named by its number.
Each is a **symlink** (chapter 01) whose target shows what the
descriptor points at. `ls -l` prints it as `3 -> /var/log/app.log`.

```
 0 -> /dev/pts/0              a terminal
 1 -> pipe:[884290]           a pipe (the number identifies the pipe)
 4 -> socket:[884213]         a socket (chapter 07 covers sockets)
 5 -> /var/log/old.log (deleted)
```

The last line is the loop back to chapter 01. A target ending in
`(deleted)` means the name was removed but this descriptor still points
at the inode, so the blocks stay allocated. This is the missing space
that Day 1 chases, and `ls -l /proc/PID/fd | grep deleted` is how to
find the holder.

`/proc/PID/fdinfo/N` goes one level deeper: for descriptor N it shows
`pos` (the offset in the open file description) and `flags` (access mode
and flags). It is the offset layer, made visible.

`lsof -p PID` is roughly `ls -l /proc/PID/fd` with more detail.

### Exit status and `$?`

When a process finishes it gives the kernel an **exit status** (chapter
02): a number from 0 to 255. By convention **0 means success** and
anything else is a failure, with the value saying which kind. The
shell keeps the last command's status in the variable **`$?`**.
Read it at once: the next command, even `echo`, replaces it.

```
 false;  echo $?     prints 1
 true;   echo $?     prints 0
```

What if the process did not choose a number because a signal killed it?
Chapter 03's signals show up here. The shell reports that as
**128 plus the signal number**. A process killed by `SIGKILL` (9) reports
137; by `SIGTERM` (15), 143; by `SIGINT` (2), 130. So a status above 128
usually means "it was killed", and subtracting 128 names the signal.
(A program can also choose such a number itself, so it is a hint.)

A **pipeline's status** is the status of its *last* command only. In
`false | true`, `false` fails with 1, `true` succeeds with 0, and the
pipeline reports `0`: the failure is silently lost. With
`set -o pipefail` the pipeline's status becomes that of the rightmost
command that failed, or 0 if all succeeded. In bash, the array
`PIPESTATUS` holds every stage's status. Day 8 goes further on both.

### Arguments versus stdin

Two channels carry input to a program. **Arguments** (also called
**argv**, the argument vector) are a fixed list of strings handed over
when the program starts; they cannot change afterwards. **Stdin** is a
stream on fd 0 that the program reads as it runs, until EOF. In `cat
file` the file name is an argument and `cat` opens the file itself; in
`echo hi | cat` there is no argument and `cat` reads the pipe. To feed
one command's output to another as arguments you need a bridge such as
`xargs`, which reads stdin and turns it into arguments. Day 10 goes
further on argument handling.

## How it connects

- **Chapter 01's inodes and link count** meet fds here: a deleted file
  lives on while an open file description points at its inode, and
  `/proc/PID/fd` shows `(deleted)` targets.
- **Chapter 02's `fork`/`exec`** are the steps where the shell wires
  up redirection, pipes and inheritance. Exit status is what `wait`
  returns to the parent.
- **Chapter 03's signals** produce the 128+N statuses and `SIGPIPE`.
  Chapter 07 shows that sockets are fds too.
- **Days 3, 8, 9, 10**: layers and redirection; exit status; subshells
  inheriting fds; arguments versus stdin.

## See it yourself

Use the `ws` container: from `labs/fleet`, run
`docker compose -p linuxops exec ws bash`. Every step only observes.

```bash
ls -l /proc/$$/fd
```

**What to look for:** your shell's own descriptors. Fds 0, 1 and 2 most
likely point at the same terminal (`/dev/pts/...`).

```bash
ls -l /proc/self/fd | cat
```

**What to look for:** `/proc/self` means "the process reading it": `ls`,
not your shell. Fd 1 is a `pipe:[...]` because of the `| cat`: the
shell rewired it before `exec`. Fd 0 and 2 still point at the terminal.

```bash
sleep 1 | ls -l /proc/self/fd
```

**What to look for:** this time `ls`'s fd 0 is the pipe (the read end,
fed by `sleep`) while its fd 1 is the terminal. A pipe in the `0` slot
is the "b" side of `a | b`.

```bash
cat /proc/$$/fdinfo/0
```

**What to look for:** `pos` (the offset) and `flags` (the open mode in
octal) for your shell's stdin. For a terminal the position is not
meaningful, but the fields are the open file description's.

```bash
false; echo "status: $?"; true; echo "status: $?"
```

**What to look for:** `1` after `false` and `0` after `true`. The
`$?` is read before the next command overwrites it.

```bash
false | true; echo "pipeline: $?"; false | true; echo "per stage: ${PIPESTATUS[@]}"
```

**What to look for:** the pipeline reports `0` although `false` failed,
because only the last command counts. The second line, read straight after
the pipeline, shows `1 0`: the per-stage statuses bash keeps.

```bash
lsof -a -d 0-2 -p $$ 2>/dev/null
```

**What to look for:** fds 0, 1 and 2 of your shell, one row each (`-d
0-2` limits it; without it, memory-mapped files fill the top). `TYPE`
`CHR` is a tty, `FIFO` a pipe.

## Words you'll meet in the course

- **file descriptor** — Day 3, *Why this matters* ([glossary](../GLOSSARY.md))
- **open file description** — Day 3, *Read the file first*
- **redirection** — Day 3, *Core concepts*
- **dup2** — Day 3, *Core concepts*
- **pipefail** — Day 3, *Core concepts* ([glossary](../GLOSSARY.md))
- **exit code** — Day 8, *The underlying truth* ([glossary](../GLOSSARY.md))
- **PIPESTATUS** — Day 8, *The underlying truth* ([glossary](../GLOSSARY.md))
- **subshell** — Day 9, *The underlying truth* ([glossary](../GLOSSARY.md))
- **argument contract** — Day 10, *Why this matters*
- **fdinfo** — Day 3, *Read the file first*

## Self-check

1. A parent forks a child, and both write lines to the same inherited
   fd 1, which points at a file. Do their lines overwrite each other?
   Where is the offset kept?
2. What is the difference between `cmd >out 2>&1` and
   `cmd 2>&1 >out`? Which one puts error messages in `out`?
3. In `a | b`, why can `b` start producing output before `a` has
   finished? What stops `a` from filling all of memory if `b` is slow?
4. `df` shows a disk 95% full but `du` finds only half of it.
   `/proc/812/fd` has a target `/var/log/app.log (deleted)`. What is
   going on, and what frees the space?
5. A deploy script runs `build | tee log` (`tee` copies its stdin to
   its stdout and to a file) and reports success although the build
   failed. Why, and what would you change?
6. `echo $?` prints 143 after a job. What most likely happened, and
   would `kill -9` have given the same number?

<details><summary>Answers</summary>

1. No. `fork` copies the fd table but the slots point at the same open
   file description, so they share one offset kept in the kernel. Each
   write advances it for both, so the lines follow each other. (Opening
   the file twice would give two offsets that can overwrite.)
2. In `>out 2>&1` fd 1 goes to `out`, then fd 2 copies it: both land in
   `out`. In `2>&1 >out` fd 2 copies the terminal first, then only fd 1
   moves, so only normal output goes to `out`.
3. They run at the same time, joined by a kernel buffer, so `b` reads as
   soon as `a` writes. When the buffer is full `a`'s write blocks until
   `b` drains it, so memory use stays bounded.
4. A process (PID 812) still holds the log open. The name was deleted
   but the open file description keeps the inode and its blocks, and
   `du` cannot walk to a nameless file. The space returns when that
   process closes the file or exits (or is restarted).
5. A pipeline reports its last command's status, here `tee`, which
   succeeded. Use `set -o pipefail` so the failing stage shows, or check
   `PIPESTATUS`. Day 8 covers the details.
6. 143 is 128 + 15: the process was killed by `SIGTERM` (signal 15,
   the default `kill`). `kill -9` would give 137 (128 + 9). The number
   is only a hint, as a program may also choose to exit with 143.

</details>

# Foundations 00 — The big picture

**Prepares you for:** every day of the course.
**Time:** about 30 minutes, including the try-it steps.

This chapter builds the base vocabulary. Every later foundations chapter,
and every `content/dayNN.md`, assumes these words. Nothing here needs
more than a shell prompt to check.

## What you'll be able to explain

- The kernel is the one program that talks to the hardware; everything
  else, including your shell and nginx, asks the kernel to act for it.
- A system call is the formal way a program asks the kernel for
  something, such as opening or reading a file.
- "Everything is a file" means many different things are reached through
  the same open/read/write calls. It does not mean everything is stored
  on a disk.
- `/proc` and `/sys` hold no stored data: the kernel makes up their
  contents at the moment you read them.
- A container is ordinary processes on the host's one kernel, with walls
  around what they see and limits on what they use.

## The mental model

### Layers: hardware, kernel, programs

A computer has **hardware**: the CPU, memory (RAM), disks, network cards.
Something has to decide which program gets the CPU next, which program
may touch which part of memory, and who gets to write to the disk. On
Linux that something is the **kernel**: one big, always-running piece of
software that owns the hardware and shares it out.

Everything that is not the kernel is a **program** running in **user
space**: your shell, `ps`, `cat`, nginx, a Python script. The kernel's
own code and memory live in **kernel space**. These are two zones with a
hard border between them, enforced by the CPU itself.

```
   user space      +-----------+  +-----------+  +-----------+
   (programs)      |   shell   |  |    ps     |  |   nginx   |
                   +-----+-----+  +-----+-----+  +-----+-----+
                         |              |              |
   ======================v==============v==============v========
        system-call boundary: the only door into the kernel
   ==============================================================
   kernel space    +------------------------------------------+
                   |  kernel: files, processes, memory,       |
                   |  network, scheduling, device drivers     |
                   +--------------------+---------------------+
                                        |
   hardware             CPU     RAM     disk      network card
```

*Analogy:* the kernel is the front desk of a building and the programs
are tenants. Tenants never walk into the machine room; they file a
request at the desk.
*Where the analogy breaks:* a desk clerk is a separate person who can be
busy elsewhere, but the kernel runs on the very same CPU, briefly taking
over whenever a program asks for something.

### Why programs cannot touch hardware directly

If any program could write straight to the disk or read any other
program's memory, one bug would corrupt everything, and no program could
be kept private from another. So the CPU has two modes. Ordinary programs
run in a restricted mode where touching hardware, or memory that belongs
to someone else, is simply refused. Only the kernel runs in the
privileged mode. This is why the border in the diagram exists, and why a
buggy program normally crashes only itself instead of the machine.

### System calls: asking the kernel

A **system call** (often "syscall") is a program's request to the kernel.
The program puts a request number and arguments in agreed places and
executes a special CPU instruction; the CPU switches to the privileged
mode, the kernel does the work, and control returns to the program with
an answer. Programs rarely do this by hand: the C library wraps each
syscall in a normal-looking function.

A handful of syscalls explain most of what you will see in this course:

| Syscall | Plain meaning |
|---|---|
| `open` | "Give me access to this file." Returns a small number as a handle. |
| `read` | "Hand me bytes from that handle." |
| `write` | "Put these bytes into that handle." |
| `fork` | "Make a copy of me." Creates a new process. |
| `exec` | "Replace my contents with this other program." |

A **program** is an executable file sitting on disk: instructions that
are not running. A **process** is a running instance of a program, with
its own memory and its own set of open handles. The shell starts `ps` by
calling `fork` (copy myself) and then `exec` (become `ps`). Chapter 02
explains processes fully; for now, "process" just means "something the
kernel is currently running on behalf of a program."

You can watch syscalls happen with `strace`, which Day 2 uses.
That makes this concrete: `cat notes.txt` is mostly an `open`, some
`read` calls, some `write` calls to the screen, and an exit.

### Everything is a file

A **file**, to a program, is anything that supports the same few
operations: open it, read from it, write to it, close it. Linux pushes
this idea very far. Ordinary documents, directories, a device file such
as `/dev/null`, a disk device, and even a network connection can all be
handled with `open`/`read`/`write`. That is the meaning of "everything
is a file": one small set of calls works on many different kinds of
thing, so one set of tools (`cat`, `ls`, redirection; chapter 04 covers
redirection) works on all of them.

The kernel makes this possible with a layer called the **VFS** (virtual
file system) that presents many different back-ends through one common
set of calls.

The limits of the idea matter just as much:

- It does not mean everything lives on disk. A network **socket** (one
  end of a network connection) is handled like a file once opened, but it
  has no name and no bytes stored anywhere; it is a live connection
  inside the kernel. Chapter 07 covers sockets.
- It does not mean every file supports every operation. Writing to a
  read-only file fails, and a directory is read as a list of names, not
  as a stream of bytes.
- Not everything has a path. A file can stay open after its last
  name is deleted (chapter 01 explains deleted-but-open files).

### /proc and /sys: files that are not stored

Run `ls /proc` and you see numbers and names that look like directories
and files. They are not on any disk. `/proc` and `/sys` are windows the
kernel offers into its own state, shaped like files so that ordinary
tools can read them. When you `cat` one of these files, the kernel runs
code at that moment and produces the text on the spot. Nothing was
sitting there waiting. That is why the content is always current, and
why `ls -l` shows `/proc` files with size 0 (`/sys` files usually show
4096): there is no stored length to report, even though `cat` then prints several lines.

- `/proc` mostly describes **processes** and the system as a whole: one
  numbered directory per running process, plus files such as
  `/proc/uptime` and `/proc/meminfo`.
- `/sys` mostly describes **devices and kernel settings**, organised as a
  tree: hardware, drivers, and (on a modern system) the control files for
  cgroups, which a later section names.

The path `/proc/self` is a shortcut worth knowing early. It always points
at the process that is looking at it. So `cat /proc/self/status` shows
the status of the `cat` process itself, whoever runs it.

```
   you run:  cat /proc/uptime
                 |
                 |  open("/proc/uptime"), read(...)    (syscalls)
                 v
   +-----------------------------------------------+
   | kernel: "uptime file" handler runs NOW,       |
   | formats the current clock into text           |
   +-----------------------------------------------+
                 |
                 v
   cat prints the text.  Nothing was read from a disk.
```

This is the heart of the course. The friendly commands are thin layers
over these files: `ps` reads `/proc` to list processes, `free` reads
`/proc/meminfo`, and `df` reads `/proc/mounts` and also calls the
`statfs` syscall to ask each filesystem for its usage (chapter 01
explains filesystems and mounts). `ss` is the one that takes a
different road: it asks the kernel about sockets over a channel called
netlink (a socket-style conversation with the kernel) instead of
parsing a text file. Either way, one kernel-owned truth sits
underneath the tool.

### A container is ordinary processes with walls and limits

A **container** (for example a Docker container) is not a small virtual
computer. It is one or more ordinary processes on the host, running on
the host's single kernel. Two kernel features make them look separate:

- **Namespaces** are walls: they limit what a process can see, such as
  which processes, which mounts, and which network interfaces.
- **Cgroups** are limits: they cap how much CPU, memory, and other
  resources a group of processes may use.

Because there is only one kernel, a container does not carry its own. On
a Linux host, `uname -r` inside a container prints the host's kernel
version. On Docker Desktop for Mac, the "host" is a small Linux virtual
machine, so the kernel your containers share is that VM's Linux kernel,
not macOS. That is why this course's `ws` container shows a Linux kernel
even though your laptop runs macOS. Chapter 06 explains namespaces and
cgroups properly; here they are just names.

### The course's four truths, and the move

The course organises everything around four facts the kernel owns. Each
is previewed here in one paragraph, with the chapter that builds it and
the day that uses it.

**1. The mount tree.** Every path you type is resolved through a tree of
mounted filesystems, and the name of a file is not the same thing as the
stored file itself. The question it answers is "where do the bytes
actually live, versus what the path claims?" Its evidence is
`/proc/mounts`. Chapter 01 builds it; Day 1 uses it.

**2. The process table.** The kernel keeps a record of every process: who
started it, what state it is in, which program it runs. The question is
"who is running, in what state, spawned by whom?" Evidence lives in
`/proc/<pid>/`, one directory per process. Chapters 02, 03, and 05 build
it; Days 2 and 5 use it.

**3. The file-descriptor table.** Each process holds a numbered list of
the things it has open: files, pipes (chapter 04 explains pipes),
sockets. The question is "what does this process hold open right now?"
Evidence is `/proc/<pid>/fd`. Chapter 04 builds it (chapter 07 adds the
network side); Days 3 and 6 use it.

**4. The cgroup and namespace boundary.** The question is "what may this
process see, and how much may it consume?" Evidence is under
`/sys/fs/cgroup` and `/proc/<pid>/ns`. Chapter 06 builds it; Day 4 uses
it.

```
   Truth                   Foundations chapter     Course day
   ----------------------  ----------------------  ----------
   1 mount tree            01 files and inodes     Day 1
   2 process table         02, 03, 05              Days 2, 5
   3 fd table              04 (07 for sockets)     Days 3, 6
   4 cgroup / namespace    06 resources            Day 4
   all four together       00-07                   Day 7
```

On top of the four truths sits one repeatable habit, **the move**:

> symptom -> resource class -> the file that proves it

You see a symptom ("the disk is full", "the container vanished"). You
decide which of the four classes of resource it belongs to. Then you
read the specific kernel file that confirms or kills your theory,
before changing anything. The rest of the course is practice at this.

## How it connects

This is the first chapter, so it connects forward. Chapter 01 zooms in on
the first truth: the files and the tree they live in. Chapter 02 zooms in
on the process, which this chapter only named. Chapter 04 explains the
"small number as a handle" that `open` returns. Chapter 06 returns to
namespaces and cgroups. Chapter 07 returns to sockets. Throughout, the
same picture holds: programs live above the system-call border, and the
files under `/proc` and `/sys` are the kernel describing itself across
that border.

## See it yourself

Open the workspace container first:
`docker compose -p linuxops exec ws bash` (run from `labs/fleet`). Every
step below only reads.

```bash
uname -r
cat /proc/version
```

**What to look for:** a kernel version string. This is the kernel your
container is sharing with the host (inside Docker Desktop on a Mac, the
Linux VM's kernel, not macOS). There is no kernel installed "in" the
container.

```bash
ls /proc
```

**What to look for:** some all-digit names (only a few inside a
container). Each is a process ID, with a
directory of information about that process. Beside them are plain names
such as `uptime` and `meminfo` that describe the whole system.

```bash
cat /proc/self/status | head -8
```

**What to look for:** the `Name:` line says `cat`, because `/proc/self`
means "the process asking". Note `Pid:` and `PPid:`: the `PPid` is the
shell that started `cat`. Chapter 02 explains both.

```bash
cat /proc/uptime
sleep 3
cat /proc/uptime
```

**What to look for:** the first number grew between the two runs. No
file on a disk changes by itself like that; the kernel recalculated it
each time you read.

```bash
ls -l /proc/uptime /proc/version
```

**What to look for:** the size column shows `0` for these files even
though `cat` printed text. The content is generated on read, so there is
no stored length.

```bash
ls /sys
ls /sys/fs/cgroup | head
```

**What to look for:** directories such as `class`, `kernel`, `fs`, and
inside `/sys/fs/cgroup` a set of control files. This is where the
fourth truth lives (chapter 06).

## Words you'll meet in the course

- **mount namespace** — Day 1, *Bind mounts* ([glossary](../GLOSSARY.md))
- **descriptor (file)** — Day 3, *Core concepts* ([glossary](../GLOSSARY.md))
- **PID 1** — Day 2, *Core concepts* ([glossary](../GLOSSARY.md))
- **cgroup** — Day 4, *cgroup v2: hierarchy and delegation* ([glossary](../GLOSSARY.md))
- **OOM killer** — Day 4, *The OOM killer: score, adjustment, cgroup versus global* ([glossary](../GLOSSARY.md))
- **system call** — Day 2, *Core concepts* (fork, exec, and the gap between them) ([glossary](../GLOSSARY.md))
- **strace** — Day 2, *Core concepts* (`strace -f -p PID`) ([glossary](../GLOSSARY.md))

## Self-check

1. Why can't a program write directly to the disk, and what does it do
   instead?
2. `cat /proc/uptime` prints a different number each time, yet
   `ls -l /proc/uptime` shows size 0. What does that tell you about where
   the content comes from?
3. You run `uname -r` inside a container on a Mac with Docker Desktop.
   Whose kernel version is it, and why is there no container-specific
   kernel?
4. "Everything is a file." Give one thing this really covers and one
   thing it does not mean.
5. A colleague says "`ps` is how the system knows what is running." What
   is the more accurate statement, and which directory does it read?
6. You see the symptom "the app was killed under load". Using the move,
   which resource class would you suspect first, and what kind of file
   would you go read?

<details><summary>Answers</summary>

1. Hardware access is restricted to the kernel, enforced by the CPU, so
   one buggy or malicious program cannot corrupt the machine or other
   programs. The program makes a system call, such as `write`, and the
   kernel performs the action on its behalf.
2. The content is generated by the kernel at read time, not stored.
   There is no stored length, so the size shows as 0, but each `cat`
   produces fresh text from the current state.
3. It is the host's kernel; on Docker Desktop for Mac the host kernel is
   the Linux VM's, not macOS. A container is just processes with
   namespaces and cgroups on that one shared kernel, so it carries no
   kernel of its own.
4. It really covers things like regular files, directories and device
   files such as `/dev/null`, all reachable by open/read/write. It does
   not mean everything is stored on disk: a socket is a live kernel
   object with no bytes on disk, and not every operation works on every
   kind of file.
5. `ps` is a thin formatter: it reads the per-process directories under
   `/proc` (the kernel's process table) and prints columns. The truth is
   the kernel's record.
6. A cgroup and namespace boundary question (truth 4): the memory limit
   may have been hit. Read the control files under `/sys/fs/cgroup`,
   such as `memory.events` (Day 4), rather than relying on `free`.

</details>

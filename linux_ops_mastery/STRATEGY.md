# The Top 1% Strategy for Linux Operations

`ps`, `top`, `free`, `df`, `ss`, and `lsof` are not knowledge; they are
pretty-printers over kernel files.

Most of these commands open a file under `/proc` or `/sys`, parse it, and
print columns: `ps` formats `/proc/*/stat`, `free` formats `/proc/meminfo`,
`df` formats `/proc/mounts` plus a `statfs(2)` call, and `netstat` parses
`/proc/net/tcp`. `ss` is the interesting exception: it asks the kernel the
same question over a different channel — netlink `SOCK_DIAG` — because
parsing text out of `/proc` stopped scaling once hosts carried hundreds of
thousands of sockets. Two tools, two transports, one kernel-owned truth
underneath, which is exactly why the doctrine here is about the *truth*
and not the *file*: land in a container with neither `ss` nor `netstat`
installed, and `cat /proc/net/tcp` still answers, because the file
interface is the one the kernel always exports. Learn the tool and you own
a vocabulary that vanishes the moment the tool is missing — which is
precisely the situation in a stripped container or a minimal EC2 AMI.
Learn the underlying truth and you can derive any tool, on any box, with
nothing but `cat` and a shell.

## The four truths

Four kernel-owned truths organise everything in this path. The seven days
walk them in dependency order — filesystem, then process, then descriptor,
then boundary — because each later truth is expressed in terms of the one
before it: a process is a set of open descriptors on top of a mount tree,
and a cgroup is a limit wrapped around a set of processes.

| # | Truth | Question it answers | Primary evidence |
|---|---|---|---|
| 1 | **Mount tree** | Where do the bytes actually live, versus what the path claims? | `/proc/mounts`, `/proc/PID/mountinfo`, `/sys/fs` |
| 2 | **Process table** | Who is running, in what state, spawned by whom? | `/proc/PID/{stat,status,cmdline,exe,cwd,environ}` |
| 3 | **FD table** | What does this process hold open right now? | `/proc/PID/fd`, `/proc/PID/fdinfo` |
| 4 | **cgroup / namespace boundary** | What may this process *see*, and how much may it *consume*? | `/sys/fs/cgroup/**`, `/proc/PID/ns`, `/proc/PID/cgroup` |

## The move

Every diagnosis in this path collapses to one repeatable move, practised
40+ times across seven days:

> **symptom → resource class → the file that proves it**

No claim about a Linux box survives unless it can be traced to a file you
can `cat`. "It's probably a disk space thing" is not a diagnosis; it is a
guess wearing a lab coat. The move forces the guess into a resource class,
and the resource class into a specific path under `/proc` or `/sys` that
either confirms or kills the theory before you touch anything.

Two worked examples:

**"The disk is full."** `df` reports 100% on a mount point, which only tells
you the mount tree's used-versus-available accounting, not why. That is
resource class 1 (mount tree), so the next file is `/proc/mounts` to confirm
which device backs the path, then `du` on the mount to see what the
directory tree accounts for. When `df` and `du` disagree, the usual cause
— though reserved root blocks, sparse files, and a submount under the `du`
target can produce the same gap — is bytes the filesystem is still billing
but no path names any more: an unlinked-but-open file. The proof lives in
resource class 3 (fd table):
walk `/proc/*/fd` for every PID, `readlink` each entry, and find the one
pointing at `<path> (deleted)`. That symlink target is the evidence; killing
or truncating the holding process is the fix, and re-running `df` afterward
is the proof.

**"The container was killed."** A process disappearing under load with no
application-level error is a boundary question, not a process-table
question — resource class 4. The file that proves it is
`/sys/fs/cgroup/memory.events`: a nonzero `oom_kill` counter confirms the
kernel's cgroup OOM killer fired, independent of what `free` reported inside
the container, because `free` reads host-wide `/proc/meminfo` and has no
idea a cgroup limit exists. `memory.max` gives the ceiling and
`memory.current` gives the last known level before the kill. Three files,
zero guessing, and a diagnosis that would otherwise have been misdiagnosed
as "the app leaked memory" from `free` output alone.

## The daily loop

Every day in this path executes the same seven steps. The loop, not the
topic list, is the product — internalise it and any Linux incident becomes
tractable, not just the seven in this curriculum.

1. **Name the truth** — state which of the four truths today's material
   belongs to, before opening any file. This scopes the search space before
   you start reading, instead of after you're already lost in output.
2. **Read the raw file first** — `cat` the kernel file and decode its
   fields by hand, with no tool standing between you and the bytes. This is
   the step every certification path and every blog post skips, and it is
   the one that makes the tool afterward legible instead of magic.
3. **Derive the tool** — run the friendly tool and map every column in its
   output back to a field in the file you just read. The tool stops being a
   black box the moment you can predict its output from the source.
4. **Break it** — run `break.sh`. It produces a symptom and no explanation,
   because a diagnosis you were handed is not a diagnosis you can repeat
   under pressure on someone else's incident.
5. **Write the chain before fixing** — the diagnosis goes into
   `journal.md` as a numbered chain of evidence *before* any repair is
   attempted. **The chain is written before the fix is attempted.** This
   is the step that forces the model to do the work instead of
   trial-and-error masquerading as troubleshooting; a fix that happens to
   work before the chain is written teaches nothing about why it worked.
6. **Fix and prove** — repair the system, then re-read the same file used
   in step 2 to demonstrate the change at the source of truth, not at the
   tool's summary layer. The proof and the diagnosis share one file for a
   reason: it closes the loop back to step 2.
7. **Strip the toolbox** — repeat the diagnosis inside the busybox-only
   Alpine container, where the friendly tool from step 3 does not exist.
   This is the step that verifies the model was actually learned rather
   than the tool's flags, and it is the one that transfers directly to a
   minimal ECS task or a distroless image with no shell fat to fall back on.

## The seven mistakes

Reproduced here because every per-day *Anti-patterns* section cites these
by number. Do not add an eighth; if a day's content wants a new mistake,
it belongs under one of these seven or it does not belong in the path.

### Mistake 1 — Memorising flags instead of the model

Beginners collect `tar czvf` and `find -exec {} \;` the way they collect
trivia, because flags feel like progress: something new was learned today.
Flags are one `--help` or `man` page away at the moment you need them; the
resource model underneath is not, and no flag mnemonic tells you why a
`tar` extraction landed with the wrong ownership or why `find -exec`
forked once per file while `xargs` didn't. Every hour spent drilling flags
is an hour not spent on the file descriptor, the inode, or the cgroup that
the flag merely manipulates. Learn what the command touches, then treat
the flags as documentation you look up.

### Mistake 2 — Trusting the summary tool

Beginners read `free`'s "free" column as "how much memory is available"
and load average as "how busy the CPU is," and both readings are wrong in
ways that matter under incident pressure. `free`'s free column ignores
reclaimable page cache; the number that answers "can a new process get
memory" is `MemAvailable`, a field `free` itself has to compute
separately. Load average counts runnable *and* uninterruptible processes,
so a box pegged on slow disk I/O reports a high load average with a bored
CPU. Trusting either folk reading produces a wrong incident call — scaling
compute for a memory-reporting artifact, or blaming the CPU for a stuck
NFS mount. Read the underlying field before repeating the summary as fact.

### Mistake 3 — Learning tools that do not exist on real servers

`htop`, `ncdu`, `bat`, and friends are comfortable and none of them ship on
a stock `alpine:3.20` image, a distroless container, or most bare EC2
AMIs. Fluency built entirely on conveniences converts to paralysis the
first time a shell has only busybox `ps` and no `top` at all. This path
treats every convenience tool as optional garnish learned after the
`/proc`-based equivalent, never as a substitute for it, because the
garnish is exactly what is missing from the box you'll be debugging at 2
a.m.

### Mistake 4 — Practising on a healthy box

A system with nothing wrong teaches nothing; every command returns a
value and there's no falsifiable claim to test. Reading `man ss` and
running it against a quiet loopback socket builds recognition, not
diagnosis, because recognition without a state to distinguish is just
narration. Every lab in this path begins from an injected, specific,
reproducible failure, because the skill under construction is
distinguishing a broken value from a normal one, and that skill has no
healthy-box analog.

### Mistake 5 — Reading instead of verifying

It is possible to read an entire book on Linux internals, understand
every diagram, and never once run `strace` against a live process —
which leaves the syscall boundary a permanently abstract idea instead of
a thing you have watched happen. The same gap shows up as never having
walked `/proc/PID/fd` by hand, or never having confirmed with your own
eyes that `cpu.max` throttling and `cpu.stat`'s `nr_throttled` counter
move together. Conceptual understanding that has never been checked
against a live, running system is a belief, not a skill, and it fails
silently exactly when an incident needs it to hold.

### Mistake 6 — Deferring the permission model

The permission model gets skipped because `chmod 755` and `chmod 644`
work often enough that the underlying rules never get forced into view —
until a setuid binary, a missing capability, or the directory execute bit
produces a denial that mode bits on the file itself cannot explain. The
default response under pressure is `chmod 777`, which frequently
"fixes" the symptom by coincidence while leaving the actual cause (wrong
owner, missing `+x` on a parent directory, a dropped capability, or a
restrictive umask at creation time) undiagnosed and ready to recur. Learn
uid/gid/euid, the directory execute bit, and capabilities before the
first permission incident, not during it.

### Mistake 7 — Learning vim from a tutorial

Working through an interactive vim tutorial in a comfortable terminal with
arrow keys still enabled builds a habit that survives exactly until the
next real editing task, when the fingers reach for the arrows out of
muscle memory built over years. The tutorial completes; the model does
not transfer. This path disables arrow keys from Day 2 onward and forces
every subsequent lab file to be edited in `nvim` under mild time pressure,
because the modal grammar (operator plus motion plus text object) is
learned by being unable to fall back to anything else, not by following
along with a demo.

## Why not the alternatives

A **USE-method spine** (order the curriculum by CPU, memory, disk, network
saturation) is an excellent checklist for "the box is slow," and it is
structurally incapable of housing the filesystem model, the permission
model, boot, or service management — none of those are resource-saturation
questions, so a USE-ordered curriculum either omits them or bolts them on
without a organising principle. It diagnoses; it does not teach.

A **certification-objective spine** (LPIC-1 or LFCS, worked in order)
guarantees coverage and directly rebuilds the decayed scaffolding from
years-old certifications, but objective lists teach *facts* organized for
an exam, not a *method* organized for an incident, and they spend real
hours on printing subsystems, X11, and SysV init that never appear on a
modern server or in a container. A learner who finishes an objective
sweep can pass a written exam and will still guess under a live incident,
because nothing in the sweep trains the symptom-to-file move. This path
uses the `/proc` doctrine as the spine and keeps the certification
objectives as an audit in `COVERAGE.md` instead: a map from every LPIC-1
and LFCS objective to the day that covers it, with an explicit
deliberately-skipped list and the reasoning for each skip.

## Neovim's bounded role

Neovim receives roughly 3 of the path's 21 hours, split deliberately rather
than spread evenly, because the goal is bounded competence for a specific
job, not editor mastery for its own sake:

- **1 h on Day 1**, placed first so the modal model is usable before it is
  needed under pressure: the operator-plus-motion-plus-text-object grammar,
  `hjkl` with arrow keys already disabled, word and line motions, basic
  edits, search, and undo.
- **1.5 h on Day 7**, the operator payload, saved for last because it
  assumes a week of forced daily practice: `:g//` and `:v//`, macros and
  registers, buffers and `:argdo`, a quickfix list populated from `grep`
  and traversed with `:cn`, `:%!` filtering through a shell command,
  marks, diff mode, and `:w !sudo tee %` for recovering a root-owned file
  opened as a non-root user.
- The remaining ~0.5 h is woven into Days 2 through 6 as short in-lab
  prompts, not scheduled as separate lessons.

**The arrow-keys rule:** from Day 2 onward, every lab file is edited in
`nvim` inside the `ws` container with arrow keys disabled by the shipped
`init.lua`. This is the actual multiplier — it converts 3 explicit hours
of instruction into roughly 15 hours of forced practice across the
remaining labs, at zero cost to the Linux budget, because the editing was
going to happen anyway.

**Explicit non-goal:** this path does not replace VSCode, and does not
cover plugin managers, LSP, completion, or Treesitter. Neovim here is a
recovery tool for a server VSCode cannot reach, nothing more.

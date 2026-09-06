# Linux Operator Mastery (+ Neovim) — Design Spec

**Date:** 2026-09-06
**Location:** `linux_ops_mastery/`
**Duration:** 7 days, 3 h/day (~21 h total)
**Path type:** Applied / engineering — ships a `labs/` scaffold
**Skill:** authored under `skill.md` (`building-learning-path`)

---

## Purpose & Goals

The learner is a senior software engineer who works on Linux servers daily and
holds LPI-era knowledge that has decayed into habit: commands still get typed
correctly, but the model underneath them is gone. The day job involves shelling
into AWS ECS tasks and EC2 instances to monitor and debug — environments where
the friendly tooling is often absent and where the failure modes (PID 1 signal
handling, cgroup memory limits, container DNS) are precisely the ones a
laptop-shaped understanding of Linux does not cover.

The goal is not to learn new commands. It is to **replace a command vocabulary
with a resource model**, so that diagnosis becomes derivable rather than
recalled. Mastery here looks like this: presented with an unfamiliar broken
Linux box and a vague symptom, the learner names the resource class involved,
names the kernel file that proves or disproves it, reads that file, and reaches
a diagnosis in a chain of evidence with no guessing and no internet.

Neovim is a secondary track with a specific and bounded purpose: editing
configuration and inspecting files fluently on a server where VSCode cannot
reach. It is not a plan to replace the learner's daily editor.

The strategy is unconventional in one specific way, described in full under
**Strategy** below: the curriculum is ordered by the kernel's own structure
rather than by tool categories or certification objectives, and every tool is
introduced *after* the kernel file it formats — never before.

## Success Criteria

By the end of Day 7, without notes and without internet access, the learner can:

1. Explain what `ps`, `top`, `free`, `df`, `ss`, and `lsof` each read, and
   reproduce the essential output of each one using only `cat` on `/proc` plus
   shell builtins.
2. Diagnose a full filesystem when `df` and `du` disagree, and name the
   mechanism (unlinked-but-open file) with evidence from `/proc/*/fd`.
3. Read `/proc/PID/status` and `/proc/PID/stat` and state a process's state,
   parent, thread count, and signal masks from the raw fields.
4. Explain why a container's application does not receive `SIGTERM` when the
   entrypoint is `sh -c "..."`, and fix it two different ways.
5. Distinguish load average from CPU utilisation, and explain what a `D`-state
   process contributes to each.
6. Diagnose an OOM kill from inside a container whose `free` output shows ample
   memory, using the cgroup v2 files, and distinguish RSS, page cache, and
   `MemAvailable`.
7. Detect CPU throttling from `cpu.stat` and connect it to an ECS task
   definition's CPU units.
8. Resolve a permission denial that persists at mode `0777`, naming the actual
   cause (directory execute bit, ownership, capability, or umask on creation).
9. Write and debug a systemd unit, read its failure from `journalctl`, and state
   what replaces each systemd responsibility inside a container.
10. Walk the connectivity ladder — DNS, route, firewall, listener, application —
    naming the command *and* the proving file at each rung, including the
    container `ndots` resolution trap.
11. Edit any config file on a bare server in neovim without arrow keys:
    navigate by motion and text object, search and substitute across a file with
    `:g//`, record and replay a macro, populate and traverse a quickfix list,
    and recover from having opened a root-owned file as a non-root user.
12. Produce, for any injected incident, a written diagnosis chain in which every
    claim cites the file or command output that proves it.

## Constraints & Environment

| Constraint | Detail |
|---|---|
| **Host** | macOS on Apple Silicon (iMac M4) — everything must be arm64-native |
| **Runtime** | Docker Desktop; all base images multi-arch (`ubuntu:24.04`, `alpine:3.20`, `postgres:16-alpine`, `nginx:alpine`) |
| **Cost** | Zero. No cloud resources are created at any point. AWS appears only as explanatory context |
| **`strace`** | Requires `--cap-add=SYS_PTRACE` on the workstation container; specified in the compose file |
| **systemd** | Day 5 needs a real PID 1 systemd. Runs as a dedicated container with `--privileged` and `--cgroupns=host`. This is the one fragile piece on Docker Desktop; a Colima/Lima VM fallback is documented and must be tested-by-instruction in the lab README |
| **cgroup v2** | Docker Desktop exposes cgroup v2; Day 4 depends on `memory.max`, `memory.current`, `memory.events`, `cpu.max`, `cpu.stat` being readable |
| **Git** | Never commit, add, or push on the learner's behalf. The learner owns all VCS |
| **Credentials** | No real secrets, keys, tokens, or account IDs in any file. Placeholders plus `*.example` files only |
| **Real infra** | Labs are *authored*, not *run*, during content creation. No `docker compose up` during authoring |
| **Exercises** | Every exercise ships a hint and a solution sketch. Non-negotiable |
| **Editor** | From Day 2 onward, all lab file editing is done in neovim with arrow keys disabled |

## Strategy (the core design decision)

### The `/proc` doctrine

The organising claim of this path: **`ps`, `top`, `free`, `df`, `ss`, and `lsof`
are not knowledge — they are pretty-printers over kernel files.** `ps` formats
`/proc/*/stat`. `free` formats `/proc/meminfo`. `ss` formats `/proc/net/tcp`.
`df` formats `/proc/mounts` plus a `statfs` call.

An operator who learns the tools has learned a vocabulary that fails the moment
the vocabulary is unavailable — which is exactly the situation in a stripped
container. An operator who learns the *files* can derive any tool, and can work
where no tool exists. This is the single highest-leverage inversion available in
Linux operations, and it is why every day introduces the kernel file first and
the tool second.

Four kernel-owned truths organise everything, and the seven days walk them in
dependency order:

| # | Truth | Question it answers | Primary evidence |
|---|---|---|---|
| 1 | **Mount tree** | Where do the bytes actually live, versus what the path claims? | `/proc/mounts`, `/proc/PID/mountinfo`, `/sys/fs` |
| 2 | **Process table** | Who is running, in what state, spawned by whom? | `/proc/PID/{stat,status,cmdline,exe,cwd,environ}` |
| 3 | **FD table** | What does this process hold open right now? | `/proc/PID/fd`, `/proc/PID/fdinfo` |
| 4 | **cgroup / namespace boundary** | What may this process *see*, and how much may it *consume*? | `/sys/fs/cgroup/**`, `/proc/PID/ns`, `/proc/PID/cgroup` |

From these falls the one repeatable move the learner practises 40+ times across
the path:

> **symptom → resource class → the file that proves it**

No claim about a Linux box is accepted unless it can be traced to a file the
learner can `cat`.

### The daily loop

Every day executes the same seven steps. The loop, not the topic list, is the
product.

1. **Name the truth** — which of the four is today's subject.
2. **Read the raw file first** — `cat` the kernel file and decode its fields
   before any tool is allowed to touch it.
3. **Derive the tool** — run the friendly tool and map each column back to the
   bytes just read.
4. **Break it** — run `break.sh`. It produces a symptom and no explanation.
5. **Write the chain before fixing** — the diagnosis goes into `journal.md`
   as a numbered chain of evidence *before* any repair is attempted. This
   forces the model to do the work instead of trial-and-error.
6. **Fix and prove** — repair, then re-read the same file to demonstrate the
   change at the source of truth.
7. **Strip the toolbox** — repeat the diagnosis inside the busybox-only Alpine
   container, where the tool used in step 3 does not exist.

Step 7 is the signature move of this path and the mechanism by which the
learning transfers to the learner's actual job.

### Why the alternatives were rejected

**A USE-method / resource-saturation spine** (order by CPU, memory, disk,
network) is excellent for "the box is slow" and structurally incapable of
housing the filesystem model, the permission model, boot, or service
management. It is a diagnostic checklist, not a curriculum.

**An LPIC-1 / LFCS objective sweep** guarantees coverage and directly rebuilds
the learner's decayed certification scaffolding, but objective lists teach
*facts* rather than a *method*, and they spend real hours on printing, X11, and
SysV init. A learner finishing that path can answer exam questions and will
still guess under a live incident.

The resolution: **the `/proc` doctrine supplies the spine; the certification
objectives supply an audit.** `COVERAGE.md` maps every LPIC-1 and LFCS objective
to the day that covers it, with an explicit *"deliberately skipped, because…"*
list. The learner gets a method plus documented proof that nothing systematic
was missed.

### The mistakes that waste 80% of beginners' time

Reproduced in `STRATEGY.md` and referenced by the per-day *Anti-patterns*
sections:

1. **Memorising flags instead of the model.** Flags are one `--help` away; the
   model is not. Time spent on `tar` mnemonics is time not spent understanding
   a file descriptor.
2. **Trusting the summary tool.** Believing the `free` "free" column, or that
   load average measures CPU. Both are folk wisdom, both are wrong, and both
   produce bad incident calls under pressure.
3. **Learning tools that do not exist on real servers.** Fluency in `htop`,
   `ncdu`, and `bat` converts to paralysis on a busybox container.
4. **Practising on a healthy box.** Nothing is learned from a working system.
   Every hour in this path begins from a broken one.
5. **Reading instead of verifying.** Never running `strace` even once leaves the
   syscall boundary permanently abstract.
6. **Deferring the permission model** until setuid, capabilities, or the
   directory execute bit bites — and then guessing with `chmod 777`.
7. **Learning vim from a tutorial** rather than by disabling the arrow keys and
   editing real configuration under time pressure.

### Neovim's bounded role

Neovim receives ~3 h of the 21, split deliberately:

- **1 h on Day 1**, placed first, covering only the modal model, motions,
  operators, text objects, search, and undo.
- **1.5 h on Day 7**, the operator payload: `:g//`, macros and registers,
  buffers and `:argdo`, quickfix populated from `grep`, `:%!` filtering through
  a shell command, marks, diff mode, and `:w !sudo tee %`.
- The remaining ~0.5 h is distributed as short in-lab prompts.

The multiplier is structural rather than temporal: **from Day 2 onward every
lab file is edited in neovim with arrow keys disabled**, which converts 3 h of
instruction into roughly 15 h of forced practice at no cost to the Linux budget.
A minimal `init.lua` — short enough to paste onto any server, with no plugin
manager and no LSP — ships on Day 7. Replacing VSCode is explicitly a non-goal.

## Curriculum

Seven days, 3 h each. Every day follows the daily loop, ends with a `journal.md`
entry, and injects its incident through `labs/dayNN/break.sh`.

### Day 1 — The mount tree, and everything is a file (2 h Linux + 1 h nvim)

- **Linux (2 h):** the FHS as a set of promises about where things live; the VFS
  and why `/proc` and `/sys` are filesystems rather than directories; inodes
  versus names; hard and symbolic links; `/proc/mounts` and
  `/proc/PID/mountinfo`; `findmnt`; bind mounts; what an image layer actually is
  (overlayfs `lowerdir`/`upperdir`/`merged`); `df` versus `du` and why they
  measure different things.
- **Incident:** filesystem at 100 %, `df` reports full while `du` accounts for
  40 %. Resolution runs through `/proc/*/fd` to an unlinked-but-still-open file
  held by a running process.
- **nvim (1 h):** the modal model as a grammar (operator + motion + text
  object); `hjkl` with arrow keys disabled; `w b e 0 $ gg G`; `dw ci" ca( yy p`;
  `/` and `n`; `u` and `Ctrl-r`; `:w`, `:q`, `:wq`, `:q!`. Exit criterion: the
  learner edits `/etc/hosts` in the workstation container without reaching for
  an arrow key.

### Day 2 — The process table and the syscall boundary (3 h)

- `fork`/`exec`/`wait` and what each actually does to the process table; PID 1
  and the reaping contract; process states `R S D Z T` and what each means for
  the load average; decoding `/proc/PID/stat` field by field, and
  `/proc/PID/{status,cmdline,exe,cwd,environ}`; signals, default dispositions,
  and which ones cannot be caught; process groups, sessions, `nohup`, `setsid`;
  first `strace` on a live process.
- **Incident:** the three reproducible members of the "won't die" family — a
  process that traps and ignores `SIGTERM`, a `T`-stopped process that cannot
  act on any signal until `SIGCONT`, and zombies accumulating under a `sh -c`
  PID 1. Uninterruptible `D` state is taught in the content as the fourth
  member, with its real causes (NFS, a failing EBS volume, a device timeout)
  and why no signal can touch it; it is not reproduced in the lab, because it
  cannot be induced reliably or safely under Docker Desktop on macOS.
- **AWS tie-in:** why an ECS task built with a shell-form `ENTRYPOINT` never
  delivers `SIGTERM` to the application, why the task then takes the full
  `stopTimeout` to die, and the two correct fixes (exec form, or an init
  process).

### Day 3 — The file descriptor table (3 h)

- Descriptors 0, 1, 2; redirection and pipes understood as descriptor surgery
  rather than syntax; `/proc/PID/fd` and `/proc/PID/fdinfo`, including file
  offset and flags; sockets and pipes as descriptors; `lsof` derived from the
  above; `tee`, here-documents, process substitution; the triage trio `grep`,
  `sed`, `awk` with the specific subset an operator actually needs; `find -exec`
  versus `xargs` and when each is correct; exit codes, `$?`, pipelines, and
  `set -euo pipefail`.
- **Incident:** 4 GB of application logs. Locate the failing request; identify
  which process still holds the rotated file open; explain why log rotation
  stopped reclaiming space.
- **Strip the toolbox:** repeat the entire triage in the Alpine container using
  only `cat`, `/proc`, and shell builtins.

### Day 4 — Resources and the cgroup boundary (3 h)

- Load average and what it actually counts (runnable plus uninterruptible),
  `/proc/loadavg`, `/proc/stat`, and PSI via `/proc/pressure/*`; memory decoded
  honestly — RSS versus shared versus page cache versus `MemAvailable` — from
  `/proc/meminfo` and `/proc/PID/status`; the OOM killer and `oom_score_adj`;
  the cgroup v2 tree; `memory.max`, `memory.current`, `memory.events`,
  `cpu.max`, `cpu.stat`; disk I/O basics via `/proc/diskstats`; the USE method
  as the resulting checklist.
- **Incident (two-part):** a container OOM-killed at a 512 M limit while `free`
  inside the container reports abundant memory; and a container throttled on CPU
  while showing a low load average.
- **AWS tie-in:** both symptoms map directly to the two most common ECS task
  definition mistakes — `memory` versus `memoryReservation`, and CPU units
  translating to a `cpu.max` quota.

### Day 5 — Identity, permission, and service management (3 h)

- uid/gid/euid and how they are set; mode bits; setuid, setgid, and the sticky
  bit; the directory execute bit as the most common invisible denial; umask at
  creation time; `/etc/passwd`, `/etc/shadow`, `/etc/group`; `sudo` and its
  audit trail; Linux capabilities (why an unprivileged `ping` works) and
  `/proc/PID/status` capability sets; ACLs, briefly.
- systemd: unit file anatomy, dependency ordering versus `After=`, the
  `systemctl` verb set, `journalctl` and its filters, targets and boot,
  timers versus cron.
- **The contrast that matters:** what replaces each systemd responsibility
  inside a container — the application *is* PID 1, there is no journal, stdout
  is the log, and restart policy lives in the orchestrator.
- **Incident:** a file at mode `0777` that still yields permission denied, and a
  systemd unit that fails to start.
- **Environment note:** this is the day requiring the `sysd` container
  (`--privileged`, `--cgroupns=host`) with the documented Colima/Lima fallback.

### Day 6 — The network, seen from the box (3 h)

- Interfaces and addresses with `ip` (and why `ifconfig` output misleads on
  modern kernels); the routing table as a decision procedure; DNS resolution
  order through `/etc/nsswitch.conf` and `/etc/resolv.conf`, and the container
  `ndots` trap; sockets and listening state via `ss` and `/proc/net/tcp`; TCP
  connection states, ephemeral port exhaustion, and `TIME_WAIT`; `curl -v` read
  as a protocol trace; `openssl s_client` for certificate and TLS problems; MTU
  and path issues; read-level literacy in `nftables`/`iptables`; `tcpdump` for
  the two or three captures an operator actually runs.
- **Incident:** a connectivity ladder across the five-container fleet. "The
  service is unreachable" resolves to exactly one of DNS, route, firewall,
  listener, or application — and each rung has a command *and* a proving file.

### Day 7 — Synthesis (1.5 h nvim + 1.5 h gauntlet)

- **nvim operator payload (1.5 h):** `:g//` and `:v//` as the highest-leverage
  ex command; registers and macros; buffers, the argument list, and `:argdo`;
  quickfix populated from `grep`/`make` and traversed with `:cn`; `:%!`
  filtering a buffer through a shell command; marks; `:diffthis`;
  `:w !sudo tee %`; and a minimal plugin-free `init.lua`.
- **The gauntlet (1.5 h):** five unseen injected incidents on the fleet, timed,
  no hints, spanning all four truths. Each requires a written diagnosis chain
  before the fix.
- **Coverage audit:** the learner walks `COVERAGE.md`, confirms the LPIC-1 and
  LFCS objective mapping, and reads the deliberate-skip list with its reasoning.

### Lab fleet

One `docker compose` project, all images arm64-native.

| Service | Image | Role |
|---|---|---|
| `ws` | `ubuntu:24.04` plus a full toolbox, `cap_add: SYS_PTRACE` | Primary shell; the only place `strace` works |
| `slim` | `alpine:3.20`, busybox only | The strip-the-toolbox target |
| `app` | small static HTTP service, **memory and CPU limits applied** | Days 2, 4, 6 |
| `db` | `postgres:16-alpine` | Real sockets, descriptors, and connections |
| `proxy` | `nginx:alpine` | Day 6's connectivity ladder |
| `sysd` | systemd-enabled Ubuntu, `privileged`, `cgroupns: host` | Day 5 only; Lima fallback documented |

Each `labs/dayNN/` ships `README.md` (goal and success signal), `break.sh`
(injects the incident, no explanation), `verify.sh` (an objective pass/fail on
the repair, so the learner is never left guessing whether the fix was real),
`SOLUTION.md` (the full chain of evidence, not merely the fix), and
`teardown.md`. Day 7 substitutes `gauntlet.sh` for `break.sh` and a
spoiler-gated `ANSWERS.md` for `SOLUTION.md`.

## Directory Layout

```
linux_ops_mastery/
├── README.md                       # quickstart, 7-day map, how to run the fleet, daily loop
├── STRATEGY.md                     # the /proc doctrine, the daily loop, the 7 wasted-time mistakes
├── COVERAGE.md                     # LPIC-1 + LFCS objective → day matrix, and deliberate skips
├── journal.md                      # learner's diagnosis chains (template + Day 1 example)
├── content/
│   ├── GLOSSARY.md                 # plain-English terms: inode, fd, cgroup, PSI, ndots, …
│   ├── day01.md                    # mount tree + nvim survival
│   ├── day02.md                    # process table + syscall boundary
│   ├── day03.md                    # fd table + shell as operator language
│   ├── day04.md                    # resources + cgroup boundary
│   ├── day05.md                    # identity, permission, service management
│   ├── day06.md                    # network from the box
│   ├── day07.md                    # nvim operator payload + gauntlet
│   └── primers/
│       ├── proc-field-reference.md # decode /proc/PID/stat, /proc/meminfo, /proc/net/tcp fields
│       └── nvim-cheatsheet.md      # the grammar, not a command dump
└── labs/
    ├── fleet/
    │   ├── docker-compose.yml      # ws, slim, app, db, proxy
    │   ├── docker-compose.sysd.yml # day 5 overlay: systemd container
    │   ├── Dockerfile.ws           # ubuntu + toolbox
    │   ├── app/                    # tiny HTTP service + Dockerfile
    │   ├── README.md               # bring-up, arm64 notes, SYS_PTRACE, Lima fallback
    │   └── seed/                   # log fixtures, sample configs used by break.sh
    ├── lib/common.sh                # shared helpers: compose wrapper, symptom(), require_fleet
    ├── day01/ … day07/             # README.md, break.sh, verify.sh, SOLUTION.md, teardown.md
    └── verify-teardown.sh          # confirms no containers, volumes, or networks remain
```

## Content Day Skeleton

Every `content/dayNN.md` uses this structure:

```markdown
# Day N — <Title>

**Truth of the day:** <mount tree | process table | fd table | cgroup boundary>
**Budget:** <X h> — <breakdown>

## Why this matters
<One short paragraph, concrete: the failure this day makes tractable.>

## Read the file first
<The raw kernel file(s), field by field. No tools yet.>

## Derive the tool
<The friendly tool, with each column mapped back to the bytes above.>

## Core concepts
<The day's body.>

## Lab
See `labs/dayNN/`. The goal: <one line>. Success signal: <one line>.
Run `break.sh`, write the chain in `journal.md` **before** fixing.

## Strip the toolbox
<The same diagnosis, redone in `slim` without the tool.>

## Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
2. …

## Anti-patterns / Common mistakes
- <bullet, tied to a numbered mistake in STRATEGY.md>
- <bullet>

## Where this shows up in AWS
<Two or three lines connecting the day to ECS/EC2 reality.>

## Teardown
<Checklist leaving zero running containers and no stray volumes.>
```

## Out of Scope

Named explicitly so the plan does not drift into them:

- Replacing VSCode with neovim; plugin managers, LSP, completion, Treesitter.
- Kernel module development, kernel compilation, eBPF authoring.
- Configuration management (Ansible, Puppet, Salt) and infrastructure as code.
- Kubernetes. Container internals appear only where they explain a Linux truth.
- Distribution packaging internals beyond reading what a package installed.
- Printing, X11/Wayland, desktop, SysV init, GRUB internals — each listed in
  `COVERAGE.md` as a deliberate skip with its reason.

# Linux Foundations Track Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an 8-chapter, read-and-try Linux foundations track (`content/foundations/`) that rebuilds the mental model the main course assumes, and wire it into the course.

**Architecture:** Plain Markdown chapters in dependency order (00 → 07), each with a fixed six-section anatomy, checked by one structural lint script. An index README maps chapters to days; each day file and the course README get a one-line pointer. Chapter "See it yourself" commands are read-only and are verified live in the existing `ws` container.

**Tech Stack:** Markdown; bash (macOS bash 3.2-compatible) for the lint; Docker Compose fleet `linuxops` (`ws` = Ubuntu 24.04, runs as root, has procps psmisc lsof strace iproute2 curl jq acl sysstat tree; `SYS_PTRACE` cap; `/labs` mounted read-only).

**Spec:** `linux_ops_mastery/docs/superpowers/specs/2026-10-08-linux-foundations-design.md`

## Global Constraints

- All paths below are relative to `linux_ops_mastery/` unless they start with `/`.
- Chapter H2 headings, exactly and in this order: `## What you'll be able to explain`, `## The mental model`, `## How it connects`, `## See it yourself`, `## Words you'll meet in the course`, `## Self-check`.
- 250–400 lines per chapter; `00-big-picture.md` may be 150–400.
- "See it yourself": 4–8 fenced ```` ```bash ```` blocks, each read-only, each followed by a line beginning `**What to look for:**`.
- "Self-check": 5–6 numbered questions; answers inside one `<details><summary>Answers</summary>` … `</details>` block.
- Define every term at first use in plain English. A chapter may only *use* terms defined in itself or an earlier chapter; a later concept may be *mentioned by name* only with a pointer like "(chapter 04 explains this)".
- Simplified but never wrong. Where the day goes deeper, write "Day N goes further on this"; never contradict a day file.
- Analogies only with a following one-line `*Where the analogy breaks:*` note.
- English; same Markdown style as `content/dayNN.md` (prose paragraphs, ~74-col wrapping, ASCII diagrams in plain ```` ``` ```` fences).
- No changes to the technical content of `content/dayNN.md` or `GLOSSARY.md`; only the one pointer line per day.
- Host-side checks use `/usr/bin/grep` (grep is an aliased shim on this machine).
- Git: commit only on local branch `tmp/linux-foundations`; never push; never commit on `master`.

## Review Focus

1. **Wrong-but-plausible simplifications** — a reviewer reading a chapter beside its day file(s) must find zero contradictions (e.g. "SIGKILL can be caught", "a deleted file's space is freed immediately", "load average is CPU usage"). Pinned by each chapter task's "Accuracy pins" step and Task 11.
2. **Forward references** — a term used before the chapter that defines it leaves the learner exactly where they started. Pinned by Task 11 Step 2.
3. **Try-it output that doesn't match reality in `ws`** — e.g. a described field that this kernel/container doesn't show, or a command that needs a tool `ws` lacks. Pinned by Task 10.
4. **Commands that mutate the fleet** — a "see it yourself" step that kills, writes, or reconfigures would break later labs. Pinned by the lint's mutation-word check plus Task 10 review.
5. **Broken relative links** between chapters, index, glossary, and days. Pinned by the lint's link check, run in every chapter task (Step C) and in Task 12.

---

### Task 1: Structural lint script

**Files:**
- Create: `docs/superpowers/checks/foundations-lint.sh`

**Interfaces:**
- Produces: `bash docs/superpowers/checks/foundations-lint.sh <file>...` — exits 0 when every file passes, 1 otherwise; prints one `FAIL <file>: <reason>` line per problem and `OK <file>` per clean file. With `--links-only` as the first argument, it only checks relative links (used for README/day files).

- [ ] **Step 1: Write a deliberately bad fixture and a good fixture in the scratchpad**

```bash
S=/private/tmp/claude-504/-Users-hunghd-git-clone-learning-path/163269fe-0ea3-414b-96b4-26dfc64b35ac/scratchpad/lint
mkdir -p "$S"
printf '# Bad\n\n## The mental model\n\nSee [x](missing.md).\n\n```bash\nkill -9 1\n```\n' > "$S/bad.md"
{
  echo '# 09 — Good'; echo
  echo "## What you'll be able to explain"; echo
  echo '## The mental model'; echo
  echo '## How it connects'; echo
  echo '## See it yourself'; echo
  for i in 1 2 3 4; do printf '```bash\ncat /proc/self/status\n```\n**What to look for:** x\n\n'; done
  echo "## Words you'll meet in the course"; echo
  echo '## Self-check'; echo
  for i in 1 2 3 4 5; do echo "$i. Q?"; done
  echo; echo '<details><summary>Answers</summary>'; echo; echo '1. A'; echo; echo '</details>'
  for i in $(seq 1 240); do echo 'filler line'; done
} > "$S/09-good.md"
```

- [ ] **Step 2: Write the lint script**

```bash
#!/usr/bin/env bash
# Structural lint for content/foundations chapters. See the plan
# docs/superpowers/plans/2026-10-08-linux-foundations-plan.md, Task 1.
set -u
G=/usr/bin/grep
links_only=0
[ "${1:-}" = "--links-only" ] && { links_only=1; shift; }
rc=0

fail() { echo "FAIL $1: $2"; bad=1; }

check_links() {
  f=$1; dir=$(dirname "$f")
  # ](target) pairs; skip http(s), mailto, pure anchors
  $G -oE '\]\([^)]+\)' "$f" | sed -E 's/^\]\(//; s/\)$//' | while read -r t; do
    case "$t" in http*|mailto:*|\#*) continue ;; esac
    p=${t%%#*}
    [ -e "$dir/$p" ] || echo "FAIL $f: broken link -> $t"
  done
}

section() { # print body of H2 section $2 in file $1
  awk -v h="## $2" '$0==h{p=1;next} /^## /{p=0} p' "$1"
}

for f in "$@"; do
  bad=0
  [ -f "$f" ] || { echo "FAIL $f: missing"; rc=1; continue; }
  out=$(check_links "$f"); [ -n "$out" ] && { echo "$out"; bad=1; }
  if [ $links_only -eq 0 ]; then
    want="## What you'll be able to explain|## The mental model|## How it connects|## See it yourself|## Words you'll meet in the course|## Self-check"
    got=$($G -E '^## ' "$f" | paste -sd'|' -)
    [ "$got" = "$want" ] || fail "$f" "H2 headings/order wrong: $got"
    n=$(wc -l < "$f" | tr -d ' ')
    min=250; case "$(basename "$f")" in 00-*) min=150 ;; esac
    { [ "$n" -ge $min ] && [ "$n" -le 400 ]; } || fail "$f" "length $n not in $min-400"
    tries=$(section "$f" "See it yourself" | $G -c '^```bash')
    { [ "$tries" -ge 4 ] && [ "$tries" -le 8 ]; } || fail "$f" "$tries bash blocks in See it yourself (want 4-8)"
    looks=$(section "$f" "See it yourself" | $G -c '^\*\*What to look for:\*\*')
    [ "$looks" -ge "$tries" ] || fail "$f" "$looks 'What to look for' lines for $tries blocks"
    if section "$f" "See it yourself" | awk '/^```bash/{p=1;next} /^```/{p=0} p' \
        | $G -qE '(^|[;&| ])(kill -(s |[0-9]|[A-Z])|kill [0-9%$]|pkill|killall|rm|mv|truncate|chmod|chown|systemctl (start|stop|restart)|nft|iptables|ip (link|addr|route) (add|del|set)|tee|dd)( |$)|>[^&]'; then
      fail "$f" "See it yourself contains a mutating command"
    fi
    qs=$(section "$f" "Self-check" | awk '/<details>/{exit} {print}' | $G -cE '^[0-9]+\. ')
    { [ "$qs" -ge 5 ] && [ "$qs" -le 6 ]; } || fail "$f" "$qs self-check questions (want 5-6)"
    section "$f" "Self-check" | $G -q '<details><summary>Answers</summary>' || fail "$f" "no <details><summary>Answers</summary>"
    $G -qE 'TODO|TBD|FIXME' "$f" && fail "$f" "placeholder text"
  fi
  [ $bad -eq 0 ] && echo "OK $f" || rc=1
done
exit $rc
```

Note the mutation regex allows `2>/dev/null` and `>&` forms only via the `>[^&]` rule — if a chapter needs `2>/dev/null`, write it as `2>&-`-free alternatives or drop the redirection; reviewers prefer no redirection in try-it blocks anyway.

- [ ] **Step 3: Run against the fixtures**

Run: `bash docs/superpowers/checks/foundations-lint.sh "$S/bad.md" "$S/09-good.md"; echo rc=$?`
Expected: several `FAIL …/bad.md:` lines (headings, length, bash blocks, mutating command, broken link `missing.md`, self-check), then `OK …/09-good.md`, `rc=1`.

Run: `bash docs/superpowers/checks/foundations-lint.sh "$S/09-good.md"; echo rc=$?`
Expected: `OK …/09-good.md`, `rc=0`.

- [ ] **Step 4: Commit**

```bash
git add linux_ops_mastery/docs/superpowers/checks/foundations-lint.sh
git commit -m "foundations: structural lint script

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Chapter tasks (Tasks 2–9) — shared procedure

Every chapter task follows these steps. The task-specific block gives the file, source day files, must-cover list, required diagrams, and accuracy pins.

- [ ] **Step A: Read inputs** — the spec; the Global Constraints above; every earlier chapter already written in `content/foundations/` (to reuse its terms and not redefine them); the listed day file(s) "Core concepts" sections and `content/GLOSSARY.md`.
- [ ] **Step B: Write the chapter** — all six sections, covering every must-cover item, including every required diagram, honoring every accuracy pin. "Words you'll meet in the course" lists 6–12 terms as `- **term** — Day N, *Section name* ([glossary](../GLOSSARY.md))`, using real section names from the day files (link the glossary only if the term has an entry there; check with `/usr/bin/grep -n '^- \*\*term' content/GLOSSARY.md`).
- [ ] **Step C: Lint** — Run: `bash docs/superpowers/checks/foundations-lint.sh content/foundations/<file>` → Expected: `OK content/foundations/<file>`. Fix and re-run until it passes.
- [ ] **Step D: Accuracy pins** — for each pin, `/usr/bin/grep -n` the chapter for the statement and confirm it is present and phrased correctly; then confirm no sentence contradicts it.
- [ ] **Step E: Commit** — `git add linux_ops_mastery/content/foundations/<file> && git commit -m "foundations: <file>" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"`

Chapters must be written in order 00 → 07 (each depends on the earlier ones' vocabulary).

### Task 2: `00-big-picture.md` — The big picture

**Files:** Create `content/foundations/00-big-picture.md` (150–400 lines)
**Sources:** `STRATEGY.md` ("The four truths", "The move"); `content/day01.md` "Why this matters".
**Interfaces:** Produces the base vocabulary every later chapter uses: *kernel, user space, kernel space, system call, program, process (named only; ch02 defines fully), file, `/proc`, `/sys`, container*.

**Must cover:**
- Layers: hardware → kernel → system calls → user-space programs (shell, `ps`, nginx).
- Why programs cannot touch hardware directly; a system call as "asking the kernel"; `open`, `read`, `write`, `fork`, `exec` named as examples.
- "Everything is a file" — what it means and its limits (a socket is not on disk).
- `/proc` and `/sys` are not stored on disk: the kernel generates their contents when you read them. `/proc/self`.
- The course's four truths (mount tree, process table, FD table, cgroup/namespace boundary) previewed in one paragraph each, plus "the move" (symptom → resource class → file that proves it), with a pointer to the chapter covering each.
- A container is ordinary processes on the host's single kernel, with walls (namespaces) and limits (cgroups) — names only; ch06 explains.

**Required diagrams:** the layer stack with the system-call boundary; a mini map "four truths → chapter → day".

**Try-it ideas:** `uname -r`; `cat /proc/version`; `ls /proc | head`; `cat /proc/self/status | head`; `cat /proc/uptime` twice; `ls /sys`.

**Accuracy pins:**
- Containers share the host kernel (in Docker Desktop on Mac, that kernel is the Linux VM's, not macOS's).
- `/proc` content is generated on read; file sizes there show as 0.
- `ps`, `free`, `df` read `/proc` (and `df` also calls `statfs`); `ss` uses netlink — consistent with `STRATEGY.md`.

### Task 3: `01-files-inodes.md` — Files, names, and inodes

**Files:** Create `content/foundations/01-files-inodes.md`
**Sources:** `content/day01.md` (all of "Read the file first" and "Core concepts").
**Interfaces:** Consumes ch00 vocabulary. Produces *path, directory, directory entry, inode, inode number, data blocks, link count, hard link, symlink, filesystem, mount, mount point, mount tree, tmpfs, overlay (lower/upper/merged)*.

**Must cover:**
- One tree from `/`; absolute vs relative path; a directory is a file listing name → inode number.
- Inode holds metadata (type, mode, owner, size, timestamps, link count, block pointers) but **not the name**.
- Hard link = another name for the same inode; symlink = a small file containing a path; `stat` output walked field by field.
- When data is freed: link count 0 **and** no process still has it open (mention "open" in plain words; chapter 04 explains descriptors). This is the root of Day 1's incident.
- Filesystem = a format plus storage that a kernel driver understands; types seen in the course: ext4, tmpfs, overlay, proc, sysfs.
- Mounting attaches a filesystem at a directory; the mount tree; what you see at a path is the top-most mount there; `/proc/mounts` fields 1–4 in plain words.
- tmpfs lives in memory; overlay = read-only lower layers + writable upper layer = merged view (why container images are layered).
- `df` (filesystem's own accounting) vs `du` (walking names) — why they can disagree; "Day 1 goes further".

**Required diagrams:** `name → (directory entry) → inode → data blocks`; two names → one inode; overlay lower/upper/merged stack.

**Try-it ideas:** `stat /etc/hostname`; `ls -li /etc | head`; `cat /proc/mounts`; `findmnt` (if present) or `cat /proc/self/mountinfo | head`; `df -h /` and `df -h /labs`; `ls -l /proc/self/exe`.

**Accuracy pins:**
- Inode does not contain the filename.
- Deleting a name does not free space while a process holds the file open.
- `/` in `ws` is an overlay mount; `/labs` is a bind mount, read-only.
- Hard links cannot cross filesystems; symlinks can.

### Task 4: `02-processes.md` — Processes

**Files:** Create `content/foundations/02-processes.md`
**Sources:** `content/day02.md` "Core concepts"; `content/primers/proc-field-reference.md`.
**Interfaces:** Consumes ch00–01. Produces *program, process, PID, PPID, fork, exec, exit status (named; ch04 details), wait/reap, zombie, orphan, PID 1, init, process state R/S/D/T/Z, environment, working directory, `/proc/PID/`*.

**Must cover:**
- Program (file on disk) vs process (running instance: memory, registers, open files, credentials).
- `fork` copies the process; `exec` replaces the program inside it; why the shell does fork-then-exec for every command.
- Parent/child tree; `exit` → process becomes a zombie until the parent `wait`s (reaps) it; orphans are re-parented to PID 1 (or a subreaper).
- PID 1's special duties: reaps orphans; in a container, PID 1 gets no default signal actions, so it ignores SIGTERM unless it installs a handler (signal details in ch03 — mention by name only).
- States R, S, D, T, Z in plain words; why D can't be interrupted.
- What lives in `/proc/PID/`: `status`, `cmdline`, `exe`, `cwd`, `environ`, `fd/` (fd named, ch04 explains).

**Required diagrams:** fork → exec timeline (shell running `ls`); parent/child/zombie lifecycle.

**Try-it ideas:** `echo $$; ps -o pid,ppid,stat,cmd`; `ps -ef --forest` or `pstree -p`; `cat /proc/$$/status | head -12`; `ls -l /proc/$$/cwd /proc/$$/exe`; `tr '\0' '\n' < /proc/$$/environ | head`; `cat /proc/1/cmdline | tr '\0' ' '`.

**Accuracy pins:**
- A zombie holds no memory, only its process-table entry and exit status; it cannot be killed, only reaped.
- Load average on Linux counts R and D tasks (Day 4 goes further).
- In a PID namespace the container's first process is PID 1 and has the PID-1 signal rule above — consistent with Day 2's ENTRYPOINT trap section.

### Task 5: `03-signals-terminals.md` — Signals and terminals

**Files:** Create `content/foundations/03-signals-terminals.md`
**Sources:** `content/day02.md` (signals, "won't die" family, stopped, process groups/sessions); `content/day09.md` "The underlying truth" and "Breaking it down".
**Interfaces:** Consumes ch00–02. Produces *signal, default action, handler (catch), ignore, block/mask, pending, SIGTERM/SIGKILL/SIGINT/SIGHUP/SIGSTOP/SIGTSTP/SIGCONT/SIGCHLD, process group, session, controlling terminal, foreground/background job, trap*.

**Must cover:**
- A signal is a small numbered notification the kernel delivers to a process; three dispositions: default, ignore, catch.
- Block (mask) vs ignore: blocked signals wait as pending.
- Operator set with numbers: HUP 1, INT 2, QUIT 3, KILL 9, TERM 15, STOP 19, TSTP 20, CONT 18, CHLD 17 (x86/arm64 Linux numbering).
- KILL and STOP cannot be caught, ignored, or blocked; TERM can, which is why "kill" sometimes "doesn't work".
- Stopped (T) ≠ dead; a stopped process ignores TERM until CONT (as Day 2's "won't die" shows).
- Process group, session, controlling terminal; Ctrl-C sends SIGINT to the whole **foreground process group**; Ctrl-Z sends SIGTSTP; closing a terminal sends SIGHUP.
- Shell `trap` as the shell's way to catch signals (Day 9 goes further on traps and subshells).
- Reading `SigBlk`, `SigIgn`, `SigCgt` in `/proc/PID/status` as hex bitmasks (one worked decode).

**Required diagrams:** terminal → session → process groups → processes, showing who receives Ctrl-C; signal delivery decision (blocked? → pending; ignored? → drop; caught? → handler; else default).

**Try-it ideas:** `kill -l`; `grep -E 'Sig(Blk|Ign|Cgt)' /proc/$$/status`; `ps -o pid,pgid,sid,tty,stat,cmd`; `cat /proc/1/status | grep Sig`; `trap -p`. (Read-only — do not send signals in try-it blocks.)

**Accuracy pins:**
- SIGKILL and SIGSTOP cannot be caught, blocked, or ignored.
- Ctrl-C targets the foreground process group, not just one process.
- A process in D state does not act on SIGKILL until the uninterruptible wait ends.

### Task 6: `04-fds-io.md` — File descriptors and I/O

**Files:** Create `content/foundations/04-fds-io.md`
**Sources:** `content/day03.md` "Core concepts"; `content/day08.md` "The underlying truth"; `content/day09.md` (subshells inherit fds); `content/day10.md` "The underlying truth" (for the arguments-vs-stdin distinction, one paragraph).
**Interfaces:** Consumes ch00–03. Produces *file descriptor, fd table, open file description, file offset, stdin/stdout/stderr (0/1/2), redirection, `dup`, pipe, inheritance, close-on-exec, exit status, `$?`, pipeline status, `pipefail`, argv vs stdin*.

**Must cover:**
- Three layers: per-process fd table (small integers) → open file description (offset, access mode, flags; shared after `fork`/`dup`) → inode (ch01).
- 0/1/2 are a convention the shell sets up, not a kernel rule.
- Redirection as fd rewiring done by the shell between fork and exec (`>`, `>>`, `2>&1`, `<`); why `2>&1 >file` differs from `>file 2>&1`.
- Pipes: a kernel buffer with a write fd and a read fd; both sides of `a | b` run at the same time.
- Inheritance: children get copies of the parent's fds across fork and exec, unless close-on-exec.
- `/proc/PID/fd/` entries as symlinks; "(deleted)" target — closes the loop with ch01 and Day 1's incident.
- Exit status 0–255; 0 = success; 128+N = killed by signal N; `$?` is the **last** command's status; a pipeline's status is its last command's unless `set -o pipefail` (Day 8 goes further).
- Arguments (argv, fixed at exec) vs stdin (a stream on fd 0) — one paragraph.

**Required diagrams:** the three-layer fd picture for two processes sharing one open file description after fork; `cmd >out 2>&1` before/after fd table; `a | b` with the pipe in the kernel.

**Try-it ideas:** `ls -l /proc/$$/fd`; `ls -l /proc/self/fd` (note it shows `ls`'s own fds); `cat /proc/$$/fdinfo/0`; `ls -l /proc/self/fd | cat` (fd 1 is a pipe); `false; echo $?`; `false | true; echo $?`; `sleep 1 | ls -l /proc/self/fd` (note pipe on fd 0); `lsof -p $$`.

**Accuracy pins:**
- `fork` shares open file descriptions (and thus the offset) between parent and child; it does not copy the offset.
- Without `pipefail`, `false | true` exits 0.
- A terminated-by-signal process reports 128+N in the shell.

### Task 7: `05-users-permissions-services.md` — Users, permissions, and services

**Files:** Create `content/foundations/05-users-permissions-services.md`
**Sources:** `content/day05.md` "Core concepts".
**Interfaces:** Consumes ch00–04. Produces *user, group, UID, GID, root, real vs effective UID, mode bits rwx, directory x/r/w semantics, setuid, setgid, sticky bit, umask, capability, `sudo`, init system, systemd, unit, service, `systemctl`, `journalctl`*.

**Must cover:**
- Users and groups are numbers; names come from `/etc/passwd` and `/etc/group`.
- Every process carries credentials (real/effective UID/GID, supplementary groups) — the kernel checks those, not the user's name.
- Mode bits for owner/group/other; on a file r/w/x; on a directory r = list names, w = add/remove names (needs x too), x = pass through; why `0777` on a file is useless if a parent directory lacks x (Day 5's incident in miniature).
- Permission check order: owner match → group match → other; first match wins.
- setuid on an executable runs with the file owner's effective UID (`passwd`); setgid dir makes new files inherit the group; sticky dir (`/tmp`) lets only owners delete their names.
- umask removes bits at creation time only.
- root = UID 0 bypasses most checks; capabilities split root's power (`CAP_NET_BIND_SERVICE`, `CAP_SYS_PTRACE` — `ws` has the latter).
- What an init system does (PID 1, starts and supervises services, reaps); systemd units (`[Unit]`, `[Service]`, `[Install]`), `systemctl status/start/stop/enable`, `journalctl -u` — Day 5 goes further; note `ws` does not run systemd (the `sysd` container does).

**Required diagrams:** permission-check flow; path traversal needing x on every directory from `/` to the file.

**Try-it ideas:** `id`; `ls -ld / /tmp /etc /root`; `stat -c '%A %a %U %G %n' /etc/passwd /usr/bin/passwd /tmp`; `umask`; `grep -E '^(Uid|Gid|Groups|Cap(Eff|Prm))' /proc/$$/status`; `capsh --decode=$(awk '/CapEff/{print $2}' /proc/$$/status)` (if `capsh` present; otherwise omit); `getent passwd root`.

**Accuracy pins:**
- Directory `w` without `x` does not let you create or delete names.
- The kernel ignores setuid on scripts (shebang files) on Linux.
- `umask` does not change existing files.

### Task 8: `06-resources-boundaries.md` — Resources and boundaries

**Files:** Create `content/foundations/06-resources-boundaries.md`
**Sources:** `content/day04.md` "Core concepts" (all subsections); `content/day06.md` intro on the network namespace.
**Interfaces:** Consumes ch00–05. Produces *virtual memory, RSS, page cache, MemAvailable, swap, OOM killer, CPU scheduler, run queue, load average, cgroup (v2), `memory.max`, `cpu.max`, throttling, PSI (named), namespace (pid, net, mnt, uts, ipc, user, cgroup), `/proc/PID/ns`*.

**Must cover:**
- Virtual memory: each process sees its own address space; RSS = how much is actually in RAM now; shared pages counted in several RSS values.
- Page cache: free RAM used to cache file data; reclaimable, which is why "free" is low but `MemAvailable` is what matters.
- OOM killer: what triggers it (global vs cgroup limit), `oom_score`/`oom_score_adj` named.
- CPU: scheduler runs runnable tasks; load average = average queue length of R + D tasks, not a percentage (Day 4 goes further).
- cgroup v2: a directory tree under `/sys/fs/cgroup`; each directory is a group of processes with limits in files (`memory.max`, `cpu.max` = `quota period`); throttling when quota is used up; tmpfs pages are charged to the cgroup.
- Namespaces: each type gives a process its own view of one thing (PIDs, network, mounts, hostname, IPC, users, cgroup tree); `/proc/PID/ns/*` links — same inode number = same namespace.
- Docker = namespaces (walls) + cgroups (limits) + overlay (ch01) around ordinary processes on one kernel.

**Required diagrams:** physical RAM split into process memory / page cache / free; cgroup tree with limit files; one host kernel with two containers as boxes of namespaces.

**Try-it ideas:** `cat /proc/meminfo | head -8`; `free -m`; `cat /proc/loadavg`; `cat /proc/self/cgroup`; `ls /sys/fs/cgroup | head -30`; `cat /sys/fs/cgroup/memory.max /sys/fs/cgroup/cpu.max`; `ls -l /proc/self/ns`; `cat /proc/$$/oom_score_adj`.

**Accuracy pins:**
- Load average is not CPU utilisation and includes D-state tasks on Linux.
- Exceeding `memory.max` first causes reclaim; the cgroup OOM kill happens only when reclaim fails (matches Day 4 "Exceeding `memory.max` does not mean dead — yet").
- Inside the container, `/sys/fs/cgroup` shows the container's own cgroup as the root (cgroup namespace), so `memory.max` there is the container's limit (`max` if none set).

### Task 9: `07-networking-basics.md` — Networking basics

**Files:** Create `content/foundations/07-networking-basics.md`
**Sources:** `content/day06.md` "Core concepts" (first five subsections).
**Interfaces:** Consumes ch00–06. Produces *network interface, loopback, IP address, CIDR prefix, route, default gateway, port, socket, listening socket, TCP, UDP, three-way handshake, connection states (LISTEN, ESTABLISHED, TIME_WAIT), DNS, resolver, `/etc/hosts`, `/etc/resolv.conf`, `nsswitch.conf`, bind address*.

**Must cover:**
- Interface (`lo`, `eth0`) with an address and prefix; routing table as "for this destination, send via that interface/gateway"; longest prefix wins; default route.
- Port identifies a socket on a host; a connection = (src IP, src port, dst IP, dst port, protocol).
- A socket is a file descriptor (ch04): `socket:[inode]` in `/proc/PID/fd`.
- TCP server: socket → bind → listen → accept; client: connect; three-way handshake; LISTEN/ESTABLISHED/TIME_WAIT in plain words; UDP has no connection.
- Bind address: `127.0.0.1` reachable only from the same network namespace; `0.0.0.0` = all addresses in that namespace (Day 6's classic).
- Name resolution path: `nsswitch.conf` → `/etc/hosts` → DNS servers in `/etc/resolv.conf`; in Docker the resolver is `127.0.0.11`; service names like `app` and `db` resolve via it.
- Each network namespace (ch06) has its own interfaces, routes, sockets, firewall.

**Required diagrams:** `ws` → `app` request path (name lookup → route → interface → app's listening socket); TCP handshake; bind 127.0.0.1 vs 0.0.0.0.

**Try-it ideas:** `ip -br addr`; `ip route`; `cat /etc/resolv.conf`; `getent hosts app`; `ss -tlnp`; `ss -tn`; `cat /proc/net/tcp | head -3`; `curl -sI http://proxy/` (read-only HTTP HEAD — confirm the proxy service name and port from `labs/fleet/docker-compose.yml` before writing it).

**Accuracy pins:**
- A socket bound to `127.0.0.1` in one container is unreachable from another container.
- Docker's embedded DNS server address is `127.0.0.11`.
- `ss` reads via netlink, `/proc/net/tcp` is the file view; addresses there are hex, little-endian per field — say "Day 6 goes further" rather than decoding fully.

---

### Task 10: Live verification of all try-it commands

**Precondition:** Docker Desktop running (ask the user to start it if `docker ps` fails).

**Files:** Modify any chapter whose described output does not match reality.

- [ ] **Step 1: Bring up the fleet**

```bash
cd linux_ops_mastery/labs/fleet && docker compose -p linuxops up -d --build && docker compose -p linuxops ps
```
Expected: `ws`, `slim`, `app`, `db`, `proxy` running.

- [ ] **Step 2: Extract and run every try-it block**

```bash
cd linux_ops_mastery
for f in content/foundations/0*.md; do
  echo "=== $f"
  awk '/^## See it yourself/{s=1;next} /^## /{s=0} s && /^```bash/{p=1;next} s && /^```/{p=0;print "echo ----";next} s&&p' "$f" > "$SCRATCH/foundations-try.sh"
  docker compose -p linuxops -f labs/fleet/docker-compose.yml exec -T ws bash -s < "$SCRATCH/foundations-try.sh"
done 2>&1 | tee "$SCRATCH/foundations-try.out"
```
(`$SCRATCH` = the session scratchpad directory.)
Expected: no `command not found`, no `No such file`, no `Permission denied` (unless the chapter says to expect it).

- [ ] **Step 3: Compare** each block's real output with its `**What to look for:**` line. Fix wording or the command where they disagree. Re-run lint on changed files.

- [ ] **Step 4: Confirm fleet unchanged** — `docker compose -p linuxops ps` shows the same set running; no lab state touched.

- [ ] **Step 5: Commit** — `git commit -am "foundations: align try-it text with live ws output"` (with Co-Authored-By trailer).

### Task 11: Cross-chapter consistency review (main model)

**Files:** Modify chapters as needed.

- [ ] **Step 1: Contradiction pass** — for each chapter, read it next to its source day sections; list every contradiction or oversimplification-into-error; fix.
- [ ] **Step 2: Forward-reference pass** — for each chapter N, list every bolded/defined term; for each term used in chapter K<N, confirm it appears only as a named pointer ("chapter N explains"). Fix offenders.
- [ ] **Step 3: Self-check pass** — every answer is supported by its chapter body.
- [ ] **Step 4: Lint all** — `bash docs/superpowers/checks/foundations-lint.sh content/foundations/0*.md` → all `OK`.
- [ ] **Step 5: Commit** — `git commit -am "foundations: consistency fixes"` (with trailer).

### Task 12: Index README and course integration

**Files:**
- Create: `content/foundations/README.md`
- Modify: `README.md` (insert a section before `## The 7-day map`)
- Modify: `content/day01.md` … `content/day10.md` (one line at the top of the "At a glance" list)

- [ ] **Step 1: Write `content/foundations/README.md`** containing: one-paragraph purpose (who it's for, read-and-try, ~5 h); how to open the `ws` shell (`cd labs/fleet && docker compose -p linuxops up -d` then `docker compose -p linuxops exec ws bash`) and that all try-it commands are read-only; the chapter table (file link, title, ~minutes, prepares for Day N); a "Before Day N, read" table:

| Day | Read first |
|---|---|
| 1 | 00, 01 |
| 2 | 02, 03 |
| 3 | 04 |
| 4 | 06 |
| 5 | 05 |
| 6 | 06, 07 |
| 7 | whole track (review) |
| 8 | 04 |
| 9 | 03, 04 |
| 10 | 04 |

and a note: "Chapters build on each other; if you have the time, read 00→07 in order."

- [ ] **Step 2: Add to `README.md`** before `## The 7-day map`:

```markdown
## Foundations (start here if rusty)

If the day files feel like they assume vocabulary you no longer have —
inode, file descriptor, signal, cgroup — read the foundations track
first: `content/foundations/README.md`. Eight short chapters (~5 h,
read-and-try in `ws`) rebuild the mental model each day builds on, and
a table there says which chapters to read before each day.
```

- [ ] **Step 3: Add one line to each day** — insert as the first list item of the "At a glance" block, renumbering nothing (use `0.`):

`0. Rusty on the basics? Read foundations ch 00, 01 first — [content/foundations/README.md](foundations/README.md).`

with the chapter list per the table in Step 1 (Day 7: `the whole foundations track as review`). Use Edit per file; verify with `/usr/bin/grep -n 'Rusty on the basics' content/day*.md` → 10 lines.

- [ ] **Step 4: Link check** — `bash docs/superpowers/checks/foundations-lint.sh --links-only content/foundations/README.md README.md content/day*.md` → all `OK`.

- [ ] **Step 5: Commit** — `git add` the README files and day files; `git commit -m "foundations: index and course pointers"` (with trailer).

### Task 13: Bring changes back to master uncommitted

- [ ] **Step 1:** Final full lint: `bash docs/superpowers/checks/foundations-lint.sh content/foundations/0*.md && bash docs/superpowers/checks/foundations-lint.sh --links-only content/foundations/README.md README.md content/day*.md`
- [ ] **Step 2:**

```bash
cd /Users/hunghd/git_clone/learning_path
git switch master
git merge --squash tmp/linux-foundations
git reset -q
git branch -D tmp/linux-foundations
git status --short
```
Expected: new `content/foundations/`, spec, plan, lint script, and modified `README.md` + 10 day files shown as uncommitted; branch gone; nothing pushed.
- [ ] **Step 3:** Report to the user: files added/changed, verification evidence (lint output, live try-it run), and any open issues.

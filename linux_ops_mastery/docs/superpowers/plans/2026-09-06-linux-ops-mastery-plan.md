# Linux Operator Mastery (+ Neovim) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Author a complete, self-contained 7-day (21 h) Linux operator mastery
path with a runnable Docker lab fleet, in which every day teaches a kernel file
before the tool that formats it, and every day is drilled with an injected
failure.

**Architecture:** Content is markdown under `content/`; labs are a single
`docker compose` fleet under `labs/fleet/` plus seven per-day directories that
each inject one incident (`break.sh`), verify the repair objectively
(`verify.sh`), and document the chain of evidence (`SOLUTION.md`). All
break/verify scripts run **on the macOS host** and reach into containers through
a shared helper, so the learner never has to remember container names.

**Tech Stack:** Docker Compose (arm64-native images), POSIX shell, Python 3.12
(the lab's prop HTTP service only), systemd (Day 5 container), neovim.

**Spec:** `linux_ops_mastery/docs/superpowers/specs/2026-09-06-linux-ops-mastery-design.md`

## Global Constraints

Every task's requirements implicitly include this section.

| # | Constraint |
|---|---|
| G1 | **No git commands, ever.** No `git add`, `commit`, `push`, `status`, `diff`, or `log` in any task or subagent dispatch. The learner owns all VCS. This **replaces** the writing-plans "Commit" step: every task ends with a **Verify** step instead. |
| G2 | **No real infrastructure during authoring.** Do not run `docker build`, `docker compose up/run/exec`, or start any container. Scripts and compose files are *authored and statically checked* only. |
| G3 | **Permitted validation only:** `bash -n <script>` for shell syntax, and `python3 -c "import yaml,sys;yaml.safe_load(open('<f>'))"` for YAML. `shellcheck` if already installed — never install it. |
| G4 | **No credentials.** No real secrets, keys, tokens, or AWS account IDs. Placeholders plus `*.example` files only. |
| G5 | **Every exercise ships a Hint and a Solution sketch.** A bare problem is a task failure. |
| G6 | **All images arm64-multi-arch and tag-pinned:** `ubuntu:24.04`, `alpine:3.20`, `python:3.12-alpine`, `postgres:16-alpine`, `nginx:1.27-alpine`. No `latest`. |
| G7 | **Fixed names — do not invent variants.** Compose project `linuxops`; services `ws`, `slim`, `app`, `db`, `proxy`, `sysd`; network `linuxops_net`. |
| G8 | **Every `content/dayNN.md` follows the Content Day Skeleton** from the spec, section for section, in order. |
| G9 | **Anti-pattern bullets cite STRATEGY.md by number** (Mistake 1–7). Do not invent new mistake numbers. |
| G10 | **Host is macOS on Apple Silicon.** No `x86_64`-only tooling, no GNU-only flags in host-side scripts (`sed -i ''` differences: host scripts must avoid in-place sed entirely). |
| G11 | **Line length ≤ 90 characters** in markdown prose, to stay readable in a terminal pager on a server. |
| G12 | **`app` and `slim` are Alpine — their `sh`, `ps`, `pgrep`, `grep`, and `awk` are busybox.** Any command a script runs inside them must be POSIX-safe: no `pgrep -c`/`-n`, no GNU-only `grep -P`, no `awk` gensub. Commands run inside `ws` (Ubuntu) may use GNU forms freely. Every `SOLUTION.md` that shows a command run in `slim` shows the busybox form. |

## File Structure

```
linux_ops_mastery/
├── README.md                       Quickstart, 7-day map, fleet bring-up, the daily loop
├── STRATEGY.md                     The /proc doctrine, the 4 truths, the 7-step loop, Mistakes 1–7
├── COVERAGE.md                     LPIC-1 + LFCS objective → day matrix; deliberate skips + reasons
├── journal.md                      Diagnosis-chain template + one worked Day 1 example
├── content/
│   ├── GLOSSARY.md                 Plain-English terms, alphabetical
│   ├── day01.md … day07.md         One per day, Content Day Skeleton
│   └── primers/
│       ├── proc-field-reference.md Field-by-field decode of the 6 files the path relies on
│       └── nvim-cheatsheet.md      The grammar (operator+motion+text object), not a command dump
└── labs/
    ├── lib/common.sh               Shared helper: compose wrapper, symptom(), require_fleet()
    ├── fleet/
    │   ├── docker-compose.yml      ws, slim, app, db, proxy + limits, caps, tmpfs
    │   ├── docker-compose.sysd.yml Day-5 overlay: privileged systemd container
    │   ├── Dockerfile.ws           ubuntu:24.04 + operator toolbox
    │   ├── Dockerfile.sysd         ubuntu:24.04 + systemd as PID 1
    │   ├── app/Dockerfile          python:3.12-alpine + app.py
    │   ├── app/app.py              The prop service (all lab behaviours live here)
    │   ├── seed/                   Log fixtures and configs consumed by break.sh scripts
    │   └── README.md               Bring-up, arm64 notes, SYS_PTRACE, Colima/Lima fallback
    ├── day01/ … day07/             README.md, break.sh, verify.sh, SOLUTION.md, teardown.md
    └── verify-teardown.sh          Confirms zero containers, volumes, networks remain
```

**Note — one addition beyond the spec's lab file set:** each `labs/dayNN/` also
ships `verify.sh`. The spec lists README/break/SOLUTION/teardown; `verify.sh`
gives each lab an objective pass/fail signal so the learner is never left
guessing whether the repair was real. Treat it as part of every day task.

## Task Dependency Order

```
Task 1 (docs skeleton) ─┐
Task 2 (lab fleet) ─────┼──> Tasks 4–10 (days 1–7) ──> Task 11 (coverage + final audit)
Task 3 (primers) ───────┘
```

Tasks 1, 2, 3 may run in parallel. Tasks 4–10 may run in parallel **after** 2
and 3 land, because every day task consumes the fleet's service names and the
primers' field tables. Task 11 runs last.

---

### Task 1: Foundation documents

**Files:**
- Create: `linux_ops_mastery/README.md`
- Create: `linux_ops_mastery/STRATEGY.md`
- Create: `linux_ops_mastery/journal.md`

**Interfaces:**
- Consumes: nothing.
- Produces: `STRATEGY.md` heading anchors that every day file cites —
  `## The four truths`, `## The daily loop`, `## The seven mistakes` with
  bullets numbered **Mistake 1** … **Mistake 7** exactly as listed in the spec.
  Produces the `journal.md` chain template that every `SOLUTION.md` mirrors.

- [ ] **Step 1: Write `STRATEGY.md`**

Sections, in order:

1. `# The Top 1% Strategy for Linux Operations` — opens with the doctrine in
   one sentence: *`ps`, `top`, `free`, `df`, `ss`, and `lsof` are not
   knowledge; they are pretty-printers over kernel files.*
2. `## The four truths` — the spec's 4-row table verbatim (mount tree, process
   table, fd table, cgroup/namespace boundary), each with its question and its
   primary evidence path.
3. `## The move` — `symptom → resource class → the file that proves it`, with
   two worked one-paragraph examples: "the disk is full" and "the container was
   killed".
4. `## The daily loop` — the seven steps from the spec, numbered, each with one
   sentence on *why* it is in that position. Step 5 must state the rule
   explicitly: **the chain is written before the fix is attempted.**
5. `## The seven mistakes` — Mistakes 1–7 from the spec, each as
   `### Mistake N — <short name>` followed by two to four sentences: what
   beginners do, what it costs, what to do instead.
6. `## Why not the alternatives` — two short paragraphs rejecting the USE-method
   spine and the certification-objective spine, per the spec.
7. `## Neovim's bounded role` — the 1 h / 1.5 h / woven split, the arrow-keys
   rule, and the explicit non-goal of replacing VSCode.

- [ ] **Step 2: Write `README.md`**

Must contain, in order:

- One-paragraph statement of what the path is and who it is for.
- **Prerequisites:** Docker Desktop on Apple Silicon; ~4 GB free disk; neovim
  installed on the host is *not* required (it ships inside `ws`).
- **Bring-up**, as a copy-pasteable block:

```bash
cd linux_ops_mastery/labs/fleet
docker compose -p linuxops up -d --build
docker compose -p linuxops exec ws bash      # your shell for every lab
```

- **The 7-day map** — a table with columns: Day | Truth | Hours | Incident |
  Content file | Lab dir. Rows exactly matching the spec's curriculum.
- **The daily loop** — the seven steps, condensed to one line each, with a
  pointer to `STRATEGY.md` for the reasoning.
- **The arrow-key rule** — from Day 2 on, all editing happens in `nvim` inside
  `ws`, arrow keys disabled by the shipped `init.lua`.
- **How a lab works** — `bash labs/dayNN/break.sh` → write the chain in
  `journal.md` → fix → `bash labs/dayNN/verify.sh` → `teardown.md`.
- **Teardown**: `bash labs/verify-teardown.sh`.

- [ ] **Step 3: Write `journal.md`**

Contains a `## Chain template` section with this exact skeleton, then one fully
worked `## Day 1 — example entry` using the Day 1 disk-full incident so the
learner sees the standard before writing their first entry:

```markdown
### Day N — <incident in five words>
**Symptom (verbatim, no interpretation):**
**Resource class:** mount tree | process table | fd table | cgroup boundary
**Chain of evidence:**
1. Claim: … | Proof: `<command>` → `<the output line that proves it>`
2. Claim: … | Proof: …
**Diagnosis:**
**Fix applied:**
**Proof the fix worked (same file re-read):**
**What I would check first next time:**
```

- [ ] **Step 4: Verify**

Run and confirm each:
- `grep -c '^### Mistake' linux_ops_mastery/STRATEGY.md` → `7`
- `grep -n 'The four truths\|The daily loop\|The seven mistakes' linux_ops_mastery/STRATEGY.md` → 3 hits
- `grep -c '^|' linux_ops_mastery/README.md` → ≥ 9 (7 day rows + header + separator)
- `awk 'length > 90 {c++} END {print c+0}' linux_ops_mastery/*.md` → `0`

---

### Task 2: The lab fleet

**Files:**
- Create: `linux_ops_mastery/labs/lib/common.sh`
- Create: `linux_ops_mastery/labs/fleet/docker-compose.yml`
- Create: `linux_ops_mastery/labs/fleet/docker-compose.sysd.yml`
- Create: `linux_ops_mastery/labs/fleet/Dockerfile.ws`
- Create: `linux_ops_mastery/labs/fleet/Dockerfile.sysd`
- Create: `linux_ops_mastery/labs/fleet/app/Dockerfile`
- Create: `linux_ops_mastery/labs/fleet/app/app.py`
- Create: `linux_ops_mastery/labs/fleet/seed/nginx.conf`
- Create: `linux_ops_mastery/labs/fleet/seed/gen-logs.sh`
- Create: `linux_ops_mastery/labs/fleet/README.md`
- Create: `linux_ops_mastery/labs/verify-teardown.sh`

**Interfaces:**
- Consumes: nothing.
- Produces — **every later task depends on these exact names and behaviours:**
  - Services `ws`, `slim`, `app`, `db`, `proxy` (project `linuxops`), network
    `linuxops_net`, plus `sysd` in the overlay file.
  - `app` HTTP API on port `8080`: `GET /` (200 "ok"), `GET /healthz`,
    `GET /burn?seconds=N` (busy-loops N seconds), `GET /balloon?mb=N`
    (allocates N MiB and holds it), `GET /log?n=N` (appends N lines to
    `$LOG_PATH`), `GET /fail?code=C` (returns status C; with `&sticky=1` every subsequent
    request to `/` and `/healthz` returns C until any `/fail?code=200` clears it,
    with or without `sticky=1`. The control endpoints `/fail`, `/burn`,
    `/balloon` and `/log` always answer, armed or not — Day 4 needs `/burn`
    regardless, and Day 6 fault 5 must clear reliably).
  - `app` env vars: `BIND_ADDR` (default `0.0.0.0`), `PORT` (`8080`),
    `LOG_PATH` (`/var/log/app.log`), `IGNORE_SIGTERM` (`0`).
  - `app` has `tmpfs: /var/log` sized `24m` — this is what makes Day 1's
    disk-full incident possible and safe. The size is **not** free to change:
    tmpfs (shmem) pages are charged to the memory cgroup, so tmpfs size plus
    python's ~18 MiB RSS must stay under `mem_limit: 64m`, or Day 1's ENOSPC
    becomes Day 4's OOM kill.
  - `app` has `mem_limit: 64m` and `cpus: 0.20` — Day 4 depends on both.
  - `ws` has `cap_add: [SYS_PTRACE]` and `ipc: shareable`; `strace` works only
    here. **Not `pid: shareable`** — Docker's PID mode accepts only `host` or
    `container:<name>`; `shareable` is an IPC mode, and the daemon rejects the
    container outright with `invalid PID mode: shareable`.
  - `labs/lib/common.sh` exports: `compose()` (wraps
    `docker compose -p linuxops -f <fleet>/docker-compose.yml`), `symptom MSG`
    (prints a one-line symptom and nothing else), `require_fleet` (exits 1 with
    a bring-up hint if the fleet is not running), `in_ws CMD`, `in_app CMD`,
    `in_slim CMD`.

- [ ] **Step 1: Write `labs/lib/common.sh`**

```sh
#!/usr/bin/env bash
# Shared helpers for every labs/dayNN/{break,verify}.sh script.
# Sourced, never executed directly. Host-side only.
set -euo pipefail

LABS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLEET_FILE="${LABS_DIR}/fleet/docker-compose.yml"
PROJECT="linuxops"

compose() { docker compose -p "$PROJECT" -f "$FLEET_FILE" "$@"; }
in_ws()   { compose exec -T ws   bash -c "$1"; }
in_app()  { compose exec -T app  sh   -c "$1"; }
in_slim() { compose exec -T slim sh   -c "$1"; }

symptom() { printf '\nSYMPTOM: %s\n\nNothing else will be explained.\n' "$1"; }

require_fleet() {
  if ! compose ps --status running --quiet ws >/dev/null 2>&1 \
     || [ -z "$(compose ps --status running --quiet ws)" ]; then
    echo "Fleet is not running. Start it with:" >&2
    echo "  cd ${LABS_DIR}/fleet && docker compose -p linuxops up -d --build" >&2
    exit 1
  fi
}
```

- [ ] **Step 2: Write `labs/fleet/app/app.py`**

A single-file `http.server`-based service, standard library only. Requirements:

- Reads `BIND_ADDR`, `PORT`, `LOG_PATH`, `IGNORE_SIGTERM` from the environment.
- Installs a `SIGTERM` handler that logs `"got SIGTERM, shutting down"` and
  exits 0 — **unless** `IGNORE_SIGTERM=1`, in which case it logs
  `"ignoring SIGTERM"` and keeps running. Day 2 uses both branches.
- Keeps a module-level `BALLOON = []` list so `/balloon?mb=N` allocations are
  not garbage-collected; each MiB is `bytearray(1024*1024)` filled with a
  non-zero byte so the pages are actually resident (a zeroed `bytearray` may
  not be, and the OOM kill would not reproduce).
- `/burn?seconds=N` spins on `time.monotonic()` in a thread so the server stays
  responsive while `cpu.stat` throttling accumulates.
- `/log?n=N` appends `N` lines of the shape
  `2026-09-06T12:00:00Z INFO req_id=<8 hex> status=200 latency_ms=<int> path=/x`
  to `LOG_PATH`, flushing each write.
- On start, prints its own PID and the resolved bind address to stdout.

- [ ] **Step 3: Write the three Dockerfiles**

`app/Dockerfile`: `FROM python:3.12-alpine`, copy `app.py` to `/srv/app.py`,
`EXPOSE 8080`, and — deliberately — `ENTRYPOINT ["sh", "-c", "python /srv/app.py; exit $?"]`.
The trailing `; exit $?` is load-bearing: busybox ash and dash exec-optimize
`sh -c "<single command>"` into a bare exec, which would make python PID 1 and
silently delete Day 2's entire lesson. A second command forces `sh` to stay
resident. Comment this as the **intentional Day 2 defect**, explain why the
trailing command matters — it is why some real Dockerfiles handle signals
correctly by accident — and give the corrected exec form beneath it, commented out.

`Dockerfile.ws`: `FROM ubuntu:24.04`, `DEBIAN_FRONTEND=noninteractive`, install
in one layer: `procps psmisc lsof strace ltrace file findutils coreutils
util-linux iproute2 iputils-ping dnsutils netcat-openbsd curl ca-certificates
openssl tcpdump nftables less vim neovim git jq bsdmainutils acl attr sysstat
tree`. Then write the shipped `/root/.config/nvim/init.lua` (see Step 4).
`CMD ["sleep", "infinity"]`.

`Dockerfile.sysd`: `FROM ubuntu:24.04`, install `systemd systemd-sysv dbus`,
mask the units that fail in a container
(`getty.target`, `systemd-udevd`, `systemd-logind` where needed),
`STOPSIGNAL SIGRTMIN+3`, `CMD ["/lib/systemd/systemd"]`.

- [ ] **Step 4: Write the shipped neovim config into `Dockerfile.ws`**

Written as a heredoc inside the Dockerfile so it lands at
`/root/.config/nvim/init.lua`. Plugin-free, ≤ 30 lines. Must set: `number`,
`relativenumber`, `expandtab`, `shiftwidth=2`, `ignorecase`, `smartcase`,
`hlsearch`, `undofile`, `clipboard` left alone, and **disable the arrow keys in
normal, insert, and visual mode** with a message:

```lua
for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
  for _, mode in ipairs({ "n", "i", "v" }) do
    vim.keymap.set(mode, key, function()
      vim.notify("Use h j k l.", vim.log.levels.WARN)
    end)
  end
end
```

- [ ] **Step 5: Write `docker-compose.yml`**

Five services on `linuxops_net`. Non-obvious settings that later tasks depend
on, all of which must be present and commented with the day that needs them:

| Service | Settings |
|---|---|
| `ws` | `build: {context: ., dockerfile: Dockerfile.ws}`, `cap_add: [SYS_PTRACE]`, `security_opt: ["seccomp=unconfined"]`, `ipc: shareable`, `volumes: ["../:/labs:ro"]` |
| `slim` | `image: alpine:3.20`, `command: ["sleep","infinity"]` — **no extra packages, ever** |
| `app` | `build: ./app`, `tmpfs: ["/var/log:size=24m,mode=1777"]` (**not 64m** — tmpfs pages are charged to the container's memory cgroup, so a 64m tmpfs inside a 64m `mem_limit` OOM-kills before ENOSPC; 24m tmpfs + ~18m python RSS leaves headroom), `mem_limit: 64m`, `memswap_limit: 64m`, `cpus: 0.20`, `volumes: ["../:/labs:ro"]` (Day 3 runs `seed/gen-logs.sh` from here), `environment` with the four vars at their defaults |
| `db` | `image: postgres:16-alpine`, `POSTGRES_PASSWORD` from `.env.example` placeholder, `POSTGRES_DB: labs` |
| `proxy` | `build: {context: ., dockerfile: Dockerfile.proxy}` — FROM `nginx:1.27-alpine` plus `iproute2` and `nftables`, which Day 6 faults 2 and 3 require and the stock image lacks; mounts `./seed/nginx.conf:/etc/nginx/conf.d/default.conf:ro`, depends_on `app`, `cap_add: [NET_ADMIN]` (Day 6 deletes and restores its default route) |

Ship `labs/fleet/.env.example` with `POSTGRES_PASSWORD=changeme-locally` and a
comment; never ship a real `.env`.

- [ ] **Step 6: Write `docker-compose.sysd.yml`, `seed/nginx.conf`, `seed/gen-logs.sh`**

`docker-compose.sysd.yml` — an overlay adding only `sysd`: built from
`Dockerfile.sysd`, `privileged: true`, `cgroup: host`,
`volumes: ["/sys/fs/cgroup:/sys/fs/cgroup:rw"]`, `tmpfs: ["/run","/run/lock"]`.

`seed/nginx.conf` — `server { listen 80; location / { proxy_pass
http://app:8080; } }`, plus `resolver` left unset deliberately so Day 6 can
exercise DNS.

`seed/gen-logs.sh` — runs *inside* `app`; takes a line count and an optional
`--needle <req_id>` and writes a log file where exactly one line carries
`status=500` with that request id. Day 3 consumes it.

- [ ] **Step 7: Write `labs/fleet/README.md`**

Must cover: bring-up and teardown commands; why `ws` needs `SYS_PTRACE`
(`strace` returns `EPERM` without it); the arm64 note that every pinned image is
multi-arch so no `platform:` key is needed; the Day 5 systemd caveat — that
`--privileged --cgroupns=host` on Docker Desktop for macOS is the fragile part —
and the **Colima fallback**, written out in full:

```bash
brew install colima docker
colima start --arch aarch64 --cpu 2 --memory 4 --vm-type=vz
docker context use colima
# then bring the fleet up exactly as above
```

Plus a troubleshooting table: symptom → cause → fix, covering at minimum
`strace: attach: ptrace(PTRACE_SEIZE): Operation not permitted`, `sysd` exiting
immediately, and `/sys/fs/cgroup` mounted read-only.

- [ ] **Step 8: Write `labs/verify-teardown.sh`**

Checks and reports, exiting non-zero if anything remains: containers under
project `linuxops`, the `linuxops_net` network, any named volume prefixed
`linuxops`, and dangling images built by the fleet. Prints the exact `docker
compose -p linuxops down -v --remove-orphans` command when it finds leftovers.

- [ ] **Step 9: Verify**

- `bash -n` passes on `labs/lib/common.sh`, `labs/verify-teardown.sh`,
  `labs/fleet/seed/gen-logs.sh`
- `python3 -c "import yaml;yaml.safe_load(open('linux_ops_mastery/labs/fleet/docker-compose.yml'))"`
  succeeds; same for the `sysd` overlay
- `python3 -c "import ast;ast.parse(open('linux_ops_mastery/labs/fleet/app/app.py').read())"`
  succeeds
- `grep -c 'linuxops' linux_ops_mastery/labs/lib/common.sh` → ≥ 1
- `grep -n 'SYS_PTRACE\|tmpfs\|mem_limit: 64m\|cpus: 0.20' docker-compose.yml`
  → all four present
- No `latest` tag anywhere: `grep -rn ':latest' linux_ops_mastery/labs/` → no hits

---

### Task 3: Primers and glossary

**Files:**
- Create: `linux_ops_mastery/content/GLOSSARY.md`
- Create: `linux_ops_mastery/content/primers/proc-field-reference.md`
- Create: `linux_ops_mastery/content/primers/nvim-cheatsheet.md`

**Interfaces:**
- Consumes: nothing.
- Produces: field tables that Days 2, 4, and 6 cite by name rather than
  duplicating — section anchors must be exactly `## /proc/PID/stat`,
  `## /proc/PID/status`, `## /proc/meminfo`, `## /proc/loadavg`,
  `## /proc/net/tcp`, `## /sys/fs/cgroup (v2)`.

- [ ] **Step 1: Write `primers/proc-field-reference.md`**

Six sections, each a table of `Field # | Name | Meaning | Why an operator cares`:

- `## /proc/PID/stat` — at minimum fields 1–4 (pid, comm, state, ppid), 10 and
  12 (minflt, majflt — majflt is the page-fault signal Day 4 needs), 14–15
  (utime, stime), 20 (num_threads), 23 (vsize), 24 (rss in **pages**, with the
  explicit warning that it must be multiplied by page size).
- `## /proc/PID/status` — `State`, `Tgid`, `PPid`, `Threads`, `VmRSS`,
  `RssAnon`, `RssFile`, `SigQ`, `SigPnd`, `SigBlk`, `SigIgn`, `SigCgt`,
  `CapEff`. Include a worked example of decoding a `SigCgt` hex mask to a
  signal list — Day 2's SIGTERM incident is solved with exactly this.
- `## /proc/meminfo` — `MemTotal`, `MemFree`, `MemAvailable`, `Buffers`,
  `Cached`, `Dirty`, `SwapTotal/Free`, with a boxed statement that
  `MemFree` is not "memory you can use" and `MemAvailable` is.
- `## /proc/loadavg` — the five fields, and the sentence that matters most:
  the first three count **runnable plus uninterruptible-sleep** tasks, which is
  why an I/O-blocked box shows a high load average at low CPU utilisation.
- `## /proc/net/tcp` — `local_address`, `rem_address` (hex, little-endian — show
  the conversion worked out for `0100007F:1F90` → `127.0.0.1:8080`), `st` state
  codes table (01 ESTABLISHED … 0A LISTEN), `inode` and how it joins to
  `/proc/PID/fd`.
- `## /sys/fs/cgroup (v2)` — `memory.current`, `memory.max`, `memory.events`
  (with `oom_kill` called out), `cpu.max` (quota/period form), `cpu.stat`
  (`nr_throttled`, `throttled_usec`), `pids.current`, `cgroup.procs`.

Every section ends with **"The tool that formats this: …"** naming the command
it replaces.

- [ ] **Step 2: Write `primers/nvim-cheatsheet.md`**

Organised as a *grammar*, not a command list:

1. `## The sentence` — `<operator><count><motion|text-object>`, with a table
   showing `d`/`c`/`y`/`>`/`gu` crossed against `w`/`}`/`ip`/`i"`/`t,`.
2. `## Motions` — word/line/screen/file/search-as-motion/`f t ; ,`.
3. `## Text objects` — `iw aw i" a" i( a( ip ap it at`, with the
   inner-vs-around distinction shown on one example line.
4. `## Ex commands an operator actually needs` — `:g//`, `:v//`, `:%s///gc`,
   ranges, `:normal`, `:%!`, `:r !`, `:w !sudo tee %`.
5. `## Registers and macros` — `"ayy`, `qa … q`, `@a`, `@@`, `5@a`.
6. `## Moving without a mouse` — buffers, `:argdo`, quickfix `:cn`/`:cp`,
   `:cdo`, marks, `Ctrl-o`/`Ctrl-i`.
7. `## The five-line survival card` — what to do when stuck, when a file is
   read-only, when the terminal is 80×24, when `nvim` is absent and only `vi`
   exists.

- [ ] **Step 3: Write `content/GLOSSARY.md`**

Alphabetical, one to three sentences each, plain English, no jargon-by-jargon
definitions. Minimum entries: capability, cgroup (v1 vs v2), chain of evidence,
descriptor (file), dentry, D state, ephemeral port, FHS, hard link, inode,
`MemAvailable`, mount namespace, `ndots`, OOM killer, overlayfs, page cache,
PID 1, PSI, quota/period, reaping, RSS, sticky bit, setuid, TIME_WAIT, tmpfs,
umask, VFS, zombie.

- [ ] **Step 4: Verify**

- `grep -c '^## ' linux_ops_mastery/content/primers/proc-field-reference.md` → `6`
- All six required anchors present:
  `grep -n '^## /proc/PID/stat$\|^## /proc/PID/status$\|^## /proc/meminfo$\|^## /proc/loadavg$\|^## /proc/net/tcp$\|^## /sys/fs/cgroup (v2)$'`
  → 6 hits
- `grep -c 'The tool that formats this' proc-field-reference.md` → `6`
- `grep -c '^- \*\*' linux_ops_mastery/content/GLOSSARY.md` → ≥ 28
- `awk 'length > 90 {c++} END {print c+0}'` over all three files → `0`

---

## Day tasks — shared shape

Tasks 4–10 each build one day. They share a structure; only the substance
differs. Every day task creates exactly six files:

```
content/dayNN.md          Content Day Skeleton, all ten sections, in order
labs/dayNN/README.md      Goal, success signal, how to run, no spoilers
labs/dayNN/break.sh       Injects the incident, prints one symptom line, exits 0
labs/dayNN/verify.sh      Objective pass/fail on the repair, exits 0 or 1
labs/dayNN/SOLUTION.md    The full chain of evidence, in journal.md's format
labs/dayNN/teardown.md    Checklist returning the fleet to a clean state
```

Every `break.sh` and `verify.sh` begins:

```sh
#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet
```

Every `break.sh` ends by calling `symptom "…"` and printing nothing else — no
hints, no file paths, no command suggestions. Every `SOLUTION.md` uses the
`journal.md` chain template so the learner can compare their chain against a
model one, claim by claim.

Every `content/dayNN.md` **Exercises** section ships exactly **six** exercises,
each with a Hint and a Solution sketch (G5).

---

### Task 4: Day 1 — the mount tree, and everything is a file

**Files:**
- Create: `linux_ops_mastery/content/day01.md`
- Create: `linux_ops_mastery/labs/day01/{README.md,break.sh,verify.sh,SOLUTION.md,teardown.md}`

**Interfaces:**
- Consumes: `app` service with `tmpfs: /var/log size=24m` (Task 2); `slim` with
  busybox only; `common.sh` helpers.
- Produces: the phrase **"chain of evidence"** as used by every later
  `SOLUTION.md`; the Day 1 journal example referenced by `journal.md` (Task 1).

- [ ] **Step 1: Write `content/day01.md`**

Budget line: `**Budget:** 3 h — 2 h Linux + 1 h neovim`. Truth: mount tree.

- **Why this matters** — a full disk that `du` cannot account for is the single
  most common "the box is broken and nothing makes sense" page, and it is
  unsolvable without knowing that a filename is not a file.
- **Read the file first** — `cat /proc/mounts` field by field (device,
  mountpoint, fstype, options, dump, pass); then `cat /proc/self/mountinfo` and
  the two fields `df` cannot show: the mount ID and the *root of the mount
  within its filesystem*, which is what makes a bind mount visible.
- **Derive the tool** — run `df -h` and `findmnt` and map each column back to
  the bytes above; state plainly that `df` adds one thing `/proc/mounts` has
  not got: a `statfs(2)` call per mountpoint.
- **Core concepts** — the FHS as a set of promises (`/etc` config, `/var`
  mutable state, `/usr` read-only shareable, `/tmp` volatile, `/proc` and `/sys`
  not on disk at all); inode versus name, and the consequence that `rm` removes
  a *name*, never a file; hard links versus symlinks with `ls -li` shown;
  `stat` output decoded; bind mounts; overlayfs `lowerdir`/`upperdir`/`merged`
  and the one-sentence statement that a container image layer *is* a lowerdir;
  `df` versus `du` and precisely why they can disagree in both directions.
- **Lab** — `labs/day01/`. Goal: return `/var/log` on `app` to under 20 % used
  without restarting the container. Success signal: `verify.sh` exits 0.
- **Strip the toolbox** — redo the identification of the holding process in
  `slim`, where `lsof` does not exist, using only
  `ls -l /proc/*/fd 2>/dev/null | grep deleted`.
- **Exercises** — six, covering: (1) predict `df`/`du` divergence direction for
  a sparse file; (2) create a hard link and a symlink and explain which survives
  the original's removal; (3) read `/proc/self/mountinfo` and name every bind
  mount; (4) find the inode a path resolves to and locate every name pointing at
  it; (5) explain why `rm` on a 4 GB log freed no space; (6) explain from
  `/proc/mounts` alone why writing to `/proc/uptime` fails.
- **Anti-patterns** — cites Mistake 2 (trusting `df`'s summary) and Mistake 3
  (reaching for `ncdu`, which is absent on every server that matters).
- **Where this shows up in AWS** — an ECS task whose ephemeral storage fills
  because a rotated application log is still held open by the app; why the task
  keeps running while every write fails; why restarting the task "fixes" it and
  therefore hides the cause.
- **Teardown** — points at `labs/day01/teardown.md`.

- [ ] **Step 2: Write `labs/day01/break.sh`**

Body after the shared preamble:

```sh
in_app 'dd if=/dev/zero of=/var/log/bloat.log bs=1M 2>/dev/null || true'
in_app 'setsid sh -c "exec tail -f /var/log/bloat.log >/dev/null 2>&1" &'
sleep 1
in_app 'rm -f /var/log/bloat.log'
symptom "Writes to /var/log on the app container are failing with ENOSPC."
```

- [ ] **Step 3: Write `labs/day01/verify.sh`**

Passes only when both hold: `/var/log` usage under 20 %, **and** no deleted-but-
open file remains under `/var/log`.

```sh
used=$(in_app "df -P /var/log | awk 'NR==2 {gsub(/%/,\"\",\$5); print \$5}'")
held=$(in_app 'ls -l /proc/*/fd 2>/dev/null | grep -c "/var/log.*(deleted)" || true')
if [ "$used" -lt 20 ] && [ "$held" -eq 0 ]; then
  echo "PASS: /var/log at ${used}% and no deleted-but-open files remain."
else
  echo "FAIL: usage=${used}% deleted_fds=${held}" >&2
  exit 1
fi
```

- [ ] **Step 4: Write `labs/day01/README.md`, `SOLUTION.md`, `teardown.md`**

`README.md`: the goal in one line, the success signal, the run sequence, and the
constraint — **do not restart the container**, because restarting destroys the
evidence and teaches nothing.

`SOLUTION.md`: the chain, in `journal.md` format, reaching the diagnosis through
`df -h /var/log` (100 %) → `du -sh /var/log` (near zero) → the claim that the
space is held by an unlinked inode → proof via
`ls -l /proc/*/fd | grep deleted` → the holding PID → two valid fixes, with
their trade-offs stated: kill the holder (space returns immediately, process
dies) or truncate through the descriptor with `: > /proc/<pid>/fd/<n>` (space
returns, process survives, and this is the one to reach for in production).

`teardown.md`: kill any lingering `tail`, confirm `verify.sh` passes.

- [ ] **Step 5: Verify**

- `bash -n labs/day01/break.sh labs/day01/verify.sh`
- `grep -c '^## ' content/day01.md` → `10` (the skeleton's ten sections)
- `grep -c '\*\*Hint:\*\*' content/day01.md` → `6`
- `grep -c '\*\*Solution sketch:\*\*' content/day01.md` → `6`
- `grep -n 'Mistake 2\|Mistake 3' content/day01.md` → both present
- `grep -c 'symptom ' labs/day01/break.sh` → `1`

---

### Task 5: Day 2 — the process table and the syscall boundary

**Files:**
- Create: `linux_ops_mastery/content/day02.md`
- Create: `linux_ops_mastery/labs/day02/{README.md,break.sh,verify.sh,SOLUTION.md,teardown.md}`

**Interfaces:**
- Consumes: `app`'s `IGNORE_SIGTERM` env var and its shell-form `ENTRYPOINT`
  (Task 2); `ws` with `SYS_PTRACE`; the `SigCgt` decoding worked example from
  `primers/proc-field-reference.md` (Task 3).
- Produces: the signal-mask decoding procedure that Day 5 reuses for `CapEff`.

**Correction to the spec, applied here:** the spec's Day 2 incident named an
uninterruptible `D`-state process that ignores `SIGKILL`. `D` state cannot be
induced reliably or safely inside Docker Desktop on macOS — it needs genuinely
blocking device or network-filesystem I/O. The lab therefore reproduces the
**three reproducible members of the "won't die" family** — a trapped `SIGTERM`,
a `T`-stopped process, and zombie accumulation under a shell PID 1 — and `D`
state is taught in the content as the fourth member, with its real causes (NFS,
failing EBS volume, device timeout) and the reason no signal can touch it.

- [ ] **Step 1: Write `content/day02.md`**

Budget: `3 h`. Truth: process table.

- **Read the file first** — `/proc/PID/stat` fields 1–4, 14–15, 20, 24 (citing
  the primer, not duplicating it); `/proc/PID/status` for `State`, `PPid`,
  `Threads`, and the four signal masks; `/proc/PID/cmdline` and its NUL
  separators (`tr '\0' ' '`); `/proc/PID/exe`, `/proc/PID/cwd`,
  `/proc/PID/environ` as symlinks and why reading them needs the right uid.
- **Derive the tool** — `ps -eo pid,ppid,state,comm` mapped column by column
  onto the fields just read; `pstree -p` as the parent field rendered as a tree.
- **Core concepts** — `fork` duplicates, `exec` replaces, and the two are
  separate on purpose (that gap is where redirection is set up); `wait` and the
  reaping contract; what PID 1 inherits and why an orphan is reparented; process
  states `R S D Z T` with the effect of each on load average; the signal table
  an operator must know cold (TERM/INT/HUP/QUIT/KILL/STOP/CONT/CHLD) and which
  two cannot be caught; process groups, sessions, controlling terminals,
  `nohup` versus `setsid`; `strace -f -p` and reading a syscall trace.
- **Lab** — three-part incident (see break.sh). Success signal: `verify.sh` 0.
- **Strip the toolbox** — in `slim`, list processes and states with
  `for p in /proc/[0-9]*; do …` reading `stat` directly, no `ps`.
- **Exercises** — six: (1) decode a given `SigCgt` hex mask to signal names;
  (2) explain from `/proc/PID/status` why a process survived `SIGTERM`;
  (3) produce a zombie deliberately and then reap it; (4) explain why
  `kill -9` on a `T`-stopped process appears to do nothing until `SIGCONT`;
  (5) given `strace` output, name the syscall that blocked; (6) explain what
  changes about PID 1's obligations inside a container.
- **Anti-patterns** — Mistake 1 (memorising `kill` flags rather than the signal
  model) and Mistake 5 (never having run `strace`).
- **Where this shows up in AWS** — the shell-form `ENTRYPOINT` trap: ECS sends
  `SIGTERM` to PID 1, PID 1 is `/bin/sh`, `sh` does not forward it, the app
  never drains, and the task is `SIGKILL`ed at `stopTimeout`. Both fixes named:
  exec-form `ENTRYPOINT`, or `initProcessEnabled` / `tini` as PID 1.

- [ ] **Step 2: Write `labs/day02/break.sh`**

```sh
# (a) a process that traps SIGTERM and refuses to leave
in_app 'setsid sh -c "trap \"\" TERM; exec sleep 100000" >/dev/null 2>&1 &'
# (b) zombies: a parent that forks and never waits
in_app 'setsid sh -c "while :; do (sleep 0.1 &) ; sleep 5; done" >/dev/null 2>&1 &'
# (c) a stopped process that looks alive and ignores TERM
in_app 'setsid sh -c "exec sleep 100000" >/dev/null 2>&1 &'
sleep 1
in_app 'kill -STOP $(pgrep -f "sleep 100000" | tail -1)'
symptom "Three processes on app will not exit. Two ignore SIGTERM; one is multiplying."
```

- [ ] **Step 3: Write `labs/day02/verify.sh`**

Passes when: no process on `app` has state `T`; the zombie count is zero; and
the trapped `sleep 100000` is gone.

```sh
stopped=$(in_app 'grep -l "^State:.T" /proc/[0-9]*/status 2>/dev/null | wc -l')
zombies=$(in_app 'grep -l "^State:.Z" /proc/[0-9]*/status 2>/dev/null | wc -l')
sleepers=$(in_app 'pgrep -f "sleep 100000" | wc -l')
[ "$stopped" -eq 0 ] && [ "$zombies" -eq 0 ] && [ "$sleepers" -eq 0 ] \
  && echo "PASS: no stopped, zombie, or trapped processes remain." \
  || { echo "FAIL: stopped=$stopped zombies=$zombies sleepers=$sleepers" >&2; exit 1; }
```

- [ ] **Step 4: Write `README.md`, `SOLUTION.md`, `teardown.md`**

`SOLUTION.md` chain: enumerate states from `/proc/*/status` → three distinct
causes, not one → for (a) read `SigCgt`/`SigIgn` and prove `TERM` is ignored,
fix with `SIGKILL`; for (b) find the parent through `PPid` and prove it never
calls `wait`, fix by killing the *parent*, with the note that killing zombies
directly is impossible because they are already dead; for (c) prove `State: T`,
explain that a stopped process cannot process any signal until `SIGCONT`, fix
with `kill -CONT` then `kill -TERM`.

`README.md` states the constraint: solve all three **without restarting `app`**,
and name each cause before fixing it.

- [ ] **Step 5: Verify**

- `bash -n labs/day02/break.sh labs/day02/verify.sh`
- `grep -c '^## ' content/day02.md` → `10`
- `grep -c '\*\*Hint:\*\*' content/day02.md` → `6`
- `grep -n 'SigCgt' content/day02.md` → present, and the file references
  `primers/proc-field-reference.md` rather than restating the table
- `grep -n 'stopTimeout\|exec form\|initProcessEnabled' content/day02.md`
  → the AWS section names the trap and both fixes
- `grep -n 'D state\|D-state' content/day02.md` → present in Core concepts,
  **absent** from the lab files

---

### Task 6: Day 3 — the file descriptor table

**Files:**
- Create: `linux_ops_mastery/content/day03.md`
- Create: `linux_ops_mastery/labs/day03/{README.md,break.sh,verify.sh,SOLUTION.md,teardown.md}`

**Interfaces:**
- Consumes: `app`'s `/log?n=N` endpoint and `seed/gen-logs.sh` (Task 2);
  Day 1's deleted-fd technique.
- Produces: the `awk`/`sed`/`grep` subset that Day 6 reuses on `tcpdump` and
  `curl -v` output.

- [ ] **Step 1: Write `content/day03.md`**

Budget: `3 h`. Truth: fd table.

- **Read the file first** — `ls -l /proc/PID/fd` showing that every entry is a
  symlink to a file, socket, pipe, or `anon_inode`; `cat /proc/PID/fdinfo/N`
  for `pos`, `flags`, and what a large `pos` on a deleted file proves.
- **Derive the tool** — `lsof -p PID` mapped onto the directory listing;
  `lsof -i` shown to be the same table filtered to socket entries.
- **Core concepts** — descriptors 0/1/2 and that they are only a convention;
  redirection as descriptor surgery (`2>&1` explained as *duplicate fd 2 onto
  whatever fd 1 currently points at*, and why `>file 2>&1` and `2>&1 >file`
  differ); pipes as a pair of descriptors; `tee`; here-documents; process
  substitution; the triage trio with the operator subset only — `grep -c/-n/-v/
  -A/-B/-F`, `sed -n 'N,Mp'` and `s///`, `awk '{print $N}'`, `awk -F` and
  simple aggregation; `sort | uniq -c | sort -rn` as the single most useful
  operator pipeline; `find -exec` versus `xargs -0` and when each is correct;
  exit codes, `$?`, why a pipeline's status is the *last* command's, and
  `set -euo pipefail` with `PIPESTATUS`.
- **Lab** — the log-triage incident. Success signal: `verify.sh` exits 0.
- **Strip the toolbox** — repeat the triage in `slim` with busybox `grep`/`awk`
  and no `lsof`.
- **Exercises** — six: (1) find the one 500 among 200 000 lines and report its
  `req_id`; (2) produce the top five paths by request count with one pipeline;
  (3) explain the difference between the two redirection orders above;
  (4) identify which process holds a rotated log open using only `/proc`;
  (5) write a `find`+`xargs -0` that is safe with spaces in filenames;
  (6) explain why `grep pattern file | head -1` can exit non-zero.
- **Anti-patterns** — Mistake 3 (`bat`/`ripgrep` muscle memory on a busybox
  box) and Mistake 1 (collecting `awk` one-liners instead of the field model).
- **Where this shows up in AWS** — CloudWatch agent or Fluent Bit holding a
  rotated file open; why `logrotate` with `copytruncate` exists; why disk usage
  keeps climbing on an EC2 host whose logs "are rotating fine".

- [ ] **Step 2: Write `labs/day03/break.sh`**

```sh
in_app 'sh /labs/fleet/seed/gen-logs.sh 100000 --needle deadbeef'
in_app 'cp /var/log/app.log /var/log/app.log.1 && : > /var/log/app.log'
in_app 'setsid sh -c "exec tail -f /var/log/app.log.1 >/dev/null 2>&1" &'
in_app 'rm -f /var/log/app.log.1'
symptom "One request failed in the last rotation, and /var/log keeps filling after rotation."
```

Note for the implementer: `/labs` is the read-only bind mount of the repo's
`labs/` directory, declared on both `ws` and `app` in Task 2, Step 5. If it is
absent, stop and fix Task 2 rather than working around it here.

- [ ] **Step 3: Write `labs/day03/verify.sh`**

Passes when no deleted file remains open under `/var/log` **and** a file
`/tmp/answer` on `app` contains the string `deadbeef` — the learner writes the
found `req_id` there, which proves the triage was actually performed rather than
the symptom merely cleared.

- [ ] **Step 4: Write `README.md`, `SOLUTION.md`, `teardown.md`**

`README.md` states both deliverables explicitly: write the failing request's
`req_id` into `/tmp/answer` on `app`, and release the held file.

`SOLUTION.md` chain: `df` shows growth → `du` disagrees → `/proc/*/fd` shows a
deleted `app.log.1` → the holder is a `tail` → fix by killing the holder → then
the triage: `grep -n 'status=500' `, extract `req_id` with `awk -F'req_id=' `,
write it to `/tmp/answer`. Includes the busybox variant of every command.

- [ ] **Step 5: Verify**

- `bash -n labs/day03/break.sh labs/day03/verify.sh`
- `grep -c '^## ' content/day03.md` → `10`
- `grep -c '\*\*Hint:\*\*' content/day03.md` → `6`
- `grep -n '2>&1 >file\|>file 2>&1' content/day03.md` → both orders discussed
- `grep -n 'copytruncate' content/day03.md` → present in the AWS section

---

### Task 7: Day 4 — resources and the cgroup boundary

**Files:**
- Create: `linux_ops_mastery/content/day04.md`
- Create: `linux_ops_mastery/labs/day04/{README.md,break.sh,verify.sh,SOLUTION.md,teardown.md}`

**Interfaces:**
- Consumes: `app`'s `mem_limit: 64m`, `cpus: 0.20`, `/balloon?mb=N`,
  `/burn?seconds=N` (Task 2); the `## /sys/fs/cgroup (v2)` primer anchor
  (Task 3).
- Produces: the USE checklist that Day 7's gauntlet scores against.

- [ ] **Step 1: Write `content/day04.md`**

Budget: `3 h`. Truth: cgroup / namespace boundary.

- **Read the file first** — `/proc/loadavg`; `/proc/stat`'s `cpu` line fields
  (user, nice, system, idle, iowait, irq, softirq, steal) and that these are
  **cumulative jiffies**, so a rate requires two samples; `/proc/meminfo`;
  `/proc/pressure/{cpu,io,memory}` and how to read `some avg10`; then the
  cgroup files: `memory.current`, `memory.max`, `memory.events`, `cpu.max`,
  `cpu.stat`.
- **Derive the tool** — `uptime`, `free -m`, `top`, `vmstat 1` each shown as a
  formatter over the files above; the explicit statement that `free` inside a
  container reads the **host's** `/proc/meminfo`, which is the entire reason the
  lab's symptom is confusing.
- **Core concepts** — load average counts runnable **plus** uninterruptible, so
  it is a queue-length metric, not a CPU metric; `%iowait` is idle time with
  pending I/O, not work; RSS versus shared versus page cache, and why
  `MemAvailable` is the only number worth quoting; **tmpfs pages are charged to
  the memory cgroup that faults them in**, which is why a tmpfs mount can OOM a
  container that appears to be using little memory (and why this fleet's
  `/var/log` is 24m inside a 64m limit); the OOM killer, `oom_score`,
  `oom_score_adj`, and how a cgroup OOM differs from a global one; cgroup v2
  hierarchy and delegation; CPU quota as `quota/period`, and why a 0.20 CPU
  limit throttles a single-threaded burst even at trivial load average; PSI as
  the metric that answers "is this saturation or just utilisation".
- **Lab** — two-part: an OOM kill and a throttle. Success: `verify.sh` 0.
- **Strip the toolbox** — in `slim`, compute a 1-second CPU utilisation rate
  from two `/proc/stat` samples with `awk`, no `top`.
- **Exercises** — six: (1) from two `/proc/stat` samples compute per-CPU busy
  percentage; (2) explain a load of 8.0 at 5 % CPU; (3) from `memory.events`
  prove a cgroup OOM occurred and say how many times; (4) compute the effective
  CPU limit from `cpu.max` and predict `nr_throttled` behaviour;
  (5) explain why `free` shows 12 GB available inside a 64 MB container;
  (6) given PSI `some avg10=45.0`, state what it means for user-visible latency.
- **Anti-patterns** — Mistake 2 (quoting `free`'s free column, reading load as
  CPU) and Mistake 4 (only ever having watched a healthy box).
- **Where this shows up in AWS** — ECS `memory` (hard, OOM-kills) versus
  `memoryReservation` (soft); why `ECS task stopped: OutOfMemoryError` shows no
  application stack trace; CPU units → `cpu.max` quota and the p99 latency
  cliff that CloudWatch `CPUUtilization` averages away.

- [ ] **Step 2: Write `labs/day04/break.sh`**

```sh
compose exec -T app sh -c 'wget -qO- "http://127.0.0.1:8080/burn?seconds=45" &' || true
sleep 2
compose exec -T app sh -c 'wget -qO- "http://127.0.0.1:8080/balloon?mb=120"' >/dev/null 2>&1 || true
symptom "The app container restarted on its own, and requests are slow before it does."
```

Implementer note: the balloon request is expected to fail — the process is
OOM-killed mid-request. `|| true` keeps `break.sh` exiting 0, which is required
of every break script.

- [ ] **Step 3: Write `labs/day04/verify.sh`**

This lab's deliverable is a *diagnosis*, not a repair — the container recovers
by itself. `verify.sh` therefore checks the learner's written findings:
`/tmp/findings` on `app` must contain both the literal `oom_kill` count read
from `memory.events` and the `nr_throttled` value read from `cpu.stat`, one per
line, in the form `oom_kill=<n>` and `nr_throttled=<n>`. Compare each against
the live cgroup files and pass only on an exact match.

- [ ] **Step 4: Write `README.md`, `SOLUTION.md`, `teardown.md`**

`SOLUTION.md` chain: symptom "restarted on its own" → the container's exit code
137 → claim: killed by signal 9 → is it the host OOM killer or the cgroup's?
→ proof from `memory.events` `oom_kill` incrementing → `memory.max` = 64 MiB
against `memory.current` at the peak → therefore a **cgroup** OOM, and
`free` inside the container is irrelevant because it reports host memory. Then
the second thread: latency before the kill → `cpu.max` shows `20000 100000`
→ `cpu.stat` `nr_throttled` climbing → the burst was throttled to 20 % of one
core. Ends by naming the two ECS settings that produce each symptom.

- [ ] **Step 5: Verify**

- `bash -n labs/day04/break.sh labs/day04/verify.sh`
- `grep -c '^## ' content/day04.md` → `10`
- `grep -c '\*\*Hint:\*\*' content/day04.md` → `6`
- `grep -n 'memory.events\|cpu.stat\|nr_throttled\|MemAvailable' content/day04.md`
  → all four present
- `grep -n "reads the \*\*host's\*\*\|host's /proc/meminfo" content/day04.md`
  → the container-`free` caveat is stated in Derive the tool
- `grep -n 'memoryReservation' content/day04.md` → present in the AWS section

---

### Task 8: Day 5 — identity, permission, and service management

**Files:**
- Create: `linux_ops_mastery/content/day05.md`
- Create: `linux_ops_mastery/labs/day05/{README.md,break.sh,verify.sh,SOLUTION.md,teardown.md}`
- Create: `linux_ops_mastery/labs/day05/units/labs-api.service`

**Interfaces:**
- Consumes: the `sysd` service from `docker-compose.sysd.yml` (Task 2); the
  `CapEff` row of the `## /proc/PID/status` primer (Task 3); the mask-decoding
  procedure established on Day 2 (Task 5).
- Produces: nothing later tasks depend on except the gauntlet's permission
  incident (Task 10).

**This is the only task that needs the `sysd` overlay.** Both `break.sh` and
`verify.sh` must call `compose -f ../fleet/docker-compose.yml -f
../fleet/docker-compose.sysd.yml`; add a `compose_sysd()` wrapper to the top of
each script rather than editing `common.sh`, so no other day is affected.

- [ ] **Step 1: Write `content/day05.md`**

Budget: `3 h`. Truth: process table (identity is a property of a process).

- **Read the file first** — `/etc/passwd` and `/etc/group` field by field;
  `/proc/PID/status` `Uid:` and `Gid:` lines showing all four values (real,
  effective, saved, filesystem) and the `CapEff` bitmask; `stat -c '%A %U %G
  %a'` on a file, with the mode decoded bit by bit.
- **Derive the tool** — `id`, `ls -l`, and `getcap` shown as formatters over
  the above; `capsh --decode` against the raw `CapEff` hex.
- **Core concepts** — real versus effective uid and how `setuid` changes one but
  not the other; mode bits; the **directory execute bit as the most common
  invisible denial** — a `0777` file inside a `0644` directory is unreachable,
  and this is the lab; setgid on directories; the sticky bit and why `/tmp` has
  it; `umask` applying at creation, not afterwards; `/etc/shadow` and why it is
  `0640 root:shadow`; `sudo` and its audit trail; **capabilities** as the
  decomposition of root, with `CAP_NET_RAW` (`ping`), `CAP_NET_BIND_SERVICE`
  (ports < 1024), and `CAP_SYS_PTRACE` (which the lab fleet grants `ws`)
  as the three worth knowing; ACLs in three sentences (`getfacl`/`setfacl`,
  and the `+` in `ls -l`).
- systemd: unit file anatomy (`[Unit] [Service] [Install]`); `Type=simple`
  versus `notify` versus `oneshot`; `After=` orders but does not require, while
  `Requires=` requires but does not order — the single most common unit bug;
  `systemctl status/start/enable/daemon-reload` and what each actually does;
  `journalctl -u X -b --since` and `-p err`; targets and the boot sequence;
  timers versus cron.
- **The contrast that matters** — a table with columns *systemd
  responsibility | what replaces it in a container*: supervision → the
  orchestrator's restart policy; logging → stdout/stderr collected by the log
  driver; dependency ordering → `dependsOn` in the task definition or a
  readiness check; environment → the task definition; PID 1 reaping → `tini`
  or `initProcessEnabled`.
- **Lab** — two incidents: a permission denial that survives `chmod 777`, and a
  unit that will not start. Success signal: `verify.sh` exits 0.
- **Strip the toolbox** — decode `CapEff` by hand in `slim` where `capsh` does
  not exist, using the bit positions listed in the primer.
- **Exercises** — six: (1) explain why reading a `0777` file fails and name the
  exact bit; (2) predict the mode of a file created under `umask 027`;
  (3) find every setuid binary on the system and explain the risk of one of
  them; (4) explain how unprivileged `ping` works on a modern distro;
  (5) given a unit that starts before its database, write the correct
  `After=`/`Requires=` pair and explain why one alone is insufficient;
  (6) name what replaces each of three systemd responsibilities in ECS.
- **Anti-patterns** — Mistake 6 (reaching for `chmod 777` instead of reading
  the denial) and Mistake 2 (believing `ls -l` on the file alone explains
  access).
- **Where this shows up in AWS** — a container that runs fine as root locally
  and fails under a non-root `user:` in the task definition; bind-mounted EFS
  directory permissions; why dropping to non-root breaks a port-80 listener and
  what to do instead.

- [ ] **Step 2: Write `labs/day05/units/labs-api.service`**

A deliberately broken unit, shipped as a file the learner reads and repairs:

```ini
[Unit]
Description=Labs API
Requires=labs-db.service

[Service]
Type=simple
ExecStart=/usr/local/bin/labs-api --port 8080
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Two seeded defects: `Requires=` without a matching `After=` (so ordering is
undefined), and `ExecStart` pointing at a path that `break.sh` never creates.
The repair is to add `After=labs-db.service` and correct the path to the
`/usr/local/bin/labs-api` shell stub that `break.sh` *does* install under a
different name.

- [ ] **Step 3: Write `labs/day05/break.sh`**

```sh
compose_sysd() {
  docker compose -p linuxops \
    -f "${LABS_DIR}/fleet/docker-compose.yml" \
    -f "${LABS_DIR}/fleet/docker-compose.sysd.yml" "$@"
}
in_sysd() { compose_sysd exec -T sysd bash -c "$1"; }

# Incident 1: the invisible denial — file is 0777, its directory is not traversable
in_sysd 'mkdir -p /srv/reports && echo "quarterly numbers" > /srv/reports/q3.txt'
in_sysd 'chmod 777 /srv/reports/q3.txt && chmod 600 /srv/reports'
in_sysd 'id -u appuser >/dev/null 2>&1 || useradd -m appuser'

# Incident 2: the unit that will not start
in_sysd 'install -m 0755 /dev/stdin /usr/local/bin/labs-apid <<"EOF"
#!/bin/sh
echo "labs-api listening"; exec sleep infinity
EOF'
in_sysd 'printf "[Unit]\nDescription=Labs DB\n[Service]\nType=simple\nExecStart=/bin/sleep infinity\n[Install]\nWantedBy=multi-user.target\n" > /etc/systemd/system/labs-db.service'
in_sysd 'cp /labs/day05/units/labs-api.service /etc/systemd/system/labs-api.service'
in_sysd 'systemctl daemon-reload && systemctl start labs-api.service' || true

symptom "appuser cannot read /srv/reports/q3.txt (mode 777), and labs-api.service will not start."
```

- [ ] **Step 4: Write `labs/day05/verify.sh`**

Passes when all three hold: `sudo -u appuser cat /srv/reports/q3.txt` succeeds
inside `sysd`; `systemctl is-active labs-api.service` prints `active`; and the
unit file on disk contains an `After=labs-db.service` line. The third check is
what stops the learner from "fixing" it by deleting `Requires=`.

- [ ] **Step 5: Write `README.md`, `SOLUTION.md`, `teardown.md`**

`README.md` must state the bring-up for this day specifically:

```bash
cd linux_ops_mastery/labs/fleet
docker compose -p linuxops -f docker-compose.yml -f docker-compose.sysd.yml up -d --build sysd
```

and point at the fleet README's Colima fallback if `sysd` exits immediately.

`SOLUTION.md`: two chains. First — `ls -l` on the file proves nothing is wrong
with the file, so the claim must move up the path; `namei -l
/srv/reports/q3.txt` proves the directory lacks `x` for others; fix with
`chmod o+rx /srv/reports`, not `chmod 777`, and state why the narrower fix is
correct. Second — `systemctl status` gives the exit reason,
`journalctl -u labs-api -b` gives `203/EXEC`, which means the binary path does
not exist; `ls /usr/local/bin` shows `labs-apid`; fix the path, add
`After=labs-db.service`, `daemon-reload`, restart. Explains why
`daemon-reload` is required and what happens without it.

- [ ] **Step 6: Verify**

- `bash -n labs/day05/break.sh labs/day05/verify.sh`
- `grep -c '^## ' content/day05.md` → `10`
- `grep -c '\*\*Hint:\*\*' content/day05.md` → `6`
- `grep -n 'After=\|Requires=' content/day05.md` → the ordering-vs-requirement
  distinction is stated explicitly
- `grep -n 'namei' labs/day05/SOLUTION.md` → present
- `grep -n 'chmod 777' labs/day05/SOLUTION.md` → present **as the rejected
  fix**, with the reason stated
- `grep -n 'compose_sysd' labs/day05/break.sh labs/day05/verify.sh` → in both
- `grep -rn 'compose_sysd' linux_ops_mastery/labs/lib/common.sh` → **no hits**
  (the overlay must not leak into the shared helper)

---

### Task 9: Day 6 — the network, seen from the box

**Files:**
- Create: `linux_ops_mastery/content/day06.md`
- Create: `linux_ops_mastery/labs/day06/{README.md,break.sh,verify.sh,SOLUTION.md,teardown.md}`

**Interfaces:**
- Consumes: `proxy`, `app`, `db` and `linuxops_net` (Task 2); `app`'s
  `BIND_ADDR` env var and `/fail?code=C` endpoint; the `## /proc/net/tcp`
  primer anchor with its hex-address worked example (Task 3).
- Produces: the five-rung ladder that Task 10's gauntlet draws two incidents
  from.

- [ ] **Step 1: Write `content/day06.md`**

Budget: `3 h`. Truth: fd table (a socket is a descriptor) plus the network
namespace.

- **Read the file first** — `/proc/net/tcp` and `/proc/net/tcp6`, decoding
  `local_address` from little-endian hex (the primer's worked example),
  the `st` column, and the `inode` that joins back to `/proc/PID/fd`;
  `/proc/net/route`; `/etc/resolv.conf` with `nameserver`, `search`, and
  `options ndots:N`; `/etc/nsswitch.conf`'s `hosts:` line.
- **Derive the tool** — `ss -ltnp` mapped onto `/proc/net/tcp` line by line;
  `ip route` onto `/proc/net/route`.
- **Core concepts** — interfaces and addresses with `ip addr`/`ip link`, and
  why `ifconfig` misreports secondary addresses; the routing table read as a
  decision procedure (longest prefix, then metric), and `ip route get <ip>` as
  the way to ask the kernel to decide out loud; DNS resolution order and the
  **`ndots` trap** — with `ndots:5`, `db` becomes `db.svc.local.`,
  `db.local.`, … before ever being tried as an absolute name, which is why one
  lookup can cost five round trips; listening on `127.0.0.1` versus `0.0.0.0`
  and why the former is invisible from every other container; TCP states, the
  handshake, `TIME_WAIT` and ephemeral port exhaustion; `curl -v` read as a
  protocol trace (DNS → connect → TLS → request → response); `openssl s_client
  -connect host:443 -servername host` for certificate chain and SNI problems;
  MTU and the black-hole symptom (small requests work, large ones hang);
  reading — not writing — `nftables`/`iptables` rules; the two or three
  `tcpdump` invocations an operator actually needs.
- **Lab** — the five-rung ladder. Success signal: `verify.sh` exits 0 for the
  fault currently injected.
- **Strip the toolbox** — in `slim`, determine what is listening using only
  `cat /proc/net/tcp` and the hex decode, with no `ss` and no `netstat`.
- **Exercises** — six: (1) decode a given `/proc/net/tcp` line to
  `ip:port state`; (2) explain why a service reachable with `curl localhost`
  inside its own container is unreachable from `proxy`; (3) compute how many
  DNS queries `ndots:5` generates for the name `db`; (4) given `ip route get`,
  name the interface and source address the kernel chose; (5) distinguish a DNS
  failure from a routing failure from a firewall drop using exactly one command
  each; (6) explain what a hang after the TCP handshake but before the first
  byte of response usually means.
- **Anti-patterns** — Mistake 2 (`ping` succeeding "proves" the service is up)
  and Mistake 1 (memorising `tcpdump` flags without the ladder to know when to
  reach for it).
- **Where this shows up in AWS** — ECS `awsvpc` mode giving each task its own
  ENI and its own `127.0.0.1`, so sidecar-style localhost assumptions break;
  security groups producing a silent drop that looks exactly like a routing
  problem; the `ndots:5` cost inside a cluster; NLB health checks failing
  because the app bound to `127.0.0.1`.

- [ ] **Step 2: Write `labs/day06/break.sh`**

Takes a fault number `1`–`5` as `$1`, defaulting to `1`; accepts `random` to
choose one without revealing it. Each fault is injected as follows:

| # | Fault | Injection |
|---|---|---|
| 1 | DNS broken | overwrite `/etc/resolv.conf` on `proxy` with an unreachable `nameserver 10.255.255.1`, then `nginx -s reload`. The reload is required: nginx reads its resolver configuration at load time, so without it the fault does not reach the proxy path |
| 2 | Route removed | `ip route del default` inside `proxy` (uses the `NET_ADMIN` capability granted in Task 2, Step 5) |
| 3 | Firewall drop | `nft add rule` on `proxy` dropping output to `app`'s port 8080 |
| 4 | Wrong bind address | restart `app` with `BIND_ADDR=127.0.0.1` |
| 5 | Application-layer failure | `app` returns 502 via `/fail?code=502` sticky mode |

The symptom line is identical for all five — `"http://localhost:8080/ through
proxy returns nothing useful."` — because an identical symptom with five
distinct causes is the entire point of the ladder.

Record the injected fault number in `/tmp/.day06-fault` **inside the `proxy`
container** so `verify.sh` can check the right thing without the learner being
able to see it from the host by accident.

- [ ] **Step 3: Write `labs/day06/verify.sh`**

Reads the fault number, then asserts both: the specific fault is undone (DNS
resolves / default route present / no drop rule / `app` bound to `0.0.0.0` /
`app` returns 200), **and** an end-to-end request through `proxy` returns HTTP
200. Prints which rung was at fault only *after* passing.

- [ ] **Step 4: Write `README.md`, `SOLUTION.md`, `teardown.md`**

`README.md`: run `bash break.sh 1` … `bash break.sh 5` in order the first time,
then `bash break.sh random` for re-practice. States the rule — **name the rung
before touching anything.**

`SOLUTION.md`: the ladder as a table — *Rung | Question | Command | The file
that proves it* — followed by one chain per fault, each ending with the
minimum command that would have distinguished this fault from the other four in
a single step.

- [ ] **Step 5: Verify**

- `bash -n labs/day06/break.sh labs/day06/verify.sh`
- `grep -c '^## ' content/day06.md` → `10`
- `grep -c '\*\*Hint:\*\*' content/day06.md` → `6`
- `grep -n 'ndots' content/day06.md` → present in Core concepts and the AWS
  section
- `grep -n 'awsvpc' content/day06.md` → present
- `grep -c 'random' labs/day06/break.sh` → ≥ 1
- `grep -n 'NET_ADMIN' linux_ops_mastery/labs/fleet/docker-compose.yml`
  → present on `proxy`

---

### Task 10: Day 7 — neovim as an operator's tool, and the gauntlet

**Files:**
- Create: `linux_ops_mastery/content/day07.md`
- Create: `linux_ops_mastery/labs/day07/{README.md,gauntlet.sh,verify.sh,ANSWERS.md,teardown.md}`
- Create: `linux_ops_mastery/labs/day07/init.lua`

**Interfaces:**
- Consumes: every prior day's break mechanism; the `nvim-cheatsheet.md` grammar
  (Task 3); the shipped `init.lua` in `Dockerfile.ws` (Task 2, Step 4).
- Produces: `COVERAGE.md`'s inputs — the list of what was actually drilled.

**Note:** this day has `gauntlet.sh` in place of `break.sh` and `ANSWERS.md` in
place of `SOLUTION.md`. `ANSWERS.md` opens with a bold spoiler warning and is
not to be read until all five incidents have a written chain in `journal.md`.

- [ ] **Step 1: Write `content/day07.md`**

Budget: `3 h — 1.5 h neovim + 1.5 h gauntlet`. Truth: all four.

- **Why this matters** — the two things that separate someone who *studied*
  from someone who *operates*: editing confidently on a machine with no GUI,
  and reaching a diagnosis under a clock with nobody to ask.
- **Read the file first** — for this day the "file" is `journal.md`: the
  learner rereads their own six chains and marks, for each, the single step
  where they guessed instead of proved.
- **Core concepts (neovim, 1.5 h)** — `:g/pattern/cmd` and `:v//` as the
  highest-leverage ex command, with four worked examples (delete all matching
  lines, move matches to the end, number matches, run `:normal` on matches);
  registers, named and numbered; recording a macro, replaying with a count, and
  the reason a well-recorded macro starts with `0`; buffers versus windows
  versus tabs; the argument list and `:argdo %s///ge | update`; quickfix
  populated from `:grep` or `:cexpr` and traversed with `:cn`/`:cp`, plus
  `:cdo`; `:%!sort -u` and `:%!jq .` as buffer-through-shell filters; `:r !cmd`;
  marks and the jump list; `:diffthis` on two buffers;
  `:w !sudo tee % >/dev/null` for the file opened read-only.
- **The minimal `init.lua`** — reproduced inline, ≤ 30 lines, plugin-free,
  described as *safe to paste onto any server you have never seen*, with a
  one-line comment on why each setting is there and why nothing else is.
- **The gauntlet (1.5 h)** — the rules: 15 minutes per incident, a written
  chain before any fix, no reading `ANSWERS.md`, and a self-scored result.
- **Exercises** — six neovim drills, each with Hint and Solution sketch:
  (1) delete every line matching `DEBUG` from a 40 000-line log in one command;
  (2) append `;` to the end of 12 specific lines using a macro;
  (3) load every `.conf` under `/etc/nginx` into the argument list and replace a
  value across all of them; (4) build a quickfix list from a `grep` for
  `status=500` and step through it; (5) sort and dedupe a buffer in place;
  (6) save a root-owned file you opened as a non-root user.
- **Anti-patterns** — Mistake 7 (tutorials instead of arrow-key deprivation)
  and Mistake 4 (practising on files that do not matter).
- **Where this shows up in AWS** — `ecs execute-command` gives you a shell with
  no editor you configured, no plugins, and often no `$HOME`; the 30-line
  `init.lua` and `:g//` are the difference between fixing a config in 90 seconds
  and copying it to your laptop and back.

- [ ] **Step 2: Write `labs/day07/gauntlet.sh`**

Takes an incident number `1`–`5`, or `all` to run them in sequence with a timer
printed between each. The five incidents, each a **recombination** so no chain
from days 1–6 transfers verbatim:

| # | Incident | Draws on |
|---|---|---|
| 1 | `/var/log` full on `app`, but the holding process was started with `exec -a` under a misleading name, so `ps` output actively points the wrong way | Days 1 + 3 |
| 2 | `app` is `active` per its supervisor but every request times out; the process is in `T` state | Day 2 |
| 3 | Requests succeed at 1 rps and fail at 20 rps; `cpu.max` throttling, no OOM | Day 4 |
| 4 | A config file is unreadable by the service user after a deploy; setgid directory plus a bad `umask` | Day 5 |
| 5 | `proxy` reaches `app` but not `db`; `db` is listening on the wrong address **and** a stale DNS entry masks it — two faults at once | Day 6, deliberately harder |

Each incident prints only its symptom line and starts a timer. Incident 5 is
explicitly two faults, because the fifth thing an operator must learn is that
fixing one cause and seeing no improvement does not mean the first diagnosis was
wrong.

- [ ] **Step 3: Write `labs/day07/verify.sh`**

Takes the incident number and asserts the specific repair, exactly as the
per-day `verify.sh` scripts do. With `all`, runs the five checks and prints a
scorecard: incident, passed y/n, and the elapsed time recorded by
`gauntlet.sh` in `/tmp/.gauntlet-times` on `ws`.

- [ ] **Step 4: Write `README.md`, `ANSWERS.md`, `init.lua`, `teardown.md`**

`README.md`: the rules, the 15-minute-per-incident budget, the requirement to
write the chain first, and the instruction not to open `ANSWERS.md` until all
five are done or the 90 minutes are spent.

`ANSWERS.md`: opens with `> **SPOILERS.** Do not read until your five chains are
written.` Then one full chain per incident, each closing with *the one command
that would have told you most, soonest* — and for incident 5, an explicit note
on how to recognise a two-fault situation rather than doubting a correct first
diagnosis.

`init.lua`: the same ≤ 30-line config shipped in `Dockerfile.ws`, extracted as a
standalone file the learner can copy to a real server. Must be byte-identical
to the heredoc in `Dockerfile.ws` — Task 11 checks this.

- [ ] **Step 5: Verify**

- `bash -n labs/day07/gauntlet.sh labs/day07/verify.sh`
- `grep -c '^## ' content/day07.md` → `10`
- `grep -c '\*\*Hint:\*\*' content/day07.md` → `6`
- `grep -n 'SPOILERS' labs/day07/ANSWERS.md` → line 1
- `grep -c '^| [1-5] ' labs/day07/README.md` → `5` (all five incidents listed)
- `grep -n 'ecs execute-command' content/day07.md` → present
- `wc -l < labs/day07/init.lua` → ≤ 30

---

### Task 11: Coverage audit and final consistency pass

**Files:**
- Create: `linux_ops_mastery/COVERAGE.md`
- Modify: any file the audit finds inconsistent

**Interfaces:**
- Consumes: all seven `content/dayNN.md` files and all seven `labs/dayNN/`
  directories. **This task runs last.**
- Produces: the learner-facing proof that nothing systematic was skipped by
  accident.

- [ ] **Step 1: Write `COVERAGE.md`**

Three sections.

`## LPIC-1 objective coverage` — a table with columns *Objective | Topic | Day |
Where*. Walk the published LPIC-1 (101-500 and 102-500) topic areas and map each
to the day and section that covers it. Every row is one of: a day number, or
the literal `SKIPPED` with a pointer to section three.

`## LFCS domain coverage` — the same treatment for the Linux Foundation
Certified SysAdmin domains (Essential Commands; Operation of Running Systems;
User and Group Management; Networking; Service Configuration; Storage
Management).

`## Deliberately skipped, and why` — one short paragraph each, no hedging:
printing/CUPS, X11 and display managers, SysV init and `/etc/init.d`, GRUB
internals and bootloader repair, LVM and RAID administration, mail transfer
agents, localisation and time-zone administration, package build tooling. Each
paragraph names the objective, states that it is skipped, and gives the reason
in terms of this learner's job — for example, that bootloader repair does not
occur on an ECS task or an EBS-backed instance you can simply replace.

The section closes with a short note: **these are gaps by choice, not by
accident, and here is the cheapest way to close each one later if the job ever
requires it** — one line per skipped topic.

- [ ] **Step 2: Run the cross-file consistency audit**

Run each check and fix what fails:

```bash
cd linux_ops_mastery
# Nine skeleton sections in every day file
for f in content/day0*.md; do printf '%s %s\n' "$f" "$(grep -c '^## ' "$f")"; done
# Six hints and six solution sketches in every day file
for f in content/day0*.md; do
  printf '%s hints=%s sketches=%s\n' "$f" \
    "$(grep -c '\*\*Hint:\*\*' "$f")" "$(grep -c '\*\*Solution sketch:\*\*' "$f")"
done
# Every break/verify script parses
for f in labs/day0*/{break,verify,gauntlet}.sh; do [ -f "$f" ] && bash -n "$f"; done
# Every day file points at its own lab dir
for n in 01 02 03 04 05 06 07; do grep -q "labs/day$n" "content/day$n.md" \
  || echo "MISSING lab pointer in day$n"; done
# Mistake citations resolve to STRATEGY.md
grep -ho 'Mistake [1-7]' content/*.md | sort -u
# No stray credentials or account IDs
grep -rnE '[0-9]{12}|AKIA[0-9A-Z]{16}' . || echo "clean"
# No :latest tags
grep -rn ':latest' labs/ || echo "clean"
# Line length
awk 'length > 90 {print FILENAME": "FNR}' $(find . -name '*.md') | head
# init.lua is byte-identical in both places
diff <(sed -n '/init.lua/,/^EOF$/p' labs/fleet/Dockerfile.ws | sed '1d;$d') \
     labs/day07/init.lua && echo "init.lua matches"
```

- [ ] **Step 3: Check the hour budget reconciles**

Confirm every `content/dayNN.md` carries a `**Budget:**` line, and that the
seven sum to 21 h with Day 1 as `2 h + 1 h` and Day 7 as `1.5 h + 1.5 h`:

```bash
grep -h '^\*\*Budget:\*\*' content/day0*.md
```

- [ ] **Step 4: Verify**

- `COVERAGE.md` contains all three `## ` sections
- `grep -c 'SKIPPED' COVERAGE.md` → ≥ 8 (one per deliberately skipped topic)
- Every check in Step 2 reports clean or has been fixed
- `bash labs/verify-teardown.sh` exists and parses (`bash -n`) — it is **not
  run**, per G2

---

## Execution Handoff

Plan complete and saved to
`linux_ops_mastery/docs/superpowers/plans/2026-09-06-linux-ops-mastery-plan.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — a fresh subagent per task, reviewed
   between tasks. Tasks 1–3 dispatch in parallel, then Tasks 4–10 in parallel,
   then Task 11 alone. Roughly three waves.
2. **Inline Execution** — tasks run in this session with checkpoints for review.

Whichever is chosen: **no git commands in any dispatch** (G1), and **no
container is ever started during authoring** (G2).

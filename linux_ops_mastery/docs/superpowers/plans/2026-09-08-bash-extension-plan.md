# Bash Scripting Extension (day08–10) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `linux_ops_mastery/` with three bash scripting days (day08–10) that
teach the process-tree model through break/diagnose/fix labs, producing a reusable
`bash/ops-toolkit/` of four hardened scripts.

**Architecture:** Each day follows the identical daily loop from days 1–7. Content
files live in `content/`, lab files in `labs/dayNN/` (break.sh + verify.sh +
teardown.md + README.md + SOLUTION.md), and the toolkit product in
`bash/ops-toolkit/`. Tasks 2–4 are fully independent and MUST be dispatched in
parallel.

**Tech Stack:** bash 5.x, dash (POSIX sh), Docker `ws` container (Ubuntu 24.04),
existing `linuxops` compose project — no new services.

**Spec:** `linux_ops_mastery/docs/superpowers/specs/2026-09-08-bash-extension-design.md`

## Global Constraints

- No git commits — the learner handles all VCS.
- No credentials, real account IDs, or secrets in any file.
- No `git status/diff/log` in any subagent dispatch.
- No running real infrastructure — all files are authored, not executed.
- Every exercise ships with hints + solution sketches (non-negotiable).
- Every lab ships with README.md + SOLUTION.md + teardown checklist.
- All bash scripts: `#!/usr/bin/env bash` shebang + `set -euo pipefail` header.
- `bash/ops-toolkit/` lib and bin files are NOT pre-written — learners author
  them through the labs. Each day's SOLUTION.md contains the reference version.

---

### Task 1: Foundation updates

**Files:**
- Modify: `linux_ops_mastery/README.md`
- Modify: `linux_ops_mastery/STRATEGY.md`
- Create: `linux_ops_mastery/bash/ops-toolkit/lib/.gitkeep`
- Create: `linux_ops_mastery/bash/ops-toolkit/bin/.gitkeep`

**Interfaces:**
- Produces: directory scaffold that Tasks 2–4 reference in their SOLUTION.md paths

- [ ] **Step 1: Add day08–10 rows to the README day map table**

In `linux_ops_mastery/README.md`, find the table ending with the day07 row and
append these three rows immediately after it:

```
| 8 | Exit codes | 2h | Pipeline silently succeeds after `find` permission-denied failure | `content/day08.md` | `labs/day08/` |
| 9 | Subshells & traps | 2h | Cleanup trap not fired after Ctrl-C inside a pipeline loop | `content/day09.md` | `labs/day09/` |
| 10 | Argument contract | 2h | Fragile positional arg parser silently operates on wrong target | `content/day10.md` | `labs/day10/` |
```

- [ ] **Step 2: Append the bash extension section to STRATEGY.md**

Append this block at the very end of `linux_ops_mastery/STRATEGY.md`:

```
## The bash extension (days 8–10)

Days 8–10 apply the same underlying-truth doctrine to bash scripting. The
truth is the process tree: a bash script is a fork from its parent, and it
spawns a tree of child processes through pipelines, subshells, and command
substitutions. Every non-obvious bash failure — a pipeline that swallows an
exit code, a variable that vanishes after a subshell, a trap that does not
fire on Ctrl-C — is a boundary phenomenon inside that tree.

The move is the same: symptom → process boundary → the behavior that proves it.
The daily loop is identical to days 1–7. The strip step at the end of each day
uses sh (dash/POSIX) instead of the Alpine busybox container.

The product is bash/ops-toolkit/: four files the learner builds incrementally
through the labs and keeps for real use.
```

- [ ] **Step 3: Create the toolkit directory scaffold**

Create these two empty files to establish the directory structure before Tasks
2–4 reference the paths in their SOLUTION.md content:

- `linux_ops_mastery/bash/ops-toolkit/lib/.gitkeep` (empty)
- `linux_ops_mastery/bash/ops-toolkit/bin/.gitkeep` (empty)

---

### Task 2: Day 08 — Exit codes are the contract

**Parallel with Tasks 3 and 4 — dispatch simultaneously.**

**Files:**
- Create: `linux_ops_mastery/content/day08.md`
- Create: `linux_ops_mastery/labs/day08/README.md`
- Create: `linux_ops_mastery/labs/day08/break.sh`
- Create: `linux_ops_mastery/labs/day08/verify.sh`
- Create: `linux_ops_mastery/labs/day08/teardown.md`
- Create: `linux_ops_mastery/labs/day08/SOLUTION.md`

**Interfaces:**
- Produces: `lib/log.sh` reference implementation (inside SOLUTION.md)

- [ ] **Step 1: Write `content/day08.md`**

Full file content:

````
# Day 08 — Exit Codes Are the Contract

## Why this matters

A backup job runs nightly. The pipeline is `find /data -type f | tar -czf
backup.tar.gz -T -`. One night `find` hits a permission-denied path and exits
1. `tar` receives a partial list, archives it successfully, and exits 0. The
pipeline exits 0. The cron job sends a success notification. The backup is
incomplete. Nobody knows until the restore is attempted.

This is not a tar bug, a find bug, or a permissions bug. It is a pipeline exit
code boundary. Understanding the process model closes it in one line.

## The underlying truth

Every process exits with exactly one integer: its exit code. Zero means success;
non-zero means failure. When commands are joined in a pipeline (`cmd1 | cmd2`),
the shell creates one process per stage. Each stage has its own exit code. By
default, the exit code of the entire pipeline is the exit code of the **last**
command — not the first, not the worst, just the last. If `cmd1` fails and
`cmd2` succeeds, the pipeline exits 0 and the failure is silently discarded.

Verify this directly inside the `ws` container:

```sh
# false exits 1. true exits 0. Pipeline exits 0 — false's failure is gone.
false | true; echo "pipeline exit: $?"
```

`PIPESTATUS` (bash-only) exposes every stage's exit code:

```sh
false | true; echo "${PIPESTATUS[@]}"   # prints: 1 0
```

## Breaking it down

**The four `set` flags:**

| Flag | What it catches | What it misses |
|------|----------------|----------------|
| `set -e` | Exits on a non-zero exit code | Errors in `if`/`while` conditions, `\|\|` chains, `&&` chains, non-last pipeline stages |
| `set -u` | Exits on use of an unset variable | Variables set to empty string |
| `set -o pipefail` | Pipeline exit = first non-zero stage's code | Nothing — this is the pipeline fix |
| `set -x` | Prints each command before executing (debug mode) | — |

The combination `set -euo pipefail` is the standard header for every ops script.

**What `set -e` still misses (the documented exceptions):**

```bash
set -e
# These do NOT abort the script — the error is consumed by the compound expression:
if failing_cmd; then echo "ok"; fi    # exit code consumed by if-condition
failing_cmd || true                   # exit code consumed by ||
failing_cmd && echo "ok"              # && is similar
```

The rule: `set -e` fires on a bare command. It does not fire when the command
is the condition of a compound expression.

## The pattern

Every script starts with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

A `usage()` function and structured stderr logging complete the contract:

```bash
usage() {
  echo "Usage: $(basename "$0") <target_dir> <backup_file>" >&2
  echo "  target_dir   directory to back up" >&2
  echo "  backup_file  output .tar.gz path" >&2
  exit 1
}

log() {
  local level="$1"; shift
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [$level] $*" >&2
}
```

The `log` function writes to stderr (`>&2`), not stdout. Stdout is data; stderr
is diagnostics. Mixing them breaks pipelines that capture the script's output.

Author `bash/ops-toolkit/lib/log.sh` now — it will be sourced by all future
toolkit scripts. See `labs/day08/SOLUTION.md` for the reference implementation.

## Lab

See `labs/day08/`. Break scenario: a pipeline-based backup script silently
reports success after a permission-denied failure inside `find`. Success signal:
`verify.sh` exits 0.

## Exercises

1. Run `false | true; echo $?` in the `ws` container. The output is 0. Now run
   `(set -o pipefail; false | true); echo $?`. What changes and why? —
   **Hint:** `PIPESTATUS[@]` shows per-stage exit codes; `pipefail` promotes the
   first non-zero stage to the pipeline's overall exit code. —
   **Solution sketch:** Without `pipefail`, `false | true` exits 0 (last stage
   wins). With `pipefail`, it exits 1 because `false` (stage 0) exited 1. The
   pipeline failure is now visible to any caller checking `$?`.

2. Write a four-line script that uses `set -euo pipefail` and references an
   unset variable `$MISSING_VAR`. Predict the exit code before running. —
   **Hint:** `set -u` treats an unset variable reference as an error. —
   **Solution sketch:** `#!/usr/bin/env bash; set -euo pipefail; echo
   "$MISSING_VAR"` — exits non-zero with `unbound variable: MISSING_VAR`.
   Without `set -u`, `$MISSING_VAR` silently expands to an empty string.

3. Write a `log()` function that prints `[TIMESTAMP] [INFO] <message>` to
   stderr. Verify that `./script.sh > /dev/null` still shows the log output. —
   **Hint:** Redirect to `>&2`; only stderr bypasses the `> /dev/null` on
   stdout. — **Solution sketch:** `echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [INFO]
   $*" >&2`. Running `./script.sh > /dev/null` shows the log line because
   stderr is not affected by stdout redirection.

## Anti-patterns

- **Logging to stdout** — breaks pipelines that capture the script's output as
  data; all diagnostic output belongs on stderr.
- **Checking `$?` manually after every command** — noisy and easy to miss; use
  `set -e` as the default and `|| true` only where a non-zero exit is expected.
- **Omitting `set -o pipefail`** — the single most common source of "the script
  said it worked but it didn't"; silent pipeline failures are invisible without
  this flag.

## Strip step

Repeat the lab diagnosis in `sh` (not bash). Note:
- `PIPESTATUS` is bash-only — `sh` has no arrays. The POSIX alternative is to
  restructure the pipeline: run each stage separately and capture exit codes,
  or use a named pipe.
- `set -o pipefail` is available in `dash` (Ubuntu's `sh`) but is not
  guaranteed POSIX-portable across all shells.
````

- [ ] **Step 2: Write `labs/day08/README.md`**

Full file content:

```
# Day 08 Lab — Silent Pipeline Failure

## Scenario

A backup script wraps `find` and `tar` in a pipeline. `find` hits a
permission-denied path, exits 1, but `tar` succeeds on the partial input.
The pipeline exits 0. The script prints "Backup complete." The backup is
missing files.

## Setup

    bash labs/day08/break.sh

This creates /tmp/lab08/ with:
- /tmp/lab08/data/readable.txt — a normal file
- /tmp/lab08/data/secret.txt  — mode 000, unreadable
- /tmp/lab08/backup.sh        — the broken backup script

## The incident

Run the broken script:

    bash /tmp/lab08/backup.sh

It reports success. Inspect the archive. What is missing?

## Your task

1. Diagnose the failure using `echo $?`, `PIPESTATUS`, and `set -o pipefail`.
2. Write your chain of evidence in journal.md BEFORE making any fix.
3. Fix backup.sh so it fails loudly instead of silently.
4. Run verify.sh to confirm.

## Verify

    bash labs/day08/verify.sh

## Teardown

See teardown.md.
```

- [ ] **Step 3: Write `labs/day08/break.sh`**

Full file content:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[day08] Injecting silent pipeline failure incident..."

rm -rf /tmp/lab08
mkdir -p /tmp/lab08/{data,backup}

echo "important data" > /tmp/lab08/data/readable.txt
touch /tmp/lab08/data/secret.txt
chmod 000 /tmp/lab08/data/secret.txt

cat > /tmp/lab08/backup.sh << 'SCRIPT'
#!/usr/bin/env bash
# BROKEN: no pipefail — find's exit 1 is silently discarded
TARGET_DIR=/tmp/lab08/data
BACKUP_FILE=/tmp/lab08/backup/archive.tar.gz

find "$TARGET_DIR" -type f 2>/dev/null | tar -czf "$BACKUP_FILE" -T - 2>/dev/null
echo "Backup complete. Archive: $BACKUP_FILE"
SCRIPT

chmod +x /tmp/lab08/backup.sh

echo "[day08] Incident injected."
echo "  /tmp/lab08/data/secret.txt is mode 000 — find will fail on it"
echo "  Run: bash /tmp/lab08/backup.sh"
```

- [ ] **Step 4: Write `labs/day08/verify.sh`**

Full file content:

```bash
#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

check() {
  local desc="$1" result="$2"
  if [[ "$result" == "pass" ]]; then
    echo "  PASS: $desc"; ((PASS++))
  else
    echo "  FAIL: $desc"; ((FAIL++))
  fi
}

echo "[day08 verify] Checking fix..."

if grep -qE 'pipefail' /tmp/lab08/backup.sh 2>/dev/null; then
  check "backup.sh contains pipefail" pass
else
  check "backup.sh contains pipefail" fail
fi

if bash /tmp/lab08/backup.sh > /dev/null 2>&1; then
  check "fixed backup.sh exits non-zero on permission-denied find" fail
else
  check "fixed backup.sh exits non-zero on permission-denied find" pass
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 5: Write `labs/day08/teardown.md`**

Full file content:

```
# Day 08 Teardown

- [ ] Remove the lab directory: rm -rf /tmp/lab08
- [ ] Confirm it is gone: ls /tmp/lab08 should report "No such file or directory"
- [ ] Verify the ws container is still running: docker compose -p linuxops ps

No Docker services were added in this lab. No other cleanup is needed.
```

- [ ] **Step 6: Write `labs/day08/SOLUTION.md`**

Full file content:

````
# Day 08 Solution — Silent Pipeline Failure

## Chain of evidence

**Symptom:** `backup.sh` prints "Backup complete" even when `find` hits a
permission-denied path.

**Step 1 — Observe the exit code:**

```sh
bash /tmp/lab08/backup.sh; echo "exit: $?"
# Output: Backup complete. Archive: ...
# exit: 0
```

Script reports success. `$?` is 0.

**Step 2 — Identify the pipeline:**

The line `find "$TARGET_DIR" -type f 2>/dev/null | tar -czf "$BACKUP_FILE" -T -`
is a two-stage pipeline. `find` exits 1 on permission-denied; `tar` succeeds on
the partial input. The pipeline takes `tar`'s exit code (0).

**Step 3 — Confirm with PIPESTATUS:**

```sh
find /tmp/lab08/data -type f 2>/dev/null | tar -czf /dev/null -T -
echo "${PIPESTATUS[@]}"
# prints: 1 0
```

Stage 0 (`find`) exited 1. Stage 1 (`tar`) exited 0. Pipeline exited 0.

**Step 4 — The process boundary:**

A pipeline is a chain of processes. Each process exits independently. The
shell's default rule: the pipeline's exit code is the last stage's value.
`find`'s exit 1 is discarded.

**Fix:** add `set -o pipefail` (or `set -euo pipefail`) to `backup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR=/tmp/lab08/data
BACKUP_FILE=/tmp/lab08/backup/archive.tar.gz

log() { echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [INFO] $*" >&2; }

log "Starting backup of $TARGET_DIR"
find "$TARGET_DIR" -type f | tar -czf "$BACKUP_FILE" -T -
log "Backup complete: $BACKUP_FILE"
```

The `2>/dev/null` suppressors are removed — they were hiding the error.
With `set -o pipefail`, the script now exits 1 on `find` failure.

**Proof:**

```sh
bash /tmp/lab08/backup.sh; echo "exit: $?"
# exit: 1
```

**Strip step (sh):** `PIPESTATUS` does not exist in POSIX sh. Restructure:

```sh
find "$TARGET_DIR" -type f > /tmp/lab08/file_list.txt
rc=$?
[ "$rc" -ne 0 ] && { echo "find failed: $rc" >&2; exit "$rc"; }
tar -czf "$BACKUP_FILE" -T /tmp/lab08/file_list.txt
```

## lib/log.sh reference implementation

Author `bash/ops-toolkit/lib/log.sh` with this exact content:

```bash
#!/usr/bin/env bash
# source this file, then call: log INFO|WARN|ERROR "message"
# Output goes to stderr only — never to stdout.

log() {
  local level="${1:?log requires a level (INFO|WARN|ERROR)}"
  shift
  echo "[$(date '+%Y-%m-%dT%H:%M:%S')] [$level] $*" >&2
}
```
````

---

### Task 3: Day 09 — Subshells and traps

**Parallel with Tasks 2 and 4 — dispatch simultaneously.**

**Files:**
- Create: `linux_ops_mastery/content/day09.md`
- Create: `linux_ops_mastery/labs/day09/README.md`
- Create: `linux_ops_mastery/labs/day09/break.sh`
- Create: `linux_ops_mastery/labs/day09/verify.sh`
- Create: `linux_ops_mastery/labs/day09/teardown.md`
- Create: `linux_ops_mastery/labs/day09/SOLUTION.md`

**Interfaces:**
- Consumes: `lib/log.sh` pattern established in Task 2 SOLUTION.md
- Produces: `lib/trap.sh` reference implementation (inside SOLUTION.md)

- [ ] **Step 1: Write `content/day09.md`**

Full file content:

````
# Day 09 — Subshells and Traps

## Why this matters

A deployment script creates a working directory with `mktemp -d`, registers a
cleanup trap, then processes a stream of servers with `while read`. The engineer
hits Ctrl-C halfway through. The trap does not fire. The temp directory
accumulates across aborted runs. On the fifth run, a stale directory causes a
name collision and the deployment silently skips ten servers.

This is not a `mktemp` bug. It is a trap scope boundary: `while read line`
receives its input through a pipe, which runs the loop body in a subshell. A
trap registered in the parent process does not fire in a subshell.

## The underlying truth

A subshell is a child process created by the shell. Three constructs always
create subshells:

```sh
( commands )        # explicit subshell
$(commands)         # command substitution
cmd1 | cmd2         # every pipeline stage is a subshell
```

Because a subshell is a fork, it inherits the parent's state at fork time but
is a separate process afterward. Two consequences follow.

**Variables do not propagate back:**

```bash
x=1
(x=2)
echo $x    # prints 1 — the subshell's assignment died with the subshell
```

```bash
echo "hello" | read line   # read runs in a subshell; $line is empty afterward
```

**Traps do not fire across process boundaries:**

```bash
trap 'echo cleaned up' EXIT
(exit 1)           # subshell exits; parent's EXIT trap does NOT fire
echo "still running"
```

The parent's `EXIT` trap fires when the *parent* exits, not when a child exits.
Ctrl-C sends SIGINT to the foreground process group — which may be the child
pipeline, not the parent script.

## Breaking it down

**Trap syntax:**

```bash
trap 'cleanup_function' EXIT INT TERM
```

- `EXIT` fires when the shell exits for any reason (including `set -e` abort).
- `INT` catches Ctrl-C (SIGINT).
- `TERM` catches `kill <pid>` (SIGTERM).
- Trap handlers run sequentially; keep them fast.

**The subshell problem with while-read pipelines:**

```bash
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

# BUG: while body runs in a subshell because of the pipeline
some_command | while read line; do
  process "$line"
done
# Ctrl-C inside the pipeline may not trigger the parent's trap before the
# pipeline process group dies.
```

**The fix — process substitution breaks the pipeline:**

```bash
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

# while body runs in the PARENT shell, not a subshell
while IFS= read -r line; do
  process "$line"
done < <(some_command)
```

Or use an atomic lockfile for mutual exclusion:

```bash
LOCK_DIR=/tmp/deploy.lock
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Another deployment is running (or cleanup needed: rm -rf $LOCK_DIR)" >&2
  exit 1
fi
trap 'rm -rf "$LOCK_DIR"' EXIT INT TERM
```

## The pattern

Standard trap + mktemp pattern for every script that creates temporary state:

```bash
#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT INT TERM

# ... work using $TMPDIR ...
# cleanup() fires automatically on exit, Ctrl-C, or kill
```

Author `bash/ops-toolkit/lib/trap.sh` now. See `labs/day09/SOLUTION.md` for
the reference implementation.

## Lab

See `labs/day09/`. Break scenario: a deployment script registers a cleanup trap
but the trap does not fire on Ctrl-C because the work runs inside a pipeline
subshell. A stale temp directory causes the second run to fail. Success signal:
`verify.sh` exits 0.

## Exercises

1. Prove the subshell variable scope rule. Write a script that sets `x=hello`
   in a subshell `(x=world)` and prints `$x` in the parent. Predict the output
   before running. — **Hint:** A subshell is a fork; assignments do not
   propagate back across a process boundary. — **Solution sketch:** Prints
   `hello`. The subshell's `x=world` existed only inside the child process and
   died when it exited.

2. Write a script that creates a temp directory with `mktemp -d` and registers
   a cleanup trap. Verify cleanup happens even when the script exits non-zero
   via `set -e`. — **Hint:** `EXIT` fires regardless of whether the exit was
   clean or forced by `set -e`. — **Solution sketch:**
   `trap 'rm -rf "$TMPDIR"' EXIT` — fires on any exit. Confirm with
   `ls "$TMPDIR"` after the script exits: the directory is gone.

3. Show that `echo "hello" | read line` leaves `$line` empty afterward. Fix it
   using process substitution `read line < <(echo "hello")` and explain why it
   works. — **Hint:** The `|` pipe forces `read` into a subshell; `<()` hands
   `read` a file descriptor instead. — **Solution sketch:** In the pipeline
   form, `read` runs in a subshell and the assignment dies with it. In
   `read line < <(echo "hello")`, `read` runs in the current shell and the
   assignment persists.

## Anti-patterns

- **Registering a trap and then running work in a pipeline subshell** — the
  trap fires in the parent but the pipeline stages are child processes; Ctrl-C
  may kill the child group before the parent's trap can execute.
- **Using `trap` without `EXIT`** — only trapping `INT` and `TERM` misses
  `set -e` aborts and explicit `exit` calls; always include `EXIT`.
- **Using a temp file path without a lockfile** — for mutual exclusion between
  concurrent script runs, `mkdir` is atomic and self-documenting; a plain file
  test-and-create (`[ -f $lock ] || touch $lock`) is not atomic.

## Strip step

Repeat the lab diagnosis in `sh` (not bash). Note:
- `<()` process substitution is bash-only; not available in `sh`.
- POSIX portable alternative: write the command's output to a temp file with
  `mktemp`, then `read` from the file using `< /tmp/tmpfile`.
- `trap` syntax and the signals (`EXIT`, `INT`, `TERM`) are POSIX; they work
  the same way in `sh`.
````

- [ ] **Step 2: Write `labs/day09/README.md`**

Full file content:

```
# Day 09 Lab — Trap Scope and Stale Temp Directory

## Scenario

A deployment script creates a temp directory, registers a cleanup trap, then
processes a list of servers via a pipeline loop. Hitting Ctrl-C partway through
leaves the temp directory behind. The second run fails because the directory
already exists.

## Setup

    bash labs/day09/break.sh

This creates /tmp/lab09/ with deploy.sh — the broken deployment script.

## The incident

Run the broken script, then interrupt it:

    bash /tmp/lab09/deploy.sh &
    sleep 1
    kill -INT $!

Check whether the temp directory was cleaned up. Then run it again — what
happens?

## Your task

1. Diagnose why the trap does not fire on Ctrl-C inside the pipeline loop.
2. Write your chain of evidence in journal.md BEFORE making any fix.
3. Fix deploy.sh so the cleanup trap reliably fires on interrupt.
4. Run verify.sh to confirm.

## Verify

    bash labs/day09/verify.sh

## Teardown

See teardown.md.
```

- [ ] **Step 3: Write `labs/day09/break.sh`**

Full file content:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[day09] Injecting trap-scope incident..."

rm -rf /tmp/lab09
mkdir -p /tmp/lab09

cat > /tmp/lab09/deploy.sh << 'SCRIPT'
#!/usr/bin/env bash
# BROKEN: cleanup trap is registered in the parent shell, but the while
# loop runs inside a pipeline subshell — Ctrl-C may not trigger cleanup.

TMPDIR=$(mktemp -d /tmp/lab09/work.XXXXXX)
echo "Working directory: $TMPDIR"

cleanup() {
  echo "cleanup called"
  rm -rf "$TMPDIR"
}
trap cleanup EXIT INT TERM

# BUG: the while body runs in a subshell (right side of |)
seq 1 20 | while read -r server_num; do
  echo "Deploying to server-${server_num}..."
  sleep 0.3
done

echo "Deployment complete"
SCRIPT

chmod +x /tmp/lab09/deploy.sh

echo "[day09] Incident injected."
echo "  Run: bash /tmp/lab09/deploy.sh &"
echo "  Then: kill -INT \$!"
echo "  Check whether /tmp/lab09/work.* directories are cleaned up."
```

- [ ] **Step 4: Write `labs/day09/verify.sh`**

Full file content:

```bash
#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

check() {
  local desc="$1" result="$2"
  if [[ "$result" == "pass" ]]; then
    echo "  PASS: $desc"; ((PASS++))
  else
    echo "  FAIL: $desc"; ((FAIL++))
  fi
}

echo "[day09 verify] Checking fix..."

if grep -q 'trap ' /tmp/lab09/deploy.sh 2>/dev/null; then
  check "deploy.sh registers a trap" pass
else
  check "deploy.sh registers a trap" fail
fi

rm -rf /tmp/lab09/work.*
bash /tmp/lab09/deploy.sh &
DEPLOY_PID=$!
sleep 0.8
kill -INT "$DEPLOY_PID" 2>/dev/null || true
sleep 0.5

stale_count=$(find /tmp/lab09 -maxdepth 1 -name 'work.*' -type d 2>/dev/null | wc -l)
if [[ "$stale_count" -eq 0 ]]; then
  check "no stale work directories after Ctrl-C interrupt" pass
else
  check "no stale work directories after Ctrl-C interrupt" fail
fi

rm -rf /tmp/lab09/work.*
if bash /tmp/lab09/deploy.sh > /dev/null 2>&1; then
  check "second run completes without stale-directory failure" pass
else
  check "second run completes without stale-directory failure" fail
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 5: Write `labs/day09/teardown.md`**

Full file content:

```
# Day 09 Teardown

- [ ] Remove the lab directory: rm -rf /tmp/lab09
- [ ] Remove any leftover work directories: rm -rf /tmp/lab09/work.*
- [ ] Confirm cleanup: ls /tmp/lab09 should report "No such file or directory"
- [ ] Verify the ws container is still running: docker compose -p linuxops ps

No Docker services were added in this lab. No other cleanup is needed.
```

- [ ] **Step 6: Write `labs/day09/SOLUTION.md`**

Full file content:

````
# Day 09 Solution — Trap Scope and Stale Temp Directory

## Chain of evidence

**Symptom:** After interrupting `deploy.sh`, `/tmp/lab09/work.*` directories
remain. A second run fails because `mktemp` creates a new directory and stale
ones accumulate, or the collision check blocks entry.

**Step 1 — Run and interrupt:**

```bash
bash /tmp/lab09/deploy.sh &
DEPLOY_PID=$!
sleep 0.8
kill -INT "$DEPLOY_PID"
ls /tmp/lab09/work.*   # directory still exists
```

**Step 2 — Identify the pipeline:**

The critical line is:
```bash
seq 1 20 | while read -r server_num; do ... done
```

This is a pipeline. The right-hand side (`while read`) is a subshell.

**Step 3 — Prove the subshell with PID:**

```bash
echo "parent PID: $$"
seq 1 3 | while read -r n; do
  echo "loop PID: $$"
  break
done
```

The loop prints a different PID — it is a child process.

**Step 4 — The process boundary:**

Ctrl-C fires SIGINT at the foreground process group. The pipeline stages die.
The parent's trap may fire eventually, but the timing is non-deterministic
because the parent is blocked waiting for the pipeline. The reliable fix
eliminates the pipeline entirely.

**Fix — process substitution:**

```bash
#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d /tmp/lab09/work.XXXXXX)

cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT INT TERM

# while runs in the PARENT shell, not a subshell
while IFS= read -r server_num; do
  echo "Deploying to server-${server_num}..."
  sleep 0.3
done < <(seq 1 20)

echo "Deployment complete"
```

With `< <(seq 1 20)`, `seq` runs in a subshell but `while read` runs in the
parent shell. Ctrl-C hits the parent, `EXIT` trap fires, `cleanup()` removes
`$TMPDIR`.

**Proof:**

```bash
bash /tmp/lab09/deploy.sh &; sleep 0.8; kill -INT $!; sleep 0.3
ls /tmp/lab09/work.*   # "No such file or directory"
```

**Strip step (sh):** `<()` is bash-only. POSIX sh alternative:

```sh
seq 1 20 > /tmp/lab09/server_list.txt
while IFS= read -r server_num; do
  echo "Deploying to server-${server_num}..."
done < /tmp/lab09/server_list.txt
rm -f /tmp/lab09/server_list.txt
```

## lib/trap.sh reference implementation

Author `bash/ops-toolkit/lib/trap.sh` with this exact content:

```bash
#!/usr/bin/env bash
# Usage: source this file, define a cleanup() function, then call register_cleanup.
#
# Example:
#   source lib/trap.sh
#   TMPDIR=$(mktemp -d)
#   cleanup() { rm -rf "$TMPDIR"; }
#   register_cleanup

register_cleanup() {
  trap 'cleanup' EXIT INT TERM
}
```
````

---

### Task 4: Day 10 — Argument contract + capstone

**Parallel with Tasks 2 and 3 — dispatch simultaneously.**

**Files:**
- Create: `linux_ops_mastery/content/day10.md`
- Create: `linux_ops_mastery/labs/day10/README.md`
- Create: `linux_ops_mastery/labs/day10/break.sh`
- Create: `linux_ops_mastery/labs/day10/verify.sh`
- Create: `linux_ops_mastery/labs/day10/teardown.md`
- Create: `linux_ops_mastery/labs/day10/SOLUTION.md`

**Interfaces:**
- Consumes: `lib/log.sh` pattern from Task 2, `lib/trap.sh` pattern from Task 3
- Produces: `lib/args.sh` and `bin/diagnose.sh` reference implementations (inside SOLUTION.md)

- [ ] **Step 1: Write `content/day10.md`**

Full file content:

````
# Day 10 — The Argument Contract + Capstone

## Why this matters

An ops script takes a PID as its first argument and kills the process. On a
miscall — no arguments, a typo, a renamed flag — `$1` expands to empty. The
script passes an empty string to `kill`, which interprets it as `kill 0`
(send SIGTERM to the entire process group), terminates the calling shell and
every background job. The engineer's terminal dies. The deployment pipeline's
parent dies. Nobody is sure why.

A validated argument contract, checked at entry, would have printed a usage
message and exited 1 before any `kill` was ever called.

## The underlying truth

A script's interface is its argument contract: the exact set of positional
arguments and flags it accepts, what it considers invalid, and which exit code
each outcome produces. A fragile contract silently accepts wrong input and
propagates the wrong behavior downstream — potentially to destructive commands.

Key argument-handling tools:

```bash
$@          # all positional args, each separately quoted — use this, not $*
$#          # number of positional args
$1 … $N     # individual args; empty string if unset (without set -u)
${1:?msg}   # expand $1 if set and non-empty; otherwise abort with msg
getopts     # POSIX flag parser for -x style short options
```

**What `set -u` catches (and what it misses):**

```bash
set -u
echo "$1"           # aborts if $1 is unset (no arguments given)
echo "${1:-}"       # safe default: expands to empty if unset — bypasses set -u
echo "${1:?error}"  # aborts with custom error if $1 is unset or empty
```

`${1:-}` deliberately bypasses `set -u`. Use `${1:?}` when the argument is
required and its absence is an error.

## Breaking it down

**Safe positional argument parsing:**

```bash
usage() {
  echo "Usage: $(basename "$0") <pid>" >&2
  echo "  pid   PID to inspect" >&2
  exit 1
}

[[ $# -lt 1 ]] && usage
PID="${1:?PID is required}"
[[ "$PID" =~ ^[0-9]+$ ]] || { echo "error: PID must be a number" >&2; usage; }
```

**`getopts` for flag-based interfaces:**

```bash
VERBOSE=0
TIMEOUT=30

while getopts ':vt:' opt; do
  case $opt in
    v) VERBOSE=1 ;;
    t) TIMEOUT="$OPTARG" ;;
    :) echo "error: -$OPTARG requires an argument" >&2; usage ;;
    \?) echo "error: unknown flag -$OPTARG" >&2; usage ;;
  esac
done
shift $((OPTIND - 1))   # remove parsed flags; $@ now contains remaining positionals
```

**Retry with exponential backoff:**

```bash
retry() {
  local max_attempts="$1" delay="$2"; shift 2
  local attempt=1
  until "$@"; do
    if [[ $attempt -ge $max_attempts ]]; then
      echo "error: command failed after $attempt attempts: $*" >&2
      return 1
    fi
    echo "attempt $attempt failed, retrying in ${delay}s..." >&2
    sleep "$delay"
    ((attempt++))
    delay=$((delay * 2))
  done
}
# Usage: retry 3 1 some_command --with-args
```

## The pattern

Author `bash/ops-toolkit/lib/args.sh` with the validation helpers and the
`retry` function, then assemble `bash/ops-toolkit/bin/diagnose.sh` as the
capstone. See `labs/day10/SOLUTION.md` for both reference implementations.

`diagnose.sh` interface:

```
Usage: diagnose.sh [-v] <resource-class> [pid]

  -v               verbose mode (set -x)
  resource-class   one of: mounts | procs | fds | cgroups
  pid              required for procs, fds, cgroups

Examples:
  diagnose.sh mounts          # mount tree (/proc/mounts)
  diagnose.sh procs 1234      # process stat + status for PID 1234
  diagnose.sh fds   1234      # open file descriptors for PID 1234
  diagnose.sh cgroups 1234    # cgroup membership for PID 1234
```

## Lab

See `labs/day10/`. Break scenario: a script that takes a PID argument silently
accepts no arguments, passes an empty string to a command. Success signal:
`verify.sh` exits 0.

## Exercises

1. Write a three-line argument guard that exits with `usage()` if fewer than
   two arguments are given. Test it with zero, one, and two arguments. —
   **Hint:** `$#` holds the argument count; `[[ $# -lt N ]]` tests it. —
   **Solution sketch:** `[[ $# -lt 2 ]] && usage`. With zero args, `usage`
   runs and exits 1. With two args, the script continues past the guard.

2. Write a `getopts` loop that accepts `-v` (verbose) and `-o outfile` (output
   file). Print an error and call `usage` for unknown flags or missing option
   arguments. — **Hint:** `:` at the start of the optstring enables silent
   error handling; `\?` catches unknown flags, `:` catches missing option
   arguments. — **Solution sketch:**
   `while getopts ':vo:' opt; do case $opt in v) VERBOSE=1;; o) OUTFILE="$OPTARG";;
   :) echo "-$OPTARG needs an arg" >&2; usage;; \?) echo "unknown: -$OPTARG" >&2; usage;; esac; done`.

3. Implement `retry 3 2 false` (retry up to 3 times, 2s initial delay,
   doubling each attempt). Verify it exits non-zero after three failures. —
   **Hint:** Use `until cmd; do` and track attempts with a counter; return the
   command's exit code on final failure. — **Solution sketch:** The `retry`
   function above. `retry 3 2 false` sleeps 2s then 4s, then exits 1 after the
   third failure.

## Anti-patterns

- **Using `$*` instead of `$@`** — `$*` joins all arguments into a single word
  when double-quoted; `$@` preserves each argument as a separate word; always
  use `"$@"` when forwarding arguments to another command.
- **Silently accepting extra arguments** — an unrecognised `$3` is ignored by
  default; validate with `[[ $# -gt expected ]] && usage` to catch typos.
- **Exit code 0 from an error path** — a `usage()` that exits 0 is
  indistinguishable from a successful run to any caller checking `$?`; always
  `exit 1` (or the appropriate non-zero code) from every error path.

## Strip step

Run `diagnose.sh` under `sh -n` (syntax check only) and identify any
bash-only constructs: `[[ ]]`, `(( ))`, `<()`, arrays. Convert each to its
POSIX-sh equivalent:
- `[[ "$x" =~ regex ]]` → `echo "$x" | grep -qE 'regex'`
- `(( n++ ))` → `n=$((n + 1))`
- `[[ ... ]]` → `[ ... ]` with careful quoting
````

- [ ] **Step 2: Write `labs/day10/README.md`**

Full file content:

```
# Day 10 Lab — Fragile Argument Parser

## Scenario

An ops script accepts a PID as its first argument and runs a diagnostic on
that process. When called without arguments (or with a typo), $1 is empty.
The script proceeds anyway, passing an empty string to a command that
interprets it destructively.

## Setup

    bash labs/day10/break.sh

This creates /tmp/lab10/ with inspect.sh — the broken ops script.

## The incident

Run the broken script without arguments:

    bash /tmp/lab10/inspect.sh

What happens? Now run it with a non-numeric argument:

    bash /tmp/lab10/inspect.sh notapid

Does it reject the invalid input?

## Your task

1. Diagnose the argument handling gaps.
2. Write your chain of evidence in journal.md BEFORE making any fix.
3. Fix inspect.sh to validate its argument contract at entry.
4. Run verify.sh to confirm.

## Verify

    bash labs/day10/verify.sh

## Teardown

See teardown.md.
```

- [ ] **Step 3: Write `labs/day10/break.sh`**

Full file content:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[day10] Injecting fragile argument parser incident..."

rm -rf /tmp/lab10
mkdir -p /tmp/lab10

cat > /tmp/lab10/inspect.sh << 'SCRIPT'
#!/usr/bin/env bash
# BROKEN: no argument validation — $1 may be empty or non-numeric.
# In a real script this might be: kill $1
# Here it safely reads /proc/$1/status instead.

PID="$1"
echo "Inspecting PID: $PID"
cat /proc/"$PID"/status 2>/dev/null || echo "Could not read /proc/$PID/status"
SCRIPT

chmod +x /tmp/lab10/inspect.sh

echo "[day10] Incident injected."
echo "  Run: bash /tmp/lab10/inspect.sh          (no args)"
echo "  Run: bash /tmp/lab10/inspect.sh notapid  (invalid arg)"
```

- [ ] **Step 4: Write `labs/day10/verify.sh`**

Full file content:

```bash
#!/usr/bin/env bash
set -euo pipefail

PASS=0
FAIL=0

check() {
  local desc="$1" result="$2"
  if [[ "$result" == "pass" ]]; then
    echo "  PASS: $desc"; ((PASS++))
  else
    echo "  FAIL: $desc"; ((FAIL++))
  fi
}

echo "[day10 verify] Checking fix..."

if bash /tmp/lab10/inspect.sh > /dev/null 2>&1; then
  check "inspect.sh exits non-zero with no arguments" fail
else
  check "inspect.sh exits non-zero with no arguments" pass
fi

if bash /tmp/lab10/inspect.sh notapid > /dev/null 2>&1; then
  check "inspect.sh exits non-zero with non-numeric argument" fail
else
  check "inspect.sh exits non-zero with non-numeric argument" pass
fi

if bash /tmp/lab10/inspect.sh 1 > /dev/null 2>&1; then
  check "inspect.sh exits 0 with valid PID (1)" pass
else
  check "inspect.sh exits 0 with valid PID (1)" fail
fi

stderr_out=$(bash /tmp/lab10/inspect.sh 2>&1 1>/dev/null || true)
if [[ -n "$stderr_out" ]]; then
  check "inspect.sh prints error/usage to stderr on invalid call" pass
else
  check "inspect.sh prints error/usage to stderr on invalid call" fail
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 5: Write `labs/day10/teardown.md`**

Full file content:

```
# Day 10 Teardown

- [ ] Remove the lab directory: rm -rf /tmp/lab10
- [ ] Confirm it is gone: ls /tmp/lab10 should report "No such file or directory"
- [ ] Verify bash/ops-toolkit/ contains your four authored files:
      bash/ops-toolkit/lib/log.sh
      bash/ops-toolkit/lib/trap.sh
      bash/ops-toolkit/lib/args.sh
      bash/ops-toolkit/bin/diagnose.sh
- [ ] Run: bash bash/ops-toolkit/bin/diagnose.sh
      (no args — confirm the usage message works)
- [ ] Verify the ws container is still running: docker compose -p linuxops ps

No Docker services were added in this lab. No other cleanup is needed.
```

- [ ] **Step 6: Write `labs/day10/SOLUTION.md`**

Full file content:

````
# Day 10 Solution — Fragile Argument Parser

## Chain of evidence

**Symptom:** `inspect.sh` runs with no arguments and prints "Inspecting PID: "
(empty PID), then tries to read `/proc//status`. Exit code is 0.

**Step 1 — Observe with no arguments:**

```bash
bash /tmp/lab10/inspect.sh; echo "exit: $?"
# Inspecting PID:
# Could not read /proc//status
# exit: 0
```

**Step 2 — The argument expansion:**

```bash
PID="$1"   # $1 is unset — PID becomes empty string ""
```

Without `set -u`, an unset `$1` silently expands to empty. The script
continues with an empty `PID`.

**Step 3 — The contract gap:**

No `[[ $# -lt 1 ]]` guard, no `${1:?}` guard, no type validation. Any
caller can pass nothing, a non-numeric string, or extra unexpected arguments.

**Fix:**

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <pid>" >&2
  echo "  pid   numeric PID of the process to inspect" >&2
  exit 1
}

[[ $# -lt 1 ]] && usage
PID="${1:?PID argument is required}"
[[ "$PID" =~ ^[0-9]+$ ]] || { echo "error: PID must be a positive integer, got: $PID" >&2; usage; }

echo "Inspecting PID: $PID"
cat "/proc/$PID/status" 2>/dev/null || { echo "error: /proc/$PID/status not found" >&2; exit 1; }
```

**Proof:**

```bash
bash /tmp/lab10/inspect.sh;          echo "exit: $?"   # 1, prints usage
bash /tmp/lab10/inspect.sh notapid;  echo "exit: $?"   # 1, prints error + usage
bash /tmp/lab10/inspect.sh 1;        echo "exit: $?"   # 0, prints /proc/1/status
```

**Strip step (sh):**
- `[[ "$PID" =~ ^[0-9]+$ ]]` is bash-only. POSIX: `echo "$PID" | grep -qE '^[0-9]+$'`
- `[[ ... ]]` → `[ ... ]` with careful quoting

## lib/args.sh reference implementation

Author `bash/ops-toolkit/lib/args.sh` with this exact content:

```bash
#!/usr/bin/env bash
# source this file to get: require_args, is_numeric, retry

require_args() {
  # require_args <min_count> <usage_function_name> "$@"
  # Call before processing $@ in the caller:
  #   require_args 1 usage "$@"
  local min="$1" usage_fn="${2:-usage}"; shift 2
  [[ $# -lt $min ]] && "$usage_fn"
}

is_numeric() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

retry() {
  # retry <max_attempts> <initial_delay_seconds> <command> [args...]
  local max_attempts="$1" delay="$2"; shift 2
  local attempt=1
  until "$@"; do
    if [[ $attempt -ge $max_attempts ]]; then
      echo "error: command failed after $attempt attempts: $*" >&2
      return 1
    fi
    echo "attempt $attempt failed, retrying in ${delay}s..." >&2
    sleep "$delay"
    ((attempt++))
    delay=$((delay * 2))
  done
}
```

## bin/diagnose.sh reference implementation

Author `bash/ops-toolkit/bin/diagnose.sh` with this exact content:

```bash
#!/usr/bin/env bash
# diagnose.sh — wraps the /proc-based moves from linux_ops_mastery days 1-7
# into a composable CLI tool.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/log.sh
source "$SCRIPT_DIR/../lib/log.sh"
# shellcheck source=../lib/args.sh
source "$SCRIPT_DIR/../lib/args.sh"

set -euo pipefail

VERBOSE=0

usage() {
  cat >&2 << 'EOF'
Usage: diagnose.sh [-v] <resource-class> [pid]

  -v               verbose mode (set -x)
  resource-class   mounts | procs | fds | cgroups
  pid              required for procs / fds / cgroups

Examples:
  diagnose.sh mounts          # mount tree (/proc/mounts)
  diagnose.sh procs 1234      # process stat + status for PID 1234
  diagnose.sh fds   1234      # open file descriptors for PID 1234
  diagnose.sh cgroups 1234    # cgroup membership for PID 1234
EOF
  exit 1
}

while getopts ':v' opt; do
  case $opt in
    v) VERBOSE=1 ;;
    \?) echo "error: unknown flag -$OPTARG" >&2; usage ;;
  esac
done
shift $((OPTIND - 1))

[[ $# -lt 1 ]] && usage
RESOURCE_CLASS="${1:?resource-class is required}"
PID="${2:-}"

[[ $VERBOSE -eq 1 ]] && set -x

case "$RESOURCE_CLASS" in
  mounts)
    log INFO "Mount tree (/proc/mounts):"
    cat /proc/mounts
    ;;
  procs)
    is_numeric "$PID" || { echo "error: pid required and must be numeric" >&2; usage; }
    log INFO "Process stat for PID $PID:"
    cat "/proc/$PID/stat"
    log INFO "Process status for PID $PID:"
    cat "/proc/$PID/status"
    ;;
  fds)
    is_numeric "$PID" || { echo "error: pid required and must be numeric" >&2; usage; }
    log INFO "Open file descriptors for PID $PID:"
    ls -la "/proc/$PID/fd"
    ;;
  cgroups)
    is_numeric "$PID" || { echo "error: pid required and must be numeric" >&2; usage; }
    log INFO "Cgroup membership for PID $PID:"
    cat "/proc/$PID/cgroup"
    ;;
  *)
    echo "error: unknown resource-class '$RESOURCE_CLASS'" >&2
    usage
    ;;
esac
```
````

---

### Task 5: GLOSSARY additions

**Files:**
- Modify: `linux_ops_mastery/content/GLOSSARY.md`

**Interfaces:**
- Consumes: bash concepts introduced in Tasks 2–4

- [ ] **Step 1: Append bash scripting terms to GLOSSARY.md**

Open `linux_ops_mastery/content/GLOSSARY.md` and append this section after the
last existing entry:

```
---

## Bash Scripting (days 08–10)

**exit code** — The integer a process returns to its parent when it exits.
Zero means success; any non-zero value means failure. The parent reads it via
`$?` immediately after the child exits.

**PIPESTATUS** — A bash array holding the exit code of each stage in the most
recently executed pipeline. `${PIPESTATUS[0]}` is the first stage's code,
`${PIPESTATUS[1]}` the second. Bash-only — not available in POSIX sh.

**`set -euo pipefail`** — A four-flag header for reliable bash scripts: `-e`
aborts on non-zero exit, `-u` aborts on unset variable, `-o pipefail` makes
the pipeline's exit code the first non-zero stage's code rather than the last
stage's.

**subshell** — A child process created by the shell to run a group of commands.
Constructed by `(cmds)`, `$(cmds)`, or any pipeline stage. Inherits the
parent's environment at fork time; variable assignments inside it are invisible
to the parent.

**trap** — A shell built-in that registers a handler to run when the shell
receives a signal or exits. Syntax: `trap 'handler' SIGNAL...`. Common signals:
`EXIT` (fires on any exit), `INT` (Ctrl-C), `TERM` (kill). Traps are
per-process — they do not fire in child processes.

**`mktemp -d`** — Creates a uniquely-named temporary directory and prints its
path. Atomic — safe against concurrent calls. Always pair with
`trap 'rm -rf "$TMPDIR"' EXIT INT TERM` to ensure cleanup on exit or interrupt.

**`getopts`** — POSIX built-in for parsing `-x` style short option flags. Use
`shift $((OPTIND - 1))` after the loop to remove parsed flags, leaving
remaining positional arguments in `$@`.

**argument contract** — The formal interface of a script: which positional
arguments and flags it accepts, what it considers invalid, and which exit codes
each outcome produces. Validated at entry with `[[ $# -lt N ]]`, `${1:?msg}`,
and type checks before any destructive command is reached.

**process substitution** (`<(cmd)`) — A bash construct that runs `cmd` in a
subshell and presents its output as a file descriptor. `while read line; done
< <(cmd)` runs the while body in the current shell (not a subshell), so
variable assignments and trap handlers work correctly. Bash-only — not
available in POSIX sh.
```

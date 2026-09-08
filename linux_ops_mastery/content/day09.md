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

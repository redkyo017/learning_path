# Day 09 — Subshells and Traps

**At a glance — how to work through this day:**
0. Rusty on the basics? Read foundations ch 03, 04 first — [content/foundations/README.md](foundations/README.md).
1. Read "Why this matters" → "The underlying truth" → "Breaking it down" →
   "The pattern".
2. Do the Lab (start with *Start here — plain steps* in `labs/day09/README.md`):
   `break.sh` → write `journal.md` → `verify.sh`.
3. Optional, standalone: "Exercises" — conceptual, don't depend on the
   Lab's incident, do them whenever (see `STRATEGY.md`, "Where Exercises
   fit").
4. Read "Anti-patterns".
5. "Strip step" — repeat the Lab's diagnosis in `sh`, not bash.
6. Teardown: `labs/day09/teardown.md`.

## Why this matters

A CI runner's `/tmp` keeps filling up. A deployment script stages files in a
work directory made with `mktemp -d` and registers a cleanup trap, yet every
run leaves one `work.*` directory behind, and the cleanup prints `cleanup:
nothing to remove`. Worse, when an engineer hits Ctrl-C halfway through, the
script prints `Deployment complete` anyway.

Two separate bugs cause this. First, the work directory variable is set
inside a `while read` loop that sits at the end of a pipeline, so it is set in
a subshell and the parent's trap sees an empty variable. Second, the `INT`
and `TERM` handler runs cleanup but never calls `exit`, so the script carries
on after the signal.

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

Ctrl-C does not go to one process. The terminal driver sends `SIGINT` to the
whole foreground process group: the script and its pipeline children share
that group (a script has no job control, so it does not give each pipeline its
own group), so they all get the signal together. Each one then reacts on its
own. A script's trap handler runs only after the foreground command it is
waiting for returns: a `kill -TERM` sent during `sleep 0.3` takes effect after
that sleep ends.

One testing note: a background job started by a non-interactive shell (`bash
x.sh &` inside a script, or from `docker exec ... bash -c`) starts with `SIGINT`
and `SIGQUIT` ignored, so `kill -INT` does nothing to it. From scripts, test
with `SIGTERM`. In an interactive terminal, Ctrl-C in the foreground works
normally.

## Breaking it down

**Trap syntax:**

```bash
trap 'cleanup_function' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
```

- `EXIT` fires when the shell exits for any reason (including `set -e` abort
  and an `exit` called inside another trap handler).
- `INT` catches Ctrl-C (SIGINT). The handler does not end the script unless it
  calls `exit`; after the handler returns, the script carries on.
- `TERM` catches `kill <pid>` (SIGTERM), with the same rule.
- Trap handlers run sequentially; keep them fast.

**The lazily-set variable in a pipeline (the bug):**

```bash
WORKDIR=""
cleanup() {
  if [ -n "$WORKDIR" ]; then rm -rf "$WORKDIR"; else echo "cleanup: nothing to remove"; fi
}
trap cleanup EXIT INT TERM

printf 'server-%s\n' 1 2 3 | while read -r server; do
  if [ -z "$WORKDIR" ]; then
    WORKDIR=$(mktemp -d /tmp/lab09/work.XXXXXX)   # set in the loop's subshell
  fi
  echo "Deploying to $server..."
done
echo "Deployment complete"
```

The loop is the last stage of a pipeline, so it runs in a subshell. The
assignment dies with it: the parent's `WORKDIR` stays empty, the parent's trap
runs and finds nothing to remove, and the directory leaks (one per run). On
Ctrl-C the loop subshell dies from `SIGINT`; the parent runs its `INT` trap,
which does not exit, so the script continues to `Deployment complete`, then
the `EXIT` trap runs a second time.

**The fix: no subshell for the loop, and handlers that exit:**

```bash
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

while read -r server; do
  ...same body...
done < <(printf 'server-%s\n' 1 2 3 4 5 6 7 8)
```

`done < <(...)` feeds the loop from process substitution, so the loop runs in
the parent and `WORKDIR` survives. `exit 130` (128 + SIGINT 2) and `exit 143`
(128 + SIGTERM 15) end the script and trigger the `EXIT` trap, so `cleanup`
runs exactly once. Fixing only the pipeline stops the leak but not the
carry-on after a signal; fixing only the handlers does the reverse. An
alternative for the creation bug is to create `WORKDIR` before the loop.

Or use an atomic lockfile for mutual exclusion:

```bash
LOCK_DIR=/tmp/deploy.lock
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Another deployment is running (or cleanup needed: rm -rf $LOCK_DIR)" >&2
  exit 1
fi
trap 'rm -rf "$LOCK_DIR"' EXIT
```

## The pattern

Standard trap + mktemp pattern for every script that creates temporary state:

```bash
#!/usr/bin/env bash
set -euo pipefail

TMPDIR=$(mktemp -d)          # created in the parent, before any pipeline
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT            # EXIT does the cleanup
trap 'exit 130' INT          # signals just exit; EXIT then cleans up
trap 'exit 143' TERM

# ... work using $TMPDIR; feed loops with < <(cmd), not cmd | while ...
```

Author `bash/ops-toolkit/lib/trap.sh` now. See `labs/day09/SOLUTION.md` for
the reference implementation.

## Lab

See `labs/day09/`. Break scenario: a CI deployment script leaks one work
directory per run, its cleanup says "nothing to remove", and on Ctrl-C it
prints "Deployment complete" anyway. Success signal: `verify.sh` exits 0.

## Exercises

*How to use these: optional, not tied to the lab. Read a question, write down your prediction, then read the hint and solution. Cover the solution first — it is printed right under the question.*

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

4. Run the lab's script, press Ctrl-C at `server-4`, and explain why it still
   prints `Deployment complete`. After you fix the pipeline (only
   `done < <(printf ...)`), why does it still keep going, and what does
   `trap 'exit 130' INT` add? — **Hint:** What does a trap handler do when it
   finishes? Does `echo` end a script? — **Solution sketch:** The handler runs
   and returns, and the script resumes after the interrupted command. Fixing
   the pipeline removes the leak but not this. `exit 130` ends the script and
   fires the `EXIT` trap, so cleanup runs once and the script reports status
   130 instead of success.


## Anti-patterns

- **Setting state a trap needs inside a pipeline or subshell** — the
  assignment dies with the subshell, so the parent's trap sees an empty
  variable and removes nothing. Create the state in the parent before any
  pipeline, or feed the loop with `< <(cmd)`.
- **A signal trap that does not `exit`** — an `INT` or `TERM` handler that
  only cleans up returns, and the script carries on (even printing a false
  success). End it with `exit 130` / `exit 143` and let `EXIT` clean up.
- **Using `trap` without `EXIT`** — only trapping `INT` and `TERM` misses
  `set -e` aborts and explicit `exit` calls; always include `EXIT`.
- **Using a temp file path without a lockfile** — for mutual exclusion between
  concurrent script runs, `mkdir` is atomic and self-documenting; a plain file
  test-and-create (`[ -f $lock ] || touch $lock`) is not atomic.

## Strip step

*Plain version: a practice drill. Redo the loop without `<(...)` (bash-only process substitution, which feeds a command's output to a loop as if it were a file): save the list to a file, then read it back with `< file`. Try it in plain `sh` on your Mac (type `dash` for a real one) under `/tmp/lab09/`; no Docker.*

Repeat the lab fix in `sh` (not bash). Note:
- `<()` process substitution is bash-only; not available in `sh`.
- POSIX portable alternatives: write the server list to a temp file and use
  `done < "$listfile"`, or create `WORKDIR` before the pipe.
- `trap ... EXIT INT TERM` and `exit 130` are POSIX; they work the same way
  in `sh`.

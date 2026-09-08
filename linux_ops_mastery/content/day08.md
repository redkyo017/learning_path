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

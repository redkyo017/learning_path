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

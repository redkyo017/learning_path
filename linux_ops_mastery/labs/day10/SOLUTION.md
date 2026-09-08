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

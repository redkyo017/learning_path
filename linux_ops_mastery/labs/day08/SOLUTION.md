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

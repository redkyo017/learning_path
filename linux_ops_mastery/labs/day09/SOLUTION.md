# Day 09 Solution — Trap Scope and Stale Temp Directory

## Chain of evidence

**Symptom:** Every run of `deploy.sh` leaves one `/tmp/lab09/work.*` directory,
the cleanup prints `cleanup: nothing to remove`, and on Ctrl-C the script
prints `Deployment complete` anyway.

**Step 1 — The leftover count grows per run:**

```bash
bash /tmp/lab09/deploy.sh
bash /tmp/lab09/deploy.sh
bash /tmp/lab09/deploy.sh
ls -d /tmp/lab09/work.*    # three directories, one per run
```

Each run exits 0, deploys 8 servers, and prints `cleanup: nothing to remove`
once (from the `EXIT` trap). The trap ran; it just had nothing to remove.

**Step 2 — Prove the subshell:**

The critical lines are:

```bash
printf 'server-%s\n' 1 2 3 4 5 6 7 8 | while read -r server; do
  if [ -z "$WORKDIR" ]; then
    WORKDIR=$(mktemp -d /tmp/lab09/work.XXXXXX)
```

The `while` is the last stage of a pipeline, so it runs in a subshell. Add
`echo "in loop: $WORKDIR"` inside the loop and `echo "after loop: $WORKDIR"`
after `done`: the first shows the directory, the second is empty. The
assignment died with the subshell, so the parent's `cleanup` sees an empty
`WORKDIR`.

**Step 3 — Ctrl-C shows the handler does not exit:**

Press Ctrl-C at `server-4`. Actual output:

```
Deploying to server-4...
cleanup: nothing to remove
Deployment complete
cleanup: nothing to remove
```

Ctrl-C sends SIGINT to the whole foreground process group, so the loop
subshell dies. The parent runs its `INT` trap (`cleanup`), which does not
exit, so the script continues to `Deployment complete`, and then the `EXIT`
trap runs again. `kill -TERM` mid-run behaves the same way. (A trap runs only
after the foreground command the shell is waiting for returns.)

**Fix — loop in the parent, handlers that exit:**

```bash
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

while read -r server; do
  if [ -z "$WORKDIR" ]; then
    WORKDIR=$(mktemp -d /tmp/lab09/work.XXXXXX)
    echo "staging in $WORKDIR"
  fi
  echo "Deploying to $server..."
  : > "$WORKDIR/$server.done"
  sleep 0.3
done < <(printf 'server-%s\n' 1 2 3 4 5 6 7 8)
```

`done < <(...)` keeps the loop in the parent, so `WORKDIR` survives. `exit`
inside the `INT`/`TERM` handler triggers the `EXIT` trap, so cleanup runs
exactly once. Creating `WORKDIR` before the loop is also a valid fix for the
leak. Fixing only the pipeline is not enough: after TERM or Ctrl-C the script
still keeps going, and verify check 3 fails.

**Proof:**

```bash
bash labs/day09/verify.sh    # 3/3 checks pass, exit 0
ls -d /tmp/lab09/work.*      # "No such file or directory"
```

**Strip step (sh):** `<()` is bash-only. Two POSIX alternatives: write the
list to a temp file and read it back, or create `WORKDIR` before the pipe.

```sh
printf 'server-%s\n' 1 2 3 4 5 6 7 8 > /tmp/lab09/server_list.txt
while read -r server; do
  echo "Deploying to $server..."
done < /tmp/lab09/server_list.txt
rm -f /tmp/lab09/server_list.txt
```

`trap cleanup EXIT`, `trap 'exit 130' INT` and `trap 'exit 143' TERM` are
POSIX and work unchanged in `sh`.

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
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
}
```

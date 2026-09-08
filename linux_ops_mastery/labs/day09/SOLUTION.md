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

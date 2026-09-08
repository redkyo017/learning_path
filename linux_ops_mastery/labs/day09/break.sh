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

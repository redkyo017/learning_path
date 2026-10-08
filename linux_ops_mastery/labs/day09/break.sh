#!/usr/bin/env bash
set -euo pipefail

echo "[day09] Injecting trap-scope incident..."

rm -rf /tmp/lab09
mkdir -p /tmp/lab09

cat > /tmp/lab09/deploy.sh << 'SCRIPT'
#!/usr/bin/env bash
# Deploys to a list of servers, staging files in a temp directory that
# the cleanup trap is supposed to remove. It leaks one directory per run.

WORKDIR=""

cleanup() {
  if [ -n "$WORKDIR" ]; then
    rm -rf "$WORKDIR"
    echo "cleanup: removed $WORKDIR"
  else
    echo "cleanup: nothing to remove"
  fi
}
trap cleanup EXIT INT TERM

printf 'server-%s\n' 1 2 3 4 5 6 7 8 | while read -r server; do
  if [ -z "$WORKDIR" ]; then
    WORKDIR=$(mktemp -d /tmp/lab09/work.XXXXXX)
    echo "staging in $WORKDIR"
  fi
  echo "Deploying to $server..."
  : > "$WORKDIR/$server.done"
  sleep 0.3
done

echo "Deployment complete"
SCRIPT

chmod +x /tmp/lab09/deploy.sh

echo "[day09] Incident injected."
echo "  Run it a few times:  bash /tmp/lab09/deploy.sh"
echo "  Then count leftovers: ls -d /tmp/lab09/work.*"

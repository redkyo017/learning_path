#!/usr/bin/env bash
set -euo pipefail

echo "[day10] Injecting fragile argument parser incident..."

rm -rf /tmp/lab10
mkdir -p /tmp/lab10

cat > /tmp/lab10/inspect.sh << 'SCRIPT'
#!/usr/bin/env bash
# BROKEN: no argument validation — $1 may be empty or non-numeric.
# In a real script this might be: kill $1
# Here it safely reads /proc/$1/status instead.

PID="$1"
echo "Inspecting PID: $PID"
cat /proc/"$PID"/status 2>/dev/null || echo "Could not read /proc/$PID/status"
SCRIPT

chmod +x /tmp/lab10/inspect.sh

echo "[day10] Incident injected."
echo "  Run: bash /tmp/lab10/inspect.sh          (no args)"
echo "  Run: bash /tmp/lab10/inspect.sh notapid  (invalid arg)"

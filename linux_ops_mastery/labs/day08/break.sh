#!/usr/bin/env bash
set -euo pipefail

echo "[day08] Injecting silent pipeline failure incident..."

rm -rf /tmp/lab08
mkdir -p /tmp/lab08/{data,backup}

echo "important data" > /tmp/lab08/data/readable.txt
touch /tmp/lab08/data/secret.txt
chmod 000 /tmp/lab08/data/secret.txt

cat > /tmp/lab08/backup.sh << 'SCRIPT'
#!/usr/bin/env bash
# BROKEN: no pipefail — find's exit 1 is silently discarded
TARGET_DIR=/tmp/lab08/data
BACKUP_FILE=/tmp/lab08/backup/archive.tar.gz

find "$TARGET_DIR" -type f 2>/dev/null | tar -czf "$BACKUP_FILE" -T - 2>/dev/null
echo "Backup complete. Archive: $BACKUP_FILE"
SCRIPT

chmod +x /tmp/lab08/backup.sh

echo "[day08] Incident injected."
echo "  /tmp/lab08/data/secret.txt is mode 000 — find will fail on it"
echo "  Run: bash /tmp/lab08/backup.sh"

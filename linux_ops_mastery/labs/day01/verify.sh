#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

# Passes when both hold:
#   (a) /var/log usage is under 20%, and
#   (b) any remaining deleted-but-open descriptor under /var/log has size 0.
# (b), not "no deleted descriptor at all", is what actually proves the space
# was reclaimed: truncating through the fd (the production-correct fix) can
# leave a zero-length "(deleted)" entry behind -- harmless, and gone the
# moment the holding process exits or reopens the file -- while killing the
# holder removes the entry outright. Both must pass; a nonzero-size deleted
# entry means the space was never actually freed.
used=$(in_app "df -P /var/log | awk 'NR==2 {gsub(/%/,\"\",\$5); print \$5}'")
used=${used:-100}

leftover=$(in_app '
for fd in /proc/[0-9]*/fd/*; do
  link=$(readlink "$fd" 2>/dev/null) || continue
  case "$link" in
    *"/var/log"*"(deleted)"*)
      size=$(stat -Lc %s "$fd" 2>/dev/null) || continue
      if [ "$size" -ne 0 ]; then echo "$fd size=$size"; fi
      ;;
  esac
done
:
')

if [ "$used" -lt 20 ] && [ -z "$leftover" ]; then
  echo "PASS: /var/log at ${used}% and no deleted-but-open file still holds bytes."
else
  echo "FAIL: usage=${used}% nonzero_deleted_fds=[${leftover}]" >&2
  exit 1
fi

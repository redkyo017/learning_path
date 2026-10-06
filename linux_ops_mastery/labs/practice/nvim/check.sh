#!/usr/bin/env bash
# Judge nvim drill N, or all of them. Run on the Mac, from anywhere.
# Usage: bash labs/practice/nvim/check.sh <N|all>
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
require_fleet

WB=nvim
MAX=20

# ok <N> <file> <expected-text> : byte-exact compare of dNN/<file>; prints PASS/FAIL (never exits)
ok() {
  local id; id="d$(printf %02d "$1")"
  local f; f="$(drill_dir "$WB" "$1")/$2"
  if ws_file_eq "$f" "$3"; then pass "$id" "$2 is exactly right"
  else fail "$id" "$2 differs from the expected result (diff above: - expected, + yours)"; fi
}
# ok_multi: several files; one PASS only if all match
ok_multi() { # <N> then pairs: file expected ...
  local n="$1" id bad=0 d; shift
  id="d$(printf %02d "$n")"; d="$(drill_dir "$WB" "$n")"
  while [ $# -ge 2 ]; do
    if ! ws_file_eq "$d/$1" "$2"; then bad=1; echo "  (above: $1)"; fi
    shift 2
  done
  if [ "$bad" -eq 0 ]; then pass "$id" "all files exactly right"
  else fail "$id" "a file differs from the expected result (diff above)"; fi
}

check_1() { ok 1 nginx.conf 'worker_processes auto;
events {
    worker_connections 1024;
}
http {
    include mime.types;
}
# end of nginx.conf'; }
check_2() { ok 2 backends.conf 'upstream web {
  server app1:8080;
  server app2:8080 backup;
}
server {
  location / { proxy_pass http://web; }
}'; }
check_3() { ok 3 deploy.sh '#!/usr/bin/env bash
set -euo pipefail
deploy() {
  local rel="$1"
  ln -sfn "/srv/releases/${rel}" /srv/current
  echo "deployed ${rel}"
}
deploy "$1"'; }
check_4() { ok 4 hosts.csv 'host,ip,env,region
web01,10.0.1.11,prod,eu
web02,10.0.1.12,prod,eu
web03,10.0.1.13,stage,eu
web04,10.0.1.14,stage,eu'; }
check_5() { ok 5 settings.ini 'host = web01
port = 80
retries = 3
  timeout = 3'; }
check_6() { ok 6 services.txt 'svc-c
svc-d # keep
svc-e'; }
check_7() { ok 7 deploy.env 'export APP_ENV="production"
MSG="restart () now"
retry'; }
check_8() { ok 8 service.xml '<service>
  <name>web</name>
  <port>8080</port>
</service>

<note>keep</note>'; }
check_9() { ok 9 api.conf 'location /api {
    proxy_pass http://127.0.0.1:9000;
    proxy_set_header Host $host;
}

location /api-v2 {
    proxy_pass http://127.0.0.1:9000;
    proxy_set_header Host $host;
}'; }
check_10() { ok 10 compose.yml 'env:
  FOO: 1
  BAR: 2
args:
    - -v
    - -q'; }
check_11() { ok 11 hosts.txt '# 10.0.0.11 node01 # eu
# 10.0.0.12 node02 # eu
# 10.0.0.13 node03 # eu
10.0.0.14 db01 # eu'; }
check_12() { ok 12 upstreams.conf 'upstream api {
  server 10.0.0.1:8080;
}
upstream web {
  server 10.0.0.1:8080;
}'; }
check_13() { ok 13 fleet.txt 'prod-web01 10.0.1.11
prod-web02 10.0.1.12
stage-db01 10.0.2.21
stage-cache1 10.0.2.31'; }
check_14() { ok 14 inventory.txt '- {host: web01, ip: 10.0.1.11}
- {host: web02, ip: 10.0.1.12}
- {host: web03, ip: 10.0.1.13}
- {host: web04, ip: 10.0.1.14}
- {host: web05, ip: 10.0.1.15}'; }
check_15() { ok 15 app.log '2026-10-06 10:00:01 INFO  start
2026-10-06 10:00:03 ERROR upstream timeout  <-- page
2026-10-06 10:00:05 WARN  slow query
2026-10-06 10:00:06 ERROR disk full  <-- page'; }
check_16() { ok 16 listen.conf '# edge
server web   { listen 8080; }
server api   { listen 8080; }
server admin { listen 80; }
# staging
server web-s { listen 80; }
server api-s { listen 80; }'; }
check_17() { ok 17 disk.txt '/srv 1024
/var/log 340
/var/lib 87
/home 12'; }
check_18() { ok 18 app.env 'export DB_HOST=db01;
export DB_PORT=5432;
export CACHE_TTL=300;'; }
check_19() { ok_multi 19 \
  app/web.conf 'upstream api { server api.internal:8080; }
proxy_pass http://api.internal/v1;
listen 80;' \
  app/batch.conf '# nightly
endpoint = api.internal
retries = 3' \
  docs/notes.md 'We used to call old-api.internal directly. Keep this note as history.'; }
check_20() { ok 20 app.conf 'export DB_HOST="db01"
export DB_PORT="5432"
export CACHE_TTL="300"
export LOG_LEVEL="warn"
export WORKERS="4"'; }

drills=$(arg_drills "${1:-}" "$MAX") || exit 2
for n in $drills; do
  "check_$n"
done
finish

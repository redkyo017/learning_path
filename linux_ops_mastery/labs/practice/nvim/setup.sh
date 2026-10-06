#!/usr/bin/env bash
# Seed (or re-seed) nvim drill N, or all of them, inside ws:/root/practice/nvim/dNN/.
# Usage (from anywhere, on the Mac):  bash labs/practice/nvim/setup.sh <N|all>
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"
require_fleet

WB=nvim
MAX=20

# put <N> <relative-path> < content  : write one seeded file into ws:/root/practice/nvim/dNN/
put() {
  local d; d="$(drill_dir "$WB" "$1")"
  in_ws "mkdir -p \"\$(dirname '$d/$2')\" && cat > '$d/$2'"
}

# fresh start: files plus any leftover nvim swap/undo state for this drill
fresh() {
  reset_drill "$WB" "$1"
  in_ws "rm -f /root/.local/state/nvim/undo/*practice%nvim%d$(printf %02d "$1")%* /root/.local/state/nvim/swap/*practice%nvim%d$(printf %02d "$1")%* 2>/dev/null || true"
}

seed_1() { put 1 nginx.conf <<'EOF'
worker_processes auto;
events {
    worker_connections 512;
}
http {
    include mime.types;
}
EOF
}
seed_2() { put 2 backends.conf <<'EOF'
upstream pool {
  server app1:8080;
  server app2:8080 down;
}
server {
  location / { proxy_pass http://pool; }
}
EOF
}
seed_3() { put 3 deploy.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
deploy() {
  local rel="$1"
  ln -sfn "/srv/releases/${rel}" /srv/current
}
deploy "$1"
EOF
}
seed_4() { put 4 hosts.csv <<'EOF'
host,ip,env,region
web01,10.0.1.11,prod,eu
web02,10.0.1.12,prod,eu
web03,10.0.1.13,prod,eu
web04,10.0.1.14,prod,eu
EOF
}
seed_5() { put 5 settings.ini <<'EOF'
# TODO drop
# TODO drop
# TODO drop
x host = web01
port = 80;junk
retries = 3
EOF
}
seed_6() { put 6 services.txt <<'EOF'
svc-a
svc-b
svc-c
svc-d
svc-e
EOF
}
seed_7() { put 7 deploy.env <<'EOF'
export APP_ENV="staging"
MSG="restart (pid 4121, uid 0) now"
retry(3, 5, 9)
EOF
}
seed_8() { put 8 service.xml <<'EOF'
<service>
  <name>web</name>
  <port>80</port>
</service>

# stale block
old-1
old-2

<note>keep</note>
EOF
}
seed_9() { put 9 api.conf <<'EOF'
location /api {
    proxy_pass http://127.0.0.1:9000;
    proxy_set_header Host $host;
}

location /api-v2 {
}
EOF
}
seed_10() { put 10 compose.yml <<'EOF'
env:
FOO: 1
BAR: 2
args:
- -v
- -q
EOF
}
seed_11() { put 11 hosts.txt <<'EOF'
10.0.0.11 web01
10.0.0.12 web02
10.0.0.13 web03
10.0.0.14 db01
EOF
}
seed_12() { put 12 upstreams.conf <<'EOF'
upstream api {
  server 10.0.0.1:8080;
}
# junk 1
# junk 2
upstream web {
  server 10.0.0.9:8080 down;
}
EOF
}
seed_13() { put 13 fleet.txt <<'EOF'
web01.prod.example.com 10.0.1.11
web02.prod.example.com 10.0.1.12
db01.stage.example.com 10.0.2.21
cache1.stage.example.com 10.0.2.31
EOF
}
seed_14() { put 14 inventory.txt <<'EOF'
web01 10.0.1.11
web02 10.0.1.12
web03 10.0.1.13
web04 10.0.1.14
web05 10.0.1.15
EOF
}
seed_15() { put 15 app.log <<'EOF'
# app.log (excerpt)
2026-10-06 10:00:01 INFO  start
2026-10-06 10:00:02 DEBUG cache hit
2026-10-06 10:00:03 ERROR upstream timeout

2026-10-06 10:00:04 DEBUG cache miss
-- rotated --
2026-10-06 10:00:05 WARN  slow query
2026-10-06 10:00:06 ERROR disk full
EOF
}
seed_16() { put 16 listen.conf <<'EOF'
# edge
server web   { listen 80; }
server api   { listen 80; }
server admin { listen 80; }
# staging
server web-s { listen 80; }
server api-s { listen 80; }
EOF
}
seed_17() { put 17 disk.txt <<'EOF'
/var/log 340
/home 12
/srv 1024
/var/lib 87
/home 12
EOF
}
seed_18() { put 18 app.env <<'EOF'
DB_HOST=db01

DB_PORT=5432

CACHE_TTL=300
EOF
}
seed_19() {
  put 19 app/web.conf <<'EOF'
upstream api { server old-api.internal:8080; }
proxy_pass http://old-api.internal/v1;
listen 80;
EOF
  put 19 app/batch.conf <<'EOF'
# nightly
endpoint = old-api.internal
retries = 3
EOF
  put 19 docs/notes.md <<'EOF'
We used to call old-api.internal directly. Keep this note as history.
EOF
}
seed_20() { put 20 app.conf <<'EOF'
db_host=db01
db_port=5432
cache_ttl=300
log_level=warn
workers=4
EOF
}

drills=$(arg_drills "${1:-}" "$MAX") || exit 2
for n in $drills; do
  fresh "$n"
  "seed_$n"
  echo "seeded d$(printf %02d "$n") in ws:$(drill_dir "$WB" "$n")"
done

#!/usr/bin/env bash
# Seed (reset) nvimfile drills inside the fleet. Run from anywhere:
#   bash labs/practice/nvimfile/setup.sh <N|all>     seed drill N (1..12) or all
#   bash labs/practice/nvimfile/setup.sh teardown     remove everything this workbook created
# Drill 7 needs a non-root user with sudo in ws: it uses the image's existing `ubuntu` user and
# the `sudo` package from the ws image, and adds /etc/sudoers.d/nvimfile (NOPASSWD + a sudo log).
# Without sudo in ws (image not rebuilt) drill 7 is skipped with a message; the others are seeded.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../lib/common.sh"
source "$HERE/../lib.sh"
WB=nvimfile
require_fleet

ws_sh()   { compose exec -T ws bash -s -- "$@"; }
slim_sh() { compose exec -T slim sh -s -- "$@"; }

teardown() {
  ws_sh <<'EOF'
for f in /root/practice/nvimfile/d08/holder.pid /root/practice/nvimfile/d09/holder.pid; do
  [ -f "$f" ] && kill "$(cat "$f")" 2>/dev/null || true
done
rm -f /root/.local/state/nvim/swap/%root%practice%nvimfile%* /home/ubuntu/.local/state/nvim/swap/%srv%nvimfile-d07%* 2>/dev/null || true
rm -rf /srv/nvimfile-d07 /etc/sudoers.d/nvimfile /var/log/nvimfile-sudo.log
pkill -9 -f 'nvim /root/practice/nvimfile/' 2>/dev/null || true
rm -rf /root/practice/nvimfile
EOF
  slim_sh <<'EOF'
rm -rf /root/practice/nvimfile
EOF
  echo "nvimfile: removed (ws:/root/practice/nvimfile, /srv/nvimfile-d07, sudoers drop-in; slim:/root/practice/nvimfile)"
}

seed_1() { ws_sh "$1" <<'EOF'
d=$1; O=/root/practice/nvimfile/.orig; mkdir -p "$O"; rm -rf "$d"; mkdir -p "$d"
for i in $(seq 1 60); do
  case $i in 23|41) lvl=ERROR;; 7|31) lvl=WARN;; *) lvl=INFO;; esac
  printf '2026-10-06 10:%02d:00 %s worker-%d event %d\n' "$i" "$lvl" $((i%3)) "$i"
done > "$d/app.log"
cp "$d/app.log" "$O/d01.log"; chmod 444 "$d/app.log"
EOF
}
seed_2() { ws_sh "$1" <<'EOF'
d=$1; rm -rf "$d"; mkdir -p "$d"
printf 'port=80\nworkers=2\n' > "$d/base.conf"
EOF
}
seed_3() { ws_sh "$1" <<'EOF'
d=$1; O=/root/practice/nvimfile/.orig; mkdir -p "$O"; rm -rf "$d"; mkdir -p "$d"
for i in $(seq 1 30); do
  if [ $((i%7)) -eq 0 ]; then l=ERROR; else l=INFO; fi
  printf 'line %02d [%s] job finished\n' "$i" "$l"
done > "$d/app.log"
cp "$d/app.log" "$O/d03.log"
printf '== summary ==\n' > "$d/summary.txt"
EOF
}
seed_4() { ws_sh "$1" <<'EOF'
d=$1; rm -rf "$d"; mkdir -p "$d"
printf '# site\nserver {\n    # INCLUDE HERE\n}\n' > "$d/site.conf"
printf '    listen 8080;\n    server_name demo;\n' > "$d/snippet.conf"
EOF
}
seed_5() { ws_sh "$1" <<'EOF'
d=$1; O=/root/practice/nvimfile/.orig; mkdir -p "$O"; rm -rf "$d"; mkdir -p "$d"
printf '# names\nzoe\namy\nbob\namy\nzoe\ncat\n' > "$d/names.txt"
printf '# generated, do not edit\n{"name":"demo","ports":[80,443],"debug":false}\n' > "$d/cfg.json"
cp "$d/cfg.json" "$O/d05.json"
EOF
}
seed_6() { ws_sh "$1" <<'EOF'
d=$1; O=/root/practice/nvimfile/.orig; mkdir -p "$O/d06"; rm -rf "$d" "$O/d06"/*; mkdir -p "$d/conf"
mk() { printf '%s\n' "$2" "${@:3}" > "$d/conf/$1"; }
mk a.conf 'server {' '    listen 80;' '}'
mk b.conf 'server {' '    listen 80;' '    root /srv/b;' '}'
mk c.conf 'server {' '    listen 8080;' '}'
mk d.conf 'server {' '    listen 80;' '    # listen 80; was here first' '}'
mk e.conf 'server {' '    listen 443;' '}'
touch -d '2020-01-01 00:00:00' "$d"/conf/*.conf
cp -p "$d"/conf/*.conf "$O/d06/"
EOF
}
seed_7() { ws_sh <<'EOF'
d=/srv/nvimfile-d07
mkdir -p /root/practice/nvimfile
if ! command -v sudo >/dev/null 2>&1; then
  echo "drill 7 needs sudo in ws, and this ws image has none. Rebuild ws:" >&2
  echo "  docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d --build ws" >&2
  exit 1
fi
id ubuntu >/dev/null 2>&1 || { echo "ws has no 'ubuntu' user" >&2; exit 1; }
mkdir -p /etc/sudoers.d
printf 'ubuntu ALL=(root) NOPASSWD: ALL\nDefaults:ubuntu logfile=/var/log/nvimfile-sudo.log\n' > /etc/sudoers.d/nvimfile
chmod 440 /etc/sudoers.d/nvimfile
rm -f /var/log/nvimfile-sudo.log /home/ubuntu/.local/state/nvim/swap/%srv%nvimfile-d07%* 2>/dev/null || true
rm -rf "$d"; mkdir -p "$d"; chmod 755 "$d"
printf 'max_conns=100\nlog=on\n' > "$d/app.conf"; chown root:root "$d/app.conf"; chmod 644 "$d/app.conf"
EOF
}
seed_8() { ws_sh "$1" <<'EOF'
d=$1
[ -f "$d/holder.pid" ] && kill "$(cat "$d/holder.pid")" 2>/dev/null || true
rm -rf "$d"; mkdir -p "$d"
printf 'mode=a\nkeep=1\n' > "$d/conf"
printf 'mode=a\nkeep=2\n' > "$d/shared"; ln "$d/shared" "$d/shared.link"
( setsid nohup sh -c 'echo $$ > "$1/holder.pid"; exec 3< "$1/conf"; exec sleep 36000' sh "$d" </dev/null >/dev/null 2>&1 & )
for _ in $(seq 1 50); do [ -s "$d/holder.pid" ] && break; sleep 0.1; done
[ -s "$d/holder.pid" ] || { echo "holder did not start" >&2; exit 1; }
EOF
}
seed_9() { ws_sh "$1" <<'EOF'
d=$1
[ -f "$d/holder.pid" ] && kill "$(cat "$d/holder.pid")" 2>/dev/null || true
rm -rf "$d"; mkdir -p "$d"
printf 'level=info\nretries=3\n' > "$d/live.conf"
( setsid nohup sh -c 'echo $$ > "$1/holder.pid"; exec 3< "$1/live.conf"; exec sleep 36000' sh "$d" </dev/null >/dev/null 2>&1 & )
for _ in $(seq 1 50); do [ -s "$d/holder.pid" ] && break; sleep 0.1; done
[ -s "$d/holder.pid" ] || { echo "holder did not start" >&2; exit 1; }
EOF
}
seed_10() { ws_sh "$1" <<'EOF'
d=$1; R=/root/practice/nvimfile/.run; mkdir -p "$R"
sw=/root/.local/state/nvim/swap/%root%practice%nvimfile%d10%notes.txt.swp
pkill -9 -f 'nvim /root/practice/nvimfile/d10/notes.txt' 2>/dev/null || true
rm -rf "$d" "$sw"; mkdir -p "$d"
printf 'one\ntwo\nthree\n' > "$d/notes.txt"
rm -f "$R/fifo"; mkfifo "$R/fifo"
( setsid nohup script -qfc "nvim $d/notes.txt" /dev/null < "$R/fifo" >/dev/null 2>&1 & )
exec 9> "$R/fifo"
sleep 1
printf 'GoUNSAVED line from a crashed session\033:preserve\r' >&9
for _ in $(seq 1 50); do [ -e "$sw" ] && sleep 1 && break; sleep 0.2; done
[ -e "$sw" ] || { echo "no swap file appeared" >&2; exit 1; }
# kill the UI nvim (the one whose parent is not nvim); its --embed child is orphaned to PID 1
ui=$(pgrep -f "^nvim $d/notes.txt" | head -1 || true)
[ -n "$ui" ] || { echo "terminal nvim not found" >&2; exit 1; }
pkill -9 -f "script -qfc nvim $d/notes.txt" 2>/dev/null || true
kill -9 "$ui"
sleep 1
exec 9>&-
rm -f "$R/fifo"
grep -q 'UNSAVED' "$d/notes.txt" && { echo "unexpected: edit reached disk" >&2; exit 1; }
true
EOF
}
seed_11() { ws_sh "$1" <<'EOF'
d=$1; rm -rf "$d"; mkdir -p "$d"
printf 'host=db1\r\nport=5432\r\nuser=app\r\n' > "$d/crlf.conf"
EOF
}
seed_12() { slim_sh <<'EOF'
d=/root/practice/nvimfile/d12
rm -rf "$d"; mkdir -p "$d"
printf 'alpha\r\nbeta\r\ngamma\r\ndelta\r\n' > "$d/win.conf"
printf '# collected\n' > "$d/out.txt"
EOF
}

case "${1:-}" in
  teardown) teardown; exit 0 ;;
esac
drills=$(arg_drills "${1:-}" 12) || exit 2
rc=0
ws_sh <<'EOF'
mkdir -p /root/practice/nvimfile/.orig /root/practice/nvimfile/.run
EOF
for n in $drills; do
  d="$(drill_dir "$WB" "$n")"
  case "$n" in
    7) seed_7 || { echo "d07 NOT seeded (see message above)"; rc=1; continue; } ;;
    12) seed_12 ;;
    *) "seed_$n" "$d" ;;
  esac
  printf 'seeded d%02d%s\n' "$n" "$([ "$n" = 12 ] && echo ' (in slim)' || echo '')"
done
exit $rc

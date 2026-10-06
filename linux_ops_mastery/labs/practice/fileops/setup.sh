#!/usr/bin/env bash
# Seed (or reset) fileops drills inside ws (d16 also in slim).  Usage: setup.sh <N|all>
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../lib/common.sh"
. "$HERE/../lib.sh"
require_fleet

MAX=16
ws_sh() { compose exec -T ws bash -s; }
D() { drill_dir fileops "$1"; }

seed_1() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d01
awk 'BEGIN{for(n=1;n<=200;n++) printf "2026-10-06 10:%02d:%02d %s req=%d\n", int(n/60), n%60, (n%25==0?"ERROR":"INFO"), n}' > app.log
chmod 640 app.log
ln app.log app.log.keep
EOS
}
seed_2() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d02
mkdir -p logs/old
printf 'GET /a 200\nGET /b timeout\nGET /c 200\nPOST /d timeout\n' > logs/web.log
printf 'ok\ntimeout upstream\nok\n' > logs/api.log
printf 'ok\nok\n' > logs/db.log
printf 'timeout\n' > logs/old/web.log.1
printf '# comment\nport=80\n\n# other\nuser=www\n' > conf.txt
EOS
}
seed_3() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d03
cat > access.log <<'EOF2'
10.0.0.1 GET /a 200
10.0.0.2 GET /b 502
10.0.0.3 POST /c 500
10.0.0.4 GET /d 404
10.0.0.5 GET /e 503
10.0.0.7 GET /v500 200
EOF2
printf '10.0.1.1 GET /x 200\n10.0.1.2 POST /y 200\n10.0.1.3 POST /z 500\n10.0.1.4 GET /w 200\n10.0.1.5 POST /q 201\n' | gzip -c > old.log.gz
EOS
}
seed_4() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d04
mkdir -p tree/sub
head -c 2048 /dev/zero > tree/a.tmp
head -c 10 /dev/zero > tree/b.tmp
head -c 3072 /dev/zero > tree/sub/c.tmp
head -c 5120 /dev/zero > "tree/sub/big name.tmp"
head -c 4096 /dev/zero > tree/keep.log
head -c 4096 /dev/zero > tree/sub/keep.txt
EOS
}
seed_5() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d05
mkdir -p tree/sub
for f in tree/a.conf tree/old.conf tree/sub/b.conf tree/sub/c.conf "tree/sub/new notes.txt" tree/recent.log "tree/sub/recent 2.log"; do echo x > "$f"; done
touch -d 2020-03-01 ref.stamp
touch -d 2020-04-01 tree/a.conf
touch -d 2020-02-01 tree/old.conf
touch -d 2020-05-01 tree/sub/b.conf
touch -d 2020-01-01 tree/sub/c.conf
touch -d 2020-06-01 "tree/sub/new notes.txt"
touch -d '1 day ago' tree/recent.log
touch -d '2 days ago' "tree/sub/recent 2.log"
EOS
}
seed_6() { :; }
seed_7() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d07
printf 'host=db1\ntimeout=30\nretries=3\n' > server.conf
EOS
}
seed_8() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d08
printf '2026-10-06 backup ok\n2026-10-07 restore failed\nsee 2026-10-08 note\n' > dates.txt
EOS
}
seed_9() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d09
printf 'name,role,status\nalice,admin,active\nbob,dev,active\ncarol,dev,active\n' > users.csv
ln users.csv users.snapshot
EOS
}
seed_10() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d10
mkdir -p src deploy
printf 'echo run\n' > src/run.sh; chmod 750 src/run.sh; touch -d 2020-01-01 src/run.sh
printf 'data\n' > src/data.txt; chmod 640 src/data.txt; touch -d 2020-06-01 src/data.txt
ln -s data.txt src/latest
printf 'setting=old\n' > deploy/app.conf
printf 'setting=new\n' > new.conf
EOS
}
seed_11() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d11
mkdir archive
printf 'x\n' > ./-oops.txt
printf 'x\n' > "my report.txt"
printf 'keep\n' > keep.txt
printf 'quarterly\n' > report.txt
ln report.txt report.anchor
EOS
}
seed_12() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d12
for i in 1 2 3 4 5; do printf 'old\n' > w$i; ln w$i w$i.pin; done
printf 'new\n' > new.txt
printf 'new\n' > new4
EOS
}
seed_13() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d13
printf 'b\na\nb\nc\na\n' > hosts.txt
ln hosts.txt hosts.pin
EOS
}
seed_14() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d14
printf 'mode=old\nlevel=3\n' > app.conf
ln app.conf app.conf.hl
EOS
}
seed_15() { ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d15
printf 'echo hi\n' > deploy.sh; chmod 644 deploy.sh
printf 'pw=1\n' > secret.conf; chmod 644 secret.conf
printf 'key=value\n' > src.txt
EOS
}
seed_16() {
  in_slim 'rm -rf /root/practice/fileops/d16 && mkdir -p /root/practice/fileops/d16 && cd /root/practice/fileops/d16 && printf "old\n" > dst && ln dst dst.pin && printf "new\n" > src'
  ws_sh <<'EOS'
set -e
cd /root/practice/fileops/d16
printf 'old\n' > dst; ln dst dst.pin; printf 'new\n' > src
EOS
}

drills=$(arg_drills "${1:-}" "$MAX") || exit 2
for n in $drills; do
  reset_drill fileops "$n"
  "seed_$n"
  echo "seeded $(drill_dir fileops "$n")$([ "$n" = 16 ] && echo ' (ws and slim)')"
done

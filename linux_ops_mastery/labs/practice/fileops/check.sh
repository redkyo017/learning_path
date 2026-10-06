#!/usr/bin/env bash
# Judge fileops drills from the end state in ws (d16 also reads slim).  Usage: check.sh <N|all>
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../../lib/common.sh"
. "$HERE/../lib.sh"
require_fleet

MAX=16
BAD=0   # set to 1 by any failed sub-check of the current drill
# eq <path> <expected>: exact compare (+ trailing newline); sets BAD on mismatch
eq() { if ws_file_eq "$1" "$2"; then :; else BAD=1; fi; }
# t <message> <ws-shell-test>: run in the drill dir; on failure print message, set BAD
t() { if in_ws "cd '$DIR' && $2" >/dev/null 2>&1; then :; else echo "  - $1"; BAD=1; fi; }
verdict() { if [ "$BAD" -eq 0 ]; then pass "$ID" "$1"; else fail "$ID" "$2"; fi; }

c1() {
  local l; l=$(for n in 40 41 42; do printf '2026-10-06 10:%02d:%02d INFO req=%d\n' $((n/60)) $((n%60)) "$n"; done)
  eq "$DIR/ans1.txt" "$l"
  eq "$DIR/ans2.txt" "$(printf '2026-10-06 10:03:19 INFO req=199\n2026-10-06 10:03:20 ERROR req=200')"
  eq "$DIR/ans3.txt" "200"
  eq "$DIR/ans4.txt" "640 2"
  eq "$DIR/ans5.txt" $'25:2026-10-06 10:00:25 ERROR req=25\n50:2026-10-06 10:00:50 ERROR req=50'
  eq "$DIR/ans6.txt" "ASCII text"
  t "app.log must be left untouched" 'awk '"'"'BEGIN{for(n=1;n<=200;n++) printf "2026-10-06 10:%02d:%02d %s req=%d\n", int(n/60), n%60, (n%25==0?"ERROR":"INFO"), n}'"'"' | cmp -s - app.log'
  verdict "six answers match" "an answer file is missing or differs (diff above; app.log must stay as seeded)"
}
c2() {
  eq "$DIR/ans1.txt" $'logs/api.log\nlogs/old/web.log.1\nlogs/web.log'
  eq "$DIR/ans2.txt" "2"
  eq "$DIR/ans3.txt" $'port=80\nuser=www'
  verdict "grep -rl, -c, -v answers match" "an answer file is missing or differs (diff above)"
}
c3() {
  eq "$DIR/ans1.txt" $'10.0.0.2 GET /b 502\n10.0.0.3 POST /c 500\n10.0.0.5 GET /e 503'
  eq "$DIR/ans2.txt" "3"
  verdict "5xx lines and POST count match" "an answer file is missing or differs (diff above; hint: /v500 is a path, not a status)"
}
c4() {
  local got
  got=$(in_ws "cd '$DIR' && find tree -type f | sort" 2>&1) || true
  if [ "$got" = $'tree/b.tmp\ntree/keep.log\ntree/sub/keep.txt' ]; then :; else
    echo "  remaining files were:"; printf '%s\n' "$got" | sed 's/^/    /'; BAD=1; fi
  verdict "big .tmp files gone, everything else kept" "wrong files remain (expected exactly tree/b.tmp tree/keep.log tree/sub/keep.txt)"
}
c5() {
  eq "$DIR/found.txt" $'tree/a.conf\ntree/sub/b.conf'
  eq "$DIR/found2.txt" $'tree/recent.log\ntree/sub/recent 2.log'
  verdict "found.txt and found2.txt match" "a list is missing or differs (diff above)"
}
c6() {
  eq "$DIR/notes.txt" $'one\ntwo\nthree\nfour\nfive'
  t "need exactly one tmp.* file made by mktemp -p ." 'test "$(ls tmp.* 2>/dev/null | wc -l)" = 1'
  t "the tmp.* file must contain: scratch" 'grep -qx scratch tmp.*'
  verdict "notes.txt built and mktemp file written" "notes.txt differs or the mktemp file is wrong"
}
c7() {
  eq "$DIR/server.conf" $'host=db1\ntimeout=60\nretries=3'
  eq "$DIR/server.conf.bak" $'host=db1\ntimeout=30\nretries=3'
  verdict "timeout changed, .bak holds the original" "server.conf or server.conf.bak differs (diff above)"
}
c8() {
  eq "$DIR/dates.txt" $'06/10/2026 backup ok\n07/10/2026 restore failed\nsee 2026-10-08 note'
  verdict "leading dates rewritten, mid-line date untouched" "dates.txt differs (diff above)"
}
c9() {
  eq "$DIR/users.csv" $'name,role,status\nalice,admin,active\nbob,dev,disabled\ncarol,dev,active'
  eq "$DIR/users.snapshot" $'name,role,status\nalice,admin,active\nbob,dev,active\ncarol,dev,active'
  t "users.csv must be a NEW inode (replaced by mv), not the one users.snapshot holds" '! [ users.csv -ef users.snapshot ]'
  t "only users.csv and users.snapshot may remain (no leftover temp file)" '[ "$(ls | sort | tr "\n" " ")" = "users.csv users.snapshot " ]'
  verdict "bob disabled via new file + mv; snapshot still old" "users.csv/snapshot wrong, or a temp file was left behind"
}
c10() {
  t "copy/src exists: copying into an existing copy/ nests src. rm -rf copy (or setup.sh 10) before cp -a" '[ ! -e copy/src ]'
  t "copy/run.sh missing" '[ -f copy/run.sh ]'
  t "copy/run.sh mode must be 750" '[ "$(stat -c %a copy/run.sh 2>/dev/null)" = 750 ]'
  t "copy/data.txt mode must be 640" '[ "$(stat -c %a copy/data.txt 2>/dev/null)" = 640 ]'
  t "copy must keep src mtimes (use cp -a)" '[ "$(stat -c %Y copy/run.sh)" = "$(stat -c %Y src/run.sh)" ] && [ "$(stat -c %Y src/run.sh)" -lt 1700000000 ]'
  t "copy/latest must stay a symlink to data.txt" '[ "$(readlink copy/latest)" = data.txt ]'
  eq "$DIR/deploy/app.conf" "setting=new"
  eq "$DIR/deploy/app.conf.~1~" "setting=old"
  verdict "cp -a copy faithful; app.conf replaced with numbered backup" "see the lines above"
}
c11() {
  local got
  got=$(in_ws "cd '$DIR' && find . -type f | sort" 2>&1) || true
  if [ "$got" = $'./archive/report.txt\n./keep.txt\n./report.anchor' ]; then :; else
    echo "  files were:"; printf '%s\n' "$got" | sed 's/^/    /'
    echo "  expected: ./archive/report.txt ./keep.txt ./report.anchor"; BAD=1; fi
  t "archive/report.txt must be the SAME inode as report.anchor (a rename, not copy+rm)" '[ archive/report.txt -ef report.anchor ]'
  verdict "dash and spaced names deleted, report moved by rename" "wrong files remain or the move was not a rename"
}
c12() {
  local i
  for i in 1 2 3 4 5; do t "w$i must contain: new" "[ \"\$(cat w$i)\" = new ]"; done
  for i in 1 3; do t "w$i.pin should show new (same inode writer)" "[ \"\$(cat w$i.pin)\" = new ]"; done
  for i in 2 4 5; do t "w$i.pin should still show old (new inode writer)" "[ \"\$(cat w$i.pin)\" = old ]"; done
  t "ans.txt must list w1 then w3, one per line, in w1..w5 order" '[ "$(cat ans.txt 2>/dev/null)" = "$(printf "w1\nw3")" ]'
  verdict "all five writers run; ans.txt names the same-inode ones" "see the lines above (run each writer on its own wN; ans.txt = same-inode ones)"
}
c13() {
  eq "$DIR/hosts.txt" $'a\nb\nc'
  t "hosts.pin must still be the same inode as hosts.txt" '[ hosts.txt -ef hosts.pin ]'
  verdict "deduped in place, inode kept" "hosts.txt wrong (empty?) or the inode changed"
}
c14() {
  eq "$DIR/app.conf" $'mode=new\nlevel=3'
  eq "$DIR/app.conf.hl" $'mode=old\nlevel=3'
  t "app.conf must have link count 1 (own inode)" '[ "$(stat -c %h app.conf)" = 1 ]'
  t "no extra files may remain" '[ "$(ls | sort | tr "\n" " ")" = "app.conf app.conf.hl " ]'
  verdict "app.conf updated on a new inode; the hard link untouched" "app.conf/app.conf.hl wrong, or the link was written through"
}
c15() {
  t "deploy.sh must be 755" '[ "$(stat -c %a deploy.sh)" = 755 ]'
  t "secret.conf must be 600" '[ "$(stat -c %a secret.conf)" = 600 ]'
  t "private.txt must exist with mode 600 (made under umask 077)" '[ "$(stat -c %a private.txt 2>/dev/null)" = 600 ]'
  t "private.d must be a directory" '[ -d private.d ]'
  t "private.d must be a directory with mode 700 (umask 077)" '[ "$(stat -c %a private.d 2>/dev/null)" = 700 ]'
  t "etc/app/app.conf must be mode 640 with src.txt contents" '[ "$(stat -c %a etc/app/app.conf 2>/dev/null)" = 640 ] && cmp -s src.txt etc/app/app.conf'
  verdict "modes correct" "see the lines above"
}
c16() {
  local d="$DIR" sp wp
  sp=$(in_slim "cd '$d' && cat dst; cat dst.pin" 2>&1 | tr '\n' ' ') || true
  wp=$(in_ws "cd '$d' && cat dst; cat dst.pin" 2>&1 | tr '\n' ' ') || true
  if [ "$sp" = "new old " ]; then :; else echo "  - slim: run  cp src dst  in slim (dst/dst.pin read: $sp)"; BAD=1; fi
  if [ "$wp" = "new new " ]; then :; else echo "  - ws: run  cp src dst  in ws (dst/dst.pin read: $wp)"; BAD=1; fi
  eq "$d/ans.txt" $'busybox: replaced\ngnu: in-place\nbusybox fd3: deleted'
  verdict "busybox replaced the inode, GNU truncated in place" "see the lines above (ans.txt lives in ws, in d16)"
}

drills=$(arg_drills "${1:-}" "$MAX") || exit 2
for n in $drills; do
  ID=$(printf 'd%02d' "$n"); DIR=$(drill_dir fileops "$n"); BAD=0
  "c$n"
done
finish

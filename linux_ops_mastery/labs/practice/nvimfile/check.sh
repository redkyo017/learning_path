#!/usr/bin/env bash
# Judge nvimfile drills. Run from anywhere: bash labs/practice/nvimfile/check.sh <N|all>
# Prints PASS dNN ... / FAIL dNN: <what is wrong>; exits non-zero on any FAIL.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../lib/common.sh"
source "$HERE/../lib.sh"
WB=nvimfile
require_fleet
P=/root/practice/nvimfile
O=$P/.orig

# not_set_up N: true (after printing FAIL) if drill N's directory is missing
not_set_up() { local n=$1 id; id=$(printf d%02d "$n")
  local d=$P/$id; [ "$n" = 7 ] && d=/srv/nvimfile-d07
  if [ "$n" = 12 ]; then in_slim "test -d $d" >/dev/null 2>&1 && return 1
  else in_ws "test -d $d" >/dev/null 2>&1 && return 1; fi
  fail "$id" "not set up: run  bash labs/practice/nvimfile/setup.sh $n"; return 0; }

# run "<ws shell snippet>"; on non-zero print its output and return 1
ws_ok() { local out; if out=$(in_ws "$1" 2>&1); then return 0; else [ -n "$out" ] && printf '%s\n' "$out"; return 1; fi; }

c1() { not_set_up 1 && return; local d f="$P/d01/app.log" exp
  exp=$(in_ws "sed '0,/ERROR/s//RESOLVED/' $O/d01.log" 2>&1) || { fail d01 "cannot read the pristine copy: re-run setup.sh 1"; return; }
  ws_file_eq "$f" "$exp" || { fail d01 "app.log should differ from the original only in the first ERROR (now RESOLVED); diff above"; return; }
  [ "$(in_ws "stat -c %a $f" 2>/dev/null || true)" = 444 ] || { fail d01 "app.log permissions changed from 444"; return; }
  pass d01 "first ERROR resolved, permissions intact"; }

c2() { not_set_up 2 && return; local d=$P/d02
  ws_file_eq "$d/base.conf" $'port=80\nworkers=2' >/dev/null || { fail d02 "base.conf must stay untouched (port=80, workers=2); :w name writes a copy, it must not change the original"; return; }
  ws_file_eq "$d/staging.conf" $'port=8080\nworkers=2' || { fail d02 "staging.conf should hold port=8080 (written with :w staging.conf)"; return; }
  ws_file_eq "$d/prod.conf" $'port=9090\nworkers=2\n# reviewed' || { fail d02 "prod.conf should be port=9090, workers=2, then '# reviewed' (:saveas, then edit, then :wq)"; return; }
  pass d02 "base.conf untouched, staging.conf and prod.conf as expected"; }

c3() { not_set_up 3 && return; local d=$P/d03 exp
  exp=$(in_ws "sed -n 10,14p $O/d03.log" 2>&1) || { fail d03 "cannot read the pristine copy: re-run setup.sh 3"; return; }
  ws_file_eq "$d/part.txt" "$exp" || { fail d03 "part.txt should be exactly lines 10-14 of app.log"; return; }
  exp=$(in_ws "echo '== summary =='; sed -n 1p $O/d03.log; grep ERROR $O/d03.log" 2>&1) || { fail d03 "cannot read the pristine copy: re-run setup.sh 3"; return; }
  ws_file_eq "$d/summary.txt" "$exp" || { fail d03 "summary.txt should be the header, line 1, then every ERROR line (appended, not overwritten)"; return; }
  ws_file_eq "$d/app.log" "$(in_ws "cat $O/d03.log" 2>/dev/null || true)" >/dev/null || { fail d03 "app.log itself must not change"; return; }
  pass d03 "range written and appended"; }

c4() { not_set_up 4 && return; local d=$P/d04 h
  h=$(in_ws hostname 2>/dev/null || true)
  ws_file_eq "$d/site.conf" "$h"$'\n# site\nserver {\n    # INCLUDE HERE\n    listen 8080;\n    server_name demo;\n}' \
    && pass d04 "hostname on line 1, snippet below the marker" \
    || fail d04 "site.conf: line 1 must be this host's name ($h), snippet.conf must sit directly below the INCLUDE marker"; }

c5() { not_set_up 5 && return; local d=$P/d05 exp
  ws_file_eq "$d/names.txt" $'# names\namy\nbob\ncat\nzoe' || { fail d05 "names.txt: keep '# names' first, then the names sorted and unique"; return; }
  exp=$(in_ws "head -1 $O/d05.json; tail -n +2 $O/d05.json | jq ." 2>&1) || { fail d05 "cannot read the pristine copy: re-run setup.sh 5"; return; }
  ws_file_eq "$d/cfg.json" "$exp" || { fail d05 "cfg.json: keep the comment line, pretty-print only the JSON line (select it, :'<,'>!jq .)"; return; }
  pass d05 "range filter and jq filter done"; }

c6() { not_set_up 6 && return; local d=$P/d06/conf out
  out=$(in_ws "cd $O/d06 && for f in *.conf; do sed 's/listen 80;/listen 8080;/' \$f | diff -u --label \"expected \$f\" --label \"\$f\" - $d/\$f || true; done")
  if [ -n "$out" ]; then printf '%s\n' "$out"; fail d06 "conf files differ from the expected result (diff above)"; return; fi
  out=$(in_ws "cd $d && for f in c.conf e.conf; do [ \"\$(stat -c %Y \$f)\" = 1577836800 ] || echo \"\$f was rewritten (mtime changed)\"; done")
  if [ -n "$out" ]; then printf '%s\n' "$out"; fail d06 "files with nothing to change must not be written (use :update, not :w/:wq)"; return; fi
  pass d06 "all matches changed, untouched files left alone"; }

c7() { not_set_up 7 && return; local f=/srv/nvimfile-d07/app.conf out log=/var/log/nvimfile-sudo.log
  ws_file_eq "$f" $'max_conns=500\nlog=on' || { fail d07 "app.conf should read max_conns=500 / log=on"; return; }
  out=$(in_ws "stat -c '%U:%G %a' $f" 2>/dev/null || true)
  [ "$out" = "root:root 644" ] || { fail d07 "owner/mode is '$out', expected root:root 644 (the file must not have been replaced)"; return; }
  ws_ok "[ -f $log ] && tr '\\n' ' ' < $log | grep -E 'ubuntu : .*USER=root .*COMMAND=/usr/bin/tee .*app.conf' >/dev/null" \
    || { fail d07 "no sudo-tee entry for ubuntu in $log: do the edit as the ubuntu user, saving with :w !sudo tee % >/dev/null"; return; }
  pass d07 "root-owned file edited by ubuntu through sudo tee, owner and mode intact"; }

c8() { not_set_up 8 && return; local d=$P/d08 a pid out
  ws_file_eq "$d/conf" $'mode=b\nkeep=1' >/dev/null || { fail d08 "conf should have mode=b (edit it with nvim, :wq)"; return; }
  ws_file_eq "$d/shared" $'mode=b\nkeep=2' >/dev/null || { fail d08 "shared should have mode=b (edit it with nvim, :wq)"; return; }
  out=$(in_ws "cd $d; [ shared -ef shared.link ] || echo 'shared and shared.link are no longer the same inode: something replaced shared (sed -i? a rename?). Re-run setup.sh 8 and edit with nvim'; [ \"\$(stat -c %h shared)\" = 2 ] || echo 'shared should still have link count 2'; [ \"\$(cat shared.link)\" = \"\$(printf 'mode=b\nkeep=2')\" ] || echo 'shared.link does not show the edit'" 2>&1 || true)
  [ -z "$out" ] || { printf '%s\n' "$out"; fail d08 "hard-link edit not as expected (see above)"; return; }
  pid=$(in_ws "cat $d/holder.pid" 2>/dev/null || true)
  if [ -z "$pid" ] || ! in_ws "test -r /proc/$pid/fd/3 && ! grep -q '^State:.Z' /proc/$pid/status" >/dev/null 2>&1; then
    fail d08 "the fd holder on conf is gone: re-run setup.sh 8 (do not kill it)"; return; fi
  out=$(in_ws "readlink /proc/$pid/fd/3" 2>/dev/null || true)
  [ "$out" = "$d/conf~ (deleted)" ] || { fail d08 "the pinned fd on conf reads '$out'; edit conf with nvim's default :w (rename to conf~), not sed -i or an in-place write"; return; }
  ws_file_eq "/proc/$pid/fd/3" $'mode=a\nkeep=1' >/dev/null || { fail d08 "the pinned fd should still see the old content"; return; }
  a=$(in_ws "cat $d/answers.txt 2>/dev/null" 2>/dev/null || true)
  [ "$a" = $'renamed\nyes' ] && pass d08 "conf moved to a new inode (pinned fd: conf~ deleted), shared stayed on its inode, answers right" \
    || fail d08 "answers.txt must have two lines: Q1 'renamed' or 'inplace', Q2 'yes' or 'no' (observe with the pinned fd first); got: $(printf '%s' "$a" | tr '\n' '|')"; }

c9() { not_set_up 9 && return; local d=$P/d09 pid
  pid=$(in_ws "cat $d/holder.pid" 2>/dev/null || true)
  if [ -z "$pid" ] || ! in_ws "test -r /proc/$pid/fd/3 && ! grep -q '^State:.Z' /proc/$pid/status" >/dev/null 2>&1; then
    fail d09 "holder gone: re-run setup.sh 9 (do not kill it)"; return; fi
  ws_file_eq "$d/live.conf" $'level=debug\nretries=3' >/dev/null || { fail d09 "live.conf should read level=debug / retries=3"; return; }
  ws_file_eq "/proc/$pid/fd/3" $'level=debug\nretries=3' >/dev/null \
    || { fail d09 "live.conf is right, but the process holding it open still sees the OLD content: your :w replaced the file (new inode)"; return; }
  pass d09 "the running reader sees your edit: same inode was rewritten"; }

c10() { not_set_up 10 && return; local d=$P/d10 sw='/root/.local/state/nvim/swap/%root%practice%nvimfile%d10%notes.txt.swp'
  ws_file_eq "$d/notes.txt" $'one\ntwo\nthree\nUNSAVED line from a crashed session' || { fail d10 "notes.txt should contain the recovered line after 'three' (recover with R, then :w)"; return; }
  if in_ws "test -e '$sw'" >/dev/null 2>&1; then fail d10 "the stale swap file still exists: remove it (rm, or D at the prompt when offered)"; return; fi
  pass d10 "edit recovered and stale swap file removed"; }

c11() { not_set_up 11 && return; local f=$P/d11/crlf.conf
  if in_ws "grep -q \$'\\r' $f"; then fail d11 "crlf.conf still contains CR bytes"; return; fi
  ws_file_eq "$f" $'host=db1\nport=5432\nuser=app' && pass d11 "line endings are LF" || fail d11 "content changed besides the line endings"; }

c12() { not_set_up 12 && return; local d=/root/practice/nvimfile/d12 out
  out=$(in_slim "cd $d; [ \"\$(od -c win.conf | grep -c '\\\\r')\" = 0 ] || echo 'win.conf still has CR'; [ \"\$(cat win.conf)\" = \"\$(printf 'alpha\nbeta\ngamma\ndelta')\" ] || echo 'win.conf content wrong'; [ \"\$(cat part 2>/dev/null)\" = \"\$(printf 'gamma\ndelta')\" ] || echo 'part must hold exactly gamma, delta (clean, no CR): write it again with :3,4w! part after stripping'; [ \"\$(cat out.txt)\" = \"\$(printf '# collected\ngamma\ndelta')\" ] || echo 'out.txt must be # collected, gamma, delta'" 2>&1)
  if [ -z "$out" ]; then pass d12 "slim: CR stripped, range written, out.txt assembled"
  else printf '%s\n' "$out"; fail d12 "see messages above"; fi; }

drills=$(arg_drills "${1:-}" 12) || exit 2
for n in $drills; do "c$n"; done
finish

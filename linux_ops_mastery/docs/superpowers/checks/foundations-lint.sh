#!/usr/bin/env bash
# Structural lint for content/foundations chapters. See the plan
# docs/superpowers/plans/2026-10-08-linux-foundations-plan.md, Task 1.
set -u
G=/usr/bin/grep
links_only=0
[ "${1:-}" = "--links-only" ] && { links_only=1; shift; }
rc=0
[ $# -ge 1 ] || { echo "usage: foundations-lint.sh [--links-only] FILE..." >&2; exit 2; }

fail() { echo "FAIL $1: $2"; bad=1; }

check_links() {
  f=$1; dir=$(dirname "$f")
  # ](target) pairs; skip http(s), mailto, pure anchors
  $G -oE '\]\([^)]+\)' "$f" | sed -E 's/^\]\(//; s/\)$//' | while read -r t; do
    case "$t" in http*|mailto:*|\#*) continue ;; esac
    p=${t%%#*}
    [ -e "$dir/$p" ] || echo "FAIL $f: broken link -> $t"
  done
}

section() { # print body of H2 section $2 in file $1
  awk -v h="## $2" '
    /^```/ { fence=!fence }
    fence && /^## / { next }
    $0==h {p=1; next}
    /^## / && !fence {p=0}
    p' "$1"
}

for f in "$@"; do
  bad=0
  [ -f "$f" ] || { echo "FAIL $f: missing"; rc=1; continue; }
  out=$(check_links "$f"); [ -n "$out" ] && { echo "$out"; bad=1; }
  if [ $links_only -eq 0 ]; then
    want="## What you'll be able to explain|## The mental model|## How it connects|## See it yourself|## Words you'll meet in the course|## Self-check"
    got=$(awk '
      /^```/ { fence=!fence; next }
      fence { next }
      /^## / { print }' "$f" | paste -sd'|' -)
    [ "$got" = "$want" ] || fail "$f" "H2 headings/order wrong: $got"
    n=$(wc -l < "$f" | tr -d ' ')
    min=250; case "$(basename "$f")" in 00-*) min=150 ;; esac
    { [ "$n" -ge $min ] && [ "$n" -le 400 ]; } || fail "$f" "length $n not in $min-400"
    tries=$(section "$f" "See it yourself" | $G -c '^```bash')
    { [ "$tries" -ge 4 ] && [ "$tries" -le 8 ]; } || fail "$f" "$tries bash blocks in See it yourself (want 4-8)"
    looks=$(section "$f" "See it yourself" | $G -c '^\*\*What to look for:\*\*')
    [ "$looks" -ge "$tries" ] || fail "$f" "$looks 'What to look for' lines for $tries blocks"
    if section "$f" "See it yourself" | awk '/^```bash/{p=1;next} /^```/{p=0} p' \
        | sed -E 's/[0-9]*&?>>?\/dev\/(null|stderr)( |$)/ /g; s/[0-9]*>&[0-9-]//g; s/kill -[l0][0-9 ]*(\$\$|[0-9]*)//g; s/->//g; s/=>//g' \
        | $G -qE '(^|[;&| ])kill( |$)|(^|[;&| ])(pkill|killall|rm|mv|truncate|chmod|chown|systemctl (start|stop|restart)|nft (add|delete|flush|insert|replace|create)|iptables|ip (link|addr|route) (add|del|set)|tee|dd|touch|mkdir|cp|ln|mount|umount)( |$)|sed (-[a-zA-Z]*i|--in-place)|sysctl -w|systemctl (enable|disable|mask)|ip netns (add|del)|ip (addr|link|route) flush|[0-9]?>>?[ ]?[^ &]'; then
      fail "$f" "See it yourself contains a mutating command"
    fi
    qs=$(section "$f" "Self-check" | awk '/<details>/{exit} {print}' | $G -cE '^[0-9]+\. ')
    { [ "$qs" -ge 5 ] && [ "$qs" -le 6 ]; } || fail "$f" "$qs self-check questions (want 5-6)"
    section "$f" "Self-check" | $G -q '<details><summary>Answers</summary>' || fail "$f" "no <details><summary>Answers</summary>"
    $G -qE 'TODO|TBD|FIXME' "$f" && fail "$f" "placeholder text"
  fi
  [ $bad -eq 0 ] && echo "OK $f" || rc=1
done
exit $rc

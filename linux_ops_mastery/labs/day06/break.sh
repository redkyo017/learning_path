#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../lib" && pwd)/common.sh"
require_fleet

# proxy has no dedicated helper in ../lib/common.sh (only ws/app/slim do,
# since it's the one service every other day ignores). It is Alpine, same
# as app and slim, so every command below is busybox-sh-safe.
in_proxy() { compose exec -T proxy sh -c "$1"; }

usage() {
  echo "usage: $0 [1-5|random]  (default: 1)" >&2
  exit 1
}

FAULT="${1:-1}"
if [ "$FAULT" = "random" ]; then
  FAULT=$(( (RANDOM % 5) + 1 ))
fi
case "$FAULT" in
  1|2|3|4|5) ;;
  *) usage ;;
esac

# ---------------------------------------------------------------------------
# Reset. The five faults are mutually exclusive by design -- exactly one
# rung is broken at a time -- so every run starts by undoing all five,
# regardless of which one is requested next. Without this, `break.sh random`
# for re-practice (README.md's second use) would pile faults on top of
# whatever an earlier run, or an earlier fix attempt, left behind.
# ---------------------------------------------------------------------------

reset_dns() {
  # Docker's own default for a container with no custom DNS config.
  in_proxy 'printf "nameserver 127.0.0.11\noptions ndots:0\n" \
    > /etc/resolv.conf && nginx -s reload' >/dev/null 2>&1 || true
}

reset_route() {
  # Fault 2 never touches the default or connected route (see
  # inject_2_route below for why); it only adds an `unreachable` route for
  # app's specific address, so undoing it is exactly clearing that one
  # route type, whatever address it currently names.
  in_proxy 'ip route flush type unreachable' >/dev/null 2>&1 || true
}

reset_nft() {
  in_proxy 'nft delete table inet day06' >/dev/null 2>&1 || true
}

reset_app() {
  # One restart undoes both fault 4 (compose's own service definition sets
  # BIND_ADDR back to 0.0.0.0) and fault 5 (sticky failure lives only in
  # the process's memory -- app.py's module-level STICKY_CODE -- so a fresh
  # process has none).
  docker rm -f linuxops-app-1 >/dev/null 2>&1 || true
  compose up -d app >/dev/null 2>&1 || true
  sleep 1
}

reset_dns
reset_route
reset_nft
reset_app

# ---------------------------------------------------------------------------
# Inject. Every fault produces the exact same symptom; the file that proves
# which one it is differs, and that file is the whole lab.
# ---------------------------------------------------------------------------

inject_1_dns() {
  # nginx's resolver is read when the config LOADS, not per request (see the
  # comment block at the top of seed/nginx.conf). Overwriting resolv.conf
  # alone leaves nginx using whatever resolver it already loaded, so the
  # `nginx -s reload` is not cleanup -- it is the step that makes this fault
  # actually reach the proxy path at all. Skipping it is the single most
  # common way to "inject" fault 1 and have the rung silently pass.
  in_proxy 'printf "nameserver 10.255.255.1\n" > /etc/resolv.conf
    nginx -s reload'
}

inject_2_route() {
  # `ip route del default` alone survives on this fleet: every service sits
  # on one flat linuxops_net subnet, so the kernel's own connected route
  # (scope link, installed the instant the interface got its address) still
  # gets proxy to app with no default route at all -- deleting only the
  # default would leave this rung passing by accident. A targeted
  # `unreachable` route for app's own address is what actually reproduces
  # "no route to the destination": longest-prefix match picks this single
  # /32 over the broader connected route, so packets to app fail at the
  # routing decision with no packet ever sent -- and every other
  # destination, including the DNS resolver at 127.0.0.11, is untouched,
  # so rung 1's file still checks out under this fault.
  # Resolve app's address while DNS is still good (reset_dns just ran).
  app_ip="$(in_proxy 'getent hosts app' | awk '{print $1}')"
  in_proxy "ip route add unreachable ${app_ip}/32"
}

inject_3_firewall() {
  # A dedicated table keeps this rule easy to find and easy to remove
  # without guessing at whatever else nft already has loaded.
  compose exec -T proxy nft -f - >/dev/null <<'NFT'
table inet day06 {
	chain output {
		type filter hook output priority 0;
		tcp dport 8080 drop
	}
}
NFT
}

inject_4_bind() {
  # There is no compose-level way to override one service's environment for
  # a single run without editing docker-compose.yml (Task 2's contract,
  # consumed here, not modified). Rebuilding the container by hand, from
  # the same built image, with only BIND_ADDR flipped, is the equivalent of
  # a redeploy with one changed environment variable -- exactly fault 4's
  # premise (an ECS task revision that binds to 127.0.0.1 by accident).
  image="$(docker inspect --format '{{.Config.Image}}' linuxops-app-1)"
  docker rm -f linuxops-app-1 >/dev/null 2>&1 || true
  docker run -d --name linuxops-app-1 \
    --network linuxops_net --network-alias app \
    --label com.docker.compose.project=linuxops \
    --label com.docker.compose.service=app \
    -e BIND_ADDR=127.0.0.1 -e PORT=8080 -e LOG_PATH=/var/log/app.log \
    -e IGNORE_SIGTERM=0 \
    "$image" >/dev/null
  sleep 1
}

inject_5_app() {
  # app has no curl/wget guaranteed; python3 always is. HTTPError is
  # expected here -- /fail always answers with the code it was asked to
  # arm, so a 502 response is success, not failure, for this call.
  compose exec -T app python3 -c '
import urllib.request, urllib.error
try:
    urllib.request.urlopen("http://127.0.0.1:8080/fail?code=502&sticky=1")
except urllib.error.HTTPError:
    pass
' >/dev/null
}

case "$FAULT" in
  1) inject_1_dns ;;
  2) inject_2_route ;;
  3) inject_3_firewall ;;
  4) inject_4_bind ;;
  5) inject_5_app ;;
esac

# Recorded on the container, never on the host and never printed here, so
# the learner cannot see which rung broke by accident.
in_proxy "echo ${FAULT} > /tmp/.day06-fault"

symptom "http://localhost:8080/ through proxy returns nothing useful."

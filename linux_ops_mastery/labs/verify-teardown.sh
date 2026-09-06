#!/usr/bin/env bash
# verify-teardown.sh -- prove the lab left nothing behind.
#
#   ./labs/verify-teardown.sh
#
# Exits 0 only when there is no container, network, volume or dangling image
# belonging to the `linuxops` project. Exits 1 and prints the command that
# cleans up when there is. Run it at the end of every day; "I think I stopped
# it" is not an operational statement.
#
# Host side (macOS). Read only: this script reports, it never deletes.
set -uo pipefail

PROJECT="linuxops"
NETWORK="linuxops_net"
LABEL="com.docker.compose.project=${PROJECT}"
FLEET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/fleet" && pwd)"
DOWN_CMD="docker compose -p ${PROJECT} down -v --remove-orphans"

leftovers=0

heading() { printf '\n== %s\n' "$1"; }
ok()      { printf '  ok      %s\n' "$1"; }
found()   { printf '  LEFT    %s\n' "$1"; leftovers=$((leftovers + 1)); }
note()    { printf '  note    %s\n' "$1"; }

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is not on PATH; nothing to verify." >&2
  exit 2
fi
if ! docker info >/dev/null 2>&1; then
  echo "The Docker daemon is not reachable. Start Docker Desktop (or" >&2
  echo "\`colima start\`) and run this again -- a stopped daemon is not" >&2
  echo "the same thing as a clean teardown." >&2
  exit 2
fi

heading "containers (project ${PROJECT})"
containers="$(docker ps -a --filter "label=${LABEL}" \
                --format '{{.Names}} [{{.State}}] {{.Image}}' 2>/dev/null)"
if [ -z "${containers}" ]; then
  ok "none"
else
  while IFS= read -r line; do
    [ -n "${line}" ] && found "container ${line}"
  done <<< "${containers}"
fi

heading "networks"
networks="$(docker network ls --format '{{.Name}}' 2>/dev/null \
              | grep -E "^${NETWORK}$|^${PROJECT}[_-]" )"
if [ -z "${networks}" ]; then
  ok "none"
else
  while IFS= read -r line; do
    [ -n "${line}" ] && found "network ${line}"
  done <<< "${networks}"
fi

heading "volumes (named ${PROJECT}*)"
volumes="$(docker volume ls --format '{{.Name}}' 2>/dev/null \
             | grep -E "^${PROJECT}[_-]?" )"
if [ -z "${volumes}" ]; then
  ok "none"
else
  while IFS= read -r line; do
    [ -n "${line}" ] && found "volume ${line}   (needs the -v in ${DOWN_CMD})"
  done <<< "${volumes}"
fi

heading "dangling images built by the fleet"
dangling="$(docker images --filter 'dangling=true' --filter "label=${LABEL}" \
              --format '{{.ID}} {{.CreatedSince}}' 2>/dev/null)"
if [ -z "${dangling}" ]; then
  ok "none"
else
  while IFS= read -r line; do
    [ -n "${line}" ] && found "dangling image ${line}"
  done <<< "${dangling}"
fi

heading "tagged fleet images (informational, not a leftover)"
images="$(docker images --filter "reference=${PROJECT}-*" \
            --format '{{.Repository}} {{.ID}} {{.Size}}' 2>/dev/null)"
if [ -z "${images}" ]; then
  note "none built yet"
else
  while IFS= read -r line; do
    [ -n "${line}" ] && note "image ${line}"
  done <<< "${images}"
  note "keep these; rebuilding ws takes minutes. To reclaim the space:"
  note "  docker image rm ${PROJECT}-ws ${PROJECT}-app ${PROJECT}-proxy"
  note "  docker image rm ${PROJECT}-sysd"
fi

printf '\n'
if [ "${leftovers}" -eq 0 ]; then
  echo "CLEAN: no containers, networks, volumes or dangling images remain."
  exit 0
fi

echo "${leftovers} item(s) still exist. Clean up with:"
echo
echo "  cd ${FLEET_DIR}"
echo "  ${DOWN_CMD}"
echo
echo "If Day 5's systemd container is among them, include the overlay"
echo "(the -f flags go before the subcommand, not after it):"
echo
echo "  docker compose -p ${PROJECT} \\"
echo "    -f docker-compose.yml -f docker-compose.sysd.yml \\"
echo "    down -v --remove-orphans"
echo
echo "Then run this script again."
exit 1

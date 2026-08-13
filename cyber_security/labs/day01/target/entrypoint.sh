#!/bin/sh
# Day 1 target entrypoint: start the leaky legacy-service banner listener on
# 2121 in the background (loops forever, one connection at a time), then run
# nginx in the foreground as the container's main process.
set -eu

(
  while true; do
    busybox nc -l -p 2121 < /banner.txt
  done
) &

exec nginx -g "daemon off;"

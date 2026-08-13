#!/bin/sh
# Day 6 box entrypoint: start sshd in the background (host keys were
# generated at build time), then run nginx in the foreground as the
# container's main process — same shape as labs/day01/target/entrypoint.sh.
set -eu

/usr/sbin/sshd

exec nginx -g "daemon off;"

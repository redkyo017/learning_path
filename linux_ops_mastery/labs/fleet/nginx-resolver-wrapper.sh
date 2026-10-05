#!/bin/sh
# Installed in proxy as /usr/local/sbin/nginx, ahead of the real
# /usr/sbin/nginx on PATH. Every `nginx ...` call -- the container's own
# start-up CMD, and every `nginx -s reload` on Day 6 -- first rewrites
# /etc/nginx/resolver.conf from the nameservers in /etc/resolv.conf, then
# hands over to the real binary.
#
# Why: stock nginx has no "use /etc/resolv.conf" option for its `resolver`
# directive (`resolver local=on` exists in no upstream release and makes
# nginx refuse to start). Day 6 fault 1 depends on exactly that behaviour:
# rewrite /etc/resolv.conf, `nginx -s reload`, and the proxy path follows
# the new nameserver. This wrapper is what makes that true.
ns=$(awk '$1 == "nameserver" { printf "%s ", $2 }' /etc/resolv.conf 2>/dev/null)
printf 'resolver %s valid=10s ipv6=off;\n' "${ns:-127.0.0.11}" \
  > /etc/nginx/resolver.conf
exec /usr/sbin/nginx "$@"

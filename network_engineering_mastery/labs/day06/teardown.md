# Day 6 teardown

Run inside `netlab`, from `/course`.

- [ ] Remove any ESP state you added: `for s in va vb; do ip netns exec $s ip xfrm state flush; ip netns exec $s ip xfrm policy flush; done`
      (this goes away with the namespaces anyway).
- [ ] Bring the topology down: `bash labs/day06/topo.sh down`
      (and `bash labs/day06/geneve.sh down` if you ran the GENEVE lab last).
- [ ] No namespaces left: `ip netns list` prints nothing.
- [ ] No daemon left: `ps -e | /usr/bin/grep -E 'unbound|tcpdump' || echo none`
      prints `none`. Stop any `tcpdump` still running in a spare shell.
- [ ] `/etc/netns` is empty: `ls /etc/netns` prints nothing.
- [ ] Check the whole course: `bash labs/verify-teardown.sh` (run it on the Mac after
      `docker compose -p netlab down` when you are finished for the day).
- [ ] `journal.md` has the Day 6 entry: the two evidence chains, the 50-byte arithmetic,
      and the one-line "Route 53 Resolver in AWS is X on the wire" mapping.

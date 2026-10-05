# Day 5 teardown

Run inside `netlab`, from `/course`.

- [ ] Stop any capture left in a spare shell, and any background `ping`
      (`jobs`, then `kill %1`). `/tmp/bgp.pcap` can stay or go.
- [ ] Bring the BGP topology down: `bash labs/day05/topo.sh down`
- [ ] If you ran the TGW box: `bash labs/day05/vrf.sh down`
- [ ] No namespaces left: `ip netns list` prints nothing.
- [ ] No daemon left: `ps -e | /usr/bin/grep -E 'zebra|bgpd|tcpdump' || echo none`
      prints `none`.
- [ ] Check the whole course: `bash labs/verify-teardown.sh` (run it on the Mac after
      `docker compose -p netlab down` when you are finished for the day).
- [ ] `journal.md` has the Day 5 entry: the evidence chain for both faults, the
      best-path predictions you got wrong, and the one-line "X in AWS is Y on the wire"
      for TGW association and propagation.

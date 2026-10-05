# Day 7 teardown

Run inside `netlab`, from `/course`.

- [ ] Stop any capture still running: `pkill tcpdump || true`. Delete the pcaps:
      `rm -f /run/netlab/*.pcap` (`topo.sh down` removes them too).
- [ ] Bring the topology down: `bash labs/day07/topo.sh down`
      (it also clears the fault marker `/run/netlab/day07.fault`).
- [ ] No namespaces left: `ip netns list` prints nothing.
- [ ] No daemon left:
      `ps -e | /usr/bin/grep -E 'unbound|zebra|bgpd|python3|tcpdump' || echo none` prints `none`.
- [ ] `/etc/netns` is empty: `ls /etc/netns` prints nothing.
- [ ] Check the whole course: `bash labs/verify-teardown.sh` (run it on the Mac after
      `docker compose -p netlab down` when you are finished for the day).
- [ ] `journal.md` has the Day 7 entry: the filled hop table, the three-capture
      comparison, the five evidence chains with your self-score, and the one
      incident you would add to the gauntlet from your own experience.

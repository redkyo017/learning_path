# Day 3 teardown

Run inside `netlab`, from `/course`.

- [ ] Restore the port range if you changed it in the exhaustion exercise:
      `ip netns exec c1 sysctl net.ipv4.ip_local_port_range` prints `32768 60999`
      (this goes away with the namespace anyway).
- [ ] No leftover netem: `tc -n c1 qdisc show dev eth0` and `tc -n s1 qdisc show dev eth0`
      print no `netem` line (fix B and the loss demo both add one).
- [ ] Bring the topology down: `bash labs/day03/topo.sh down`
- [ ] No namespaces left: `ip netns list` prints nothing.
- [ ] No daemon left: `ps -e | /usr/bin/grep -E 'python3|tcpdump' || echo none`
      prints `none`. If a `tcpdump` is still running in a spare shell, stop it.
- [ ] Check the whole course: `bash labs/verify-teardown.sh` (run it on the Mac after
      `docker compose -p netlab down` when you are finished for the day).
- [ ] `journal.md` has the Day 3 entry: the three evidence chains, the one-line
      "X in AWS is Y on the wire" for the NLB idle timeout, and the ephemeral-port
      arithmetic.

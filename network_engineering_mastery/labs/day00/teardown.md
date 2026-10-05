# Day 0 teardown

Run inside `netlab`, from `/course`.

- [ ] Stop any capture you left in a spare shell (`tcpdump` runs until you stop it).
- [ ] Bring the topology down: `bash labs/day00/topo.sh down`
      (it kills `dnsmasq`, `python3` and removes `/etc/netns/lap/resolv.conf`).
- [ ] `/var/lib/dhcpcd` (stored DHCP leases) lives outside the lab state; the next
      `topo.sh up` clears it.
- [ ] No namespaces left: `ip netns list` prints nothing.
- [ ] No daemon left: `ps -e | /usr/bin/grep -E 'python3|dnsmasq|dhcpcd|tcpdump' || echo none`
      prints `none`.
- [ ] Check the whole course: `bash labs/verify-teardown.sh` (run it on the Mac after
      `docker compose -p netlab down` when you are finished for the day).
- [ ] `journal.md` has the Day 0 entry: the DORA sequence you captured, the two evidence
      chains, and the one-line "my address as the server sees it is ___ because ___".

# Day 4 teardown

Run inside `netlab`, from `/course`.

- [ ] Remove any trace table you left: `ip netns exec fw nft list tables` shows no `tr`
      (it goes away with the namespace anyway).
- [ ] Bring the topology down: `bash labs/day04/topo.sh down`
- [ ] If you ran the inspection emulation: `bash labs/day04/inspection.sh down`
- [ ] No namespaces left: `ip netns list` prints nothing.
- [ ] No daemon left: `ps -e | /usr/bin/grep -E 'python3|tcpdump|conntrack' || echo none`
      prints `none`. If a `tcpdump` or `conntrack -E` is still running in a spare
      shell, stop it.
- [ ] Check the whole course: `bash labs/verify-teardown.sh` (run it on the Mac after
      `docker compose -p netlab down` when you are finished for the day).
- [ ] If you ran `aws_lab/day04/`: `terraform destroy` there, then
      `aws_network_components/scripts/sweep.sh` from the course parent directory `learning_path/` (see `aws_lab/day04/README.md`).
- [ ] `journal.md` has the Day 4 entry: the two evidence chains, why ping survived
      Fault A, and the one-line "TGW appliance mode in AWS is Y on the wire".

# Day 1 teardown

```bash
bash labs/day01/topo.sh down
ip netns list          # expect: empty output
```

`topo.sh down` deletes every namespace and every process inside one, including the
background ping from `break.sh`. Nothing else from Day 1 persists.

If you are stopping for the day, leave the container and run on the host (your Mac):

```bash
bash labs/verify-teardown.sh
```

Expect exit 0 once the `netlab` container is stopped
(`docker compose -p netlab down` from `labs/netlab`).

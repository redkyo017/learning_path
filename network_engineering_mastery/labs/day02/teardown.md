# Day 2 teardown

Inside `netlab`, from `/course`:

```bash
bash labs/day02/topo.sh down
ip netns list        # expect no output
ps -e | /usr/bin/grep python3 || echo "no daemons left"
```

`topo.sh down` removes all four namespaces and kills the `python3 -m http.server`
inside `h2`. It also deletes `/run/netlab/big.bin` with the rest of `/run/netlab`.

If you are stopping for the day, leave the container (`exit`) and, on the Mac:

```bash
bash labs/verify-teardown.sh     # exit 0 means no netlab container is left
```

Starting the next day needs no cleanup first: every `topo.sh up` begins with a full
teardown.

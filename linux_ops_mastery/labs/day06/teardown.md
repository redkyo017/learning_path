# Day 6 teardown

Confirm every item before moving on to Day 7.

- [ ] Confirm no fault is still active: `bash labs/day06/verify.sh` exits
      `0`. If it doesn't, `break.sh`'s own reset logic is the fastest way
      back to clean — run `bash labs/day06/break.sh 1` and then fix that
      one known rung, rather than hand-rolling the undo.
- [ ] DNS: `docker compose -p linuxops exec proxy cat /etc/resolv.conf`
      shows `nameserver 127.0.0.11` — Docker's own embedded resolver, not
      the `10.255.255.1` fault-1 address.
- [ ] Route: `docker compose -p linuxops exec proxy ip route show` lists a
      `default` line and a connected route for `linuxops_net`'s subnet.
- [ ] Firewall: `docker compose -p linuxops exec proxy nft list ruleset`
      has no `table inet day06` and no rule dropping `tcp dport 8080`.
- [ ] Listener: reads `00000000:1F90` (bound to `0.0.0.0`), not
      `0100007F:1F90`:

      ```bash
      docker compose -p linuxops exec app \
        sh -c "awk '\$2 ~ /:1F90\$/ {print \$2}' /proc/net/tcp"
      ```

- [ ] Application: prints `200`:

      ```bash
      docker compose -p linuxops exec app python3 -c \
        "import urllib.request as u
      print(u.urlopen('http://127.0.0.1:8080/healthz').status)"
      ```

- [ ] End to end: from `ws`, prints `200`:

      ```bash
      curl -s -o /dev/null -w '%{http_code}\n' http://proxy/
      ```
- [ ] The container swapped in by fault 4 is gone: `docker compose -p
      linuxops ps app` shows one `app` container, image and command
      matching `docker-compose.yml` — not a hand-run replacement.
- [ ] Confirm `journal.md` has a Day 6 entry: five chains, or however many
      rungs you actually drilled, each with its own symptom-to-file trace.
- [ ] Leave `ws`, `slim`, `app`, `db`, and `proxy` running for Day 7 — do
      not run `docker compose down` mid-path. Full-fleet teardown is
      `bash labs/verify-teardown.sh`, run only once the whole path is done.

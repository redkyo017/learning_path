# Day 3 teardown

Checklist to leave the fleet clean before Day 4, which reuses `app` for
the OOM and CPU-throttling labs and depends on it starting from a known
state (mem_limit and the 24 MiB `/var/log` tmpfs are both load-bearing
there — see `docker-compose.yml`).

- [ ] `verify.sh` exits `0`. If it does not, finish the lab before
      tearing down — a teardown does not substitute for a passing
      verify.
- [ ] No held file remains open under `/var/log`:
      ```
      docker compose -p linuxops exec app sh -c \
        'ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep "(deleted)"'
      ```
      prints nothing.
- [ ] No stray `tail` process is still running in `app`:
      ```
      docker compose -p linuxops exec app ps
      ```
      shows only PID 1 (`sh`, per Day 2's defect) and the `python`
      process — no `tail`.
- [ ] Remove the answer file so a re-run of the lab starts clean:
      ```
      docker compose -p linuxops exec app rm -f /tmp/answer
      ```
- [ ] Reset `/var/log` fully rather than trusting a partial cleanup —
      restart `app` so its tmpfs is remounted empty and its RSS returns
      to baseline before Day 4's memory work begins:
      ```
      docker compose -p linuxops restart app
      ```
- [ ] Confirm the reset: `docker compose -p linuxops exec app du -sh
      /var/log` reports a near-empty directory.
- [ ] Leave the fleet running for the next day, or run
      `labs/verify-teardown.sh` if this is the last lab of the session
      and you intend to bring everything down
      (`docker compose -p linuxops down -v --remove-orphans`).

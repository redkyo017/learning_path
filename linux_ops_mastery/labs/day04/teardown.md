# Day 4 teardown

Confirm every item before moving on to Day 5.

- [ ] Force-recreate `app` so its cgroup counters (`memory.events`,
      `cpu.stat`) reset to zero instead of carrying leftover counts into
      the next lab — the balloon's own memory is already gone (the cgroup
      OOM killer removed the forked child that held it), but the counters
      persist on the same cgroup until the container is recreated:
      `docker compose -p linuxops up -d --force-recreate app`
- [ ] Confirm memory usage is back to idle: `docker compose -p linuxops
      exec app cat /sys/fs/cgroup/memory.current` reads a small, roughly
      idle value — tens of MiB, not near the 64 MiB limit.
- [ ] Confirm no burn thread is still running: sample `memory.current` a
      few seconds apart and see it flat, and `cpu.stat`'s `usage_usec`
      growing only slowly (idle-process background cost, not a busy loop).
- [ ] Your `/tmp/findings` file on `app` is cleared by the recreate above,
      since `/tmp` is not a mounted volume — no separate cleanup needed.
- [ ] Confirm `journal.md` has a Day 4 entry: the full chain of evidence,
      not just the two counts you wrote to `/tmp/findings`.
- [ ] Leave `ws`, `slim`, `app`, `db`, and `proxy` running for Day 5 —
      do not run `docker compose down` mid-path. Full-fleet teardown is
      `bash labs/verify-teardown.sh`, run only once the whole path is done.

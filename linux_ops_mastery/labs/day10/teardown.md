# Day 10 Teardown

- [ ] Remove the lab directory: rm -rf /tmp/lab10
- [ ] Confirm it is gone: ls /tmp/lab10 should report "No such file or directory"
- [ ] Verify bash/ops-toolkit/ contains your four authored files:
      bash/ops-toolkit/lib/log.sh
      bash/ops-toolkit/lib/trap.sh
      bash/ops-toolkit/lib/args.sh
      bash/ops-toolkit/bin/diagnose.sh
- [ ] Run: bash bash/ops-toolkit/bin/diagnose.sh
      (no args — confirm the usage message works)
- [ ] Verify the ws container is still running: docker compose -p linuxops ps

No Docker services were added in this lab. No other cleanup is needed.

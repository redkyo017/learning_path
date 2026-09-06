# Day 5 teardown

Day 5 is the only day that brings up an extra container from the `sysd`
overlay, so its teardown has one extra step the other six days do not.

- [ ] Confirm `verify.sh` printed `3/3 checks passed` before tearing down —
      there is nothing left to prove once the containers are gone.
- [ ] Undo the state `break.sh` left inside `sysd`, so the next run of
      `break.sh` starts from a clean fleet rather than an already-repaired
      one:
      ```bash
      cd linux_ops_mastery/labs/fleet
      docker compose -p linuxops -f docker-compose.yml \
        -f docker-compose.sysd.yml exec sysd bash -c \
        'systemctl stop labs-api.service labs-db.service 2>/dev/null;
         rm -f /etc/systemd/system/labs-api.service \
               /etc/systemd/system/labs-db.service \
               /usr/local/bin/labs-apid;
         rm -rf /srv/reports;
         userdel -r appuser 2>/dev/null;
         systemctl daemon-reload'
      ```
- [ ] Stop and remove the `sysd` container specifically — it is only
      defined in the overlay, so the overlay file has to be named again
      to remove it, exactly as it was named to bring it up:
      ```bash
      docker compose -p linuxops -f docker-compose.yml \
        -f docker-compose.sysd.yml stop sysd
      docker compose -p linuxops -f docker-compose.yml \
        -f docker-compose.sysd.yml rm -f sysd
      ```
- [ ] If you are done with the fleet entirely, not just Day 5, tear the
      whole thing down per `labs/fleet/README.md`'s `## Teardown` section
      (`down -v --remove-orphans` against **both** compose files, then
      `../verify-teardown.sh`). Skip this step if you are moving straight
      to Day 6, which does not need `sysd` at all.
- [ ] If you switched to Colima for this lab, remember it holds its own
      separate containers, volumes, and images from Docker Desktop's —
      run `docker compose ... down` there too, and switch back with
      `docker context use default` when finished.

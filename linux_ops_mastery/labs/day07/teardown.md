# Day 7 teardown

The gauntlet touches more of the fleet than any single prior day — a
background process on `app`, a config file and two new accounts on `app`,
a config edit and a restart on `db`, and a manual `/etc/hosts` line on
`proxy`. "I fixed the symptoms" is not the same claim as "nothing is left
armed," so work through this checklist in order rather than jumping to
`down -v`.

- [ ] **Confirm every incident is actually fixed, not just diagnosed.**
      `./verify.sh all` from `labs/day07/`. All five rows should read `y`.
      If any read `n`, re-open that incident before tearing anything down —
      a `docker compose down` afterward would silently hide an unresolved
      fault instead of clearing it.

- [ ] **Incident 1 — confirm no rogue holder remains.**
      `docker compose -p linuxops exec app sh -c 'for p in
      /proc/[0-9]*/fd; do ls -l "$p" 2>/dev/null; done | grep deleted'`
      should print nothing. If it still finds a deleted entry under
      `/var/log`, the holding process was never actually killed — find it
      again via `/proc/PID/exe` (not `ps`) and kill it before continuing.

- [ ] **Incident 4 — remove the accounts and directory the gauntlet
      created**, since they are not part of the fleet's normal image and
      would otherwise persist in the `app` container's writable layer
      until the container is recreated:
      `docker compose -p linuxops exec app sh -c 'deluser svcuser; \
      delgroup appgrp; rm -rf /srv/conf.d'`
      (`deluser`/`delgroup` failing because the account is already gone is
      harmless — this step is best-effort cleanup, not a correctness
      check.)

- [ ] **Incident 5 — confirm the fix landed in the persisted volume, not
      just the running process.** `listen_addresses` lives in
      `postgresql.conf` inside the named volume `linuxops_pgdata`, so a
      restart alone does not undo the gauntlet's edit — only actually
      reverting the file (or removing the volume) does:
      `docker compose -p linuxops exec db grep listen_addresses \
      /var/lib/postgresql/data/postgresql.conf` should show the corrected
      value as the *last* occurrence in the file (Postgres applies the
      last one). Confirm `proxy`'s `/etc/hosts` no longer carries a manual
      `db` line: `docker compose -p linuxops exec proxy grep -w db
      /etc/hosts` should find nothing.

- [ ] **Bring the fleet down, including the volume.** From
      `labs/fleet/`:
      `docker compose -p linuxops down -v --remove-orphans`
      The `-v` matters more today than on any prior day: without it, the
      `pgdata` volume keeps whatever `postgresql.conf` state incident 5
      left behind, and the next `up` starts from a `db` that may still
      carry a stale edit if incident 5's fix was ever skipped or
      incomplete.

- [ ] **Verify the teardown itself.** `../verify-teardown.sh` from
      `labs/`. It should report `CLEAN: no containers, networks, volumes
      or dangling images remain.` If it lists a leftover, it also prints
      the exact command that clears it — run that, then re-run it.

- [ ] **Close the loop in `journal.md`.** Five chains, five proofs, five
      fixes — this is the last checkbox of the whole path, not just of
      today.

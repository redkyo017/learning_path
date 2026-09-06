# Day 1 teardown

`app`, `ws`, `slim`, `db`, and `proxy` all stay running between days —
Days 2 through 6 reuse this same fleet. This checklist only confirms
today's incident left nothing behind inside `app`.

1. Re-run verification: `bash labs/day01/verify.sh` must print `PASS`. If
   it still fails, the incident isn't actually resolved yet — go back to
   the lab, don't skip ahead. `verify.sh` passes on either valid fix from
   `SOLUTION.md`, including truncate-through-the-descriptor, which
   deliberately leaves `tail` itself running.
2. **Optional cleanup, not required for passing:** if you fixed the
   incident by killing the holder, there's nothing left to clean up here.
   If you truncated through the descriptor instead, `tail` is still
   running by design — that's the production-correct outcome, not a loose
   end. Kill it only if you want a clean process list before Day 2:
   ```bash
   docker compose -p linuxops exec -T app sh -c "ps | grep '[t]ail' || echo none"
   docker compose -p linuxops exec -T app sh -c "kill <PID>"   # optional
   ```
3. Optional, informational only: a lingering zero-length `(deleted)` entry
   under `/var/log` after the truncate fix is expected and harmless — it
   disappears on its own once `tail` exits or reopens the file. Confirm
   it's zero-length rather than expecting it to be gone:
   ```bash
   docker compose -p linuxops exec -T app sh -c \
     "ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep '(deleted)' || echo none"
   ```
4. Do **not** run `docker compose down` yet — leave the fleet up for
   Day 2. Full teardown at the end of the whole path is
   `labs/verify-teardown.sh`, not this file.

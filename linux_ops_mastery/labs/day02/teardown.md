# Day 2 — teardown checklist

Run through this before starting Day 3. `app` is shared across Days 1,
2, 3, 4, and 6 — leaving it in a broken state from this lab breaks the
next one before it even starts.

- [ ] `verify.sh` in this directory prints `PASS` and exits 0.
- [ ] No `T`-state process remains on `app`:
      ```bash
      docker compose -p linuxops exec app sh -c \
        'grep -l "^State:.T" /proc/[0-9]*/status 2>/dev/null | wc -l'
      ```
      prints `0`.
- [ ] No zombie remains on `app`:
      ```bash
      docker compose -p linuxops exec app sh -c \
        'grep -l "^State:.Z" /proc/[0-9]*/status 2>/dev/null | wc -l'
      ```
      prints `0`.
- [ ] No leftover `sleep 100000` (incident a) on `app`. The bracket
      keeps this check from matching its own cmdline:
      ```bash
      docker compose -p linuxops exec app pgrep -f "sleep 10000[0]" | wc -l
      ```
      prints `0`.
- [ ] No leftover `sleep 200000` (incident c) on `app`:
      ```bash
      docker compose -p linuxops exec app pgrep -f "sleep 20000[0]" | wc -l
      ```
      prints `0`.
- [ ] No stray `python3` spawner from incident (b) still running:
      ```bash
      docker compose -p linuxops exec app pgrep -f "os[.]fork" | wc -l
      ```
      prints `0`. If it does not, `kill` the PID it reports before
      moving on — it will keep producing new zombies otherwise.
- [ ] `app`'s own health endpoint still answers, proving the fix did
      not touch the actual service, only the stray processes around it:
      ```bash
      docker compose -p linuxops exec ws curl -s http://app:8080/healthz
      ```
      prints `healthy`.
- [ ] `app` was **not** restarted or recreated during this lab —
      confirm its uptime is still climbing from before `break.sh` ran:
      ```bash
      docker compose -p linuxops exec app cat /proc/1/stat | awk '{print $22}'
      ```
      (field 22, `starttime`) is unchanged from a value noted before
      the lab began, if you captured one.
- [ ] `journal.md` has three chains for this incident (2a, 2b, 2c), each
      written before its fix, per `SOLUTION.md`'s shape.

This lab does not touch `ws`, `slim`, `db`, or `proxy` — no cleanup is
needed on them. Do **not** run `docker compose down` here; the fleet
stays up across all seven days. Full fleet teardown is
`../verify-teardown.sh`, run only at the end of Day 7.

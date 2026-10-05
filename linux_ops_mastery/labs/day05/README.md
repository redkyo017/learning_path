# Day 5 lab — identity, permission, and service management

**At a glance:**
- **Run from:** repo root — `bash labs/day05/break.sh`, `bash labs/day05/verify.sh`.
- **Environment:** Docker fleet must be up **and** the `sysd` overlay
  brought up on top of it (see "Bring-up (Day 5 only)" below) — diagnose
  inside `sysd`.
- **Journal:** write your chain into the repo-root `journal.md`
  (`linux_ops_mastery/journal.md`), not a file inside this directory.
- **This day's loop deviates:** two independent incidents on `sysd`, each
  needs its own chain entry — otherwise standard break → journal → fix →
  verify → teardown.

## Start here — plain steps

1. **Bring up the fleet and `sysd`:** on your Mac, in `linux_ops_mastery/`, run `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d`, then `docker compose -p linuxops -f labs/fleet/docker-compose.yml -f labs/fleet/docker-compose.sysd.yml up -d --build sysd`. Here the fleet means the lab's Docker containers, and `sysd` is the one that runs real systemd. See "Bring-up (Day 5 only)" below. If `sysd` exits within seconds, read the Colima fallback in `labs/fleet/README.md` (`## Day 5: the systemd container`) instead of editing files.
2. **Start the incidents:** on your Mac, in `linux_ops_mastery/`, run `bash labs/day05/break.sh`. It prints one `SYMPTOM` line that covers two separate problems.
3. **Get a shell in `sysd`:** on your Mac, in `linux_ops_mastery/`, run `docker compose -p linuxops exec sysd bash`. Look and fix in this shell; run `verify.sh` back on your Mac.
4. **Look at both symptoms (in the `sysd` shell):** run `ls -l /srv/reports/q3.txt` and read its mode, then run `systemctl status labs-api.service` (it says `failed`). Do not fix anything yet.
5. **Write two chains in `journal.md` before fixing anything.** Edit it on your Mac, in your editor. Copy the chain template (the claim-and-proof outline) at the top of that file once per incident; its Day 1 example shows the style.
6. **Fix both incidents in the `sysd` shell.** If `systemctl` still shows the old behaviour after you edit the unit, open the Incident 2 hints. If `systemctl` then says "Start request repeated too quickly", run `systemctl reset-failed labs-api.service` and start it again.
7. **Check your work:** on your Mac (type `exit` first if you are still inside `sysd`), in `linux_ops_mastery/`, run `bash labs/day05/verify.sh`. Wait for `3/3 checks passed`.
8. **Strip drill, then tidy up:** on your Mac, run `docker compose -p linuxops exec slim sh` and do the drill in "Strip the toolbox" in `content/day05.md`. Then follow `labs/day05/teardown.md`.

## Goal

Two independent incidents on `sysd`, the one container in this fleet that
boots real systemd as PID 1:

1. A file `appuser` cannot read, even though the file itself is mode `0777`.
2. A unit, `labs-api.service`, that will not start.

## Success signal

`verify.sh` exits `0` and prints `3/3 checks passed`.

## Bring-up (Day 5 only)

This is the only day that needs the `sysd` overlay **on top of** the base
fleet — `break.sh` and `verify.sh` both call `require_fleet`, which checks
that `ws` is running on the base fleet, so bring both up, from
`labs/fleet/`:

```bash
cd linux_ops_mastery/labs/fleet
docker compose -p linuxops up -d --build
docker compose -p linuxops -f docker-compose.yml -f docker-compose.sysd.yml \
  up -d --build sysd
```

The first command is the same base bring-up every other day uses; the
second one adds `sysd` on top of it. `sysd` has no `depends_on` on the
base services, so the order above — base fleet first — is what makes
`require_fleet` pass instead of failing with "Fleet is not running."

`sysd` runs `--privileged` with `--cgroupns=host`, which is the most fragile
combination in this whole course on Docker Desktop for macOS. If it exits
within a second or two, do not start editing `Dockerfile.sysd` — read the
**Colima fallback** in `labs/fleet/README.md` (`## Day 5: the systemd
container`) and bring the fleet up there instead.

Confirm it is actually up before running anything else:

```bash
docker compose -p linuxops -f docker-compose.yml -f docker-compose.sysd.yml \
  exec sysd systemctl is-system-running --wait
```

`degraded` is fine here (several units are masked on purpose for a
container); anything that never returns means go to Colima.

## How to run

```bash
cd linux_ops_mastery/labs/day05
./break.sh
```

`break.sh` prints one `SYMPTOM` line and nothing else. From here:

1. Open `journal.md` at the repo root and write the diagnosis chain for
   **both** incidents, before you touch anything — see `STRATEGY.md`, The
   daily loop, step 5.
2. Repair the fleet.
3. Run `./verify.sh`. It exits `0` only when all three objective checks pass.
4. Compare your chain against `SOLUTION.md` claim by claim.
5. Run through `teardown.md` before moving on.

If you get stuck, use **Stuck? Hints** at the bottom of this file before opening `SOLUTION.md`.

No spoilers below this line — the incident, the files involved, and the fix
are for you to find with the primer and `content/day05.md` open beside you.

## Stuck? Hints

Open one at a time. Try for 10 minutes before opening the next.

### Incident 1 — the 0777 file

<details><summary>Hint 1 — where to look</summary>

Opening a file needs more than the file's own permission bits. Ask: what else sits between `/` and this file that the kernel must check for `appuser`?
</details>

<details><summary>Hint 2 — what proves it</summary>

Run `namei -l /srv/reports/q3.txt` in the `sysd` shell. It prints the owner, group and mode of every step of the path, one per line. Read each line's permission letters.
</details>

<details><summary>Hint 3 — almost there</summary>

The directory `/srv/reports` is mode `drw-------`: it has no `x` (search) bit for anyone. Passing through a directory needs `x`, so `appuser` is stopped there and never reaches the file's `0777` bits. Do not reach for `777` on the directory; only one missing bit matters.
</details>

### Incident 2 — the unit that won't start

<details><summary>Hint 1 — where to look</summary>

A unit failing is a story told by systemd's log and by the unit file itself. Ask: at which step did systemd give up, and what does the file tell it to run?
</details>

<details><summary>Hint 2 — what proves it</summary>

Run `journalctl -u labs-api -b` and find the `Failed at step EXEC` line with `status=203/EXEC`. Then run `ls -l /usr/local/bin` and read `/etc/systemd/system/labs-api.service` with `cat`. Compare the path after `ExecStart=` with the file names in `/usr/local/bin`.
</details>

<details><summary>Hint 3 — almost there</summary>

`ExecStart=` names `/usr/local/bin/labs-api`, but the program on disk is called `labs-apid`, so the exec fails. Also, the unit has `Requires=labs-db.service` with no matching `After=` line, so start order is not guaranteed. Last, systemd reads unit files once and keeps them in memory, so edits on disk are not seen until it is told to re-read.
</details>

Still stuck: read `SOLUTION.md`.

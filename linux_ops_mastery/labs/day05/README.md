# Day 5 lab — identity, permission, and service management

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

No spoilers below this line — the incident, the files involved, and the fix
are for you to find with the primer and `content/day05.md` open beside you.

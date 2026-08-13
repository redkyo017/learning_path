# Day 0 Lab — Solution / Verify Walkthrough

## Authorized use only

Same notice as [`README.md`](README.md): this lab only stands up the shared attacker
toolbox. No target is attacked here. From Day 1 on, only point this toolbox at
containers this path starts on `cyberlab`, or your own AWS sandbox account.

## What "solving" Day 0 means

There's no exploit to reproduce — the lab is solved when the environment is up and the
verify command prints the expected string. This file documents the exact commands run
and the real output confirmed while building this lab, so you can compare your own run
against it.

## Step-by-step, with actual verified output

1. **Build and start** (from `cyber_security/labs/base`):

   ```sh
   ./up.sh
   ```

   Confirmed output ends with:

   ```
   Container cyberlab-attacker Started
   [*] Done. Shell into the attacker container with:
         docker compose exec attacker bash
   ```

   (First run builds the full Kali-rolling image with the tool list — expect several
   minutes. Subsequent runs reuse Docker's build cache and finish in seconds.)

2. **Run the Day 0 verify command** (from `cyber_security/labs/base`):

   ```sh
   docker compose exec attacker sh -c "echo LAB_READY"
   ```

   **Confirmed output:** `LAB_READY`

3. **(Optional) Run the fuller toolbox check** reused from `labs/base` (run from `cyber_security/labs/base`):

   ```sh
   docker compose exec attacker sh -c "nmap --version >/dev/null && sqlmap --version >/dev/null && hashcat --version >/dev/null && hydra -h >/dev/null 2>&1; echo TOOLS_OK"
   ```

   **Confirmed output:** `TOOLS_OK`

   Reminder: `hydra -h` intentionally exits non-zero (hydra's own design, not a
   failure) — the `;` instead of `&&` before it is what lets `TOOLS_OK` still print.

4. **Tear down when finished:**

   ```sh
   ./down.sh
   ```

   Confirmed output ends with the attacker container and `cyberlab` network both
   removed (`docker compose ps -a` shows no containers; `docker network ls` no longer
   lists `cyberlab`).

## If something doesn't match

- **`up.sh` fails to pull `kalilinux/kali-rolling`:** edit
  `labs/base/attacker/Dockerfile` and swap the `FROM` line for
  `debian:bookworm-slim` (documented as a comment in that file) — every listed
  package is also available in Debian's repos. Rerun `./up.sh` after editing.
- **`docker compose exec attacker ...` errors with "no such service" or similar:**
  `up.sh` didn't finish starting the container — check `docker compose ps` from
  `labs/base` and re-run `./up.sh`.
- **`LAB_READY` never prints, command hangs:** confirm the Docker daemon itself is
  running (`docker info`) before assuming the lab is broken.

## Answers reused from the content file

The STRIDE and trust-boundary/mitigation exercises for Day 0 live in
[`content/day00-ignition.md`](../../content/day00-ignition.md) (Sections 3 and 4) —
worked answers are inline there rather than duplicated here, since they're analysis
exercises rather than a hidden exploit path.

# Day 7 lab — the gauntlet

**At a glance:**
- **Run from:** repo root — `bash labs/day07/gauntlet.sh <1-5|all>`,
  `bash labs/day07/verify.sh <N|all>`.
- **Environment:** Docker fleet must be up (`labs/fleet/`:
  `docker compose -p linuxops up -d --build`); no `sysd` overlay needed.
- **Journal:** write your chain into the repo-root `journal.md`
  (`linux_ops_mastery/journal.md`), not a file inside this directory.
- **This day's loop deviates entirely:** no `break.sh`/`SOLUTION.md` —
  `gauntlet.sh` replaces `break.sh`, `ANSWERS.md` replaces `SOLUTION.md`
  and stays closed until all five chains are written, 15 minutes per
  incident, fix each fully before moving to the next.

No spoilers below. If you want the mechanism behind an incident before you
have written its chain, you are reading the wrong file — that file is
`ANSWERS.md`, and it stays closed until all five chains exist.

## Start here — plain steps

1. **Check the fleet first:** on your Mac, in `linux_ops_mastery/`, run `docker compose -p linuxops ps`. Every container should be `Up`. If one is missing, run `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d`. (The fleet is the lab's Docker containers.) If `proxy` shows as exited, rebuild it with `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d --build proxy`. Known issue: incident 1 currently does not break anything (its script relies on a trick busybox rejects), so `verify.sh 1` passes with no fix — skip incident 1 and start with 2. Optional: do the Neovim block in `content/day07.md` first; it is a separate skill, not part of the gauntlet.
2. **Start incident 2 and start your clock:** on your Mac, in `linux_ops_mastery/`, run `bash labs/day07/gauntlet.sh 2` (incident 1 is skipped for now — see step 1). It prints one symptom line and nothing else. Set a 15-minute timer on your phone now. The timer is yours to enforce; nothing stops you at zero.
3. **Find the shell to work in:** the symptom line names the container. On your Mac, in `linux_ops_mastery/`, enter it with `docker compose -p linuxops exec <name> sh` (use `bash` for `ws`). The *Getting a shell* table in the top-level `README.md` lists every container. Look around in that shell; run `verify.sh` back on your Mac.
4. **Write the chain in `journal.md` before you fix anything.** Edit it on your Mac, in your editor. Copy the chain template (the claim-and-proof outline) at the top of that file; its Day 1 example shows the style. A fix that works before the chain is written proves nothing.
5. **Fix it, then check it:** type `exit` first if you are still inside a container. On your Mac, in `linux_ops_mastery/`, run `bash labs/day07/verify.sh 2` and wait for `incident 2: PASS`. Fix each incident fully before the next; each incident assumes the one before it is repaired.
6. **Repeat for incidents 3, 4 and 5:** on your Mac, in `linux_ops_mastery/` (type `exit` first if you are still inside a container), run `bash labs/day07/gauntlet.sh 3`, then a new 15-minute timer, a shell, a journal chain, a fix, and `bash labs/day07/verify.sh 3`. Same for 4 and 5. If 15 minutes pass with no proof, stop, write down what you know, and note the overrun — then still fix this incident before starting the next.
7. **Only now open `ANSWERS.md`:** once all four chains are written (passed or not, or once your 90 minutes are spent), type `exit` first if you are still inside a container, then read `labs/day07/ANSWERS.md` and score your chains against it. Then follow `labs/day07/teardown.md`.

No hints today — that is the test. `ANSWERS.md` opens after all four chains (incidents 2–5) are written.

## What this is

Six days built one truth and one tool at a time. Today has no new truth and
no new tool: five unseen incidents, each a recombination of a mechanism from
an earlier day, and a clock. This substitutes for the usual `break.sh` /
`SOLUTION.md` pair:

- `gauntlet.sh` — replaces `break.sh`. Takes an incident number `1`-`5`, or
  `all` to run every incident in sequence.
- `verify.sh` — same contract as every other day: takes the incident number
  and asserts the specific repair, exiting `0` (fixed) or `1` (not yet).
  With `all`, prints a scorecard.
- `ANSWERS.md` — replaces `SOLUTION.md`. Do not open it yet.

## The five incidents

| # | Incident | Draws on |
|---|---|---|
| 1 | `/var/log` full on `app`, holding process misidentified by `ps` | Days 1 + 3 |
| 2 | `app` shows active per its supervisor, but every request times out | Day 2 |
| 3 | Requests succeed at low rate, fail under load, no OOM | Day 4 |
| 4 | A config file is unreadable by the service user after a deploy | Day 5 |
| 5 | `proxy` reaches `app` but not `db` — two faults, not one | Day 6 |

That is all this table says. `gauntlet.sh` prints one symptom line per
incident and nothing else — no hint, no file path, no command suggestion.

## The rules

1. **15 minutes per incident.** Set your own timer. This is a budget you
   enforce on yourself, not something the script cuts you off at — the
   point is the discipline of walking away from a diagnosis that is not
   converging, the same discipline a real page enforces on you regardless
   of whether you decide to honor it.
2. **Write the chain in `journal.md` before applying any fix.** Same
   template as every prior day: symptom verbatim, resource class, numbered
   chain of evidence with a command and the exact output line that proves
   each claim, diagnosis, fix, proof, and what you'd check first next time.
   A fix that happens to work before the chain is written proves nothing
   about whether you understood why.
3. **Do not open `ANSWERS.md`** until you have a written chain — passed or
   not — for all five incidents, or the 90 minutes are spent, whichever
   comes first.
4. **Self-scored.** `verify.sh` gives you an objective pass/fail on the
   repair itself. It cannot see whether your chain was proof or a guess
   that happened to land. Score that part yourself against `ANSWERS.md`
   once you're allowed to read it.
5. **Fix each incident fully before moving to the next.** Incident 2
   assumes incident 1 is actually repaired, not just diagnosed; running
   them out of order, or skipping a fix, is on you.

## How to run it

From the host (macOS), with the fleet already up:

```sh
cd linux_ops_mastery/labs/fleet
docker compose -p linuxops up -d --build
```

Then, from `linux_ops_mastery/labs/day07/`:

```sh
./gauntlet.sh 1        # inject incident 1, print its symptom, and exit
#  ... write the chain in ../../journal.md, then fix it, then:
./verify.sh 1          # objective pass/fail on incident 1's repair

./gauntlet.sh all       # run all five in sequence, one at a time, waiting
                        # for you between each; prints elapsed time as it
                        # goes
./verify.sh all         # scorecard: incident, pass/fail, elapsed time
```

`gauntlet.sh` records when each incident started in `/tmp/.gauntlet-times`
inside the `ws` container (not on your Mac) so the scorecard survives
between separate invocations of the scripts.

## Success signal

Five entries in `journal.md`, each closing with a real proof line, each
matched by a `verify.sh <N>` that exits `0`. Whether you got there by
proof or by trial-and-error that happened to work is the one thing this
lab cannot check for you — `ANSWERS.md` and your own honesty can.

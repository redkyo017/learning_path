# Day 7 lab — the gauntlet

No spoilers below. If you want the mechanism behind an incident before you
have written its chain, you are reading the wrong file — that file is
`ANSWERS.md`, and it stays closed until all five chains exist.

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

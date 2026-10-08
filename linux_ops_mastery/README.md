# Linux Operator Mastery (+ Neovim)

A 7-day, 3 h/day path that replaces a decayed command vocabulary with a
resource model. It is for a senior engineer who works on Linux servers
daily, holds LPI-era knowledge that has settled into habit, and needs to
diagnose AWS ECS tasks and EC2 instances where the friendly tooling is
often missing. Every day introduces a kernel file before the tool that
formats it, and every incident is diagnosed from a running, broken lab
fleet — never from notes or from a healthy box. See `STRATEGY.md` for the
full reasoning behind this design.

## Prerequisites

- Docker Desktop for Mac, Apple Silicon build.
- ~4 GB free disk for the image set (`ubuntu:24.04`, `alpine:3.20`,
  `postgres:16-alpine`, `nginx:1.27-alpine`, plus the built `app` image).
- Neovim installed on the host is **not** required — it ships pre-configured
  inside the `ws` container, and from Day 2 on all lab editing happens there.

## Bring-up

```bash
cd linux_ops_mastery/labs/fleet
docker compose -p linuxops up -d --build
docker compose -p linuxops exec ws bash      # your shell for every lab
```

The compose project name is fixed at `linuxops`. Day 5 additionally needs
the `sysd` service brought up via its overlay file — see
`labs/fleet/README.md` for that step and its Colima/Lima fallback.

## Foundations (start here if rusty)

If the day files feel like they assume vocabulary you no longer have —
inode, file descriptor, signal, cgroup — read the foundations track
first: `content/foundations/README.md`. Eight short chapters (about 6 hours,
read-and-try in `ws`) rebuild the mental model each day builds on, and
a table there says which chapters to read before each day.

## The 7-day map

| Day | Truth | Hours | Incident | Content file | Lab dir |
|---|---|---|---|---|---|
| 1 | Mount tree | 2h + 1h nvim | `df` full, `du` at 40%: unlinked open file | `content/day01.md` | `labs/day01/` |
| 2 | Process table | 3h | The "won't die" family: trap, `T`-stop, zombies | `content/day02.md` | `labs/day02/` |
| 3 | FD table | 3h | A full 24 MiB `/var/log`; rotation not reclaiming space | `content/day03.md` | `labs/day03/` |
| 4 | cgroup / namespace boundary | 3h | cgroup OOM at a 64 MiB limit; CPU throttled at low load | `content/day04.md` | `labs/day04/` |
| 5 | Process table | 3h | Mode `0777` denied; systemd unit fails to start | `content/day05.md` | `labs/day05/` |
| 6 | FD table (a socket is a descriptor), plus the network namespace | 3h | Connectivity ladder: DNS, route, firewall, app | `content/day06.md` | `labs/day06/` |
| 7 | All four | 1.5h nvim + 1.5h gauntlet | Five unseen incidents, timed, no hints | `content/day07.md` | `labs/day07/` |
| 8 | Exit codes | 2h | Pipeline silently succeeds after `find` permission-denied failure | `content/day08.md` | `labs/day08/` |
| 9 | Subshells & traps | 2h | Cleanup trap not fired after Ctrl-C inside a pipeline loop | `content/day09.md` | `labs/day09/` |
| 10 | Argument contract | 2h | Fragile positional arg parser silently operates on wrong target | `content/day10.md` | `labs/day10/` |

## The daily loop

Seven steps, every day. Full reasoning for each is in `STRATEGY.md` under
**The daily loop**.

1. Name the truth — which of the four is today's subject.
2. Read the raw file first — `cat` it before any tool touches it.
3. Derive the tool — run it, map every column back to the file.
4. Break it — run `break.sh`. No explanation is given.
5. Write the chain before fixing — into `journal.md`, before any repair.
6. Fix and prove — repair, then re-read the same file as proof.
7. Strip the toolbox — repeat the diagnosis in `slim`, busybox only.

## How to approach any day

Each day has up to four kinds of activity. They have different names but
are simple:

- **Lab** — a script breaks something on purpose; you find out why, write
  it down, fix it, and a second script checks your fix.
- **Strip drill** ("Strip the toolbox" / "Strip step") — practice: do the
  same detection again with only bare tools, so you can still do it on a
  minimal server.
- **Exercises** — optional predict-then-check questions. Not tied to the
  lab. Cover the solution, guess, then read.
- **Neovim block** — Days 1 and 7 only: editor practice, separate from the
  incident.
- **Practice track** — optional finger drills in `labs/practice/`, seeded and
  judged by scripts: Day 1 `nvim` 1-6 and `fileops` 1-2, then the rest spread
  over Days 2-6 and before Day 7 (schedule table in the track README). Overview: `labs/practice/README.md`.

The routine, every day:

1. Read `content/dayNN.md`.
2. Open `labs/dayNN/README.md` and follow **Start here — plain steps**.
3. Stuck? Open the hints at the bottom of that README, one at a time.
4. `SOLUTION.md` last — after your own attempt.
5. Teardown file before moving on.

### Getting a shell

Run these on your Mac from `linux_ops_mastery/`:

| Where | Command | Used on |
|---|---|---|
| `ws` (main shell, has every tool) | `docker compose -p linuxops exec ws bash` | Day 2, Day 7 (and any day you want the full toolset) |
| `app` (the service being debugged) | `docker compose -p linuxops exec app sh` | Days 1–4, 6, 7 |
| `slim` (busybox only) | `docker compose -p linuxops exec slim sh` | Strip drills |
| `db` | `docker compose -p linuxops exec db sh` | Day 6, Day 7 |
| `proxy` | `docker compose -p linuxops exec proxy sh` | Day 6, Day 7 |
| `sysd` (real systemd) | `docker compose -p linuxops exec sysd bash` | Day 5 (exists only after the Day 5 overlay bring-up; see `labs/day05/README.md`) |
| Your Mac | no container | Days 8–10 |

If a container isn't running, bring the fleet up with
`docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d` from
`linux_ops_mastery/`.

`exit` leaves a container shell.

## The arrow-key rule

From Day 2 on, all lab file editing happens in `nvim` inside `ws`. Arrow
keys are disabled by the shipped `init.lua` — motions and text objects are
the only way to move. Day 1's nvim hour teaches the grammar this depends
on; Day 7's nvim block adds the operator payload (`:g//`, macros, quickfix,
`:argdo`, `:w !sudo tee %`).

## How a lab works

All commands below run from the repo root (`linux_ops_mastery/`), and
`journal.md` is always this one shared file at the repo root — never a
file inside `labs/dayNN/`.

```
bash labs/dayNN/break.sh        # injects the incident, no explanation
# write the chain of evidence in journal.md — before touching the fix
bash labs/dayNN/verify.sh       # objective pass/fail on the repair
# read labs/dayNN/teardown.md before moving to the next day
```

`SOLUTION.md` in each lab directory holds the full chain of evidence, not
merely the fix — read it only after your own attempt, or after `verify.sh`
tells you the repair didn't take.

**Environment switches at Day 8.** Days 1-7 need the Docker fleet up
(`labs/fleet/`) and diagnose inside its containers. Days 8-10 need no
Docker at all — `break.sh` sets up `/tmp/labNN/` directly on your host and
everything happens there. Each `labs/dayNN/README.md` states which one
applies under "At a glance."

## Teardown

```bash
bash labs/verify-teardown.sh
```

Confirms zero running containers, no stray volumes, and no leftover
`linuxops_net` network before you close out for the day.

## Reference material

| File | What it is |
|---|---|
| `STRATEGY.md` | The `/proc` doctrine, the four truths, the daily loop, the seven mistakes |
| `COVERAGE.md` | Every LPIC-1 and LFCS objective mapped to a day, plus deliberate skips |
| `content/GLOSSARY.md` | Plain-English terms, alphabetical |
| `content/primers/proc-field-reference.md` | Field-by-field decode of the six kernel files this path relies on |
| `content/primers/file-ops-reference.md` | Read, search, write, update, copy — GNU and busybox forms side by side, each marked same-inode or new-inode |
| `content/primers/nvim-cheatsheet.md` | Neovim as a grammar: operator + count + motion/text object |
| `content/primers/nvim-file-ops.md` | The file side of a Neovim session: opening, writing, what `:w` does to the inode, swap-file recovery |
| `labs/practice/README.md` | Practice track: three drill workbooks (`fileops`, `nvim`, `nvimfile`), each drill seeded and checked by script, one per primer below |
| `content/primers/nvim-vscode-setup.md` | **Optional, after Day 7.** Turning Neovim into a VSCode-shaped daily editor on macOS and Linux |

The last one is deliberately outside the 21 hours. This path treats Neovim as a
survival tool for servers you have never seen, and `labs/day07/init.lua` is 22
plugin-free lines you could retype from memory. Replacing VSCode on your own
machine is a separate decision with a separate config — keep the two apart.
> **Next:** Day 6 seen from the wire — see [../network_engineering_mastery/README.md](../network_engineering_mastery/README.md).

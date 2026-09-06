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

## The arrow-key rule

From Day 2 on, all lab file editing happens in `nvim` inside `ws`. Arrow
keys are disabled by the shipped `init.lua` — motions and text objects are
the only way to move. Day 1's nvim hour teaches the grammar this depends
on; Day 7's nvim block adds the operator payload (`:g//`, macros, quickfix,
`:argdo`, `:w !sudo tee %`).

## How a lab works

```
bash labs/dayNN/break.sh        # injects the incident, no explanation
# write the chain of evidence in journal.md — before touching the fix
bash labs/dayNN/verify.sh       # objective pass/fail on the repair
# read labs/dayNN/teardown.md before moving to the next day
```

`SOLUTION.md` in each lab directory holds the full chain of evidence, not
merely the fix — read it only after your own attempt, or after `verify.sh`
tells you the repair didn't take.

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
| `content/primers/nvim-cheatsheet.md` | Neovim as a grammar: operator + count + motion/text object |
| `content/primers/nvim-vscode-setup.md` | **Optional, after Day 7.** Turning Neovim into a VSCode-shaped daily editor on macOS and Linux |

The last one is deliberately outside the 21 hours. This path treats Neovim as a
survival tool for servers you have never seen, and `labs/day07/init.lua` is 22
plugin-free lines you could retype from memory. Replacing VSCode on your own
machine is a separate decision with a separate config — keep the two apart.

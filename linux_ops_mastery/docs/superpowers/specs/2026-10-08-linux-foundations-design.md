# Linux Foundations Track — Design

**Date:** 2026-10-08
**Status:** approved; implemented 2026-10-08
**Location:** `linux_ops_mastery/content/foundations/`

## Problem

The main course (`content/day01.md` … `day10.md`) is written for "a senior
engineer who works on Linux servers daily" and opens each day at the
kernel-file level (`/proc/mounts` fields, inodes, overlayfs, fd tables,
cgroups). The learner reports that the daily content is hard to follow
because the basic theory has been forgotten. Asked where reading breaks
down, they chose:

- **Core concepts** — what a kernel, process, inode, file descriptor,
  signal, mount, user/permission actually *is*.
- **How parts connect** — how kernel ↔ process ↔ filesystem ↔ shell fit
  together, so the "why" sections land.

They did **not** choose shell/command syntax or day pacing. Existing
support material (`GLOSSARY.md`, 1–3 sentence entries; `primers/`, field
and command references) defines terms but never builds the mental model.

## Goal and success criterion

A self-study refresher, ~4–6 h total, read-and-try format. Success: after
reading the chapters mapped to Day N, that day's "Core concepts" section
reads as a deepening of things the learner already knows, not as new
vocabulary.

**Non-goals:** no break/fix labs, no `verify.sh`, no new containers, no
shell-syntax tutorial, no changes to the main days' technical content.

## Structure

New directory `content/foundations/`:

| File | Chapter | Covers | Prepares for |
|---|---|---|---|
| `README.md` | Index | Reading order, before-Day-N table, time estimate, how to use `ws` for the try-it steps | — |
| `00-big-picture.md` | The big picture | Hardware → kernel → system calls → processes; user vs kernel space; "everything is a file"; `/proc` and `/sys` as files the kernel generates on read; a container is a normal process with walls | all days |
| `01-files-inodes.md` | Files, names, inodes | Directory tree and paths; directory entry vs inode vs data blocks; hard links vs symlinks; what a filesystem is; mounting and the mount tree; tmpfs and overlay in plain terms | Day 1 |
| `02-processes.md` | Processes | Program vs process; PID/PPID; `fork` + `exec`; parent/child, `exit`/`wait`, zombies and orphans; PID 1's special duties; process states (R/S/D/T/Z); environment and cwd | Day 2 |
| `03-signals-terminals.md` | Signals and terminals | What a signal is; default action / catch / ignore / block; TERM vs KILL; STOP/CONT; process groups, sessions, controlling terminal; who receives Ctrl-C | Days 2, 9 |
| `04-fds-io.md` | File descriptors and I/O | Three layers: per-process fd table → open file description (offset, flags) → inode; 0/1/2 convention; redirection and pipes as fd rewiring; inheritance across fork/exec; exit status | Days 3, 8, 9 |
| `05-users-permissions-services.md` | Users, permissions, services | UID/GID, real vs effective; rwx on files vs directories; setuid/setgid/sticky; umask; root vs capabilities; what an init system and systemd do (units, start/stop, logs) | Day 5 |
| `06-resources-boundaries.md` | Resources and boundaries | Virtual memory vs RSS, page cache, "free" vs "available"; CPU scheduling, run queue, load average; cgroups = limits on a group of processes; namespaces = walls on what a process sees; Docker = cgroups + namespaces + overlay | Days 4, 6 |
| `07-networking-basics.md` | Networking basics | Interface, IP address, route, port; socket as an fd; TCP listen/connect/accept and the handshake; DNS lookup path (`/etc/hosts`, `/etc/resolv.conf`); `127.0.0.1` vs `0.0.0.0` | Day 6 |

Chapters are in dependency order: each may use only terms defined in
itself or an earlier chapter.

## Chapter anatomy

Every chapter file uses these sections, in this order:

1. **What you'll be able to explain** — 3–5 plain sentences the learner
   should be able to say aloud afterwards.
2. **The mental model** — narrative prose; one ASCII diagram per key idea
   (e.g. `name → dentry → inode → data blocks`, `fd table → open file →
   inode`). Analogies allowed only with a one-line "where this analogy
   breaks" note.
3. **How it connects** — short paragraph explicitly linking this chapter's
   objects to earlier chapters' objects.
4. **See it yourself** — 4–8 read-only observation commands for the `ws`
   container (`docker compose -p linuxops exec ws bash`), each followed by
   "what to look for". Nothing that modifies the fleet or breaks a lab.
5. **Words you'll meet in the course** — term → day + section where it
   appears; links to `GLOSSARY.md` entries instead of redefining them.
6. **Self-check** — 5–6 questions, answers in a `<details>` block.

**Constraints:**
- 250–400 lines per chapter; `00` may be shorter.
- Define every term at first use, in plain English, before any jargon
  that depends on it.
- Simplified but never wrong: every claim must be consistent with the
  corresponding day's content. Where the day goes deeper, the chapter says
  "Day N goes further on this" rather than contradicting.
- English, matching the rest of the course; same Markdown conventions as
  `content/dayNN.md`.

## Integration with existing files

- `linux_ops_mastery/README.md`: add a "Foundations (start here if rusty)"
  paragraph before "The 7-day map", pointing to `content/foundations/README.md`.
- Each `content/dayNN.md` (01–10): add one line as item 0 of the
  "At a glance" list (all ten days have that block): `Rusty on the basics? Read foundations ch X (and Y)
  first — content/foundations/README.md.` Mapping per the table above;
  Day 7 points to the whole track, Day 10 points to ch 04.
- `GLOSSARY.md`: no content changes; chapters link into it.

## Verification

1. **Live commands:** start Docker Desktop, bring up the fleet
   (`docker compose -p linuxops up -d --build` in `labs/fleet`), and run
   every "See it yourself" command inside `ws`; the described output must
   match what is actually shown. Use `/usr/bin/grep` in host-side checks
   (grep is aliased on this machine).
2. **Consistency with days:** for each chapter, cross-read against the
   days it prepares for; flag any contradiction.
3. **Forward-reference check:** no term used before the chapter that
   defines it.
4. **Self-check answers** agree with the chapter body and the days.
5. **Links:** every relative link in new and edited files resolves.

## Execution notes

- Content writing (8 chapters + index) is delegated to Sonnet subagents,
  one chapter per agent, with this spec and the relevant day file(s) as
  inputs; the spec and plan stay on the main model; review and fixes on
  the main model.
- Git: work happens on local branch `tmp/linux-foundations`; commits go
  there only. At the end, changes are brought back to `master` uncommitted
  (`git merge --squash` then `git reset`), the temp branch is deleted, and
  the user commits.

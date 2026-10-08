# Foundations: A Linux essentials refresher

If vocabulary like inode, file descriptor, signal, or cgroup has gotten rusty, this eight-chapter track is for you. Each chapter is a short, read-and-try exploration that builds the mental model the main course assumes. Plan about 6 hours for the whole track; if you are short on time, read only the chapters the table below lists for your day. All try-it commands are read-only; you won't break anything.

## Open the workspace

Most chapters have try-it commands that run in a Docker workspace called `ws`. Open it like this:

```bash
# from the `linux_ops_mastery` directory
cd labs/fleet
docker compose -p linuxops up -d
docker compose -p linuxops exec ws bash
```

Then you're in a clean Linux shell. All try-it commands are read-only — no mutations, no side effects.

## Chapters

| Chapter | Title | Time | Read before Day |
|---|---|---|---|
| [00](00-big-picture.md) | The big picture | ~30 min | 1 |
| [01](01-files-inodes.md) | Files, names, and inodes | ~45 min | 1 |
| [02](02-processes.md) | Processes | ~45 min | 2 |
| [03](03-signals-terminals.md) | Signals and terminals | ~45 min | 2, 9 |
| [04](04-fds-io.md) | File descriptors and I/O | ~45 min | 3, 8, 9, 10 |
| [05](05-users-permissions-services.md) | Users, permissions, and services | ~45 min | 5 |
| [06](06-resources-boundaries.md) | Resources and boundaries | ~45 min | 4, 6 |
| [07](07-networking-basics.md) | Networking basics | ~45 min | 6 |

## Before each day

Refer to this table to know which chapters to read before tackling a given day's labs:

| Day | Read first |
|---|---|
| 1 | 00, 01 |
| 2 | 02, 03 |
| 3 | 04 |
| 4 | 06 |
| 5 | 05 |
| 6 | 06, 07 |
| 7 | whole track (review) |
| 8 | 04 |
| 9 | 03, 04 |
| 10 | 04 |

**Total: about 6 hours (30 min for chapter 00, 45 min for each of 01-07).**

**Chapters build on each other; if you have the time, read 00 → 07 in order.**

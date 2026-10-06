# Practice track — file ops and nvim, by repetition

**At a glance:**
- **Run from:** `linux_ops_mastery/` on your Mac — `bash labs/practice/<workbook>/setup.sh <N|all>` and `bash labs/practice/<workbook>/check.sh <N|all>`.
- **Environment:** the Docker fleet must be up (`ws` and `slim`). You do the drills *inside* `ws`.
- **Where your files live:** `ws:/root/practice/<workbook>/dNN/`, never `/tmp` (nvim skips its backup there, which would hide the `:w` behaviour some drills teach).
- **What it is:** three workbooks of short drills at three levels. Each drill is seeded by a script and judged by a script, so you know without a mentor whether you got it.
- **Not a lab:** there is no incident and no journal. This is finger practice, like scales.

## Start here — plain steps

1. **Start the fleet:** on your Mac, in `linux_ops_mastery/`, run `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d ws slim`.
2. **Pick a workbook** from the table below and open its `README.md` on your Mac, in your editor or on GitHub.
3. **Open a shell in `ws`** (a second terminal tab): `docker compose -p linuxops -f labs/fleet/docker-compose.yml exec ws bash`. Leave it open; you work here.
4. **Seed one drill:** on your Mac, in `linux_ops_mastery/`, run `bash labs/practice/<workbook>/setup.sh 1`. It recreates `/root/practice/<workbook>/d01/` in `ws` from scratch, so it is safe to run again.
5. **Do the drill in the `ws` shell.** Read Goal and Steps; open the hint only after you have tried.
6. **Check it:** back on your Mac, run `bash labs/practice/<workbook>/check.sh 1`. `PASS d01 ...` means done. `FAIL d01: ...` says what is wrong; fix it in `ws` and run `check.sh` again. You do not need to re-run `setup.sh`.
7. **Stuck for more than 10 minutes?** Read the drill's section in the workbook's `SOLUTION.md`, then reset with `setup.sh N` and do it again without looking.
8. **Run the whole workbook:** `setup.sh all` then `check.sh all`. Right after setup everything should FAIL (except drills marked `Check: self`); that is how you know the check is honest.

## Which workbook, when

| Workbook | Practises | Do it after | Primer to keep open |
|---|---|---|---|
| `fileops/` | read, search, write, update, copy/move/delete from the shell (GNU in `ws`, busybox in `slim`) | Day 1 and Day 3 | `content/primers/file-ops-reference.md` |
| `nvim/` | the edit grammar: motions, text objects, ex commands, registers, macros | Day 1 survival hour, again before Day 7 | `content/primers/nvim-cheatsheet.md` |
| `nvimfile/` | nvim as a file tool: open/read, `:w` semantics (inode, backup, swap), recovery | Day 3 and Day 7 | `content/primers/nvim-file-ops.md` |

Each drill links to the primer section it practises. The primers explain; the drills make your hands do it. The schedule below says which drills to do when.

The `ws` image now ships `sudo` (`nvimfile` drill 7 needs it); if setup says it is missing, run `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d --build ws`.

## Levels

- **L1 guided.** The exact commands or keystrokes are given. Type them (do not paste), watch what happens, compare with "You should see".
- **L2 hinted.** A goal and numbered steps, without the answer. The hint is collapsed under `Hint`.
- **L3 challenge.** A goal and a constraint only ("one ex command", "at most 12 keystrokes"). No steps.

A drill marked `Check: self` is observe-and-explain: there is nothing for `check.sh` to judge. Say the answer out loud, then compare with `SOLUTION.md`.

## A suggested schedule

20 to 30 minutes a day beats a three-hour block. Muscle memory comes from spacing.

| When | Drills |
|---|---|
| Day 1 | `nvim` 1-6, `fileops` 1-2 |
| Day 2 | `fileops` 6-7 |
| Day 3 | `fileops` 3-4, 8, 10-16; `nvimfile` 1-2, 8, 11 |
| Days 4-6 | `nvim` 7-14 (2 a day), `fileops` 5, 9 |
| Before Day 7 | `nvim` 15-20 (keystroke budgets); `nvimfile` 3-7, 9, 10, 12 |
| Daily, any day | 2 new drills, then 2 repeats from earlier days |
| Weekly | `setup.sh all` and `check.sh all` for one workbook, with the primer closed |

## Cleaning up

Drill files live in `ws` (and `slim` for fileops drill 16) and stay until you remove them.

- **fileops:** `docker compose -p linuxops -f labs/fleet/docker-compose.yml exec ws rm -rf /root/practice/fileops`, and for drill 16 also `docker compose -p linuxops -f labs/fleet/docker-compose.yml exec slim rm -rf /root/practice/fileops`.
- **nvim:** remove `/root/practice/nvim` in `ws`, and the undo files nvim kept: `rm -f ~/.local/state/nvim/undo/*practice%nvim%*` (in `ws`).
- **nvimfile:** `bash labs/practice/nvimfile/setup.sh teardown` (on your Mac).

Warning: `up -d --build ws` recreates `ws`, which wipes `/root/practice` and any Day-lab state inside `ws`. Run it between labs, not in the middle of one.

## Repeat until it is from memory

A drill is learned when you can do it with the primer closed, the README closed, and `check.sh` passing the first time. Until then:

1. Do it with the README open. `check.sh` must PASS.
2. Next day, `setup.sh N` and do it again without the Steps (Goal only).
3. Three days later, again, with a timer. Aim to beat your last time.
4. Tick it in the table below only after the memory-only run passes.

If you keep failing the same drill, read the primer section it links to, once, then go back to step 1. Do not read the solution first; reading is not practising.

## Progress

Tick the last column only when you passed from memory.

### fileops

| Drill | Level | Topic | Passed from memory |
|---|---|---|---|
| 1 | L1 | Read and inspect | [ ] |
| 2 | L1 | Search | [ ] |
| 3 | L2 | Extended regex and compressed logs | [ ] |
| 4 | L2 | `find` into `xargs -0` | [ ] |
| 5 | L3 | `find` by time | [ ] |
| 6 | L1 | Write and create | [ ] |
| 7 | L1 | `sed -i`, dry-run first | [ ] |
| 8 | L2 | `sed -E` with a capture group | [ ] |
| 9 | L3 | `awk` to a new file, atomic `mv` | [ ] |
| 10 | L2 | `cp -a` and `cp --backup` | [ ] |
| 11 | L2 | `rm` and `mv` safety | [ ] |
| 12 | L1 | Which writers keep the inode? | [ ] |
| 13 | L2 | The `sort -u f > f` trap | [ ] |
| 14 | L3 | Update without touching the other name | [ ] |
| 15 | L2 | Permissions, umask, `install -m` | [ ] |
| 16 | L2 | busybox `cp` vs GNU `cp` | [ ] |

### nvim

| Drill | Level | Topic | Passed from memory |
|---|---|---|---|
| 1 | L1 | open, jump, change, append, save | [ ] |
| 2 | L1 | search, `*`, `n`, `.` | [ ] |
| 3 | L1 | `%` and `O` | [ ] |
| 4 | L1 | `f`, `;`, `ct,` and `.` on CSV | [ ] |
| 5 | L1 | `3dd`, `dw`, `d$`, `yyp`, `>>` | [ ] |
| 6 | L1 | undo, redo, `U` | [ ] |
| 7 | L2 | `ci"`, `di(`, `da(` | [ ] |
| 8 | L2 | `cit` and `dap` | [ ] |
| 9 | L2 | `yi{` and paste | [ ] |
| 10 | L2 | visual `V`, `>`, `gv` | [ ] |
| 11 | L2 | visual block insert and append | [ ] |
| 12 | L2 | registers: `"a`, `"_` | [ ] |
| 13 | L2 | `:s` with `\v` groups, `&`, `g&` | [ ] |
| 14 | L2 | macro: `qa`/`q`, `@a`, `3@@` | [ ] |
| 15 | L3 | `:g`, `:v`, `:g/.../normal` | [ ] |
| 16 | L3 | `:s` with a range and confirm | [ ] |
| 17 | L3 | `:sort` | [ ] |
| 18 | L3 | `:g/^$/d` and `:norm` | [ ] |
| 19 | L3 | quickfix: `:vimgrep` + `:cdo` | [ ] |
| 20 | L3 | one substitute does it all | [ ] |

### nvimfile

| Drill | Level | Topic | Passed from memory |
|---|---|---|---|
| 1 | L1 | open at a pattern, read-only, discard | [ ] |
| 2 | L1 | `:w name` versus `:saveas` | [ ] |
| 3 | L2 | write a range, append | [ ] |
| 4 | L2 | `:r file` and `:r !cmd` | [ ] |
| 5 | L2 | filters | [ ] |
| 6 | L3 | args and `:argdo` | [ ] |
| 7 | L2 | a root-owned file as a non-root user | [ ] |
| 8 | L1 | which inode did `:w` write? | [ ] |
| 9 | L3 | a running process must see your edit | [ ] |
| 10 | L2 | swap-file recovery | [ ] |
| 11 | L1 | CRLF to LF | [ ] |
| 12 | L2 | busybox `vi` contrast, in `slim` | [ ] |

## For authors of workbook scripts

Source `labs/lib/common.sh` and then `labs/practice/lib.sh`. The helper API (`drill_dir`, `reset_drill`, `arg_drills`, `pass`, `fail`, `finish`, `ws_file_eq`) is documented at the top of `lib.sh`, with a usage example.

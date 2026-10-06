# nvimfile — nvim as a file tool

**At a glance:**
- **Run from:** `linux_ops_mastery/` on your Mac — `bash labs/practice/nvimfile/setup.sh <N|all>` and `bash labs/practice/nvimfile/check.sh <N|all>`.
- **Work in:** `ws` — `docker compose -p linuxops -f labs/fleet/docker-compose.yml exec ws bash` (drill 12 uses `slim` and says so).
- **Practises:** the file side of nvim — open at a line or pattern, read-only, `:w` versus `:saveas`, ranges, `:r`, filters, `:argdo`, `:e!`, root-owned files, what `:w` does to the inode, swap-file recovery, CRLF, and busybox `vi`.
- **Primer to keep open:** [`content/primers/nvim-file-ops.md`](../../../content/primers/nvim-file-ops.md). Day 3's write-semantics section and Day 7 exercises 6-8 (`content/day07.md`) are the same ideas.
- **Files live in** `ws:/root/practice/nvimfile/dNN/`, never `/tmp`: nvim 0.9.5 skips its backup under `/tmp`, which would falsify the inode drills. The exception is drill 7 (`/srv/nvimfile-d07/`, because `/root` is closed to other users, see there). Drill 7 needs `sudo` in the `ws` image: if setup says it is missing, rebuild with `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d --build ws`.
- **Levels:** L1 guided (type the given commands), L2 hinted (goal and steps), L3 challenge (goal and constraints). See [`../README.md`](../README.md).
- **Teardown:** `bash labs/practice/nvimfile/setup.sh teardown` removes every file and the sudoers drop-in drill 7 adds. Drills 8-10 leave background processes and zombies (a dead nvim's `--embed` child is never reaped under `ws`'s PID 1); they are harmless, and `docker compose -p linuxops -f labs/fleet/docker-compose.yml restart ws` clears them.

## Start here — plain steps

1. Start the fleet on your Mac in `linux_ops_mastery/`: `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d ws slim`.
2. Open a shell in `ws` in a second terminal tab: `docker compose -p linuxops -f labs/fleet/docker-compose.yml exec ws bash`. Keep it open; you edit here.
3. Seed drill 1 on your Mac: `bash labs/practice/nvimfile/setup.sh 1`. It recreates `/root/practice/nvimfile/d01/` from scratch.
4. Read drill 1's Goal and Steps below. Type the commands in the `ws` shell; do not paste.
5. Check it on your Mac: `bash labs/practice/nvimfile/check.sh 1`. `PASS` means done; `FAIL d01: ...` says what is wrong, fix it in `ws` and check again (no need to re-run setup).
6. Stuck more than 10 minutes? Open the drill's section in [`SOLUTION.md`](SOLUTION.md), then `setup.sh N` and redo it without looking.
7. Go on to the next drill. A drill is learned when you pass it with this page and the primer closed.
8. Whole workbook: `setup.sh all` then `check.sh all`: everything FAILs right after setup, that is how you know the checks are honest.

| # | Level | Topic |
|---|---|---|
| 1 | L1 | open at a pattern, read-only, `:w!`, `:e!` |
| 2 | L1 | `:w name` versus `:saveas` |
| 3 | L2 | write a range, append to a file |
| 4 | L2 | `:r file` and `:r !cmd` |
| 5 | L2 | filters: `:2,$!sort -u`, `:%!jq .` |
| 6 | L3 | `:args` + `:argdo ... \| update` |
| 7 | L2 | root-owned file as a non-root user |
| 8 | L1 | which inode did `:w` write? (pinned fd, hard link) |
| 9 | L3 | a running process must see your edit |
| 10 | L2 | swap-file recovery after a crash |
| 11 | L1 | CRLF to LF with `fileformat` |
| 12 | L2 | busybox `vi` in `slim`: what is missing |

---

## Drill 1 — open at a pattern, read-only, discard (L1)

**Primer:** [Open and read](../../../content/primers/nvim-file-ops.md#open-and-read), [When opening or writing fails](../../../content/primers/nvim-file-ops.md#when-opening-or-writing-fails). **Setup:** `bash labs/practice/nvimfile/setup.sh 1`

**Goal:** in `/root/practice/nvimfile/d01/app.log` (60 lines, mode 444) change the first `ERROR` to `RESOLVED`, opening the file read-only so you cannot do it by accident.

**Steps** (in `ws`):

1. `cd /root/practice/nvimfile/d01 && nvim -R +/ERROR app.log` — the cursor starts on the first line that matches.
2. Press `dd` three times. The first `dd` shows `W10: Warning: Changing a readonly file`. Then `:e!` — the deleted lines are back; nothing was written.
3. Search for the first match again with `/ERROR` and Enter, then `:s/ERROR/RESOLVED/`.
4. `:w` — refused with `E45: 'readonly' option is set (add ! to override)`.
5. `:w!` — written; `:q`.

**You should see:** `E45` at step 4; `ls -l app.log` still shows `-r--r--r--`; `grep -n RESOLVED app.log` prints one line.

**Check:** `bash labs/practice/nvimfile/check.sh 1`

<details><summary>Hint</summary>

`:w!` only overrides nvim's own `readonly` flag. As root the kernel allows the write; as another user it would answer `E212`.

</details>

[Solution](SOLUTION.md#drill-1)

## Drill 2 — `:w name` versus `:saveas` (L1)

**Primer:** [Write](../../../content/primers/nvim-file-ops.md#write). **Setup:** `bash labs/practice/nvimfile/setup.sh 2`

**Goal:** from `base.conf` (`port=80`, `workers=2`) produce `staging.conf` (port 8080) and `prod.conf` (port 9090 plus a last line `# reviewed`) while `base.conf` itself stays as it was.

**Steps** (in `/root/practice/nvimfile/d02`):

1. `nvim base.conf`, then `:s/80/8080/`.
2. `:w staging.conf` — a copy is written; the buffer is still named `base.conf` (look at the status line).
3. `:s/8080/9090/`, then `:saveas prod.conf` — now the buffer *is* `prod.conf`.
4. `Go# reviewed<Esc>`, then `:wq`.

**You should see:** `cat base.conf` unchanged; `cat staging.conf` has `port=8080`; `cat prod.conf` has `port=9090`, `workers=2`, `# reviewed`.

**Check:** `bash labs/practice/nvimfile/check.sh 2`

<details><summary>Hint</summary>

The last `:wq` writes to whatever name the buffer has at that moment. That is the whole difference between `:w name` and `:saveas`.

</details>

[Solution](SOLUTION.md#drill-2)

## Drill 3 — write a range, append (L2)

**Primer:** [Write](../../../content/primers/nvim-file-ops.md#write). **Setup:** `bash labs/practice/nvimfile/setup.sh 3`

**Goal:** from `app.log` (30 lines, every seventh is `ERROR`) make `part.txt` hold exactly lines 10-14, and extend `summary.txt` (it already has a header) with line 1 of the log followed by every `ERROR` line. `app.log` must not change.

**Steps** (in `/root/practice/nvimfile/d03`):

1. Open the log at line 10 with one command-line flag.
2. Write lines 10-14 to a *new* file with one ex command.
3. Append line 1 to `summary.txt` with one ex command that does not overwrite.
4. Append every `ERROR` line with `:g` and a write that appends. Look at `summary.txt` afterwards: if the whole log landed in it several times, the range of your `:w` was missing.
5. `:q`.

**You should see:** `wc -l part.txt` is 5; `summary.txt` has 6 lines.

**Check:** `bash labs/practice/nvimfile/check.sh 3`

<details><summary>Hint</summary>

`:w` with no range writes the whole buffer. Under `:g`, the current line is `.`. The append form is `:<range>w >> file`.

</details>

[Solution](SOLUTION.md#drill-3)

## Drill 4 — `:r file` and `:r !cmd` (L2)

**Primer:** [Update](../../../content/primers/nvim-file-ops.md#update). **Setup:** `bash labs/practice/nvimfile/setup.sh 4`

**Goal:** in `site.conf`, put the contents of `snippet.conf` on the lines directly below the `# INCLUDE HERE` marker (the marker stays), and make the very first line of the file the output of `hostname`.

**Steps** (in `/root/practice/nvimfile/d04`):

1. `nvim site.conf`.
2. Jump to the marker with a search, then read `snippet.conf` in below it.
3. Insert `hostname`'s output above line 1 (the `0` address means "before line 1").
4. `:wq`.

**You should see:** a file of 7 lines: the host name, `# site`, `server {`, the marker, two snippet lines, `}`.

**Check:** `bash labs/practice/nvimfile/check.sh 4`

<details><summary>Hint</summary>

`:r other` inserts below the cursor line, `:0r other` above line 1; `:r !cmd` is the same with a command's output.

</details>

[Solution](SOLUTION.md#drill-4)

## Drill 5 — filters (L2)

**Primer:** [Update](../../../content/primers/nvim-file-ops.md#update). **Setup:** `bash labs/practice/nvimfile/setup.sh 5`

**Goal:** `names.txt` keeps its first line `# names` and gets the other lines sorted, duplicates removed. `cfg.json` (a comment line, then one compact JSON line) keeps its comment and gets the JSON line pretty-printed.

**Steps** (in `/root/practice/nvimfile/d05`):

1. Open `names.txt`. Filter *lines 2 to the end* through `sort -u`; line 1 must not move. `:wq`.
2. Open `cfg.json`, go to line 2, select it with `V`, and press `:` (the prompt shows `:'<,'>`); filter that selection through `jq .`. `:wq`.

**You should see:** `names.txt` = `# names`, `amy`, `bob`, `cat`, `zoe`; `cfg.json` is the comment line plus 8 lines of JSON.

**Check:** `bash labs/practice/nvimfile/check.sh 5`

<details><summary>Hint</summary>

`:{range}!cmd` replaces the range with the command's output. `$` is the last line, `%` is `1,$`, and a visual selection is the range `'<,'>`.

</details>

[Solution](SOLUTION.md#drill-5)

## Drill 6 — args and `:argdo` (L3)

**Primer:** [the cheatsheet](../../../content/primers/nvim-cheatsheet.md#moving-without-a-mouse) for `:argdo`; [Write](../../../content/primers/nvim-file-ops.md#write) for `:update`; Day 7 (`content/day07.md`) exercises 1-8 are the neighbours. **Setup:** `bash labs/practice/nvimfile/setup.sh 6`

**Goal:** in the five files `conf/*.conf`, change `listen 80;` to `listen 8080;` everywhere it occurs. Files with nothing to change (`c.conf`, `e.conf`) must not be rewritten: their mtime stays 2020-01-01. One nvim session, one `:argdo` line.

**Warm-up, not checked (buffers):** `cd /root/practice/nvimfile/d06 && nvim conf/a.conf`, then `:e conf/b.conf`, `:ls` (two buffers, `%` marks the current), `:b1` (back to the first), `:bd` (close it). Then `:qa`.

**Steps:** none. Constraint: no `sed -i`, no shell loop.

**You should see:** after the `:argdo`, `grep -c 'listen 8080;' conf/*.conf` gives 1 for `a`, `b`, `c`, `d` and 0 for `e`; `ls -l --time-style=+%F conf` shows 2020-01-01 on `c.conf` and `e.conf` only.

**Check:** `bash labs/practice/nvimfile/check.sh 6`

<details><summary>Hint</summary>

`nvim conf/*.conf` or `:args conf/*.conf`. The substitute needs the `e` flag (files without a match would abort the `:argdo`), and `update` writes only buffers that changed. Join them with `|`. `:ls` shows the buffers it opened; `:qa` leaves.

</details>

[Solution](SOLUTION.md#drill-6)

## Drill 7 — a root-owned file as a non-root user (L2)

**Primer:** [Write](../../../content/primers/nvim-file-ops.md#write) (last row), [`E45` on a file you expected to edit](../../../content/primers/nvim-file-ops.md#when-opening-or-writing-fails). **Setup:** `bash labs/practice/nvimfile/setup.sh 7`

`ws` runs as root. The image ships `sudo` (no rules by default); this setup gives the existing `ubuntu` user passwordless sudo (`/etc/sudoers.d/nvimfile`) and makes sudo log to `/var/log/nvimfile-sudo.log`. That log is how the check knows you really did it as `ubuntu`. `teardown` undoes all of it. The file is `/srv/nvimfile-d07/app.conf`, not under `/root/practice`, because `/root` is mode 700 and `ubuntu` could not reach it.

**Goal:** as `ubuntu`, change `max_conns=100` to `max_conns=500` in the root-owned, mode-644 `/srv/nvimfile-d07/app.conf` and save it, keeping owner and mode.

**Steps** (in `ws`):

1. `cd /srv/nvimfile-d07 && su ubuntu` (no password from root; `su` keeps the directory, `-` would not). `id` confirms.
2. `nvim /srv/nvimfile-d07/app.conf`, change the number. `:w` fails; note the message.
3. Save through a privileged writer: pipe the buffer to `sudo tee` on the same file name (`%` is the current file name), discarding tee's echo.
4. nvim now shows `W12: Warning: File ... has changed` with `[O]K, (L)oad File`: press `L`. (If you pressed `O` or Enter, use `:e!`.) Then `:q`.

**You should see:** `ls -l /srv/nvimfile-d07/app.conf` still `-rw-r--r-- root root`; `cat` shows 500.

**Check:** `bash labs/practice/nvimfile/check.sh 7`

<details><summary>Hint</summary>

`:w !cmd` pipes the buffer to `cmd`'s stdin instead of a file. `tee FILE` writes stdin to FILE; `sudo tee` does it as root. `>/dev/null` hides the copy tee prints.

</details>

[Solution](SOLUTION.md#drill-7)

## Drill 8 — which inode did `:w` write? (L1)

**Primer:** [How `:w` lands on disk](../../../content/primers/nvim-file-ops.md#how-w-lands-on-disk); Day 3 write semantics. **Setup:** `bash labs/practice/nvimfile/setup.sh 8`

**Goal:** observe, then record, what nvim's default `:w` does to (a) a one-link file and (b) a file with a second hard link. Inode numbers get reused, so you pin the old inode with an open descriptor instead of comparing `stat` numbers.

**Steps** (in `/root/practice/nvimfile/d08`, one bash shell):

1. `exec 3< conf` — fd 3 now holds the original `conf` inode.
2. `nvim conf`, `:%s/mode=a/mode=b/`, `:wq`.
3. `ls -l /proc/$$/fd/3` — does it say `conf` or `conf~ (deleted)`? `cat /proc/$$/fd/3` — old or new content? Then `exec 3<&-`.
4. `nvim shared`, same substitution, `:wq`. `shared.link` is a second name for the same inode: `cat shared.link`. Did it see the edit?
5. Write the two answers into `answers.txt`, one word per line: first `renamed` or `inplace` (step 3), then `yes` or `no` (step 4).

**You should see:** `fd 3` points at `conf~ (deleted)` with the old `mode=a`; `shared.link` shows the edit.

**Check:** `bash labs/practice/nvimfile/check.sh 8` — it verifies both files were edited and the answers.

<details><summary>Hint</summary>

`writebackup` makes nvim keep the old content until the write works. It renames the original when that is safe, and copies it (then overwrites in place) when the file has another link.

</details>

[Solution](SOLUTION.md#drill-8)

## Drill 9 — a running process must see your edit (L3)

**Primer:** [How `:w` lands on disk](../../../content/primers/nvim-file-ops.md#how-w-lands-on-disk). **Setup:** `bash labs/practice/nvimfile/setup.sh 9`

Setup starts a background process that holds `live.conf` open on fd 3 (its pid is in `holder.pid`) and reads through that descriptor, like a daemon that opened its config once.

**Goal:** change `level=info` to `level=debug` in `/root/practice/nvimfile/d09/live.conf` so that the *holder's* open descriptor shows the new content: `cat /proc/$(cat holder.pid)/fd/3`.

**Constraint:** edit with nvim, from a normal `nvim live.conf` session, with default options changed only inside the session. Do not kill the holder.

**You should see:** `cat /proc/$(cat holder.pid)/fd/3` prints `level=debug` / `retries=3`, and `ls -l /proc/$(cat holder.pid)/fd/3` points at plain `live.conf`, not `live.conf~ (deleted)`.

**Check:** `bash labs/practice/nvimfile/check.sh 9`

<details><summary>Hint</summary>

After a default `:w` the holder's fd shows `live.conf~ (deleted)`. Which option decides rename versus copy? `:set backupcopy=yes` before the write. If you already broke it, `setup.sh 9` resets.

</details>

[Solution](SOLUTION.md#drill-9)

## Drill 10 — swap-file recovery (L2)

**Primer:** [When opening or writing fails](../../../content/primers/nvim-file-ops.md#when-opening-or-writing-fails) (E325, zombie `--embed` child). **Setup:** `bash labs/practice/nvimfile/setup.sh 10`

Setup runs a real terminal nvim on `notes.txt`, types a line without saving it, and `kill -9`s it. Your unsaved line exists only in the swap file.

**Goal:** get that line into `notes.txt` and leave no stale swap file behind.

**Steps** (in `ws`):

1. `nvim -r` — list swap files. Find the one for `notes.txt`: `modified: YES`, a process ID, and probably `(STILL RUNNING)`.
2. `ps -o pid,ppid,stat,args -p <that pid>` — what is it really? (`Zs [nvim] <defunct>`, parent 1: a zombie `nvim --embed` child under PID 1)
3. `nvim /root/practice/nvimfile/d10/notes.txt`: the `E325` message may end in `-- More --` in a 24-row terminal, press Space. At the prompt press `R` (recover). Check the buffer, `:w`, `:q`. (Alternative without the prompt: open the file with `nvim -n` and run `:recover`.)
4. `D` is not offered while nvim believes the process lives, so remove the swap yourself (its name is in the `nvim -r` listing, under `~/.local/state/nvim/swap/`).

**You should see:** `notes.txt` has 4 lines, the last one `UNSAVED line from a crashed session`.

**Check:** `bash labs/practice/nvimfile/check.sh 10`

<details><summary>Hint</summary>

`R` first, delete second: deleting before recovering throws the edits away. The swap file name is the path with `/` replaced by `%`.

</details>

[Solution](SOLUTION.md#drill-10)

## Drill 11 — CRLF to LF (L1)

**Primer:** [Open and read](../../../content/primers/nvim-file-ops.md#open-and-read) (`:set ff?`), [Update](../../../content/primers/nvim-file-ops.md#update). **Setup:** `bash labs/practice/nvimfile/setup.sh 11`

**Goal:** make `crlf.conf` use Unix line endings.

**Steps** (in `/root/practice/nvimfile/d11`):

1. `nvim crlf.conf`, then `:set ff?` — `fileformat=dos`.
2. `:set ff=unix`, then `:wq`.
3. `od -c crlf.conf | head -3` — no `\r` left.

**You should see:** `fileformat=dos` first; after the write no `\r` in the `od` output.

**Check:** `bash labs/practice/nvimfile/check.sh 11`

<details><summary>Hint</summary>

The buffer's format is what decides the line ending on write; changing it is enough, no substitute needed (that is only for *mixed* files). From the shell, `dos2unix` does the same where installed (busybox has it).

</details>

[Solution](SOLUTION.md#drill-11)

## Drill 12 — busybox `vi` contrast, in `slim` (L2)

**Primer:** [Busybox `vi`, the file-lifecycle subset](../../../content/primers/nvim-file-ops.md#busybox-vi-the-file-lifecycle-subset). **Setup:** `bash labs/practice/nvimfile/setup.sh 12` (seeds `slim`)

Open a shell in slim: `docker compose -p linuxops -f labs/fleet/docker-compose.yml exec slim sh`. Files: `/root/practice/nvimfile/d12/` in `slim`.

**Goal:** `win.conf` (CRLF, 4 lines) must end up with Unix line endings; `part` must hold its lines 3-4; `out.txt` (header `# collected`) must get those two lines appended, giving `# collected`, `gamma`, `delta`.

**Steps:**

1. `vi win.conf`: try `:set ff=unix` (what does it say?), then `:3,4w part`, then `:3,4w >> out.txt`, `:q`. Compare `cat part` and `cat out.txt`.
2. Fix it from the shell: `:3,4w >> out.txt` did not append; it created a file literally named `>> out.txt` (vi printed `'>> out.txt' 2L, 14C`). Remove it with `rm './>> out.txt'`. Remember `part` was written from a CRLF file, so strip CRs from `win.conf`, re-write `part` with `:3,4w! part` (it exists now), and append with `cat`.

**You should see:** `bad option: ff=unix`; `part` has the two lines (with CRs); `out.txt` unchanged after `>>`, plus a stray file named `>> out.txt` (`ls`).

**Check:** `bash labs/practice/nvimfile/check.sh 12`

<details><summary>Hint</summary>

`sed -i 's/\r$//' file` works in busybox (so does `dos2unix file`). Order matters: strip first, then write the range with `:3,4w! part`, then `cat part >> out.txt`.

</details>

[Solution](SOLUTION.md#drill-12)

---

## Stuck? Hints

- **`check.sh` says `FAIL` right after you did it:** read the message; most name the exact file and what differs. Diffs show `expected` first.
- **A drill misbehaves after several tries:** `setup.sh N` resets that drill completely.
- **Remember the three questions for any write:** which name does the buffer have now (`:file`), did `:w` get a range (default is the whole buffer), and which inode did it end up on (Drill 8).
- **`W10` / `E45` in drill 1:** nvim's flag, not the kernel. `:w!` overrides the flag only.
- **Drill 7, `sudo: command not found`:** you are in the wrong shell, or your `ws` predates the sudo change: rebuild it with `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d --build ws`, then `setup.sh 7`. Run the edit as `ubuntu`, not root: the check looks for the sudo log entry.
- **Drill 9 holder gone:** `setup.sh 9`.
- **Drill 10 prompt looks different:** with no `(STILL RUNNING)` line the offered keys include `(D)elete it`; recover first anyway. If no swap is listed in `nvim -r`, re-run `setup.sh 10`.
- **Teardown:** `bash labs/practice/nvimfile/setup.sh teardown`.

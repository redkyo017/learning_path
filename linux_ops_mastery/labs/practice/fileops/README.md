# fileops — read, search, write, update, copy/move/delete

**At a glance:**
- **Run from:** `linux_ops_mastery/` on your Mac (zsh): `bash labs/practice/fileops/setup.sh N` and `bash labs/practice/fileops/check.sh N`. `N` is 1 to 16, or `all`.
- **Work in:** a `ws` shell (bash, GNU tools): `docker compose -p linuxops -f labs/fleet/docker-compose.yml exec ws bash`. Drill 16 also uses a `slim` shell (busybox `sh`).
- **Your files:** `ws:/root/practice/fileops/dNN/`. Every command block below is for the `ws` shell unless it says Mac or slim.
- **Primer to keep open:** `content/primers/file-ops-reference.md`. Inode background: `content/day01.md` ("Inode versus name") and `content/day03.md` ("A write lands on one of two inodes", exercises 7 to 9).

## Start here — plain steps

1. **Start the fleet** (Mac, in `linux_ops_mastery/`): `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d ws slim`.
2. **Open a `ws` shell** in a second terminal tab and leave it open: `docker compose -p linuxops -f labs/fleet/docker-compose.yml exec ws bash`.
3. **Seed drill 1** (Mac): `bash labs/practice/fileops/setup.sh 1`. It rebuilds `/root/practice/fileops/d01/` from scratch, so you can re-run it any time.
4. **Go to the drill's directory in `ws`:** `cd /root/practice/fileops/d01`. Do the Steps there.
5. **Check it** (Mac): `bash labs/practice/fileops/check.sh 1`. `PASS d01 ...` means done; `FAIL d01: ...` says what is wrong. Fix it in `ws` and check again; you do not need to re-seed.
6. **Stuck?** Open the `Hint` under the drill first. After ten minutes read the drill's section in `SOLUTION.md`, then `setup.sh N` and redo it without looking.
7. **Do the drills in order.** L1 drills give the exact commands; L2 give a goal and steps; L3 give a goal and a constraint. Later drills assume the earlier ones.
8. **Whole workbook:** `setup.sh all` then `check.sh all` shows 16 FAIL; after you have done every drill it shows 16 PASS. Every drill here is checkable (none is `Check: self`).

Levels, the schedule and the progress table are in `../README.md`.

| # | Level | Topic |
|---|---|---|
| 1 | L1 | read and inspect: `sed -n`, `tail`, `wc`, `stat` |
| 2 | L1 | search: `grep -rl`, `-c`, `-v` |
| 3 | L2 | `grep -E` and `zgrep` |
| 4 | L2 | `find -size` into `xargs -0` |
| 5 | L3 | `find -newer` and `-mtime` |
| 6 | L1 | write: `>`, `>>`, `tee -a`, heredoc, `mktemp` |
| 7 | L1 | `sed -i`, dry-run first, `.bak` |
| 8 | L2 | `sed -E` with capture groups |
| 9 | L3 | `awk` to a new file, atomic `mv` |
| 10 | L2 | `cp -a`, `cp --backup` |
| 11 | L2 | `rm` and `mv`: dash names, spaces, rename |
| 12 | L1 | which writers keep the inode |
| 13 | L2 | the `sort -u f > f` trap |
| 14 | L3 | update a file without touching its hard link |
| 15 | L2 | `chmod`, `umask`, `install -m` |
| 16 | L2 | busybox `cp` vs GNU `cp` (`slim` and `ws`) |

---

## Drill 1 — Read and inspect (L1)

**Primer:** [Read](../../../content/primers/file-ops-reference.md#read) · **Solution:** [SOLUTION.md#drill-1](SOLUTION.md#drill-1)

**Goal:** look at a 200-line log with the basic read tools, then pull six facts out of it without opening an editor.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 1`

**Steps (`ws`, in `/root/practice/fileops/d01`):**

```sh
head -n 3 app.log                         # first lines
file app.log                              # what kind of file is it?
less +F app.log                           # follow mode; press Ctrl-C to stop following, then q to quit
grep -n 'req=100$' app.log                # -n shows the line number
grep -rn ERROR . | head -n 3              # -r searches the directory; "." is here
```

Now save the answers:

```sh
sed -n '40,42p' app.log > ans1.txt        # a line range
tail -n 2 app.log > ans2.txt              # the last two lines
wc -l < app.log > ans3.txt                # the line count, no filename
stat -c '%a %h' app.log > ans4.txt        # octal mode and link count
grep -n ERROR app.log | head -n 2 > ans5.txt   # first two ERROR lines, with line numbers
file -b app.log > ans6.txt                # type only, no filename
```

**You should see:** `file` says `ASCII text`; `grep -n 'req=100$'` prints `100:...`; `cat ans*.txt` shows three `INFO` lines, two lines ending in `req=199` and `req=200`, `200`, two numbers, two `25:`/`50:` ERROR lines, `ASCII text`. Ask yourself why the link count is not 1: look at `ls -li`.

**Check (Mac):** `bash labs/practice/fileops/check.sh 1`

<details><summary>Hint</summary>

`wc -l app.log` prints the name too; feed the file on stdin (`< app.log`) so only the number comes out. Do not edit `app.log`. In `less +F`, Ctrl-C leaves follow mode and `q` quits.

</details>

## Drill 2 — Search (L1)

**Primer:** [Search](../../../content/primers/file-ops-reference.md#search) · **Solution:** [SOLUTION.md#drill-2](SOLUTION.md#drill-2)

**Goal:** answer three questions about a small tree: which files mention `timeout`, how many lines in one file, and which config lines are real settings.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 2`

**Steps (`ws`, in `d02`):**

```sh
grep -rl timeout logs | sort > ans1.txt           # names only, recursive
grep -c timeout logs/web.log > ans2.txt           # count of matching lines
grep -v '^#' conf.txt | grep -v '^$' > ans3.txt   # drop comments, then blanks
```

**You should see:** `ans1.txt` lists three paths including one under `logs/old/`; `ans2.txt` holds `2`; `ans3.txt` holds `port=80` and `user=www`.

**Check (Mac):** `bash labs/practice/fileops/check.sh 2`

<details><summary>Hint</summary>

`grep -rl` prints in directory order, which is why the answer is piped to `sort`. If `ans3.txt` has an empty line, you forgot the second `grep -v`.

</details>

## Drill 3 — Extended regex and compressed logs (L2)

**Primer:** [Search](../../../content/primers/file-ops-reference.md#search) · **Solution:** [SOLUTION.md#drill-3](SOLUTION.md#drill-3)

**Goal:** from `access.log` (plain), save the lines whose status is a 5xx; from the rotated `old.log.gz`, save how many `POST` requests it holds. Do not decompress the `.gz` to disk.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 3`

**Steps (`ws`, in `d03`):**

1. Look at one line: the status is the last field.
2. Write a pattern that matches a 5xx status at the end of a line only. Save the matching lines to `ans1.txt`.
3. Count the `POST` lines in the `.gz` with one command and save the number to `ans2.txt`.

**You should see:** three 5xx lines in `ans1.txt` (not four), and `3` in `ans2.txt`.

**Check (Mac):** `bash labs/practice/fileops/check.sh 3`

<details><summary>Hint</summary>

`$` anchors to the end of a line in plain grep too; `grep -E` is what lets you write an interval like `{2}` without backslashes. One log line contains `500` inside a path (`/v500`); anchor the status to the end of the line. The compressed-file grep starts with `z`.

</details>

## Drill 4 — `find` into `xargs -0` (L2)

**Primer:** [Search](../../../content/primers/file-ops-reference.md#search) · **Solution:** [SOLUTION.md#drill-4](SOLUTION.md#drill-4)

**Goal:** delete every `*.tmp` file larger than 1 KiB, at any depth, in one pipeline. One of them has a space in its name.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 4`

**Steps (`ws`, in `d04`):**

1. List what you would delete first: `find tree ...` with the name and size tests, no `rm`.
2. Check the space-named file is in the list.
3. Send the list to `rm` NUL-delimited, so the space cannot split a name.

**You should see:** afterwards `find tree -type f` shows exactly `tree/b.tmp`, `tree/keep.log`, `tree/sub/keep.txt`.

**Check (Mac):** `bash labs/practice/fileops/check.sh 4`

<details><summary>Hint</summary>

`-print0` on the producer pairs with `xargs -0` on the consumer. `-size +1k` means more than 1 KiB. If you delete too much, `setup.sh 4` restores everything.

</details>

## Drill 5 — `find` by time (L3)

**Primer:** [Search](../../../content/primers/file-ops-reference.md#search) · **Solution:** [SOLUTION.md#drill-5](SOLUTION.md#drill-5)

**Goal:** two sorted lists, each from one `find` pipeline run in `d05`, paths printed as `tree/...`:

- `found.txt`: the `*.conf` files under `tree` that are newer than the file `ref.stamp`.
- `found2.txt`: every regular file under `tree` modified in the last 7 days.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 5`

**You should see:** `found.txt` holds `tree/a.conf` and `tree/sub/b.conf`; `found2.txt` holds `tree/recent.log` and `tree/sub/recent 2.log`.

**Constraint:** one `find` per list; names contain spaces, so do not parse `ls`.

**Check (Mac):** `bash labs/practice/fileops/check.sh 5`

<details><summary>Hint</summary>

Two time tests: one compares against another file, one against "now". `find ... | sort > list` is fine; only whitespace-splitting the output would break.

</details>

## Drill 6 — Write and create (L1)

**Primer:** [Write and create](../../../content/primers/file-ops-reference.md#write-and-create) · **Solution:** [SOLUTION.md#drill-6](SOLUTION.md#drill-6)

**Goal:** build `notes.txt` from five lines using four different writers, and make one temp file the right way.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 6` (an empty `d06`)

**Steps (`ws`, in `d06`):**

```sh
echo one > notes.txt                       # > truncates and writes
echo two >> notes.txt                      # >> appends
echo three | tee -a notes.txt >/dev/null   # tee -a appends too
cat >> notes.txt <<'EOF'
four
five
EOF
t=$(mktemp -p .); echo scratch > "$t"; ls
```

**You should see:** `cat notes.txt` prints `one` to `five`; `ls` shows one `tmp.XXXXXXXXXX` file. Not in `/tmp`: your drill files never live there.

**Check (Mac):** `bash labs/practice/fileops/check.sh 6`

<details><summary>Hint</summary>

If `notes.txt` only has `four` and `five`, a `>` crept in where `>>` belongs. `setup.sh 6` empties the directory.

</details>

## Drill 7 — `sed -i`, dry-run first (L1)

**Primer:** [Update and replace](../../../content/primers/file-ops-reference.md#update-and-replace) · **Solution:** [SOLUTION.md#drill-7](SOLUTION.md#drill-7)

**Goal:** change `timeout=30` to `timeout=60` in `server.conf`, keeping the original as `server.conf.bak`.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 7`

**Steps (`ws`, in `d07`):**

```sh
sed -n 's/^timeout=30$/timeout=60/p' server.conf     # dry-run: prints only the line that would change
sed -i.bak 's/^timeout=30$/timeout=60/' server.conf  # do it; suffix glued to -i
diff -u server.conf.bak server.conf
```

**You should see:** the dry-run prints exactly one line; `diff` shows one `-timeout=30` / `+timeout=60` pair.

**Check (Mac):** `bash labs/practice/fileops/check.sh 7`

<details><summary>Hint</summary>

`-i.bak` has no space. If you ran it twice, `.bak` now holds the already-changed file: `setup.sh 7` and redo.

</details>

## Drill 8 — `sed -E` with a capture group (L2)

**Primer:** [Update and replace](../../../content/primers/file-ops-reference.md#update-and-replace) · **Solution:** [SOLUTION.md#drill-8](SOLUTION.md#drill-8)

**Goal:** in `dates.txt`, rewrite a date at the **start** of a line from `YYYY-MM-DD` to `DD/MM/YYYY`, in place. A date in the middle of a line must stay as it is.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 8`

**Steps (`ws`, in `d08`):**

1. Write a pattern with three capture groups (year, month, day), anchored to the line start.
2. Dry-run it with `sed -n '...p'` and read the output.
3. Apply it with `-i`.

**You should see:** `06/10/2026 backup ok`, `07/10/2026 restore failed`, and `see 2026-10-08 note` unchanged.

**Check (Mac):** `bash labs/practice/fileops/check.sh 8`

<details><summary>Hint</summary>

`sed -E 's/^([0-9]{4})-([0-9]{2})-([0-9]{2})/\3.../'`; the delimiter `/` is inside your output, so either escape it or pick another delimiter such as `|`.

</details>

## Drill 9 — `awk` to a new file, atomic `mv` (L3)

**Primer:** [Update and replace](../../../content/primers/file-ops-reference.md#update-and-replace) · **Solution:** [SOLUTION.md#drill-9](SOLUTION.md#drill-9)

**Goal:** (awk: [Day 3 triage trio](../../../content/day03.md#core-concepts)) in `users.csv`, set `bob`'s third field to `disabled`. `users.snapshot` is a second name for the old file (think: a reader that opened it earlier); it must still show the old content when you are done.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 9`

**You should see:** `users.csv` has `bob,dev,disabled`; `users.snapshot` still has `bob,dev,active`; `ls` shows only those two files.

**Constraint:** edit with `awk`, write a new file, then replace `users.csv` by one `mv`; leave no temp file; the commas must survive.

**Check (Mac):** `bash labs/practice/fileops/check.sh 9`

<details><summary>Hint</summary>

Look at `awk`'s `-F` and `OFS`; an action only for the line where field 1 is `bob`; send output to a new name, then one `mv`. Why is `snapshot` safe? Rename semantics: see drill 12 and the primer's Copy, move, delete table. 

</details>

## Drill 10 — `cp -a` and `cp --backup` (L2)

**Primer:** [Copy, move, delete](../../../content/primers/file-ops-reference.md#copy-move-delete) · **Solution:** [SOLUTION.md#drill-10](SOLUTION.md#drill-10)

**Goal:** (a) copy directory `src` to `copy` keeping modes, mtimes and the symlink `latest` as a symlink; (b) replace `deploy/app.conf` with `new.conf` while keeping the old one as `deploy/app.conf.~1~`.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 10`

**Steps (`ws`, in `d10`):**

1. Compare `ls -l --time-style=full-iso src` before and after your copy; plain `cp -r` loses the 2020 mtimes. If you tried `cp -r` first, run `rm -rf copy` (or re-run `setup.sh 10`) before the next try: copying into an existing directory nests `src` inside it.
2. Find the `cp` option that makes numbered backups of a file it overwrites.

**You should see:** `ls -l copy` matches `ls -l src` (mode, 2020 date, `latest -> data.txt`); `ls deploy` shows `app.conf` and `app.conf.~1~`.

**Check (Mac):** `bash labs/practice/fileops/check.sh 10`

<details><summary>Hint</summary>

(a) one flag, `-a`; if `copy/src` appeared, `rm -rf copy` and retry. (b) `--backup=numbered`; the numbered name is `~1~`, not `.bak`.

</details>

## Drill 11 — `rm` and `mv` safety (L2)

**Primer:** [Copy, move, delete](../../../content/primers/file-ops-reference.md#copy-move-delete) · **Solution:** [SOLUTION.md#drill-11](SOLUTION.md#drill-11)

**Goal:** delete the file `-oops.txt` and the file `my report.txt`; move `report.txt` into `archive/`; leave `keep.txt` alone. `report.anchor` is a second name for `report.txt`: after the move it must be the same inode as `archive/report.txt`.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 11`

**Steps (`ws`, in `d11`):**

1. Try `rm -oops.txt`. Read the error. Find two different ways to say "this is a name, not an option". (Why the move keeps the inode: rename semantics, drill 12.)
2. Delete the file with the space without using a glob.
3. Move `report.txt` with `mv`, then `ls -li archive report.anchor` and compare the inode numbers.

**You should see:** the same inode number on `archive/report.txt` and `report.anchor`.

**Check (Mac):** `bash labs/practice/fileops/check.sh 11`

<details><summary>Hint</summary>

`--` ends option parsing, and `./-oops.txt` is a path that no longer starts with a dash. Quote the spaced name. Always `ls` the names first.

</details>

## Drill 12 — Which writers keep the inode? (L1)

**Primer:** [Write and create](../../../content/primers/file-ops-reference.md#write-and-create) · **Concept:** `content/day03.md`, "A write lands on one of two inodes" · **Solution:** [SOLUTION.md#drill-12](SOLUTION.md#drill-12)

**Goal:** run five writers, one per file, and use a hard link as a witness to see which ones kept the inode. `wN.pin` is a second name for `wN`. If the writer kept the inode, `wN.pin` shows the new content; if the writer built a new inode, `wN.pin` still shows `old`. (A hard link is the safe proof; bare before/after inode numbers can be reused.)

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 12`

**Steps (`ws`, in `d12`):**

```sh
echo new > w1                  # redirect
sed -i 's/old/new/' w2         # sed -i
cp new.txt w3                  # GNU cp onto an existing file
mv new4 w4                     # mv a new file over it
install new.txt w5             # install
for i in 1 2 3 4 5; do echo "w$i: $(cat w$i)  pin: $(cat w$i.pin)"; done
```

Then write into `ans.txt`, one per line in `w1`...`w5` order, the names whose pin showed `new`.

**You should see:** two files where the pin changed with the file, three where the pin kept `old`.

**Check (Mac):** `bash labs/practice/fileops/check.sh 12`

<details><summary>Hint</summary>

Truncate-and-write keeps the inode; "build a file, then rename it over the name" does not. Write `ans.txt` only from what you saw yourself.

</details>

## Drill 13 — The `sort -u f > f` trap (L2)

**Primer:** [Write and create](../../../content/primers/file-ops-reference.md#write-and-create) · **Solution:** [SOLUTION.md#drill-13](SOLUTION.md#drill-13)

**Goal:** make `hosts.txt` a sorted, de-duplicated list (`a`, `b`, `c`), and keep it the **same inode** (`hosts.pin` is a second name for it; both must show the result).

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 13`

**Steps (`ws`, in `d13`):**

1. First, on purpose: `sort -u hosts.txt > hosts.txt; wc -c hosts.txt`. It prints 0. Why? Who opened the file first?
2. Re-seed (`setup.sh 13` on the Mac) and fix it with one `sort` option, no temp file.

**You should see:** `cat hosts.pin` prints `a`, `b`, `c`.

**Check (Mac):** `bash labs/practice/fileops/check.sh 13`

<details><summary>Hint</summary>

The shell truncates the target before `sort` starts. `sort` has an output option that opens the file only after it has read all input.

</details>

## Drill 14 — Update without touching the other name (L3)

**Primer:** [Update and replace](../../../content/primers/file-ops-reference.md#update-and-replace) · **Solution:** [SOLUTION.md#drill-14](SOLUTION.md#drill-14)

**Goal:** in `app.conf`, change `mode=old` to `mode=new`. `app.conf.hl` is a hard link to the same file and **must keep showing `mode=old`**.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 14`

**You should see:** `app.conf` reads `mode=new` and `level=3`; `app.conf.hl` still reads `mode=old`; `stat -c %h app.conf` gives 1; `ls` shows only the two names.

**Constraint:** one command, no leftover files, and `app.conf` must end up with link count 1.

**Check (Mac):** `bash labs/practice/fileops/check.sh 14`

<details><summary>Hint</summary>

You need a writer that builds a new inode. The opposite of drill 13, where you needed the same one.

</details>

## Drill 15 — Permissions, umask, `install -m` (L2)

**Primer:** [Write and create](../../../content/primers/file-ops-reference.md#write-and-create) · **Solution:** [SOLUTION.md#drill-15](SOLUTION.md#drill-15)

**Goal:** in `d15`: `deploy.sh` executable (final mode 755, using a symbolic chmod such as `a+x`); `secret.conf` mode 600 (octal chmod); a file `private.txt` and directory `private.d` created under `umask 077`, without changing the umask of your interactive shell; `src.txt` installed as `etc/app/app.conf` with mode 640, creating `etc/app/` in the same command.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 15`

**Steps (`ws`, in `d15`):** do the four items; `ls -l` and `stat -c '%a %n' *` after each.

**You should see:** `stat -c '%a %n' deploy.sh secret.conf private.txt private.d etc/app/app.conf` prints `755`, `600`, `600`, `700`, `640`.

**Check (Mac):** `bash labs/practice/fileops/check.sh 15`

<details><summary>Hint</summary>

Say who gets execute: a bare `chmod +x` honours the umask, `a+x` does not. A subshell `( umask 077; ... )` scopes the umask. `install -D` creates missing parent directories; `-m` sets the mode.

</details>

## Drill 16 — busybox `cp` vs GNU `cp` (L2, `slim` and `ws`)

**Primer:** [Copy, move, delete](../../../content/primers/file-ops-reference.md#copy-move-delete) · **Concept:** `content/day03.md` · **Solution:** [SOLUTION.md#drill-16](SOLUTION.md#drill-16)

**Goal:** run the same `cp src dst` in `slim` (busybox) and in `ws` (GNU), each in its own `d16`, and use `dst.pin` (a hard link to `dst`) to see which `cp` kept the inode.

**Setup (Mac):** `bash labs/practice/fileops/setup.sh 16` seeds both containers.

**Steps:**

1. Mac: `docker compose -p linuxops -f labs/fleet/docker-compose.yml exec slim sh`. In it (busybox `sh`): `cd /root/practice/fileops/d16`, then `exec 3<dst` (holds the old file open), `cp src dst`, `cat dst dst.pin`, `ls -l /proc/$$/fd/3`, `cat <&3`, then `exit`.
2. In your `ws` shell: `cd /root/practice/fileops/d16 && cp src dst && cat dst dst.pin`.
3. In `ws`, write `ans.txt` with three lines: `busybox: replaced` or `busybox: in-place`, then `gnu: ...` the same way, matching what you saw (`replaced` = pin kept old content = new inode); the third line is `busybox fd3: deleted` or `busybox fd3: live`, from the `ls -l /proc/$$/fd/3` step.

**You should see:** in `slim` the pin still says `old`, and the held descriptor shows `dst (deleted)` and still reads `old`; in `ws` the pin says `new`.

**Check (Mac):** `bash labs/practice/fileops/check.sh 16`

<details><summary>Hint</summary>

If a holder of the old file reads it after the busybox `cp`, it sees a deleted file, not the new bytes. That is the same trap as `sed -i` on a held log.

</details>

## Stuck? Hints

- **`check.sh` says missing or unreadable:** you are in the wrong directory, or the file name is off by a character. The path is in the message; `ls` that directory in `ws`.
- **A drill went wrong and you are lost:** `setup.sh N` on the Mac resets only drill N; your other drills are untouched.
- **`check.sh` says "Fleet is not running":** step 1 of Start here.
- **zsh vs bash:** `setup.sh`/`check.sh` run on the Mac; everything else runs in the `ws` bash shell. A command that behaves strangely is often in the wrong one.
- **Inode numbers lie across runs:** the kernel reuses them. That is why drills prove "same inode" with a second name (hard link), not by eyeballing `ls -i` before and after.
- **`grep` shows nothing on the Mac:** it may be an alias there. Practice runs in `ws`.
- **Still stuck on one drill:** read its section in `SOLUTION.md`, then reset and redo from memory tomorrow.

# nvim editing workbook — the grammar, by repetition

**At a glance:**

- **Run from:** `linux_ops_mastery/` on your Mac for `setup.sh` and `check.sh`. You edit **inside `ws`**.
- **Open `ws`:** `docker compose -p linuxops -f labs/fleet/docker-compose.yml exec ws bash`
- **Your files:** `ws:/root/practice/nvim/dNN/` (never `/tmp`).
- **Config:** the shipped `/root/.config/nvim/init.lua` — arrow keys are off, `relativenumber` on, `ignorecase`+`smartcase`, `expandtab` with `shiftwidth=2`, `undofile`; nvim's own default `hidden` is on (a modified buffer can be left without saving). Every drill works with it.
- **Primers to keep open:** [`nvim-cheatsheet.md`](../../../content/primers/nvim-cheatsheet.md), [Day 1 "Neovim survival"](../../../content/day01.md), [Day 7 nvim exercises](../../../content/day07.md). Worked solutions: [`SOLUTION.md`](SOLUTION.md).
- **Levels:** 6 x L1 guided (d01-d06), 8 x L2 hinted (d07-d14), 6 x L3 challenge (d15-d20, with a keystroke budget). Every drill is judged by `check.sh`, which judges the **result only**: method and keystroke budget are on you.

Count keystrokes the way a human types: each key is one, `<Esc>` and `<CR>` are one, `<C-v>` is one.

**Visual mode in 30 seconds** (no primer covers it): in normal mode `v` starts a character selection, `V` a whole-line selection, `<C-v>` (Ctrl-v) a rectangular block. Move with any motion to grow the selection, then press an operator (`>`, `d`, `c`, `y`, `I`/`A` for blocks) or `:` for a range command (nvim fills in `:'<,'>`, the selected lines). `<Esc>` cancels; `gv` reselects the previous selection.

## Start here — plain steps

1. Start the fleet (once): `docker compose -p linuxops -f labs/fleet/docker-compose.yml up -d ws slim`.
2. Open a second terminal tab and get a shell in `ws` (command above). Leave it open.
3. On the Mac, seed the first drill: `bash labs/practice/nvim/setup.sh 1`.
4. In the `ws` tab, open the file the drill names, e.g. `nvim /root/practice/nvim/d01/nginx.conf`. Type the keys; do not paste them.
5. Save and quit the way the drill says (`:wq<CR>`).
6. On the Mac: `bash labs/practice/nvim/check.sh 1`. `PASS` means done; `FAIL` shows a diff (`-` expected, `+` yours).
7. Fix it in `ws` (or `setup.sh 1` and start over, which is cheap) and check again.
8. Move on in order. After a day, redo a drill from memory with the Steps hidden.
9. When you are done with the workbook, clean up the undo files nvim kept for it: `rm -f ~/.local/state/nvim/undo/*practice%nvim%*` (in `ws`).

`bash labs/practice/nvim/setup.sh all` then `check.sh all` should show 20 FAIL; that is how you know the checks are honest. Edits made *after* `:wq` are not seen, so always write the file.

> If a keystroke does something strange, press `<Esc>` twice, then `u`. If you are completely lost: `:q!<CR>` throws the buffer away, and `setup.sh N` resets the file.

---

## L1 — guided (type exactly this)

### d01 — open, jump, change, append, save  (L1)

**Primer:** [Motions](../../../content/primers/nvim-cheatsheet.md#motions)

**Goal:** `worker_connections` becomes `1024`, and the file ends with the line `# end of nginx.conf`.

**Setup:** `bash labs/practice/nvim/setup.sh 1`

**Steps** (in `ws`):

1. `nvim /root/practice/nvim/d01/nginx.conf`
2. `:3<CR>` jump to line 3. Play: `0` start of line, `w` next word start, `e` word end, `b` back a word start, `$` end of line. Then `$b` (end of line, back one word, onto `512`) and `cw1024<Esc>` change that word.
3. `G` jump to the last line. `o# end of nginx.conf<Esc>` open a line below and type.
4. `:wq<CR>`

**You should see:** line 3 reads `    worker_connections 1024;` and a new last line.

**Check:** `bash labs/practice/nvim/check.sh 1`

<details><summary>Hint</summary>

`cw` stops at the `;` because `;` is not part of a word. If you pressed `:q` and got `E37`, you have unsaved changes: use `:wq`, or `:q!` to discard.

</details>

**Solution:** [d01](SOLUTION.md#d01)

### d02 — search, `*`, `n`, `.`  (L1)

**Primer:** [Motions: search as motion](../../../content/primers/nvim-cheatsheet.md#motions)

**Goal:** rename the upstream `pool` to `web` in both places, and replace the word `down` with `backup`.

**Setup:** `bash labs/practice/nvim/setup.sh 2`

**Steps:**

1. `nvim /root/practice/nvim/d02/backends.conf`
2. `gg` then `w` puts you on `pool`. `*` jumps to the next whole-word `pool` (line 6).
3. `cwweb<Esc>` changes it. `n` jumps to the other `pool` (it wraps to line 1). `.` repeats the change.
4. `/down<CR>` then `ciwbackup<Esc>` (`ciw` = change the inner word, wherever in the word you stand). `:wq<CR>`

**You should see:** `upstream web {`, `proxy_pass http://web;` and `server app2:8080 backup;`.

**Check:** `bash labs/practice/nvim/check.sh 2`

<details><summary>Hint</summary>

`*` and `n` search for the same pattern, which is why `n` finds the other `pool`. Pressing `.` right after `cw` plus its text and `<Esc>` repeats the whole change.

</details>

**Solution:** [d02](SOLUTION.md#d02)

### d03 — `%` and `O`  (L1)

**Primer:** [Motions](../../../content/primers/nvim-cheatsheet.md#motions)

**Goal:** add the line `echo "deployed ${rel}"` as the last line inside the function `deploy`.

**Setup:** `bash labs/practice/nvim/setup.sh 3`

**Steps:**

1. `nvim /root/practice/nvim/d03/deploy.sh`
2. `/deploy()<CR>` finds the definition (line 3). `$` goes to the `{`. `%` jumps to its matching `}`.
3. `Oecho "deployed ${rel}"<Esc>` opens a line *above* the `}`. Type no leading spaces: nvim indents it for you (shell filetype). Check the result looks like the line above.
4. `:wq<CR>`

**You should see:** the new line is indented two spaces like its neighbours.

**Check:** `bash labs/practice/nvim/check.sh 3`

<details><summary>Hint</summary>

`%` works on `()`, `[]`, `{}`. If your new line has four spaces, you typed spaces on top of the automatic indent.

</details>

**Solution:** [d03](SOLUTION.md#d03)

### d04 — `f`, `;`, `ct,` and `.` on CSV  (L1)

**Primer:** [Motions: character find](../../../content/primers/nvim-cheatsheet.md#motions)

**Goal:** the `env` of `web03` and `web04` becomes `stage` (only those two rows).

**Setup:** `bash labs/practice/nvim/setup.sh 4`

**Steps:**

1. `nvim /root/practice/nvim/d04/hosts.csv`
2. `:4<CR>` (the `web03` row). `0f,;l` goes to the first comma, then the second comma (`;` repeats the find), then one right: on the `p` of `prod`.
3. `ct,stage<Esc>` changes up to (not including) the next comma.
4. `j0f,;l.` does the same on the next row; `.` repeats the whole `ct,stage`. `:wq<CR>`

**You should see:** two rows end `,stage,eu`; the others still say `prod`.

**Check:** `bash labs/practice/nvim/check.sh 4`

<details><summary>Hint</summary>

`t,` is "till comma": the cursor stops one short, so the comma survives. `f,` would eat it.

</details>

**Solution:** [d04](SOLUTION.md#d04)

### d05 — `3dd`, `dw`, `d$`, `yyp`, `>>`  (L1)

**Primer:** [The sentence](../../../content/primers/nvim-cheatsheet.md#the-sentence)

**Goal:** end with exactly four lines: `host = web01`, `port = 80`, `retries = 3`, and `  timeout = 3` (indented two spaces).

**Setup:** `bash labs/practice/nvim/setup.sh 5`

**Steps:**

1. `nvim /root/practice/nvim/d05/settings.ini`
2. `3dd` deletes the three `TODO` lines. You are on `x host = web01`: `dw` deletes the stray `x `.
3. `j` down, `f;` to the semicolon, `d$` deletes to end of line.
4. `j` to `retries`, `yyp` duplicates the line, `cwtimeout<Esc>` renames the copy, `>>` indents it. `:wq<CR>`

**You should see:** the four lines above and nothing else.

**Check:** `bash labs/practice/nvim/check.sh 5`

<details><summary>Hint</summary>

`3dd` = count 3 + `dd` (the doubled operator means "this line"). `>>` shifts by `shiftwidth`, which is 2 here.

</details>

**Solution:** [d05](SOLUTION.md#d05)

### d06 — undo, redo, `U`  (L1)

**Primer:** [Day 1 Neovim survival](../../../content/day01.md)

**Goal:** end with `svc-c`, `svc-d # keep`, `svc-e`.

**Setup:** `bash labs/practice/nvim/setup.sh 6`

**Steps:**

1. `nvim /root/practice/nvim/d06/services.txt`
2. `dd` three times. Watch the lines vanish. Then `u` twice: two come back. `<C-r>` redoes one deletion. You now have `svc-c`, `svc-d`, `svc-e`.
3. `j` then `xx` deletes two characters of `svc-d`. `U` restores the whole line (undo all changes on the last-changed line).
4. `A # keep<Esc>`, then `:wq<CR>`.

**You should see:** after step 2 three lines; after `U`, `svc-d` whole again.

**Check:** `bash labs/practice/nvim/check.sh 6`

<details><summary>Hint</summary>

`u` undoes one change, `<C-r>` redoes. `U` is the odd one: it works on a line, and is itself undoable with `u`. The shipped config sets `undofile`, so undo history survives `:wq` and reopening.

</details>

**Solution:** [d06](SOLUTION.md#d06)

---

## L2 — hinted (goal and steps; the keys are yours)

### d07 — `ci"`, `di(`, `da(`  (L2)

**Primer:** [Text objects](../../../content/primers/nvim-cheatsheet.md#text-objects)

**Goal:** line 1 value becomes `"production"`; line 2 becomes `MSG="restart () now"`; line 3 becomes `retry`.

**Setup:** `bash labs/practice/nvim/setup.sh 7`  **File:** `/root/practice/nvim/d07/deploy.env`

**Steps:**

1. Line 1: change the text inside the quotes.
2. Line 2: delete what is inside the parentheses, keep the parentheses.
3. Line 3: delete the parentheses and what is inside.
4. Write and quit.

**You should see:** the three lines exactly as in the Goal.

**Check:** `bash labs/practice/nvim/check.sh 7`

<details><summary>Hint</summary>

Operator `c` or `d`, then `i` (inner) or `a` (around), then the delimiter. The cursor must be on the line, and for `(` it must be on or inside the parentheses: `0f(` gets there.

</details>

**Solution:** [d07](SOLUTION.md#d07)

### d08 — `cit` and `dap`  (L2)

**Primer:** [Text objects](../../../content/primers/nvim-cheatsheet.md#text-objects)

**Goal:** the port becomes `8080`; the "stale block" paragraph is gone (including one blank line, so one blank remains before `<note>`).

**Setup:** `bash labs/practice/nvim/setup.sh 8`  **File:** `/root/practice/nvim/d08/service.xml`

**Steps:**

1. Search to the `<port>` line and change the tag's contents.
2. Search to the stale paragraph and delete the whole paragraph in one command.
3. Write and quit.

**You should see:** the file has 6 lines.

**Check:** `bash labs/practice/nvim/check.sh 8`

<details><summary>Hint</summary>

`it` is "inner tag", `ap` is "a paragraph" (it takes the trailing blank line along). A search such as `/<port<CR>` lands you on the tag.

</details>

**Solution:** [d08](SOLUTION.md#d08)

### d09 — `yi{` and paste  (L2)

**Primer:** [Text objects](../../../content/primers/nvim-cheatsheet.md#text-objects)

**Goal:** `location /api-v2` gets the same two directives as `location /api`.

**Setup:** `bash labs/practice/nvim/setup.sh 9`  **File:** `/root/practice/nvim/d09/api.conf`

**Steps:**

1. Put the cursor inside the `/api` block and yank the inside of the braces.
2. Go to the line `location /api-v2 {`.
3. Paste (the yank is linewise, so it lands below the cursor line, inside the braces).
4. Write and quit.

**You should see:** both blocks hold two lines.

**Check:** `bash labs/practice/nvim/check.sh 9`

<details><summary>Hint</summary>

`yi{`, then `/v2<CR>` jumps to the target, then `p`. If the text lands outside the braces you pasted from the wrong line or used `P`.

</details>

**Solution:** [d09](SOLUTION.md#d09)

### d10 — visual `V`, `>`, `gv`  (L2)

**Primer:** [The sentence](../../../content/primers/nvim-cheatsheet.md#the-sentence) (visual mode: see the box at the top)

**Goal:** `FOO` and `BAR` indented 2 spaces, the two `-` items indented 4 spaces (`env:` and `args:` stay at column 0).

**Setup:** `bash labs/practice/nvim/setup.sh 10`  **File:** `/root/practice/nvim/d10/compose.yml`

**Steps:**

1. `j` to `FOO`, `Vj` selects `FOO` and `BAR` linewise, `>` indents them once.
2. Move to the `- -v` line (`3j`), select it and the next line (`Vj`), press `>`.
3. `gv` reselects those same two lines; `>` again shifts them a second time.
4. `:wq<CR>`

**You should see:** 2-space and 4-space indents (the file is not valid compose, it is an indent exercise).

**Check:** `bash labs/practice/nvim/check.sh 10`

<details><summary>Hint</summary>

`V` then a motion extends the selection; `>` shifts by `shiftwidth` (2). After `>` the cursor returns to the first selected line, so `3j` from `FOO` reaches `- -v`. `gv` reselects the last visual area.

</details>

**Solution:** [d10](SOLUTION.md#d10)

### d11 — visual block insert and append  (L2)

**Primer:** [Day 7 nvim exercises](../../../content/day07.md)

**Goal:** the first three lines start with `# `; every line ends with ` # eu`; `web` becomes `node` on the first three lines.

**Setup:** `bash labs/practice/nvim/setup.sh 11`  **File:** `/root/practice/nvim/d11/hosts.txt`

**Steps:**

1. Block-select the first column of the first three lines and insert `# `.
2. Block-select all four lines out to the end of the longest and append ` # eu`.
3. Select the first three lines linewise and, from the `:` prompt that nvim opens as `:'<,'>`, replace `web` with `node` on just those lines.
4. Write and quit.

**You should see:** line 1 is `# 10.0.0.11 node01 # eu`; line 4 is `10.0.0.14 db01 # eu`.

**Check:** `bash labs/practice/nvim/check.sh 11`

<details><summary>Hint</summary>

`<C-v>` starts the block, `I` inserts at its left edge, `A` appends at its right. Press `$` after `<C-v>` (and the movement) and the block follows each line's own end, so `A` works on lines of different length. The edit shows on all lines only after `<Esc>`. For step 3, `V2j` selects three lines, then typing `:` shows `:'<,'>` already filled in; add `s/web/node/` and `<CR>`.

</details>

**Solution:** [d11](SOLUTION.md#d11)

### d12 — registers: `"a`, `"_`  (L2)

**Primer:** [Registers and macros](../../../content/primers/nvim-cheatsheet.md#registers-and-macros)

**Goal:** delete the two `# junk` lines, and replace `web`'s `down` line with `api`'s `server` line.

**Setup:** `bash labs/practice/nvim/setup.sh 12`  **File:** `/root/practice/nvim/d12/upstreams.conf`

**Steps:**

1. Yank the `api` server line into register `a`.
2. Delete both junk lines without disturbing any register.
3. Delete the `down` line without touching the unnamed register (or `a`), then put register `a`'s line where it was.
4. Write and quit.

**You should see:** two `upstream` blocks, each with `server 10.0.0.1:8080;`.

**Check:** `bash labs/practice/nvim/check.sh 12`

<details><summary>Hint</summary>

`"ayy` yanks into `a`; `"ap` / `"aP` puts below / above. The blackhole register `"_` swallows a delete: `"_dd`. After deleting the `down` line you stand on `}`, so `P` puts above it.

</details>

**Solution:** [d12](SOLUTION.md#d12)

### d13 — `:s` with `\v` groups, `&`, `g&`  (L2)

**Primer:** [Ex commands](../../../content/primers/nvim-cheatsheet.md#ex-commands-an-operator-actually-needs)

**Goal:** every `name.env.example.com` becomes `env-name` (`web01.prod.example.com` -> `prod-web01`); IPs untouched.

**Setup:** `bash labs/practice/nvim/setup.sh 13`  **File:** `/root/practice/nvim/d13/fleet.txt`

**Steps:**

1. On line 1 run one `:s` that captures the two labels with `\v` groups and swaps them.
2. Move to line 2 and repeat the last `:s` with `&`.
3. Repeat it on the whole file with `g&`.
4. Write and quit.

**You should see:** all four lines swapped, nothing doubled.

**Check:** `bash labs/practice/nvim/check.sh 13`

<details><summary>Hint</summary>

`\v` makes `( ) + .` regex operators (literal dot is `\.`). Groups come back as `\1`, `\2`. `&` repeats the last `:s` on this line; `g&` repeats it on every line (a line already changed no longer matches, so it is skipped).

</details>

**Solution:** [d13](SOLUTION.md#d13)

### d14 — macro: `qa`/`q`, `@a`, `3@@`  (L2)

**Primer:** [Registers and macros](../../../content/primers/nvim-cheatsheet.md#registers-and-macros)

**Goal:** every `web01 10.0.1.11` line becomes `- {host: web01, ip: 10.0.1.11}`.

**Setup:** `bash labs/practice/nvim/setup.sh 14`  **File:** `/root/practice/nvim/d14/inventory.txt`

**Steps:**

1. On line 1 record a macro into `a` that converts the line **and ends by moving to the next line**.
2. Line 1 is converted by the recording itself. Run `@a` once (line 2), then `3@@` (the last macro, three more times: lines 3-5).
3. Write and quit.

**You should see:** five YAML flow-style list items.

**Check:** `bash labs/practice/nvim/check.sh 14`

<details><summary>Hint</summary>

Recording: `qa` to start, `q` to stop. Inside: `I` for the prefix, `f<space>` to find the separator, `s` to replace that one char, `A` for the suffix, `j` to land on the next line. Then `@a` and `3@@`; `@@` repeats the last-run macro, with a count.

</details>

**Solution:** [d14](SOLUTION.md#d14)

---

## L3 — challenge (goal and budget only)

### d15 — `:g`, `:v`, `:g/.../normal`  (L3)

**Primer:** [Ex commands](../../../content/primers/nvim-cheatsheet.md#ex-commands-an-operator-actually-needs)

**Goal:** from `app.log` keep only real log lines, drop DEBUG, and flag each ERROR with the suffix `  <-- page` (two spaces, then `<--`).

**Setup:** `bash labs/practice/nvim/setup.sh 15`  **File:** `/root/practice/nvim/d15/app.log`

**Budget:** three ex commands, at most 55 keystrokes in total, no hand-editing of lines.

**You should see:** 4 lines: INFO, ERROR, WARN, ERROR (the ERRORs flagged).

**Check:** `bash labs/practice/nvim/check.sh 15`

<details><summary>Hint</summary>

Real lines start with the year; `:v/pat/d` deletes the lines that do **not** match. `:g/pat/normal {keys}` runs normal-mode keys on each match.

</details>

**Solution:** [d15](SOLUTION.md#d15)

### d16 — `:s` with a range and confirm  (L3)

**Primer:** [Ex commands](../../../content/primers/nvim-cheatsheet.md#ex-commands-an-operator-actually-needs)

**Goal:** move `web` and `api` in the *edge* block from port 80 to 8080. `admin` stays on 80, and the *staging* block is untouched.

**Setup:** `bash labs/practice/nvim/setup.sh 16`  **File:** `/root/practice/nvim/d16/listen.conf`

**Budget:** one ex command plus your answers, at most 22 keystrokes, then `:wq<CR>`.

**You should see:** the prompt `replace with 8080 (y/n/a/q/l/^E/^Y)?` once per candidate line.

**Check:** `bash labs/practice/nvim/check.sh 16`

<details><summary>Hint</summary>

A range before `s` limits the lines (`:2,4s`); the flag `c` asks per match. Read each prompt: the answer for `admin` is `n`.

</details>

**Solution:** [d16](SOLUTION.md#d16)

### d17 — `:sort`  (L3)

**Primer:** [Ex commands](../../../content/primers/nvim-cheatsheet.md#ex-commands-an-operator-actually-needs)

**Goal:** `disk.txt` sorted by size, largest first, with the duplicate line gone.

**Setup:** `bash labs/practice/nvim/setup.sh 17`  **File:** `/root/practice/nvim/d17/disk.txt`

**Budget:** one ex command, at most 12 keystrokes, then `:wq<CR>`.

**You should see:** 4 lines starting `/srv 1024`.

**Check:** `bash labs/practice/nvim/check.sh 17`

<details><summary>Hint</summary>

`:sort` flags: `n` numeric, `u` unique, and `!` reverses.

</details>

**Solution:** [d17](SOLUTION.md#d17)

### d18 — `:g/^$/d` and `:norm`  (L3)

**Primer:** [Ex commands](../../../content/primers/nvim-cheatsheet.md#ex-commands-an-operator-actually-needs)

**Goal:** turn `app.env` into three lines like `export DB_HOST=db01;` (no blank lines).

**Setup:** `bash labs/practice/nvim/setup.sh 18`  **File:** `/root/practice/nvim/d18/app.env`

**Budget:** three ex commands, at most 40 keystrokes in total, then `:wq<CR>`.

**You should see:** 3 lines, each starting `export ` and ending `;`.

**Check:** `bash labs/practice/nvim/check.sh 18`

<details><summary>Hint</summary>

`:%norm` runs normal-mode keys on every line: `I` inserts at the start, `A` appends. An empty-line pattern is `^$`.

</details>

**Solution:** [d18](SOLUTION.md#d18)

### d19 — quickfix: `:vimgrep` + `:cdo`  (L3)

**Primer:** [Moving without a mouse](../../../content/primers/nvim-cheatsheet.md#moving-without-a-mouse)

**Goal:** in every `.conf` file under `d19/` replace `old-api.internal` with `api.internal`. `docs/notes.md` must stay unchanged.

**Setup:** `bash labs/practice/nvim/setup.sh 19`  **Files:** `/root/practice/nvim/d19/app/web.conf`, `app/batch.conf`, `docs/notes.md`

**Budget:** two ex commands and a quit, at most 65 keystrokes in total. Start nvim from `/root/practice/nvim/d19` (`cd` there, run `nvim`).

**You should see:** `:copen` lists 3 hits, all in `.conf` files.

**Check:** `bash labs/practice/nvim/check.sh 19`

<details><summary>Hint</summary>

`:vimgrep /pat/ **/*.conf` fills the quickfix list. `:cdo {cmd}` runs a command on each entry; chain `| update` so each file is saved before the next. Because `hidden` is on, `:cdo` works without `| update`, but the buffers stay modified: `:qa` then says `E37`/`E162` until you `:wa`. `| update` saves as it goes.

</details>

**Solution:** [d19](SOLUTION.md#d19)

### d20 — one substitute does it all  (L3)

**Primer:** [Ex commands](../../../content/primers/nvim-cheatsheet.md#ex-commands-an-operator-actually-needs)

**Goal:** every `key=value` line becomes `export KEY="value"` (key uppercased, value quoted).

**Setup:** `bash labs/practice/nvim/setup.sh 20`  **File:** `/root/practice/nvim/d20/app.conf`

**Budget:** one ex command, at most 40 keystrokes, then `:wq<CR>`.

**You should see:** five `export` lines, e.g. `export LOG_LEVEL="warn"`.

**Check:** `bash labs/practice/nvim/check.sh 20`

<details><summary>Hint</summary>

Two `\v` groups; in the replacement `\U` starts uppercase, `\E` ends it. A literal `=` in a `\v` pattern is `\=` (a bare `=` means "0 or 1" there).

</details>

**Solution:** [d20](SOLUTION.md#d20)

---

## Stuck? Hints

- **Lost in a mode:** `<Esc>` twice, look at the bottom-left (`-- INSERT --`, `-- VISUAL --`), then `u` to undo anything odd.
- **`E37: No write since last change`:** you tried `:q` with edits. `:wq` to keep them, `:q!` to drop them.
- **`E325: swap file exists`:** an earlier session was killed. Choose `(D)elete` or reset the drill with `setup.sh N`.
- **Arrow keys do nothing:** by design. Use `h j k l`.
- **`FAIL` and the diff looks identical:** look for trailing spaces and tabs; `:set list` shows them. Check the very last line too.
- **My macro ran on one line only:** it must end by moving to the next line (`j`), and start from a fixed column (`0` or `I`).
- **Confirm prompt (`y/n/a/q/l`):** `y` yes, `n` skip this one, `a` all remaining, `q` stop.
- **Not enough keystrokes?** Re-read the primer grammar: operator + count + motion/text object. Most budgets are met by one text object or one ex command.
- **Still stuck after 10 minutes:** read the drill's [SOLUTION.md](SOLUTION.md) section, then `setup.sh N` and redo it without looking.

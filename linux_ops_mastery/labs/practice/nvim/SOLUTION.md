# nvim workbook — solutions and why

Keys are written as you type them. `<CR>` = Enter, `<Esc>` = Escape, `<C-v>` = Ctrl-v. Try the drill first; see the [README](README.md). Every solution here was run headlessly in `ws` with the shipped `init.lua` and then passed `check.sh`; d06 and d14 (undo steps, macro recording) were also driven interactively in a pty.

<a id="d01"></a>
## d01 — open, jump, change, append
`nvim /root/practice/nvim/d01/nginx.conf`, then
`:3<CR>$bcw1024<Esc>Go# end of nginx.conf<Esc>:wq<CR>`
Why: `:3` is "go to line 3"; `$b` goes to the end of the line and back one word, onto `512` (`0`, `w`, `e` are the other word motions to try); `cw` changes to the end of the word (the `;` is not part of it); `G` is the last line; `o` opens a line below and enters insert mode.

<a id="d02"></a>
## d02 — search, `*`, `n`, `.`
`ggw*cwweb<Esc>n.` then `/down<CR>ciwbackup<Esc>:wq<CR>`
Why: `*` searches for the whole word under the cursor, so `n` afterwards uses the same pattern and wraps to the other `pool`. `.` repeats the last change (`cwweb<Esc>`). `ciw` changes the whole word `down` from wherever you stand in it.

<a id="d03"></a>
## d03 — `%` and `O`
`/deploy()<CR>$%Oecho "deployed ${rel}"<Esc>:wq<CR>`
Why: `$` lands on `{`, `%` jumps to its partner `}`, `O` opens a line above it. The shell filetype indents the new line by two spaces automatically, so you type none (typing two more gives four, and `check.sh` shows it).

<a id="d04"></a>
## d04 — `f`, `;`, `ct,`, `.`
`:4<CR>0f,;lct,stage<Esc>j0f,;l.:wq<CR>`
Why: `f,` finds the first comma, `;` repeats the find (the second comma), `l` steps onto the first letter of the field. `ct,` changes up to the next comma. On the next row the same navigation is repeated and `.` replays `ct,stage`.

<a id="d05"></a>
## d05 — operators with counts
`3dddwjf;d$jyypcwtimeout<Esc>>>:wq<CR>`
Why: `3dd` removes three lines; `dw` deletes a word and the space after it; `f;` + `d$` deletes from the `;` to the end; `yyp` duplicates a line; `cw` renames the copy; `>>` indents by `shiftwidth` (2, expanded to spaces).

<a id="d06"></a>
## d06 — undo, redo, `U`
`dddddd` `uu` `<C-r>` `jxx` `U` `A # keep<Esc>:wq<CR>`
Why: three deletions are three undo steps; `uu` brings two lines back (`svc-b`, `svc-c`), `<C-r>` re-applies the deletion of `svc-b`. `U` undoes all the changes made on the line since you moved onto it, so the two `x` are reverted at once. 

<a id="d07"></a>
## d07 — `ci"`, `di(`, `da(`
`ci"production<Esc>j0f(di(j0f(da(:wq<CR>`
Why: `ci"` works from anywhere on the line (it finds the quotes). `di(` needs the cursor on or inside the parentheses, hence `0f(`; it keeps the `()`. `da(` takes the parentheses too.

<a id="d08"></a>
## d08 — `cit`, `dap`
`/<port<CR>cit8080<Esc>/stale<CR>dap:wq<CR>`
Why: `it` selects between `<port>` and `</port>`. `ap` is the paragraph plus one trailing blank line, so exactly one blank line is left before `<note>`.

<a id="d09"></a>
## d09 — `yi{`
`/proxy<CR>yi{/v2<CR>p:wq<CR>`
Why: when the braces are on their own lines, `i{` is the lines between them and the yank is linewise. `p` on the `location /api-v2 {` line puts those lines below it, inside the block.

<a id="d10"></a>
## d10 — `V`, `>`, `gv`
`jVj>3jVj>gv>:wq<CR>`
Why: `jVj>` indents `FOO` and `BAR` once; the cursor returns to the first selected line, so `3j` reaches `- -v`. `Vj>` indents the items once, `gv` reselects them, `>` indents again (4 spaces).

<a id="d11"></a>
## d11 — visual block
`gg<C-v>jjI# <Esc>gg<C-v>G$A # eu<Esc>gg` then `V2j:s/web/node/<CR>:wq<CR>`
Why: `<C-v>jj` is a one-column, three-row block; `I` inserts at its left edge and the text is replicated to the other rows when you leave insert mode. `$` inside a block makes it ragged to each line's end, so `A` appends at every line's end. Typing `:` in visual mode pre-fills `:'<,'>` (the selected lines), so the `s` only touches lines 1-3; `web01` -> `node01`, `db01` is untouched.

<a id="d12"></a>
## d12 — registers
`j"ayy/junk<CR>"_2dd/down<CR>"_dd"aP:wq<CR>`
Why: `"ayy` stores the line in `a`. `"_2dd` deletes two lines into the blackhole, so nothing is overwritten. After `"_dd` of the `down` line the cursor is on `}`; `"aP` puts `a` above it. (Without the blackhole, the plain unnamed register would hold the last delete, but `"0` would still hold your last *yank*; `"0P` is the other way to do it.)

<a id="d13"></a>
## d13 — `\v` groups, `&`, `g&`
`:s/\v(\w+)\.(\w+)\.example\.com/\2-\1/<CR>j&g&:wq<CR>`
Why: `\v` very magic: `(..)` are groups and `+` is a quantifier. `\1` is the host, `\2` the environment. `&` repeats the last `:s` on the line (without flags); `g&` is `:%s//~/&`, the last `:s` on all lines. Lines already changed no longer match and are skipped. `:%s/\v.../\2-\1/` in one go is the same result.

<a id="d14"></a>
## d14 — macro
`qaI- {host: <Esc>f s, ip: <Esc>A}<Esc>jq@a3@@:wq<CR>`
Why: `I` goes to the start and inserts; `f ` (f, space) finds the separator; `s` replaces that one char with `, ip: `; `A` appends `}`; `j` ends on the next line so the macro can chain. The recording itself converted line 1; `@a` does line 2, and `3@@` replays the last-run macro three more times (lines 3-5). 

<a id="d15"></a>
## d15 — `:g`, `:v`
`:v/^2026/d<CR>:g/DEBUG/d<CR>:g/ERROR/normal A  <-- page<CR>:wq<CR>` (50 keys before `:wq`)
Why: `:v` runs `d` on every line that does *not* match, which removes the comment, the blank and the `-- rotated --` line. `:g/DEBUG/d` removes the DEBUG lines. `:g/ERROR/normal A...` runs `A` plus the text on each ERROR line.

<a id="d16"></a>
## d16 — range and confirm
`:2,4s/80/8080/gc<CR>yyn:wq<CR>` (20 keys)
Why: the range `2,4` is the edge block. `c` stops at each match; answer `y` for `web`, `y` for `api`, `n` for `admin`. The staging lines are outside the range.

<a id="d17"></a>
## d17 — `:sort`
`:sort! nu<CR>:wq<CR>` (10 keys before `:wq`)
Why: `n` sorts by the first number on the line, `!` reverses, `u` drops lines that compare equal (here the repeated `/home 12`).

<a id="d18"></a>
## d18 — `:g/^$/d` and `:norm`
`:g/^$/d<CR>:%norm Iexport <CR>:%norm A;<CR>:wq<CR>` (34 keys before `:wq`)
Why: `^$` matches only empty lines. `:%norm Iexport ` runs `Iexport ` (note the trailing space) on every line; `A;` appends. `:normal` ends the insert on its own, so no `<Esc>`.

<a id="d19"></a>
## d19 — quickfix
From `/root/practice/nvim/d19`: `nvim`, then `:vimgrep /old-api/ **/*.conf<CR>:cdo s/old-api/api/ | update<CR>:qa<CR>` (62 keys)
Why: `:vimgrep` collects every match in `.conf` files (`**` recurses; `docs/notes.md` is not a `.conf`) into the quickfix list. `:cdo` runs the command on each entry. nvim has `hidden` on by default, so `:cdo s/old-api/api/` alone also finishes without error and leaves the files modified in hidden buffers; the trouble only shows at `:qa` (`E37`/`E162`), and `:wa` then `:qa` is the alternative. `| update` writes each file as it goes, so `:qa` is clean.

<a id="d20"></a>
## d20 — one substitute
`:%s/\v(\w+)\=(.*)/export \U\1\E="\2"/<CR>:wq<CR>` (38 keys before `:wq`)
Why: group 1 is the key, group 2 the value; `\U...\E` uppercases just the key. The literal `=` must be written `\=` in `\v` mode.

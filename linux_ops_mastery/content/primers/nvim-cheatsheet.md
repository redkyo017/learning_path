# nvim cheatsheet — the grammar, not a command list

Vim/nvim is a language, not a command palette. Memorizing keystrokes as
isolated commands doesn't scale; learning the grammar does, because every
new motion or text object you learn immediately composes with every
operator you already know. This is that grammar.

## The sentence

Every edit is a sentence: `<operator><count><motion|text-object>`. The
operator says *what to do*; the count/motion/text-object says *where*.
Drop the operator entirely and the motion just moves the cursor.

- Operators: `d` (delete), `c` (change), `y` (yank), `>`/`<` (indent),
  `gu`/`gU` (lowercase/uppercase), `!` (filter through external command).
- A count before the operator *or* the motion multiplies — `2dw` and `d2w`
  are the same edit.
- Double the operator (`dd`, `cc`, `yy`, `>>`, `guu`) to apply it linewise
  to the current line — a shorthand for `<op><op>`, not a special case.

The same five operators against five motions/text-objects — this grid is
the entire mental model, everything below just grows the second axis:

| op | w | } | ip | i" | t, |
|---|---|---|---|---|---|
| d | dw | d} | dip | di" | dt, |
| c | cw | c} | cip | ci" | ct, |
| y | yw | y} | yip | yi" | yt, |
| > | >w | >} | >ip | >i" | >t, |
| gu | guw | gu} | guip | gui" | gut, |

Only `>`, `<`, `=`, and `!` are **linewise by nature**: `>w` still only
indents the current line, because indent always rounds its target up to
whole lines regardless of the motion's own width. `d`, `c`, `y`, `gu`,
and `gU` all respect the motion's actual shape instead — `guw` and
`gui"` genuinely operate charwise, lowercasing exactly the word or the
quoted text and nothing else.

## Motions

- **Word:** `w`/`b`/`e` (word start/back/end), `W`/`B`/`E` (WORD, i.e.
  whitespace-delimited, ignores punctuation boundaries).
- **Line:** `0`/`^`/`$` (col 0 / first non-blank / end), `gg`/`G` (file
  top/bottom), `{count}G` or `:{count}` (go to line).
- **Screen:** `H`/`M`/`L` (top/middle/bottom of window), `Ctrl-d`/`Ctrl-u`
  (half-page down/up), `zz`/`zt`/`zb` (recenter cursor line).
- **File:** `gg`, `G`, `` `` `` (jump back to last position, exact),
  `''` (jump back, linewise).
- **Search as motion:** `/pat<CR>` and `?pat<CR>` are motions — `d/foo<CR>`
  deletes up to the next `foo`. `n`/`N` repeat forward/backward.
- **Character find:** `f{c}`/`F{c}` (to char, inclusive, fwd/back),
  `t{c}`/`T{c}` (till char, stops one short), `;`/`,` (repeat find,
  same/opposite direction). `dt,` deletes up to (not including) the
  next comma — the workhorse for editing CSV-shaped log lines.

## Text objects

Every text object is `i` (inner: contents only) or `a` (around: contents
plus the delimiter/whitespace). This is the second half of the grammar,
alongside motions — text objects are what an operator eats when the thing
you want isn't expressible as a movement (a quoted string, a bracketed
block, a paragraph).

- `iw`/`aw` — inner/a word (`aw` includes trailing whitespace).
- `i"`/`a"` — inner/a double-quoted string (`a"` includes the quotes).
- `i(`/`a(` (also `ib`/`ab`) — inner/a parenthesized block.
- `ip`/`ap` — inner/a paragraph (`ap` includes the trailing blank line).
- `it`/`at` — inner/a tag (HTML/XML/JSX): `it` is between `<tag>` and
  `</tag>`; `at` includes the tags themselves.

One example line, `f("bad arg")`, shows the distinction directly:
cursor anywhere inside the quotes, `di"` leaves `f("")` — only the text
between the quotes is gone; `da"` leaves `f()` — the quotes go too.

## Ex commands an operator actually needs

- `:g/pat/cmd` — run `cmd` on every line matching `pat` (default `cmd` is
  print). `:g/ERROR/d` deletes every error line file-wide in one pass.
- `:v/pat/cmd` — inverse of `:g`: run `cmd` on every line **not** matching.
  `:v/ERROR/d` keeps only the error lines.
- `:%s/old/new/gc` — substitute across the whole file (`%`), all matches
  per line (`g`), with confirmation per hit (`c`) — the safe default over
  a blind `:%s///g` on a file you haven't grepped first.
- **Ranges:** `:5,10d` (lines 5-10), `:.,+5d` (current line plus next 5),
  `:'a,'bd` (between marks `a` and `b`), `:g/pat/normal @a` (range = every
  matching line, from `:g`).
- `:normal {keys}` — replay a normal-mode sequence per matched line; pairs
  with `:g` for "do this edit on every line matching that pattern."
- `:%!cmd` — filter the whole buffer through an external command and
  replace it with the output (`:%!sort`, `:%!jq .`, `:%!column -t`).
- `:r !cmd` — read a shell command's stdout into the buffer at the
  cursor, without leaving the editor.
- `:w !sudo tee %` — the fix for "opened a root-owned file without sudo":
  writes the buffer through `sudo tee` back onto the same path, then
  `:e!` to reload it since `:w` itself didn't touch the file on disk.

## Registers and macros

- `"ayy` — yank the current line into register `a` (`"a` before any
  yank/delete/change targets that register instead of the unnamed one).
- `"ap` — paste from register `a`. Uppercase (`"A`) appends instead of
  overwriting — build up a multi-line register across several yanks.
- `qa … q` — record a macro into register `a`: `qa` starts recording,
  the keystrokes in between are the macro body, `q` stops.
- `@a` — replay the macro in register `a` once. `@@` replays whichever
  macro ran last, so you don't retype the register name.
- `5@a` — replay macro `a` five times; `99@a` on a file with fewer than
  99 remaining targets stops cleanly at the last one, no error needed.

## Moving without a mouse

- **Buffers:** `:ls` (list open buffers), `:b {N|name}` (jump to one),
  `:bn`/`:bp` (next/previous), `Ctrl-^` (toggle last two buffers).
- `:argdo {cmd}` — run `cmd` across every file in the argument list
  (`:args *.log`, then `:argdo %s/foo/bar/ge | update`).
- **Quickfix:** `:cn`/`:cp` (next/previous match), `:cc {N}` (jump to
  entry N), `:copen` (open the list window), populated by `:vimgrep` or
  an external `:grep`.
- `:cdo {cmd}` — like `:argdo` but iterates the quickfix list instead of
  the arg list — run one edit across every grep hit.
- **Marks:** `` ma `` sets mark `a` at the cursor; `` `a `` jumps to it
  exactly, `` 'a `` jumps to its line's first non-blank.
- `Ctrl-o`/`Ctrl-i` — back/forward through the jump list (like browser
  back/forward) — the fastest way to return after a `gg`, search, or `gd`.

## The five-line survival card

- **Stuck in a mode or a pending operator:** `Esc` (or `Ctrl-c`) always
  returns to normal mode; `Esc` twice clears a half-typed command safely.
- **File opened read-only (permissions):** finish the edit anyway, then
  `:w !sudo tee % > /dev/null`, then `:e!` to reload without re-prompting.
- **Terminal is 80x24 and splits feel cramped:** skip splits — `:b {n}`,
  `Ctrl-^`, and the quickfix list cover buffer-switching without a second
  window; `zz` recenters instead of scrolling blind.
- **Accidentally in Ex/replace/visual-block and unsure what's active:**
  `Ctrl-c` returns to normal mode from almost anywhere; the bottom-left
  status line (`-- INSERT --`, `-- VISUAL --`, etc.) names the mode you
  were actually in, so check it before your next keystroke.
- **`nvim` absent, only busybox `vi`** (the `app`/`slim` containers):
  most of this grammar does **not** survive — no text objects (`iw`,
  `i"`, `ip`, `it`), no `gu`/`gU`, no `:normal`, no `:g`/`:v`. What does
  survive: `hjkl`, `dw`/`dd`/`x`, `/search`, `:%s/old/new/g`, `:w`/`:q`,
  and counts (`5dd`). This is exactly why this path has you edit inside
  `ws` (real `nvim`) rather than `app`/`slim` — and why, on a busybox box,
  you deliberately fall back to that smaller vocabulary instead of
  discovering the gaps one failed keystroke at a time under pressure.

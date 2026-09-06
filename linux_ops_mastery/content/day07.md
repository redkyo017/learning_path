# Day 7 — Synthesis: neovim as an operator's tool, and the gauntlet

**Truth of the day:** all four (mount tree, process table, fd table, cgroup
boundary) — today recombines them, it does not add a fifth.
**Budget:** 3 h — 1.5 h neovim + 1.5 h gauntlet

## Why this matters

Two things separate someone who *studied* Linux from someone who *operates*
it: editing confidently on a machine with no GUI and no configured editor,
and reaching a correct diagnosis under a clock with nobody to ask. The first
six days built the vocabulary — one truth, one tool, one break, one fix, one
proof, each day. Today has no new vocabulary. It has a clock, five incidents
you have not seen, and the same four files you have been reading all week.

## Read the file first

For every prior day, "the file" was something under `/proc` or `/sys`.
Today it is `journal.md` — the one file you wrote yourself. Reread all six
chains before touching the gauntlet, and for each one mark the single step
where you wrote a claim you had not yet proved: the line that says "probably
X" instead of "Proof: `command` → `output`". That step is where you guessed.
Everyone has at least one. Finding it in your own writing, in your own
words, before the clock starts, is worth more than any tip in this file.

## Derive the tool

The "tool" this day derives is the editor itself. `labs/day07/init.lua`,
reproduced below, is the entire operator config — plugin-free, under 30
lines, and *safe to paste onto any server you have never seen*, because it
asks nothing of that server beyond a `nvim` binary. Each line earns its
place by a question a bare server forces on you:

```lua
-- Linux Operator Mastery: plugin-free operator config.
-- No plugin manager, no LSP, no completion. Motions and ex commands only.
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.undofile = true
-- clipboard: deliberately left at the default. A container has no host
-- clipboard, so learning the plus-register here would teach you a lie.

-- Arrow keys are off. h j k l is the whole point.
for _, key in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
  for _, mode in ipairs({ "n", "i", "v" }) do
    vim.keymap.set(mode, key, function()
      vim.notify("Use h j k l.", vim.log.levels.WARN)
    end)
  end
end
```

`number`/`relativenumber` together give you an absolute line for `:123` and
a relative count for `5j` in the same gutter — the two things `:g/pat/normal
@a` and macros need to target a line without counting by eye.
`expandtab`/`shiftwidth`/`softtabstop` avoid a mixed-tabs-and-spaces diff on
a shared config file, which is the single most common reason a one-line fix
turns into a ten-line diff nobody wants to review. `ignorecase`+`smartcase`
means `/error` also finds `ERROR`, but `/Error` (any uppercase letter) stays
exact — one pair of settings, no flag to remember mid-search. `hlsearch`
shows every match at once, which matters more here than usual: `:g//` and
`:v//` act on exactly what `hlsearch` is lighting up. `undofile` survives a
crashed SSH session — the undo tree persists to disk, not just to the
process's memory. Nothing else is here on purpose: no colorscheme (the
default renders on any terminal, including one with no 256-color support),
no statusline plugin (the built-in one already names the mode), no LSP or
completion (both assume a language server this box does not have and often
must not have). The arrow-key block is copied verbatim from Day 1's
`init.lua` — see `Dockerfile.ws`, which ships the identical file so the
learner never has to hand-type it twice.

## Core concepts

**`:g/pattern/cmd` and `:v//pattern/cmd`.** This is the highest-leverage ex
command in the whole grammar, because it turns "edit N lines" into "state
the pattern once." Four worked examples, all against a hypothetical
`app.log`:

1. Delete every matching line: `:g/DEBUG/d` — one pass, no loop, no macro.
2. Move matches to the end of the file: `:g/ERROR/m$` — `:m$` moves the
   current (matched) line to after the last line; `:g` reruns it per match,
   so every `ERROR` line ends up at the bottom in its original order.
3. Number the matches with their own file line number, without touching
   any other line: `:g/WARN/s/^/\=line(".") . ": "/` — `\=` inside a
   substitute's replacement evaluates one Vim expression and uses its
   (auto-stringified) result; `line(".")` is the current line's number.
4. Run `:normal` on every match: `:g/^ERROR/normal A;` appends a semicolon
   to every line starting with `ERROR` — `:normal {keys}` replays a
   normal-mode keystroke sequence on each matched line, so anything you can
   type by hand you can also broadcast with `:g`.

`:v//cmd` is `:g` with the match inverted: `:v/ERROR/d` deletes every line
that is *not* an error, keeping only what you came to read. See the
`nvim-cheatsheet.md` primer for the full `:g`/`:v`/range grammar — it is not
repeated here.

**Registers, named and numbered.** `"ayy` yanks a line into register `a`;
`"ap` pastes it. Numbered registers (`"1` through `"9`) fill automatically
from recent deletes — `"1p` after a `dd` pastes back the line you just
deleted, and each further delete shifts `"1`→`"2`→… so `"3p` reaches three
deletes back without having named anything.

**Recording a macro, replaying with a count, and why it starts with `0`.**
`qa` starts recording into register `a`; the keystrokes until `q` are the
macro body; `@a` replays it once, `5@a` replays it five times. A
well-recorded macro starts with `0` (column 0, not `^`) so that replaying it
on a line whose cursor position differs from the line you recorded on still
starts from the same place — a macro that assumes "the cursor is already
where I left it" breaks the moment a target line is shorter or the cursor
drifted, and `0` is the one motion guaranteed to land the same way on every
line regardless of its content.

**Buffers versus windows versus tabs.** A buffer is a file loaded into
memory; a window is a viewport onto a buffer; a tab is a named collection of
windows. Ten open files is ten buffers whether or not you ever split a
window to look at more than one at once — `:ls` lists buffers, not windows.
On an 80x24 terminal, prefer switching buffers (`:b {name}`, `Ctrl-^`) over
splitting windows; a split halves your usable width for no benefit when you
only look at one file at a time anyway.

**The argument list and `:argdo %s///ge | update`.** `:args *.conf` loads
every matching path into the argument list (distinct from the buffer list —
every arg becomes a buffer, but not every buffer is on the arg list).
`:argdo %s/old/new/ge | update` runs the substitution across the whole
buffer (`%`) for every occurrence per line (`g`), suppressing "pattern not
found" errors for files that don't match (`e`), then writes only the
buffers `:argdo` actually changed (`update`, unlike `w`, is a no-op on an
unmodified buffer — safe to chain after files the pattern skipped).

**Quickfix from `:grep`/`:cexpr`, `:cn`/`:cp`, and `:cdo`.** `:grep
status=500 access.log` shells out to the external `grep`, and its matches
populate the quickfix list; `:cexpr system('grep -n status=500 access.log')`
does the same from a raw command when you want more control over the
source. `:cn`/`:cp` step forward/back through the list one match at a time;
`:copen` opens it as a browsable window. `:cdo {cmd}` is `:argdo` for the
quickfix list instead of the arg list — run one edit across every grep hit
in one pass, e.g. `:cdo s/status=500/status=502/`.

**`:%!sort -u` and `:%!jq .` as buffer-through-shell filters.** `:%!cmd`
replaces the whole buffer with the stdout of piping it through `cmd`.
`:%!sort -u` sorts and dedupes in place; `:%!jq .` pretty-prints a
minified JSON buffer, using `jq` as a formatter with no separate save/reload
round trip. If `cmd` exits non-zero or prints nothing, `:undo` gets the
buffer back — `:%!` never touches the file on disk until you `:w`.

**`:r !cmd`.** Reads a shell command's stdout into the buffer at the cursor
without leaving the editor or losing your place — `:r !date` drops a
timestamp inline; `:r !curl -s https://…` drops a fetched response body in.

**Marks and the jump list.** `ma` sets mark `a` at the cursor; `` `a `` jumps
back to that exact position, `'a` to its line's first non-blank. The jump
list is automatic — every search, `gg`, `G`, or `:{N}` pushes the old
position onto it, and `Ctrl-o`/`Ctrl-i` walk back and forward through it
like browser history, which is faster than a mark for "let me just go back
to where I was a second ago."

**`:diffthis` on two buffers.** Open both files, run `:diffthis` in each
window, and nvim highlights every differing hunk with `]c`/`[c` to jump
between them — the fastest way to compare a deployed config against a known
good one without leaving the editor for an external `diff`.

**`:w !sudo tee % >/dev/null` for a file opened read-only.** You edited a
root-owned file as yourself, `:w` fails with "permission denied," and the
buffer's changes are still only in memory. `:w !sudo tee % >/dev/null`
pipes the buffer's content through `sudo tee` back onto the same path (`%`)
— the buffer itself is unmodified by this, so nvim still reports it as
"changed," and `:e!` reloads the now-actually-written file from disk to
clear that flag.

## Lab

See `labs/day07/`. The goal: reach a proven diagnosis on five unseen
incidents inside a 90-minute budget, with the chain written before the fix
every time. Success signal: five entries in `journal.md`, each with a
`verify.sh` pass, none of them started by reading `ANSWERS.md`.

This day has no `break.sh` — it has `gauntlet.sh`, because there is no
single incident to run: `gauntlet.sh {1..5|all}` injects one incident (or
all five in sequence) and prints one symptom line per incident, exactly as
every prior `break.sh` did. The rules: 15 minutes per incident, a written
chain in `journal.md` before any fix is attempted, no reading `ANSWERS.md`
until all five chains exist, and a self-scored result — `verify.sh` gives
you an objective pass/fail, but whether you *earned* it by proof rather
than guesswork is a judgment only your own `journal.md` entry can answer.

## Strip the toolbox

Three of the five incidents live entirely inside `app` or `slim` — Alpine,
busybox `ps`/`pgrep`/`grep`/`awk`, no `lsof`, no `ss`. There is no separate
"now redo it without the tool" step today, because the gauntlet never hands
you the tool in the first place: busybox `pgrep` has neither `-c` nor `-n`,
so counting matches is `pgrep -f PATTERN | wc -l` and finding one specific
match is `pgrep -f PATTERN | tail -1`, not a flag. One trap in that idiom
under a clock: a `pgrep -f` pattern that appears verbatim in the command
line of the shell running `pgrep` (e.g. inside `sh -c 'pgrep -f PATTERN'`)
matches that shell too — bracket one character to break the literal match,
`"/srv/app[.]py"` or `"sleep 10000[0]"`, the same trick as `ps aux | grep
"[p]ython"`. Skip it and `tail -1` can hand back the wrapper shell instead
of the process you meant, which under the gauntlet's clock reads as "the
fix did nothing" when the real problem is that nothing was ever targeted.
The one place this matters for the editor rather than the shell: `app` and
`slim` ship only
busybox `vi`, which has no text objects, no `gu`/`gU`, and no `:normal` —
if a fix requires editing a file that only exists inside one of them, the
grammar from this file mostly does not apply, and the busybox survival
subset is what is left. The busybox survival subset — `hjkl`,
`dw`/`dd`/`x`, `/search`, `:%s/old/new/g`, `:w`/`:q`, counts — is in the
cheatsheet's last section; it is what you have if a fix genuinely cannot
wait for `ws`.

## Exercises

1. Delete every line matching `DEBUG` from a 40,000-line log in one
   command. — **Hint:** one ex command covers the whole file regardless of
   its length; you do not scroll to find them. — **Solution sketch:**
   `:g/DEBUG/d` — `:g` scans every line once, `d` deletes each match as it's
   found; 40,000 lines costs the same one keystroke sequence as 40.

2. Append `;` to the end of 12 specific lines using a macro. —
   **Hint:** record the edit on line one with `0` as the first keystroke, so
   replaying it does not depend on where the cursor happened to land. —
   **Solution sketch:** `qa0A;<Esc>q` records "go to column 0, append a
   semicolon at end of line" into register `a`; move to each of the other
   11 lines and `@a`, or `11@a` if they are contiguous and the cursor
   advances a line per replay (e.g. the macro itself ends with `j`).

3. Load every `.conf` under `/etc/nginx` into the argument list and replace
   a value across all of them. — **Hint:** the argument list is not the
   same as "files you have open"; `:args` with a glob populates it in one
   step. — **Solution sketch:** `:args /etc/nginx/**/*.conf` then `:argdo
   %s/old_value/new_value/ge | update` — `**` recurses into subdirectories,
   `e` skips files where the pattern isn't found instead of erroring out of
   the loop, `update` only writes files actually changed.

4. Build a quickfix list from a `grep` for `status=500` and step through
   it. — **Hint:** `:grep` is not `/search` — it populates a persistent,
   navigable list instead of just moving the cursor. — **Solution sketch:**
   `:grep status=500 access.log` (requires `'grepprg'` to be a real `grep`,
   the default), then `:copen` to see every hit, `:cn`/`:cp` to step through
   them one at a time, `:cdo s/status=500/status=502/` to edit every hit in
   one pass if that's the actual task.

5. Sort and dedupe a buffer in place. — **Hint:** you don't need `:%s`, a
   macro, or even nvim's own sort — the shell already has the tool. —
   **Solution sketch:** `:%!sort -u` replaces the buffer with the sorted,
   deduplicated output of piping its own contents through `sort -u`; `:undo`
   recovers the original if the buffer had nothing worth keeping sorted.

6. Save a root-owned file you opened as a non-root user. — **Hint:** `:w`
   alone cannot fix a permission problem — the fix routes the write through
   a different, privileged process instead. — **Solution sketch:** finish
   editing, then `:w !sudo tee % >/dev/null` to pipe the buffer through
   `sudo tee` back onto the same path, then `:e!` to reload the file nvim
   now sees on disk and clear the stale "modified" flag.

## Anti-patterns / Common mistakes

- Mistake 7 (learning vim from a tutorial): a tutorial completed in a
  comfortable terminal with arrow keys still live builds a habit that does
  not survive first contact with a real incident. Today's gauntlet is the
  test of whether the week's arrow-key deprivation actually transferred —
  if fingers still reach for an arrow key under the 15-minute clock, that is
  the signal, not a failure to memorize today's material.
- Mistake 4 (practising on a healthy box): a `:g//` drill against a log file
  with nothing wrong in it teaches recognition of the command, not the
  judgment of when to reach for it. Every exercise above and every gauntlet
  incident starts from an actual injected fault for exactly this reason —
  there is no healthy-box version of today that would teach the same thing.

## Where this shows up in AWS

`aws ecs execute-command` drops you into a shell inside a running task with
no editor you configured, no plugins, often no `$HOME` writable, and
whatever base image the task happens to ship. A 30-line `init.lua` — or,
lacking even that, the busybox `vi` survival subset from the cheatsheet — is
the difference between fixing a misconfigured file in 90 seconds on the box
itself and copying it to a laptop, editing it comfortably, and copying it
back, twice, under the same incident clock. `:g//` and `:argdo` matter for
the identical reason `strace` and `/proc` mattered all week: none of them
depend on a tool that might not be on the box, only on a shell and a file.

## Teardown

See `labs/day07/teardown.md` for the full checklist. In short: run
`verify.sh all` one last time to confirm every incident is actually fixed,
not just diagnosed, then tear the fleet down with `docker compose -p
linuxops down -v --remove-orphans` and confirm with
`labs/verify-teardown.sh` — the same close-out every prior day used.

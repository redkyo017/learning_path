# nvim file operations — open, read, write, update, recover

`nvim-cheatsheet.md` is the editing grammar: what happens *inside* a buffer.
This primer is the file's side of the same session — how a file gets into a
buffer, how the buffer gets back onto disk, what that write does to the
inode, and how to get out of the prompts that appear when either step goes
wrong on a server. Sections mirror `file-ops-reference.md`, so the shell
form and the editor form of each operation sit side by side.

Everything below was run against **NVIM v0.9.5** in `ws`, with the shipped
`init.lua` (which turns `undofile` on and changes no write-related option).
The busybox `vi` notes were run in `slim`. Check `nvim --version` on an
unfamiliar box: option defaults move between releases.

## Open and read

| Task | Command | What you see |
|---|---|---|
| Open at line 30 | `nvim +30 f` | cursor on line 30 |
| Open at the first match | `nvim +/^ERROR f` | cursor on the first line matching `^ERROR` |
| Open read-only | `nvim -R f`, or `view f` (a wrapper for the same thing) | a change warns `W10: Warning: Changing a readonly file`; `:w` refuses with `E45: 'readonly' option is set (add ! to override)` |
| Read a command's output | `journalctl -u x \| nvim -` | a `[No Name]` buffer holding stdin; `:w name` saves it |
| Open without a swap file | `nvim -n f` | no swap file is created — use it on a huge log, a read-only box, or when `$HOME` isn't writable |
| Open with no config at all | `nvim -u NONE f` | factory defaults; rules out your `init.lua` when something behaves oddly |
| Switch to another file | `:e path` | |
| Throw away changes, reload from disk | `:e!` | buffer back to the on-disk content, `modified` cleared |
| See tabs, trailing space | `:set list` | default `listchars=tab:> ,trail:-,nbsp:+` |
| Which line endings did nvim detect? | `:set ff?` | `fileformat=dos` for a pure-CRLF file; a *mixed* file reads as `unix`, with each `\r` left in the buffer |

**A huge log** is a search problem before it is an editing problem. Find the
line from the shell (`grep -n 'req_id=00000777' app.log`), then open straight
to it with `nvim -n +<line> app.log`. `-n` saves writing a swap file for a
buffer you have no intention of changing.

**nvim is not `tail -f`.** A buffer is a snapshot taken at `:e`. When the
file changes on disk, `:checktime` compares them:

- Buffer unchanged → reloaded silently, because `autoread` is on by default.
- Buffer *also* changed → `W12: Warning: File "f" has changed and the buffer
  was changed in Vim as well`, then
  `[O]K, (L)oad File, Load File (a)nd Options`. `L` discards your edits for
  the disk version; `O` keeps your buffer, and a later `:w` stops again at
  `WARNING: The file has been changed since reading it!!!` and asks for
  confirmation before overwriting the other writer's change.

To watch a live log, stay in the shell: `tail -F` (see the reference).

## Search without changing anything

| Task | Command | Result |
|---|---|---|
| Count matches | `:%s/status=500//gn` | `2 matches on 2 lines` — the `n` flag reports and substitutes nothing |
| List matching lines with their numbers | `:g/status=500/#` | each match printed with its line number |
| Search a tree of files | `:vimgrep /listen 80/ conf/**/*.conf`, then `:copen` | a quickfix list of every hit; `:cn`/`:cp` walk it (cheatsheet) |
| Forward search, next, word under cursor | `/pat`, `n`, `*` | cheatsheet |

## Write

| Task | Command | Detail |
|---|---|---|
| Write | `:w` | |
| Write only if modified | `:up` (`:update`) | leaves the mtime alone on an unmodified buffer |
| Write if modified, then quit | `:x` or `ZZ` | same rule as `:up` |
| Always write, then quit | `:wq` | rewrites even an unmodified buffer, bumping the mtime |
| Quit, discarding changes | `:q!` or `ZQ` | |
| Write every modified buffer | `:wa` | |
| Write a copy, keep editing the original | `:w newname` | the buffer is still named after the original |
| Write a copy and switch to it | `:sav newname` | the buffer is now `newname` |
| Write a line range to a new file | `:10,20w part.txt` | onto an existing file: `E13: File exists (add ! to override)`, so `:10,20w! part.txt` |
| Append a range to a file | `:10,20w >> notes.txt` | |
| Pipe the buffer to a command | `:w !wc -c` | the file on disk is **not** written |
| Force past the `readonly` flag | `:w!` | only overrides nvim's flag — the kernel's permission check still applies |
| Save a root-owned file you opened as a user | `:w !sudo tee % >/dev/null`, then `:e!` | cheatsheet |

`:x` versus `:wq` is not trivia. The mtime is what `find -mmin`, `make`,
config watchers, and "what changed recently?" all read, so `:wq` on a file
you only looked at makes it look freshly edited.

## Update

| Task | Command | Detail |
|---|---|---|
| Insert another file below the cursor line | `:r other.conf` | `:0r other.conf` inserts above line 1 |
| Insert a command's output | `:r !date` | |
| Filter the whole buffer through a command | `:%!sort -u` | cheatsheet |
| Convert CRLF to LF | `:set ff=unix`, then `:w` | for a file nvim detected as `dos` |
| Strip stray `\r` from a mixed file | `:%s/\r$//e` | the `e` flag suppresses "pattern not found" |
| Strip trailing whitespace | `:%s/\s\+$//e` | |
| Tabs to spaces (per `expandtab`/`tabstop`) | `:set expandtab`, then `:retab` | |
| Preserve a missing final newline | `:set nofixeol` before `:w` | the default, `fixendofline`, adds one on write; `nofixeol` writes `[noeol]` |
| Go back to how the file was one write ago | `:earlier 1f` | `:later 1f` forward; time forms such as `:earlier 10m` also exist |

`undofile` is on in `ws`, so undo history survives quitting: `:earlier 1f`
in a brand-new session still steps back past the last write. The history is
stored under `~/.local/state/nvim/undo/`, one file per edited path, with the
path encoded as the name (`%etc%hosts`). That is a copy of every change you
made — secrets included — sitting in the editing user's home directory.

## How `:w` lands on disk

This is Day 3's *A write lands on one of two inodes*, seen from inside the
editor. Five options decide it; nvim 0.9.5's defaults are:

```
backupcopy=auto  writebackup  nobackup  backupskip=/tmp/*  backupdir=.,~/.local/state/nvim/backup//
```

`writebackup` means nvim keeps a backup of the old content until the write
succeeds, then deletes it; `backupcopy` decides whether that backup is made
by **renaming** the original (the new file is then a new inode) or by
**copying** it (the original inode is then overwritten in place). Traced
with `strace` in `ws`:

| Situation | What `:w` did | Inode |
|---|---|---|
| Ordinary file, one link, outside `/tmp`, defaults | `renameat(f, f~)`, `openat(f, O_CREAT\|O_TRUNC)`, `unlink(f~)` | **new** — a descriptor held on the old file now reads `f~ (deleted)` and the old content |
| File with a second hard link | copies `f` to `f~`, `openat(f, O_TRUNC)` | same — both names show the edit |
| Opened through a symlink | writes the target | same — the link stays a link |
| Bind-mounted file (`/etc/hosts` in a container) | `renameat` → `EBUSY`, falls back to copy, `openat(O_TRUNC)` | same — **the write succeeds**, unlike `sed -i` |
| Any file under `/tmp` | no backup at all (`backupskip`), `openat(O_TRUNC)` | same |
| Directory not writable, file writable | backup to `f~` fails `EACCES`, retries in `~/.local/state/nvim/backup/`, `openat(O_TRUNC)` | same — succeeds, where `sed -i` fails |
| `:set backupcopy=yes` | copies, then `O_TRUNC` | same, always |
| `:set backupcopy=no` | renames when it can; still falls back for bind mounts | new where possible |

Two practical rules fall out of that table:

- **When a running process holds the file open and must see your edit** —
  a `tail -f`, anything that reads through a descriptor it opened earlier —
  `:set backupcopy=yes` before `:w`. The default renames the file out from
  under it.
- **Never test this under `/tmp`.** `backupskip=/tmp/*` makes every write
  there in-place, so a demonstration in `/tmp` shows the opposite of what
  happens to the same file in `/etc` or `/srv`.

Prove it the same way as for any shell write — pin the old inode first:

```sh
exec 3< /srv/app/app.conf
nvim /srv/app/app.conf          # edit, :wq
ls -l /proc/$$/fd/3             # "app.conf~ (deleted)" = renamed; plain path = in place
exec 3<&-
```

Busybox `vi` has no backup options: it writes into the existing inode. In
`slim` a hard-linked file kept both names in sync after `:wq`, and the
bind-mounted `/etc/hosts` saved without complaint.

## When opening or writing fails

**`E325: ATTENTION` — a swap file already exists.** nvim keeps unsaved
changes in a swap file under `~/.local/state/nvim/swap/`, named after the
full path (`%srv%app%app.conf.swp`) — not next to the file as classic Vim
does. The prompt block tells you which case you are in:

- `process ID: 857 (STILL RUNNING)` → a process with that PID exists. The
  choices are `[O]pen Read-Only, (E)dit anyway, (R)ecover, (Q)uit, (A)bort`.
  Before choosing, look at it: `ps -o pid,ppid,stat,args -p 857`.
  - A live `nvim --embed …` → another session is editing this file right
    now. Choose `O` or `Q` and go find that session; `E` produces two
    diverging copies.
  - `Z` with parent `1` → nobody is editing; it is a zombie. nvim 0.9.5 in
    a terminal runs as two processes, a UI `nvim` and its `nvim --embed`
    child, and the swap file records the **child's** PID. Kill the session
    and that child is orphaned to PID 1; in a container whose PID 1 is not
    an init — `ws` runs `sleep infinity` — it is never reaped (Day 2), the
    PID stays taken, and nvim's liveness check passes. `(D)elete it` is
    never offered. Recover with `R` and `:w` as below, then remove the
    swap file yourself: `rm ~/.local/state/nvim/swap/%srv%app%app.conf.swp`.
- A process ID with no `(STILL RUNNING)` → that session died. If the block
  also says `modified: YES`, the swap holds edits that never reached disk.
  The choices now add `(D)elete it`.
  1. `R` — the buffer gets the recovered edits: `Recovery completed. You
     should check if everything is OK.`
  2. Check it, then `:w`. nvim reminds you:
     `You may want to delete the .swp file now.`
  3. Quit, reopen, and choose `D` at the same prompt. Choosing `D` *before*
     recovering deletes the unsaved edits for good.

`nvim -r` with no file lists every swap file with its owner, original path,
`modified` flag, and process ID — the inventory to read after a box reboot
or a killed SSH session.

Because the swap directory lives under the **editing user's** home, E325
only protects a user from themselves. Root and an application user editing
the same file at the same moment each get their own swap file and no
warning.

**`$HOME` is not writable.** Common in an `aws ecs execute-command` shell,
and it breaks two things nvim keeps under `~/.local/state/nvim/`:

- The swap file: `E303: Unable to open swap file for "cfg", recovery
  impossible`. Editing continues without one. `nvim -n` skips the swap file
  and the message with it — and crash recovery too, so write early.
- The backup, if the file's own directory isn't writable either: `:w` tries
  `cfg~` beside the file, then the state directory, and stops at
  `E509: Cannot create backup file (add ! to override)` **without writing
  anything**. `:w!` writes anyway (still reporting the backup `E303`), or
  `:set nowritebackup` first and plain `:w` works. If the directory *is*
  writable, the backup lands there and `:w` just works.

`E886: Failed to create directory … for writing ShaDa file` on quit is the
same unwritable `$HOME` refusing nvim's history file; the edit is already
on disk by then.

**`E212: Can't open file for writing: read-only file system`.** In `ws`,
`/labs` is mounted read-only. nvim opens files there with the `readonly`
flag already set, so the first message is `E45`; `:w!` gets past nvim's
flag and hits the kernel, which answers `EROFS`. The proof is Day 1's —
`grep ' /labs ' /proc/mounts` shows `ro` — and no nvim option changes it.

**`E45` on a file you expected to be able to edit.** nvim set `readonly`
because your user can't write the file. `:w!` only gets as far as the
kernel — `E212: Can't open file for writing: permission denied` — so this is
Day 5's permission model, or `:w !sudo tee %` where `sudo` exists.

## Busybox `vi`, the file-lifecycle subset

What worked in `slim`: `:w`, `:wq`, `:x`, `:q`, `:q!`, `:e!` (reload,
discarding edits), `:r file` (insert a file below the cursor), and
`:3,4w part` (write a range to a new file). What did **not**: `:3,4w >> f`
left the target unchanged; `:sav` is misread as `:s` (`expression missing
delimiters`); `:set ff=unix` gives `bad option: ff=unix`; `:vimgrep` gives
`'vimgrep' is not implemented`. No swap file appears while editing, so there
is no E325 and nothing to recover after a crash. Strip CRLF from the shell
before opening — `sed -i 's/\r$//' f` works in busybox `sed` too. Every
`:w` writes in place.

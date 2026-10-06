# nvimfile — solutions

Each section: the interactive keystrokes, the headless one-liner that was run to prove it (`nvim --headless -c '...' -c wq file`, run in `ws`), and why it works. Drills are in [README.md](README.md).

## Drill 1
Interactive: `nvim -R +/ERROR app.log`, `:s/ERROR/RESOLVED/`, `:w!`, `:q`.
Proven: `nvim --headless -R +/ERROR -c 's/ERROR/RESOLVED/' -c 'w!' -c q app.log`.
Why: `+/pat` runs a search at startup, so the cursor sits on the first matching line (an ex `:s` on that line does not depend on which column the cursor landed in). `-R` sets `readonly`; `:w` answers `E45`, `:w!` overrides nvim's flag only. As root the kernel permits it, the 444 mode is left alone. `:e!` re-reads the file and drops the buffer's changes without touching the disk.

## Drill 2
`:s/80/8080/`, `:w staging.conf`, `:s/8080/9090/`, `:saveas prod.conf`, `Go# reviewed<Esc>`, `:wq`.
Proven: `nvim --headless base.conf -c 's/80/8080/' -c 'w staging.conf' -c 's/8080/9090/' -c 'saveas prod.conf' -c 'exe "normal! Go# reviewed"' -c wq`.
Why: `:w name` writes a copy and the buffer keeps its name (and stays modified); `:saveas name` writes and renames the buffer, so the final `:wq` writes `prod.conf`. `base.conf` is never written.

## Drill 3
`nvim +10 app.log`, then `:10,14w part.txt`, `:1w >> summary.txt`, `:g/ERROR/.w >> summary.txt`, `:q`.
Proven: `nvim --headless +10 app.log -c '10,14w part.txt' -c '1w >> summary.txt' -c 'g/ERROR/.w >> summary.txt' -c q`.
Why: the trap is `:g/ERROR/w >> summary.txt`: `:w` without a range writes the whole buffer, once per matching line (live run: `summary.txt` grew to 30 lines four times). Under `:g` the current line is `.`, so `.w >> f` appends just the match.

## Drill 4
`/INCLUDE HERE`, `:r snippet.conf`, `:0r !hostname`, `:wq`.
Proven: `nvim --headless site.conf -c '/INCLUDE HERE/r snippet.conf' -c '0r !hostname' -c wq`.
Why: `:r` inserts below the addressed line (`/INCLUDE HERE/r` addresses by search); `:0r` inserts above line 1. Do the marker first: the `0r` shifts every line number down by one.

## Drill 5
`names.txt`: `:2,$!sort -u`, `:wq`. `cfg.json`: `2GV` then `:` (the prompt shows `:'<,'>`), `!jq .`, Enter, `:wq`.
Proven: `nvim --headless names.txt -c '2,$!sort -u' -c wq` and `nvim --headless cfg.json -c 'exe "normal! 2GV\<Esc>"' -c "'<,'>!jq ." -c wq`.
Why: `:{range}!cmd` (a visual selection is the range `'<,'>`, which is how the comment line stays out of jq's way); feeds the lines to the command and replaces them with its output; leaving line 1 out of the range is how the header stays on top.

## Drill 6
`nvim conf/*.conf`, `:argdo %s/listen 80;/listen 8080;/e | update`, `:qa`.
Proven: `nvim --headless -c 'args conf/*.conf' -c 'argdo %s/listen 80;/listen 8080;/e | update' -c qa`.
Why: `e` keeps `:argdo` going over files without a match (otherwise `E486` aborts it at `c.conf`); `update` writes only modified buffers, so `c.conf` and `e.conf` keep their mtime. `:wq` or `:wa` would have rewritten all five, and the check would see the new mtime. Note `d.conf` has a comment containing `listen 80;`, which also changes: the substitute is on text, not meaning.

## Drill 7
```sh
cd /srv/nvimfile-d07 && su ubuntu
nvim /srv/nvimfile-d07/app.conf     # :%s/100/500/   then :w fails (E45)
:w !sudo tee % >/dev/null           # W12 prompt: press L (or :e! if you pressed O/Enter), then :q
```
Proven (as root, dropping to ubuntu): `runuser -u ubuntu -- nvim --headless /srv/nvimfile-d07/app.conf -c '%s/100/500/' -c 'w !sudo tee % >/dev/null' -c 'q!'`. The sudo log recorded `ubuntu : USER=root ; COMMAND=/usr/bin/tee app.conf`, owner and mode stayed `root:root 644`.
Why: `:w !cmd` sends the buffer to `cmd`'s stdin and writes nothing itself; `sudo tee %` writes it to the file as root, in place (same inode, same owner, same mode). tee also echoes to stdout, hence `>/dev/null`. nvim then sees the file changed under it (`W12 ... [O]K, (L)oad File`): `L`, or `:e!`, reloads. Without sudo you would use `su -c` or `doas` the same way.

## Drill 8
```sh
exec 3< conf
nvim conf        # :%s/mode=a/mode=b/  :wq
ls -l /proc/$$/fd/3      # .../conf~ (deleted)
cat /proc/$$/fd/3        # mode=a: the old inode
exec 3<&-
nvim shared      # same edit, :wq
cat shared.link          # mode=b
printf 'renamed\nyes\n' > answers.txt
```
Proven live: fd 3 printed `/root/practice/nvimfile/d08/conf~ (deleted)`; `shared.link` showed `mode=b`.
The setup holds `conf` open on fd 3 in a background process (`holder.pid`), so the check can read it back: `conf~ (deleted)` with the old content proves the rename; a `sed -i` would show `conf (deleted)` instead. The hard link is checked with `[ shared -ef shared.link ]` and link count 2.
Why: with `backupcopy=auto` and `writebackup`, nvim renames the original to `conf~`, writes a new `conf`, deletes the backup: a new inode, the pinned fd still holds the old one. A file with two links is *copied* to the backup and rewritten in place, so both names show the edit. Pinning with an fd (or a link) is what makes this provable; bare `stat -c %i` numbers get reused.

## Drill 9
`nvim live.conf`, `:set backupcopy=yes`, `:%s/info/debug/`, `:wq`.
Proven: `nvim --headless live.conf -c 'set backupcopy=yes' -c '%s/info/debug/' -c wq`, then `cat /proc/$(cat holder.pid)/fd/3` shows `level=debug`.
Why: with default options the write replaces the inode and the holder keeps reading the deleted old one. `backupcopy=yes` makes the backup a copy and truncates and rewrites the original inode, so every holder of that inode sees the edit. (The same thing happens to a daemon that reads its config through a descriptor it opened at start; most daemons re-open on reload, which is why this rarely bites.)

## Drill 10
```sh
nvim -r                                   # lists the swap and a (STILL RUNNING) pid
ps -o pid,ppid,stat,args -p <pid>         # Z, ppid 1: zombie nvim --embed
nvim /root/practice/nvimfile/d10/notes.txt   # E325: press R, check, :w, :q
rm ~/.local/state/nvim/swap/%root%practice%nvimfile%d10%notes.txt.swp
```
(`nvim -n notes.txt` then `:recover` also works and skips the prompt.)
Proven: `setup.sh 10` reproduces the real thing (a terminal nvim under `script`, `:preserve`, `kill -9` of the UI; its `--embed` child is orphaned to `sleep infinity` as PID 1 and shows `STILL RUNNING` in `nvim -r`). Recovery was run headless: `nvim --headless -r notes.txt -c w -c q` printed `Recovery completed` and `Note: process STILL RUNNING`, then `notes.txt` had the 4th line; the swap was removed with `rm`. The interactive `E325` prompt and its choices are as recorded in the primer.
Why: the swap holds the edits that never reached disk; `R` loads them, `:w` makes them real. Because a zombie keeps the PID "alive", nvim never offers `D`, so you remove the swap file yourself, after recovering.

## Drill 11
`:set ff?` shows `dos`; `:set ff=unix`, `:wq`.
Proven: `nvim --headless crlf.conf -c 'set ff=unix' -c wq`; `check.sh 11` PASS (no CR bytes, content intact).
Why: nvim strips the CRs on read for a pure-CRLF file and re-adds them on write according to `fileformat`; changing the option changes what is written.

## Drill 12
```sh
# in slim
cd /root/practice/nvimfile/d12
sed -i 's/\r$//' win.conf
vi win.conf          # :3,4w! part   :q   (part exists from your first try)
rm './>> out.txt'    # the stray file from `:3,4w >> out.txt`
cat part >> out.txt
```
Proven in `slim`: `sed -i 's/\r$//'` strips CRs; `vi -c '3,4w! part' win.conf` wrote `gamma`/`delta` (busybox `vi` takes `-c`, then complains `can't read user input` without a terminal, expected); `vi -c '3,4w >> out.txt' …` left `out.txt` unchanged and created a file literally named `>> out.txt` (removed with `rm './>> out.txt'`); `cat part >> out.txt` finished the job. `:set ff=unix` giving `bad option` was taken from the primer's verified notes (it needs a terminal to type it).
Why: busybox `vi` implements `:w`, ranged `:N,Mw newfile`, `:r`, `:e!`, but not `ff`, not `:w >>`, not swap or backup files. The shell fills each gap.

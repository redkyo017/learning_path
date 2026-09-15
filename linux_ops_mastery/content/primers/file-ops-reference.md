# File operations reference — read, search, write, update

Read this when you know *what* you want to do to a file and need the form
that works on the box in front of you. It is a lookup table, not a drill
(Mistake 1): the model it hangs off is Day 1's inode-versus-name split and
Day 3's *A write lands on one of two inodes*. Every row was run in this
fleet — `ws` is Ubuntu 24.04 with GNU sed 4.9, GNU grep 3.11, and mawk;
`app` and `slim` are Alpine with BusyBox 1.36. Where the two differ, both
forms are given; where a busybox cell says *absent*, the flag or command
genuinely isn't there.

The last column of each write table is the one that matters under incident
pressure: **same** means the existing inode is modified (descriptor holders
see it, not atomic, bind mounts and hard links survive); **new** means a
different inode takes the name (descriptor holders keep the old content,
atomic within one filesystem, fails on a bind-mounted file). To prove which
one happened, pin the old inode across the write — `exec 3< f`, write,
`ls -l /proc/$$/fd/3` — because a bare `stat -c %i` comparison can be
fooled by inode-number reuse.

The nvim equivalents of every section live in `nvim-file-ops.md`.

## Read

| Task | `ws` (GNU) | `slim`/`app` (busybox) | Note |
|---|---|---|---|
| Show invisible bytes (CRLF, tabs, trailing space) | `cat -A f` | `cat -A f` | CRLF prints as `^M$`, tab as `^I` |
| Byte-exact dump | `od -c f` | `od -c f` | `\r \n` is a CRLF line ending |
| Guess a file's type | `file f` | *absent* | `ASCII text, with CRLF, LF line terminators` names mixed endings |
| First N bytes / lines | `head -c 3 f`, `head -n 20 f` | same | |
| A line range | `sed -n '100,120p' f` | same | Day 3's range form |
| Follow a growing log | `tail -f f` | same | follows the **descriptor**: after a rename-based rotation it stays on the old inode and prints nothing new |
| Follow a log across rotation | `tail -F f` | same | follows the **name**: prints `'f' has been replaced; following new file` (GNU) and reopens. In this fleet GNU `tail` needed more than three seconds to notice; busybox caught it within two |
| Read a rotated `.gz` log | `gzip -dc f.gz` or `zcat f.gz` | same | leaves the `.gz` untouched |
| Compress but keep the original | `gzip -k f` | same | |
| List an archive | `tar tzf a.tgz` | same | |
| Print one member of an archive | `tar xzOf a.tgz path/in/archive` | same | `-O` writes to stdout, extracts nothing |
| Read a deleted-but-open file | `cat /proc/PID/fd/N` | same | Day 3's recovery path |

## Search

| Task | `ws` (GNU) | `slim`/`app` (busybox) |
|---|---|---|
| Recursive, with line numbers | `grep -rn 'pat' dir` | same |
| Only names of files that match / don't | `grep -rl 'pat' dir` / `grep -rL 'pat' dir` | same |
| Only the matched part | `grep -o 'status=[0-9]*' f` | same |
| Extended regex / whole word / literal | `grep -E 'a\|b'` / `grep -w 500` / `grep -F 'a.b'` | same |
| Recurse into some file types only | `grep -rn --include='*.conf' 'pat' dir` | *absent* — `find dir -type f -name '*.conf' -exec grep -n 'pat' {} +` |
| Matching names, NUL-delimited, into another command | `grep -rlZ 'pat' dir \| xargs -0 cmd` | *no `-Z`* — `find dir -type f -print0 \| xargs -0 grep -l 'pat'` |
| Search a compressed log | `zgrep 'pat' f.gz` | *absent* — `gzip -dc f.gz \| grep 'pat'` |
| Changed in the last hour | `find dir -mmin -60` | same |
| Older than 24 hours | `find dir -mtime +0` | same |
| Newer than a reference file | `find dir -newer ref` | same |
| Bigger than 1 MiB | `find dir -size +1024k` (`+1M` also works) | `find dir -size +1024k` — `+1M` fails with `invalid number '1M'` |
| Empty files | `find dir -type f -empty` | same |
| Stay on one filesystem | `find / -xdev ...` | same |

`-exec cmd {} +` and `-print0 | xargs -0` both batch many names into one
invocation and both survive spaces in filenames; `-exec cmd {} \;` forks
once per file (Day 3). The `find` time tests are the concrete form of Day
1's "`/var` is where you look for what changed recently."

## Write and create

| Task | Form (both, unless noted) | Inode |
|---|---|---|
| Replace contents | `printf '%s\n' "$v" > f` | same |
| Append | `printf '%s\n' "$v" >> f`, or `… \| tee -a f >/dev/null` | same |
| Empty a file without removing it | `: > f` or `truncate -s 0 f` | same |
| Multi-line literal text | `cat > f <<'EOF'` … `EOF` — quoted delimiter, so `$V` stays literal | same |
| Multi-line text with variables expanded | `cat > f <<EOF` … `EOF` | same |
| Indented heredoc | `<<-EOF` strips leading **tabs** only, never spaces | same |
| Temp file on the target's filesystem | `t=$(mktemp ./cfg.XXXXXX)` | n/a |
| Atomic replace | `… > "$t" && mv "$t" f` | new |
| Install with a mode in one step | `install -m 0644 src f` | new |
| Copy, keeping mode and mtime | `cp -a src dst` — plain `cp` resets the mtime to now | GNU onto existing: same; busybox: new |
| Sort a file into itself | `sort -o f f` — never `sort f > f`, which empties `f` first | same |

**Redirection is opened by the shell that parses it, with that shell's
identity.** As `nobody` on `ws`, `sh -c 'echo x > /etc/probe-root'` fails
with `cannot create /etc/probe-root: Permission denied` before `echo` runs.
The same rule is why `sudo echo x > /etc/f` fails for a non-root user — the
unprivileged shell opens `/etc/f`, not `sudo` — and why the working form puts
the privileged process on the writing end: `echo x | sudo tee /etc/f >/dev/null`.
(`ws` ships no `sudo`; the `nobody` case above is the same mechanism with
nothing borrowed.)

## Update and replace

Dry-run first, always — on a real box the pattern that matched the one line
you meant usually also matches two you didn't:

```sh
grep -rn 'listen 80' /etc/nginx          # where are the hits?
sed -n 's/listen 80/listen 8080/p' f     # print only the lines that would change
```

| Task | `ws` (GNU) | `slim`/`app` (busybox) | Inode |
|---|---|---|---|
| Substitute in place | `sed -i 's/old/new/' f` | same | new |
| … keeping a backup | `sed -i.bak 's/old/new/' f` (suffix attached, no space) | same | new |
| Paths in the pattern | `sed -i 's\|/old/path\|/new/path\|' f` — any delimiter works | same | new |
| Append a line after a match | `sed -i '/^\[main\]/a key=value' f` | same | new |
| Insert a line before a match | `sed -i '/^\[main\]/i ; comment' f` | same | new |
| Delete matching lines | `sed -i '/^#/d' f` | same | new |
| Edit through a symlink, keeping the link | `sed -i --follow-symlinks 's/a/b/' link` | *absent* — edit the target path | new (target) |
| Same substitution across many files | `grep -rlZ 'old' dir \| xargs -0 sed -i 's/old/new/'` | `find dir -type f -name '*.conf' -exec sed -i 's/old/new/' {} +` | new |
| Edit with awk | `awk '…' f > f.tmp && mv f.tmp f` — mawk has no `-i inplace` (`awk: not an option: -i`) | same; busybox awk has no `-i` either | new |
| Edit a bind-mounted or hard-linked file | `sed 's/old/new/' f > /tmp/f.new && cat /tmp/f.new > f` | same | same |
| Review the change | `diff -u f.bak f` (exit 1 = differ) | same | n/a |
| Just "are they identical?" | `cmp a b` (exit 0 = identical) | same | n/a |

`sed -i` also needs write permission on the **directory**, because it
creates its temp file there: `sed: couldn't open temporary file
lk/sedekqLxH: Permission denied` for a user who can write `lk/cfg` but not
`lk/`. The same-inode form (`… > /tmp/f.new && cat /tmp/f.new > f`) needs
only the file's own write bit.

## Copy, move, delete

| Operation | What happens | Inode |
|---|---|---|
| `mv a b`, same filesystem | one `rename(2)`; atomic; `b` takes `a`'s inode | new for `b` |
| `mv a b`, across filesystems | `renameat2` returns `EXDEV (Invalid cross-device link)`; `mv` copies, then unlinks `a` — not atomic | new |
| GNU `cp a b`, `b` exists | truncates `b` and copies bytes in | same |
| busybox `cp a b`, `b` exists | replaces `b` — a holder of the old `b` sees `(deleted)`; onto a bind-mounted file fails with `can't create '…': File exists` | new |
| Replace a **running** binary with GNU `cp` | `cp: cannot create regular file './sleep': Text file busy` | — |
| Replace a running binary with `mv` | succeeds; the running process's `/proc/PID/exe` now reads `… (deleted)` | new |
| `rm f` | removes one name; blocks free only at link count 0 **and** no open descriptor | Day 1 |

## Quick decision

- Config that a service reads by name → temp file in the same directory,
  then `mv`.
- `/etc/hosts`, `/etc/resolv.conf`, `/etc/hostname` inside a container, or
  any file mounted with `-v host:container` → write in place.
- A file something holds open that must see the change → write in place.
- Output going back onto its own input → `-o`, or a temp file — never `>`.

# fileops — solutions

Read a section only after you have tried the drill. Every command runs in the `ws` bash shell, in the drill's directory `/root/practice/fileops/dNN`, unless marked. Each solution here was applied live and `check.sh` went from FAIL to PASS.

## Drill 1

```sh
sed -n '40,42p' app.log > ans1.txt
tail -n 2 app.log > ans2.txt
wc -l < app.log > ans3.txt
stat -c '%a %h' app.log > ans4.txt
grep -n ERROR app.log | head -n 2 > ans5.txt
file -b app.log > ans6.txt
```

Why: `wc -l file` prints the name, `wc -l < file` does not, because `wc` never learns the name. The link count is 2 because `app.log.keep` is another name for the same inode. `grep -n` prefixes each hit with its line number and `head -n 2` keeps the first two. `file -b` prints the type without the filename prefix.

## Drill 2

```sh
grep -rl timeout logs | sort > ans1.txt
grep -c timeout logs/web.log > ans2.txt
grep -v '^#' conf.txt | grep -v '^$' > ans3.txt
```

Why: `-l` lists names, `-c` counts matching lines (not matches), `-v` inverts. The two `-v` passes remove comments, then blanks.

## Drill 3

```sh
grep -E ' 5[0-9]{2}$' access.log > ans1.txt
zgrep -c POST old.log.gz > ans2.txt
```

Why: the `$` anchors the status to the end of the line, so the path `/v500` does not count. `zgrep` reads the compressed file without writing a decompressed copy.

## Drill 4

```sh
find tree -name '*.tmp' -size +1k -print0 | xargs -0 rm --
```

Why: NUL (`-print0` / `-0`) is the one byte a file name cannot contain, so `big name.tmp` stays one argument. Dry-run by replacing `xargs -0 rm --` with `xargs -0 ls -l`.

## Drill 5

```sh
find tree -name '*.conf' -newer ref.stamp | sort > found.txt
find tree -type f -mtime -7 | sort > found2.txt
```

Why: `-newer` compares mtimes with another file; `-mtime -7` means modified less than 7 days ago. Piping into `sort` is safe because nothing splits the names.

## Drill 6

```sh
echo one > notes.txt
echo two >> notes.txt
echo three | tee -a notes.txt >/dev/null
cat >> notes.txt <<'EOF'
four
five
EOF
t=$(mktemp -p .); echo scratch > "$t"
```

Why: `>` truncates, `>>` appends, `tee -a` appends from a pipe. `mktemp -p .` makes a unique file in the current directory, not in `/tmp` (see the primer on keeping the temp file on the target's filesystem).

## Drill 7

```sh
sed -n 's/^timeout=30$/timeout=60/p' server.conf
sed -i.bak 's/^timeout=30$/timeout=60/' server.conf
```

Why: the `-n ... p` form prints only what would change, so a pattern that matches too much shows up before it does damage. `-i.bak` keeps the original.

## Drill 8

```sh
sed -n -E 's/^([0-9]{4})-([0-9]{2})-([0-9]{2})/\3\/\2\/\1/p' dates.txt   # dry-run
sed -i -E 's/^([0-9]{4})-([0-9]{2})-([0-9]{2})/\3\/\2\/\1/' dates.txt
```

Why: `\1 \2 \3` are the captured year, month, day. `^` stops the mid-line date from matching. With `|` as delimiter you would not need the escaped slashes: `s|^(...)-(...)-(...)|\3/\2/\1|`.

## Drill 9

```sh
awk -F, -v OFS=, '$1=="bob"{$3="disabled"}1' users.csv > users.csv.new && mv users.csv.new users.csv
```

Why: `-F,` splits input on commas and `OFS=,` joins output with commas (without it the output is space-separated). The final `1` prints every line. `mv` on the same filesystem is a `rename`: `users.csv` gets the new inode and `users.snapshot` still holds the old one, so a reader sees the whole old file or the whole new one, never half.

## Drill 10

```sh
cp -a src copy
cp --backup=numbered new.conf deploy/app.conf
```

Why: `-a` is recursive and preserves mode, times and symlinks as symlinks. `--backup=numbered` renames the file it is about to overwrite to `app.conf.~1~`.

## Drill 11

```sh
rm -- -oops.txt          # or: rm ./-oops.txt
rm "my report.txt"
mv report.txt archive/
```

Why: `rm -oops.txt` fails with an invalid-option error; `--` ends options. `mv` on one filesystem is a rename, so the inode does not change and `report.anchor` still names the same file as `archive/report.txt`. A `cp` then `rm` would create a new inode and the check would fail.

## Drill 12

```sh
echo new > w1
sed -i 's/old/new/' w2
cp new.txt w3
mv new4 w4
install new.txt w5
printf 'w1\nw3\n' > ans.txt
```

Why: `>` and GNU `cp` open the existing inode and overwrite it, so `w1.pin` and `w3.pin` show `new`. `sed -i`, `mv` and `install` build another file and put it under the name, so `w2`, `w4`, `w5` are new inodes and their pins keep `old`. Details: `content/day03.md`, "A write lands on one of two inodes".

## Drill 13

```sh
sort -u hosts.txt -o hosts.txt
```

Why: with `sort -u hosts.txt > hosts.txt`, the shell opens and empties `hosts.txt` before `sort` starts, so `sort` reads nothing. `-o` makes `sort` read all input first and open the output after, in place, so the inode (and `hosts.pin`) are kept. `sort -u hosts.txt > t && mv t hosts.txt` also works but gives a new inode and fails the check on purpose.

## Drill 14

```sh
sed -i 's/mode=old/mode=new/' app.conf
```

Why: `sed -i` writes a new file and renames it over `app.conf`; the other name keeps the old inode and the old content. Using `>` or GNU `cp` here would change both names, which is the right thing in drill 13 and the wrong thing here.

## Drill 15

```sh
chmod a+x deploy.sh              # 644 -> 755; a bare +x would follow the umask
chmod 600 secret.conf
( umask 077; touch private.txt; mkdir private.d )
install -m 0640 -D src.txt etc/app/app.conf
```

Why: `a+x` adds execute for everyone (a bare `+x` with no who follows the umask: under 077 it gives 744, under 022 it gives 755); octal sets all nine bits exactly. The subshell scopes the umask: a new file gets `666 & ~077` = 600 (the 077 bits cleared), a directory `777 & ~077` = 700. `install -D` creates `etc/app/`; `-m` sets the mode at creation.

## Drill 16

In `slim` (busybox `sh`):

```sh
cd /root/practice/fileops/d16
exec 3<dst; cp src dst; cat dst dst.pin   # new, then old
ls -l /proc/$$/fd/3                        # .../d16/dst (deleted)
cat <&3                                    # old
```

In `ws`:

```sh
cd /root/practice/fileops/d16 && cp src dst && cat dst dst.pin     # new, then new
printf 'busybox: replaced\ngnu: in-place\nbusybox fd3: deleted\n' > ans.txt
```

Why: GNU `cp` onto an existing file truncates and writes into the same inode, so the hard link sees the new bytes. busybox `cp` replaces the file; `dst.pin` keeps the old inode. The pinned descriptor proves it: after a busybox `cp`, `/proc/$$/fd/3` points at `dst (deleted)` and still reads `old`; with GNU `cp` it points at the live `dst` and reads `new`.

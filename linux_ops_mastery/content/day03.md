# Day 3 — The File Descriptor Table

**Truth of the day:** fd table
**Budget:** 3 h — 1.5 h fd table, redirection, and where a write lands, 1.5 h shell triage toolkit

**At a glance — how to work through this day:**
1. Read "Why this matters" → "Read the file first" → "Derive the tool" →
   "Core concepts".
2. Do the Lab: `labs/day03/` — `break.sh` → write `journal.md` → `verify.sh`
   → then "Strip the toolbox" below.
3. Optional, standalone: "Exercises" — conceptual, don't depend on the
   Lab's incident, do them whenever (see `STRATEGY.md`, "Where Exercises
   fit").
4. Read "Anti-patterns / Common mistakes" → "Where this shows up in AWS".
5. Teardown: `labs/day03/teardown.md`.

## Why this matters

A process's file descriptor table is the kernel's answer to "what does this
program actually have open right now" — every regular file, every socket,
every pipe, every log it writes to. Two failures live entirely in this
table and nowhere else: a log rotation that "worked" (the old name is gone)
but disk usage never drops, because a reader kept its fd on the unlinked
inode; and a genuine incident buried in hundreds of thousands of log lines,
findable in seconds with the right five-command pipeline and invisible to
anyone scrolling a file in an editor. Both are today's lab, in one
incident.

## Read the file first

`ls -l /proc/PID/fd` lists one entry per open descriptor, and every entry
is a symlink. Read the target, not just the number:

```
$ ls -l /proc/4211/fd
lrwx------ 1 app app 64 09:00 0 -> /dev/pts/0
lrwx------ 1 app app 64 09:00 1 -> /dev/pts/0
lrwx------ 1 app app 64 09:00 2 -> /dev/pts/0
lr-x------ 1 app app 64 09:00 3 -> /var/log/app.log.1 (deleted)
lrwx------ 1 app app 64 09:00 4 -> socket:[884213]
lrwx------ 1 app app 64 09:00 5 -> pipe:[884290]
lrwx------ 1 app app 64 09:00 6 -> anon_inode:[eventpoll]
```

Every kind of thing a descriptor can point at shows up in that target:
a regular path, a path suffixed `(deleted)` — the name was unlinked but
the inode is still open, Day 1's exact discovery repeated here — a socket
(`socket:[inode]`, which is the join key into `/proc/net/tcp`; see
`content/primers/proc-field-reference.md#procnettcp` for the byte-order
decode, not repeated here), a pipe (`pipe:[inode]`), or an `anon_inode`
for a kernel object with no filesystem presence at all (`eventpoll`,
`eventfd`, `timerfd`).

`cat /proc/PID/fdinfo/N` goes one level deeper than the symlink, for a
single descriptor:

```
$ cat /proc/4211/fdinfo/3
pos:    7823104
flags:  0100000
mnt_id: 27
```

`pos` is the byte offset the next read or write will happen at — the same
offset `lseek(2)` reports. `flags` is the octal `open(2)` flags word
(low bits are the access mode: `01` write-only, `02` read-write, `00`
read-only; higher bits add `O_APPEND`, `O_NONBLOCK`, and friends — `0100000`
above decodes as plain `O_RDONLY`, matching a `tail -f` that only reads).
On a `(deleted)` target, `pos` tells you how much of the vanished file
the holder has actually consumed: a `tail -f` that caught up to
end-of-file before the name was removed sits with `pos` at the file's
size and stays there, because nothing appends to an unlinked inode any
more. What keeps the blocks allocated does not depend on `pos` moving at
all — it is the open file description itself: the kernel frees an
inode's blocks only once both its link count and its open-file-description
count reach zero, and this fd is one more reference holding that count
above zero. That is exactly the evidence a `df`/`du` mismatch cannot
supply by itself: `du` cannot walk to an unlinked inode at all, so it
never sees these bytes, while `df` counts every block the filesystem
still has allocated, named or not.

## Derive the tool

`lsof -p PID` is `ls -l /proc/PID/fd` plus `readlink` plus a lookup of each
inode's type, printed as columns: `FD` is the entry name, `TYPE` is
`REG`/`sock`/`FIFO`/`unix` decoded from the same symlink target above, and
`NAME` is the resolved path — with `(deleted)` carried through verbatim.
Prove it on `ws`, which actually has `lsof`:

```
ws$ sleep 300 & pid=$!
ws$ lsof -p "$pid"
ws$ ls -l /proc/$pid/fd
```

The `FD` column tells you which of two different things you are looking
at. The numbered rows (`0u`, `1u`, `2u`, and so on) are exactly the
entries in `ls -l /proc/$pid/fd` above, one per line — the trailing
letter (`r`/`w`/`u`) restates the access mode `fdinfo`'s `flags` field
encodes numerically. The unnumbered rows (`cwd`, `txt`, `rtd`, `mem`) are
a different, separately useful convenience: they read `/proc/$pid/cwd`,
`/proc/$pid/exe`, and the memory-mapped files in `/proc/$pid/maps` — none
of which lives under `/proc/$pid/fd` at all, so do not expect those rows
to show up in the directory listing above. `lsof -i` is the identical
numbered-FD table with a `WHERE` filter: show only the rows whose target
is `socket:[inode]`, then resolve that inode against `/proc/net/tcp` (or
`/proc/net/tcp6`, `/proc/net/udp`) the way the primer's socket section
describes. There is no separate mechanism for "network lsof" — it is the
same fd walk, filtered.

The catch for this day specifically: `app` and `slim` are both Alpine, and
neither ships `lsof` — the real incident below has to be diagnosed with
nothing but `/proc` and busybox `sh`/`grep`/`awk` from the first command,
not as a fallback after `lsof` fails. That is the point of the exercise,
not an inconvenience: `lsof` on `ws` teaches the model; the incident on
`app` proves you actually own it.

## Core concepts

**Descriptors 0/1/2 are a convention, not a law.** Nothing in the kernel
requires fd 0 to be readable input or fd 1 to be a terminal; `exec` and
the shell simply arrange it that way for every new process by inheritance.
A descriptor is one entry — a number — in a per-process table, each entry
pointing at a kernel-wide open file description that tracks the offset and
flags. That is all "stdin", "stdout", and "stderr" ever mean.

**Redirection is descriptor surgery.** `>file` opens `file` and makes fd 1
point at it. `2>&1` performs `dup2(1, 2)`: make fd 2 a copy of *whatever
fd 1 currently points at* — not "tie fd 2 to fd 1 forever," a one-time
copy, evaluated left to right at the moment the shell parses that token.
That single fact is why order changes the outcome:

```
cmd >file 2>&1
```

Read left to right: `>file` first — fd 1 now points at `file`. Then
`2>&1` — fd 2 becomes a copy of fd 1's *current* target, which is now
`file`. Both stdout and stderr land in `file`.

```
cmd 2>&1 >file
```

Read left to right: `2>&1` first — fd 2 becomes a copy of fd 1's *current*
target, which at this point is still the original stdout (the terminal,
or whatever the caller had). Then `>file` — fd 1 is redirected to `file`,
but fd 2 was already duplicated a step earlier and is untouched by this.
Stdout goes to `file`; stderr keeps going to the terminal. Same two
tokens, reversed order, a different destination for stderr — because
`2>&1` copies a target, it does not create a link.

**Pipes** are a descriptor pair from one `pipe(2)` call: the write end
feeds the read end, and `cmd1 | cmd2` connects cmd1's fd 1 to that write
end and cmd2's fd 0 to the read end — a fact you can see directly as the
`pipe:[inode]` targets above, one on each process. **`tee`** reads its fd 0
and writes it unchanged to both fd 1 and every file argument — a fd
fan-out, not a special case. **Here-documents** (`<<EOF`) build an
anonymous temp file or pipe and connect it to fd 0 before the command
runs. **Process substitution** (`<(cmd)`) is the same idea in reverse:
bash runs `cmd`, connects its stdout to a pipe, and hands the *reading*
end to the outer command as a path like `/dev/fd/63` — which is why
`diff <(sort a) <(sort b)` works without a temp file.

**A write lands on one of two inodes.** Every command that changes a file
makes a choice its man page rarely states: keep the inode and replace its
bytes, or build a new inode and move the name onto it. Day 1 separated the
name from the inode; this is the same fact seen from the writer's side, and
every row below was observed in this fleet, not copied from documentation:

| Write form | What it does | Inode afterwards |
|---|---|---|
| `>`, `>>`, `: > f`, `truncate -s 0 f` | opens the existing inode with `O_TRUNC` or `O_APPEND` | same |
| GNU `cp src f`, onto an existing `f` | opens `f` with `O_TRUNC`, copies bytes in | same |
| `sed -i`, `mv tmp f`, `install src f`, busybox `cp src f` | creates a separate file, then puts it under the name | new |
| nvim `:w`, default settings | renames `f` to `f~`, writes a fresh `f`, removes `f~` | new, with exceptions — see `content/primers/nvim-file-ops.md` |

*Same inode* has four consequences. Any process holding a descriptor sees
the new bytes — including half of them, if it reads while the write is still
in progress. Truncation happens at `open(2)`, before a single byte is read,
which is why `sort f > f` leaves `f` empty: the shell truncated it before
`sort` ever opened it (`sort -o f f` is safe, because `sort` reads all its
input before opening the output). A running executable refuses it — `cp`
onto `./sleep` while `./sleep` runs fails with `Text file busy`
(`ETXTBSY`). And hard links and bind mounts survive, because nothing about
the name changed.

*New inode* has the opposite set:

- A process holding the old descriptor keeps reading the old content, and
  `ls -l /proc/PID/fd` shows the target as `(deleted)` — Day 1's mechanism,
  produced by an edit instead of an `rm`. This is the whole difference
  between `tail -f` (follows the descriptor, so it stays on the dead inode)
  and `tail -F` (follows the name, so it reopens the new one).
- Readers see the whole old file or the whole new one, never half:
  `rename(2)` is atomic — within one filesystem. Across filesystems `mv`
  gets `EXDEV` from `renameat2` and falls back to copy-then-unlink, which
  is not atomic. Create the temp file in the target's own directory
  (`mktemp ./cfg.XXXXXX`), not in `/tmp`.
- A hard link detaches: `sed -i` through one name leaves the other name on
  the old content, each with a link count of 1.
- A symlink is replaced by a regular file: `sed -i` on the link writes the
  new content to the link's own name. GNU `sed --follow-symlinks` edits the
  target instead; busybox `sed` has no such flag.
- It needs write permission on the *directory*, not only the file. A user
  who can write `cfg` but not its directory gets
  `sed: couldn't open temporary file lk/sedekqLxH: Permission denied` from
  `sed -i`, while `echo new > lk/cfg` succeeds — Day 5's directory model.
- A bind-mounted single file cannot be renamed over. Every container in
  this fleet has `/etc/hosts`, `/etc/hostname`, and `/etc/resolv.conf` as
  bind mounts (Day 1, exercise 3), so `sed -i` on them fails —
  `sed: cannot rename /etc/sedL8Dmgj: Device or resource busy` on `ws`,
  `sed: can't move '/etc/hostsEGaeDm' to '/etc/hosts': Resource busy` on
  `slim`. The same-inode form works:
  `sed 's/old/new/' /etc/hosts > /tmp/hosts.new && cat /tmp/hosts.new > /etc/hosts`.

**Proving which one happened.** Comparing `stat -c %i` before and after is
not proof: a freed inode number can be handed to the very next file created,
and in this fleet `install` over a file came back with the *original's*
number. Hold a reference across the write instead, so the old inode cannot
be freed:

```sh
exec 3< f              # fd 3 now pins f's current inode
sed -i 's/old/new/' f  # or whatever write you are testing
ls -l /proc/$$/fd/3    # "(deleted)" = new inode; plain path = same inode
cat <&3                # and this is the content the old inode still holds
exec 3<&-
```

The choice, then: a file a process reads **by name** (most config) gets a
new inode — temp file in the same directory, then `mv` — so no reader ever
sees half a file. A file that is bind-mounted, hard-linked, or followed
through an open descriptor you want to keep gets written in place, and you
accept that it is not atomic. `logrotate` makes the same choice under
different names: `create` renames, `copytruncate` writes in place — see
*Where this shows up in AWS* below. The command subset for all of this, GNU
and busybox side by side, is `content/primers/file-ops-reference.md`.

**The triage trio, the operator subset only:**

- `grep -c` counts matches, `-n` numbers them, `-v` inverts the match,
  `-A N`/`-B N` print trailing/leading context lines, `-F` treats the
  pattern as a literal string, not a regex — the fastest way to search for
  a literal `req_id` value with no regex surprises.
- `sed -n 'N,Mp'` prints only lines N through M (`-n` suppresses the
  default echo, `p` is the print command); `sed 's/old/new/'` substitutes
  the first match per line, `s/old/new/g` every match.
- `awk '{print $N}'` prints field N of whitespace-split input; `awk -F'x'`
  changes the field separator to `x`; simple aggregation
  (`awk '{sum+=$N} END{print sum}'`) needs no external tool at all.
- `sort | uniq -c | sort -rn` — sort the values so equal ones are
  adjacent, count consecutive duplicates, then sort those counts
  numerically descending. This one pipeline answers "what are the top N
  values of this field" for any log on any box, and it is the single most
  reused line in this entire path.

**`find -exec` versus `xargs -0`:** `find . -exec cmd {} \;` forks `cmd`
once per matched file — correct when the command must run once per file
(e.g. it takes only one argument) and safe with any filename, spaces
included, because `find` never re-tokenizes the name. `find . -print0 |
xargs -0 cmd` batches many filenames onto as few `cmd` invocations as fit
an argument list — correct and much faster when `cmd` accepts multiple
filenames (`rm`, `grep -l`, `wc -l`) — and the `-print0`/`-0` pairing is
what makes it space-safe: it delimits filenames with `NUL`, the one byte
that cannot appear in a filename, instead of whitespace or newline.

**Exit codes and pipeline status.** `$?` holds the exit status of the last
command executed — not the last command *in a pipeline* unless that
happens to be the one you meant. `grep pattern file | head -1` exits with
`head`'s status (usually 0, since `head` succeeded), even when `grep`
found nothing — the pipeline's reported status is always the *last*
command's, full stop. `set -euo pipefail` changes exactly that:
`pipefail` makes the pipeline's status the *rightmost non-zero* status of
any stage, or zero if every stage succeeded; `${PIPESTATUS[@]}` (bash
only) then holds every stage's individual exit status if you need to know
which one actually failed, not just whether one did.

## Lab

Goal: `app`'s log rotation ran, but `/var/log` keeps reporting the same
usage instead of shrinking, and one request in the rotated batch failed.
Diagnose which process is still holding the rotated file open, recover
the failing request's `req_id` from it, and release the space. Success
signal: `labs/day03/verify.sh` exits 0.

The fixture is `/labs/fleet/seed/gen-logs.sh`, run inside `app` at 100 000
lines (~80 bytes each, ~8 MiB) — the live log plus one rotated copy is
roughly 16 MiB, comfortably inside `app`'s 24 MiB `/var/log` tmpfs (see
`docker-compose.yml`'s comment on why that ceiling is exact, not
approximate). Run `labs/day03/break.sh`, write the chain in `journal.md`
**before** fixing, per `STRATEGY.md`'s daily loop.

## Strip the toolbox

Redo the same triage skills — grep/sed/awk on a log fixture, and the
deleted-fd walk — inside `slim`, which has neither `lsof` nor the `/labs`
mount `app` and `ws` both get. Build a tiny fixture with nothing but
`awk` and busybox `sh`, then repeat the trio:

```sh
slim$ awk 'BEGIN{
  for (i = 1; i <= 2000; i++) {
    c = (i == 777) ? 500 : 200
    printf "req_id=%08d status=%d path=/x\n", i, c
  }
}' > /tmp/fixture.log
slim$ grep -c 'status=200' /tmp/fixture.log
slim$ grep -n 'status=500' /tmp/fixture.log
slim$ awk -F'status=' '{print $2}' /tmp/fixture.log | awk '{print $1}' \
  | sort | uniq -c | sort -rn
```

That last line is the trio from Core concepts, run on `status` rather than
the unique `req_id` field so the counts are worth looking at (`1999 200`,
`1 500`) instead of every value tying at one.

Every one of those is busybox `grep`/`awk` — no `-P`, no `gensub`, no GNU
extension — and every one behaves identically to the same command run on
`ws`, which is exactly the point: the field model, not the flag set, is
what transfers. For the deleted-fd half of the toolbox, hold a file open
in the same way `tail -f` did in the incident, then find it with only
`ls` and `grep`:

```sh
slim$ : > /tmp/held.log
slim$ tail -f /tmp/held.log >/dev/null 2>&1 &
slim$ rm -f /tmp/held.log
slim$ ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep '(deleted)'
```

The write-semantics check needs nothing more than that. Busybox `sed -i`
makes the same new-inode choice as GNU `sed -i`, and the bind-mounted
`/etc/hosts` refuses it the same way, only with busybox's wording:

```sh
slim$ echo old > /tmp/w; exec 3< /tmp/w
slim$ sed -i 's/old/new/' /tmp/w
slim$ ls -l /proc/$$/fd/3        # -> /tmp/w (deleted)
slim$ cat <&3                    # old
slim$ sed -i 's/^#//' /etc/hosts # can't move '/etc/hosts…' to '/etc/hosts': Resource busy
slim$ exec 3<&-
```

One place busybox does *not* match `ws`: busybox `cp` onto an existing file
replaces the inode rather than truncating it, so a descriptor held on the
old file goes `(deleted)`, and `cp` onto the bind-mounted `/etc/hosts` fails
with `cp: can't create '/etc/hosts': File exists`. Same command name,
opposite side of the table — which is why the table lists `cp` twice.

## Exercises

1. Find the one `status=500` line among the 100 000 in the rotated,
   now-unlinked log, and report its `req_id`.
   **Hint:** the name is gone; the content is not — read it through the
   fd that still holds it open.
   **Solution sketch:** `grep -n 'status=500' /proc/<pid>/fd/<n>`, then
   `awk -F'req_id=' '{print $2}'` on the matched line, then
   `awk '{print $1}'` to cut at the trailing fields — or a single
   `awk -F'[= ]' '{print $4}'` once you know the field layout.

2. Produce the top five paths by request count with one pipeline.
   **Hint:** every log line has a `path=` field at the end; extract it,
   then reach for the three-command pipeline from Core concepts.
   **Solution sketch:**
   `awk -F'path=' '{print $2}' app.log | sort | uniq -c | sort -rn | head -5`.

3. Explain the difference between `cmd >file 2>&1` and `cmd 2>&1 >file`.
   **Hint:** redirections apply left to right, and `2>&1` copies fd 1's
   *current* target — it does not keep fd 2 permanently linked to fd 1.
   **Solution sketch:** in the first form fd 1 is already `file` when
   `2>&1` runs, so stderr follows it into `file`; in the second form fd 2
   copies the original stdout before fd 1 is ever redirected, so stderr
   keeps going to the terminal while stdout moves to `file`.

4. Identify which process holds a rotated log open, using only `/proc`.
   **Hint:** this is Day 1's technique, one level further — the `(deleted)`
   marker names the file; `fdinfo` tells you how much of it the holder
   has already read.
   **Solution sketch:**
   `ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep '(deleted)'` (the trailing
   `/*` keeps the PID on the same line as the target) finds the fd and
   its owning PID directly, from the path itself (`/proc/<pid>/fd/<n>`);
   `cat /proc/<pid>/comm` and `tr '\0' ' ' < /proc/<pid>/cmdline` name
   the process; `cat /proc/<pid>/fdinfo/<n>` shows `pos` sitting at
   end-of-size — evidence of how much was read, not why the space stays
   allocated, which is the open fd alone.

5. Write a `find` + `xargs -0` command that is safe with spaces in
   filenames.
   **Hint:** the pairing that makes it safe is the `NUL` delimiter on
   both ends, not either flag alone.
   **Solution sketch:**
   `find . -name '*.log' -print0 | xargs -0 grep -l 'status=500'` — never
   `find . -name '*.log' | xargs grep -l ...`, which breaks the moment a
   filename contains whitespace.

6. Explain why `grep pattern file | head -1` can exit non-zero even when
   `pattern` is present in `file`.
   **Hint:** a pipeline's exit status, without `pipefail`, is not
   `grep`'s.
   **Solution sketch:** the reported status is `head`'s, always — but
   `head -1` closes its input early once it has one line, which can make
   the upstream `grep` receive `SIGPIPE` and exit non-zero itself; under
   plain `$?` that detail is invisible, and under `set -o pipefail` it
   would surface as the pipeline's overall non-zero status.

7. For each of `echo x > f`, `sed -i 's/x/y/' f`, GNU `cp g f`, and
   `mv g f`, predict whether `f` keeps its inode, then prove it in a way a
   recycled inode number cannot fool.
   **Hint:** comparing two `stat -c %i` outputs is a guess — the old number
   can be reissued the instant it is freed. Pin the old inode first.
   **Solution sketch:** `>` and GNU `cp` keep the inode; `sed -i` and `mv`
   replace it. Before each write, `exec 3< f`; afterwards
   `ls -l /proc/$$/fd/3` shows `f (deleted)` for the two replacements and a
   plain `f` for the two in-place writes, and `cat <&3` prints whichever
   content the pinned inode holds. `exec 3<&-` between runs.

8. On `ws`, `sed -i 's/^127\.0\.0\.1.*/& ws-alias/' /etc/hosts` fails.
   Write the chain, then make the change anyway.
   **Hint:** read the error for the syscall that failed, not the word
   "busy"; then ask Day 1 what kind of thing `/etc/hosts` is inside a
   container.
   **Solution sketch:** the error is
   `sed: cannot rename /etc/sedXXXXXX: Device or resource busy` — the edit
   itself succeeded into a temp file, and the `rename(2)` onto `/etc/hosts`
   is what failed. `grep ' /etc/hosts ' /proc/self/mountinfo` shows
   `/etc/hosts` as its own mount entry, and a mountpoint cannot be replaced
   by a rename. Write into the existing inode instead:
   `sed 's/^127\.0\.0\.1.*/& ws-alias/' /etc/hosts > /tmp/hosts.new && cat /tmp/hosts.new > /etc/hosts`.
   Proof: `grep ws-alias /etc/hosts` matches, and the mountinfo entry is
   still there.

9. `sort -u access.log > access.log` leaves an empty file. Explain why,
   and give two forms that work.
   **Hint:** list what the shell does before `sort` runs.
   **Solution sketch:** the shell performs the redirection first —
   `open("access.log", O_TRUNC)` — so `sort` opens an already-empty file.
   Safe forms: `sort -u -o access.log access.log` (`sort` reads all input
   before opening its output), or
   `sort -u access.log > access.log.tmp && mv access.log.tmp access.log`
   (a new inode, so a writer still holding the old one keeps writing to
   an unlinked file — the incident this whole day is about).

## Anti-patterns / Common mistakes

- Mistake 3 — reaching for `bat`, `ripgrep`, or `htop` out of muscle
  memory the moment a shell feels unfamiliar; none of them exist on `app`
  or `slim`, and the busybox `grep`/`awk` trio above is not a downgrade,
  it is the version that actually ships on the box you'll be paged for.
- Mistake 1 — collecting one-off `awk`/`sed` incantations instead of the
  field model (fields are whitespace- or `-F`-delimited positions,
  `sed -n 'N,Mp'` is just "print this range," `s///` is just
  "substitute"); the model derives any one-liner on demand, and no
  collection of memorized ones covers the log format you haven't seen yet.
- Mistake 5 — treating `sed -i`'s exit status 0 as proof that the change
  reached everything that reads the file. It proves a new inode now carries
  the name; any process still holding the old descriptor is reading the old
  inode, and only `/proc/PID/fd` can tell you which one it holds.

## Where this shows up in AWS

The CloudWatch agent and Fluent Bit both open the log file they are
tailing and keep that fd across a plain `mv`/rename-based rotation — if
the shipper does not reopen by name or receive a reload signal, it holds
the old inode exactly like the `tail -f` in this lab, and disk usage on
the EC2 host or the ECS task's ephemeral storage keeps climbing on a host
whose logrotate config swears the logs "are rotating fine." This is
precisely why `logrotate`'s `copytruncate` option exists: instead of
renaming the file out from under the writer, it copies the current
content aside and truncates the *original* path in place, so any process
still holding that original fd keeps writing into the (now empty) same
inode rather than into an unlinked one nobody will ever reclaim. The
trade-off is a small window where a few log lines can be lost between the
copy and the truncate — accepted deliberately because the alternative,
silent unbounded disk growth from every reader that never reopens, is
worse.

## Teardown

See `labs/day03/teardown.md`.

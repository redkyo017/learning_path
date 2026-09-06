# Day 3 — The File Descriptor Table

**Truth of the day:** fd table
**Budget:** 3 h — 1.5 h fd table and redirection, 1.5 h shell triage toolkit

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

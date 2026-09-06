# Day 1 — The mount tree, and everything is a file

**Truth of the day:** mount tree
**Budget:** 3 h — 2 h Linux + 1 h neovim

## Why this matters

A full disk that `du` cannot account for is the single most common "the
box is broken and nothing makes sense" page, and it is unsolvable without
knowing one fact: a filename is not a file. The name is a directory entry;
the file is an inode with data blocks behind it; the kernel can keep
billing those blocks to a filesystem long after every name pointing at
them is gone. Everything else today — the FHS, inodes, links, bind
mounts, overlayfs — is scaffolding for that one fact and the diagnostic
move it enables.

## Read the file first

Before any tool, read the two files that describe what's actually mounted.

`cat /proc/mounts` — one line per mount, six whitespace-separated fields,
in `/etc/fstab` field order:

```
overlay / overlay rw,relatime,lowerdir=... 0 0
tmpfs /var/log tmpfs rw,relatime,size=24576k,mode=1777 0 0
proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0
```

1. **device/source** — what backs the mount (a block device, or a
   pseudo-name like `overlay`, `tmpfs`, `proc` for filesystems that have
   no disk behind them at all).
2. **mountpoint** — where it's attached in this mount namespace's tree.
3. **fstype** — `overlay`, `tmpfs`, `ext4`, `proc`, `sysfs`, ...
4. **options** — comma-separated mount flags: `rw`/`ro`, `relatime`,
   `size=` for tmpfs, `lowerdir=`/`upperdir=`/`workdir=` for overlay
   (`merged` is the resulting view, not a mount option — see
   `overlayfs: lowerdir, upperdir, merged` below).
5. **dump** — the historic `dump(8)` backup flag; always `0` here, dead
   weight carried from the `/etc/fstab` line format.
6. **pass** — the historic `fsck` pass order; also always `0` in
   `/proc/mounts`, for the same reason.

`/proc/mounts` tells you *what* is mounted. It does not tell you *which*
mount you're looking at when two mounts stack at the same path, and it
does not tell you whether a mount is the whole filesystem or a slice of
one — that's what `/proc/self/mountinfo` adds. Same idea, denser format:

```
36 35 0:31 / /var/log rw,relatime shared:20 - tmpfs tmpfs rw,size=24576k,mode=1777
```

Ten-plus space-separated fields, with an optional-fields block in the
middle terminated by a literal `-`: mount ID, parent ID, `major:minor`,
**root**, mountpoint, mount options, zero or more optional fields, `-`,
fstype, source, super options. Two fields here have no equivalent in
`/proc/mounts` or in anything `df` prints:

- **Mount ID** (field 1) — a small integer unique to *this* mount entry,
  not to the path. Two mounts can share a mountpoint (one stacked over the
  other); the mount ID is the only way to name a specific one of them.
- **Root** (field 4) — the path *within the source filesystem* that this
  mount exposes. `/` means the whole filesystem is mounted; anything else
  means only a subtree of it is visible here — which is precisely what a
  bind mount is. Docker's `/etc/hosts`, `/etc/hostname`, and
  `/etc/resolv.conf` in every container are bind mounts of single files
  from the host, and this is the field that proves it: their root is the
  specific file path on the host side, not `/`.

## Derive the tool

Run `df -h` and `findmnt` and map every column back to the fields above.

```
$ df -h /var/log
Filesystem      Size  Used Avail Use% Mounted on
tmpfs            24M   24M     0 100% /var/log

$ findmnt /var/log
TARGET    SOURCE FSTYPE OPTIONS
/var/log  tmpfs  tmpfs  rw,relatime,size=24576k,mode=1777
```

`findmnt`'s `TARGET`/`SOURCE`/`FSTYPE`/`OPTIONS` are a direct relabelling
of `/proc/self/mountinfo`'s mountpoint/source/fstype/options fields —
`findmnt` is `mountinfo` with headers, nothing more.

`df` is different: `Size`, `Used`, `Avail`, and `Use%` exist in neither
`/proc/mounts` nor `mountinfo`, because neither file records how full a
filesystem currently is — they only describe the mount table, which
changes when something is mounted or unmounted, not when a file is
written. `df` gets its four numbers by calling `statfs(2)` once per
mountpoint, live, at the moment you run it. That's the one thing `df`
adds on top of the mount table: a syscall, not a file read.

## Core concepts

### The FHS as a set of promises

The Filesystem Hierarchy Standard isn't enforced by the kernel; it's a
convention every distro maintainer honors so paths mean something without
reading a manual. Read each top-level directory as a promise: `/etc` holds
config the admin edits by hand and package managers should not silently
overwrite; `/var` holds state that changes constantly (logs, spool,
databases) and is the correct place to look for "what changed
recently"; `/usr` holds installed software that's meant to be
read-only and shareable — read-only enough that some distros bind-mount
it `ro` outright; `/tmp` is volatile by convention (and often literally
`tmpfs`), so anything there can vanish on reboot with no warning. `/proc`
and `/sys` break the pattern entirely: they hold **no bytes on any disk**.
Every read of a file under either one runs kernel code that formats
live kernel state on the fly — there is no block device backing
`/proc/uptime`, and `stat`-ing it shows size `0` even though `cat`-ing it
prints real numbers.

### Inode versus name

A file is two separate things the shell hides from you: an **inode**
(size, permissions, timestamps, and the block pointers to the actual
data — no name inside it) and a **directory entry** (a name, plus the
inode number it points at, stored in the parent directory's own data).
`rm` deletes a directory entry. It never touches the inode directly. The
kernel frees an inode's data blocks only when two conditions both hold:
the link count (how many directory entries point at it) reaches zero,
*and* no process has an open file descriptor on it. Miss either
condition and the blocks stay allocated, invisible to `du` (which only
walks named directory entries) but still billed by `df` (which reads the
filesystem's live block accounting). This is the entire mechanism behind
today's incident.

### Hard links, symlinks, and stat

`ln a.txt b.txt` creates a **hard link**: a second directory entry
pointing at `a.txt`'s inode, incrementing its link count. `ls -li` proves
it — both names show the same inode number in the first column:

```
$ ls -li a.txt b.txt
131094 -rw-r--r-- 2 op op 11 Sep  6 10:00 a.txt
131094 -rw-r--r-- 2 op op 11 Sep  6 10:00 b.txt
```

The `2` in the link-count column confirms two names share this inode.
`rm a.txt` now only decrements that count to `1` and removes one
directory entry; `b.txt` still opens the same data, unaffected, because
the inode is still named at least once.

`ln -s a.txt c.txt` creates a **symlink** instead: a distinct inode of
its own, whose "data" is the literal text `a.txt`, resolved fresh by the
kernel on every path lookup that passes through it. `ls -li c.txt` shows
a *different* inode number and a link count of `1`, because a symlink
doesn't hold a reference to the target's inode at all — only a string.
`rm a.txt` now leaves `c.txt` dangling: `readlink c.txt` still prints
`a.txt`, but `cat c.txt` fails with `ENOENT`, because the string it
points at no longer resolves.

`stat` decodes the inode directly (abridged below — real `stat` output
also prints a separate `Access: (0644/-rw-r--r--) Uid:(...) Gid:(...)`
mode line, and each of the three timestamps below is its own full line
down to nanosecond precision, not one compressed row):

```
$ stat a.txt
  File: a.txt
  Size: 11          Blocks: 8          IO Block: 4096   regular file
Device: 0,31        Inode: 131094      Links: 2
Access: 2026-09-06  Modify: 2026-09-06  Change: 2026-09-06
```

`Links` is the hard-link count from the paragraph above. `Access`,
`Modify`, and `Change` are three distinct timestamps that get confused
constantly: **atime** is last read, **mtime** is last data change, and
**ctime** is last *metadata* change (permissions, ownership, link count)
— ctime is not "creation time," a common and wrong assumption; Linux has
no creation-time field in the classic inode at all (some filesystems
expose a separate `Birth` field, but `ctime` never means that).

### Bind mounts

`mount --bind /srv/data /srv/data-copy` makes the same inode tree visible
at a second path — not a copy, one filesystem, two mountpoints. This is
exactly what the mountinfo **root** field revealed earlier: any mount
whose root isn't `/` is showing you a slice of another filesystem bound
in somewhere else. It's also precisely the mechanism behind every
`docker run -v /host/path:/container/path` and every `volumes:` entry in
this fleet's compose file — a bind mount from the host's filesystem into
the container's mount namespace, no copy involved.

### overlayfs: lowerdir, upperdir, merged

A container's root filesystem is `overlay`, a union of three roles:
**lowerdir** (one or more read-only directory trees), **upperdir** (one
writable directory that catches every new write), and **merged** (the
single view a process actually sees, presenting upper on top of lower).
Deleting a file that only exists in a lower layer doesn't remove any
bytes from it — overlayfs writes a **whiteout** marker into upperdir that
tells the merged view to hide that name. One sentence worth memorizing
because it demystifies every container image: **a container image layer
*is* a lowerdir** — each layer in an image manifest is one read-only
directory tree, stacked in order, with the running container's own
writable changes landing in a final upperdir on top of all of them.

### df versus du, and why they can disagree in both directions

`df` reads a filesystem's live block accounting via `statfs(2)`: total
capacity, and how many blocks are currently allocated, full stop — it has
no concept of names. `du` walks a directory tree, summing the on-disk
size of every named file it finds, deduplicating by inode as it goes (a
hard-linked file is counted once per `du` run, not once per name — `-l`/
`--count-links` is the flag that opts *into* the double count, which is
why hard links are not a source of accidental divergence). They agree
when every allocated block on the filesystem is reachable through exactly
one name under the path `du` was given, and nothing else is mounted
underneath that path. They disagree in two opposite directions:

- **`df` reports more used than `du`** when blocks are allocated but
  unnamed — the unlinked-but-open file from the inode section above is
  the canonical case: `df`'s live accounting still counts the block,
  `du` has no directory entry left to walk to find it.
- **`du` reports more used than `df`** when `du` descends into a
  *different* filesystem mounted under the path it was given: `du`
  crosses mount points by default (`-x`/`--one-file-system` is the flag
  that stops it), so its total for `/data` can include every byte under
  `/data/other-volume` too, while `df /data` reports usage for the
  `/data` filesystem alone and never counted `other-volume`'s blocks at
  all — different device, different `statfs(2)` call.

A `df`-internal gap worth naming separately, because it looks like a
`df`-vs-`du` disagreement and isn't one: on filesystems that reserve a
root-only margin (classically ~5% on ext4), `df`'s own `Avail` column
reads lower than `Size` minus `Used` — that gap is `df` talking to
itself about headroom held back for root, with no `du` comparison
involved at all.

## Lab

See `labs/day01/`. The goal: return `/var/log` on `app` to under 20% used
without restarting the container. Success signal: `verify.sh` exits 0.
Run `break.sh`, write the chain in `journal.md` **before** fixing.

### Neovim survival (1 h)

From here on, every lab file in this path gets edited in `nvim` inside
`ws`, with arrow keys disabled by the container's shipped, plugin-free
`/root/.config/nvim/init.lua` — in normal, insert, and visual mode alike.
That rule starts today and every remaining day depends on it holding.
Work through `content/primers/nvim-cheatsheet.md` now rather than having
it repeated here: the grammar is `<operator><count><motion|text-object>`
(`d`/`c`/`y`/`>`/`gu`), the motions (`w b e 0 $ gg G`, `f`/`t` character
finds), the text objects (`iw`, `i"`, `i(`, `ip`), search as a motion
(`/pat<CR>`, `n`/`N`), and undo/redo (`u`, `Ctrl-r`). Practice with
`hjkl` — no arrows, they're dead in this container — until the exit
criterion holds: **open a real file in `ws` (`/etc/hosts` is a safe
target) and make a nontrivial edit using only motions, text objects, and
ex commands, without your hand moving toward the arrow keys even once.**
If you catch yourself reaching for an arrow key, that's the tell you're
not done with this hour yet.

## Strip the toolbox

Check first: `command -v lsof` inside `slim`. Whether or not this
particular Alpine build happens to carry a busybox `lsof` applet, treat
it as absent and reproduce the identification step by hand instead — the
skill under construction is the `/proc` technique, not a fact about
which applets one image ships. Inside `slim`, write a file, open it in a
background reader, unlink it, then find the evidence with only busybox
`ls`, `sh`, and `grep`:

```sh
dd if=/dev/zero of=/tmp/x bs=1M count=1 2>/dev/null
setsid sh -c 'exec tail -f /tmp/x >/dev/null 2>&1' &
sleep 1
rm -f /tmp/x
ls -l /proc/[0-9]*/fd/* 2>/dev/null | grep '(deleted)'
```

The last line is the entire technique, and the glob matters: each entry
is a symlink, and `ls -l` prints where it resolves, appending ` (deleted)`
when the target name is gone — but pointing `ls -l` at the fd
*directories* (`/proc/*/fd`) prints one `/proc/PID/fd:` header line per
process above its entries, and `grep` only ever sees the entry line, never
the header, so the PID is lost. Globbing the individual fd files
themselves (`/proc/[0-9]*/fd/*`) puts the full `/proc/PID/fd/N` path
directly on the matched line instead. No `lsof -X`, no `fuser`, just `ls`
piped through busybox `grep`, which supports plain pattern matching and
`-c`/`-v`/`-l` but not GNU extensions like `-P`. This is the one command
this entire day's diagnosis reduces to when every friendlier tool is
missing; `verify.sh` walks the same `/proc/*/fd/*` entries against `app`.

## Exercises

1. A process creates a 4 GB sparse file (`truncate -s 4G f`, no data
   actually written) inside a directory you then run `df` and `du`
   against. Predict which direction they diverge, if at all, and why. —
   **Hint:** both `df` and `du` account for real allocated blocks, not
   the size a program declared. — **Solution sketch:** they don't
   diverge from each other here; a sparse file with no data written has
   almost no allocated blocks, so both `df` and `du` stay near zero. The
   divergence lands somewhere else entirely: `ls -l f` (or `stat`'s
   `Size` field) reports the full 4 GB *apparent* size, because that
   field records the logical end-of-file offset, not disk usage — the
   trap is expecting `df`/`du` to disagree with each other when the real
   disagreement is between apparent size and either of them.
2. Create a hard link and a symlink to the same file, then remove the
   original. Which survives, and why? — **Hint:** one link type stores an
   inode reference; the other stores a path string. — **Solution sketch:**
   the hard link survives untouched — it shares the inode, so removing
   the original only drops one of now-two directory entries and the data
   stays reachable through the other name. The symlink goes dangling: it
   holds the literal text of the original's path, and once that path
   resolves to nothing, `cat` on the symlink fails with `ENOENT` even
   though `readlink` still happily prints the (now-broken) target string.
3. Read `/proc/self/mountinfo` inside any container in this fleet and
   name every mount whose root field is not `/`. — **Hint:** the root
   field is the fourth space-separated field, before the mountpoint. —
   **Solution sketch:** in every container, `/etc/hosts`, `/etc/hostname`,
   and `/etc/resolv.conf` show up as bind mounts whose root is a specific
   file path on the host (or in Docker's per-container config store), not
   `/` — proof that a single-file bind mount is still a full mount table
   entry, not a special case. Containers that also declare a `volumes:`
   entry (`ws` and `app` both bind `../` at `/labs`) show a fourth
   non-root-rooted entry for that path as well.
4. Find the inode number `/etc/hosts` resolves to, then find every other
   name pointing at that same inode. — **Hint:** `stat` or `ls -i` gives
   the number; a link search needs to stay on one filesystem. —
   **Solution sketch:** `stat -c '%i' /etc/hosts` (or `ls -i /etc/hosts`)
   prints the inode number; `find / -xdev -inum <that number>` walks the
   root filesystem looking for every directory entry pointing at it,
   `-xdev` stops the search from crossing into other mounted filesystems
   where the same inode *number* could coincidentally exist but refer to
   something unrelated — inode numbers are only unique per filesystem,
   never globally.
5. A 4 GB application log is `rm`'d, but `df` shows no space freed.
   Explain why, using today's model, with no new commands. — **Hint:**
   ask what `rm` actually removes, and what a running process might still
   hold. — **Solution sketch:** `rm` only removes the directory entry;
   the inode's link count may have hit zero, but a process still has the
   file open on a file descriptor, and the kernel keeps every block
   allocated until that last descriptor closes — exactly the mechanism
   this whole day is built around, just with a different filename.
6. Using only `/proc/mounts`, explain why writing to `/proc/uptime`
   fails. — **Hint:** check whether the *mount* is actually read-only
   before assuming that's the reason. — **Solution sketch:** it isn't,
   and that's the point of the exercise: `/proc/mounts` shows the procfs
   mount itself as `rw` (typically `rw,nosuid,nodev,noexec,relatime`),
   which rules out "mounted read-only" as the explanation. The real
   reason lives one level below what this file can show you — the
   kernel generates `/proc/uptime` on every read with no write handler
   implemented at all, so the write fails regardless of mount options or
   the (cosmetic) permission bits `ls -l` displays. `/proc/mounts`
   answers mount-level questions; it cannot answer a per-file question,
   and knowing that boundary is as much the lesson as the file itself.

## Anti-patterns / Common mistakes

- Mistake 2 (trusting the summary tool) applies to `df` exactly as it
  applies to `free`: reading `df`'s `Use%` as the complete story, instead
  of treating it as one number that still needs `du` and `/proc/*/fd` to
  explain *why* it's high, is the same failure mode that misreads `free`'s
  "free" column as available memory.
- Mistake 3 (learning tools absent from real servers): `ncdu` is not on
  `alpine:3.20`, not on most bare EC2 AMIs, and not in this fleet's
  `slim` container. Build the `du`/`/proc` habit first; treat `ncdu` as
  optional garnish you might get to use on a well-stocked box, never as
  the only way you know how to find what's using space.

## Where this shows up in AWS

An ECS task's ephemeral storage fills up because the application's log
was rotated on disk but the process still holds the old, now-unlinked,
file open on a descriptor — identical mechanism to today's lab, different
host. The task keeps running and keeps accepting new connections while
every write to that descriptor (and often every write anywhere on the
now-full ephemeral volume) fails, because ECS's health check almost
never probes disk write success directly. Restarting the task "fixes"
it — a new task gets fresh ephemeral storage and the old process (with
its unlinked fd) is simply gone — but that's exactly why restarting
hides the cause: nothing about the log rotation or reload configuration
that produced the leak got touched, so the same task definition leaks
again on the next box it lands on.

## Teardown

See `labs/day01/teardown.md`.

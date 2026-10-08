# Foundations 01 — Files, names, and inodes

**Prepares you for:** Day 1.
**Time:** about 45 minutes, including the try-it steps.

Chapter 00 promised deleted-but-open files and mounts. By the end you
can read a `/proc/mounts` line and a `stat` listing, where Day 1 starts.

## What you'll be able to explain

- A file's name lives in a directory; everything else about the file
  (owner, size, timestamps, where the bytes are) lives in a separate
  record called an inode, which does not contain the name.
- A hard link is a second name for the same inode; a symlink is a tiny
  separate file that holds a path. Hard links cannot cross filesystems;
  symlinks can.
- Removing a name does not free the space while any process still has
  the file open. That is why a "deleted" log can keep a disk full.
- Every path is resolved through a tree of mounted filesystems, and what
  you see at a path is the top-most mount there.
- In the `ws` container, `/` is an overlay mount (read-only layers plus
  one writable layer) and `/labs` is a read-only bind mount.

## The mental model

### One tree, starting at `/`

Linux has a single directory tree starting at one point, written `/`,
the **root directory**. Everything is reached by a **path**: names
separated by `/`. There are no drive letters; a second disk appears
inside the same tree.

A path that starts with `/` is an **absolute path**: it means the same
thing wherever you are. A path that does not is a **relative path**,
read from the current working directory of the process using it
(chapter 02 explains that directory). `.` means "this directory" and
`..` the parent directory.

### A directory is a list: name to inode number

A **directory** is a file that holds a list of **directory entries**.
A **directory entry** is one line in that list: a name, and a number.
The number says which stored file the name refers to. That number is the
**inode number**, and the stored file it points to is an **inode**.

An **inode** is a small record the filesystem keeps for every file. It
holds the type (regular file, directory, symlink, ...), the mode and
owner (chapter 05 explains them), the size, three timestamps, the **link
count** (how many directory entries point at this inode), and the
**block pointers** saying where the content sits. The content itself is
stored in **data blocks**: fixed-size chunks of storage, commonly 4 KiB.

Notice what is missing from the inode: the name. The inode does not
contain the filename at all. Names live only in directory entries, in
the data of the directory that holds them.

```
  path "/etc/hostname"
        |
        |  look up "etc" in "/", then "hostname" in "etc"
        v
  +--------------------------+
  | directory /etc           |   a directory is a file whose data is
  |   name      inode number |   a list of  name -> inode number
  |   hostname  ->  4012     |   (this line is a directory entry)
  |   hosts     ->  4015     |
  +------------+-------------+
               |  inode number 4012
               v
  +--------------------------+
  | inode 4012               |   type, mode, owner, size, timestamps,
  |   link count: 1          |   link count, block pointers
  |   block pointers: ...    |   (no name in here)
  +------------+-------------+
               |
               v
  +--------------------------+
  | data blocks              |   the actual bytes of the file
  +--------------------------+
```

### Where the numbers show up: `ls -i` and `stat`

`ls -i` prints the inode number next to each name. `stat` prints the
inode's own record. Reading a `stat` listing field by field:

```
  File: /etc/hostname
  Size: 11          Blocks: 8          IO Block: 4096   regular file
Device: 0,31        Inode: 4012        Links: 1
Access: (0644/-rw-r--r--)  Uid: (    0/    root)   Gid: (    0/    root)
Access: 2026-10-08 ...
Modify: 2026-10-08 ...
Change: 2026-10-08 ...
```

(An illustration; your numbers will differ.) `Size` is bytes and
`Blocks` the storage allocated (512-byte units, so a tiny file still
takes a whole 4 KiB block). `Device` names the filesystem, and `Inode`
is the inode number, unique only within that filesystem. `Links` is the
link count. The three timestamps are separate: **atime** (`Access`) is
the last read, **mtime** (`Modify`) the last content change, **ctime**
(`Change`) the last inode change such as permissions or link count. ctime
is not a creation time. Day 1 goes further on this.

### Two names, one inode: hard links

A **hard link** is an additional directory entry that points to an inode
that already exists. `ln a.txt b.txt` adds the name `b.txt` pointing at
the same inode as `a.txt`, and raises the link count from 1 to 2. There
is one file with two names; neither is the "real" one.

```
   directory entries                inode                 data blocks
  +------------------+         +---------------+        +-----------+
  | a.txt -> 131094  |-------->|  inode 131094 |------->| "hello    |
  +------------------+    ^    |  links: 2     |        |  world"   |
  | b.txt -> 131094  |----+    |  size, mode,..|        +-----------+
  +------------------+         +---------------+
   two names (maybe in two directories), one inode, one set of bytes
```

If you remove `a.txt`, the kernel deletes that one directory entry and
lowers the link count to 1. `b.txt` still opens the same bytes. Nothing
about the content changed, because the content never belonged to a name.

A **symlink** (symbolic link) works differently. It is a separate,
small file of its own, with its own inode, whose content is just a path
written as text. When a program opens a symlink, the kernel reads that
text and follows it to wherever it points. `ln -s a.txt c.txt` makes
`c.txt`, a tiny file containing the text `a.txt`. If `a.txt` is later
removed, `c.txt` is left **dangling**: it still holds the text `a.txt`,
but nothing is there to follow it to.

Why can't a hard link cross filesystems? A directory entry holds only an
inode number, unique only inside one filesystem, so a name on disk A
cannot refer to an inode on disk B. A symlink holds a path (text), which
can name a place on any filesystem.

### When is the data actually freed?

The kernel frees a file's data blocks when two things are both true:

1. the link count is 0 (no directory entry points at the inode), **and**
2. no process still has the file open.

"Open" has its plain meaning: a process asked the kernel for access and
has not let go. A program writing a log keeps it open while it runs.
(Chapter 04 explains how the kernel tracks this.)

So `rm bigfile` does only the first half: it removes a name. If a
process still holds the file open, the inode and blocks stay allocated
and the process can keep writing. The file is now an inode with no name;
`ls` cannot show it. When the last process closes it or exits, the
blocks are freed.

This is the root of Day 1's incident: a disk nearly full though you
deleted the big file, because an unnamed file is still open. The last
topic of this chapter shows the tools that see the gap.

### What a filesystem is

A **filesystem** is two things together: a way of arranging inodes,
directory entries, and data blocks on storage (the "format"), and the
kernel code that understands that format (the "driver").

The types you will meet:

| Type | What it is | Where its bytes live |
|---|---|---|
| `ext4` | The classic general-purpose disk filesystem. | on a disk |
| `tmpfs` | A filesystem that lives in memory. | RAM (and swap, chapter 06) |
| `overlay` | A filesystem built from other directories, stacked. | in the layers below it |
| `proc` | The kernel's process and system view (chapter 00). | nowhere: generated on read |
| `sysfs` | The kernel's device and settings view (chapter 00). | nowhere: generated on read |

### Mounting: attaching a filesystem at a directory

A filesystem on its own is not yet part of the tree. **Mounting**
attaches it to a directory, called the **mount point**. Afterwards a
path through that directory reaches the root of the mounted filesystem.
The set of all current mounts is the **mount tree**: the root filesystem
at `/`, with others attached at directories inside it (for example
`/proc` is `proc`, and in `ws` `/` is overlay and `/labs` a bind mount).

What you see at a path is the top-most mount there. Mounting over a
directory that has files hides them; it does not delete them. A path is
not a place on a disk: it may be a disk, memory, or a kernel view, so
"where do the bytes live?" (chapter 00's first truth) is answered by the
mount table, not by the path.

A **bind mount** makes a directory or single file that already exists
elsewhere in the tree show up at a second path, with no copy: the same
inode and data, reached by two paths. `ws` gets `/labs` this way from your
Mac's course folder, read-only, so writing under `/labs` fails. Day 1
goes further on bind mounts.

(Each container can have its own private mount tree, a **mount
namespace**; chapter 06 explains namespaces.)

### Reading `/proc/mounts`

`/proc/mounts` is the kernel's list of mounts, one line per mount, such
as `overlay / overlay rw,relatime,lowerdir=... 0 0`. Fields 1-4 matter:

1. **source** — what backs the mount. For a real disk this is a device
   such as `/dev/sda1`. For filesystems with no disk behind them it is
   just a label such as `overlay`, `tmpfs`, or `proc`.
2. **mount point** — the directory in the tree where it is attached.
3. **type** — the filesystem type (`ext4`, `tmpfs`, `overlay`, `proc`,
   `sysfs`, ...).
4. **options** — a comma-separated list of settings. `rw` or `ro` says
   whether it can be written. Others (`relatime`, `size=`) tune
   behaviour.

Fields 5 and 6 are old bookkeeping, always `0 0`. Day 1 goes further and
reads `/proc/self/mountinfo`, a denser file that also shows which slice
of a filesystem a bind mount exposes.

### tmpfs and overlay in plain terms

**tmpfs** is a filesystem whose storage is memory. Its files are real
files with inodes, but the bytes sit in RAM: fast, and gone when the
mount goes away or the machine reboots. Its `size=` option caps how much
memory it may hold (chapter 06 returns to this).

**overlay** (the filesystem type is `overlay`; the feature is called
overlayfs) builds one directory view out of several directories stacked
on top of each other:

- the **lower** layers: one or more directories that are read-only;
- the **upper** layer: one directory that is writable;
- the **merged** view: what a process actually sees, the lower layers
  with the upper layer on top. If a name exists in both, the upper one
  wins.

Reading takes a file from whichever layer has it. Writing to a file
that exists only in a lower layer first copies it up into the upper
layer; the lower layer is never touched. Deleting such a name leaves a
"hide this name" marker (a **whiteout**) in the upper layer.

```
   merged   (what a process sees: upper on top of lower)
      ^
   upper    (writable: new files, copies, whiteouts land here)
   lower 2  (read-only: e.g. an app layer)
   lower 1  (read-only: e.g. the OS layer)
```

This is why container images are built in **layers**: each image layer
is a read-only directory tree and becomes one lower layer. Containers
share the lower layers and each gets only its own thin upper layer. The
root of the `ws` container, `/`, is an overlay mount.

### `df` and `du`: two ways to measure, and why they can disagree

`df` asks each filesystem how full it is, using the filesystem's own
block accounting (the `statfs` syscall; syscalls are from chapter 00).
It never looks at names. `du` walks the directory entries under a path
and adds up the sizes of the files it finds by name.

They agree when every allocated block is reachable by a name under the
path you gave `du`. They can disagree in two directions:

- `df` says more is used than `du` can find. An unnamed file has blocks
  that are allocated but no directory entry leads to them. A deleted file
  that a process still has open is the standard cause. This is Day 1's
  incident.
- `du` says more than `df`. `du` follows directories into other mounted
  filesystems below the path, so its total can include another
  filesystem's bytes, while `df` for that one path counts only the
  filesystem that contains the path.

Day 1 goes further on this, including the flags that change `du` and the
reserved space that makes `df`'s own columns not add up.

## How it connects

Chapter 00 introduced the mount tree and the file-versus-name split;
this chapter built both. A path may land in any filesystem type,
including ones that store nothing (`proc`, `sysfs`). Chapter 04 explains
how the kernel tracks what each process holds open, the other half of
deleted-but-open. Chapter 05 returns to mode and owner; chapter 06 to
mount namespaces and tmpfs memory.

## See it yourself

Open the workspace container first:
`docker compose -p linuxops exec ws bash` (from `labs/fleet`). Every step
only reads.

```bash
stat /etc/hostname
stat -c '%d %n' /etc /etc/hostname
ls -li /etc | head
```

**What to look for:** in `stat`, find `Inode:`, `Links:`, the size and
three timestamps; no filename field. The `%d` line shows `/etc` and
`/etc/hostname` on different devices (Docker bind-mounts this file in).
In `ls -li`, column 1 is the inode number, column 3 the link count.

```bash
cat /proc/mounts
```

**What to look for:** one line per mount; use fields 1 to 4. Find `/`
with type `overlay`, `/proc` with `proc`, `/sys` with `sysfs`, and a
`tmpfs` line. Options include `rw` or `ro`.

```bash
findmnt 2>/dev/null | head -20
cat /proc/self/mountinfo | head
```

**What to look for:** `findmnt` (if installed) draws the mount tree as an
indented list. If it prints nothing, the second command shows the denser
form of the same data.

```bash
df -h /
df -h /labs
```

**What to look for:** two rows. `Filesystem` is field 1 of `/proc/mounts`
for the mount containing each path. `/labs` is a different mount from
`/`, though it sits inside the tree under `/`.

```bash
grep ' /labs ' /proc/mounts
```

**What to look for:** the options field contains `ro`: a read-only bind
mount of a host folder. Writing there would be refused with "Read-only
file system".

```bash
ls -l /proc/self/exe
```

**What to look for:** a symlink the kernel generates (`l` at the start
and an arrow `->`) pointing at the program file `ls` itself runs from.
It is a path stored as text, filled in on each read.

## Words you'll meet in the course

- **inode** — Day 1, *Inode versus name* ([glossary](../GLOSSARY.md))
- **hard link** — Day 1, *Hard links, symlinks, and stat* ([glossary](../GLOSSARY.md))
- **tmpfs** — Day 1, *Read the file first* ([glossary](../GLOSSARY.md))
- **overlayfs** — Day 1, *overlayfs: lowerdir, upperdir, merged* ([glossary](../GLOSSARY.md))
- **bind mount** — Day 1, *Bind mounts* ([glossary](../GLOSSARY.md))
- **whiteout** — Day 1, *overlayfs: lowerdir, upperdir, merged* ([glossary](../GLOSSARY.md))
- **link count** — Day 1, *Inode versus name* (how many directory entries point at an inode) ([glossary](../GLOSSARY.md))
- **df versus du** — Day 1, *df versus du, and why they can disagree in both directions* ([glossary](../GLOSSARY.md))

## Self-check

1. A directory holds an entry `report.txt -> 900`. Where are the file's
   size and its name stored? What does that mean for renaming?
2. You run `ln a.txt b.txt`, then `rm a.txt`. Is the content gone? What
   is the link count afterwards?
3. Why can't a hard link point from `/data` to a file on another
   filesystem, and what would work instead?
4. You `rm` a 3 GB log but `df` still shows the disk full. What are the
   two conditions for freeing the space, and which is not yet true?
5. A container's `/` is `overlay`. You edit a file that came from an
   image layer. Where does the change land, and what happens to the
   original?
6. `/labs` is under `/`, yet `df` shows different filesystems for them.
   Why? What do you see where a second filesystem is mounted over a
   directory that had files?

<details><summary>Answers</summary>

1. The size is in the inode (number 900); the name is in the directory's
   entry. Renaming only changes the directory entry (or moves it to
   another directory on the same filesystem); the inode and data blocks
   are untouched.
2. No, the content is still there. `rm a.txt` removes one directory
   entry and lowers the link count from 2 to 1; `b.txt` still points at
   the inode, so the bytes survive.
3. A hard link is a directory entry holding an inode number, and inode
   numbers are only unique within one filesystem, so a name on one
   filesystem cannot refer to an inode on another. A symlink (a small
   file holding a path) works across filesystems.
4. The link count must be 0 (met: `rm` removed the only name) and no
   process may have the file open. The second is not yet true: a
   process still holds the file open, so the blocks stay allocated until
   it closes the file or exits (chapter 04 explains how to find it).
5. The file is first copied up from the read-only lower layer into the
   writable upper layer, and the change lands there. The lower layer
   keeps its original untouched, and the merged view shows the upper
   copy.
6. `/labs` is a separate mount attached at a directory inside the
   root's tree, so the path crosses into another filesystem; `df` reports
   the filesystem that contains the path. What you see at a path with a
   filesystem mounted over a directory is the top-most mount; the
   files that were there before are hidden, not deleted.

</details>

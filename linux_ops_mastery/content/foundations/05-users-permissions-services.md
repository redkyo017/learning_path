# Foundations 05 — Users, permissions, and services

**Prepares you for:** Day 5.
**Time:** about 45 minutes with the try-it steps.

Day 5 opens with a file at mode `0777` nobody can reach. By the end that
looks obvious, and you know what systemd is for.

## What you'll be able to explain

- Users and groups are numbers (UID, GID). Names are a lookup in
  `/etc/passwd` and `/etc/group`. The kernel checks the numbers a
  process carries, never the name.
- A permission check goes owner, then group, then other, and the first
  match wins, so being the owner can deny you something the group
  would allow.
- On a directory, `r` lists names, `w` adds or removes names (only with
  `x` too) and `x` lets you pass through. A file is reachable only if
  you have `x` on every directory leading to it.
- `setuid` runs a program as the file's owner, `setgid` on a directory
  hands new files its group, `sticky` stops others deleting your names,
  and `umask` trims the mode of new files only.
- Root is UID 0 and skips most checks. Capabilities split that power
  into separate pieces so a process can hold just one.
- An init system is PID 1: it starts services, keeps them running and
  collects their logs. systemd is the common one, and `ws` does not
  run it.

## The mental model

### Users and groups are numbers

To the kernel a **user** is a number, the **UID** (user ID). A **group**
is a number too, the **GID**. Files record an owner UID and a group GID
in the inode (chapter 01). The names you see in `ls -l` are looked up
afterwards: `/etc/passwd` maps UID to user name (plus home directory and
login shell), and `/etc/group` maps GID to group name and lists members.
`ls -l` just formats numbers from `stat` (chapter 01 showed `Uid:`).

Rename a user in `/etc/passwd` and every file they own is still theirs,
because the inode holds the number. Move a file to a machine where that
number means someone else, and it belongs to them.

A user has one **primary group** and can belong to more. Those extras
are **supplementary groups**. A **root** user is the user with UID 0.
The kernel's special treatment attaches to the number 0, not the name.

### Every process carries credentials

A process (chapter 02) is not "run by a name". It carries a set of
numbers called its **credentials**:

- a **real UID** and a **real GID**: who started it;
- an **effective UID** and **effective GID**: whose identity the kernel
  checks when the process touches a file;
- a list of supplementary GIDs.

These come from the process that created it. `fork` copies them to the
child and `exec` keeps them (chapter 02), so a login starts as one user
and every command under that shell inherits the same numbers. For
almost every process real and effective are equal. They differ only in
the setuid case below. Day 5 goes further on this.

Every file access works the same way: the process makes a system call
(chapter 00), and the kernel compares the **effective** IDs with the
owner and group in the inode and with the **mode bits**. The user's
name is never consulted.

### Mode bits: three triads of r, w, x

The **mode** of a file is a set of bits, shown by `ls -l` as ten
characters: a type (`-` file, `d` directory, `l` symlink) then three
triads, for **owner**, **group** and **other** (everyone else).

```
   -   r w x   r - x   r - -        mode 754
   |   | | |   | | |   | | |
 type  owner   group   other
        7        5       4          r=4  w=2  x=1, added per triad
```

On an ordinary **file**, `r` means read the contents, `w` means change
them, and `x` means run it as a program.

The kernel decides with a short check:

```
        process (euid, egid, supplementary groups)  wants to open file
                               |
              euid == 0 ?  --yes--> allowed (root bypasses most checks)
                               |no
                               v
              euid == file's owner UID ?
                  |yes                        |no
                  v                            v
         use OWNER triad only      egid or a supplementary group
         (stop here, even if       == file's group GID ?
          group would allow)           |yes                |no
                                       v                   v
                              use GROUP triad only    use OTHER triad
```

The first match wins and the rest are not consulted. A file at mode
`070` (owner nothing, group `rwx`) is unreadable to its owner even
when the owner is in that group: the owner match stops the check. The
triads are never added together.

### Directories mean something different

A directory is a table of names to inodes (chapter 01), and its three
bits are about that table:

- `r`: **list the names** in it (`ls`).
- `x`: **pass through** it: look up a name inside and reach the inode.
  This is "traversal", not "execute".
- `w`: **add, remove or rename names**. Creating or deleting a file edits
  the directory, so it needs `w` on the directory, not on the file.
  `w` only works together with `x`. A directory with `w` but no `x` does
  not let you create or delete names, because you cannot do the lookup.

With `r` but no `x` you can list names but not reach what they point
at. With `x` but no `r` you cannot list, but you can open a file whose
exact name you know. Deleting a file needs `w` and `x` on its directory
and nothing on the file itself.

### A path needs `x` on every directory

Naming a file means walking its path from `/` one component at a time
(chapter 01), and each step is a lookup in a directory. So each
directory on the way needs `x` for the caller. The file's own mode is
checked last, only if every step succeeded.

```
  open("/srv/app/conf/app.cfg")      caller: unprivileged user "dev"

  /            drwxr-xr-x   x for other   ok, step through
  /srv         drwxr-xr-x   x for other   ok
  /srv/app     drwxr-xr-x   x for other   ok
  /srv/app/conf  drw-r--r-- NO x anywhere  DENIED: Permission denied
  app.cfg      -rwxrwxrwx   (0777, never even looked at)
```

That is Day 5's incident in miniature. A file at `0777` inside a
directory at `0644` is unreachable to every unprivileged caller,
owner included, because `0644` has no `x`. `ls -l` on the file looks
fine, since the file is innocent. The denial is one or more levels up.
Root gets through, not because it owns an `x` bit, but because it
bypasses the check (see capabilities below). Panicking with
`chmod 777` on the file changes nothing about the real problem.

### The three special bits

The mode has three more bits, shown by replacing an `x`:

- **setuid** (`4000`, an `s` in the owner's `x` slot) on an executable:
  when run, its **effective** UID becomes the file owner's, while the
  real UID stays the caller's. `/usr/bin/passwd` is owned by root with
  setuid, so any user runs it and it still can write `/etc/shadow`
  (the password-hash file, which ordinary users cannot even open). A
  setuid program runs with someone else's power, so it must be small
  and careful. Linux ignores the setuid bit on scripts (files that start
  with a `#!` line); it only works on compiled binaries. That is a
  safety choice: a script's interpreter is swapped in at `exec`, which
  opens a race.
- **setgid** (`2000`, an `s` in the group's `x` slot) on a **directory**:
  new files and directories created inside get the **directory's**
  group, not the creator's primary group. This is the fix for a shared
  team directory where uploads keep getting the wrong group.
- **sticky bit** (`1000`, a `t` in the other's `x` slot) on a
  **directory**: even with `w` on the directory, you may delete or
  rename an entry only if you own that entry (or are root; the
  directory's owner may too). `/tmp` is `1777`: everyone can create
  files there, but nobody can remove another user's.

### umask: trimming new files at creation

When a program creates a file it asks for a mode, usually `666`
(read/write for all, since new files do not get `x`) or `777` for a
directory. The process's **umask** is a mask of bits to *remove* from
that request. It is applied once, at the moment of creation. With the
common umask `022`:

```
  new file      requested 666  minus 022  ->  644  rw-r--r--
  new directory requested 777  minus 022  ->  755  rwxr-xr-x
```

The mask clears bits (it does not subtract, so a bit already absent
stays absent). A umask never changes a file that already exists;
changing it later affects only files created after. Only changing the
mode of the file itself does that. The umask belongs to the process and
passes to children (chapter 02), like the working directory.
`/etc/shadow` at `0640` is not a umask result: it was set by hand to be
narrower.

### Root and capabilities

**Root** (UID 0) passes almost every permission check: the first step
in the diagram. Historically a process was either root or not.

A **capability** is one slice of root's power that a process can hold
on its own. There are about 40. Three to know by name:

- `CAP_NET_BIND_SERVICE`: bind ports below 1024 (chapter 07; Docker
  relaxes it via `net.ipv4.ip_unprivileged_port_start=0`). A web server needs only it.
- `CAP_SYS_PTRACE`: attach to and inspect other processes, as `strace`
  does. The `ws` container holds this one.
- `CAP_DAC_READ_SEARCH` bypasses read and directory-search checks;
  `CAP_DAC_OVERRIDE` also bypasses write checks. Root's "skip" is these.

Capabilities live on the process. In `/proc/PID/status` the line
`CapEff` is a hex number where each bit is one capability that is
**effective** (in force now); `CapPrm` is the **permitted** set (the
ceiling the process may raise to). Root in `ws` is a limited root: UID
0 with only the capabilities the container was granted (chapter 06
explains the walls). Day 5 also covers capabilities stored on files.

### Briefly: ACLs and sudo

**ACLs** (access control lists) add extra per-user and per-group entries
on a file beyond owner/group/other; `ls -l` shows a `+` after the mode.
**`sudo`** runs one command as another user, root by default, after
checking `/etc/sudoers`, and logs it. Day 5 goes further on both.

### What an init system does

When the kernel finishes booting it starts one program: **PID 1**
(chapter 02). On a full machine that program is the **init system**.
Its jobs: start every service the machine needs, in a sensible order;
**supervise** them (restart one that dies); adopt orphans and reap
zombies (chapter 02); and collect what services print.

**systemd** is the init system on most current distributions. Its
vocabulary:

- A **unit** is a thing systemd manages, described in a text **unit
  file**. The commonest is a **service** unit (a program to run); there
  are also timers and **targets** (named milestones such as "multi-user
  system is up").
- A unit file has up to three sections. `[Unit]` holds description and
  dependencies, `[Service]` says how to run it, and `[Install]` says
  what enabling it hooks it into.

```
  [Unit]
  Description=Demo app
  Requires=db.service        <- pulls in db (presence, not order)
  After=db.service           <- order: start after db

  [Service]
  ExecStart=/usr/bin/demo    <- the program to run
  Restart=on-failure         <- supervision: bring it back

  [Install]
  WantedBy=multi-user.target <- what "enable" hooks this into
```

- **`systemctl`** is the control tool: `status` shows a unit's state and
  its last log lines; `start` and `stop` act now; `enable` wires the
  unit in so it starts at boot, without starting it now.
- **`journalctl`** reads the **journal**, systemd's log store. `journalctl
  -u NAME` shows one unit's lines.

systemd runs each service in its own cgroup (chapter 06 explains
cgroups), which is how it knows which processes belong to which service.
Day 5 goes further on all of this, including `Type=`, why `Requires=`
without `After=` starts things in the wrong order, and `daemon-reload`.

In a container, PID 1 is just the command you launched (chapter 02).
`ws` does not run systemd, so `systemctl` has nothing to talk to there;
the `sysd` container does, and Day 5 practises there.

## How it connects

- **Chapter 01's inode** stores owner UID, group GID and mode bits; a
  directory is the name table that `r`, `w` and `x` guard.
- **Chapter 02's processes** carry the credentials: `fork` copies them,
  `exec` keeps them, except that setuid changes the effective UID.
- **Chapters 00 and 04**: every `open`, `mkdir` or `unlink` is a system
  call where the kernel runs this check. It happens at `open`; the
  descriptor then keeps working even if the mode changes later.
- **Day 5** builds on this: the traversal lab, capabilities, systemd.

## See it yourself

Use the `ws` container: from `labs/fleet`, run
`docker compose -p linuxops exec ws bash`. Every step only observes.

```bash
id; getent passwd root
```

**What to look for:** `id` prints UID, GID and supplementary groups as
numbers with names beside them; as root, `uid=0(root)`. The `getent`
line is the `/etc/passwd` entry: name, `x`, UID, GID, comment, home,
login shell.

```bash
ls -ld / /tmp /etc /root
```

**What to look for:** `/tmp` should end in `t` (sticky, `drwxrwxrwt`);
`/root` should grant nothing to group or other.

```bash
stat -c '%A %a %U %G %n' /etc/passwd /etc/shadow /usr/bin/passwd /tmp
```

**What to look for:** `%A` is the symbolic mode and `%a` the octal.
`/usr/bin/passwd` should show an `s` in the owner triad (setuid, a
leading `4` in the octal). `/etc/shadow` should be narrow, readable
by at most root and the `shadow` group. `/tmp` shows the sticky `1`.

```bash
namei -l /etc/ssl/certs
```

**What to look for:** one row per path component from `/` down, each with
its own mode, owner and group. This is the traversal chain: the caller
needs `x` on every directory row, not only the last one.

```bash
umask
```

**What to look for:** a number like `0022`: the bits removed from new
files. It describes this shell process only.

```bash
grep -E '^(Uid|Gid|Groups)' /proc/$$/status
```

**What to look for:** `Uid` columns are real, effective, saved and
filesystem UID (the last two are kernel bookkeeping); all equal here.
`Groups` lists supplementary GIDs: the numbers the kernel checks.

```bash
grep -E '^Cap(Eff|Prm)' /proc/$$/status
echo $(( 0x$(awk '/CapEff/{print $2}' /proc/$$/status) / 524288 % 2 ))
```

**What to look for:** two hex numbers, one bit per capability; as root in
`ws` they are non-zero but not all ones, since a container is granted
only some. The `echo` tests bit 19 (value 524288): `1` means `ws` holds
`CAP_SYS_PTRACE`. This by-hand decode works without `capsh`.

## Words you'll meet in the course

- **effective UID** — Day 5, *Core concepts*
- **setuid** — Day 5, *Core concepts* ([glossary](../GLOSSARY.md))
- **setgid** — Day 5, *Core concepts*
- **sticky bit** — Day 5, *Core concepts* ([glossary](../GLOSSARY.md))
- **umask** — Day 5, *Core concepts* ([glossary](../GLOSSARY.md))
- **capability** — Day 5, *Core concepts* ([glossary](../GLOSSARY.md))
- **unit file** — Day 5, *Core concepts*
- **daemon-reload** — Day 5, *Core concepts*
- **journalctl** — Day 5, *Core concepts*

## Self-check

1. A file is `0777` and you own it, yet `cat` says "Permission denied".
   Its directory is `0644`. Why, and why does `chmod 777` on the file
   not help?
2. A directory you own is `drw-------` (`w` but no `x`). Can you
   create a file in it? Why?
3. A file is mode `070`, owned by you, and you belong to its group. Can
   you read it? Which rule decides?
4. `passwd` is setuid root. A user runs it: which UID is real, which is
   effective, and why does that let it edit `/etc/shadow`? Would a
   setuid bit on a shell script give the same effect?
5. Your umask is `077`. You create a file, then change umask to `022`.
   What mode does the first file have? What does the new umask change?
6. Why is `/tmp` mode `1777` and not `0777`? And what does it mean that
   `ws` has `CAP_SYS_PTRACE`?

<details><summary>Answers</summary>

1. Reaching the file needs `x` on every directory in the path. `0644`
   has no `x`, so the lookup stops there for any unprivileged caller,
   owner included, before the file's mode is looked at. The fix is `x`
   on the directory. Root gets through only by bypassing the check.
2. No. Creating a name edits the directory, which needs `w`, but `w`
   is only useful together with `x`: without `x` the kernel cannot
   look up inside it, so creating or deleting names fails.
3. No. The owner match comes first and uses only the owner triad, which
   is empty. First match wins, so the group's `rwx` is never consulted.
4. Real is the user's own UID; effective is 0 (the file owner, root)
   because setuid changes the effective UID at `exec`. The kernel checks
   the effective one, so it may open `/etc/shadow`. No for a script: on
   Linux the kernel ignores setuid on `#!` scripts.
5. Still the mode it was created with (`600`, from 666 minus 077). A
   umask applies only at creation, so the new `022` affects only files
   made afterwards, which get `644`.
6. Everyone must write in `/tmp`, so it is world-writable; the sticky
   bit (the leading `1`) stops users deleting or renaming each other's
   entries. A capability (`CAP_SYS_PTRACE`) is a slice of root's power
   held by the process, which lets `strace` attach in `ws` although
   `ws` is not a full root of the host.

</details>

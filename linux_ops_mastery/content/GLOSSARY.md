# Glossary

Plain-English definitions for terms used across this path without re-explaining
them inline. Alphabetical; each entry is one to three sentences.

- **capability**: A slice of root's privilege, granted independently
  (`CAP_NET_BIND_SERVICE` to bind port 80, `CAP_SYS_PTRACE` to trace another process) so a
  process needs less than full root. See `CapEff` in the /proc primer.

- **cgroup (v1 vs v2)**: A kernel mechanism that groups processes and limits/accounts
  their CPU, memory, and I/O. v1 mounted a separate hierarchy per resource controller; v2
  (the default on modern distros) is a single unified hierarchy -
  `/sys/fs/cgroup/<name>/memory.max` instead of a per-controller tree.

- **chain of evidence**: The ordered list of commands and their output that led you from
  symptom to root cause, written down as you go rather than reconstructed afterward. This
  path's journal.md format exists to make that chain reviewable by someone else.

- **D state**: A process in uninterruptible sleep - usually blocked on disk or network
  I/O, cannot be killed with a signal (even SIGKILL) until the I/O completes or times out.
  Shown as D in ps/top and in /proc/PID/stat field 3.

- **dentry**: A directory-entry cache object mapping a filename to an inode. Dentries are
  why repeated stat()/open() calls on the same path are cheap - the kernel doesn't re-walk
  the directory tree from disk each time.

- **descriptor (file)**: A small per-process integer that refers to an open file, socket,
  or pipe. Listed under /proc/PID/fd/, where each entry is a symlink to what it actually
  points at.

- **ephemeral port**: A short-lived, OS-assigned source port used for the client side of
  an outbound connection, drawn from a configurable range (Linux default roughly
  32768-60999). Exhausting the range under heavy short-lived-connection load causes
  connect() failures.

- **FHS**: The Filesystem Hierarchy Standard - the convention behind why /etc holds
  config, /var holds variable/runtime data, /usr holds installed software, and /tmp is
  wiped on reboot. Not enforced by the kernel, just widely followed.

- **hard link**: A second directory entry pointing at the same inode as an existing file -
  not a copy, not a shortcut. Deleting one link leaves the data intact until the inode's
  link count reaches zero and no process has it open.

- **inode**: The on-disk (or in-memory) structure holding a file's metadata - size,
  permissions, timestamps, and the block pointers to its data - but not its name; names
  live in directory entries that point at inodes.

- **MemAvailable**: The kernel's own estimate of RAM that can be given to a new process
  without swapping, accounting for reclaimable cache and buffers. The correct field to
  alert on for memory pressure - MemFree is not.

- **mount namespace**: A per-process view of the filesystem mount table, letting a
  container see a different root filesystem and mount points than the host or other
  containers, all from the same kernel.

- **ndots**: A resolv.conf option controlling how many dots a hostname needs before the
  resolver tries it as-is versus appending search-domain suffixes first. Kubernetes's
  default of 5 is a classic source of slow or duplicate DNS lookups for short names.

- **OOM killer**: The kernel subsystem that selects and kills a process when an
  allocation cannot be satisfied — system-wide, or within a cgroup. Exceeding
  memory.max does not itself kill anything: the kernel reclaims and stalls the
  cgroup first, and the OOM kill follows only when reclaim cannot free enough.
  Its choice is driven by an oom_score, not simply the largest process.

- **overlayfs**: A union filesystem that layers a writable directory on top of one or more
  read-only ones, presenting them as a single merged tree. This is what makes a
  container's writable layer sit on top of its shared, read-only image layers.

- **page cache**: RAM the kernel uses to cache file contents read from or written to disk,
  shown as Cached in /proc/meminfo. A full page cache is normal and healthy - it shrinks
  automatically under memory pressure.

- **PID 1**: The first process the kernel starts (init, systemd, or a container's
  entrypoint). It inherits any orphaned process as its new parent and is responsible for
  reaping them - a container without a real PID 1 accumulates zombies.

- **PSI**: Pressure Stall Information (/proc/pressure/{cpu,memory,io}) - kernel-reported
  percentages of time tasks spent stalled waiting for a resource, a more direct pressure
  signal than load average or free memory alone.

- **quota/period**: The two numbers that define a cgroup v2 CPU limit in cpu.max: quota is
  microseconds of CPU time allowed per period, period is the window length - 50000 100000
  means 0.5 CPU averaged over each 100ms window.

- **reaping**: The parent process calling wait()/waitpid() to collect a child's exit
  status after it terminates, which removes the child from the process table. A child that
  has exited but not been reaped is a zombie.

- **RSS**: Resident Set Size - the physical RAM a process currently occupies, as opposed
  to virtual size (vsize), which includes unmapped/reserved address space. Reported in
  pages in /proc/PID/stat and in kB in /proc/PID/status.

- **setuid**: A file permission bit causing an executable to run with its owner's user ID
  rather than the invoking user's - how passwd lets an unprivileged user modify a
  root-owned file, and a classic privilege-escalation target if misapplied.

- **sticky bit**: A permission bit on a directory (classically /tmp) restricting
  deletion/renaming of a file to its owner, the directory's owner, or root - regardless of
  the directory's own write permissions for other users.

- **TIME_WAIT**: A TCP socket state held by the side that closed a connection first,
  lasting roughly 2x the maximum segment lifetime, to absorb any delayed packets from the
  old connection. A large TIME_WAIT count on a busy proxy is normal, not a leak.

- **tmpfs**: A filesystem backed by RAM (and swap, if needed) rather than a disk -
  contents vanish on unmount or reboot. /dev/shm and often /tmp are tmpfs; useful for
  scratch space you never want touching real disk I/O.

- **umask**: A per-process mask that CLEARS bits (AND NOT, not subtraction) from the
  requested permissions when a new file or directory is created - the reason a shell's
  default umask 022 yields 644 files and 755 directories from nominal 666/777 requests.

- **VFS**: The Virtual File System - the kernel's abstraction layer that presents ext4,
  overlayfs, tmpfs, procfs, and every other filesystem type through one common set of
  syscalls (open, read, stat, ...).

- **zombie**: A process that has exited but whose parent hasn't yet called wait() to
  collect its exit status, shown as state Z. It holds no resources beyond a process-table
  slot, but a pile of zombies signals a parent that never reaps.

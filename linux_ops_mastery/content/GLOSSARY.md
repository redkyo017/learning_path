# Glossary

Plain-English definitions for terms used across this path without re-explaining
them inline. Alphabetical; each entry is one to three sentences.

- **0.0.0.0**: As a bind address, "every IPv4 address of this network namespace": a
  socket bound to it accepts connections on any interface, loopback included. It is not
  an address to connect to (Linux quietly treats it as "this host"), and it is different
  from 127.0.0.1, which only the
  namespace's own loopback can reach. See Day 6, *Listening on `127.0.0.1` versus
  `0.0.0.0`*.

- **atomic rename**: Replacing a file by writing a new one and `rename(2)`-ing it over
  the old name, so every reader sees either the whole old file or the whole new one. It
  gives the name a new inode, works only within one filesystem, and fails on a
  bind-mounted file. See Day 3, *A write lands on one of two inodes*.

- **bind mount**: A mount that makes an existing directory or file visible at a second
  path: the same inode tree, not a copy. It is how `docker run -v` and compose
  `volumes:` put host paths into a container, and a bind-mounted single file cannot be
  renamed over. See Day 1, *Bind mounts*.

- **capability**: A slice of root's privilege, granted independently
  (`CAP_NET_BIND_SERVICE` to bind port 80, `CAP_SYS_PTRACE` to trace another process) so a
  process needs less than full root. See `CapEff` in the /proc primer.

- **cgroup namespace**: A namespace that makes a process's own cgroup appear as the root
  of /sys/fs/cgroup, so a container reads its own memory.max and cannot see sibling or
  host cgroups. See Day 4, *cgroup v2: hierarchy and delegation*.

- **cgroup (v1 vs v2)**: A kernel mechanism that groups processes and limits/accounts
  their CPU, memory, and I/O. v1 mounted a separate hierarchy per resource controller; v2
  (the default on modern distros) is a single unified hierarchy -
  `/sys/fs/cgroup/<name>/memory.max` instead of a per-controller tree.

- **chain of evidence**: The ordered list of commands and their output that led you from
  symptom to root cause, written down as you go rather than reconstructed afterward. This
  path's journal.md format exists to make that chain reviewable by someone else.

- **child subreaper**: A process that has asked the kernel
  (`prctl(PR_SET_CHILD_SUBREAPER)`) to adopt orphaned descendants below it instead of
  PID 1. It then owes them a wait() once they exit. See Day 2, *wait, the reaping
  contract, and PID 1*.

- **container**: Ordinary processes on the host's one kernel, with namespaces limiting
  what they can see and cgroups limiting what they use. It is not a virtual machine. See
  foundations ch 00.

- **controlling terminal**: The terminal a session is attached to. The terminal driver
  turns Ctrl-C and Ctrl-Z into SIGINT and SIGTSTP for that terminal's foreground process
  group; `setsid` starts a session with none. See Day 2, *Process groups, sessions,
  controlling terminals*.

- **daemon-reload**: `systemctl daemon-reload` makes systemd re-read every unit file
  from disk. It is needed after editing a unit file because systemd does not watch
  /etc/systemd/system for changes and otherwise keeps its old cached copy. See Day 5,
  *`systemctl` verbs, what each actually does*.

- **dentry**: A directory-entry cache object mapping a filename to an inode. Dentries are
  why repeated stat()/open() calls on the same path are cheap - the kernel doesn't re-walk
  the directory tree from disk each time.

- **descriptor (file)**: A small per-process integer that refers to an open file,
  socket, or pipe; it points at a kernel-side open file description (own entry) that
  holds the offset and flags. Listed under /proc/PID/fd/, where each entry is a symlink
  to what it actually points at.

- **df versus du**: `df` reads a filesystem's live block accounting and knows nothing of
  names; `du` walks a directory tree adding up the files it can reach by name. They
  disagree when blocks are allocated but unnamed (a deleted-but-open file: df is higher)
  or when du crosses into another mounted filesystem (du is higher). See Day 1, *df
  versus du, and why they can disagree in both directions*.

- **DNS resolver**: The lookup code that turns a hostname into an address: it consults
  the sources in nsswitch.conf and then the DNS servers in resolv.conf. See Day 6, *DNS
  resolution order, and the `ndots` trap*.

- **D state**: A process in uninterruptible sleep - usually blocked on disk or network
  I/O, cannot be killed with a signal (even SIGKILL) until the I/O completes or times out.
  Shown as D in ps/top and in /proc/PID/stat field 3.

- **dup2**: The system call `dup2(old, new)`: make descriptor `new` point at the same
  open file description as `old`. The shell's `2>&1` is `dup2(1, 2)`, a one-time copy of
  where fd 1 points right now, which is why redirection order matters. See Day 3,
  *Redirection is descriptor surgery*.

- **effective UID**: The user ID whose permissions the kernel checks on every access, as
  opposed to the real UID, who started the process. They typically differ after a setuid
  program (such as `sudo` or `passwd`) is executed. See Day 5, *Real vs. effective UID*.

- **ephemeral port**: A short-lived, OS-assigned source port used for the client side of
  an outbound connection, drawn from a configurable range (Linux default roughly
  32768-60999). Exhausting the range under heavy short-lived-connection load causes
  connect() failures.

- **/etc/resolv.conf**: The file that tells the resolver which DNS servers to ask
  (`nameserver`), which suffixes to try (`search`), and options such as `ndots`. In a
  container it is usually a bind mount, and on a user-defined Docker network its
  nameserver is Docker's embedded DNS at 127.0.0.11. See Day 6, *DNS resolution order,
  and the `ndots` trap*.

- **exec**: The system call that replaces the program a process is running, keeping the
  same PID: new code and memory, argv reset. Open descriptors survive (unless
  close-on-exec), ignored signals stay ignored, and caught handlers reset to default.
  See Day 2, *fork, exec, and the gap between them*.

- **fdinfo**: `/proc/PID/fdinfo/N`: for one descriptor N, `pos` (the offset of the next
  read or write), `flags` (the octal open() flags), and `mnt_id`. It shows the open file
  description behind the descriptor. See Day 3, *Read the file first*.

- **FHS**: The Filesystem Hierarchy Standard - the convention behind why /etc holds
  config, /var holds variable/runtime data, /usr holds installed software, and /tmp holds
  scratch files that may be removed at any time (many distros clear it on reboot; do not
  rely on either). Not enforced by the kernel, just widely followed.

- **filesystem**: A structure on a device (or in memory) that organises data into files
  and directories, such as ext4, tmpfs, or overlayfs; the VFS presents them all through
  the same system calls. See foundations ch 01.

- **fork**: The system call that duplicates the calling process: same code and open
  descriptors, a new PID, copy-on-write memory. Parent and child share the open file
  descriptions, and with them the file offset. See Day 2, *fork, exec, and the gap
  between them*.

- **hard link**: A second directory entry pointing at the same inode as an existing file -
  not a copy, not a shortcut. Deleting one link leaves the data intact until the inode's
  link count reaches zero and no process has it open.

- **ICMP**: The IP control-message protocol, used by ping and to report errors such as
  "destination unreachable" and "packet too big". See Day 6, *MTU and the black-hole
  symptom*.

- **init / systemd**: init is PID 1, the first process. On most servers it is systemd,
  which starts and supervises services from unit files, collects their logs in the
  journal, and reaps orphans; in a container PID 1 is just the start command. See Day 5,
  *systemd unit anatomy*, and foundations ch 05.

- **inode**: The on-disk (or in-memory) structure holding a file's metadata - size,
  permissions, timestamps, and the block pointers to its data - but not its name; names
  live in directory entries that point at inodes.

- **journalctl**: The command that reads systemd's journal. `-u UNIT` selects one unit,
  `-b` the current boot, `--since "10 min ago"` a time window, `-p err` priority err and
  worse. See Day 5, *`journalctl` filters*.

- **kernel**: The always-running core of the operating system, which owns the hardware
  and shares out CPU, memory, disk, and network among programs. Everything else is a
  program in user space. See foundations ch 00.

- **link count**: The number of directory entries that point at an inode (the second
  column of `ls -l`). The data is freed only when it reaches zero and no process still
  has the file open. See Day 1, *Inode versus name*.

- **load average**: The three numbers in /proc/loadavg: the 1, 5, and 15 minute averages
  of tasks that are runnable (R) or in uninterruptible sleep (D). It is a queue length,
  not a CPU percentage, so a box with an idle CPU and many D-state tasks still shows a
  high load. See Day 4, *Load average is a queue, not a CPU gauge*.

- **longest matching prefix**: The routing rule: among all routes that contain the
  destination, the most specific one (largest prefix length) wins, so a /32 beats a /16
  whatever the order or metric. Metric only breaks ties between equal prefixes. See Day
  6, *The routing table as a decision procedure*.

- **loopback**: The virtual interface `lo` (127.0.0.1) whose traffic never leaves its
  own network namespace. See Day 6, *Listening on `127.0.0.1` versus `0.0.0.0`*.

- **MemAvailable**: The kernel's own estimate of RAM that can be given to a new process
  without swapping, accounting for reclaimable cache and buffers. The correct field to
  alert on for memory pressure - MemFree is not.

- **memory.max**: The cgroup v2 file holding a cgroup's memory limit in bytes (or `max`
  for none). Going over it first triggers reclaim and stalls the allocator; the cgroup's
  OOM kill follows only if reclaim fails, and the `oom_kill` counter in memory.events
  records it. See Day 4, *Exceeding `memory.max` does not mean dead — yet*.

- **mode bits (rwx)**: Three read/write/execute triads for owner, group, and other,
  written in octal (644). On a directory, x means "may be looked up by name" and r lists
  names; creating or deleting entries needs both w and x. See Day 5, *Mode bits and the
  directory execute bit*.

- **mount / mount point**: Mounting attaches a filesystem to a directory, called the
  mount point, so its files appear in the single tree starting at `/`. /proc/mounts
  lists what is mounted where. See foundations ch 01.

- **mount namespace**: A per-process view of the filesystem mount table, letting a
  container see a different root filesystem and mount points than the host or other
  containers, all from the same kernel.

- **MTU**: Maximum transmission unit: the largest packet an interface or path carries
  (1500 bytes is typical for Ethernet). A smaller MTU mid-path with the ICMP "packet too
  big" message filtered makes small requests work and large ones hang. See Day 6, *MTU
  and the black-hole symptom*.

- **namespace**: A kernel feature that gives a group of processes their own private view
  of one kind of system resource, such as mounts, PIDs, or the network, while sharing
  the one kernel. Containers are built from them. See foundations ch 06.

- **ndots**: A resolv.conf option controlling how many dots a hostname needs before the
  resolver tries it as-is versus appending search-domain suffixes first. Kubernetes's
  default of 5 is a classic source of slow or duplicate DNS lookups for short names.

- **network namespace**: A namespace giving a process its own interfaces, addresses,
  routes, firewall rules, and loopback. A socket bound to 127.0.0.1 in one is
  unreachable from another, and the caller gets an immediate "connection refused". See
  Day 6, *Listening on `127.0.0.1` versus `0.0.0.0`*.

- **nftables ruleset (table, chain, rule, policy)**: What `nft list ruleset` (or
  `iptables -L -n -v`) prints: tables hold chains, chains hold rules in evaluation
  order, and the first matching rule that gives a verdict (accept, drop, reject)
  decides; rules that only count or log let the packet fall through. A base chain's
  policy (ACCEPT or DROP) applies if no verdict was reached. See Day 6, *Reading `nftables`/`iptables` rules*.

- **nsswitch.conf**: /etc/nsswitch.conf, whose `hosts:` line sets the order of sources a
  name lookup tries, commonly `files dns` (/etc/hosts first, then DNS). It is consulted
  before resolv.conf's DNS settings matter. See Day 6, *DNS resolution order, and the
  `ndots` trap*.

- **OOM killer**: The kernel subsystem that selects and kills a process when an
  allocation cannot be satisfied — system-wide, or within a cgroup. Exceeding
  memory.max does not itself kill anything: the kernel reclaims and stalls the
  cgroup first, and the OOM kill follows only when reclaim cannot free enough.
  Its choice is driven by an oom_score, not simply the largest process.

- **oom_score_adj**: `/proc/PID/oom_score_adj`, a per-process bias from -1000 to 1000
  added when the kernel ranks victims for the OOM killer; -1000 means never kill this
  process. See Day 4, *The OOM killer: score, adjustment, cgroup versus global*.

- **open file description**: The kernel object created by an open() call that holds the
  file offset and flags; descriptors (own entry) are just numbers that point at one.
  fork() and dup2() make two descriptors share one, which is why they share an offset.
  See Day 3, *Descriptors 0/1/2 are a convention, not a law*.

- **orphan**: A process whose parent exited first. The kernel reparents it to the
  nearest child subreaper, or else to PID 1 of its PID namespace, which must reap it.
  See Day 2, *wait, the reaping contract, and PID 1*.

- **overlayfs**: A union filesystem that layers a writable directory on top of one or more
  read-only ones, presenting them as a single merged tree. This is what makes a
  container's writable layer sit on top of its shared, read-only image layers.

- **page cache**: RAM the kernel uses to cache file contents read from or written to disk,
  shown as Cached in /proc/meminfo. A full page cache is normal and healthy - it shrinks
  automatically under memory pressure.

- **PID 1**: The first process the kernel starts (init, systemd, or a container's
  entrypoint). It inherits any orphaned process as its new parent and is responsible for
  reaping them - a container without a real PID 1 accumulates zombies.

- **PID / PPID**: The process ID is the number the kernel gives each process; the PPID
  is the PID of its parent. Every process except the first descends from another by
  fork(). See foundations ch 02.

- **pipe**: A kernel buffer with a write-end descriptor and a read-end descriptor; `cmd1
  | cmd2` connects cmd1's fd 1 to the write end and cmd2's fd 0 to the read end. Shown
  as `pipe:[inode]` in /proc/PID/fd. See Day 3, *Pipes*, and foundations ch 04.

- **port**: A 16-bit number that picks which socket on an address receives a connection.
  Binding below 1024 needs `CAP_NET_BIND_SERVICE` by default (Docker relaxes this
  inside containers via `net.ipv4.ip_unprivileged_port_start=0`). See foundations ch 07.

- **/proc**: A virtual filesystem the kernel generates on the fly: files such as
  /proc/PID/status, /proc/meminfo, and /proc/net/tcp expose live kernel and process
  state and are not stored on disk. See foundations ch 00.

- **process**: A running instance of a program: its own PID, memory map, descriptor
  table, and state, created by fork() from another process. See foundations ch 02.

- **process group**: A set of processes, such as one pipeline, that terminal signals
  reach as a unit: Ctrl-C makes the terminal driver send SIGINT to the whole foreground
  process group. See Day 2, *Process groups, sessions, controlling terminals*.

- **process state**: The scheduling status shown by ps and in /proc/PID/stat field 3: R
  runnable, S interruptible sleep, D uninterruptible sleep, T stopped, Z zombie. Only R
  and D count toward load average. See Day 2, *Process states and load average*.

- **/proc/net/tcp**: One row per TCP socket in the reader's network namespace.
  `local_address` is hex IP:port with the IP's bytes reversed (`0100007F` is 127.0.0.1,
  `00000000` is 0.0.0.0) and the port as plain hex (`1F90` is 8080). See Day 6,
  *Listening on `127.0.0.1` versus `0.0.0.0`*.

- **PSI**: Pressure Stall Information (/proc/pressure/{cpu,memory,io}) - kernel-reported
  percentages of time tasks spent stalled waiting for a resource, a more direct pressure
  signal than load average or free memory alone.

- **quota/period**: The two numbers that define a cgroup v2 CPU limit in cpu.max: quota is
  microseconds of CPU time allowed per period, period is the window length - 50000 100000
  means 0.5 CPU averaged over each 100ms window.

- **real UID**: The user ID of whoever started the process. The kernel checks
  permissions against the effective UID instead; the two typically differ after a setuid
  program (such as `sudo` or `passwd`) is executed. See Day 5, *Real vs. effective UID*.

- **reaping**: The parent process calling wait()/waitpid() to collect a child's exit
  status after it terminates, which removes the child from the process table. A child that
  has exited but not been reaped is a zombie.

- **root**: The user with UID 0, for whom most permission checks are bypassed;
  capabilities split that power into independent pieces. Not to be confused with `/`,
  the root of the file tree. See Day 5, *Capabilities: root, decomposed*.

- **routing table / default route**: The kernel's list of destination prefixes and where
  to send each (`ip route`). The default route, 0.0.0.0/0, matches anything no more
  specific route covers. See Day 6, *The routing table as a decision procedure*.

- **RSS**: Resident Set Size - the physical RAM a process currently occupies, as opposed
  to virtual size (vsize), which includes unmapped/reserved address space. Reported in
  pages in /proc/PID/stat and in kB in /proc/PID/status.

- **RST**: The TCP reset flag. A host answers a connection attempt to a port with no
  listener with a RST, which the caller sees as an immediate "connection refused". See
  Day 6, *TCP states, the handshake, and port exhaustion*.

- **session**: A collection of process groups, usually tied to one controlling terminal.
  `setsid` starts a new session with no controlling terminal. See Day 2, *Process
  groups, sessions, controlling terminals*.

- **setgid**: A permission bit (mode 2000, `s` in the group x slot). On a directory, new
  files inherit the directory's group instead of the creator's primary group, the usual
  fix for shared team directories. See Day 5, *Setgid on directories*.

- **setuid**: A file permission bit causing an executable to run with its owner's user ID
  rather than the invoking user's - how passwd lets an unprivileged user modify a
  root-owned file, and a classic privilege-escalation target if misapplied.

- **SigCgt (and the other `Sig*` masks)**: Five lines in /proc/PID/status, each a
  16-digit hex bitmask in which bit N-1 stands for signal N (SIGTERM, 15, is bit 14).
  ShdPnd is signals pending for the whole process (where a kill() lands), SigPnd pending
  for one thread, SigBlk blocked, SigIgn ignored, and SigCgt caught, meaning a handler
  is installed. See Day 2, *Read the file first*, and foundations ch 03.

- **SIGCHLD**: Signal 17 on x86/ARM Linux, sent to a parent when one of its children
  stops or terminates. Its default action is to ignore it, but a real reaper catches it
  and calls wait() to collect the child. See Day 2, *Signals an operator must know
  cold*.

- **SIGKILL**: Signal 9: terminate the process at once. It cannot be caught, blocked, or
  ignored, and it is the only signal the kernel delivers to a stopped (T) process
  without a SIGCONT first. A process in D state still dies only when its I/O finishes.
  See Day 2, *Stopped means not scheduled*.

- **signal**: A small numbered notification the kernel or another process delivers to a
  process. Each signal has a disposition: take the default action, ignore it, or run a
  handler the program installed ("catch" it). The ones an operator must know: SIGHUP 1
  (hangup, by convention "reload config"), SIGINT 2 (Ctrl-C), SIGKILL 9, SIGTERM 15 (ask
  to terminate), SIGCHLD 17, SIGCONT 18 (resume), SIGSTOP 19, SIGTSTP 20 (Ctrl-Z);
  numbers are for x86/ARM Linux. See Day 2, *Signals an operator must know cold*.

- **SIGSTOP**: Signal 19 on x86/ARM Linux: suspend the process into state T, so the
  kernel stops scheduling it. Like SIGKILL it cannot be caught, blocked, or ignored;
  SIGCONT resumes it. See Day 2, *Stopped means not scheduled*.

- **SIGTSTP**: Signal 20 on x86/ARM Linux, the "terminal stop" sent to the foreground
  process group when you press Ctrl-Z. Unlike SIGSTOP it can be caught or ignored; by
  default it stops the process into state T. See Day 2, *Stopped means not scheduled*.

- **SNI**: Server Name Indication: the hostname a client sends in the TLS handshake so a
  server hosting several domains can present the right certificate. `openssl s_client
  -servername HOST` sends it; omitting it often shows a default or wrong certificate.
  See Day 6, *`openssl s_client` for certificate and SNI problems*.

- **socket**: An endpoint for network communication, which a process uses through a file
  descriptor like any other. See foundations ch 07.

- **stdin / stdout / stderr**: Descriptors 0, 1, and 2, which processes conventionally
  read input from, write output to, and write diagnostics to. Only a convention, set up
  by inheritance. See Day 3, *Descriptors 0/1/2 are a convention, not a law*.

- **sticky bit**: A permission bit on a directory (classically /tmp) restricting
  deletion/renaming of a file to its owner, the directory's owner, or root - regardless of
  the directory's own write permissions for other users.

- **strace**: A tool that prints each system call a process makes, with arguments and
  return value. `strace -f -p PID` attaches to a running process and its children; a
  call shown with no `= result` is the one currently blocking. It needs ptrace
  permission (same user, or `CAP_SYS_PTRACE`). See Day 2, *`strace -f -p PID`*.

- **swap**: Disk space where the kernel can park memory pages a process has not touched
  lately. tmpfs pages can be swapped; with swap off there is nowhere to push them, so
  the OOM killer is more likely to fire. See Day 4, *tmpfs is memory, and it is charged
  to a cgroup*, and foundations ch 06.

- **swap file (nvim)**: Neovim term, not the kernel's swap: the file where nvim keeps
  unsaved changes so they survive a crash, under `~/.local/state/nvim/swap/`, not next
  to the edited file. A leftover one is what triggers `E325: ATTENTION` on the next
  open. For the kernel's swap, see **swap**.

- **SYN_SENT**: The TCP state of a client that has sent its SYN and is waiting for the
  SYN-ACK. A socket stuck here means nothing answered (no route, or a silent firewall
  drop); a RST instead ends the attempt at once with "connection refused". See Day 6,
  *TCP states, the handshake, and port exhaustion*.

- **/sys**: A virtual filesystem exposing kernel objects as files, including devices
  and, under /sys/fs/cgroup, the cgroup tree. Like /proc, it is not stored on disk. See
  foundations ch 00.

- **system call**: A program's request to the kernel, the only door from user space into
  kernel space: open, read, fork, exec, and so on. See Day 2, *fork, exec, and the gap
  between them*, and foundations ch 00.

- **tcpdump**: A packet-capture tool. `tcpdump -i any -n host IP and port PORT` captures
  one conversation (`-n` skips name lookups) and `-c 20` stops after 20 packets. A SYN
  leaving with no SYN-ACK back points to routing or a firewall. See Day 6, *`tcpdump` —
  the two or three invocations that matter*.

- **three-way handshake**: How TCP opens a connection: the client sends SYN, the server
  answers SYN-ACK, the client sends ACK. Until the second packet arrives the client sits
  in SYN_SENT. See Day 6, *TCP states, the handshake, and port exhaustion*.

- **TIME_WAIT**: A TCP socket state held by the side that closed a connection first,
  lasting roughly 2x the maximum segment lifetime, to absorb any delayed packets from the
  old connection. A large TIME_WAIT count on a busy proxy is normal, not a leak.

- **tmpfs**: A filesystem backed by RAM (and swap, if needed) rather than a disk -
  contents vanish on unmount or reboot. /dev/shm and often /tmp are tmpfs; useful for
  scratch space you never want touching real disk I/O.

- **UID / GID**: The numbers that identify a user and a group; the kernel checks
  numbers, and names come from /etc/passwd and /etc/group. See foundations ch 05.

- **umask**: A per-process mask that CLEARS bits (AND NOT, not subtraction) from the
  requested permissions when a new file or directory is created - the reason a shell's
  default umask 022 yields 644 files and 755 directories from nominal 666/777 requests.

- **unit file**: A systemd text file describing one unit, such as a service. A service
  has a `[Unit]` section (metadata, dependencies), `[Service]` (how to run it), and
  `[Install]` (what enabling it hooks into). Edit it, then run daemon-reload. See Day 5,
  *systemd unit anatomy*.

- **user space vs kernel space**: Two zones separated by a hard border enforced by the
  CPU: programs run in user space and cannot touch hardware or each other's memory; only
  the kernel's own code runs in kernel space. Programs cross the border only through
  system calls. See foundations ch 00.

- **VFS**: The Virtual File System - the kernel's abstraction layer that presents ext4,
  overlayfs, tmpfs, procfs, and every other filesystem type through one common set of
  syscalls (open, read, stat, ...).

- **whiteout**: A marker overlayfs writes into the upperdir to hide a name that exists
  only in a lower layer. The lower layer's bytes are not changed. See Day 1, *overlayfs:
  lowerdir, upperdir, merged*.

- **xargs**: Reads items from stdin and runs a command with them as arguments, batching
  many per invocation. Paired with `find -print0` and `xargs -0`, NUL-delimited names
  make it safe for spaces. See Day 3, *`find -exec` versus `xargs -0`*.

- **zombie**: A process that has exited but whose parent hasn't yet called wait() to
  collect its exit status, shown as state Z. It holds no memory or CPU, but it keeps its
  PID and exit status until reaped, and PIDs are a limited pool (`pid_max`, or a
  container's `pids.max`), so a pile of zombies signals a parent that never reaps and
  can eventually block new processes. See Day 2, *wait, the reaping contract, and PID
  1*.

---

## Bash Scripting (days 08–10)

**argument contract** — The formal interface of a script: which positional
arguments and flags it accepts, what it considers invalid, and which exit codes
each outcome produces. Validated at entry with `[[ $# -lt N ]]`, `${1:?msg}`,
and type checks before any destructive command is reached.

**exit code** — The integer a process returns to its parent when it exits.
Zero means success; any non-zero value means failure. The parent reads it via
`$?` immediately after the child exits.

**`getopts`** — POSIX built-in for parsing `-x` style short option flags. Use
`shift $((OPTIND - 1))` after the loop to remove parsed flags, leaving
remaining positional arguments in `$@`.

**here-document** — `<<EOF` followed by lines up to a closing `EOF` supplies
those lines as a command's stdin; the shell builds an anonymous temp file or
pipe and connects it to fd 0. See Day 3, *Pipes*.

**`mktemp -d`** — Creates a uniquely-named temporary directory and prints its
path. Atomic, so safe against concurrent calls. Pair it with `trap cleanup
EXIT; trap 'exit 130' INT; trap 'exit 143' TERM` (where `cleanup` runs `rm
-rf` on the directory) so cleanup runs once on exit or interrupt. See Day 9,
*The pattern*.

**PIPESTATUS** — A bash array holding the exit code of each stage in the most
recently executed pipeline. `${PIPESTATUS[0]}` is the first stage's code,
`${PIPESTATUS[1]}` the second. Bash-only — not available in POSIX sh.

**positional parameters** — The arguments a script or function receives:
`$1`...`$N` individually, `$#` their count, `"$@"` all of them as separate
words (only when quoted; prefer it to `$*`), `$0` the script's name. `shift` drops `$1` and
moves the rest down. See Day 10, *The underlying truth*.

**process substitution** (`<(cmd)`) — A bash construct that runs `cmd` in a
subshell and presents its output as a file descriptor. `while read line; done
< <(cmd)` runs the while body in the current shell (not a subshell), so
variable assignments and trap handlers work correctly. Bash-only — not
available in POSIX sh.

**redirection** — Rewiring a command's standard descriptors before it runs:
`>file` points fd 1 at a file, `2>&1` copies where fd 1 points to fd 2,
`<file` feeds fd 0. Processed left to right, so `>file 2>&1` and `2>&1 >file`
differ. See Day 3, *Redirection is descriptor surgery*.

**`set -euo pipefail`** — A three-flag header for reliable bash scripts: `-e`
aborts on non-zero exit, `-u` aborts on unset variable, `-o pipefail` makes
the pipeline's exit code the last (rightmost) non-zero stage's code rather than
simply the last stage's.

**subshell** — A child process created by the shell to run a group of commands.
Constructed by `(cmds)`, `$(cmds)`, or any pipeline stage. Inherits the
parent's environment at fork time; variable assignments inside it are invisible
to the parent.

**trap** — A shell built-in that registers a handler to run when the shell
receives a signal or exits. Syntax: `trap 'handler' SIGNAL...`. Common
signals: `EXIT` (fires on any exit), `INT` (Ctrl-C), `TERM` (kill). Traps are
per-process; they do not fire in child processes. An INT or TERM handler does
not end the script unless it calls `exit`, so use `trap cleanup EXIT; trap
'exit 130' INT; trap 'exit 143' TERM`. See Day 9, *Breaking it down*.

**`${var:?msg}`** — Expands to the value of `var` if it is set and non-empty;
otherwise the shell aborts with `msg`. It is how a script demands a required
argument (`${1:?PID is required}`), whereas `${1:-}` supplies an empty default
and bypasses `set -u`. See Day 10, *The underlying truth*.

# Coverage Audit

This path is ordered by the kernel's structure, not by a certification syllabus.
That is deliberate — see `STRATEGY.md`. The risk of ordering it that way is
silently dropping something a systematic sweep would have caught, so this file
is the proof that nothing was missed by accident.

Every LPIC-1 and LFCS objective below is either mapped to the day that covers
it, or marked **SKIPPED** with its reason in the third section. There is no
third category.

---

## LPIC-1 objective coverage

### Exam 101-500

| Objective | Topic | Day | Where |
|---|---|---|---|
| 101.1 | Determine and configure hardware settings | 1, 4 | `/proc` and `/sys` as the kernel's exported truth; `/proc/cpuinfo`, `/proc/meminfo` |
| 101.2 | Boot the system | 5 | systemd targets and the boot sequence; `journalctl -b` |
| 101.3 | Change runlevels / boot targets, shutdown, reboot | 5 | `systemctl` targets, `isolate`; SysV runlevels **SKIPPED** |
| 102.1 | Design hard disk layout | — | **SKIPPED** |
| 102.2 | Install a boot manager | — | **SKIPPED** |
| 102.3 | Manage shared libraries | 2 | `/proc/PID/maps`, `ldd`, `/proc/PID/exe` |
| 102.4 | Debian package management | 5 | `apt` in `Dockerfile.ws`; reading what a package installed |
| 102.5 | RPM and YUM/DNF | 5 | named as the Amazon Linux equivalent; not drilled |
| 102.6 | Linux as a virtualization guest | 4 | containers as namespaced processes, not VMs; cgroup limits |
| 103.1 | Work on the command line | 3 | shell as an operator language; quoting, exit codes, `set -euo pipefail` |
| 103.2 | Process text streams using filters | 3 | `grep`/`sed`/`awk` operator subset; `sort \| uniq -c \| sort -rn` |
| 103.3 | Perform basic file management | 1 | inode vs name, links, `find`, `stat` |
| 103.4 | Use streams, pipes and redirects | 3 | redirection as descriptor surgery; `>file 2>&1` vs `2>&1 >file` |
| 103.5 | Create, monitor and kill processes | 2 | full day: process table, signals, states, `strace` |
| 103.6 | Modify process execution priorities | 4 | `nice`/`renice`, and why cgroup quota supersedes them in containers |
| 103.7 | Search text files using regular expressions | 3 | `grep`/`sed` on real log triage |
| 103.8 | Basic file editing | 1, 7 | neovim survival (Day 1) and the operator payload (Day 7) |
| 104.1 | Create partitions and filesystems | — | **SKIPPED** |
| 104.2 | Maintain the integrity of filesystems | 1 | `df` vs `du`, ENOSPC, unlinked-but-open inodes; `fsck` **SKIPPED** |
| 104.3 | Control mounting and unmounting of filesystems | 1 | `/proc/mounts`, `/proc/self/mountinfo`, bind mounts, overlayfs |
| 104.5 | Manage file permissions and ownership | 5 | full section: mode bits, setuid/setgid/sticky, umask, the directory execute bit |
| 104.6 | Create and change hard and symbolic links | 1 | `ls -li`, dangling symlinks, why `rm` removes a name |
| 104.7 | Find system files, place files in the correct location | 1 | FHS as a set of promises; `find` |

### Exam 102-500

| Objective | Topic | Day | Where |
|---|---|---|---|
| 105.1 | Customize and use the shell environment | 3 | environment, `/proc/PID/environ`, exported vs shell variables |
| 105.2 | Customize or write simple scripts | 3, and every lab | `break.sh`/`verify.sh` are POSIX shell the learner reads and modifies |
| 106.1 | Install and configure X11 | — | **SKIPPED** |
| 106.2 | Graphical desktops | — | **SKIPPED** |
| 106.3 | Accessibility | — | **SKIPPED** |
| 107.1 | Manage user and group accounts | 5 | `/etc/passwd`, `/etc/shadow`, `/etc/group`, `useradd`, real vs effective uid |
| 107.2 | Automate system administration tasks | 5 | systemd timers vs cron, with the container replacement named |
| 107.3 | Localisation and internationalisation | — | **SKIPPED** |
| 108.1 | Maintain system time | — | **SKIPPED** |
| 108.2 | System logging | 3, 5 | log triage and rotation (Day 3); journald and its container replacement (Day 5) |
| 108.3 | Mail Transfer Agent basics | — | **SKIPPED** |
| 108.4 | Manage printers and printing | — | **SKIPPED** |
| 109.1 | Fundamentals of internet protocols | 6 | addressing, routing, TCP states, ports |
| 109.2 | Persistent network configuration | 6 | `ip addr`/`ip link`/`ip route`; persistence is the orchestrator's job in ECS |
| 109.3 | Basic network troubleshooting | 6 | the whole day — the five-rung connectivity ladder |
| 109.4 | Configure client side DNS | 6 | `/etc/resolv.conf`, `/etc/nsswitch.conf`, the `ndots` trap |
| 110.1 | Perform security administration tasks | 5 | setuid binaries, capabilities, `sudo` and its audit trail |
| 110.2 | Setup host security | 5, 6 | least privilege, capability dropping; read-level `nftables` literacy |
| 110.3 | Securing data with encryption | 6 | `openssl s_client` for TLS diagnosis; at-rest encryption **SKIPPED** |

---

## LFCS domain coverage

| Domain | Weight | Days | Notes |
|---|---|---|---|
| Essential Commands | ~25% | 1, 3 | filesystem model, links, find, the grep/sed/awk triage subset, redirection |
| Operation of Running Systems | ~20% | 2, 4, 5 | process table, signals, states, cgroups, resource saturation, boot, journald |
| User and Group Management | ~10% | 5 | accounts, groups, uid/gid semantics, sudo, capabilities |
| Networking | ~12% | 6 | interfaces, routes, DNS, sockets, TLS, packet capture |
| Service Configuration | ~20% | 5, 6 | systemd units and ordering; nginx as a real proxy; container equivalents |
| Storage Management | ~13% | 1, 4 | mount tree, overlayfs, tmpfs and its cgroup accounting; LVM/RAID **SKIPPED** |

---

## Deliberately skipped, and why

Each of these is a gap by choice. The reason is always the same shape: it does
not occur in the work this path is for — debugging containers and instances you
can replace rather than repair.

**Printing and CUPS (108.4).** No printer has ever been attached to an ECS
task. This objective exists because LPIC-1 predates the cloud.

**X11, graphical desktops, accessibility (106.1-106.3).** Servers have no
display. Every interaction in this path is over a shell.

**SysV init and `/etc/init.d` (part of 101.3).** systemd is what every current
distribution ships. Knowing SysV helps only when maintaining a system old
enough that its other problems dominate.

**GRUB and bootloader repair (102.2).** An instance that will not boot is
replaced, not repaired — you terminate it and let the ASG launch another. On
Fargate there is no bootloader at all. The one case where this matters, a
root volume you must recover, is better served by detaching it and attaching
it to a working instance.

**Partitioning, mkfs, and fsck (102.1, 104.1, part of 104.2).** Storage is
provisioned declaratively — an EBS volume in Terraform, an ephemeral volume in
a task definition. Day 1 covers reading the mount tree, which is what you
actually do at 2am; creating filesystems by hand is not.

**LVM and RAID administration (part of Storage Management).** Same reasoning:
EBS resizing and snapshots replace both, and the failure modes are AWS-side.

**Mail Transfer Agents (108.3).** Application concern, delegated to SES or a
provider in every environment this learner touches.

**Localisation and time zones (107.3, 108.1).** Servers run UTC. Time
synchronisation is handled by the hypervisor or the Amazon Time Sync Service,
and a clock problem presents as a certificate or a token failure, which
Day 6 does cover.

**Package build tooling.** Consuming packages is covered; producing them is a
different job.

**Encryption at rest (part of 110.3).** KMS and EBS encryption are AWS
configuration, not Linux administration. TLS in transit *is* covered, on
Day 6, because that is what breaks in a way a shell can diagnose.

### Closing a gap later, if the job asks

One line each — the cheapest path from here, not a course.

- **Storage (LVM, mkfs, fsck):** attach a spare EBS volume to a scratch EC2
  instance and take it through `pvcreate` → `vgcreate` → `lvcreate` → `mkfs` →
  `mount` → `lvextend` → `resize2fs`. Two hours, and the muscle memory sticks.
- **GRUB and boot repair:** break `/etc/fstab` on a disposable VM, then recover
  from the rescue shell. One hour. Do it on a VM, never on a container.
- **SysV init:** read one real `/etc/init.d` script end to end and write the
  systemd unit that replaces it. Thirty minutes.
- **Localisation and time:** `timedatectl`, `/etc/localtime`, and one `chrony`
  configuration. Twenty minutes.
- **MTA:** configure one `msmtp` relay to SES. Thirty minutes, and it is the
  only MTA shape you are likely to need.
- **Printing, X11, accessibility:** leave these. If the job ever needs them,
  the job has changed.

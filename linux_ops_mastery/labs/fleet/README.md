# The lab fleet

Six containers, one Docker Compose project named `linuxops`, one network named
`linuxops_net`. Everything the seven days break, they break in here.

Nothing in this fleet touches your host beyond a bridge network and one named
volume. Disk-full happens on a 24 MiB tmpfs; the OOM kill happens inside a
64 MiB cgroup. That is the point: real failure modes, on a laptop, safely.

## Bring-up

**Requires Docker Compose v2.15 or newer.** The Day 5 overlay uses
`cgroup: host`, which older Compose silently does not understand. Check first:

```bash
docker compose version
```

```bash
cd linux_ops_mastery/labs/fleet
cp .env.example .env          # optional; a default password is built in
docker compose -p linuxops up -d --build
docker compose -p linuxops ps
```

The first build pulls Ubuntu and installs the toolbox — a few minutes once,
then cached. `ws` is the container you live in:

```bash
docker compose -p linuxops exec ws bash
```

Smoke test, from inside `ws`:

```bash
curl -s http://app:8080/healthz     # healthy
curl -s http://proxy/              # ok   (through nginx)
```

No host ports are published by default. Every lab reaches the services from
inside `ws`, and an occupied host port turns bring-up into a confusing
failure. If you want `http://localhost:8080/` on macOS, uncomment the `ports:`
lines in `docker-compose.yml`.

## Teardown

```bash
cd linux_ops_mastery/labs/fleet
docker compose -p linuxops down -v --remove-orphans
../verify-teardown.sh
```

`verify-teardown.sh` exits non-zero while anything survives — containers, the
network, the `linuxops_pgdata` volume, or a dangling built image. Run it. "I
think I stopped it" is not an operational statement.

Day 5 adds a container from the overlay file, and the overlay has to be named
again to remove it:

```bash
docker compose -p linuxops \
  -f docker-compose.yml -f docker-compose.sysd.yml \
  down -v --remove-orphans
```

## What is in the fleet

| Service | Image / build | Role |
|---|---|---|
| `ws` | `Dockerfile.ws` (ubuntu:24.04) | Primary shell, full toolbox |
| `slim` | `alpine:3.20` | Busybox only — the strip-the-toolbox target |
| `app` | `app/Dockerfile` (python:3.12-alpine) | The service under investigation |
| `db` | `postgres:16-alpine` | Real sockets, descriptors, connections |
| `proxy` | `Dockerfile.proxy` (nginx:1.27.5-alpine) | Day 6's ladder |
| `sysd` | `Dockerfile.sysd` (overlay) | Day 5 only: systemd as PID 1 |

Compose names the containers `linuxops-<service>-1`, so `ws` is
`linuxops-ws-1` when you want `docker inspect`.

`slim` never gets extra packages. Not for one exercise, not for convenience.
Every day's "Strip the toolbox" section depends on it staying bare. That rule
is about `slim` alone.

`proxy` is the one service built rather than pulled, and `Dockerfile.proxy` is
`nginx:1.27.5-alpine` plus exactly two packages, `iproute2` and `nftables`.
That base is pinned to the exact patch because `seed/nginx.conf` uses
`resolver local=on`, which needs nginx >= 1.27.3. Day 6
takes this container's network apart from the inside: fault 2 is
`ip route del default`, fault 3 is an nftables DROP rule. The stock nginx image
has no `nft` at all and only busybox's unreliable `ip` applet, so two of the
five rungs would be unrunnable. The base tag is still pinned.

### The `app` API

All GET, all on port 8080, all plain text:

| Path | Effect |
|---|---|
| `/` | 200, body `ok` |
| `/healthz` | 200, body `healthy` |
| `/burn?seconds=N` | Busy-loops N seconds in a thread (Day 4) |
| `/balloon?mb=N` | Allocates N MiB in the app process and holds it |
| `/balloon?mb=N&child=1` | Forks; the child holds it. 202 + child pid |
| `/log?n=N` | Appends N lines to `$LOG_PATH` (Day 1) |
| `/fail?code=C` | Responds with status C. 200–599 only; 1xx is a 400 |
| `/fail?code=C&sticky=1` | Responds C, and arms sticky mode |
| `/fail?code=200` | Clears sticky mode, with or without `sticky=1` |

Sticky mode poisons `/` and `/healthz` — what a health check or a proxy calls
— and nothing else. The control endpoints (`/fail`, `/burn`, `/balloon`,
`/log`) always answer for themselves, so the fault can always be cleared and
Day 4 can still drive `/burn` while Day 6's fault is armed:

```bash
curl -s -o /dev/null -w '%{http_code}\n' 'http://app:8080/fail?code=503&sticky=1'
curl -s -o /dev/null -w '%{http_code}\n' http://app:8080/healthz   # 503
curl -s -o /dev/null -w '%{http_code}\n' http://app:8080/          # 503
curl -s -o /dev/null -w '%{http_code}\n' 'http://app:8080/burn?seconds=1'  # 200
curl -s -o /dev/null -w '%{http_code}\n' 'http://app:8080/fail?code=200'
curl -s -o /dev/null -w '%{http_code}\n' http://app:8080/healthz   # 200
```

Day 4 needs both balloon forms, and the difference is the whole point:

- `/balloon?mb=120` — the OOM killer takes python, PID 1 (`sh`) runs its
  `exit $?`, the container exits 137 and `restart: unless-stopped` replaces it
  with a **new** runc task in a **new** leaf cgroup, where `memory.events` is
  back at `oom_kill=0`. Read the counter after that and you read a lie.
- `/balloon?mb=120&child=1` — the killer takes the forked child instead.
  python and PID 1 survive, the container never exits, the cgroup is the same
  one, and `oom_kill` in `memory.events` has actually incremented where you
  can see it. Any lab that asserts on `oom_kill` must use this form. The child
  writes `500` to its own `/proc/self/oom_score_adj` before it allocates, so
  it is the victim by construction rather than by weight — raising your own
  score needs no privilege, and `cat /proc/<pid>/oom_score_adj` inside `app`
  shows it.

The parent answers `202` immediately with the child's pid and never waits on
it; `SIGCHLD` is set to `SIG_IGN` at start-up so the kernel reaps and this
service never manufactures a zombie of its own (Day 2 counts zombies across
the whole container).

`/burn` is likewise not tied to the request that started it: it runs on its own
daemon thread, so a 45-second burn keeps accumulating `nr_throttled` in
`cpu.stat` long after curl has returned — and survives a `child=1` OOM kill,
since that kill lands on the child.

Environment: `BIND_ADDR` (`0.0.0.0`), `PORT` (`8080`), `LOG_PATH`
(`/var/log/app.log`), `IGNORE_SIGTERM` (`0`).

`/var/log` in `app` is a 24 MiB tmpfs, and `app` runs under `mem_limit: 64m`
with `cpus: 0.20`. Those three numbers are what make Days 1 and 4 work; do not
raise them because a lab "did not do anything" — that *is* the lab.

The 24 is not a typo for 64, and the two numbers are coupled:

> **tmpfs size + app RSS must stay under `mem_limit`, or Day 1's ENOSPC
> becomes Day 4's OOM.**

tmpfs pages are shmem, and shmem is charged to the memory cgroup of whichever
process faults them in. `memswap_limit` equals `mem_limit`, so there is no
swap to push them to and they cannot be reclaimed. A 64 MiB tmpfs inside a
64 MiB limit means `dd` into `/var/log` kills the container (exit 137) before
the filesystem ever returns `ENOSPC`, and Day 1's incident arrives wearing
Day 4's clothes. 24 MiB plus python's ~18 MiB RSS leaves headroom, and 24 MiB
still fills in seconds.

### The log fixture

`seed/gen-logs.sh` runs **inside** `app` and writes a fixture where exactly one
line out of N carries `status=500`:

```bash
docker compose -p linuxops exec app \
  sh /labs/fleet/seed/gen-logs.sh 5000 --needle 4f2a91be -o /var/log/app.log
```

It is POSIX `sh` and busybox `awk`, because `app` is Alpine. The needle is
printed on stderr, never into the file.

## Why `ws` needs `SYS_PTRACE`

Docker drops `CAP_SYS_PTRACE` from every container by default. Without it,
`strace` cannot attach to a process it did not itself start:

```
strace: attach: ptrace(PTRACE_SEIZE): Operation not permitted
```

That is not a broken `strace` and not a missing package. It is the kernel
refusing `ptrace(2)` because the calling process lacks the capability. So
`ws` — and only `ws` — carries `cap_add: [SYS_PTRACE]`, plus
`security_opt: ["seccomp=unconfined"]` so the default seccomp filter does not
block the syscall on top of that.

Joining `ws`'s PID namespace needs no compose setting at all — Docker's PID
mode has no "shareable" value, only `host` and `container:<name>`:

```bash
docker run --rm -it --pid=container:linuxops-ws-1 alpine:3.20 sh
```

`ws` does set `ipc: shareable`, which is the real thing under that name: it
lets another container share this one's SysV IPC and `/dev/shm`.

Read the capability set for yourself rather than trusting this paragraph:

```bash
docker compose -p linuxops exec ws grep Cap /proc/self/status
docker compose -p linuxops exec app grep Cap /proc/self/status
```

## arm64 note

The host is Apple Silicon. Every tag this fleet pins — `ubuntu:24.04` and
`alpine:3.20` and `postgres:16-alpine` in `docker-compose.yml`,
`python:3.12-alpine` in `app/Dockerfile`, `nginx:1.27.5-alpine` in
`Dockerfile.proxy` — publishes a `linux/arm64` manifest, so Docker pulls the
native image and there is **no `platform:` key anywhere in this fleet**.

Do not add one. `platform: linux/amd64` silently drags every container through
qemu emulation: five to twenty times slower, and — worse for this course —
`/proc`, timing, and syscall behaviour stop being the truth you are trying to
read. If you ever see `qemu` in the process list, something added a platform
override.

Tags are pinned, never floating, so the fleet you debug in on Day 7 is the
fleet you built on Day 1.

## Day 5: the systemd container

Day 5 needs a container where `systemctl`, unit files, and `journalctl` are
real rather than simulated. That means systemd running as PID 1, which needs
`privileged: true` and `cgroup: host` (`--cgroupns=host`) — and that
combination is **the most fragile thing in this course on Docker Desktop for
macOS**. Docker Desktop runs a Linux VM whose cgroup hierarchy it manages
itself; letting a container's systemd take over parts of it works on some
versions and not others.

Bring it up:

```bash
cd linux_ops_mastery/labs/fleet
docker compose -p linuxops \
  -f docker-compose.yml -f docker-compose.sysd.yml up -d --build sysd
docker compose -p linuxops \
  -f docker-compose.yml -f docker-compose.sysd.yml exec sysd bash
systemctl is-system-running --wait     # degraded is fine; failed is not
```

If `sysd` exits within a second or two, do not start editing the Dockerfile.
Use Colima, which gives you a plain Linux VM with a normal cgroup v2 tree.

### Colima fallback

```bash
brew install colima docker
colima start --arch aarch64 --cpu 2 --memory 4 --vm-type=vz
docker context use colima
# then bring the fleet up exactly as above
```

`docker context use default` puts you back on Docker Desktop. The two contexts
have separate images, volumes and containers, so run the fleet in one of them
at a time — and run `../verify-teardown.sh` in **both** contexts on the last
day.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `invalid PID mode`, (5) | `pid: shareable` is an IPC mode | Use `ipc: shareable` |
| `strace` EPERM, note (1) | Not in `ws`; no `SYS_PTRACE` | Run it in `ws` |
| Same EPERM inside `ws` | Stale container, or seccomp | Recreate `ws`, note (4) |
| `sysd` exits at once, (2) | cgroupns or privileged refused | Read logs, then Colima |
| cgroup read-only, (3) | `/sys/fs/cgroup` not writable | Check `:rw`, then Colima |
| `docker stop app` waits 10s | PID 1 is `sh`; it eats SIGTERM | Day 2. Read `/proc/1` |
| `app` dies under load | cgroup OOM kill at 64 MiB | Day 4 expects this; leave it |
| Day 1 ends in exit 137 | tmpfs is charged to the cgroup | Keep tmpfs under `mem_limit` |
| `proxy` 502, `app` is up | Upstream address cached 10s | Wait 10s or `nginx -s reload` |
| Bring-up: no DB password | Compose run from the wrong dir | Run it from `labs/fleet/` |
| `db` rejects a new password | `linuxops_pgdata` kept the old | `down -v`, then up |
| `qemu` in the process list | A `platform:` key crept in | Remove it; see arm64 note |
| `/labs` is not there | Only `ws`, `app`, `sysd` mount it | Use those, or `docker cp` |
| Writing to `/labs` fails | Mounted read-only, on purpose | Use `/tmp` or `/var/log` |

**(1)** The message in full:

```
strace: attach: ptrace(PTRACE_SEIZE): Operation not permitted
```

Not a broken `strace`, not a missing package: the kernel refusing `ptrace(2)`
to a process without `CAP_SYS_PTRACE`. Confirm with
`grep Cap /proc/self/status` in `ws` and in `app` — the bit sets differ.

**(2)** `sysd` up for a second and then `Exited (255)`. Look first:

```bash
docker compose -p linuxops \
  -f docker-compose.yml -f docker-compose.sysd.yml logs sysd
```

**(3)** Both of these are the same fault, one layer apart:

```
Failed to mount cgroup at /sys/fs/cgroup/systemd: Read-only file system
Failed to create /init.scope control group: Read-only file system
```

systemd needs to write the unified hierarchy. Check that the overlay still
binds `/sys/fs/cgroup:/sys/fs/cgroup:rw` and sets `cgroup: host`, recreate the
container, and if it still fails, move to Colima. Do not edit
`Dockerfile.sysd` — the image is not the problem, the VM is.

**(4)** Recreating one service:

```bash
docker compose -p linuxops up -d --force-recreate ws
```

**(5)** If a container refuses to start with:

```
Error response from daemon: invalid PID mode: shareable
```

someone put `pid: shareable` back into `docker-compose.yml`. Docker's PID mode
accepts only `host` and `container:<name>` -- `shareable` belongs to `ipc`, and
the daemon rejects the container outright, which takes the whole fleet down
with it. Use `ipc: shareable`, which is what `ws` already sets. Joining ws's
PID namespace never needed a compose key in the first place:

```bash
docker run --rm -it --pid=container:linuxops-ws-1 alpine:3.20 sh
```

## Files

| File | What it is |
|---|---|
| `docker-compose.yml` | The five always-on services |
| `docker-compose.sysd.yml` | Day 5 overlay: `sysd` only |
| `Dockerfile.ws` | Ubuntu toolbox and the shipped `init.lua` |
| `Dockerfile.sysd` | systemd as PID 1 |
| `Dockerfile.proxy` | nginx plus `iproute2` and `nftables` |
| `app/Dockerfile` | The service image, with Day 2's defect |
| `app/app.py` | The service itself, standard library only |
| `seed/nginx.conf` | proxy to app, resolution deferred to request time |
| `seed/gen-logs.sh` | Log fixture generator, runs inside `app` |
| `.env.example` | Placeholder password. Never commit a real `.env` |
| `../lib/common.sh` | `compose`, `in_ws`/`in_app`/`in_slim`, `symptom` |
| `../verify-teardown.sh` | Proves the fleet left nothing behind |

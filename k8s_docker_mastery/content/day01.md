# Day 1 — Docker Internals & Image Mastery

## Why this matters

As a senior backend engineer working on microservices and API gateways, you package and ship containers every day. In platforms like AWS ECS or Kubernetes, a container is treated as the atomic unit of deployment. But if you treat a container as a "lightweight virtual machine," you will inevitably hit obscure production outages: zombie processes ignoring SIGTERM during rollouts, sudden OOMKilled crashes with 137 exit codes, multi-gigabyte image pull delays causing autoscaling lag, and privilege escalation vulnerabilities during security audits.

A container is not a virtual machine. A container is simply a standard Linux process running with kernel constraints. Once you understand the three kernel pillars (namespaces, cgroups, and OverlayFS) and the OCI image format that feeds them, container behavior ceases to be magic and becomes entirely deterministic.

**Mac note (applies to the whole course):** on macOS/Docker Desktop every container runs inside a hidden Linux VM (kernel `linuxkit`, 7.0.x on the machine this course was verified on). `/proc`, namespaces, cgroups and overlay mounts exist in that VM, not on your Mac. The lab shows how to step into it.

---

## The layer this covers

```
┌─────────────────────────────────────────────────────────────────┐
│               Userspace Client / CLI (docker CLI)               │
└────────────────────────────────┬────────────────────────────────┘
                                 │ REST API (unix socket)
┌────────────────────────────────▼────────────────────────────────┐
│               Docker Engine Daemon (dockerd)                    │
│     (API, networks, volumes, build via BuildKit, healthchecks)  │
└────────────────────────────────┬────────────────────────────────┘
                                 │ gRPC
┌────────────────────────────────▼────────────────────────────────┐
│               High-Level Container Runtime (containerd)         │
│       (image pull/unpack, snapshots, container lifecycle)       │
└────────────────────────────────┬────────────────────────────────┘
                                 │ ttrpc
┌────────────────────────────────▼────────────────────────────────┐
│        containerd-shim-runc-v2  (one per container/pod)         │
│  stays alive as the container's parent: reaps it, holds stdio,  │
│  reports the exit status; containerd/dockerd can restart        │
│  without killing the container                                  │
└────────────────────────────────┬────────────────────────────────┘
                                 │ OCI Runtime Spec (config.json) → exec
┌────────────────────────────────▼────────────────────────────────┐
│               Low-Level OCI Runtime (runc / crun)               │
│       (invoked to set the container up, then it exits)          │
└────────────────────────────────┬────────────────────────────────┘
                                 │ Linux Syscalls (clone, unshare, setns, pivot_root)
┌────────────────────────────────▼────────────────────────────────┐
│                         Linux Kernel                            │
│  ├── Namespaces: Isolation (PID, NET, MNT, UTS, IPC, USER,      │
│  │                          CGROUP, TIME)                       │
│  ├── Cgroups v2: Limits & Metering (cpu.max, memory.max, ...)   │
│  └── OverlayFS: CoW Layering (lowerdir, upperdir, merged)       │
└─────────────────────────────────────────────────────────────────┘
```

Kubernetes skips dockerd: kubelet → CRI → containerd (or CRI-O) → shim → runc. Everything from containerd down is identical, which is why Day 1 internals carry over to every later day.

---

## Core concepts

### 1. Linux Kernel Primitives

#### A. Namespaces (Isolation)
Namespaces restrict *what a process can see*. Linux has **eight** namespace types; Docker/runc creates (or joins) all of them except USER by default:
- **PID (`CLONE_NEWPID`):** Isolates process IDs. The container process sees itself as PID 1 (`NSpid: 47720 1` in `/proc/<pid>/status`), while on the host it has a standard high PID.
- **NET (`CLONE_NEWNET`):** Isolates network devices, IP routing tables, port bindings, and firewall rules. A container gets its own loopback interface and virtual ethernet interface (`veth`).
- **MNT (`CLONE_NEWNS`):** Isolates filesystem mount points. The process sees its own root filesystem (`/`) without seeing the host mounts.
- **UTS (`CLONE_NEWUTS`):** Isolates hostname and NIS domain name.
- **IPC (`CLONE_NEWIPC`):** Isolates System V IPC and POSIX message queues.
- **CGROUP (`CLONE_NEWCGROUP`):** Virtualises the view of `/proc/<pid>/cgroup`, so the container sees its own cgroup as the root (`0::/`) instead of the host's hierarchy. A view change only; it enforces nothing.
- **TIME (`CLONE_NEWTIME`):** Per-namespace offsets for `CLOCK_MONOTONIC` / `CLOCK_BOOTTIME` (Linux 5.6+). Rarely used; runc can create it.
- **USER (`CLONE_NEWUSER`):** Maps UID/GID ranges, so UID 0 inside can be an unprivileged UID outside.

**Common misconception:** user namespaces are **not** on by default. Plain Docker shares the host (VM) user namespace: `/proc/self/uid_map` inside a container is `0 0 4294967295` (identity map), so container root *is* UID 0 on the host, restrained only by dropped capabilities, seccomp, AppArmor/SELinux and the other namespaces. Real UID remapping needs `userns-remap` in `daemon.json` or rootless Docker/Podman (or, in Kubernetes, `hostUsers: false`). That is why running as a non-root `USER` matters so much.

Namespaces are just kernel objects with an inode: `ls -l /proc/<pid>/ns` shows one symlink per type, and two processes share a namespace iff the inode numbers match. `nsenter -t <pid> -n` / `setns(2)` is how `docker exec`, `kubectl debug` and `--network container:<name>` work.

#### B. Control Groups / Cgroups v2 (Resource Metering and Constraints)
Cgroups restrict *how much a process can use*. Namespaces provide visibility isolation; cgroups stop one noisy neighbour from starving the host. cgroup v2 is a single unified hierarchy under `/sys/fs/cgroup`; Docker places each container at `/docker/<container-id>` (with the systemd cgroup driver: a `docker-<id>.scope`).
- **`memory.max`:** Hard limit. If the cgroup exceeds it and the kernel cannot reclaim enough (anonymous memory such as a Go heap is not reclaimable without swap), the cgroup OOM killer sends `SIGKILL`. Docker reports exit code **137** (128 + 9) and `State.OOMKilled=true`. `memory.high` is the softer throttle point (Kubernetes memory QoS uses it); `memory.swap.max` controls swap, and `--memory-swap=<same as --memory>` disables swap for the container. `memory.events` counts `oom` / `oom_kill`.
- **`cpu.max`:** CFS bandwidth control: `$QUOTA $PERIOD` (e.g. `50000 100000` = 50 ms of CPU time per 100 ms window = 0.5 core, what `--cpus=0.5` writes). CPU is compressible: exceeding quota **throttles** the process (`cpu.stat` → `nr_throttled`), it never kills it. Throttling is a latency problem: a multi-threaded service can burn its whole quota in the first few ms of a period and then stall. `cpu.weight` (`--cpu-shares`) is only relative priority under contention. Since kernel 6.6 the CPU scheduler is EEVDF, which replaced CFS's pick-next logic; the bandwidth controller (`cpu.max`) still works the same way.
- **`pids.max`:** Maximum number of tasks (processes + threads); protects against fork bombs (`--pids-limit`).
- **I/O:** `io.max` is the actual per-device bandwidth/IOPS **limit**; `io.weight` is only a **proportional share** under contention (not a limit). The Docker flags are `--device-write-bps` etc.
- **Go does not read `memory.max`.** The Go runtime sizes its heap from the GC target (`GOGC`, default 100: collect when the heap has doubled) and knows nothing about your cgroup limit unless you tell it with `GOMEMLIMIT` (soft limit; typically ~90% of the cgroup limit). It limits *garbage* that is waiting to be collected, not live data: a live set bigger than the cgroup still gets OOM-killed (the lab proves this). In contrast, **since Go 1.25 `GOMAXPROCS` defaults to the cgroup CPU limit** (`--cpus=2` → 2 Ps instead of all host cores), which removes a classic cause of CPU throttling.

#### C. Union Filesystem / OverlayFS (Storage Efficiency)
Docker images are a stack of read-only, content-addressable layers (tar archives identified by a SHA-256 digest):
- **`lowerdir`:** The stacked read-only layers that make up the image (colon-separated, top layer first).
- **`upperdir`:** The read-write container layer created when a container starts.
- **`workdir`:** Internal OverlayFS scratch directory (must be on the same filesystem as `upperdir`) used to prepare changes atomically.
- **`merged`:** The unified mount point presented to the container as `/`.

**Copy-on-write:** when a container modifies a file that exists in `lowerdir`, OverlayFS copies the **whole file** up to `upperdir` first (even for a one-byte append; `metacopy=on` can copy only metadata for metadata-only changes, and it is off by default). Deleting a lower file creates a **whiteout** (a 0/0 character device) in `upperdir`; deleting a lower *directory* and recreating it creates an **opaque directory** (xattr `trusted.overlay.opaque=y`) that hides everything below it. Consequences: write-heavy paths (databases, logs) belong on volumes, not the container layer, and `RUN rm bigfile` in a *later* layer does not shrink the image because the earlier layer still contains it. `docker diff <container>` lists the upperdir changes (`A`dded / `C`hanged / `D`eleted).

**Which storage backend am I on?** Docker Engine 29 makes the **containerd image store** the default for *new* installs (snapshotter `overlayfs`; image data lives in containerd's content store and `docker inspect ... .GraphDriver.Name` reports `overlayfs`, and `docker info` lists a `driver-type` of `io.containerd.snapshotter.v1`). Installs upgraded from older versions (this course's verified machine included) keep the classic **`overlay2` graph driver** under `/var/lib/docker/overlay2/<id>/{diff,merged,work}`. Check with `docker info -f '{{.DriverStatus}}'`. The kernel mechanics are identical; only the directory layout and tooling (`docker save` format, multi-platform and attestation support in `--load`) differ.

---

### 2. Dockerfile Deep-Dive & Instruction Semantics

#### A. RUN vs CMD vs ENTRYPOINT
- **`RUN`:** Executes during the **build** phase to generate a new image layer (e.g., compiling code, installing packages).
- **`ENTRYPOINT`:** Defines the **executable** to run when the container starts.
- **`CMD`:** Defines default **arguments** passed to `ENTRYPOINT`, or the default executable if `ENTRYPOINT` is omitted. `docker run img args...` replaces `CMD`, not `ENTRYPOINT` (`--entrypoint` replaces that).

##### The Exec vs Shell Form Trap and PID 1
Always use the **exec form** (JSON array syntax) for `ENTRYPOINT` and `CMD`:
```dockerfile
# EXEC FORM (Correct)
ENTRYPOINT ["/app/server"]
# Default args; replaced by `docker run img <args>`.
CMD ["--port=8080"]
# /app/server is PID 1 and receives SIGTERM directly.

# SHELL FORM
ENTRYPOINT /app/server
# Runs as: /bin/sh -c "/app/server". Ignores CMD and `docker run` args entirely
# (they become extra args to sh -c, not to your program). Needs a shell in the image.
```
PID 1 is special in a PID namespace, and the details matter:
1. **Signal semantics.** The kernel does not apply default signal actions to PID 1 of a PID namespace: a signal with no installed handler is **ignored** (SIGKILL/SIGSTOP from outside the namespace excepted). A Go program installs handlers via `signal.Notify`, so it is fine as PID 1; `sh`, `python` without handlers, etc. are not.
2. **Shells do not forward signals.** If a shell is PID 1 and *stays* as parent of your app, SIGTERM hits the shell (no handler → ignored), the app never learns about it, and `docker stop` waits out the grace period and SIGKILLs (exit **137**; a rolling deploy then drops in-flight requests).
3. **Shell form is not automatically broken.** Many shells (dash, busybox ash, bash) `exec` the *last simple command* of `sh -c "<single command>"`, so `ENTRYPOINT /app/server` often ends up with the app as PID 1 anyway, and you only see the problem later. The trap is anything where the app is not the final command the shell runs: `app; cleanup` or `app && next` (shell must stay to run what follows), pipelines (`app | tee log`), and wrapper/entrypoint scripts that call the app without `exec`. (`echo starting; app` is optimised away because the app is last.) The lab builds exactly this case and times it.
4. **Zombies.** PID 1 is also the reaper for orphaned children. An app that spawns subprocesses and never `wait()`s leaves zombies. `docker run --init` (Kubernetes: `shareProcessNamespace` or tini/dumb-init in the image) puts a tiny init (`tini`) at PID 1 that forwards signals and reaps.
5. **`--init` is not a cure-all.** tini forwards SIGTERM to its direct child (the shell). The shell, no longer PID 1, has the default action for SIGTERM (terminate) and dies without forwarding to the app, so you stop fast but the app still never drains (lab shows exit 143 and no "draining" log). The reliable fix is `exec`: wrapper scripts end with `exec "$@"` (or `exec /app/server`), or use exec-form `ENTRYPOINT`.

#### B. COPY vs ADD
- **`COPY`:** Copies local files/directories (or `--from=<stage|image>`) into the image. Predictable and explicit.
- **`ADD`:** Also auto-extracts local tar archives and fetches remote URLs/git repos. **Rule:** use `COPY` unless you specifically need that. For downloads prefer `RUN --mount=type=cache ... curl` with checksum verification, or `ADD --checksum=sha256:...`.

#### C. ARG vs ENV
- **`ARG`:** Build-time variable. Not in the running container's environment, but **recorded in image metadata and `docker history`** when used (`ARG X=...` and `RUN |1 X=... cmd` appear verbatim), so it is never a place for secrets.
- **`ENV`:** Persisted into image config and the running container environment.

#### D. Layer Invalidation & Cache Strategy
BuildKit caches each step keyed on the **instruction string** plus its inputs: for `COPY`/`ADD`, the checksum of the files; for `RUN`, **only the command text** (and parent layer). It never checks whether the network content a `RUN curl` fetches has changed, so `RUN apt-get update` stays cached forever until you change the line or `--no-cache`. **Rule:** once a step's cache key changes, every later step re-executes.
```dockerfile
# BAD: any source change invalidates the dependency download
COPY . .
RUN go mod download
RUN go build -o server .

# GOOD: dependencies re-download only when the manifests change
# The glob lets this work whether or not go.sum exists
COPY go.mod go.sum* ./
RUN go mod download
COPY . .
RUN go build -o server .
```
(`labs/shared/order-api` has no third-party dependencies, so no `go.sum`; plain `COPY go.mod go.sum ./` would fail with "not found". The `go.sum*` glob is the portable form. Toolchain note: the builder image is `golang:1.27-alpine` (current release), while `go.mod` says `go 1.25`: that line is the *minimum language version* the module needs, not the compiler used, so anyone with Go 1.25 or newer can still build it locally.)

#### E. BuildKit mounts: cache and secrets
BuildKit (default builder since Docker 23) can attach things to a single `RUN` without writing them into a layer:
```dockerfile
# Persistent compiler/module caches across builds, never baked into the image
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o /app/server .

# Secret available only during this RUN, as the file /run/secrets/api_token
RUN --mount=type=secret,id=api_token \
    TOKEN=$(cat /run/secrets/api_token) && ./fetch-private-dep "$TOKEN"
```
```bash
docker build --secret id=api_token,src=./token.txt .   # or env=API_TOKEN
```
A cache mount keeps `/root/.cache/go-build` warm so a one-line code change recompiles only the changed packages instead of the whole module (measured in the lab folder: ~1.4 s vs ~4.4 s even for this tiny service; the gap grows with dependencies). A secret mount leaves **no trace** in layers or `docker history`, unlike `ARG`/`ENV`/`COPY .env`. Related: `RUN --mount=type=ssh` forwards your SSH agent for private git dependencies.

---

### 3. Images as OCI Artifacts

An image is three kinds of JSON/tar objects, all addressed by SHA-256 digest (content-addressable):
- **Manifest** (`application/vnd.oci.image.manifest.v1+json`): lists the config blob and the ordered layer blobs (each `tar+gzip` or `tar+zstd`, with size and digest).
- **Config** (`application/vnd.oci.image.config.v1+json`): architecture/os, `User`, `Entrypoint`, `Cmd`, `Env`, `ExposedPorts`, `Healthcheck`, plus `rootfs.diff_ids` (digests of the *uncompressed* layers) and the build history.
- **Index** (`application/vnd.oci.image.index.v1+json`, the "manifest list"): maps platforms (`linux/amd64`, `linux/arm64`) to per-platform manifests. When you `docker pull nginx` on a Mac, the client picks the `arm64` entry. With attestations the index also carries extra `unknown/unknown` manifests holding the SBOM and provenance.

A **tag** is a mutable pointer to a digest; a **digest** (`image@sha256:...`) is immutable. Layers are shared between images by digest, so only unseen layers are pulled, and `docker history` reports each layer's uncompressed size. Production consequences:
- Pin by digest (`FROM gcr.io/distroless/static-debian13:nonroot@sha256:<digest>`; Kubernetes `image: repo/app@sha256:...`) for reproducible, tamper-evident deploys. Tags are for humans; let Renovate/Dependabot bump the digest.
- Inspect without pulling: `docker buildx imagetools inspect <ref>` (index and platforms), `... --raw` (the JSON), `docker manifest inspect <ref>`.

#### Multi-platform builds (Apple Silicon → amd64 nodes)
Your Mac builds `linux/arm64` images natively, but EKS/ECS nodes are usually `linux/amd64`: an arm64 image there fails with `exec format error`. Either build for the target or publish a multi-arch index:
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t REGISTRY/order-api:1.0 --push .
```
Go makes this cheap: the builder stage uses `FROM --platform=$BUILDPLATFORM golang:...` (runs natively, no emulation) and cross-compiles with `GOOS=$TARGETOS GOARCH=$TARGETARCH`. Only steps that *execute* target-arch binaries (e.g. `RUN apk add` in a non-Go runtime stage) need QEMU emulation, which is slow. Multi-platform results and attestations need a `docker-container` builder (`docker buildx create --use`) or the containerd image store; the classic `docker` driver can only `--load` one platform.

#### Supply chain: scan, SBOM, provenance
- **Scan:** `docker scout cves <image>` (needs a Docker login) or `trivy image <image>` (no account). Scans OS packages *and* Go build info embedded in the binary. A distroless static image has ~0 findings; a full `golang` image has hundreds because it ships a whole Debian userland.
- **SBOM:** `--sbom=true` attaches an SPDX document listing the packages/modules inside, so you can answer "are we affected by CVE-X?" without pulling anything.
- **Provenance:** `--provenance=mode=max` attaches a SLSA statement: which Dockerfile, source, build args and builder produced this digest. Sign (cosign) and verify in admission control to close the loop. `docker buildx imagetools inspect <ref> --format '{{json .SBOM}}'` / `'{{json .Provenance}}'` read them back.

---

### 4. Production Patterns for Minimal, Secure Images

#### Base Image Comparison

| Base Image | Typical Size | Attack Surface | Debug Shell | libc | Best For |
|:---|:---|:---|:---|:---|:---|
| `golang:1.27` | ~1GB | Massive (compilers, git, curl, full Debian) | `bash`, `sh` | glibc | Build stage only |
| `alpine:3.20` | ~8MB | Low (busybox + apk) | `sh` | musl | Small images that still need a shell |
| `gcr.io/distroless/static-debian13` | ~2-3MB | Near zero (CA certs, tzdata, `/etc/passwd`, no shell) | None (use the `:debug` tag) | None (static binaries) | Production static Go/Rust |
| `scratch` | 0MB | Absolute zero (empty filesystem) | None | None | Static binaries; you must add CA certs, tzdata and a `/etc/passwd` yourself |

Sizes are approximate; check with `docker images`. musl vs glibc matters for CGO/DNS behaviour differences; for Go with `CGO_ENABLED=0` it does not.

#### The Golden Multi-Stage Build Pattern
This is the real `labs/shared/order-api/Dockerfile` (abridged); you write your own in the lab.
```dockerfile
# syntax=docker/dockerfile:1
# Stage 1: build natively on the build host, cross-compile for the target
FROM --platform=$BUILDPLATFORM golang:1.27-alpine AS builder
ARG TARGETOS TARGETARCH
WORKDIR /app
# General form with dependencies: COPY go.mod go.sum* ./  then  RUN go mod download
COPY go.mod ./
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /app/server .

# Stage 2: minimal runtime
FROM gcr.io/distroless/static-debian13:nonroot
WORKDIR /app
COPY --from=builder /app/server /app/server
EXPOSE 8080
# Numeric: Kubernetes runAsNonRoot can verify it
USER 65532:65532
# No curl in distroless: the binary probes itself
HEALTHCHECK CMD ["/app/server", "-healthcheck"]
ENTRYPOINT ["/app/server"]
```
- `-ldflags="-s -w"` strips the symbol table (`-s`) and DWARF (`-w`); `-trimpath` removes build-host file paths for reproducibility. Together they cut the binary by roughly a quarter to a third.
- `CGO_ENABLED=0` yields a fully static binary with no libc dependency.
- `USER 65532:65532` is the `nonroot` user baked into distroless. Use the **numeric** form: with `USER nonroot:nonroot`, Kubernetes `runAsNonRoot: true` cannot verify a name and fails with `CreateContainerConfigError` (Day 5). `docker top` shows `65532`, not a name, for the same reason (no matching `/etc/passwd` lookup on the host).
- `EXPOSE` is documentation only; `-p` does the publishing. `HEALTHCHECK` is evaluated by the Docker engine (and Compose), **not** by Kubernetes, which uses its own probes.

---

## Decision tree: Base Image Selection

```
Is the binary statically compiled (Go, Rust with CGO=0)?
├── Yes ──► Do you need an interactive shell in the image in production?
│           ├── Yes ──► alpine (or distroless :debug)
│           └── No  ──► gcr.io/distroless/static (or scratch)
│                       (debug later with `docker debug`, a --network container: sidecar,
│                        or `kubectl debug --target`)
└── No (Node.js, Python, Java, CGO=1)
    ├── Requires glibc compatibility ──► debian-slim or distroless:cc / base
    └── Pure musl compatible        ──► alpine
```

---

## Exercises

### Exercise 1 — Audit the Anti-Pattern Dockerfile
Review `labs/shared/order-api/Dockerfile.bad`. Identify 5 engineering anti-patterns and explain why each impairs production operations.

**Hint:** Think about image size, cache behaviour in CI, the user the process runs as, what an attacker finds inside the image, and what the orchestrator can learn about the container.

**Solution sketch:**
1. **Full SDK image as the runtime (`FROM golang:latest`):** ~1GB on disk, slow to pull when nodes scale out, ships compilers, git and a whole Debian userland (hundreds of HIGH/CRITICAL CVEs in a scan versus 0 for distroless), and the floating `latest` tag makes builds non-reproducible.
2. **`COPY . /app` as the first step, with no `.dockerignore`:** every file change (including `README.md`, `.git`) busts the layer and everything after it, and the whole directory is sent to the daemon and baked into the image. (This module has no third-party dependencies, so there is no separate download step to protect here; with dependencies you would copy `go.mod`/`go.sum*` and download first.)
3. **No multi-stage build, no `-trimpath -ldflags="-s -w"`:** the compiler, sources and build cache stay in the final image, and the binary is larger than needed.
4. **No `USER`:** the process runs as UID 0. Container root is host (VM) root minus capabilities/seccomp, and there is no user namespace by default, so any escape bug or writable mount is far worse.
5. **No `HEALTHCHECK` and no `EXPOSE`:** the engine and Compose cannot tell a hung process from a healthy one, and the listening port is undocumented.

---

### Exercise 2 — Image Transfer at Scale
A fleet of 50 nodes runs 200 replicas of an API service. CI builds a ~1GB unoptimized image on every commit. You refactor it into an ~9MB distroless multi-stage image (the lab's measured size). What changes during a rolling deployment, and what is the cold-start impact?

**Hint:** Registries transfer *compressed* layers, nodes cache layers by digest, and a pull has a network phase, a decompress/unpack phase and then container start.

**Solution sketch:**
- **Unoptimized:** the first pull on each node moves the compressed layers (a few hundred MB for a golang-based image) and then unpacks ~1GB onto disk: 50 nodes × several hundred MB = tens of GB through the registry/NAT, and tens of seconds per node (unpack is often the bottleneck, not bandwidth). Every commit also changes the big `COPY`/`RUN go build` layers, so little is reused.
- **Optimized:** the lab's amd64/arm64 image is ~3MB compressed (2.5MB of that is the binary layer), and the distroless base layers are cached on every node after the first deploy, so each rollout pulls only the new binary layer. 50 nodes × ~2.5MB ≈ 125MB total, finishing in about a second per node.
- **Impact:** new nodes and replicas become Ready in seconds instead of tens of seconds to minutes, registry load and cross-AZ/NAT transfer cost drop by roughly two orders of magnitude, and pull-time is no longer the dominant term in autoscaling reaction time. Also note `imagePullPolicy` (Day 3): an already-cached digest is not pulled at all.

---

### Exercise 3 — Kernel OOM vs Application Panic
A containerized Go microservice runs with `docker run --memory=64m` and the process dies under load.
1. What signal does the Linux kernel send?
2. What exit code does Docker report, and which flag distinguishes this from an application crash?
3. Can a Go `recover()` or signal handler trap this termination?
4. How would `GOMEMLIMIT` change it?

**Hint:** Differentiate `SIGTERM`, `SIGINT` and `SIGKILL`, and look at `docker inspect` state.

**Solution sketch:**
1. The cgroup OOM killer (triggered when `memory.max` is hit and nothing can be reclaimed) sends `SIGKILL` (signal 9).
2. Exit code **137** (128 + 9) with `State.OOMKilled=true`. A Go `panic` exits 2 with a stack trace in the logs; `os.Exit(1)` exits 1; neither sets `OOMKilled`. (137 alone is also what a `docker stop` timeout SIGKILL looks like, so check `OOMKilled` and `memory.events`.)
3. **No.** `SIGKILL` and `SIGSTOP` cannot be caught, blocked or ignored; `recover()` handles only goroutine panics. The kernel removes the process instantly, so there is no drain and no deferred cleanup.
4. `GOMEMLIMIT` makes the GC work harder as the heap approaches the limit, which helps when much of the heap is *garbage*. It does not shrink live data: if the live set exceeds the cgroup limit the process is still OOM-killed (the lab shows this). Set it to ~90% of the container limit and still size the limit from the live set.

---

## Anti-patterns / Common mistakes

1. **Fat images in production:** build tools (`gcc`, `make`, `git`) and package managers in the runtime image add CVEs, pull time and attacker tooling. Use multi-stage builds.
2. **Running as root (UID 0):** without `USER`, an escape bug or writable mount operates as root, and there is no user-namespace remapping by default to soften it. Use a numeric non-root `USER`.
3. **A shell that stays PID 1 (or a wrapper script without `exec`):** SIGTERM goes to the shell and is ignored, so `docker stop`/rolling updates wait out the grace period and SIGKILL the app mid-request (exit 137). Use exec-form `ENTRYPOINT`, `exec "$@"` in scripts, and `--init` when you spawn subprocesses.
4. **Secrets in `ARG`, `ENV` or `COPY .env`:** all of them persist in image metadata or layers and are readable with `docker history`/`docker save`. Use `RUN --mount=type=secret` at build time and runtime secret injection (Day 5).
5. **Missing `.dockerignore`:** uploads `.git/`, `.env`, `node_modules` to the daemon, slows builds, busts `COPY . .` cache and can leak credentials into layers.
6. **Mutable tags as the deployment reference:** `FROM golang:latest` or `image: app:latest` means the same manifest can run different bytes on different nodes. Pin versions and, for production, digests.
7. **Memory limit without runtime tuning:** a Go service with `--memory` but no `GOMEMLIMIT` sizes its heap by GC target alone and is OOM-killed under bursts. Set `GOMEMLIMIT` below the limit.
8. **Writing hot data to the container layer:** overlay copy-up and the upperdir's lifetime make this slow and ephemeral. Use volumes for databases, uploads and logs.

---

## Recall drill

Answer from memory first, then open the answers.

1. How many namespace types exist, and which one is *not* enabled by default in Docker?
2. A container with `--memory=32m` allocates a 64MB live buffer even though `GOMEMLIMIT=28MiB`. What happens and why?
3. `docker stop` on your container takes the full grace period and the exit code is 137. What is your first hypothesis and how do you confirm it?
4. Why does `docker top` show `65532` rather than `nonroot`?
5. What does `memory.max` do versus `cpu.max` when exceeded?
6. Why does `RUN rm -rf /big` in a later layer not shrink the image?
7. Which three object types make up an OCI image, and what does an index add?
8. Why is `ARG TOKEN=...` not a way to pass a secret, and what is?

<details>
<summary>Answers</summary>

1. Eight: mnt, pid, net, ipc, uts, user, cgroup, time. USER is not enabled by default (no `userns-remap`, not rootless): container root is host root.
2. The process is OOM-killed (exit 137, `OOMKilled=true`). `GOMEMLIMIT` is a soft target that only makes the GC more aggressive; live data cannot be collected.
3. PID 1 is not receiving or handling SIGTERM (a shell or wrapper stayed as PID 1). Confirm with `docker top` (parent `sh`), `docker logs` (no "SIGTERM received"), and the 10 s stop timing; fix with exec-form `ENTRYPOINT`/`exec`.
4. The host (VM) has no `/etc/passwd` entry for that UID; the name only exists in the image's own `/etc/passwd`. That is also why Kubernetes needs a numeric `USER` for `runAsNonRoot`.
5. `memory.max`: hard cap, OOM kill (SIGKILL, 137) when unreclaimable. `cpu.max`: throttling (quota per period), never a kill.
6. Layers are immutable and additive; the file still exists in the earlier layer, the later one only adds a whiteout. Delete in the same `RUN` or use a multi-stage build.
7. Manifest (layer list), config (runtime settings, diff_ids, history), and the layer tarballs; an index maps platforms (and attestations) to per-platform manifests.
8. `ARG` values appear in `docker history` and image metadata. Use `RUN --mount=type=secret` (build time) or runtime secret injection.

</details>

---

## Lab
See [`labs/day01/`](../labs/day01/). Run commands from the course root `k8s_docker_mastery/`.
- **The goal:** Build `order-api` with the bad Dockerfile and inspect it; write the production multi-stage Dockerfile yourself; explore namespaces, cgroups and overlay inside Docker Desktop's VM; trigger a cgroup OOM kill and compare it with `GOMEMLIMIT`; reproduce the PID 1 signal trap; build a multi-arch image with SBOM and provenance and scan it.
- **Success signal:** the production image is well under 20MB and runs as UID 65532 with a healthy `HEALTHCHECK`; `docker inspect` shows `OOMKilled: true`, `ExitCode: 137`; the shell-wrapped image needs the full stop timeout (exit 137) while the exec-form image stops in about 0.1 s (exit 0).

---

## Key commands reference

| Command | Purpose |
|:---|:---|
| `docker build -f <Dockerfile> -t app:v1 <context-dir>` | Build an image (Dockerfile path and context are independent) |
| `docker history --no-trunc app:v1` | Layer commands and sizes (ARGs appear here) |
| `docker inspect -f '{{.State.Pid}}' <c>` | Host (VM) PID of the container's PID 1 |
| `docker inspect -f '{{json .GraphDriver}}' <c>` | Overlay lowerdir/upperdir/merged paths (inside the VM) |
| `docker run --rm -it --privileged --pid=host --cgroupns=host alpine nsenter -t 1 -m -u -n -i sh` | Shell in the Docker Desktop VM's namespaces |
| `ls -l /proc/<pid>/ns` | Namespace inodes of a process (run inside the VM) |
| `docker run -d --memory=32m --memory-swap=32m app:v1` | Hard memory cap, swap disabled |
| `docker diff <c>` | Files added/changed/deleted in the container's upper layer |
| `docker stop -t 10 <c>` | Stop with an explicit SIGTERM grace period |
| `docker run --init ...` | tini as PID 1 (signal forwarding, zombie reaping) |
| `docker buildx build --platform linux/amd64,linux/arm64 --sbom=true --provenance=mode=max --push` | Multi-arch image with attestations (needs a `docker-container` builder) |
| `docker buildx imagetools inspect <ref>` | Show the OCI index and its platforms |
| `docker build --secret id=x,src=file` | Pass a build secret for `RUN --mount=type=secret,id=x` |
| `trivy image <img>` / `docker scout cves <img>` | Vulnerability scan |

---

## Teardown
Clean up local images, containers and the builder created during Day 1 (the optional scanner/dive/registry images are included; the `orderflow/*` images from `labs/shared/load-images.sh` are not touched):
```bash
docker rm -fv order-api-test order-api-oom order-api-oom-gc pid1-shell pid1-init pid1-exec d1-cow d1-registry 2>/dev/null || true
docker buildx rm d1-builder 2>/dev/null || true
docker rmi -f order-api:bad order-api:prod order-api:shellform order-api:shellform-exec order-api:amd64 localhost:5001/order-api:multi 2>/dev/null || true
docker rmi registry:2 aquasec/trivy:latest wagoodman/dive:latest 2>/dev/null || true
```

# Day 1 Lab: Solution & Explanations

Outputs below are real, captured on Docker Desktop (Engine 29.8, Apple Silicon, VM kernel `7.0.12-linuxkit`, cgroup v2, classic `overlay2` graph driver). IDs, PIDs, digests and timestamps will differ on your machine; sizes, exit codes and relationships will not. Commands run from the course root.

## Step 1-2: The bad image

```text
$ docker images order-api
IMAGE           ID             DISK USAGE   CONTENT SIZE   EXTRA
order-api:bad   b2b0f5562b2a          1GB             0B
```
(`docker image inspect order-api:bad -f '{{.Size}}'` → `1002904213` bytes.)

`docker history order-api:bad` (trimmed):
```text
IMAGE          CREATED         CREATED BY                                      SIZE
b2b0f5562b2a   2 minutes ago   CMD ["/app/server"]                             0B
<missing>      2 minutes ago   RUN /bin/sh -c go build -o server . # buildk…   103MB
<missing>      2 minutes ago   WORKDIR /app                                    0B
<missing>      2 minutes ago   COPY . /app # buildkit                          7.88kB
<missing>      10 hours ago    WORKDIR /go                                     0B
<missing>      10 hours ago    COPY /target/ / # buildkit                      238MB   <- Go toolchain
...                                                                             ...     <- Debian + gcc/git/etc.
```
Why ~1GB: `golang:latest` is a full Debian userland plus the Go toolchain (hundreds of MB). `go build` adds 103MB of build cache and the binary, and everything stays in the shipped image. The five anti-patterns (annotated in `Dockerfile.bad`): fat floating base, `COPY . /app` first with no `.dockerignore`, no multi-stage/no strip flags, runs as root, no `EXPOSE`/`HEALTHCHECK`.

## Step 3: Reference Dockerfile

This is `labs/shared/order-api/Dockerfile` (yours should be equivalent; exact comments and ordering may differ):
```dockerfile
# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.27-alpine AS builder
ARG TARGETOS TARGETARCH
WORKDIR /app
# No go.sum (no dependencies). General form: COPY go.mod go.sum* ./  + RUN go mod download
COPY go.mod ./
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /app/server .

FROM gcr.io/distroless/static-debian13:nonroot
WORKDIR /app
COPY --from=builder /app/server /app/server
EXPOSE 8080
USER 65532:65532
HEALTHCHECK --interval=10s --timeout=3s --start-period=3s --retries=3 CMD ["/app/server", "-healthcheck"]
ENTRYPOINT ["/app/server"]
```
Design notes:
- `--platform=$BUILDPLATFORM` + `GOOS/GOARCH=$TARGET*`: the compiler runs natively and cross-compiles, so `--platform linux/amd64` on an Apple Silicon Mac needs no emulation.
- The cache mounts persist across builds but are not part of any layer.
- `COPY go.mod` before `COPY . .` only pays off once a module has dependencies (then add `go mod download` between them). Plain `COPY go.mod go.sum ./` would fail here: there is no `go.sum`.
- Numeric `USER`, so Kubernetes `runAsNonRoot` can verify it (Day 5).

```text
$ docker images order-api
IMAGE            ID             DISK USAGE   CONTENT SIZE   EXTRA
order-api:prod   4c01df3f237c       8.93MB             0B
order-api:bad    b2b0f5562b2a          1GB             0B

$ docker history order-api:prod
IMAGE          CREATED        CREATED BY                                      SIZE
4c01df3f237c   ...            ENTRYPOINT ["/app/server"]                      0B
<missing>      ...            HEALTHCHECK {Test:[CMD /app/server -healthch…   0B
<missing>      ...            USER 65532:65532                                0B
<missing>      ...            EXPOSE [8080/tcp]                               0B
<missing>      ...            COPY /app/server /app/server # buildkit         6.55MB
<missing>      ...            WORKDIR /app                                    0B
<missing>      N/A            bazel build //common:cacerts_debian13_arm64_…   261kB
<missing>      N/A            bazel build @trixie//tzdata/arm64:data_statu…   754kB
...
```
The image is 8.93MB (about 99.1% smaller than the bad one): 6.55MB stripped binary, ~2.4MB distroless base (CA certs, tzdata, `/etc/passwd`, `/etc/nsswitch.conf`). The amd64 variant measures 9.5MB. (The older "15-20MB" in some course text was wrong.)

## Step 4: User and health

```text
$ docker top order-api-test -o pid,user,comm
PID      USER    COMMAND
47720    65532   server
$ curl -s localhost:8080/health
{"status":"ok","service":"order-api"}
$ curl -s localhost:8080/ready
{"status":"ready","service":"order-api"}
$ docker inspect -f '{{.State.Health.Status}} {{.Config.User}}' order-api-test
healthy 65532:65532
$ docker exec order-api-test sh
OCI runtime exec failed: ... exec: "sh": executable file not found in $PATH
```
`docker top` shows the UID `65532`, not `nonroot`: `docker top` runs `ps` on the VM, which has no passwd entry for that UID (the name exists only in the image's `/etc/passwd`). `-healthcheck` exits 0 (`docker exec order-api-test /app/server -healthcheck; echo $?` → `0`): the binary probes itself because there is no curl. `docker exec ... sh` failing is the distroless trade-off; debug with `docker debug`, a `--network container:` sidecar, or Kubernetes ephemeral containers.

## Step 5: Inside the VM

```text
$ docker run -d --name order-api-test -m 64m --cpus 0.5 --pids-limit 100 ... order-api:prod
$ docker inspect -f '{{.State.Pid}}' order-api-test
78374
```
In the helper shell (`nsenter -t 1 -m -u -n -i sh`, i.e. the Docker Desktop VM's filesystem; all values below are from this one run):
```text
# ls -l /proc/$PID/ns
cgroup -> cgroup:[4026533694]
ipc -> ipc:[4026533692]
mnt -> mnt:[4026533689]
net -> net:[4026533695]
pid -> pid:[4026533693]
pid_for_children -> pid:[4026533693]
time -> time:[4026533953]
time_for_children -> time:[4026533953]
user -> user:[4026531837]
uts -> uts:[4026533691]
# ls -l /proc/1/ns | tail -n +2        (VM PID 1)
cgroup -> cgroup:[4026531835]   ipc -> ipc:[4026531839]   mnt -> mnt:[4026531832]
net -> net:[4026531833]         pid -> pid:[4026531836]   time -> time:[4026531834]
user -> user:[4026531837]       uts -> uts:[4026531838]
# lsns -p $PID
        NS TYPE   NPROCS   PID USER  COMMAND
4026531837 user      216     1 root  /initd
4026533689 mnt         1 78374 65532 /app/server
4026533691 uts         1 78374 65532 /app/server
4026533692 ipc         1 78374 65532 /app/server
4026533693 pid         1 78374 65532 /app/server
4026533694 cgroup      1 78374 65532 /app/server
4026533695 net         1 78374 65532 /app/server
4026533953 time        1 78374 65532 /app/server
# cat /proc/$PID/cgroup
0::/docker/f591428c77f6b23fc524a57daacf8ac62a6fb187d6812d9ac335e48f797533d5
# cat $CG/memory.max $CG/cpu.max $CG/pids.max $CG/memory.current
67108864
50000 100000
100
3358720
# grep -E 'NSpid|Uid|CapEff' /proc/$PID/status
Uid:	65532	65532	65532	65532
NSpid:	78374	1
CapEff:	0000000000000000
# cat /proc/$PID/uid_map
         0          0 4294967295
# uname -r
7.0.12-linuxkit
```
Read-out: seven namespaces are private to the container (mnt, uts, ipc, pid, cgroup, net, time); the **user** namespace inode equals the VM's own, so there is no user namespace remapping (container UID 0 would be real UID 0 in the VM; `uid_map` is the identity map). `NSpid: 78374 1` is the same process: PID 78374 in the VM, PID 1 inside. `lsns` is already present in the VM's filesystem (the shell is in the VM's mount namespace, which has no `apk`; `apk add` fails there). `memory.max` is exactly `64 × 1048576`, `cpu.max` `50000 100000` is `--cpus 0.5`, and the container has no effective capabilities at all (`CapEff` 0) because it runs as non-root. Without `--cgroupns=host` the helper reports `0::/../<id>` and the `/sys/fs/cgroup/...` lookup fails.

```text
$ docker info -f '{{.Driver}} {{.DriverStatus}}'
overlay2 [[Backing Filesystem extfs] [Supports d_type true] [Using metacopy false] [Native Overlay Diff true] [userxattr false]]
$ docker inspect -f '{{json .GraphDriver.Data}}' order-api-test | cut -c1-300
{"ID":"39c22763d4d9...","LowerDir":"/var/lib/docker/overlay2/aee57966...-init/diff:/var/lib/docker/overlay2/...
  (also MergedDir=.../merged, UpperDir=.../diff, WorkDir=.../work)
$ docker diff d1-cow
A /newfile
C /usr
C /usr/lib
C /usr/lib/os-release
C /bin
D /bin/ls
```
`LowerDir` lists the image layers (plus the `-init` layer Docker adds for `/etc/hosts` etc.), `UpperDir` is the container's writable layer. `os-release` was a symlink, so `echo >> /etc/os-release` copied up the whole target file (copy-up) and `rm /bin/ls` shows as a `D` whiteout. `Metacopy false` means a metadata-only change would still copy data. This machine is on the classic `overlay2` driver; a fresh Engine 29 install uses the containerd image store, where `GraphDriver.Name` is `overlayfs` and the data lives under containerd's snapshotter.

## Step 6: OOM and GOMEMLIMIT

```text
$ curl -s "localhost:8080/debug/alloc?mb=16"
{"allocated_mb":16,"retained_mb":16}
$ docker stats --no-stream --format '{{.MemUsage}}' order-api-oom
22.46MiB / 32MiB
$ curl -s -m 10 "localhost:8080/debug/alloc?mb=64"; echo "curl exit: $?"
curl exit: 52                                  <- empty reply: the process was killed mid-request
$ docker inspect order-api-oom --format 'Status: ... | OOMKilled: ... | ExitCode: ...'
Status: exited | OOMKilled: true | ExitCode: 137
$ docker logs order-api-oom | tail -3
2026/10/06 13:25:44 order-api listening on port 8080      <- no "SIGTERM received": SIGKILL, nothing to log
```
Mechanics: `--memory=32m` makes the engine write `33554432` to the container cgroup's `memory.max`; `--memory-swap=32m` (equal to memory) disables swap (`memory.swap.max` 0). The handler makes a 64MiB slice and touches every 4KiB page, so the pages are resident anonymous memory held by a live reference. The kernel cannot reclaim anonymous memory without swap, so the cgroup OOM killer picks the only real process and sends `SIGKILL` (9). Docker reports 128 + 9 = **137** and `OOMKilled=true` (derived from `memory.events`'s `oom_kill`). Before this lab's fix the idle server (~5MiB) could never reach 10MiB, which is why the old step never fired.

GOMEMLIMIT comparison (8MiB steps, `GODEBUG=gctrace=1`):
```text
--- no GOMEMLIMIT
{"allocated_mb":8,"retained_mb":8} curl-exit=0
{"allocated_mb":8,"retained_mb":16} curl-exit=0
{"allocated_mb":8,"retained_mb":24} curl-exit=0
 curl-exit=52
OOMKilled: true | ExitCode: 137     gc cycles: 3      (last: gc 3 ... 32->32->32 MB, 32 MB goal)
--- GOMEMLIMIT=28MiB (run via `for lim in off 28MiB`; the no-limit run used GOMEMLIMIT=off)
{"allocated_mb":8,"retained_mb":8} curl-exit=0
{"allocated_mb":8,"retained_mb":16} curl-exit=0
{"allocated_mb":8,"retained_mb":24} curl-exit=0
 curl-exit=52
OOMKilled: true | ExitCode: 137     gc cycles: 7 (6 on a zsh re-run)  (last: gc 7 ... 32->32->32 MB, 24 MB goal)
```
The 64MB single call with `GOMEMLIMIT=28MiB` also ended `OOMKilled: true, ExitCode: 137`. `GOMEMLIMIT` is a soft target: the runtime collects more often as it nears 28MiB (6-7 cycles vs 3, and the goal drops to 24MB), but all the data is live, so collection frees nothing and the kernel still kills at 32MiB. It helps with garbage-heavy services (it replaces "GC when the heap doubles" with "GC before we hit the container limit"), and with `GOGC` tuning; it never substitutes for sizing the limit above the live set. Also verified: with `--cpus=2`, `gctrace` prints `2 P` (default: `8 P` on this 8-core VM), i.e. Go 1.25 sets `GOMAXPROCS` from the cgroup CPU limit.

## Step 7: PID 1 and signals

```text
$ docker top pid1-shell -o pid,ppid,comm,args
PID     PPID    COMMAND   COMMAND
49620   49598   sh        sh -c /app/server; echo server-exited
49637   49620   server    /app/server                          <- sh is PID 1 inside; server is its child
$ stoptime pid1-shell
pid1-shell: stop took 10s, exit=137
$ docker logs pid1-shell | tail -2
2026/... order-api listening on port 8080                       <- no "SIGTERM received"

$ docker top pid1-init -o pid,ppid,comm,args
49798   49774   docker-init  /sbin/docker-init -- /bin/sh -c sh -c "/app/server; echo server-exited"
49811   49798   sh           sh -c /app/server; echo server-exited
49812   49811   server       /app/server
$ stoptime pid1-init
pid1-init: stop took 0s, exit=143                               <- fast, but 128+15: the shell died of SIGTERM
(logs: no "SIGTERM received, draining": the app was killed with the container, not drained)

$ stoptime pid1-exec          (ENTRYPOINT sh -c "exec /app/server")
pid1-exec: stop took 0s, exit=0
2026/... SIGTERM received, draining
2026/... order-api stopped

$ stoptime order-api-test     (distroless, exec-form)
order-api-test: stop took 0s, exit=0
```
(Sub-second precision with `date +%s.%N`: 0.087s for `pid1-exec`, 0.118s for the distroless image, 0.097s for `--init`, 10.12s for `pid1-shell`.)

Why:
- `docker stop` sends SIGTERM to PID 1 and, after the timeout (`-t`), SIGKILL. In the shell variant PID 1 is `sh`; it has no SIGTERM handler (`SigCgt` of `sh` was `0x10002`: only INT and CHLD), and the kernel ignores unhandled signals for the namespace's init, so nothing happens until SIGKILL (exit 137).
- With `--init`, tini is PID 1 and forwards SIGTERM to `sh`; `sh` is no longer init, so default action applies: it dies (143) without telling `/app/server`, which is then killed with the container's PID namespace. Fast, but no drain: in-flight requests are cut.
- `exec` replaces the shell with the server, which becomes PID 1 directly with its own SIGTERM handler: drain, exit 0.
- Mixed result you may hit: `ENTRYPOINT sh -c "echo starting; /app/server"` stopped in 0.08s too, because busybox `ash` execs the *last* command of a `sh -c` string. Shell form is a risk, not an automatic failure; it bites when the app is not the last command (`app; cleanup`, `app && next`), in pipelines, and in wrapper scripts without `exec`.
- Docker's documented default stop timeout is 10s, but a bare `docker stop` measured 3s on this engine (cause not established), which is why the lab passes `-t 10` explicitly.

## Step 8: OCI, multi-arch, SBOM, scan

```text
$ docker buildx build --platform linux/amd64,linux/arm64 -t localhost:5001/order-api:multi --sbom=true --provenance=mode=max --push ...
... exporting attestation manifest ... exporting manifest list sha256:36b641e2... pushing manifest ... DONE   (~39 s cold)

$ docker buildx imagetools inspect localhost:5001/order-api:multi
Name:      localhost:5001/order-api:multi
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:36b641e2565d142fcbe076ba5883863c99ae9146a965ccc9ced01b63a7324d34
Manifests:
  Name:      ...@sha256:b1ee3a55...   MediaType: application/vnd.oci.image.manifest.v1+json   Platform: linux/amd64
  Name:      ...@sha256:f439d6a0...   MediaType: application/vnd.oci.image.manifest.v1+json   Platform: linux/arm64
  Name:      ...@sha256:5cb9afab...   Platform: unknown/unknown   vnd.docker.reference.type: attestation-manifest
  Name:      ...@sha256:7f21de60...   Platform: unknown/unknown   vnd.docker.reference.type: attestation-manifest
```
Without the `docker-container` builder the same build stops with `ERROR: failed to build: Attestation is not supported for the docker driver.`

Anatomy of the arm64 manifest (layer sizes from the first run on Go 1.25; the Go 1.27 binary layer is about 10% larger; fetched with `curl -H 'Accept: application/vnd.oci.image.manifest.v1+json' localhost:5001/v2/order-api/manifests/<digest>`):
```text
config  application/vnd.oci.image.config.v1+json  sha256:525fd90ba526...
14 layers, each application/vnd.oci.image.layer.v1.tar+gzip (sizes in bytes): 83901, 12481, 445709, 29005, 67, 188, ..., 143347, 97, 2505136
config: architecture=arm64 os=linux User=65532:65532 Entrypoint=['/app/server'] Healthcheck=['CMD','/app/server','-healthcheck']
rootfs: type=layers, 14 diff_ids   history: 18 entries
```
Total compressed pull ≈ 3.3MB (the 2.5MB layer is the binary); the other 13 layers are the distroless base, shared with every distroless image on the node. The SBOM (`--format '{{json .SBOM}}'`) is SPDX generated by syft (`"Tool: syft-v1.51.0"`), the provenance (`.Provenance`) is a SLSA statement from buildkit.

```text
$ docker image inspect order-api:amd64 -f '{{.Architecture}} {{.Size}}'
amd64 8499826
$ trivy image --quiet --severity HIGH,CRITICAL <img> | grep -E 'order-api'      (via aquasec/trivy container; table rows whose target name contains order-api)
│ order-api:prod (debian 12.15) │  debian  │        0        │    -    │
│ order-api:bad (debian 13.7)   │  debian  │       143       │    -    │
(unfiltered, the table also lists gobinary rows: app/server 0, and for :bad the Go toolchain binaries, each 0)
```
(Counts change daily as the vulnerability DB updates. `docker scout cves` requires a `docker login`, so the lab uses trivy.) `docker run wagoodman/dive --ci order-api:bad` reports many `/var/lib/apt`, `/var/lib/dpkg` files in the layers, and passes `highestUserWastedPercent` / `lowestEfficiency` (efficiency is about duplicated bytes between layers, not about the toolchain you should not have shipped).

BuildKit mounts, measured with a scratch copy of the service (append a comment to `main.go`, rebuild):
```text
with cache mounts:      3.33s (first change), 1.43s (second change)
without cache mounts:   4.40s, 4.44s
```
The gap is small because the module is tiny and has no dependencies; with real dependencies the module cache alone saves downloading everything on each change. Secret mount: a build with `ARG LEAKY=...` plus `RUN --mount=type=secret,id=api_token echo "secret len: $(wc -c < /run/secrets/api_token)"` printed `secret len: 21` during the build; `docker history --no-trunc` then showed `ARG LEAKY=placeholder-arg-456` and `RUN |1 LEAKY=placeholder-arg-456 ...` (the argument leaked) but nothing about the secret, and `ls /run/secrets` in the resulting image failed ("No such file").

## Exercise answers (summary)
See `content/day01.md`: Exercise 1 (the five anti-patterns above), Exercise 2 (compressed-layer and layer-cache arithmetic with the lab's measured 9MB / ~3.3MB), Exercise 3 (SIGKILL, 137 + `OOMKilled`, not catchable, `GOMEMLIMIT` bounds garbage only).

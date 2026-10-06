# Day 1 Lab: Docker Internals, Image Anatomy & Cgroup Limits

**Run every command from the course root** (`k8s_docker_mastery/`). Day 1 uses the Docker engine only, no Kubernetes. Mac-specific notes assume Docker Desktop on Apple Silicon.

## Start here — plain steps

1. Open a terminal in `k8s_docker_mastery/`, check `docker version` works and port 8080 is free (`lsof -i :8080` prints nothing).
2. Build the deliberately bad image (`order-api:bad`) and look at its size and layers. It should be about 1GB.
3. Write your own multi-stage `Dockerfile` in `labs/day01/Dockerfile` from the requirements below (peek at `SOLUTION.md` only after trying) and build it as `order-api:prod`. It should be under 10MB, run as user 65532 and report `healthy`.
4. Step into Docker Desktop's Linux VM and look at the container's namespaces, cgroup limits and overlay mount. You should see the numbers you passed to `docker run` in `memory.max` and `cpu.max`.
5. Start the container with a 32MB memory cap, allocate 64MB through the debug endpoint and watch it die with `OOMKilled: true`, exit code 137. Repeat with `GOMEMLIMIT` and see that live data still kills it.
6. Build two tiny variants whose entrypoint is a shell wrapper, time `docker stop`, and compare with your real image. A shell that stays PID 1 costs the whole grace period (exit 137); exec form stops in about 0.1 s.
7. Build a multi-arch image with SBOM and provenance into a throwaway local registry, read the OCI index back, and scan the images.
8. You are done when each step's "You should see" line matched. Run **Teardown** at the end.

## Objective
Build OrderFlow's `order-api` with a flawed Dockerfile, analyze the layer anatomy and bloated size, write a production-grade multi-stage distroless build yourself, inspect namespaces/cgroups/overlay inside the Docker VM, trigger a kernel cgroup OOM kill, reproduce the PID 1 signal trap, and inspect the OCI/supply-chain side of an image.

---

## Lab Architecture

```
labs/shared/order-api/Dockerfile.bad ─► 1GB image: root, toolchain, whole OS
labs/day01/Dockerfile (you write it) ─► ~9MB image: distroless, UID 65532, HEALTHCHECK
        │
        ▼  docker run --memory=32m --memory-swap=32m -e ENABLE_DEBUG_ALLOC=1
 [dockerd → containerd → shim → runc] ─► process in its own namespaces + cgroup /docker/<id>
        │  GET /debug/alloc?mb=64 → live heap > memory.max
        ▼
 kernel cgroup OOM killer ─► SIGKILL ─► OOMKilled=true, exit 137
```

`order-api` lives in `labs/shared/order-api/` (read-only for you; later days reuse it). It serves `/health`, `/ready` and `/orders`, supports `-healthcheck` (used by the Dockerfile's `HEALTHCHECK`) and `/debug/alloc?mb=N` when `ENABLE_DEBUG_ALLOC=1`. It keeps orders in memory and does not use Postgres.

---

## Instructions

### Step 1: Build the Unoptimized Anti-Pattern Image
```bash
docker build -f labs/shared/order-api/Dockerfile.bad -t order-api:bad labs/shared/order-api
docker images order-api
```
*You should see: `order-api:bad` around 1GB.* (Engine 29 prints a `DISK USAGE` column; older engines print `SIZE`.)

### Step 2: Inspect Layers
```bash
docker history order-api:bad
```
Find the `golang` base layers, the `COPY . /app` layer and the `go build` layer. Then read `labs/shared/order-api/Dockerfile.bad` and list its five anti-patterns (Exercise 1).

Optional visual layer explorer (non-interactive check shown; drop `--ci` and add `-it` for the TUI):
```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive:latest --ci order-api:bad
```

### Step 3: Write the Production Multi-Stage Dockerfile
Create `labs/day01/Dockerfile` yourself. Requirements:

1. First line `# syntax=docker/dockerfile:1`.
2. **Build stage** `FROM --platform=$BUILDPLATFORM golang:1.27-alpine AS builder`, with `ARG TARGETOS TARGETARCH` and `WORKDIR /app`.
3. Copy `go.mod` first (this module has no dependencies, so there is no `go.sum`; know the general form `COPY go.mod go.sum* ./`), then `COPY . .`.
4. Build with `CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w" -o /app/server .`, using **BuildKit cache mounts** for `/go/pkg/mod` and `/root/.cache/go-build`.
5. **Runtime stage** `FROM gcr.io/distroless/static-debian13:nonroot`; copy only `/app/server` from the builder.
6. `EXPOSE 8080`, **numeric** `USER 65532:65532`, exactly this health check (distroless has no curl; the short interval is what makes it `healthy` within Step 4's `sleep 4`, the default 30 s interval would still say `starting`): `HEALTHCHECK --interval=10s --timeout=3s --start-period=3s --retries=3 CMD ["/app/server", "-healthcheck"]`, exec-form `ENTRYPOINT ["/app/server"]`.

Skeleton:
```dockerfile
# syntax=docker/dockerfile:1
FROM --platform=$BUILDPLATFORM golang:1.27-alpine AS builder
# TODO: ARG, WORKDIR, COPY go.mod, COPY source, RUN with two cache mounts + static build

FROM gcr.io/distroless/static-debian13:nonroot
# TODO: WORKDIR, COPY --from=builder, EXPOSE, USER, HEALTHCHECK, ENTRYPOINT
```
Build it (the Dockerfile lives in `labs/day01/`, the build context is the service directory):
```bash
docker build -f labs/day01/Dockerfile -t order-api:prod labs/shared/order-api
docker images order-api
docker history order-api:prod
```
*You should see: `order-api:prod` under 10MB (about 9MB on arm64); `docker history` shows tiny layers except the ~6.5MB binary.* The reference is `labs/shared/order-api/Dockerfile` (see `SOLUTION.md`).

### Step 4: Run It, Check User and Health
```bash
docker run -d --name order-api-test -p 8080:8080 order-api:prod
sleep 4
docker top order-api-test -o pid,user,comm
curl -s localhost:8080/health; echo
curl -s localhost:8080/ready; echo
docker inspect -f '{{.State.Health.Status}} {{.Config.User}}' order-api-test
docker exec order-api-test sh      # fails on purpose: no shell in distroless
docker rm -f order-api-test
```
*You should see: USER `65532` (a number: the VM has no name for it), `{"status":"ok",...}`, `healthy 65532:65532`, and an "executable file not found" error from the `exec`.*

### Step 5: Look Inside the VM (namespaces, cgroups, overlay)
On a Mac the container's kernel objects live in Docker Desktop's Linux VM. Start a container with limits so there is something to read, then enter the VM's namespaces with a privileged helper container (`--cgroupns=host` makes the container's cgroup path resolvable):
```bash
docker run -d --name order-api-test -m 64m --cpus 0.5 --pids-limit 100 -p 8080:8080 order-api:prod
docker inspect -f '{{.State.Pid}}' order-api-test        # note this PID

docker run --rm -it --privileged --pid=host --cgroupns=host alpine nsenter -t 1 -m -u -n -i sh
```
This shell runs in the **Docker Desktop VM's filesystem** (we entered its mount namespace), so it has the VM's tools (`lsns`, `/sys/fs/cgroup`) but no `apk`. Replace `<PID>` with the number above:
```sh
PID=<PID>
ls -l /proc/$PID/ns                  # one symlink per namespace type
ls -l /proc/1/ns | tail -n +2        # VM PID 1, for comparison: which inodes differ?
lsns -p $PID                         # same data as a table
cat /proc/$PID/cgroup                # 0::/docker/<container-id>
CG=/sys/fs/cgroup$(cut -d: -f3 /proc/$PID/cgroup)
cat $CG/memory.max $CG/cpu.max $CG/pids.max $CG/memory.current
grep -E 'NSpid|Uid|CapEff' /proc/$PID/status
cat /proc/$PID/uid_map               # identity map = no user namespace
head -1 /proc/$PID/mountinfo | cut -c1-200   # the overlay root mount
uname -r
exit
```
Back on the Mac, look at the overlay side:
```bash
docker info -f '{{.Driver}} {{.DriverStatus}}'
docker inspect -f '{{json .GraphDriver.Data}}' order-api-test | cut -c1-300
docker run --name d1-cow alpine sh -c 'echo x >> /etc/os-release; rm /bin/ls; touch /newfile'
docker diff d1-cow; docker rm d1-cow
docker rm -f order-api-test
```
*You should see: namespace inodes for `mnt, uts, ipc, pid, cgroup, net, time` that differ from VM PID 1's, but `user` identical; `memory.max=67108864`, `cpu.max=50000 100000`, `pids.max=100`; `uid_map` of `0 0 4294967295`; `docker diff` listing `A /newfile`, `C /usr/lib/os-release`, `D /bin/ls`, plus `C` lines for the parent directories (`C /usr`, `C /usr/lib`, `C /bin`).* If your engine uses the containerd image store (Engine 29 default for new installs), `docker info` shows an `io.containerd.snapshotter.v1` driver type instead of `overlay2` and `GraphDriver` paths differ; the kernel mechanics don't.

### Step 6: BREAK IT — Cgroup OOM, then GOMEMLIMIT
`order-api` idles at ~5MB, so we ask it to allocate. Run with a 32MB hard cap (swap disabled so the kill is deterministic) and the debug endpoint enabled:
```bash
docker run -d --name order-api-oom --memory=32m --memory-swap=32m -e ENABLE_DEBUG_ALLOC=1 -p 8080:8080 order-api:prod
sleep 2
curl -s "localhost:8080/debug/alloc?mb=16"; echo
docker stats --no-stream --format '{{.MemUsage}}' order-api-oom
curl -s -m 10 "localhost:8080/debug/alloc?mb=64"; echo "curl exit: $?"
docker inspect order-api-oom --format 'Status: {{.State.Status}} | OOMKilled: {{.State.OOMKilled}} | ExitCode: {{.State.ExitCode}}'
docker logs order-api-oom | tail -3
docker rm -f order-api-oom
```
*Success signal: the 16MB call returns `retained_mb:16`, usage is ~22MiB of 32MiB, the 64MB call gets an empty reply (curl exit 52), and state is `exited | OOMKilled: true | ExitCode: 137`. No "SIGTERM received" in the logs: SIGKILL cannot be caught.* Why: the handler writes every page of a live 64MB slice, so the cgroup needs 64MB of anonymous memory it can never reclaim (swap is off) while `memory.max` is 32MB.

Now the Go-specific lesson. Go does not read the cgroup limit; `GOMEMLIMIT` is a soft limit that makes the GC work harder. Allocate 8MB at a time with GC tracing, without (`GOMEMLIMIT=off`) and with it:
```bash
for lim in off 28MiB; do
  docker run -d --name order-api-oom-gc --memory=32m --memory-swap=32m -e ENABLE_DEBUG_ALLOC=1 -e GODEBUG=gctrace=1 -e GOMEMLIMIT=$lim -p 8080:8080 order-api:prod >/dev/null
  sleep 2
  for i in 1 2 3 4; do curl -s -m 10 -w ' curl-exit=%{exitcode}\n' "localhost:8080/debug/alloc?mb=8"; done
  docker inspect order-api-oom-gc --format 'OOMKilled: {{.State.OOMKilled}} | ExitCode: {{.State.ExitCode}}'
  echo "gc cycles: $(docker logs order-api-oom-gc 2>&1 | grep -c '^gc ')"
  docker rm -f order-api-oom-gc >/dev/null
done
```
*You should see: both runs die on the 4th call (32MB of live data plus runtime overhead) with 137, but the `GOMEMLIMIT` run did more GC cycles (about 6-7 vs 3) trying to stay under 28MiB. Conclusion: `GOMEMLIMIT` bounds garbage, not live data.* Also try `--cpus=2 -e GODEBUG=gctrace=1`: the trace shows `2 P`, because `GOMAXPROCS` (Go 1.25+) follows the cgroup CPU limit.

### Step 7: PID 1 and Signals
Build a variant whose entrypoint is a shell wrapper where the app is not the last command (so the shell must stay and cannot `exec` it), and a fixed variant:
```bash
docker build -q -t order-api:shellform - <<'EOF'
FROM alpine:3.20
COPY --from=order-api:prod /app/server /app/server
ENTRYPOINT sh -c "/app/server; echo server-exited"
EOF
docker build -q -t order-api:shellform-exec - <<'EOF'
FROM alpine:3.20
COPY --from=order-api:prod /app/server /app/server
ENTRYPOINT sh -c "exec /app/server"
EOF

stoptime() { s=$(date +%s); docker stop -t 10 "$1" >/dev/null; echo "$1: stop took $(( $(date +%s)-s ))s, exit=$(docker inspect -f '{{.State.ExitCode}}' "$1")"; }

docker run -d --name pid1-shell order-api:shellform; sleep 2
docker top pid1-shell -o pid,ppid,comm,args        # who is PID 1?
stoptime pid1-shell; docker logs pid1-shell 2>&1 | tail -2

docker run -d --name pid1-init --init order-api:shellform; sleep 2
docker top pid1-init -o pid,ppid,comm,args
stoptime pid1-init; docker logs pid1-init 2>&1 | tail -2

docker run -d --name pid1-exec order-api:shellform-exec; sleep 2
stoptime pid1-exec; docker logs pid1-exec 2>&1 | tail -2

docker run -d --name order-api-test order-api:prod; sleep 2
stoptime order-api-test
docker rm -f pid1-shell pid1-init pid1-exec order-api-test
```
*You should see: `pid1-shell` takes the full 10s and exits 137 with no "SIGTERM received" log (`sh` as PID 1 ignores SIGTERM); `pid1-init` stops in ~0s but exits 143 and the app never logs "draining" (tini signalled the shell, the shell died without forwarding); `pid1-exec` and the distroless image stop in ~0s, exit 0, and log `SIGTERM received, draining`.*

Also try the simpler `ENTRYPOINT sh -c "echo starting; /app/server"`: busybox `ash` execs the last command, so it behaves like exec form. Shell form is dangerous when the app is not the last command or a script forgets `exec`. Docker's documented default stop timeout is 10 s, but a bare `docker stop` measured 3 s on this engine (cause not established); pass `-t 10` explicitly so the demo is deterministic.

### Step 8: OCI Index, Multi-Arch, SBOM, Scan
Your Mac builds arm64; cloud nodes are often amd64. Build both into a throwaway local registry. Attestations need a `docker-container` builder (or the containerd image store):
```bash
docker run -d --name d1-registry -p 5001:5000 registry:2
docker buildx create --name d1-builder --driver docker-container --driver-opt network=host
docker buildx build --builder d1-builder -f labs/shared/order-api/Dockerfile --platform linux/amd64,linux/arm64 \
  -t localhost:5001/order-api:multi --sbom=true --provenance=mode=max --push labs/shared/order-api
docker buildx imagetools inspect localhost:5001/order-api:multi
docker buildx imagetools inspect localhost:5001/order-api:multi --format '{{json .SBOM}}' | head -c 300; echo
```
*You should see: an `application/vnd.oci.image.index.v1+json` with `linux/amd64`, `linux/arm64` and two `unknown/unknown` attestation manifests; the SBOM is an SPDX document.* Pin by digest: `localhost:5001/order-api@sha256:<index digest>` is immutable, the tag is not.

Single-platform cross-build into the local store, then scan:
```bash
docker buildx build --platform linux/amd64 -f labs/shared/order-api/Dockerfile -t order-api:amd64 --load labs/shared/order-api
docker image inspect order-api:amd64 -f '{{.Architecture}} {{.Size}}'
for img in order-api:prod order-api:bad; do
  docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:latest image --quiet --severity HIGH,CRITICAL $img | grep -E 'order-api'
done
```
*You should see: `amd64 ~9.5MB`; `order-api:prod` with 0 HIGH/CRITICAL, `order-api:bad` with over a hundred (counts vary by day). `docker scout cves <img>` is the alternative if you are logged in to Docker.*

Optional, BuildKit mounts: copy `labs/shared/order-api` into a scratch directory, append a comment line to `main.go` and time `docker build` with and without the two `--mount=type=cache` lines (about 1.4 s vs 4.4 s here). For a secret mount, build a Dockerfile with `RUN --mount=type=secret,id=api_token echo "len: $(wc -c < /run/secrets/api_token)"` and `--secret id=api_token,src=token.txt`; then confirm `docker history --no-trunc` shows no trace of it, whereas an `ARG` value shows up verbatim.

---

## Stuck? Hints

- **`docker build` fails with `no such file` or "not found" for `go.mod`/`Dockerfile`.** `-f` is relative to your shell, the last argument is the build context. Run from the course root and use the commands exactly as written (`-f labs/day01/Dockerfile ... labs/shared/order-api`).
- **`bind: address already in use` on port 8080.** A previous step's container is still running: `docker ps`, then `docker rm -f` it.
- **The OOM step does not kill the container.** Without `-e ENABLE_DEBUG_ALLOC=1` the endpoint is 404; without `--memory-swap=32m` the kernel may swap and the 64MB call "succeeds". Use the flags exactly.
- **`nsenter ... sh` shows `No such file` under `/sys/fs/cgroup`.** Add `--cgroupns=host` to the helper `docker run`; otherwise the path in `/proc/<pid>/cgroup` is relative to the helper's own cgroup namespace. `lsns` not found or `apk` errors: you are in the VM's filesystem, which has `lsns` already; do not try `apk add`.
- **`docker stop` returns instantly for the shell variant.** busybox `sh -c "a; b"` execs a final command; keep the app *not* last, as in the lab, and check that `docker top` shows `sh` as PID 1.
- **`Attestation is not supported for the docker driver`, or multi-platform `--load` fails.** The default `docker` driver on the classic image store cannot do either; use the `docker-container` builder from Step 8 (or enable the containerd image store in Docker Desktop settings).

---

## Teardown
```bash
docker rm -fv order-api-test order-api-oom order-api-oom-gc pid1-shell pid1-init pid1-exec d1-cow d1-registry 2>/dev/null || true
docker buildx rm d1-builder 2>/dev/null || true
docker rmi -f order-api:bad order-api:prod order-api:shellform order-api:shellform-exec order-api:amd64 localhost:5001/order-api:multi 2>/dev/null || true
docker rmi registry:2 aquasec/trivy:latest wagoodman/dive:latest 2>/dev/null || true
```
(`-v` also removes the registry's anonymous volume. `labs/day01/Dockerfile`, the one you wrote, stays as your work. The `orderflow/*` images from `labs/shared/load-images.sh` are not touched.)

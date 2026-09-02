# awsdevops-sample

A deliberately tiny Go HTTP service used as the single artifact for every lab in
this learning path (Day 1 CI build, Day 2 CodeBuild/ECR push, Day 3 Fargate +
ALB deploy, Day 4 local `kind` deploy, Day 5 CloudWatch alarms and rollback).
Building one artifact once, and reusing it for five days, is what makes the
chain of custody (source → image → registry → running task) a fact you can
trace instead of a story you have to trust.

## Routes

| Route       | Purpose                                                                                     | Used by |
|-------------|-----------------------------------------------------------------------------------------------|---------|
| `GET /`         | Returns JSON `{"service","version","commit","hostname"}`. Confirms which build and which task instance answered. | All days, spot checks |
| `GET /healthz`  | Liveness. Always returns `200 ok`. Answers "is the process up at all?" and never fails on purpose. | Day 3 ECS health check, Day 4 `kind` liveness probe |
| `GET /readyz`   | Readiness. Returns `200 ready`, or `503 poisoned` when the `POISON` env var is `"true"`.       | Day 3 poison-pill deploy test, Day 4 readiness-probe test |
| `GET /burn`     | Returns `500 burned` with probability `BURN_RATE` (0.0–1.0), else `200 ok`. Delayed by `LATENCY_MS` first, same as `/`. Drives ALB 5XX metrics on demand. | Day 3 and Day 5 CloudWatch alarm tests |

## Environment variables

| Var           | Default   | Effect |
|---------------|-----------|--------|
| `PORT`        | `8080`    | Listen port. |
| `POISON`      | `false`   | `"true"` makes `/readyz` return `503`. |
| `BURN_RATE`   | `0`       | Fraction (`0.0`–`1.0`) of `/burn` requests that return `500`. Invalid values are logged and treated as `0`. |
| `LATENCY_MS`  | `0`       | Fixed delay, in milliseconds, applied to `GET /` and `GET /burn` before either responds. Independent of `BURN_RATE` — set this alone to drive a latency-only failure (all `200`s, just slow) with no error-rate increase, which is what Day 5's p99 alarm needs to be exercised deterministically. Invalid values are logged and treated as `0`. |

## Build-time variables (ldflags)

`main.version` and `main.gitCommit` are injected at build time via:

```
-ldflags="-X main.version=${VERSION} -X main.gitCommit=${GIT_COMMIT}"
```

They default to `"dev"` and `"unknown"` when built without ldflags (e.g. plain
`go build` or `go run .`), and surface in the `GET /` response so you can tell
which build is actually answering a request.

## Why zero dependencies

`go.mod` declares no third-party modules — only the standard library
(`net/http`, `encoding/json`, `math/rand`, `strconv`, `os`, `log`). This is
deliberate: it keeps the CodeBuild caching lessons later in this path about
*Docker layers and Go build caching*, not about dependency-resolution
flakiness, private module auth, or supply-chain scanning noise. A real service
would have dependencies; this one is a teaching artifact.

## Why `scratch`

The final image `FROM scratch` contains nothing but the statically linked
binary (`CGO_ENABLED=0`, no libc). That buys:

- **Small image** — roughly 15 MB, which matters for ECR storage cost and
  Fargate/`kind` pull time.
- **Small attack surface** — no shell, no package manager, no OS packages to
  patch or scan.

**The honest tradeoff:** there is no shell in the final image, which means
**no `docker exec -it <container> sh`, no `curl` from inside the container, no
`cat /etc/...` to check a mounted file.** If the process is misbehaving, your
only debugging tools are the container's stdout/stderr logs (CloudWatch Logs
in Day 3, `kubectl logs` in Day 4) and whatever the process itself exposes
over HTTP (`/`, `/healthz`, `/readyz`). This is a real cost, not a free lunch
— you are trading interactive debuggability for a smaller, harder-to-tamper-
with image. Day 5's incident-response material asks you to argue both sides
of that tradeoff explicitly.

## Why arm64 everywhere

- CodeBuild `ARM_CONTAINER` compute is roughly 30% cheaper per build-minute
  than the equivalent x86 compute.
- Fargate arm64 (Graviton) tasks are cheaper per vCPU/GB-hour than x86 Fargate
  tasks.
- If you're building or running labs on Apple Silicon, your local `kind`
  cluster (Day 4) is arm64 natively — no emulation, no `--platform` surprises.

The Dockerfile therefore always targets `GOOS=linux GOARCH=arm64`, and the
build stage uses `--platform=$BUILDPLATFORM` so it builds fast on both arm64
and x86 hosts while always producing an arm64 final image.

## Running locally

No Docker required — this is plain Go:

```bash
cd app
go run .                      # then: curl localhost:8080/readyz
POISON=true go run .          # curl localhost:8080/readyz -> 503
BURN_RATE=0.5 go run .        # curl localhost:8080/burn repeatedly -> ~half are 500
LATENCY_MS=1500 go run .      # curl localhost:8080/ or /burn -> still 200, ~1.5s slower
```

## Verifying (offline, no Docker)

```bash
cd app
gofmt -l .            # must print nothing
go vet ./...           # must pass — local only, no network, no infra
```

Building the container image (`docker build`) and pushing it happen in later
labs, not here.

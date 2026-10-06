# Docker & Kubernetes Mastery — Review Fix Plan (3 passes)

**Spec:** `k8s_docker_mastery/docs/superpowers/specs/2026-10-06-k8s-docker-mastery-design.md` (binding authority for scope)
**Findings:** `k8s_docker_mastery/docs/superpowers/reviews/2026-10-06-review-findings.md` (IDs like D4-2 refer to it — READ the sections your task names)
**Goal:** every lab runs end-to-end on the learner's machine (pass 1), every claim is correct as of Oct 2026 (pass 2),
and the course fits an API-gateway / microservices engineer who wants to recall and consolidate (pass 3).
Each day task does all three passes for its own files.

## Global Constraints (every task)

- Course root: `/Users/hunghd/git_clone/learning_path/k8s_docker_mastery`. All lab commands in READMEs are written
  to run **from the course root** (say so once at the top of each lab README).
- Edit ONLY the files your task lists (create new ones only where listed). No git commands at all.
- Learner environment (target): macOS Apple Silicon, Docker Desktop with Kubernetes on the **kind provisioner**
  (context `docker-desktop`, node `desktop-control-plane`, k8s 1.34, kindnet CNI, StorageClass `hostpath`/`standard`
  = rancher.io/local-path). Labs must also note the two alternatives in one line each where they differ:
  Docker Desktop **kubeadm** provisioner (node `docker-desktop`: local images visible, NetworkPolicy NOT enforced),
  and plain `kind` (`kind load docker-image`).
- Tool versions to use: Go **1.25** (`golang:1.25-alpine`, `go 1.25` in go.mod); Helm **4** (current 4.3.0) —
  binary for live testing at `/private/tmp/claude-504/-Users-hunghd-git-clone-learning-path/798875aa-a66b-449c-b337-a59c692108e1/scratchpad/bin/helm`
  (learner docs just say `helm`, install with `brew install helm`); Envoy Gateway **v1.9.2**; metrics-server **v0.9.0**;
  upstream Kubernetes stable 1.37. Postgres image `postgres:16-alpine` unless the task says otherwise.
- Images are distroless (no shell): debugging inside pods uses `kubectl debug --image=... --target=<container>`
  ephemeral containers, never `kubectl exec ... sh`.
- **Live verification is required**: run your lab end-to-end on the Docker Desktop cluster / engine
  (`kubectl --context docker-desktop`), record the key command outputs as evidence in your report file, then run
  your teardown and confirm nothing of yours is left (`kubectl get ns`, `docker ps -a`, `docker volume ls`).
  Only create resources in namespace `orderflow` (plus the controller namespaces your task installs, e.g.
  `envoy-gateway-system`, `kube-system` for metrics-server). Never touch other namespaces' resources.
  If the kindnet agent wedges (finding E2), `kubectl rollout restart ds/kindnet -n kube-system` is permitted.
  Never touch AWS. Use `/usr/bin/grep` in shell checks (grep is aliased).
- Images get into the cluster ONLY via `labs/shared/load-images.sh` (Task 1). Each K8s day starts from a clean
  namespace via `labs/shared/reset.sh` (Task 1).
- Content day files keep the existing structure: `# Day N — <Title>`, `## Why this matters`, `## Core concepts`,
  `## Exercises` (every exercise: `**Hint:**` + `**Solution sketch:**`), `## Anti-patterns / Common mistakes`,
  `## Lab`, `## Teardown`. Add a `## Recall drill` section (5–8 short Q→A pairs, answers in a collapsed
  `<details>` block) just before `## Lab`.
- Every lab README starts (after the title) with `## Start here — plain steps`: 5–8 numbered plain-English steps
  (where to run, what to build/load, what you should see, how you know you're done), and ends with
  `## Stuck? Hints` (3–6 symptom → cause → fix bullets, including environment gotchas) before `## Teardown`.
  Lab README teardown and content-day teardown must list the same commands.
- SOLUTION.md must match what the commands really print on the live run (names, counts, ports, exit codes).
  Use real output you observed; trim long output with `...`.
- Every command block must work when pasted into **zsh** (macOS default): never rely on word-splitting of an unquoted
  variable (`$q` holding "get pods" is ONE argument in zsh); avoid unmatched globs (zsh `nomatch` aborts); verify
  loops with `zsh -c`. Async effects (fire-and-forget calls, first image pulls) need a wait before reading results.
- No real secrets/account IDs; placeholders only. No LaTeX in markdown (use plain arrows `→`).
- Prose: concise, technical, senior-engineer audience. Don't pad. Mark anything Docker-Desktop-specific as such.

## Shared contracts (produced by Task 1, consumed by Tasks 2–10)

Each Go service (`order-api` :8080, `payment-service` :8081, `notification-service` :8082):
- `PORT` env (default above). Non-numeric/out-of-range PORT → `log.Fatalf("invalid PORT %q: ...")` → exit 1
  (gives a real CrashLoopBackOff with logs).
- `GET /health` = liveness: 200 `{"status":"ok","service":"<name>"}` while the process runs.
- `GET /ready` = readiness: 200 `{"status":"ready",...}`; returns 503 `{"status":"draining"}` once SIGTERM received.
- `server -healthcheck` (first arg): GET `http://127.0.0.1:$PORT/health` with 2s timeout, exit 0 if 200 else 1.
  Used by Docker HEALTHCHECK / compose.
- `GET /debug/alloc?mb=N` exists only when `ENABLE_DEBUG_ALLOC=1` (404 otherwise): allocates N MiB, writes every
  page, keeps it referenced (cumulative), returns `{"allocated_mb":N,"retained_mb":total}`.
- On SIGTERM: set not-ready (`/ready` → 503), log `"SIGTERM received, draining"`, then keep serving for
  `DRAIN_DELAY_SECONDS` (env, default 0) before `http.Server.Shutdown` with 20s timeout, exit 0. Default 0 keeps the
  Day 6 preStop experiment honest (0 vs 10s preStop); setting it shows the app-level alternative and makes the 503 observable.
- order-api keeps its in-memory store and existing endpoints (`/orders`, `/orders/{id}`), still calls payment and
  notification via `PAYMENT_SERVICE_URL` / `NOTIFICATION_SERVICE_URL`. It does not use Postgres (labs say so).
- Dockerfiles: `# syntax=docker/dockerfile:1`; builder `FROM --platform=$BUILDPLATFORM golang:1.25-alpine`;
  `ARG TARGETOS TARGETARCH`; BuildKit cache mounts for `/go/pkg/mod` and `/root/.cache/go-build`;
  `COPY go.mod ./` with a comment that there is no go.sum because there are no dependencies (`go.sum*` glob pattern
  shown as the general form); `CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -trimpath -ldflags="-s -w"`;
  runtime `gcr.io/distroless/static-debian12:nonroot` (or `static-debian13:nonroot` if it pulls); `USER 65532:65532`;
  exec-form `ENTRYPOINT ["/app/server"]`; `HEALTHCHECK CMD ["/app/server","-healthcheck"]`. Each service gets a
  `.dockerignore`.
- `labs/shared/load-images.sh [TAG]` (default `v1`): builds `orderflow/order-api|payment-service|notification-service:TAG`
  from `labs/shared/<svc>/` and loads them into the current kube context's cluster: node `desktop-control-plane`
  exists → `docker save | docker exec -i desktop-control-plane ctr -n k8s.io images import -`; context `kind-*` →
  `kind load docker-image --name <cluster>`; node `docker-desktop` (kubeadm) → no load needed; else print what to do.
  Works from any cwd. Prints what it did.
- `labs/shared/reset.sh`: deletes namespace `orderflow` (wait), deletes Helm release `orderflow` if present, then
  recreates the namespace unlabeled (no PSA label). Idempotent, prints state.
- Edge (produced by Task 5, consumed by Tasks 7–8): Envoy Gateway v1.9.2 in `envoy-gateway-system`; GatewayClass `eg`;
  shared Gateway `edge` in namespace `gateway-infra` (platform-owned — survives `reset.sh`), HTTP listener port 80,
  `allowedRoutes.namespaces.from: All`. App teams attach HTTPRoutes from `orderflow` with
  `parentRefs: [{name: edge, namespace: gateway-infra}]`. Task 5 records in its lab README how the learner reaches the
  Gateway from the Mac; Tasks 7–8 reuse exactly that. Task 5 ships `labs/day04/manifests/gateway.yaml` (GatewayClass +
  namespace + Gateway) that later days re-apply idempotently.
  [Task 5 result, LIVE] Mac access: `curl http://localhost/<path>` (Docker Desktop publishes the LB port 80 on
  localhost; the LB IP itself is not routable). Fallback: `kubectl port-forward -n envoy-gateway-system svc/<proxy-svc> 8888:80`
  (svc found by label `gateway.envoyproxy.io/owning-gateway-name=edge`). Envoy proxy pods run in namespace
  `envoy-gateway-system` — NetworkPolicies admitting edge traffic must select that namespace.
- `labs/shared/metrics-server.yaml`: upstream v0.9.0 components manifest + `--kubelet-insecure-tls` (needed on
  Docker Desktop/kind), moved from `labs/day07/manifests/metrics-server.yaml` (delete the old file).

---

### Task 1: Shared services, Dockerfiles, helper scripts

Files: `labs/shared/{order-api,payment-service,notification-service}/{main.go,go.mod,Dockerfile,.dockerignore}`,
`labs/shared/order-api/Dockerfile.bad`, create `labs/shared/load-images.sh`, `labs/shared/reset.sh`,
create `labs/shared/metrics-server.yaml`, delete `labs/day07/manifests/metrics-server.yaml`.
Findings: S1–S7, D1-8 (Dockerfile.bad comment), D7-4.

- Implement the Shared contracts above exactly. Keep code small, idiomatic, std-lib only, gofmt'd; `go vet` clean.
- `Dockerfile.bad`: keep it deliberately bad (golang:latest-style fat image, root, COPY before deps, no
  .dockerignore effect) but make every comment true (no "downloading dependencies" step that doesn't exist).
- Tests: `go vet ./... && go build` for each service; add a small `main_test.go` per service covering /health,
  /ready (incl. 503 after draining flag set), PORT validation helper, and /debug/alloc gating (404 when disabled).
  `go test ./...` passes.
- Live: `bash labs/shared/load-images.sh` → `kubectl run` a pod per image in ns `orderflow` (after
  `bash labs/shared/reset.sh`) and show it Running; `docker run` order-api with `--memory=32m -e ENABLE_DEBUG_ALLOC=1`
  and show `/debug/alloc?mb=64` produces `OOMKilled true / 137`; show `docker inspect` health status `healthy`
  for a container started from the new image; `docker buildx build --platform linux/amd64` of one service succeeds;
  apply `labs/shared/metrics-server.yaml` and show `kubectl top nodes` works (leave metrics-server installed — later
  days use it); run `reset.sh` twice to show idempotence; delete ns `orderflow` at the end.

### Task 2: Day 1 — Docker internals & images

Files: `content/day01.md`, `labs/day01/README.md`, `labs/day01/SOLUTION.md`.
Findings: D1-1..D1-8, plus Shared contracts.
- Pass 1: OOM step uses `--memory=32m --memory-swap=32m -e ENABLE_DEBUG_ALLOC=1` + `curl localhost:8080/debug/alloc?mb=64`
  (state why it OOMs; add GOMEMLIMIT lesson: run again with `-e GOMEMLIMIT=28MiB` and compare). Real sizes from the
  live run. Teardown names match the containers created. Learner WRITES the multi-stage Dockerfile from a skeleton
  (`labs/day01/README.md` gives the requirements; the reference is `labs/shared/order-api/Dockerfile`, revealed in SOLUTION).
- Add hands-on internals step via the VM: `docker run --rm -it --privileged --pid=host alpine nsenter -t 1 -m -u -n -i sh`
  → inspect the container PID's `/proc/$PID/ns`, `lsns -p $PID`, `/proc/$PID/cgroup`, `memory.max`; overlay via
  `docker inspect -f '{{json .GraphDriver}}'` and a note about the containerd image store (Engine 29 default).
  Optional `dive` (`docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock wagoodman/dive order-api:bad`).
- PID 1 step: build a shell-form variant inline (heredoc Dockerfile with `ENTRYPOINT sh -c "echo starting; /app/server"`)
  and time `docker stop` vs the prod image; then `docker run --init` fix; explain.
- Pass 2: fix D1-4, D1-5, D1-8 content errors. Pass 3: BuildKit cache + secret mounts, buildx multi-arch
  (Apple Silicon → amd64 nodes), `docker scout cves`/trivy + `--sbom=true --provenance=mode=max`, digest pinning,
  OCI manifest/index/config (show `docker buildx imagetools inspect`), containerd-shim in the runtime chain, GOMEMLIMIT.

### Task 3: Day 2 — Docker networking, volumes, Compose

Files: `content/day02.md`, `labs/day02/README.md`, `labs/day02/SOLUTION.md`, `labs/day02/docker-compose.yml`,
`labs/day02/docker-compose.override.yml`, `labs/day02/.env.example`; may create `labs/day02/docker-compose.test.yml`.
Findings: D2-1..D2-8.
- Pass 1: healthchecks use `/app/server -healthcheck` (or inherit the image HEALTHCHECK — pick one, explain);
  order-api gets a healthcheck; `depends_on` with `service_healthy` for payment/notification; `docker compose up -d --wait`;
  pg_isready with `-h 127.0.0.1`; publish Postgres on 15432 in override; remove unused LOG_LEVEL; pin the network subnet
  if the docs cite it; correct image names; `up -d <svc>` to apply env changes. Live: all services `(healthy)`.
- Add internals steps: netshoot in the engine netns (`--net=host --privileged nicolaka/netshoot`: `ip -br link`,
  `bridge link`, `iptables -t nat -S` / `nft list ruleset` — whichever works on the live run) and in a container's
  netns (`--network container:orderflow-order-api`: `cat /etc/resolv.conf`, `dig payment-service`) showing 127.0.0.11.
  Volume inspection via `docker run --rm -v <vol>:/data alpine ls -la /data`.
- Pass 2: D2-2, D2-5, D2-6, D2-8 corrections. Pass 3: profiles, env precedence (interpolation `.env` vs container
  `environment`/`env_file`), network aliases, `compose watch`, dev vs test override file demo, distroless debugging
  (`--network container:` sidecar, `docker debug` note).

### Task 4: Day 3 — Kubernetes core objects

Files: `content/day03.md`, `labs/day03/README.md`, `labs/day03/SOLUTION.md`, `labs/day03/manifests/*.yaml`.
Findings: D3-1..D3-7, E1.
- Pass 1: Start with `reset.sh` + `load-images.sh` (and `load-images.sh v2` for the rolling-update step — define
  what differs in v2, e.g. env `APP_VERSION` or a label; must be observable). Manifests: readiness `/ready`,
  liveness `/health`, securityContext-ready (`runAsNonRoot`, numeric user) without PSA label yet. `--timeout=60s`
  on rollout status. Scale back after the scale step. SOLUTION counts/ports from the live run.
- Pass 2: D3-3, D3-6, D3-7. Pass 3: owner references + GC + `kubectl delete deploy order-api --cascade=orphan`
  demo + re-adoption, pod-template-hash, informers; ConfigMap env vs volume hot-reload demo (mount a ConfigMap
  file, edit, observe file change vs stale env), subPath gotcha, `immutable: true`; progressDeadlineSeconds.

### Task 5: Day 4 — Kubernetes networking, Gateway API, NetworkPolicy

Files: `content/day04.md`, `labs/day04/README.md`, `labs/day04/SOLUTION.md`, `labs/day04/manifests/*` (may replace
`ingress.yaml` with `gateway.yaml` + `httproute.yaml`; keep `ingress.yaml` only as a documented legacy example that is
NOT applied, or delete it).
Findings: D4-1..D4-9, E2, E5.
- Pass 1 (decision: **Gateway API with Envoy Gateway v1.9.2 is the lab's edge**; ingress-nginx is retired):
  install via `helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.9.2 -n envoy-gateway-system --create-namespace`
  (verify live; this installs Gateway API CRDs), GatewayClass + Gateway + HTTPRoute for `/orders` → order-api
  (payment stays internal), reach it from the Mac (find the working path live: LoadBalancer IP via Docker Desktop's
  cloud-provider-kind, or `kubectl port-forward` to the envoy Service — document what works). Demonstrate a header
  match or weighted backendRef (canary) since this learner runs API gateways. Teach Ingress (resource, IngressClass,
  pathType, TLS) in content as the legacy API with a migration note (ingress2gateway).
- NetworkPolicy: default-deny + allow edge(envoy namespace)→order-api, order-api→payment, order-api→notification.
  Allowed-path test via `kubectl debug $ORDER_POD --image=curlimages/curl --target=order-api`. Add an
  "enforcement check" step and the kindnet wedge + kubeadm-provisioner notes. Headless DNS via FQDN.
- Dataplane step: inspect kube-proxy rules on the node (`docker exec desktop-control-plane` or
  `kubectl debug node/desktop-control-plane --profile=sysadmin`; `iptables-save -t nat | grep KUBE-SVC` or nft — use
  whatever the live kube-proxy mode is) and conntrack if available. EndpointSlices instead of Endpoints.
- Pass 2: D4-6, D4-8, D4-9. Pass 3: conntrack/long-lived connection & gRPC load-balancing pitfall, MASQ/SNAT,
  externalTrafficPolicy/internalTrafficPolicy, ExternalName, NetworkPolicy AND/OR gotcha, egress default-deny vs DNS,
  AdminNetworkPolicy mention, Gateway API role split (infra vs app teams), GRPCRoute, IngressNightmare lesson.

### Task 6: Day 5 — Storage, security, RBAC

Files: `content/day05.md`, `labs/day05/README.md`, `labs/day05/SOLUTION.md`, `labs/day05/manifests/*.yaml`.
Findings: D5-1..D5-7.
- Pass 1: PSA preview first (`kubectl label --dry-run=server --overwrite ns orderflow pod-security.kubernetes.io/enforce=restricted`),
  then enforce; all Day 5 pods restricted-compliant (verified fix in D5-1); fs-probe busybox container for the
  read-only rootfs break; `kubectl get sc` step; use `pvc.yaml` or delete it; Retain vs Delete demo (PV reclaim);
  teardown removes the PSA label (or reset.sh) — say so. automountServiceAccountToken false.
- Pass 2: D5-3 corrections. Pass 3: PVC retention policy, podManagementPolicy, PVCs survive STS delete (demo:
  delete STS, PVC remains, recreate → data still there), volume node/zone affinity, RoleBinding→ClusterRole `view`,
  `auth can-i --list --as=system:serviceaccount:orderflow:<sa>`, secrets via volume vs env anti-pattern,
  external secret managers mention (External Secrets Operator / CSI Secrets Store).

### Task 7: Day 6 — Helm 4, chart, design patterns, graceful shutdown

Files: `content/day06.md`, `labs/day06/README.md`, `labs/day06/SOLUTION.md`, everything under
`labs/day06/orderflow-chart/` (may add templates/files, e.g. `templates/httproute.yaml`, `templates/postgres.yaml`,
`values-eks.yaml` stub is Task 9's — do not create it).
Findings: D6-1..D6-12, E3.
- Chart: restricted-PSA-compliant pods everywhere (namespace labeled restricted in this lab and it must install);
  names consistent and documented; readiness `/ready`, liveness `/health`, startupProbe; native sidecar
  (`initContainers` + `restartPolicy: Always`) that does something visible (e.g. busybox tailing a shared emptyDir file
  the app... — the apps log to stdout, so pick an honest sidecar job, e.g. a tiny reverse-proxy/ambassador or a
  log shipper reading a file written by a second demo container; justify the choice); init container waits for
  Postgres; real migration via Helm hook Job (`post-install,pre-upgrade`) running `psql` CREATE TABLE against a
  chart-managed Postgres (`postgres.enabled`, StatefulSet + headless svc, restricted-compliant) with password from a
  Secret; `replicas` omitted when HPA enabled; PDB; topologySpreadConstraints; `lifecycle.preStop.sleep.seconds`
  + `terminationGracePeriodSeconds`; edge via HTTPRoute to the Day 4 Gateway (`gateway.enabled`, parentRef values)
  with Ingress template kept optional and correct (`ingress.enabled`, className/annotations/paths from values,
  Prefix paths, no broken rewrite) — Task 9 will rely on `ingress.className`, `ingress.annotations`, `ingress.paths[]`
  with `pathType`, and per-service `image.repository/tag` values; ConfigMap name must not collide; no
  `values.namespace` (use `.Release.Namespace`); fix duplicate labels; image repo/tag per service in values.
- Lab: Prerequisites = `reset.sh`, `load-images.sh`, Envoy Gateway from Day 4 present (or install command),
  metrics-server present (`labs/shared/metrics-server.yaml`). `helm lint`, `helm template | kubectl apply --dry-run=server`,
  install, upgrade, history, rollback with correct revision numbers (count them in the live run), production values,
  OOM via `ENABLE_DEBUG_ALLOC` + low limit with requests ≤ limits, HPA reacting to load (show `kubectl get hpa` with real
  numbers), PDB + drain behaviour explanation, broken readiness step, **graceful shutdown experiment**: load loop
  through the Gateway during `kubectl rollout restart` with preStop sleep 0 vs 10s, count non-2xx.
- Content pass 2: D6-7 corrections; pass 3: Helm 4 changes, hooks, helm diff plugin, Chart.lock/deps, range/with,
  Kustomize vs Helm, GitOps (Argo CD/Flux) and operators/CRDs short sections, native sidecar, the endpoint-propagation race.

### Task 8: Day 7 — Observability, debugging, production synthesis

Files: `content/day07.md`, `labs/day07/README.md`, `labs/day07/SOLUTION.md`, `labs/day07/debug-runbook.md`,
`labs/day07/manifests/chaos-scenarios.yaml` (may add more manifests under `labs/day07/manifests/`).
Findings: D7-1..D7-5, F3.
- Pass 1: `scenario` label on pod templates; OOM scenario via `ENABLE_DEBUG_ALLOC` (+ an exec-free trigger: a
  `command`/args can't call curl in distroless — use a tiny curlimages/curl sidecar or a startup env like a dedicated
  scenario image approach; simplest honest option: a second container `curlimages/curl` in the pod that hits
  `localhost:<port>/debug/alloc?mb=64` after a sleep) and verify `OOMKilled`/137 live; real CrashLoop via
  `PORT=notanumber` (logs --previous shows the fatal line); keep a StartError scenario but label it honestly
  (missing binary → StartError/128, empty logs); add DNS failure (egress default-deny NetworkPolicy without port-53
  allowance → `no such host`), selector/readiness mismatch (Service with no endpoints / readiness failing → gateway 503),
  Pending (unsatisfiable requests or nodeSelector). Every scenario's SOLUTION shows the real observed signals.
  metrics-server comes from `labs/shared/metrics-server.yaml` (Task 1 moved it).
- Ephemeral-container exercise (`kubectl debug -it <pod> --image=nicolaka/netshoot --target=<c>`), `--copy-to`,
  `kubectl debug node/`. Runbook: complete DNS section, kindnet wedge entry, exit-code table (0/1/126/127/128/137/143).
- Pass 2: D7-5. Pass 3: service mesh concepts (sidecar vs ambient, Envoy xDS, mTLS, retries/timeouts/circuit breaking,
  retry budgets), where to rate-limit (gateway vs mesh vs app), canary via HTTPRoute weights, decision framework with
  EKS Auto Mode/Karpenter.

### Task 9: EKS appendix

Files: `content/appendix-eks.md`; create `labs/eks/README.md`, `labs/eks/SOLUTION.md`, `labs/eks/cluster.yaml`,
`labs/eks/teardown.md` (or teardown inside README); create `labs/day06/orderflow-chart/values-eks.yaml`.
Findings: X1–X9. **Do not run anything against AWS.** Validate YAML syntax locally (`python3 -c 'import yaml...'`),
`helm template` the chart with `values-eks.yaml` and `kubectl apply --dry-run=client` it.
- eksctl ClusterConfig: version "1.36" with an explicit "check `aws eks describe-cluster-versions --default-only`
  and use the current default" note; `nat: {gateway: Single}`; managed nodegroup of Graviton `t4g.medium` (arm64 —
  Mac-built images run as-is; mention amd64 alternative with `docker buildx --platform linux/amd64`); addons
  `vpc-cni`, `coredns`, `kube-proxy`, `eks-pod-identity-agent`, `aws-ebs-csi-driver` with Pod Identity association;
  `<ACCOUNT_ID>`/region placeholders.
- Steps: ECR repos + push (`aws ecr get-login-password | docker login`), Pod Identity for AWS Load Balancer
  Controller (IAM policy from the pinned controller release's `iam_policy.json`), helm install from
  `https://aws.github.io/eks-charts`, gp3 default StorageClass, chart install with values-eks.yaml (ALB Ingress:
  className alb, Prefix paths, `alb.ingress.kubernetes.io/scheme: internet-facing`, `target-type: ip`), verify ALB,
  Pod Identity verification (`aws sts get-caller-identity` from a pod with the SA). IRSA taught as the alternative
  (Fargate, cross-account) with a comparison table. EKS Auto Mode + Karpenter section. Costs ≈ $0.35–0.40/h with a table.
- Teardown in strict order with CLI verification commands (X8). Keep content structure (Why/Core/Exercises with
  hints+sketches/Anti-patterns/Lab/Teardown).

### Task 10: Top level — README, STRATEGY, GLOSSARY, cheat sheet, recall

Files: `README.md`, `STRATEGY.md`, `content/GLOSSARY.md`; create `content/CHEATSHEET.md`, `content/RECALL.md`.
Findings: F1–F5. Read the finished day files first (they were updated by Tasks 1–9).
- README: `## Start here` (one-time setup: Docker Desktop with Kubernetes enabled (kind provisioner recommended),
  `kubectl config use-context docker-desktop`, `kubectl get nodes`, `brew install helm` (Helm 4), Go 1.25,
  `bash labs/shared/load-images.sh`, metrics-server), the provisioner table (kind vs kubeadm vs plain kind:
  images, NetworkPolicy), a timed 7-day schedule (~3.5 h/day: theory / lab / break-it / recall blocks), how each day
  begins (`reset.sh` + `load-images.sh`), cost note, remove LaTeX.
- STRATEGY: keep the core, add an "aggressive 7-day practice protocol" (daily loop with time boxes, the
  break-it-first rule, spaced recall on days 2/4/7 using RECALL.md), and a short API-gateway-engineer mapping
  (what you already know → K8s/Gateway API concept).
- GLOSSARY: F4 corrections + missing terms. CHEATSHEET: one page of high-value commands and decision rules
  (debug tree, exit codes, probes, QoS, PSA, NetworkPolicy, Helm 4). RECALL: cumulative recall questions per day
  with answers in `<details>`, plus a final 20-question mixed self-test.
- Also add one line to the spec doc's top (`docs/superpowers/specs/...design.md`) pointing to the fix plan and
  findings (the only edit to that file).

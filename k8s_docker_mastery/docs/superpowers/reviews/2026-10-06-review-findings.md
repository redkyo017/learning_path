# Review findings — k8s_docker_mastery (2026-10-06)

Source: 4 static reviewers + a live run on Docker Desktop (macOS, Apple Silicon, Docker Engine 29.8,
Kubernetes 1.34.3 via the **kind provisioner** — node `desktop-control-plane`, containerd 2.2, kindnet CNI,
StorageClasses `hostpath` and `standard (default)` both `rancher.io/local-path`). `[LIVE]` = reproduced on
that machine. IDs are referenced by the fix plan.

## Environment facts (LIVE, load-bearing for every K8s day)
- E1 [LIVE] Images built with `docker build` are NOT visible to the kind-provisioner cluster → every pod
  `ImagePullBackOff`. The labs/day03 README claim "Docker Desktop built-in K8s shares the local Docker
  engine cache" is only true for the older kubeadm provisioner. Working loader:
  `docker save IMG | docker exec -i desktop-control-plane ctr -n k8s.io images import -`.
  Plain `kind` clusters: `kind load docker-image IMG --name <cluster>`. kubeadm provisioner: nothing needed.
- E2 [LIVE] kindnet on this cluster DOES enforce NetworkPolicy (allowed path 200, blocked path timeout).
  The kubeadm provisioner does not. kindnet's policy agent can wedge (log: `Could not receive message
  error="netlink receive: no such file or directory"`) and then drops ALL traffic to pods that ever had a
  policy, even after policies are deleted. Fix: `kubectl rollout restart ds/kindnet -n kube-system`.
- E3 [LIVE] No local helm; `alpine/helm:latest` is Helm **v4.3.0**. Helm 4 is current (Nov 2025+).
- E4 Local Go is 1.25.5. `golang:1.21` is EOL since Aug 2024.
- E5 ingress-nginx (community) was retired by SIG Network in March 2026; Gateway API is the forward path.

## Shared services (labs/shared)
- S1 [LIVE] Compose healthcheck `/app/server --check`: no such flag; starts 2nd server → EADDRINUSE →
  permanently unhealthy. Need a real `-healthcheck` mode (GET 127.0.0.1:$PORT/health, exit 0/1).
- S2 [LIVE] Idle Go server uses ~5 MiB; nothing allocates → no OOM demos possible. Need an opt-in
  allocation endpoint (e.g. `/debug/alloc?mb=N`, only when `ENABLE_DEBUG_ALLOC=1`, touches pages).
- S3 Readiness and liveness both use `/health` while the course says never do that → need `/ready`
  (readiness; can fail when deps/draining) distinct from `/health` (liveness, process alive).
- S4 `USER nonroot:nonroot` (non-numeric) + K8s `runAsNonRoot` without `runAsUser` → CreateContainerConfigError
  trap. Use `USER 65532:65532`.
- S5 No `.dockerignore`; no BuildKit cache mounts; no TARGETOS/TARGETARCH; golang:1.21; go.mod `go 1.21`.
- S6 No real crash path for a CrashLoop demo with useful logs (e.g. invalid PORT → log.Fatalf).
- S7 order-api never uses Postgres (in-memory map) — Postgres usage in labs is illustrative only; say so.

## Day 1
- D1-1 [LIVE] OOM step never fires (5.0MiB / 10MiB after 50 POSTs). Success signal unreachable.
- D1-2 [LIVE] prod image is 7.2MB, README says 15–20MB; SOLUTION sizes wrong. `docker top` shows `65532` not `nonroot`.
- D1-3 content:237 `/proc/<pid>/ns` etc. can't run on macOS (VM). Lab never inspects namespaces/cgroups/overlay.
  Use `docker run --rm -it --privileged --pid=host alpine nsenter -t 1 -m -u -n -i sh` to enter the VM;
  `docker inspect -f '{{.State.Pid}}'`, `lsns -p`, `/proc/$PID/cgroup`, `memory.max`; containerd image store
  (default on Engine 29) changes overlay paths. Add `dive`.
- D1-4 "six namespaces" → eight (add cgroup, time). Userns is NOT on by default (userns-remap opt-in;
  container root = host root unless rootless/remap).
- D1-5 PID 1: kernel ignores signals to PID 1 with no handler; zombies; shell-form often exec-optimised for a
  single command — trap is compound commands / wrapper scripts without `exec`; shell-form ENTRYPOINT ignores
  CMD/args; `--init`/tini; `exec "$@"`. Add a lab step timing `docker stop` (~10s vs instant).
- D1-6 Learner never writes the multi-stage Dockerfile; content pattern `COPY go.mod go.sum ./` fails (no go.sum).
- D1-7 Missing: BuildKit `--mount=type=cache` and `--mount=type=secret`, buildx multi-platform on Apple Silicon,
  scanning/SBOM (`docker scout` / trivy, `--sbom --provenance`), digest pinning, OCI manifest/index/config,
  containerd-shim in runtime chain, `GOMEMLIMIT` (Go ignores cgroup memory; Go 1.25 GOMAXPROCS is cgroup-aware).
- D1-8 minors: io.weight is weight not limit (io.max); EEVDF since 6.6; overlay copy-up copies whole file,
  opaque dirs; RUN cache keys on command string; Dockerfile.bad comment mentions nonexistent download;
  content teardown names wrong containers; paths relative to course root; Exercise 2 overstates.

## Day 2
- D2-1 [LIVE] = S1. Also `order-api` has no healthcheck and depends with `service_started` which hides it.
- D2-2 Cross-network isolation is firewall rules (DOCKER-ISOLATION / Engine 28+ DOCKER-FORWARD chains), not L2.
- D2-3 Networking internals described but never inspected; all in the VM on macOS. Add netshoot steps:
  `docker run --rm --net=host --privileged nicolaka/netshoot ...` and `--network container:<c>` to see
  127.0.0.11 resolver. Mention Docker Desktop port forwarder + docker-proxy, SNAT/MASQUERADE.
- D2-4 `docker compose exec <svc> sh` impossible on distroless → teach `--network container:` sidecars / `docker debug`.
- D2-5 Volume host paths live inside the VM; bind-mount ownership claim wrong (numeric UID passes through on
  Linux; VirtioFS remaps on Docker Desktop).
- D2-6 `compose down` doesn't remove images without `--rmi`; restart vs recreate; postgres image declares VOLUME
  (anonymous volume).
- D2-7 Missing: profiles, `env_file` vs `.env` interpolation precedence, network aliases, `compose watch`,
  override for dev vs test, `--wait`. pg_isready should use `-h 127.0.0.1` (init-phase socket false positive).
- D2-8 minors: image names `day02-*`; subnet not pinned; "restart" won't pick up env change (use `up -d`);
  override re-declares ports, sets unused LOG_LEVEL, publishes 5432 (use 15432); overlay is a driver;
  host networking on DD opt-in; engine runs healthchecks; unlink not DELETE.

## Day 3
- D3-1 [LIVE] = E1 (images). Step 5 `rollout status` no timeout → 10 min hang; add `--timeout=60s`;
  teach progressDeadlineSeconds / ProgressDeadlineExceeded, K8s never auto-rolls-back.
- D3-2 SOLUTION numbers assume 2 replicas after Step 4 scaled to 5; SOLUTION port 8082 for payment (is 8081);
  startupProbe mentioned but absent; `kubectl scale` is imperative.
- D3-3 `:latest` anti-pattern wrong (default pull policy already Always; real issue: same template → no rollout,
  no pinning, mixed digests).
- D3-4 Missing owner references, GC, `--cascade=orphan`, pod-template-hash, informer cache (not polling).
- D3-5 Missing ConfigMap volume hot-reload demo, subPath never updates, update delay, `immutable: true`.
- D3-6 kube-proxy modes: add nftables (GA 1.33), IPVS deprecated (1.35).
- D3-7 minors: naked pod survives reboot; ~5 min eviction (tolerationSeconds 300); exercise 1 sketch; undo
  revision numbering; missing anti-patterns "config baked into images", "kubectl run for prod".

## Day 4
- D4-1 [LIVE] = E2 — NetworkPolicy works on kind provisioner, add enforcement-check + kindnet wedge note;
  kubeadm provisioner doesn't enforce.
- D4-2 Ingress rewrite `/api/orders(/|$)(.*)` → `/$2` sends to `/` → 404. Payment exposed via Ingress
  (spec: internal only; also dead once NP enforced).
- D4-3 `kubectl exec ... /app/server --check` bogus; distroless has no shell → use `kubectl debug
  --image=curlimages/curl --target=order-api` (ephemeral container shares netns and pod labels).
- D4-4 ingress-nginx v1.9.4 (2023) and retired (E5). Gateway API missing — critical for an API-gateway
  engineer: GatewayClass/Gateway/HTTPRoute/GRPCRoute role split, weights, header match. CVE-2025-1974.
- D4-5 default-deny blocks order-api→notification-service (no allow) — every POST logs notification failure.
- D4-6 Exercise 1 cause wrong (numeric targetPort mismatch keeps endpoints). Diagram vs SOLUTION: ingress
  controllers go straight to pod IPs from EndpointSlices.
- D4-7 Missing dataplane inspection (`kubectl debug node/... --profile=sysadmin` / nsenter; iptables-save or
  `nft list table ip kube-proxy`; conntrack), conntrack pins long-lived HTTP/gRPC connections (gRPC LB
  pitfall), KUBE-MARK-MASQ/SNAT, externalTrafficPolicy/internalTrafficPolicy, ExternalName.
- D4-8 NetworkPolicy semantics: additive/union; AND vs OR list-item gotcha; egress default-deny breaks DNS;
  ipBlock; AdminNetworkPolicy. Endpoints API deprecated (1.33) → EndpointSlices. kubelet→CRI→CNI (not kubelet→CNI).
  gRPC is L7 (HTTP/2), not L4.
- D4-9 minors: IPVS ClusterIP pingable; ndots fix prefer dnsConfig; inconsistent query counts; 60% stat
  unsourced; FQDN nslookup; test pod joins Service endpoints; regex path called prefix.

## Day 5
- D5-1 [LIVE] postgres STS forbidden by restricted PSA. [LIVE] Fix verified: pod seccompProfile RuntimeDefault +
  container allowPrivilegeEscalation:false + capabilities.drop[ALL]; UID 999 works on hostpath (local-path).
  `postgres:16-alpine` native UID is 70 — either use `postgres:16` (999) or say runAsUser 999 is an override.
- D5-2 Step 6 exec `sh` into distroless → fails; add busybox fs-probe container with same securityContext.
- D5-3 PSA table wrong: readOnlyRootFilesystem not in any PSS; no label = privileged (not baseline); add
  warn/audit modes and `kubectl label --dry-run=server` preview. runAsNonRoot+non-numeric USER trap.
  Capabilities: ~14 default, SYS_ADMIN not among them.
- D5-4 Missing: persistentVolumeClaimRetentionPolicy (GA 1.32), podManagementPolicy, PVCs survive STS delete,
  volume node/zone affinity, volumeBindingMode WaitForFirstConsumer, show `kubectl get sc`, Retain vs Delete demo,
  pvc.yaml unused.
- D5-5 RBAC: add RoleBinding→ClusterRole (view/edit), `auth can-i --list`, aggregated roles;
  `automountServiceAccountToken: true` contradicts its own comment; secrets-as-env anti-pattern.
- D5-6 Teardown must remove the restricted label or say it's deliberately kept (it broke Day 6).
- D5-7 minors: SOLUTION storageclass `standard`→ actual default; emptyDir is disk unless medium Memory;
  label overlap with Day 3 Service; postgres 18 PGDATA layout note.

## Day 6
- D6-1 [LIVE] helm install fails: chart pods violate restricted PSA (payment, notification, migration Job);
  ConfigMap `orderflow-config` collides with Day 3's. Need Prerequisites (clean namespace) + compliant chart.
- D6-2 [LIVE] OOM `--set limits.memory=15Mi` rejected (requests 64Mi > limit). Also wouldn't OOM (S2).
- D6-3 [LIVE] Names: Deployment `orderflow-order-api`, HPA `orderflow-order-api-hpa`, PDB
  `orderflow-order-api-pdb`; README/SOLUTION use `order-api`, `orderflow-hpa`, `orderflow-pdb`.
- D6-4 SOLUTION describes a `db-migrator` that doesn't exist; init container is busybox sleep; hook Job only
  echoes; Helm hooks never taught.
- D6-5 Rollback revision wrong (`helm rollback orderflow 5` = the broken OOM revision).
- D6-6 No native sidecar (initContainers restartPolicy: Always, GA 1.33); sidecar is no-op; no startupProbe
  though diagrams claim one; readiness == liveness; pods are 2/2 not 1/1.
- D6-7 PDB claim wrong (never creates replicas; voluntary only; maxUnavailable; unhealthyPodEvictionPolicy).
  Liveness failure → SIGTERM+grace then SIGKILL. Release secret name `.v<revision>`. rollback creates a new
  revision; doesn't restore PVC/CRDs. Init container failure retries per restartPolicy.
- D6-8 HPA vs Helm: render `replicas` only when HPA disabled. metrics-server only installed on Day 7 → HPA `<unknown>`.
- D6-9 Ingress template broken like D4-2, hardcoded paths/annotations, `values.ingress.paths` unused.
- D6-10 Helm 4 unmentioned (SSA default, `--rollback-on-failure` replaces `--atomic`, `--force-replace`, kstatus wait).
- D6-11 Missing: helm hooks, helm diff, Chart.lock/deps, `range`, topology spread / anti-affinity, preStop sleep
  (native `lifecycle.preStop.sleep.seconds`) + terminationGracePeriodSeconds and the endpoint-propagation race
  (Go services call Shutdown immediately), Kustomize vs Helm, GitOps (Argo CD/Flux), operators/CRDs.
- D6-12 minors: duplicate `app.kubernetes.io/instance` label; `values.namespace` overriding Release.Namespace;
  probe period text; endpoints deprecated; SOLUTION 1/1 vs 2/2.

## Day 7
- D7-1 [LIVE] `scenario:` label only on Deployment metadata → every `-l scenario=` pod command matches nothing.
- D7-2 [LIVE] OOM scenario runs fine (no OOM). [LIVE] crashloop scenario = StartError exit 128, empty logs.
- D7-3 Missing DNS failure scenario (spec criterion 11), runbook DNS section empty; missing selector/readiness
  mismatch scenario; ephemeral containers only a one-liner (images are distroless!); `kubectl debug --copy-to`,
  `debug node/`. pod runAsUser blocks tcpdump in debug container.
- D7-4 metrics-server v0.7.0 → current v0.8.x; must be installed by Day 6.
- D7-5 minors: ImagePull "pull access denied" wording; restart count increments by 1 (back-off doubles);
  dmesg not in events; containerd CRI log format not JSON; drain deletes via Eviction API (no Evicted status);
  etcd contrast; "only portable runtime" overstated; canary via HTTPRoute weights.

## EKS appendix
- X1 K8s 1.29 no longer creatable/standard; use current standard-support version (check with
  `aws eks describe-cluster-versions`).
- X2 No ECR push; arch mismatch (Mac builds arm64; t3 is amd64) → use Graviton `t4g` or buildx amd64.
- X3 Ingress `--set ingress.annotations` ignored; className nginx; nginx regex paths. Need values-eks.yaml /
  chart support for className alb + Prefix paths + annotations. `kubernetes.io/ingress.class` annotation deprecated.
- X4 AWS Load Balancer Controller never installed (IAM policy, identity, helm install from eks-charts).
- X5 EBS CSI role referenced, never created; use add-on + Pod Identity; gp3 default StorageClass annotation.
- X6 Only IRSA → teach EKS Pod Identity first (IRSA for Fargate/cross-account/legacy); misnamed "Pod Identity
  Webhook"; IRSA SA unused — add sts get-caller-identity check.
- X7 Costs contradictory: realistic ≈ $0.35–0.40/h with single NAT; use `nat: {gateway: Single}`.
- X8 Teardown: delete ALB-backed Ingress + verify LB/TG/SG gone before cluster delete, PVC/EBS check by CLI,
  IAM policy/roles, ECR repos, log groups, EIP/NAT check, `eksctl delete cluster --wait`.
- X9 EKS Auto Mode + Karpenter missing; EKS Fargate overrecommended. No labs/eks README/SOLUTION.

## Top-level / fit-to-request
- F1 No "Start here" / quickstart; no timed 7-day schedule (spec ~3.5h/day); README LaTeX arrows.
- F2 No recall drills / cheat sheet though learner asked to "recall and consolidate systematically".
- F3 Gateway API, graceful shutdown/draining practice, service mesh/mTLS/retries/rate-limit concepts thin.
- F4 Glossary errors: compose env precedence (run -e > environment > env_file > image ENV; .env only for
  interpolation); readiness removal done by EndpointSlice controller; grace period includes preStop; QoS
  Guaranteed requires requests==limits for CPU and memory on every container; Pending; subPath. Missing
  terms: Pod Identity, Auto Mode, Karpenter, ephemeral container, service mesh, mTLS, Gateway API kinds,
  native sidecar, EndpointSlice.
- F5 Days assume earlier state without a "rebuild from zero" block.

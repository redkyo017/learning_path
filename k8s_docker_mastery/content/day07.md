# Day 7 — Observability, Debugging & Production Synthesis

## Why this matters

What separates "I can deploy" from "I can operate" is what happens when things fail. Anyone can apply YAML that succeeds on an empty cluster; operating distributed systems means reading the signals a failing system gives you (a status, a reason, an exit code, an event, a log line, a gateway status code), mapping them to a cause, and knowing which layer (app, runtime, scheduler, network, gateway) owns the problem.

Equally important is architectural discernment: **knowing when NOT to use Kubernetes**, and, if you do, which pieces (mesh, gateway, autoscaler) earn their operational cost. Day 7 synthesizes the week: a debugging method backed by nine live failure scenarios, a production observability frame, service mesh and gateway concepts for engineers who already run an API gateway, and a decision model across Lambda, ECS Fargate and EKS (standard, Fargate, Auto Mode, Karpenter).

---

## The layer this covers

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Observability & Telemetry                       │
│                                                                        │
│   RED (per service)                        USE (per resource)          │
│   ├── Rate: req/sec                        ├── Utilization: CPU/Mem %  │
│   ├── Errors: 5xx count                    ├── Saturation: run queue,  │
│   └── Duration: p95/p99 latency            │    throttling, PSI, queue │
│                                            └── Errors: drops, I/O errs │
│   Logs:  app stdout/stderr ─► containerd (CRI format) ─► node file     │
│          /var/log/pods/... ─► DaemonSet shipper ─► Loki / Elasticsearch│
│   Events: API objects in etcd, ~1 h TTL.  Metrics: metrics-server /    │
│          Prometheus.  Kernel messages: node dmesg.                     │
└────────────────────────────────────┬───────────────────────────────────┘
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Systematic Debugging Engine                     │
│   kubectl get pods (STATUS/READY) ► describe (Events, Last State, exit │
│   code) ► logs --previous ► kubectl debug (ephemeral / copy / node)    │
│   ► Gateway status code & route conditions                             │
└────────────────────────────────────┬───────────────────────────────────┘
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│     Traffic & Platform Architecture (gateway, mesh) and Orchestrator   │
│   Edge gateway ► (mesh: sidecar | ambient) ► app                       │
│   Lambda ◄──► ECS Fargate ◄──► EKS (Fargate | Auto Mode | EC2+Karpenter)│
└────────────────────────────────────────────────────────────────────────┘
```

---

## Core concepts

### 1. Observability: measuring distributed systems

#### A. USE vs. RED
Do not flood dashboards with random charts. Pick the frame that fits the thing you are looking at:
- **USE (resources: node, disk, NIC, a pod's CPU/memory):**
  - **Utilization:** fraction of time/capacity in use (node CPU 78%, memory working set vs limit).
  - **Saturation:** work that has to wait: CPU run queue and **CFS throttling** (a pod at its CPU limit is throttled long before the node is busy), memory pressure (PSI), disk queue depth, a full connection pool.
  - **Errors:** device errors, dropped packets, OOM kills, evictions.
- **RED (request-driven services such as `order-api`):**
  - **Rate:** requests per second. **Errors:** failed requests (5xx; also timeouts that never become a status). **Duration:** latency distribution (p50/p95/p99, from histograms, never averages).
- The Google "four golden signals" are RED plus saturation. Use RED for services, USE for the resources underneath, and alert on symptoms (RED, user-visible) rather than causes (CPU high).

#### B. The logging contract (and what the node actually stores)
Containers write logs to **stdout** (info) and **stderr** (errors), never to files inside the container.
- The runtime (containerd via CRI) captures both streams and the kubelet places them on the node at `/var/log/pods/<namespace>_<pod>_<uid>/<container>/<restart-count>.log` (symlinked from `/var/log/containers/`). The kubelet rotates these files; `kubectl logs` reads them through the kubelet.
- **The on-disk format is the CRI format, not JSON:**
  ```text
  2026-10-06T15:00:07.345586Z stderr F 2026/10/06 15:00:07 order-api listening on port 8080
  ```
  RFC3339Nano timestamp, stream (`stdout`/`stderr`), a tag (`F` = full line, `P` = a partial line when a long line was split), then the message. (The JSON-per-line format belongs to the old Docker `json-file` driver; Docker Desktop's `docker logs` may still show it, Kubernetes nodes on containerd do not.) If you want structured logs, emit JSON as the **message** and let the shipper parse the CRI wrapper and then the JSON.
- Shipping: a DaemonSet (Fluent Bit, Promtail/Alloy, Vector) mounts `/var/log/pods`, parses CRI, enriches with pod/namespace/label metadata and forwards to Loki or Elasticsearch/OpenSearch. Patterns: EFK/ELK (full-text, heavy) vs Loki (index labels only, cheap). A pod's logs vanish when the pod is deleted unless shipped: ship them.
- Log lines are not metrics. Do not alert by grepping logs when a counter can answer.

#### C. Where each kind of data lives (and the etcd contrast)
| Data | Stored | Lifetime | Use |
|:--|:--|:--|:--|
| Container logs | Files on the node, rotated | Until rotation / pod deletion | `kubectl logs`, shipper |
| **Events** | API objects, i.e. **etcd** | ~1 hour by default | "What just happened to this object": scheduling, pull, probe failures |
| metrics-server data | In-memory, latest sample | Seconds | `kubectl top`, HPA |
| Prometheus data | TSDB you operate | Your retention | Dashboards, alerts, SLOs |
| Kernel messages (OOM kill) | Node `dmesg`/journal | Ring buffer | Proof of an OOM kill; **not** in events |
Events are cheap, useful and short-lived; do not treat them as an audit trail or ship the cluster's history from them alone, and do not put high-rate telemetry into etcd.

#### D. metrics-server and Prometheus
- **metrics-server** scrapes each kubelet's resource metrics endpoint (`/metrics/resource`), keeps only the latest sample in memory and serves the `metrics.k8s.io` API (`kubectl top`, the HPA). Current release v0.9.0 (course manifest: `labs/shared/metrics-server.yaml`, with `--kubelet-insecure-tls` for Docker Desktop/kind only; on EKS the kubelet certificates are fine).
- **Prometheus** pulls `/metrics` endpoints on an interval and stores time series. **Counter** (only increases, e.g. `http_requests_total`; use `rate()`), **Gauge** (up and down, e.g. queue depth), **Histogram** (bucketed observations, for p99 via `histogram_quantile`; averages hide tails). Services, nodes (node-exporter), kubelet/cAdvisor and kube-state-metrics are scrape targets; `ServiceMonitor`/`PodMonitor` CRDs declare them with the Prometheus Operator.

---

### 2. Debugging mastery: from symptom to root cause

When something fails, do not guess or restart. Read signals in a fixed order and ask which layer produced each one:

```
                      [Alert / incident]
                              │
                     kubectl get pods  -o wide        (STATUS, READY, RESTARTS, NODE)
                              │
  ┌───────────────┬───────────┼──────────────┬──────────────────┐
  ▼               ▼           ▼              ▼                  ▼
Pending      ImagePull-   CreateContainer-  CrashLoopBackOff/  Running but
(no NODE)    BackOff      ConfigError       RunContainerError  broken (0/1,
  │            │             │              /OOMKilled          5xx, timeouts)
describe:    describe:    describe:         describe: Last     logs, EndpointSlices,
scheduler    pull error   missing key/      State + exit code; HTTPRoute status,
events       text         object            logs --previous    ephemeral debug
```

#### Failure modes with the signals that identify them (all reproduced in the lab)
| STATUS | What it tells you | Decisive signal | Typical fix |
|:---|:---|:---|:---|
| `ErrImagePull` → **`ImagePullBackOff`** | The container was never created (RESTARTS 0) | Event `Failed to pull image ... pull access denied, repository does not exist or may require authorization`. **Misleading:** Docker Hub returns this for a *missing tag* too; check the spelling before hunting credentials. Honest registries say `manifest unknown`. | Correct tag; `imagePullSecrets`; load the image (kind provisioner) |
| **`CrashLoopBackOff`** (Reason `Error`) | The app **ran** and exited non-zero | `kubectl logs --previous` shows the fatal line; `Exit Code: 1` | Fix config/code; fail-fast validation gives you the log |
| **`RunContainerError`** / `StartError`, exit **128** | The **runtime could not start** the process (bad `command`, missing binary, wrong arch). *Not* an app crash | `Last State ... Reason: StartError`, `exec: "...": no such file or directory`; **empty logs** | Fix `command`/`args`/image |
| **`OOMKilled`**, exit **137** | The kernel killed the process at the cgroup memory limit | `Last State: Reason OOMKilled`. **No event, no log line**; the kernel line is in the node's `dmesg` | Profile; `GOMEMLIMIT`; raise limit |
| **`CreateContainerConfigError`** | The kubelet cannot build the container's config; the container never started | Event `couldn't find key X in ConfigMap ns/name` (or `configmap "x" not found`); RESTARTS 0 | Fix the reference/data; kubelet retries on its own |
| **`Pending`** (NODE `<none>`) | Not scheduled | `FailedScheduling: 0/1 nodes are available: 1 Insufficient cpu ...` (or node affinity/selector, untolerated taint, unbound PVC). Scheduling uses **requests** | Right-size, fix selector/taints, bind PVC; autoscaler adds a node |
| **`Running`** `2/2`, calls fail | Network/DNS/policy | App log timeouts; `nslookup` from an ephemeral container: **timeout** (DNS unreachable: egress policy without port 53, CoreDNS, kindnet) vs **NXDOMAIN / `no such host`** (name wrong) | Allow 53 to CoreDNS; correct the name |
| **`Running`** `1/1`, Gateway **503** | Service has **no endpoints at all** (selector typo, 0 replicas) | EndpointSlice empty; `HTTPRoute ... BackendsAvailable=False EndpointsNotFound`; Envoy Gateway answers itself (`direct_response`, access log `upstream_cluster: null`) | Fix selector/labels |
| **`Running`** `0/1` | Readiness failing | `Readiness probe failed: ... 404`; EndpointSlice `ready: false`. **The Gateway may still answer 200** (Envoy panic routing: below 50% healthy hosts Envoy fails open and uses all of them) | Fix probe path/port. Keep liveness (`/health`) separate from readiness (`/ready`); keep ≥ 2 replicas |
| `Evicted` (status Failed) | **Node-pressure eviction** by the kubelet (disk/memory/PID pressure) | `kubectl describe pod` reason `Evicted`, node conditions | Free disk, set requests, capacity |

Details that trip people up:
- **CrashLoopBackOff is a waiting state, not an error.** RESTARTS goes up by **one** per restart; what doubles is the *delay* (10 s, 20 s, 40 s ... capped at 5 min, reset after 10 min of healthy running). `STATUS` flips between `Error`/`OOMKilled` (just died) and `CrashLoopBackOff` (waiting).
- **`logs --previous`** reads the last terminated instance; it can say `unable to retrieve container logs` mid-restart (retry) and is empty for StartError (no process ever ran).
- **`kubectl drain` does not produce `Evicted` pods.** It uses the **Eviction API** (honours PodDisruptionBudgets; the pod is deleted gracefully and recreated by its controller). `Evicted` is the kubelet's own node-pressure eviction, and those pods remain as `Failed` until cleaned up.
- Pending + `Insufficient cpu` is about *requests* against allocatable, not about what is in use.

#### Exit codes
`Exit Code` is `128 + signal` for signals and the process's own value otherwise: **0** normal; **1** application error; **126** found but not executable; **127** command not found; **128** the runtime could not start it; **137** SIGKILL (OOM kill, or killed after the termination grace period); **143** SIGTERM (graceful stop). Always read `Reason` with the code. Full table in the runbook.

#### Advanced debugging toolkit
Production images here are distroless (no shell), so there is nothing to `kubectl exec` into. Attach tools to the pod's namespaces instead.
- **Ephemeral containers** (`kubectl debug`):
  ```bash
  kubectl debug -it <pod> --image=nicolaka/netshoot --target=<container> --profile=general -- bash
  ```
  `--target` shares the target container's **process** namespace (so `ps` shows `/app/server` as PID 1 and `/proc/1/root` reaches its filesystem); the **network** namespace is the pod's anyway: `nslookup`, `curl`, `ss` show what the app sees and are subject to the same NetworkPolicy. **Default profile:** kubectl 1.32-1.35 default to the deprecated `legacy` profile (with a warning), kubectl 1.36+ defaults to `general`; always pass `--profile`. `general` adds `SYS_PTRACE`, which Pod Security `baseline`/`restricted` reject: use `--profile=baseline` or `restricted` in such namespaces. **Constraints:** (1) the pod-level `securityContext` applies, so in a non-root pod (`runAsUser: 65532`) `tcpdump` fails (`CAP_NET_RAW may be required`) and `--profile=netadmin` alone does **not** fix it (non-root processes start with an empty capability set); run the container as root with a `--custom` JSON; (2) under the `restricted` Pod Security Standard root/added capabilities are rejected, use `--profile=restricted`; (3) ephemeral containers **cannot be removed** from a pod and count against PSA; recreate the pod. Profiles: `general`, `baseline`, `restricted`, `netadmin`, `sysadmin` (legacy is deprecated; always pass one).
- **`kubectl debug <pod> --copy-to=<name> --container=<c> --image=<img> -- sleep 3600`:** clones a crashing pod with a shell-friendly command and keeps the original untouched (the copy has no labels, so the Service and ReplicaSet ignore it).
- **`kubectl debug node/<node> --image=... --profile=sysadmin`:** a privileged pod with the node's filesystem under `/host`. Reads kernel OOM lines (`chroot /host dmesg`), CRI logs under `/host/var/log/pods`, kubelet logs. It is created in the current namespace and must be deleted afterwards.
- **`kubectl port-forward svc/<svc> <local>:<remote>`:** tunnel past the gateway to test the app alone. Bypasses NetworkPolicy ingress rules (the traffic comes from the API server/kubelet path), so a pass here does not prove the policy is right.
- **Gateway-level debugging:** `curl -i` through the edge, then `kubectl get httproute ... -o jsonpath` conditions (`Accepted`, `ResolvedRefs`, `BackendsAvailable`), EndpointSlices, and the Envoy access log (`response_code`, `response_code_details`, `response_flags`). **503 with empty body** = Envoy Gateway's own `direct_response` when the Service has no endpoints at all, while an existing cluster whose hosts are all unhealthy gives `503 UH` ("no healthy upstream"); **200 although pods are `0/1`** = panic routing; **504** = upstream timeout; **404 with empty body** = no route matched, **404 with `404 page not found`** = it reached the app.

---

### 3. Service mesh, gateway and traffic concepts (for the API-gateway engineer)

You already know an edge gateway: north-south traffic, authentication, routing, limits. A **service mesh** applies the same ideas *between* services (east-west) without changing application code.

#### A. What a mesh does
- **Identity and mTLS:** every workload gets a short-lived certificate whose identity is derived from its ServiceAccount (SPIFFE ID like `spiffe://cluster.local/ns/orderflow/sa/order-api`). Peers authenticate each other and encrypt traffic; **authorization policy** then says *which identity may call which service/method*. This is "zero trust between pods", and the cryptographic workload identity is the compliance value (PCI-DSS), not just the encryption. NetworkPolicy (L3/L4, by labels/IPs) and mesh authorization (L7, by identity) are complementary.
- **Traffic management:** retries, timeouts, circuit breaking and outlier detection, weighted routing, mirroring, fault injection, uniformly and observably.
- **Telemetry:** golden-signal metrics, access logs and traces for every hop for free.

#### B. Architectures
| Model | How | Trade-offs |
|:--|:--|:--|
| **Sidecar** (classic Istio, Linkerd) | A proxy container (Envoy / linkerd2-proxy) per pod intercepts traffic; native sidecars (init container with `restartPolicy: Always`; beta and on by default since 1.29, GA in 1.33) fix start/stop ordering | Per-pod CPU/memory tax; injection and restart-to-upgrade; strongest per-workload isolation; mature |
| **Istio ambient** (sidecarless) | A per-node **ztunnel** gives mTLS identity and L4 policy; an optional per-namespace/service **waypoint** proxy (an Istio ambient concept) adds L7 only where needed | Far less overhead, no per-pod injection; L7 features cost a waypoint hop; younger |
| **Cilium** (CNI-based) | eBPF dataplane for NetworkPolicy; transparent **WireGuard/IPsec** encryption; L7 policy/routing through a **per-node Envoy** | Not a full identity mesh: its mutual authentication is still **Beta** (disabled by default in 1.19, with the direction pointing at a ztunnel-based integration). Good for CNI policy and encryption |
Linkerd uses its own lightweight Rust proxy per pod; Istio uses Envoy (sidecar or ambient).

#### C. Envoy and xDS
Envoy is the proxy under Envoy Gateway and Istio. It is configured **dynamically** by a control plane over **xDS** gRPC APIs: **LDS** (listeners), **RDS** (routes), **CDS** (clusters = upstream groups), **EDS** (endpoints = the pod IPs), **SDS** (secrets/certificates). The control plane (Envoy Gateway, istiod) watches Kubernetes objects (Gateway, HTTPRoute, Services, EndpointSlices) and pushes translated config; no reload, no restart. When you broke the Service selector in the lab, Envoy Gateway found no endpoints at all and configured a **direct_response 503** for that route (access log `upstream_cluster: null`); an existing cluster whose hosts are all unhealthy would instead give `503 UH` ("no healthy upstream"), and below the panic threshold (default 50% healthy) Envoy ignores health and balances over all hosts. When a config is not applied, look at the control plane's status/conditions first, then Envoy's `config_dump`.

#### D. Resilience: timeouts, retries, circuit breaking, retry budgets
- **Timeouts at every hop**, shorter downstream than upstream (e.g. app→dependency 3 s, gateway 5 s, user-facing 10 s). Without them, slow dependencies pile up threads and connections (the cascade).
- **Retries** only for **idempotent** operations (GET/PUT/DELETE, or POST with an idempotency key), with exponential backoff and jitter, a low attempt cap and `retryOn` conditions (connect failure, 503, reset; not 500s from application logic).
- **Retry storms:** three layers each retrying 3 times is 27 attempts against a dependency that is already failing. Counter with a **retry budget** (cap retries to a share of active requests per upstream; Envoy's `retry_budget` defaults to `budget_percent` 20% with `min_retry_concurrency` 3; Linkerd has retry budgets too), retry in *one* layer, and make downstream layers retry less.
- **Circuit breaking:** limits on connections / pending requests / concurrent requests per upstream (Envoy circuit-breaker thresholds) plus **outlier detection** (eject hosts that return consecutive 5xx for a while). They shed load and fail fast instead of queueing.
- Mesh/gateway policy gives uniform behaviour without code; the app knows idempotency and partial results. Use the proxy for connection-level resilience and the app for business-aware retry decisions.

#### E. Where to rate-limit: edge gateway vs mesh vs app
| Layer | Good for | Identity available | Notes |
|:--|:--|:--|:--|
| **Edge gateway** (Envoy Gateway `BackendTrafficPolicy`, ALB + WAF) | Abuse, per-client/API-key/IP/route quotas on **external** traffic, before it consumes capacity | Client IP, API key/JWT claims, headers | Default place. **Global** limits use a shared counter service (exact across replicas); **local** limits are per-proxy token buckets (approximate, cheap) |
| **Mesh** (sidecar or waypoint policy) | Protect an internal dependency from a noisy caller; per-service quotas | mTLS workload identity | Internal fairness |
| **Application** | Business rules (per-tenant plan limits, expensive-operation budgets), and **load shedding** (429/503 when saturated) | Everything in the request, the user, the plan | Last line of defence; never your only one |
Limit early (cheapest rejection), return `429` with `Retry-After`, and distinguish **rate limiting** (requests/time) from **concurrency limiting** (in-flight) and **load shedding** (self-protection).

#### F. Canary and traffic splitting with the Gateway API
HTTPRoute `backendRefs[].weight` splits traffic between Services (weights are relative, not percentages): `order-api` 90 / `order-api-canary` 10, plus a header match (`x-canary: true`) to force the canary for testers (Day 4, `httproute-canary.yaml`). Promote by editing weights (5 → 25 → 50 → 100) while watching RED metrics per backend; roll back by setting the canary weight to 0. Argo Rollouts and Flagger automate this by rewriting route weights and querying Prometheus. Edge-level weights cover north-south canaries; a mesh extends weighted routing to service-to-service hops. **Blue/green** = two full stacks and a single switch (selector or route flip), instant rollback at double capacity.

#### G. Do you need a mesh?
Adopt one when you need **uniform mTLS with identity-based authorization across many teams**, consistent resilience policy you cannot enforce in app libraries, or per-hop observability. Do not adopt it for five services and one team: a mesh adds a control plane, upgrades, debugging layers (is it the app, the proxy, the policy?) and latency. Alternatives: NetworkPolicy + app-level TLS, a good gateway, cloud-native options (ECS Service Connect, VPC Lattice). Reduced-scope option: Istio ambient (ztunnel mTLS and L4 policy without sidecars), or Cilium when the driver is CNI policy and transparent encryption rather than auditable identity.

---

### 4. Container orchestration decision framework

Cargo-culting Kubernetes when a simpler abstraction delivers higher velocity at lower cost is among the costliest engineering mistakes.

#### The control vs. operational-burden spectrum
```
Low burden, less control                                   High burden, full control
   ◄───────────────────────────────────────────────────────────────────────►
 Lambda    ECS Fargate    EKS Auto Mode    EKS + Karpenter     EKS self-managed
(functions) (no nodes,    (K8s API; AWS    (K8s API; you own    node groups (full
            AWS API)       runs nodes,      NodePools, AMIs      ownership)
                           core add-ons)    policy, add-ons)
                         EKS on Fargate: pods without nodes, with restrictions
                         (no DaemonSets, no privileged, no GPUs; slower start)
```
- **EKS Auto Mode** (GA Dec 2024): AWS manages the data plane: nodes provisioned and replaced automatically (Karpenter-style, Bottlerocket-based), plus managed compute autoscaling, load balancing, block storage, pod networking and DNS. You keep the Kubernetes API, but fewer knobs and a per-instance management fee. Good default for teams that want Kubernetes without owning nodes and add-ons.
- **Karpenter** (open source, runs in your cluster or inside Auto Mode): provisions right-sized nodes directly from pending-pod requirements (instance diversity, Spot, consolidation) instead of fixed node groups. This is what turns a `Pending: Insufficient cpu` into a new node within a minute. It needs correct **requests** to be efficient.
- **EKS on Fargate** is a restricted compromise (no DaemonSets, so no node-level log/metrics agents, no privileged pods). Auto Mode usually replaces its reason to exist.

#### When ECS / Fargate wins
1. **Small team without a platform team:** no control plane to upgrade, no add-on matrix, no etcd or API-version deprecations.
2. **Pure AWS:** native IAM task roles, ALB/NLB targets, CloudWatch, Cloud Map / Service Connect (which also offers TLS between services).
3. **Moderate service count** (fewer than ~15-20): CRDs and operators add little over task definitions and target groups.
4. **Time-to-market:** a production-grade ECS stack in days; production-grade Kubernetes (policies, GitOps, observability, upgrades) is a standing investment.

#### When Kubernetes (EKS) wins
1. **Multi-cloud / hybrid:** Kubernetes is the runtime with the broadest portable ecosystem (manifests, Helm, Gateway API, GitOps). It is not the *only* portable option (Nomad, VMs), and portability costs are real.
2. **Platform engineering and extension:** CRDs/operators (databases, preview environments, policy engines), internal developer platforms.
3. **Advanced scheduling:** taints/tolerations, topology spread, GPUs/bin-packing, Spot at scale with Karpenter.
4. **Network and identity depth:** default-deny NetworkPolicy, Gateway API, a service mesh for mTLS, authorization and uniform resilience.
5. **Ecosystem:** Helm, Argo CD/Flux, Prometheus, cert-manager, Kyverno/Gatekeeper, Karpenter.

#### Decision tree
```
Do you need containers?
├── Bursty event-driven compute (< 15 min)           ──► Lambda
├── Legacy monolith with tight OS/kernel coupling    ──► EC2 VMs
└── Long-running services, env parity                ──► Containers
      │
      ▼
Team, services, constraints?
├── < ~15 services, pure AWS, small team             ──► ECS on Fargate
├── Need Kubernetes API/ecosystem, small platform capacity
│                                                    ──► EKS Auto Mode
├── 20+ services, dedicated platform team, custom scheduling/Spot
│                                                    ──► EKS + Karpenter (or Auto Mode)
└── Multi-cloud / on-prem requirement                ──► Kubernetes everywhere (EKS + others),
                                                         Gateway API + Helm + GitOps as the portable layer
Mesh? ──► only if you need identity-based mTLS/authz or uniform resilience across teams (ambient first)
```
Common mistake: "Kubernetes is the industry standard" is not "Kubernetes is right for us."

---

### 5. Production readiness: the 12-factor app on Kubernetes

| 12-Factor principle | Kubernetes implementation |
|:---|:---|
| **I. One codebase, many deploys** | One repo per service; images tagged by commit SHA (or digest) |
| **II. Explicit dependencies** | Multi-stage Dockerfiles; pinned base images; SBOM/scan in CI |
| **III. Config in the environment** | `ConfigMap`/`Secret` as env or mounted files (a missing key is `CreateContainerConfigError`) |
| **IV. Backing services as resources** | Attached by Service name (`orderflow-postgres.orderflow.svc.cluster.local`); swap without code change |
| **V. Separate build, release, run** | CI builds an immutable image → Helm/GitOps renders a release → kubelet runs it |
| **VI. Stateless processes** | Ephemeral pods; state in managed databases or StatefulSets with PVCs |
| **VII. Port binding** | `containerPort` + Service/HTTPRoute |
| **VIII. Concurrency via process model** | Scale out with replicas and the `HorizontalPodAutoscaler` |
| **IX. Disposability** | Fast start; readiness vs liveness; SIGTERM → fail readiness → drain → exit (Day 6 measured it) |
| **X. Dev/prod parity** | Same image in Docker Desktop and EKS; same chart, different values |
| **XI. Logs as event streams** | stdout/stderr only; node agent ships them |
| **XII. Admin processes** | Migrations as Helm hook `Job`s; one-off tasks as Jobs |

#### Conventions, delivery and deployment strategies
- **Namespaces:** per-team, per-environment, or hybrid (`team-env`); RBAC, ResourceQuota and NetworkPolicy attach per namespace. **Labels:** `app.kubernetes.io/{name,instance,version,component,part-of,managed-by}` plus `team`; labels select (Services, policies), annotations describe.
- **GitOps (Argo CD / Flux):** Git is the source of truth; a controller continuously reconciles the cluster to it and reverts drift. CI pattern: build → test → scan → push image → update manifest/values → controller syncs.
- **Rolling update** (default) vs **blue/green** (two stacks, one switch) vs **canary** (weighted HTTPRoute split or Argo Rollouts, see 3.F). Choose by rollback speed, cost and how you detect a bad release (RED per version).

---

## Exercises

### Exercise 1 — The silent OOMKill
A pod restarts and `kubectl logs <pod>` shows nothing unusual. Prove the kernel OOM-killed the container and show the kernel's side.

**Hint:** The process did not exit voluntarily; the kubelet records how the container ended, and the kernel logs the kill on the node.

**Solution sketch:**
1. `kubectl describe pod <pod>` → `Last State: Terminated`, `Reason: OOMKilled`, `Exit Code: 137` (128 + SIGKILL). The previous log simply stops: SIGKILL cannot be caught.
2. There is **no OOMKilled event**. The kernel line is on the node: `kubectl debug node/<node> -n <ns> --image=busybox:1.37 --profile=sysadmin -- sh -c 'chroot /host dmesg | grep -i "killed process"'` → `Memory cgroup out of memory: Killed process ... (server) ... anon-rss:65036kB`; read the output with `kubectl logs` of the `node-debugger-*` pod, then delete it.
3. Distinguish from a node-pressure eviction (status `Evicted`, a kubelet decision) and from exit 137 caused by a missed grace period (`terminationGracePeriodSeconds`), where `Reason` is not `OOMKilled`.

---

### Exercise 2 — Broken metrics pipeline
`kubectl top pods -n orderflow` prints `error: Metrics API not available`. Diagnose.

**Hint:** Is the aggregated API registered, and is the pod behind it healthy?

**Solution sketch:**
1. `kubectl get apiservice v1beta1.metrics.k8s.io` → `AVAILABLE` must be `True` (`MissingEndpoints`/`FailedDiscoveryCheck` otherwise).
2. `kubectl get pods -n kube-system -l k8s-app=metrics-server`; none → not installed: `kubectl apply -f labs/shared/metrics-server.yaml` (v0.9.0, includes `--kubelet-insecure-tls`).
3. Running but not Ready / error logs (`kubectl logs -n kube-system -l k8s-app=metrics-server`): `x509: cannot validate certificate for <ip>` on Docker Desktop/kind means the kubelet serving cert is self-signed → `--kubelet-insecure-tls` (local clusters only). Allow a minute for the first scrape (`metrics not available yet`).

---

### Exercise 3 — 5-service startup
A 4-person team runs 5 microservices on AWS at 50 req/s. The lead proposes EKS with Istio and Karpenter. Approve?

**Hint:** Weigh operational load and failure modes against what the workload needs.

**Solution sketch:**
1. **Reject as proposed; recommend ECS on Fargate** (or, if they insist on the Kubernetes ecosystem, EKS Auto Mode without a mesh).
2. Istio + Karpenter + EKS is a control plane, a data plane add-on and an autoscaler to learn, upgrade and debug (a half to one platform engineer's time) for a workload that needs none of: multi-cloud, custom scheduling, identity-based L7 policy.
3. ECS gives IAM task roles, ALB, Cloud Map/Service Connect (TLS between services if needed) and no node or cluster upgrades. Revisit at ~15-20 services or a platform requirement.

---

### Exercise 4 — 35-service fintech
35 services, 25 backend engineers, PCI-DSS requiring mTLS between all services, hybrid cloud in 18 months. Recommend a strategy, including the mesh choice and node management.

**Hint:** Separate "what compliance needs" (workload identity, encryption, auditable policy) from "which product provides it".

**Solution sketch:**
1. **EKS** with a 2-3 person platform team: manifests, Helm, Gateway API and GitOps are the portable layer for the hybrid plan (ECS is AWS-only).
2. mTLS with SPIFFE-style workload identity plus L7 authorization policy: Istio (ambient first to limit overhead, sidecar where per-pod isolation is required) or Linkerd for auditable mTLS identity; Cilium for CNI policy and WireGuard/IPsec encryption (its own mutual authentication is still Beta); plus default-deny NetworkPolicy. Prove the control with auditable policy and certificate rotation, not just "encryption on".
3. Nodes: Karpenter or EKS Auto Mode to avoid managing node groups; Pod Identity for AWS access; edge rate limiting at the gateway, per-service quotas in the mesh.

---

### Exercise 5 — Diagnose a Gateway 503
`curl http://localhost/chaos-selector` returns `503`, empty body, while `kubectl get pods` shows the backend `1/1 Running`. Walk the path from the client to the cause.

**Hint:** Who produced the 503, Envoy or the app? What does the route's status say about its backends?

**Solution sketch:**
1. `curl -i`: `content-length: 0`, no app headers → Envoy itself answered (the Envoy access log shows `direct_response`, `upstream_cluster: null`).
2. `kubectl get httproute <name> -o jsonpath` conditions: `Accepted=True`, `BackendsAvailable=False EndpointsNotFound`.
3. `kubectl get endpointslices -l kubernetes.io/service-name=<svc>`: empty → compare the Service `selector` with `kubectl get pods --show-labels` → typo. Patch the selector; the same URL returns 200 within seconds.
4. If instead the pod were `0/1` (readiness), the EndpointSlice would list it with `ready: false`; do not trust the Gateway to prove readiness: observed here, a Service whose only pod was not ready still got 200s through the Gateway (Envoy panic routing: below 50% healthy hosts Envoy fails open), and adding one ready replica moved all traffic to it.

---

### Exercise 6 — Timeouts versus NXDOMAIN
A pod's log shows `context deadline exceeded` calling `http://orderflow-payment:8081`. Prove whether it is DNS, the network, or the callee, with no shell in the image.

**Hint:** An ephemeral container shares the pod's network namespace and its NetworkPolicy.

**Solution sketch:**
1. `kubectl debug <pod> --target=<c> --image=nicolaka/netshoot --profile=general -c dbg -- sh -c 'nslookup -timeout=2 <svc>; curl -sS -m 3 http://<svc>:8081/health'`, then `kubectl logs <pod> -c dbg`.
2. `communications error to 10.96.0.10#53: timed out` / `curl (28) Resolving timed out` → DNS unreachable (egress policy without UDP/TCP 53 to `kube-dns`; check `kubectl get netpol`; CoreDNS pods; kindnet wedge).
3. `NXDOMAIN` / `no such host` → DNS fine, name wrong. Resolves but curl times out → port-level policy or callee overloaded; `Connection refused` → nothing listening or no endpoints.
4. Fix the policy: allow `kube-system` pods `k8s-app=kube-dns` on UDP and TCP 53 in the same `to` element (AND of namespaceSelector and podSelector).

---

### Exercise 7 — Rate limiting and retries for an API gateway engineer
Design where to rate-limit `POST /orders` and how `order-api` should call `payment-service`, which is flaky.

**Hint:** Match the limit to the identity each layer can see; mind retry amplification.

**Solution sketch:**
1. Edge gateway: per-API-key and per-IP limits (global limit if exactness matters, local otherwise) returning `429` + `Retry-After`; WAF in front for abuse. Mesh/waypoint: cap `order-api` → `payment-service` concurrency by caller identity. App: per-tenant plan limits and load shedding when saturated.
2. Calls to payment: timeout shorter than the gateway's, retries **only** with an idempotency key (a duplicate charge is worse than a failure), exponential backoff + jitter, 1-2 retries in **one** layer, a retry budget, circuit breaking / outlier detection so a sick replica is ejected.
3. Metrics to prove it: RED per hop (rate of retries, 429s, 5xx), saturation of the pool.

---

## Anti-patterns / Common mistakes

1. **Logging to files inside containers:** lost on restart, invisible to node collectors, fills ephemeral storage.
2. **Restarting pods as the first debugging step:** destroys `Last State`, `--previous` logs and Events (which expire in about an hour). Capture first.
3. **Ignoring Events and Last State:** the cause of most `Pending`, config and pull failures is in `kubectl describe`.
4. **Trusting the error text literally:** `pull access denied` often means a typo'd tag; `context deadline exceeded` can be DNS; a Running pod can have no endpoints.
5. **Using the same endpoint for liveness and readiness:** a dependency blip then restarts healthy pods. Liveness = process alive, readiness = can serve.
6. **Aggressive liveness probes on slow apps:** GC pauses or cold starts get healthy apps killed.
7. **Stacked retries without a budget or idempotency:** three layers retrying amplify a partial outage into a full one and duplicate side effects.
8. **Adopting a mesh or Kubernetes by default:** both are tools with a standing operational cost; adopt for a stated requirement.
9. **Debug sidecars/tools in production images:** keep images distroless and attach ephemeral containers instead; remember they cannot be removed and need the right profile.

---

## Recall drill

1. Which exit code and Reason mean the **runtime** could not start the process, and why are the logs empty? <details><summary>Answer</summary>`StartError` / exit 128 (STATUS `RunContainerError`): no process ever ran, so there is nothing to log.</details>
2. How do you prove an OOM kill, and what will you *not* find? <details><summary>Answer</summary>`Last State: OOMKilled`, exit 137; the kernel line via `kubectl debug node/` + `dmesg`. No Event and no log line (SIGKILL).</details>
3. `ImagePullBackOff` with `pull access denied ... may require authorization`: first check? <details><summary>Answer</summary>The tag/repository spelling (and that the image is on the node for local builds). Docker Hub reports a missing tag this way.</details>
4. How do you tell DNS-unreachable from a wrong name from inside a distroless pod? <details><summary>Answer</summary>Ephemeral netshoot container: `nslookup` timeout = DNS unreachable (egress policy/CoreDNS); `NXDOMAIN` = wrong name.</details>
5. Gateway returns an empty-body 503 while the pod is Running 1/1. Likely cause and proof? <details><summary>Answer</summary>Service has no endpoints (selector mismatch): empty EndpointSlice, route `BackendsAvailable=False EndpointsNotFound`, Envoy `direct_response`.</details>
6. Why does `tcpdump` fail in an ephemeral container of a non-root pod, and what does `--profile=netadmin` change? <details><summary>Answer</summary>The pod's `runAsUser` applies, so no effective capabilities even if `NET_RAW` is added; run as root via `--custom` (not allowed under `restricted`).</details>
7. Where do you rate-limit, and where do retries live? <details><summary>Answer</summary>Edge gateway for external identity; mesh for internal callers; app for business rules/load shedding. Retries only for idempotent calls, one layer, with a budget and backoff; timeouts at every hop.</details>
8. Sidecar mesh versus ambient? <details><summary>Answer</summary>Per-pod Envoy proxy vs a per-node L4 agent (mTLS, L4 policy) with optional per-namespace L7 waypoint: less overhead, no injection, L7 costs a hop.</details>

---

## Lab
See [`labs/day07/`](../labs/day07/).
- **The goal:** install the Day 6 chart as the baseline, break it nine ways (ImagePullBackOff, CrashLoopBackOff, StartError, OOMKilled, CreateContainerConfigError, Pending, DNS failure, no-endpoints Gateway 503, failing readiness) and diagnose each from signals; use ephemeral containers, `--copy-to` and node debugging; then answer the architecture, mesh and rate-limiting decision questions.
- **Success signal:** every scenario's real STATUS/Reason/exit code/events read correctly with a written root cause and fix; `kubectl top` works; you can state where a mesh and rate limiting belong.

---

## Key commands reference

| Command | Purpose |
|:---|:---|
| `kubectl top nodes` / `kubectl top pods -n <ns> --containers` | Current CPU/memory (metrics-server) |
| `kubectl describe pod <pod> -n <ns>` | Events, `Last State`, exit code, probes, env |
| `kubectl logs <pod> -n <ns> [-c <c>] --previous` | Logs of the last terminated container instance |
| `kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp` | Chronological namespace events (about 1 h of history) |
| `kubectl debug -it <pod> --image=nicolaka/netshoot --target=<c> --profile=general` | Ephemeral container sharing the target's namespaces |
| `kubectl debug <pod> --copy-to=<name> --container=<c> --image=<img> --profile=general -- sleep 3600` | Debug a crashing pod via a copy |
| `kubectl debug node/<node> --image=busybox:1.37 --profile=sysadmin` | Node filesystem under `/host` (dmesg, CRI logs); delete the pod after |
| `kubectl get endpointslices -l kubernetes.io/service-name=<svc>` | Who is behind a Service, and `ready` status |
| `kubectl get httproute <r> -o jsonpath='{.status.parents[0].conditions}'` | Gateway API route status |
| `kubectl port-forward svc/<svc> <local>:<remote> -n <ns>` | Tunnel to a Service, bypassing the gateway |

---

## Teardown
```bash
helm uninstall orderflow -n orderflow 2>/dev/null || true
kubectl delete namespace orderflow --ignore-not-found
```
This removes every scenario object (they all live in `orderflow`). The Gateway `edge` (platform) and metrics-server stay installed on purpose; the next day's `labs/shared/reset.sh` recreates an empty `orderflow`.

**Finished the course?** Remove the shared platform pieces too (this frees `localhost:80`, which the edge Gateway publishes):
```bash
kubectl delete -f labs/day04/manifests/gateway.yaml --ignore-not-found
helm uninstall eg -n envoy-gateway-system || true
kubectl delete namespace envoy-gateway-system --ignore-not-found
kubectl get crd -o name | grep -E 'gateway.networking.(x-)?k8s.io|gateway.envoyproxy.io' | xargs kubectl delete
kubectl delete -f labs/shared/metrics-server.yaml --ignore-not-found
docker rmi orderflow/order-api:v1 orderflow/payment-service:v1 orderflow/notification-service:v1 orderflow/order-api:v2 orderflow/payment-service:v2 orderflow/notification-service:v2 || true
docker exec desktop-control-plane crictl rmi docker.io/orderflow/order-api:v1 docker.io/orderflow/order-api:v2 docker.io/orderflow/payment-service:v1 docker.io/orderflow/payment-service:v2 docker.io/orderflow/notification-service:v1 docker.io/orderflow/notification-service:v2 2>/dev/null || true   # only for the kind provisioner: removes the images loaded into the node
```
The `docker rmi` removes the images from your Docker engine; on the kind provisioner the copies loaded into the node's containerd go away when you delete the cluster (Docker Desktop → Kubernetes → reset/delete).

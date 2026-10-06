# Day 6 — Helm 4, Kubernetes Design Patterns & Graceful Shutdown

## Why this matters

Raw YAML works for a proof of concept. Once you have several environments (dev, staging, production), several regions or tens of services, copy-pasted manifests drift and `sed` over YAML becomes the deployment tool. Helm is the de facto package manager and templating engine for Kubernetes: one chart, many configurations, a recorded release history you can roll back.

Day 6 is also where you move from "resources that exist" to "resources that behave under change": **init containers** and **native sidecars** for pod composition, **probes** that mean different things, **HPA** and **PDB** for load and disruption, and the part most courses skip, **graceful shutdown**: why a correct rolling update still drops requests unless the pod keeps serving for a few seconds after it is told to stop. That last item is the one that matters most for an API gateway or any service behind a load balancer, and you will measure it on your own machine.

The chart you build here (`labs/day06/orderflow-chart/`) is the artifact Day 7 debugs and the EKS appendix deploys with a different values file.

---

## The layer this covers

```
┌──────────────────────────────────────────────────────────────────────────┐
│ Packaging tier   helm install orderflow ./orderflow-chart -f values-*.yaml│
│   Chart.yaml · values.yaml (+ overlays) · templates/ (Go templates)       │
│   release = rendered manifests + values, stored as Secrets (revisions)    │
└──────────┬───────────────────────────────────────────────────────────────┘
           ▼ rendered, applied (Helm 4: server-side apply)
┌──────────────────────────────────────────────────────────────────────────┐
│ Edge    Gateway edge (Day 4)  ◄── HTTPRoute orderflow  (gateway.enabled)  │
│ Pod: order-api (2/2 READY)                                                │
│   init:    wait-for-postgres            runs to completion, then exits    │
│   sidecar: readiness-watcher            native sidecar, runs the pod's life│
│   main:    order-api  startup + readiness(/ready) + liveness(/health)     │
│            lifecycle.preStop.sleep → terminationGracePeriodSeconds        │
│ Pods: payment-service, notification-service (internal, no route)          │
│ StatefulSet: postgres (+ headless Service)   Secret: postgres-auth        │
│ Hook Job: db-migration  (post-install, pre-upgrade)  → CREATE TABLE …     │
│ HPA (replicas owned by it)   PDB (voluntary disruptions)                  │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Core concepts

### 1. Helm: a package manager with a release history

A **chart** is a directory of templates plus default `values.yaml`. A **release** is one installation of a chart under a name in a namespace. Helm renders the templates client-side (Go templates plus the Sprig function library), applies the result, and stores the rendered manifests and the values as a **release Secret** per revision: `sh.helm.release.v1.<release>.v<revision>` (so revision 3 of `orderflow` is `sh.helm.release.v1.orderflow.v3`). There is no server-side Helm component; the Secrets *are* the history, and by default only the latest 10 revisions are kept (`--history-max`).

#### Chart structure (this course's chart)
```text
orderflow-chart/
├── Chart.yaml               # name, version (chart semver), appVersion, kubeVersion, dependencies:
├── values.yaml              # defaults: the documented interface of the chart
├── values-dev.yaml          # overlay: one replica, small limits
├── values-production.yaml   # overlay: replicas, HPA, PDB
└── templates/
    ├── _helpers.tpl         # named templates: labels, selector labels, securityContext, probes, shutdown, validation
    ├── deployment.yaml      # 3 Deployments (order-api has the init container + native sidecar)
    ├── service.yaml         # 3 ClusterIP Services, generated with `range`
    ├── configmap.yaml       # order-api config (orderflow-order-api-config; never a name Day 3 owns)
    ├── postgres.yaml        # Secret + headless Service + StatefulSet (restricted-compliant)
    ├── migration-job.yaml   # Helm hook Job: post-install,pre-upgrade
    ├── httproute.yaml       # edge via the Day 4 Gateway (gateway.enabled)
    ├── ingress.yaml         # optional classic Ingress (ingress.enabled)
    ├── hpa.yaml  pdb.yaml
    └── NOTES.txt
```
The namespace is **never** a value: every template uses `.Release.Namespace`, so `helm install -n orderflow` decides it. A `values.namespace` that overrides it makes `-n` lie.

#### Template language: the parts you will actually use
- **Values and defaults:** `{{ .Values.orderApi.image.tag }}`, `{{ .Values.x | default 2 }}`, `{{ required "msg" .Values.x }}` (fail the render with a message), `{{ fail "msg" }}`.
- **Conditionals:** `{{- if .Values.gateway.enabled }} … {{- end }}`. The `-` trims whitespace on that side; YAML is indentation-sensitive, so stray blank lines or wrong indents are the usual cause of "mapping values are not allowed here".
- **`with` rebinds `.`; `range` loops and rebinds `.`:**
  ```yaml
  {{- range .Values.gateway.paths }}
  - matches: [{path: {type: PathPrefix, value: {{ .path }}}}]
    backendRefs: [{name: {{ include "orderflow.backendName" (dict "root" $ "service" .service) }}}]
  {{- end }}
  ```
  Inside `range`/`with`, `.` is the current element, so the chart root is `$`. Forgetting that (`.Release.Name` inside a `range`) is the classic nil-pointer error. `range` also loops maps (`range $k, $v := .Values.annotations`).
- **Named templates:** `define "orderflow.labels"` in `_helpers.tpl`, used with `include` (not `template`, because `include` returns a string you can pipe: `{{ include "x" . | nindent 4 }}`). Pass several arguments by building a dict: `include "orderflow.labels" (dict "root" . "component" "order-api")`.
- **Indentation:** `{{ toYaml .Values.resources | nindent 12 }}` emits a newline then indents every line.
- **Checksum annotation:** `checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}`. Pods referencing a ConfigMap via `envFrom` do **not** restart when it changes; a changed pod-template annotation does, which triggers a rollout.
- **`lookup`** reads live cluster objects (and returns empty under `helm template`), which makes template output cluster-dependent: use it rarely.

#### Release lifecycle commands
| Command | What it does |
|:---|:---|
| `helm lint <chart>` | Static checks of structure and rendering |
| `helm template <rel> <chart> -f v.yaml` | Render locally, no cluster. Pipe to `kubectl apply --dry-run=server -f -` to validate against the real API server (schema, admission, Pod Security) |
| `helm install / upgrade --install` | Render, apply, record a revision |
| `helm get values/manifest/hooks <rel> [--revision N]` | What was actually deployed |
| `helm history <rel>` | Revision list with status |
| `helm rollback <rel> <N>` | Re-apply revision N's manifests **as a new revision** |
| `helm uninstall <rel>` | Delete the release's resources (and, with `--keep-history`, keep the Secrets) |

**Rollback creates a new revision.** After upgrades 1 → 2, `helm rollback orderflow 1` produces revision 3, described `Rollback to 1`; history never rewinds. Rollback re-applies *Kubernetes objects from the stored manifest*. It does not restore data: a StatefulSet's PVC contents, a dropped database table, or CRDs (Helm never upgrades or deletes CRDs placed in `crds/`) stay as they are. A rollback is not a database undo; this is why schema migrations must be backward compatible for one release.

Choosing which revision to roll back **to** matters: after a bad upgrade the right target is the last *good* revision, not "current minus one". Count revisions with `helm history` before you type the number.

### 2. Helm 4: what changed from Helm 3

Helm 4 (current line: 4.x) keeps charts and the release model but changes the engine and several flags. Install with `brew install helm`.

| Area | Helm 3 | Helm 4 |
|:---|:---|:---|
| Applying | client-side 3-way merge | **server-side apply (SSA) by default** for new installs (`--server-side=auto`: upgrades keep the method the release already used; `--force-conflicts` to take fields from other field managers) |
| Wait | `--wait` polled readiness of some kinds | `--wait` (= `watcher`) uses **kstatus**, understands CRDs that follow the status conventions; default without `--wait` is `hookOnly` (waits for hooks only); `--wait=legacy` keeps the old behaviour; `--wait-for-jobs` |
| Auto-rollback | `--atomic` | **`--rollback-on-failure`** (implies `--wait`) |
| Replace on conflict | `--force` | **`--force-replace`** |
| Extensibility | executable plugins; post-renderer was an executable path | plugins can be **WebAssembly**; post-renderers are plugins (`--post-renderer <plugin>`) |
| Charts | `apiVersion: v2` | `v2` still works; `v3` is introduced as experimental |

SSA matters in practice: the API server tracks which field manager owns which field, so conflicts with `kubectl edit` or other controllers show up as explicit field conflicts instead of silent overwrites. If a chart sets `spec.replicas` *and* an HPA also manages it, the two fight over the field (Helm re-asserts its value on every upgrade, or reports a conflict); SSA makes the fight visible, it does not remove it. The HPA rule below (omit `replicas` when the HPA is enabled) is correct under both Helm 3 and Helm 4.

**Hooks.** A resource with the annotation `"helm.sh/hook": post-install,pre-upgrade` is not part of the release's normal resources; Helm creates it at that point of the lifecycle and (for Jobs) **waits for completion**; a failed hook fails the operation. Events: `pre-install`, `post-install`, `pre-upgrade`, `post-upgrade`, `pre-delete`, `post-delete`, `pre-rollback`, `post-rollback`, `test`. `hook-weight` orders hooks; `hook-delete-policy` (`before-hook-creation`, `hook-succeeded`, `hook-failed`) controls cleanup. Set the delete policy explicitly (since Helm 3.2 the default is `before-hook-creation`, which replaces the previous Job on the next run); without a sensible policy leftover hook resources pile up or block re-runs. Trade-off: `hook-succeeded` leaves no Job to read logs from (this chart's `migration.keepJob: true` keeps it).

Choosing the event is a design decision. **Schema migration:** `pre-upgrade` (new schema before new code), but on the very first install the database does not exist yet, so `post-install` too. Hooks are not tracked as release resources, so `helm uninstall` does not delete a leftover hook Job unless the delete policy does.

**`helm diff`.** The community plugin `helm diff upgrade <rel> <chart> -f values.yaml` shows what an upgrade would change in the cluster before you run it. In Helm 4 plugin installs verify provenance by default; use `helm plugin install https://github.com/databus23/helm-diff --verify=false` only after you have decided to trust the source. (`helm template | kubectl diff -f -` is the plugin-free equivalent.)

**Dependencies.** `Chart.yaml` `dependencies:` lists subcharts (name, version range, repository). `helm dependency update` downloads them to `charts/` and writes **`Chart.lock`** with exact versions and digests (commit it; `helm dependency build` installs exactly what the lock says, like a lockfile). Subchart values live under a key named after the subchart; `global:` values reach all of them. Day 6's chart has none: Postgres is an in-chart StatefulSet so the lab is self-contained; production would use a managed service or an operator.

### 3. Helm vs Kustomize vs GitOps vs operators

| Tool | Model | Good for | Weak at |
|:---|:---|:---|:---|
| **Helm** | Templates + values → manifests; releases with history | Distributing third-party software; many parametrized installs; hooks | Templating YAML as text is fragile; rollback is manifest-level only |
| **Kustomize** (`kubectl apply -k`) | Plain YAML base + patches/overlays, no templating | Your own apps with a few environment differences; patches on top of someone else's manifests | No release history, no packaging/versioning, no lifecycle hooks |
| **GitOps** (Argo CD, Flux) | A controller in the cluster reconciles the cluster to a Git repo (it can render Helm charts or Kustomize itself) | Audited, pull-based delivery; drift detection; rollback = git revert | It is a delivery model, not a templating tool; `helm list` may show nothing because Argo renders with `helm template` and applies itself |
| **Operators / CRDs** | A CRD (e.g. `Cluster` for CloudNativePG) + a controller that encodes operational knowledge (failover, backups, upgrades) | Stateful systems and anything with day-2 operations | Another controller to run and upgrade; CRDs are cluster-scoped and shared |

A common production shape: Helm chart per app (or Kustomize overlays), Argo CD/Flux applying it from Git, operators for databases, Helm only for installing the operators themselves. A **CRD** is a new resource kind in the API; an **operator** is a controller reconciling CRs of that kind. Envoy Gateway, which you installed on Day 4, is exactly that: Gateway API CRDs plus a controller.

### 4. Pod composition patterns

#### Init containers
Run **sequentially, to completion, before** the app containers start. If one fails, the kubelet retries it according to the pod's `restartPolicy` (`Always`/`OnFailure` → restarted with back-off, pod stays `Init:Error`/`Init:CrashLoopBackOff`; with `Never` the pod fails). The app containers never start until all init containers succeed. Use them for dependency gates (this chart's `wait-for-postgres` loops on `pg_isready`), one-off setup, fetching config. They keep tooling (`psql`, migration binaries) out of the runtime image. They run on **every** pod start, including each replica, so they are the wrong place for one-per-release work such as schema migration: that is the hook Job.

#### Native sidecars (Kubernetes 1.33+, GA)
A sidecar is a helper container that lives as long as the app. Until 1.28 it was just a second entry in `containers:`, with real lifecycle problems: no start ordering (the app could start before its proxy), and no stop ordering (a Job never finished because the sidecar kept running). Now a sidecar is an **init container with `restartPolicy: Always`**:
```yaml
initContainers:
  - name: readiness-watcher
    image: busybox:1.37
    restartPolicy: Always      # this is what makes it a native sidecar
```
Behaviour: it starts **before** the app containers (in init order) and the next init container waits for its startup, it keeps running next to the app, it is restarted on its own, it counts in the pod's READY column (the order-api pod shows **2/2**), and on shutdown it is stopped **after** the app containers, so a log shipper or proxy outlives the process it serves. A Job's pod can complete even though a sidecar is still running.

What this chart's sidecar does: `readiness-watcher` polls the app's `/ready` on `localhost:8080` and logs every transition (`unknown -> not-ready -> ready`, and later `ready -> not-ready` when SIGTERM flips readiness to 503). That is a small but honest job: it shows start ordering, shared network namespace, and shutdown ordering in `kubectl logs -c readiness-watcher`. The apps log to stdout, so a log-shipper sidecar would have nothing to ship from a file; and it is *not* a service mesh, so do not mistake it for one.

Typical real uses: a service-mesh proxy, a log/metrics shipper reading a shared volume, an auth proxy, a config reloader. **When it is wrong:** when a library does the job (log to stdout instead of file + shipper), or when every pod pays CPU and memory for something a node-level DaemonSet (log agent) does once per node.

#### Ambassador and adapter
An **ambassador** is a proxy container that represents a remote system on `localhost` (a database proxy that handles TLS/IAM). An **adapter** translates the app's output to a standard shape (a metrics exporter). Both are sidecars by mechanism; they differ in intent.

### 5. Production reliability

#### Resources, QoS, and the requests ≤ limits rule
`resources.requests` is what the scheduler reserves; `limits` is the ceiling the kernel enforces. **A request larger than the limit is rejected by the API server** (`must be less than or equal to memory limit`), so lowering a limit below the request needs the request lowered too. Exceeding a **memory** limit gets the process OOM-killed (`Reason: OOMKilled`, exit code 137 = 128 + SIGKILL); exceeding a **CPU** limit only throttles.

| QoS class | Criteria | Eviction under node memory pressure |
|:---|:---|:---|
| Guaranteed | every container has requests == limits (CPU and memory) | last |
| Burstable | at least one request or limit set, not Guaranteed | after BestEffort, ordered by usage over request |
| BestEffort | nothing set | first |

Note that a native sidecar's requests count toward the pod's total, which matters for the next topic.

#### HPA
The HPA controller reads **metrics-server** (every 15 s by default) and computes `desired = ceil(current × currentMetric / target)`, bounded by min/max, with a scale-down stabilization window (default 300 s) so it does not flap.
- CPU **utilization** is a percentage of the pod's CPU **requests, summed over all containers** (the native sidecar's requests are part of that sum; `kubectl describe hpa` shows what your version counts). No requests → `<unknown>`; no metrics-server → `<unknown>` too. Check `kubectl top pods` first.
- **Helm and the HPA both want to own `replicas`.** If the Deployment template renders `replicas: N` while an HPA is active, every `helm upgrade` resets the replica count to N. Render it only when the HPA is disabled: `{{- if not .Values.hpa.enabled }} replicas: … {{- end }}`. Be precise about what omitting does: if Helm was the **sole owner** of `spec.replicas` (for instance when you switch an existing release from fixed replicas to the HPA), removing the field removes Helm's ownership and the API server defaults the Deployment to **1 replica**, then the HPA raises it to `minReplicas`: a one-time dip. Once the HPA has written the field it co-owns it, and later upgrades that omit `replicas` leave the HPA's value alone (that is why the lab's later upgrades keep 6). Safe migration: accept the short dip off-peak, or first let the HPA take over the field (enable it while keeping the old value, wait for its first write), then drop `replicas` from the template; the Kubernetes HPA docs describe the same migration.

#### PodDisruptionBudget (PDB)
A PDB limits **voluntary** disruptions: evictions through the Eviction API, which is what `kubectl drain`, the cluster autoscaler and node-upgrade tooling use. It does **not** protect against involuntary loss (node crash, OOM kill, a `kubectl delete pod`, which is a plain delete and ignores PDBs) and it never *creates* replicas; it only refuses an eviction that would take the app below budget. The API answers an over-budget eviction with HTTP 429, and `drain` retries until it is allowed.
```yaml
spec:
  maxUnavailable: 1               # or minAvailable; with `minAvailable: 1` and 1 replica nothing can ever be evicted
  unhealthyPodEvictionPolicy: AlwaysAllow   # pods that are Running but not Ready may be evicted
  selector: {matchLabels: {app: order-api}}
```
Prefer `maxUnavailable` for Deployments (it scales with the replica count). Without `unhealthyPodEvictionPolicy: AlwaysAllow`, a crash-looping or unready pod is *counted against the budget but protected*, and can stall a node drain indefinitely. A budget that allows zero disruptions blocks every node upgrade: the classic "drain hangs" outage.

#### Probes
| Probe | Question | On failure | Impact |
|:---|:---|:---|:---|
| `startupProbe` | Has the app finished starting? | After `failureThreshold` the container is killed and restarted | Pauses liveness and readiness until it first succeeds; gives slow starters room without a huge `initialDelaySeconds` |
| `readinessProbe` | Should traffic reach this pod right now? | Pod removed from Service endpoints (EndpointSlice `ready: false`); **no restart** | Traffic stops, process keeps running; this is also what a rolling update waits for |
| `livenessProbe` | Is the process stuck beyond recovery? | The kubelet **restarts the container**: SIGTERM, the grace period, then SIGKILL | A restart loop if it checks something the restart cannot fix |

The apps in this course expose `/health` (liveness: the process is up) and `/ready` (readiness: 200, but 503 once SIGTERM arrives). They are deliberately different endpoints. **Golden rule:** never put an external dependency (database, payment provider) in a liveness probe: when the database has an outage every pod fails liveness at once, the kubelet restarts them all, and the cold-start connection storm makes the outage worse. A dependency belongs in readiness (or a circuit breaker), where the failure just removes the pod from rotation. `kubectl get endpointslices` is the current API (`Endpoints` is deprecated since 1.33).

#### Spreading: topologySpreadConstraints and anti-affinity
`topologySpreadConstraints` keeps replicas evenly spread over a topology key (`kubernetes.io/hostname`, `topology.kubernetes.io/zone`). `maxSkew: 1` means no domain may hold more than one more pod than the emptiest domain; `whenUnsatisfiable: DoNotSchedule` is a hard rule (pods stay `Pending`), `ScheduleAnyway` a preference. `podAntiAffinity` is the older tool: "not on a node that already runs pods with this label", simpler to read but all-or-nothing per rule. Spreading across zones is what lets a PDB plus a zone outage leave you with replicas; on this one-node cluster the chart uses `ScheduleAnyway` on the hostname because a zone label does not exist (a `DoNotSchedule` on a missing topology key would leave every pod `Pending`).

### 6. Graceful shutdown and the endpoint-propagation race

When a pod is deleted (rollout, scale-down, eviction):
1. The pod gets a `deletionTimestamp` and becomes `Terminating`.
2. **In parallel, with no ordering between them:** (a) the EndpointSlice controller removes the pod from its Service's endpoints and the change propagates to kube-proxy / the Gateway's data plane (Envoy reads it over xDS); (b) the kubelet runs the `preStop` hook, then sends **SIGTERM** to the container.
3. The kubelet waits up to `terminationGracePeriodSeconds` (default 30) **counted from step 2, including the time spent in `preStop`**, then sends SIGKILL.

The race: (a) takes anywhere from milliseconds to seconds; (b) starts immediately. A Go service that calls `http.Server.Shutdown` on SIGTERM stops accepting new connections at once, but for a short window the load balancer still has this pod in rotation and sends requests to it: **connection refused / 503 during a perfectly healthy rolling update**. Probes cannot fix it, because they only add pods; nothing tells the balancer fast enough that the pod is leaving.

The fixes, both of which keep the pod accepting traffic *after* the removal begins:
- **`lifecycle.preStop.sleep.seconds: 10`** (native since 1.30, GA in 1.34): the kubelet sleeps before SIGTERM, so the endpoint removal propagates first. The `sleep` action is built in: a distroless image has no `sleep` binary, so `exec: ["sleep","10"]` would fail. The pod's grace period must cover it.
- **App-level drain:** on SIGTERM, flip readiness to 503 and keep serving for N seconds before shutting down. These services do exactly that with `DRAIN_DELAY_SECONDS` (default 0 so the experiment is honest). This also works where the platform offers no preStop, and it makes the drain visible (`/ready` returns 503 while requests still succeed), at the cost of the code knowing about it.

**Sizing:** `terminationGracePeriodSeconds` must be greater than `preStop + drain delay + the app's own shutdown timeout (20 s here)`, or the kubelet SIGKILLs a pod that is still finishing requests. The chart enforces this at render time: `helm template --set shutdown.preStopSleepSeconds=30` fails with `terminationGracePeriodSeconds=45 is too short: need >= … = 50`. Do not set the grace period to 0 (immediate SIGKILL).

Related, for the API-gateway case: Envoy-based gateways use **panic routing**: when fewer than 50% of a Service's endpoints are healthy, Envoy fails open and load-balances across *all* of them, so a draining or not-ready pod can still receive traffic. Single-replica (or mostly-unready) rollouts are exposed to this: keep at least 2 replicas. The gateway itself drains the same way; and a **liveness** failure takes the same path (SIGTERM, grace period, SIGKILL), so a restarted container is also subject to this race.

---

## Exercises

### Exercise 1 — HPA shows `<unknown>`
`kubectl get hpa` shows `TARGETS: <unknown>/70%`. List the causes and how you tell them apart.

**Hint:** two different components must provide numbers: one for usage, one for the denominator.

**Solution sketch:**
1. **No requests on a container** → no denominator. All containers count: a sidecar without a CPU request also breaks it. `kubectl describe hpa` says `missing request for cpu`.
2. **metrics-server missing/unhealthy** → no numerator. `kubectl top pods -n orderflow` errors with `Metrics API not available`. Install it from `labs/shared/metrics-server.yaml` (it needs `--kubelet-insecure-tls` on Docker Desktop/kind).
3. **Pods just started:** metrics need ~15–60 s; `<unknown>` for the first minute is normal (`did not receive metrics for targeted pods` in the events).

### Exercise 2 — Init container, native sidecar, or hook Job?
(a) Create the `orders` table before the new version serves traffic. (b) Wait until Postgres accepts connections before the app starts. (c) Ship the access logs of every pod to a remote system for the pod's whole life. Pick a mechanism for each and say why not the others.

**Hint:** per pod or per release? Finite or continuous?

**Solution sketch:** (a) **Hook Job** (`pre-upgrade`, plus `post-install` for the first install): once per release, not once per replica, and a failure fails the release. As an init container it would run on every replica start and race with its siblings. (b) **Init container**: per pod, finite, blocks the app. (c) **Native sidecar** (or a node-level DaemonSet agent, which is cheaper): continuous, lifetime tied to the pod; as a plain init container it would never exit and the pod would never start; as an ordinary second container, the pod's shutdown order is undefined.

### Exercise 3 — A PDB that blocks the upgrade
A team sets `minAvailable: 1` on a Deployment with `replicas: 1`. Cluster upgrade day: what happens, and what are two fixes?

**Hint:** what does `ALLOWED DISRUPTIONS` show?

**Solution sketch:** `ALLOWED DISRUPTIONS: 0`, every eviction of that pod returns 429 and `kubectl drain` waits forever (it never creates the replacement; it only refuses). Fixes: run ≥ 2 replicas with `maxUnavailable: 1` (preferred), or drop the PDB for a single-replica non-critical workload; add `unhealthyPodEvictionPolicy: AlwaysAllow` so a broken pod cannot hold a node hostage. A PDB does not apply to `kubectl delete pod` or to a node crash.

### Exercise 4 — Why does a healthy rolling update return 503s?
You deploy with `maxUnavailable: 0`, good readiness probes, and the Go service shuts down gracefully on SIGTERM. Under load you still see a handful of 503/502s during every rollout. Explain and fix without changing the app.

**Hint:** which two things happen at the same time when a pod is deleted?

**Solution sketch:** endpoint removal and SIGTERM race; the app closes its listener before the data plane stops sending to it. Add `lifecycle.preStop.sleep.seconds: 10` (and raise `terminationGracePeriodSeconds` above preStop + shutdown time). App-level alternative: keep serving for a drain delay while `/ready` returns 503. The lab measures the difference.

### Exercise 5 — Liveness cascade
A liveness probe calls `/health/full` which queries PostgreSQL and a payment API. The database hits its connection limit. What happens across 20 replicas, and what is the right design?

**Hint:** what does the kubelet do on liveness failure?

**Solution sketch:** all 20 fail liveness together, the kubelet SIGTERMs then SIGKILLs them, all 20 reconnect at once (thundering herd) and the database stays down. Right design: liveness checks only the process (`/health`); dependency state belongs in readiness (pods leave rotation, nothing restarts) plus timeouts/circuit breakers in the client.

---

## Anti-patterns / Common mistakes

1. **`replicas:` in the template while an HPA owns the Deployment.** Helm and the HPA fight over the field and each `helm upgrade` can reset the scale. Omit the field when `hpa.enabled` (expect a one-time dip to 1 when migrating an existing release, see the HPA section).
2. **Same endpoint for liveness and readiness**, or a dependency in liveness. Restarts on transient dependency trouble.
3. **No `preStop`/drain on services behind a load balancer or gateway.** Every deploy drops a few requests; nobody notices until traffic grows.
4. **`terminationGracePeriodSeconds` shorter than preStop + drain + shutdown time**, or `0`: SIGKILL mid-request.
5. **A `values.namespace` or hardcoded names/namespaces in templates.** The release's namespace and name are the template inputs; hardcoding makes `-n` and a second release lie, and a fixed ConfigMap name collides with what is already in the namespace.
6. **Schema migration in an init container.** It runs once per replica, concurrently. Use a hook Job (and make migrations backward compatible, because rollback does not undo them).
7. **A PDB with zero allowed disruptions**, or relying on a PDB to protect against `kubectl delete`/node failure.
8. **Ingress templates with hardcoded controller annotations** (e.g. regex rewrites) and ignored `values`. Annotations, class and paths belong in values; `Prefix` paths need no rewrite.
9. **Secrets in `values.yaml` for real clusters.** The lab password is a placeholder; production passes `existingSecret` from a secret manager.
10. **`helm rollback` as a data undo.** It re-applies manifests only.

---

## Recall drill

1. Name two things `helm rollback 1` does *not* restore, and the revision number it creates after revisions 1–2.
2. What makes a container a native sidecar, and in which order are sidecars stopped relative to app containers?
3. HPA `<unknown>`: name the two usual causes.
4. Which of `startupProbe`, `readinessProbe`, `livenessProbe` can restart the container, and which removes the pod from endpoints?
5. Why does `preStop.sleep` fix 503s during a rollout, and what must `terminationGracePeriodSeconds` exceed?
6. What does a PDB not protect against?
7. Helm 4 names for `--atomic` and `--force`?

<details>
<summary>Answers</summary>

1. PVC/database contents and CRDs (and anything not in the stored manifests); it creates revision **3** (`Rollback to 1`).
2. `restartPolicy: Always` on an entry in `initContainers`; stopped **after** the app containers.
3. Missing CPU requests (on any container) or no working metrics-server.
4. Startup (on failure) and liveness restart the container; readiness removes the endpoint.
5. Endpoint removal and SIGTERM start simultaneously; the sleep lets the data plane stop routing before the app stops accepting. It must exceed preStop + drain delay + the app's shutdown timeout.
6. Involuntary disruptions (node failure, OOM kill, `kubectl delete pod`); it also never creates replicas.
7. `--rollback-on-failure` and `--force-replace`.
</details>

---

## Lab
See [`labs/day06/`](../labs/day06/).
- **The goal:** install the OrderFlow chart under the `restricted` Pod Security Standard with a Helm-hook migration against a chart-managed Postgres, expose it through the Day 4 Gateway, upgrade/roll back with correct revisions, reproduce an OOM kill, an HPA scale-out, a broken-readiness rollout and the PDB's behaviour, and **measure** dropped requests during a rollout with preStop 0 vs 10 s.
- **Success signal:** `helm install` succeeds in a restricted namespace; `order-api` is `2/2`; the `orders` table exists in Postgres; `curl http://localhost/orders` returns 200 through the Gateway; the load test shows errors with preStop 0 and none with 10.

---

## Key commands reference

| Command | Purpose |
|:---|:---|
| `helm lint <chart>` | Validate chart structure and templates |
| `helm template <rel> <chart> -n <ns> -f <values> \| kubectl apply --dry-run=server -f -` | Render locally, validate on the API server |
| `helm install <rel> <chart> -n <ns> -f <values>` | Install (revision 1) |
| `helm upgrade <rel> <chart> -f <values> --set k=v --wait --rollback-on-failure --timeout 2m` | Upgrade; roll back automatically if it does not become ready |
| `helm history <rel> -n <ns>` / `helm rollback <rel> <N>` | Revisions / roll back to N (creates a new revision) |
| `helm get values <rel> [--revision N]` / `helm get hooks <rel>` | What was deployed |
| `kubectl get hpa,pdb,endpointslices -n <ns>` | Autoscaler targets, allowed disruptions, endpoint readiness |
| `kubectl top pods -n <ns>` | Live CPU/memory (needs metrics-server) |

---

## Teardown
```bash
helm uninstall orderflow -n orderflow --ignore-not-found
bash labs/shared/reset.sh
kubectl delete namespace orderflow --ignore-not-found
```
(The platform pieces from Day 4, the Gateway `edge` and Envoy Gateway, and metrics-server stay installed.)

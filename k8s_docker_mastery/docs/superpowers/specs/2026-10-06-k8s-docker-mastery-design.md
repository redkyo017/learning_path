> **Update:** a review-driven fix plan changed the implementation of this spec; see [`docs/superpowers/plans/2026-10-06-k8s-docker-mastery-fixes-plan.md`](../plans/2026-10-06-k8s-docker-mastery-fixes-plan.md) and the findings in [`docs/superpowers/reviews/2026-10-06-review-findings.md`](../reviews/2026-10-06-review-findings.md).

# Docker & Kubernetes Mastery — Design Spec

**Date:** 2026-10-06
**Location:** `k8s_docker_mastery/`
**Duration:** 7 days, ~3.5 h/day (~24.5h total)

---

## Purpose & Goals

Build a 7-day aggressive learning path that systematically consolidates an experienced backend/microservices engineer's hands-on Docker and Kubernetes knowledge into structured, deep understanding. The learner uses Docker daily, works with API gateways and microservices as a backbone, and can do things by habit — but wants to understand the *why*, know the failure modes, and master the design patterns that separate operators from architects.

This is not a beginner tutorial. It is a consolidation-and-deepening path: internals, best practices, design patterns, anti-patterns, and production-grade techniques. The strategy follows the "top 1%" approach — learn by understanding the layers beneath the abstraction, break things intentionally to understand failure modes, and know when NOT to use each pattern.

**Mastery defined:** By day 7, the learner can:
- Explain what happens between `docker run` and the process starting
- Write production-grade Dockerfiles with multi-stage builds, security hardening, and cache optimization
- Design K8s deployments with proper resource management, security, networking, and observability
- Debug any K8s failure by tracing from symptom → controller → events → root cause
- Package applications as Helm charts with production values
- Articulate when each K8s design pattern (sidecar, init container, ambassador) is the right — and wrong — choice

---

## Success Criteria

1. Can explain Linux namespaces, cgroups, and OverlayFS and how Docker maps to them
2. Can write a multi-stage Dockerfile that produces a minimal, non-root, scannable image
3. Can wire a multi-service Docker Compose stack with healthchecks, networks, and volumes
4. Can deploy a microservice application on K8s using raw manifests
5. Can trace a request from external client → Ingress → Service → Pod and explain each hop
6. Can configure NetworkPolicies to isolate services
7. Can set up a StatefulSet with PVCs for a database workload
8. Can lock down pods with SecurityContext, RBAC, and Pod Security Standards
9. Can package an application as a Helm chart with values, templates, and helpers
10. Can implement K8s design patterns: sidecar, init container, HPA, PDB
11. Can debug CrashLoopBackOff, ImagePullBackOff, OOMKilled, Pending, and DNS failures using only kubectl
12. Can articulate production readiness: probes, resource limits, graceful shutdown, observability
13. (Optional) Can deploy a Helm chart on EKS with IRSA and ALB Ingress Controller

---

## Constraints & Environment

| Constraint | Detail |
|---|---|
| **Primary lab env** | Docker Desktop (macOS) with built-in Kubernetes enabled. Alternative: `kind` for multi-node simulation. |
| **Optional lab env** | Personal AWS account for EKS appendix. Learner manages cost. |
| **Cost** | All primary labs are free (local). EKS appendix includes teardown checklist. |
| **Credentials** | No real secrets in any file. Use placeholders + `.env.example` / `values.yaml` examples. |
| **Language** | OrderFlow microservices written in Go (learner's primary language). |
| **Running infra** | Labs are written, not auto-deployed. Learner runs them manually. |
| **No git push** | Authoring branch only. Never push to remote. |

---

## Strategy (the core design decision)

### Core mental model

- **Docker** = a user-friendly wrapper around three Linux kernel features: namespaces (isolation), cgroups (resource limits), union filesystems (image layers). Every Docker behavior is predictable once you see these primitives.
- **Kubernetes** = a declarative reconciliation loop: declare desired state → controllers continuously drive actual state toward it. Every K8s object is a different controller watching a different desired-state spec. Debugging = "which controller is stuck?"

### The pattern loop (apply every day)

1. Name the concept and the problem it was invented to solve
2. Map it to the layer — kernel primitive / Docker abstraction / K8s object / design pattern
3. Wire it — minimal lab, see it work
4. Break it — remove a component, inject a failure, exhaust a limit
5. Fix it — add the resilience mechanism the pattern implies
6. Know when NOT to use it — every tool has a "wrong scenario"

### What the 80% waste time on

| Trap | Why it fails |
|---|---|
| Tutorial-driven learning (follow along, copy-paste YAML) | Builds false confidence — you can replicate but can't adapt |
| Learning Docker and K8s as separate tools | They're a stack — image quality determines K8s behavior |
| Ignoring networking until it breaks | Networking is where 60%+ of production issues live |
| Skipping resource limits and security | "It works in dev" → OOMKilled, privilege escalation in prod |
| Memorizing K8s YAML fields | Understand the controller model; the fields become derivable |
| Using `:latest` tag everywhere | Non-reproducible deployments, cache-busting, silent regressions |
| Never reading `kubectl describe` or events | The answer is almost always in the events; beginners only check logs |

### What the top 1% do differently

- They can explain what happens between `docker run` and the process starting (namespace creation, cgroup assignment, layer mount, entrypoint exec)
- They debug K8s by asking "which controller owns this object and what's its status?" — not by randomly restarting pods
- They treat Dockerfiles as build pipelines — multi-stage, minimal base images, layer ordering for cache efficiency
- They design K8s manifests with failure in mind — liveness/readiness probes, resource limits, PDBs, anti-affinity
- They understand the networking stack end-to-end: container → pod network → Service (kube-proxy/iptables) → Ingress → external

### Why alternatives were rejected

- **Production Incident Driven:** Extremely practical but leaves systematic coverage gaps — design patterns and best practices don't surface naturally from incident debugging alone.
- **Build a Platform (project-only):** Risks rushing through theory to hit milestones. The learner already knows how to make things work — the gap is understanding why.
- **Chosen approach (Hybrid):** Internals-first depth + pattern breadth + a running microservice example (OrderFlow) for continuity + "break it" sections from incident-driven for practical debugging. Best of all three.

---

## Container Orchestration Decision Framework

The top 1% don't just know K8s — they know **when K8s is the wrong answer**. This framework is a first-class part of the path, not an afterthought. It's covered as theory in Day 7 (Production Synthesis) with a decision exercise.

### Step 1 — Do you even need containers?

Before choosing an orchestrator, determine if containers are the right abstraction:

| Signal | Direction |
|---|---|
| Need consistent dev/prod environment parity | → Containers |
| Event-driven, bursty, short-lived functions (< 15min) | → Serverless (Lambda) — skip containers entirely |
| Legacy monolith with specific OS/kernel dependencies | → VMs (EC2) — containerizing adds risk without benefit |
| GPU/specialized hardware with driver dependencies | → VMs or bare-metal — container GPU support exists but adds complexity |
| Licensing tied to specific OS instances | → VMs — container licensing is murky for some vendors |

### Step 2 — ECS/Fargate vs Kubernetes (EKS)

This is the real decision for most AWS-native teams. Think of it as a spectrum of control vs operational burden:

```
Less control, less burden                              More control, more burden
        ◄──────────────────────────────────────────────────────────►
  Lambda    Fargate     ECS on EC2     EKS on Fargate    EKS on EC2
  (no containers)  (no nodes)   (you manage nodes)  (no nodes,     (full control,
                                                     K8s API)       full ownership)
```

#### Stay with ECS / Fargate when:

| Factor | Why ECS wins |
|---|---|
| **Team size < 10 engineers, no dedicated platform team** | ECS is operationally simpler — no control plane management, no etcd, no RBAC complexity. One less thing to page about at 3am. |
| **Pure AWS stack** | ECS integrates natively with ALB, CloudMap, App Mesh, CloudWatch, IAM task roles — no adapters, no controllers to install. If you're already deep in AWS, ECS gives you those integrations for free. |
| **< 15-20 microservices** | Below this threshold, K8s's power (custom controllers, CRDs, advanced scheduling) is overhead you don't need. ECS task definitions + services + ALB target groups handle this cleanly. |
| **Simple networking model** | Security groups on tasks, ALB routing, Cloud Map service discovery. No CNI plugins, no NetworkPolicies to reason about. |
| **Fargate for variable/bursty workloads** | No node capacity planning, no cluster autoscaler tuning, no node AMI patching. Pay per-second for vCPU/memory actually used. |
| **Faster time-to-production** | Less to learn, less to configure, less to operate. A senior engineer can have ECS running in production in a day; EKS takes a week minimum to do properly. |
| **Cost-sensitive at small scale** | ECS control plane is free. EKS control plane costs $0.10/hour ($73/month) before any workloads. |

**Your current setup (ECS Fargate with WSO2 distributed deployment) is a good example of "right tool for the job" — unless you're hitting ECS's walls.**

#### Move to Kubernetes (EKS) when:

| Factor | Why K8s wins |
|---|---|
| **Multi-cloud or hybrid-cloud strategy** | K8s is the only orchestrator that runs identically on AWS, GCP, Azure, and on-prem. If cloud portability matters, K8s is the only serious option. |
| **> 20 microservices with complex topology** | At this scale, you need the ecosystem: Helm for packaging, ArgoCD for GitOps, Istio/Linkerd for service mesh, custom operators for domain-specific automation. ECS has no equivalent ecosystem. |
| **Need custom controllers / CRDs** | K8s's killer feature: extend the API with your own resource types and controllers. "I want a `DatabaseCluster` CRD that auto-provisions RDS" — only K8s supports this pattern. |
| **Advanced scheduling requirements** | Pod affinity/anti-affinity, topology spread constraints, custom schedulers, priority classes, preemption. ECS placement strategies are simpler but less expressive. |
| **Advanced networking (NetworkPolicies, service mesh)** | K8s NetworkPolicies give you pod-level network segmentation. ECS security groups operate at task/ENI level — coarser granularity. If you need "pod A can only talk to pod B on port 8080," that's K8s territory. |
| **Dedicated platform engineering team** | K8s needs a team to operate it. If you have that team (or plan to build it), the investment pays off in operational capabilities. If you don't, K8s will slow you down. |
| **Strong open-source ecosystem dependency** | Prometheus, Grafana, Jaeger, OPA/Gatekeeper, cert-manager, external-dns, Sealed Secrets — the K8s ecosystem is 10x richer than ECS's. If you need 3+ of these, the ecosystem pull justifies K8s. |

#### The hybrid path: EKS on Fargate

EKS on Fargate gives you the K8s API (Deployments, Services, Helm, ArgoCD) without managing nodes. Trade-offs:

| Benefit | Limitation |
|---|---|
| K8s API + no node management | No DaemonSets (no node-level agents) |
| Per-pod security isolation (microVM) | No GPU support |
| IAM per-pod via IRSA | Slower pod startup (~30-60s vs ~5-10s on EC2) |
| Simpler than EKS on EC2 | No persistent volumes (EBS) — only EFS |
| | Higher per-vCPU cost than EC2 spot instances |

**Best for:** Teams that want K8s ecosystem benefits but don't want to manage nodes. Good middle ground when migrating from ECS to K8s.

### Step 3 — Decision tree

```
Q1: Do you need containers at all?
├── Event-driven, < 15min, bursty → Lambda (serverless)
├── Legacy monolith, OS-specific → EC2 (VMs)
└── Microservices, need env parity → Containers → Q2

Q2: How many services and how complex?
├── < 15 services, simple topology, pure AWS → ECS Fargate
├── < 15 services, need K8s ecosystem (Helm, ArgoCD) → EKS Fargate
├── 15-50 services, growing complexity → EKS Fargate or EKS EC2
└── > 50 services, multi-cloud, custom operators → EKS EC2 (full K8s)

Q3: Do you have a platform team?
├── No → Stay with ECS or EKS Fargate (minimize operational surface)
└── Yes → EKS EC2 is viable; you'll get the most from K8s's power

Q4: Are you hitting ECS walls?
├── Need NetworkPolicies (pod-level network segmentation) → EKS
├── Need CRDs / custom controllers → EKS
├── Need service mesh (Istio/Linkerd) → EKS
├── Need advanced scheduling (affinity, topology spread) → EKS
├── Need multi-cloud portability → EKS
└── None of the above → Stay with ECS
```

### Step 4 — Migration signals (when to start planning the move)

You're likely outgrowing ECS when:

1. **Deployment complexity exceeds ECS primitives:** You're building custom tooling around `aws ecs update-service` to handle blue-green, canary, or progressive rollouts that ArgoCD/Flagger handle natively on K8s.
2. **Service mesh becomes necessary:** Your microservices need mutual TLS, traffic shifting, or circuit breaking between services — ECS App Mesh exists but the K8s service mesh ecosystem (Istio, Linkerd, Cilium) is more mature and better supported.
3. **Cross-cutting operational patterns repeat:** You keep building the same sidecar pattern, the same init-container pattern, the same config-reload pattern across services — K8s has first-class support; ECS requires custom task definition gymnastics.
4. **Observability stack outgrows CloudWatch:** You want Prometheus + Grafana + Jaeger + OPA as a unified stack — these are K8s-native tools.
5. **Team size crosses ~15-20 engineers:** At this point, the investment in K8s platform engineering pays for itself in developer self-service, standardized deployments, and ecosystem tooling.

### Common mistakes in the "ECS vs K8s" decision

| Mistake | Reality |
|---|---|
| "K8s is the industry standard, so we should use it" | K8s is a standard, not a default. It's the right tool for complex orchestration — using it for 5 services with a 3-person team is over-engineering. |
| "We'll need K8s eventually, so let's start now" | Pre-mature K8s adoption burns the team's time on platform work instead of product work. Start with ECS, migrate when you hit the walls. |
| "ECS is just for small projects" | ECS runs some of the largest production workloads on AWS. Netflix, Capital One, and Duolingo all use ECS at massive scale. |
| "K8s is too complex" | K8s complexity is proportional to what you use. A basic Deployment + Service + Ingress is not harder than ECS task definition + service + ALB. The complexity comes from the ecosystem — and you adopt that incrementally. |
| "Fargate is always more expensive than EC2" | True per-vCPU, false per-engineer-hour. Factor in node management, AMI patching, cluster autoscaler tuning, and capacity planning. For many teams, Fargate's premium is cheaper than hiring a platform engineer. |

---

## The Running Example: OrderFlow

A 3-service microservice application that evolves across all 7 days:

| Service | Role | Tech |
|---|---|---|
| **order-api** | REST API — accepts and queries orders | Go (net/http) |
| **payment-service** | Processes payments, async communication | Go (net/http) |
| **notification-service** | Sends notifications on order events | Go (net/http) |

Supporting infrastructure:
- **PostgreSQL** — order storage (introduced Day 2 Compose, StatefulSet Day 5)
- **Redis** — optional cache/pub-sub (Day 4 networking exercise)

Each service is intentionally minimal (~100-150 lines) so the focus stays on Docker/K8s, not application logic.

---

## Curriculum

### Day 1 — Docker Internals & Image Mastery (~3.5h)

**Theme:** Crack open the black box — understand what a container actually is

| Block | Content | Time |
|---|---|---|
| **Theory** | Linux primitives: namespaces (pid, net, mnt, uts, ipc, user), cgroups v2 (cpu, memory limits), union filesystem (OverlayFS). How `docker run` maps to these. Container runtime hierarchy: Docker Engine → containerd → runc → kernel. OCI image spec. | 45min |
| **Dockerfile deep-dive** | Instruction semantics (RUN vs CMD vs ENTRYPOINT — and the exec vs shell form trap), COPY vs ADD, ARG vs ENV, layer model & cache invalidation rules, `.dockerignore`, build context. | 45min |
| **Production patterns** | Multi-stage builds (builder → runtime), minimal base images (distroless, alpine, scratch — trade-offs of each), layer ordering for cache efficiency, security scanning (trivy), non-root USER, HEALTHCHECK instruction. | 45min |
| **Lab** | Build OrderFlow's `order-api` with a deliberately bad Dockerfile → analyze with `docker history` and `dive` → refactor to production-grade multi-stage. Break it: exceed cgroup memory limit with `--memory=10m`, observe OOMKill. Inspect namespaces with `docker inspect` and `lsns`. | 60min |

**Anti-patterns:** Fat images (1GB+ for a Go binary), running as root, missing `.dockerignore` (sending `.git/` to build context), invalidating cache early (COPY . before go mod download), secrets baked into layers.

---

### Day 2 — Docker Networking, Volumes & Compose (~3.5h)

**Theme:** How containers talk, persist data, and orchestrate locally

| Block | Content | Time |
|---|---|---|
| **Networking internals** | Bridge networks (docker0), veth pairs, Docker embedded DNS server (127.0.0.11), port mapping (iptables DNAT/SNAT), container-to-container communication on same vs different networks. `--network=none` and `--network=host`. Overlay networks (VXLAN) — concept only, relevant for Swarm/K8s. | 60min |
| **Volumes & storage** | Named volumes vs bind mounts vs tmpfs — when each is correct. Volume lifecycle (survives container removal). Volume drivers. Data ownership (uid/gid mapping). | 30min |
| **Compose deep-dive** | Service definitions, build context in Compose, dependency ordering (`depends_on` with `condition: service_healthy`), profiles, env files (`.env` + `env_file:`), override files (`docker-compose.override.yml`), Compose networking (default bridge, custom networks, aliases). `docker compose watch` for dev. | 45min |
| **Lab** | Wire all 3 OrderFlow services + Postgres in Compose with a custom bridge network, named volume for Postgres data, healthchecks, `.env.example`. Break it: misconfigure service name → DNS resolution failure. Remove named volume → observe data loss. Demonstrate `docker compose override` for dev vs test configs. | 45min |

**Anti-patterns:** Using `links` (deprecated), `depends_on` without healthcheck conditions, bind-mounting `node_modules`, hardcoded IPs between containers, no volume for database data.

---

### Day 3 — Kubernetes Core Objects (~3.5h)

**Theme:** The reconciliation loop — declare desired state, controllers drive reality

| Block | Content | Time |
|---|---|---|
| **Architecture primer** | Control plane components: API server (the only stateful entry point), etcd (the single source of truth), kube-scheduler (bin-packing), kube-controller-manager (runs all controllers). Data plane: kubelet (node agent), kube-proxy (network rules), container runtime (containerd via CRI). The watch-loop pattern. | 45min |
| **Core workload objects** | Pod (the scheduling unit — why not just containers? → shared network namespace, shared volumes, co-scheduling). ReplicaSet (why not just pods? → desired count, self-healing). Deployment (why not just ReplicaSets? → rolling updates, rollback, revision history). Labels & selectors — how controllers find their objects. | 60min |
| **Configuration objects** | ConfigMap (non-sensitive config). Secret (base64 encoding ≠ encryption — what encryption-at-rest actually means). Mounting as env vars vs volume files — trade-offs (env vars visible in `kubectl describe`, volume mounts support hot-reload). | 30min |
| **Lab** | Deploy OrderFlow on K8s (Docker Desktop K8s or kind). Write all manifests by hand — no generators. Create namespace, ConfigMaps, Secrets, Deployments, Services. Scale up/down. Roll out a bad image tag → observe failed rollout → `kubectl rollout undo`. Break it: delete a pod, watch ReplicaSet recreate it. Change a label selector to mismatch → understand why pods become orphaned. | 60min |

**Anti-patterns:** Putting config in container images, using `kubectl run` for production workloads, deploying naked pods (no controller), no resource requests/limits (scheduler flies blind), using `default` namespace for everything.

---

### Day 4 — Kubernetes Networking & Services (~3.5h)

**Theme:** The most misunderstood layer — how traffic actually flows

| Block | Content | Time |
|---|---|---|
| **Pod networking model** | K8s networking requirements (every pod gets a routable IP, pods can reach each other without NAT). CNI (Container Network Interface) — what it does, popular implementations (Calico, Cilium, Flannel). Pause container — the network namespace holder. | 30min |
| **Service deep-dive** | ClusterIP: virtual IP → iptables/IPVS rules → pod endpoints. How kube-proxy maintains these rules. NodePort: ClusterIP + port on every node. LoadBalancer: NodePort + cloud provider LB. ExternalName: CNAME alias. Headless services (clusterIP: None) — direct DNS to pod IPs, used by StatefulSets. Endpoint slices. Service DNS: `<svc>.<ns>.svc.cluster.local`. | 60min |
| **Ingress** | Ingress resource vs Ingress Controller (the controller does the work, the resource is just config). L7 routing: path-based, host-based. TLS termination. IngressClass for multi-controller setups. nginx-ingress controller on Docker Desktop. Gateway API (the future replacement for Ingress — brief intro). | 45min |
| **NetworkPolicies** | Default: all traffic allowed. Deny-all baseline + explicit allow rules. Ingress vs egress policies. Namespace isolation. podSelector and namespaceSelector. CIDR-based rules for external access control. | 30min |
| **Lab** | Expose OrderFlow: ClusterIP for payment-service and notification-service (internal only), Ingress for order-api (external). Install nginx-ingress controller. Add NetworkPolicy: payment-service only accepts traffic from order-api namespace. Break it: misconfigure Service selector → `kubectl describe endpoints` shows empty endpoints. Remove NetworkPolicy → demonstrate any-pod-to-any-pod access. Trace a full request: `curl → Ingress → Service → iptables → Pod`. | 45min |

**Anti-patterns:** Using NodePort in production (exposes ports on every node), hardcoding pod IPs in application code, no NetworkPolicies (flat network = any compromised pod can reach any service), not understanding that ClusterIP is iptables rules (not a real server), ignoring DNS caching issues.

---

### Day 5 — Storage, Security & RBAC (~3.5h)

**Theme:** The production-readiness layer most people skip

| Block | Content | Time |
|---|---|---|
| **Storage model** | PersistentVolume (PV): cluster-level storage resource. PersistentVolumeClaim (PVC): namespace-level request. StorageClass: dynamic provisioning template. Access modes: ReadWriteOnce (RWO), ReadOnlyMany (ROX), ReadWriteMany (RWX) — and what each actually means for scheduling. Reclaim policies (Retain, Delete). Volume lifecycle (provisioning → binding → using → releasing → reclaiming). | 45min |
| **StatefulSets** | Why Deployments aren't enough for stateful workloads: stable network identity (`pod-0`, `pod-1`), stable storage (per-pod PVC via `volumeClaimTemplates`), ordered startup/shutdown. Headless service pairing. When to use StatefulSet vs Deployment + external state. | 30min |
| **Security model** | SecurityContext: `runAsNonRoot`, `runAsUser`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, `capabilities` (drop ALL, add only what's needed). Pod Security Admission (PSA): namespace-level enforcement of Privileged / Baseline / Restricted standards. `seccompProfile`. | 45min |
| **RBAC** | Authentication (who are you?) vs Authorization (what can you do?). Role (namespace-scoped) vs ClusterRole (cluster-scoped). RoleBinding vs ClusterRoleBinding. ServiceAccounts — every pod gets one. Default ServiceAccount dangers. Principle of least privilege: start with nothing, add only required verbs on specific resources. Auditing: `kubectl auth can-i`. | 45min |
| **Lab** | Add Postgres as a StatefulSet with `volumeClaimTemplates` and a headless service. Lock down all OrderFlow pods: non-root, read-only filesystem, drop ALL capabilities, restricted PSA label on namespace. Create dedicated ServiceAccounts: order-api gets read access to ConfigMaps, payment-service gets no extra permissions. Break it: try to write to filesystem with `readOnlyRootFilesystem: true` → fix with `emptyDir` for `/tmp`. Run `kubectl auth can-i` to verify RBAC. Delete PVC → observe data loss vs Retain policy. | 60min |

**Anti-patterns:** Running containers as root in K8s, using the `default` ServiceAccount (has more permissions than you think), mounting secrets as env vars (visible in process listing and `kubectl describe`), no PodDisruptionBudget, wildcard RBAC (`*` verbs on `*` resources), StorageClass with Delete reclaim policy for critical data.

---

### Day 6 — Helm, Templating & Design Patterns (~3.5h)

**Theme:** From artisanal YAML to repeatable, maintainable deployments

| Block | Content | Time |
|---|---|---|
| **Helm deep-dive** | Why Helm (the package manager problem for K8s). Chart structure: `Chart.yaml`, `values.yaml`, `templates/`, `charts/` (dependencies). Template syntax: Go templates, `{{ .Values.x }}`, `{{ include }}`, `{{ if }}`, `{{ range }}`. Named templates and `_helpers.tpl`. Helm hooks (pre-install, post-install, pre-upgrade). Release lifecycle: `install` → `upgrade` → `rollback` → `uninstall`. `helm template` for dry-run debugging. `helm diff` plugin. Dependency management: `Chart.lock`, subcharts. | 60min |
| **K8s design patterns** | **Sidecar:** co-located container that extends the main container's functionality (logging agent, service mesh proxy, config reloader). **Init Container:** runs before main containers, used for migrations, config fetching, dependency waiting. **Ambassador:** outbound proxy (simplify external service access). **Adapter:** normalize output format (different log formats → standard). When each is the right choice and when it's over-engineering. | 60min |
| **Production patterns** | Resource management: `requests` (scheduler guarantee) vs `limits` (hard ceiling). QoS classes: Guaranteed (requests == limits), Burstable (requests < limits), BestEffort (neither set) — and how they affect eviction priority. HPA (Horizontal Pod Autoscaler): metrics-server → CPU/memory targets → scale. VPA (Vertical Pod Autoscaler) — concept. PodDisruptionBudget (PDB): `minAvailable` / `maxUnavailable` during voluntary disruptions. Probes: liveness (is it alive? → restart), readiness (can it serve? → remove from Service), startup (is it ready yet? → delay other probes). Graceful shutdown: `preStop` hook, `terminationGracePeriodSeconds`, SIGTERM handling in application. Pod topology spread constraints and anti-affinity. | 45min |
| **Lab** | Package entire OrderFlow as a Helm chart. `values.yaml` with environment-specific overrides (`values-dev.yaml`, `values-production.yaml`). Add init container for DB schema migration (runs `psql` commands before order-api starts). Add sidecar to order-api for structured log forwarding. Configure HPA targeting 70% CPU. Set PDB `minAvailable: 1`. Configure liveness, readiness, and startup probes appropriately (not identical). `helm template` to debug. `helm install` → `helm upgrade` with changed values → `helm rollback`. Break it: set memory limit to 20Mi → OOMKilled → find right size with `kubectl top`. Set readiness probe to wrong port → observe traffic blackhole during rollout. | 45min |

**Anti-patterns:** Helm charts with hardcoded values (defeats the purpose), identical liveness and readiness probes (they serve different purposes), HPA without resource requests (HPA can't calculate percentages), no PDB (cluster drain kills all your pods at once), liveness probe on an external dependency (if DB is down, restarting the app won't fix the DB), `terminationGracePeriodSeconds: 0` (kills in-flight requests).

---

### Day 7 — Observability, Debugging & Production Synthesis (~4h)

**Theme:** What separates "I can deploy" from "I can operate" — and when to use K8s at all

| Block | Content | Time |
|---|---|---|
| **Observability stack** | What to monitor: the USE method (Utilization, Saturation, Errors) for infrastructure; RED method (Rate, Errors, Duration) for services. metrics-server: node and pod resource usage (`kubectl top`). Logging architecture: application → stdout/stderr → container runtime → kubelet → node log file. Why stdout matters (K8s logging contract). Log aggregation patterns (EFK, Loki — concepts only). Prometheus metrics concepts (counters, gauges, histograms). | 40min |
| **Debugging mastery** | The debugging decision tree: symptom → `kubectl get` (status?) → `kubectl describe` (events?) → `kubectl logs` (app error?) → `kubectl exec` (inspect container?) → network debug pod (connectivity?). Common failure modes with root causes: **ImagePullBackOff** (wrong tag, no pull secret, private registry), **CrashLoopBackOff** (app crash, wrong command, missing config, OOMKilled), **Pending** (no schedulable node, insufficient resources, unbound PVC), **OOMKilled** (memory limit exceeded — container vs pod level), **Evicted** (node under pressure), **CreateContainerConfigError** (missing ConfigMap/Secret). `kubectl debug` and ephemeral containers for distroless images. `kubectl port-forward` for ad-hoc testing. | 50min |
| **Container orchestration decision framework** | When to use K8s vs ECS/Fargate vs serverless vs VMs. The control-vs-burden spectrum: Lambda → Fargate → ECS on EC2 → EKS on Fargate → EKS on EC2. Decision signals for when to stay on ECS (< 15 services, pure AWS, no platform team, simple networking) vs when to move to K8s (multi-cloud, > 20 services, need CRDs/operators, need service mesh, need advanced scheduling). Migration signals: custom tooling around ECS deploys, service mesh needs, cross-cutting operational patterns, observability outgrowing CloudWatch. The hybrid path: EKS on Fargate. Common decision mistakes ("K8s is the industry standard" ≠ "K8s is the right choice for us"). | 45min |
| **Production readiness** | The 12-factor app mapped to K8s. Namespace strategy: per-team vs per-environment vs hybrid. Label and annotation conventions (app, version, team, component). GitOps model: repo as source of truth → ArgoCD/Flux watches → auto-sync to cluster (concept, not lab). CI/CD pipeline pattern: build → test → scan → push image → update manifest → sync. Blue-green and canary deployment strategies on K8s. | 40min |
| **Lab** | Full production simulation: deploy OrderFlow Helm chart with all Day 5-6 hardening. Install metrics-server, verify `kubectl top` works. Simulate failures and debug each: (1) push bad image tag → ImagePullBackOff, (2) misconfigure CMD → CrashLoopBackOff, (3) set memory limit too low → OOMKilled, (4) break DNS → connection refused, (5) remove ConfigMap → CreateContainerConfigError. Create a debugging runbook documenting symptom → diagnosis → fix for each. **Decision exercise:** Given 3 real-world scenarios (5-service startup on AWS, 30-service fintech with compliance, 8-service team migrating from monolith), choose the right orchestration strategy and justify it. | 65min |

**Anti-patterns:** Logging to files inside containers (lost on restart, hard to collect), no resource monitoring (flying blind), restarting pods as first debugging step (hides root cause), not checking events (the answer is usually there), overly aggressive liveness probes (healthy app gets killed during slow GC), adopting K8s because "everyone does it" without evaluating whether ECS/Fargate meets the actual requirements.

---

### Appendix — EKS Production Experience (Optional, ~3h)

**Theme:** Bridge from local K8s to production cloud Kubernetes

| Topic | Content |
|---|---|
| **EKS cluster setup** | `eksctl` cluster creation, managed node groups vs Fargate profiles — when each is right |
| **IRSA** | IAM Roles for Service Accounts — how pod-level AWS identity works, why node-level IAM roles are dangerous |
| **AWS Load Balancer Controller** | ALB Ingress → replaces nginx-ingress with AWS-native L7, annotations for target groups, health checks |
| **EBS CSI Driver** | Dynamic PV provisioning on EKS, gp3 StorageClass |
| **Lab** | Deploy OrderFlow Helm chart on EKS with IRSA for order-api → S3 access, ALB Ingress, EBS PVCs. Full teardown checklist (EKS cluster, node groups, ALB, EBS volumes, IAM roles). |
| **Cost estimate** | ~$2.50/hour for minimal EKS cluster. Lab designed for < 2 hours active time. |

---

## Directory Layout

```
k8s_docker_mastery/
├── README.md                          # quickstart, prerequisites, day index, usage
├── STRATEGY.md                        # "top 1%" strategy document
├── content/
│   ├── GLOSSARY.md                    # ~80+ terms, plain-English, organized by domain
│   ├── day01.md                       # Docker Internals & Image Mastery
│   ├── day02.md                       # Docker Networking, Volumes & Compose
│   ├── day03.md                       # Kubernetes Core Objects
│   ├── day04.md                       # Kubernetes Networking & Services
│   ├── day05.md                       # Storage, Security & RBAC
│   ├── day06.md                       # Helm, Templating & Design Patterns
│   ├── day07.md                       # Observability, Debugging & Production Synthesis
│   └── appendix-eks.md               # Optional EKS production appendix
├── labs/
│   ├── shared/                        # OrderFlow microservice source code
│   │   ├── order-api/
│   │   │   ├── main.go               # Go REST API (~100 lines)
│   │   │   ├── go.mod
│   │   │   ├── Dockerfile            # production-grade multi-stage
│   │   │   └── Dockerfile.bad        # deliberately bad (Day 1 exercise)
│   │   ├── payment-service/
│   │   │   ├── main.go
│   │   │   ├── go.mod
│   │   │   └── Dockerfile
│   │   └── notification-service/
│   │       ├── main.go
│   │       ├── go.mod
│   │       └── Dockerfile
│   ├── day01/
│   │   ├── README.md                 # lab instructions + "break it" exercises
│   │   └── SOLUTION.md              # full solutions with explanations
│   ├── day02/
│   │   ├── README.md
│   │   ├── SOLUTION.md
│   │   ├── docker-compose.yml
│   │   ├── docker-compose.override.yml
│   │   └── .env.example
│   ├── day03/
│   │   ├── README.md
│   │   ├── SOLUTION.md
│   │   └── manifests/
│   │       ├── namespace.yaml
│   │       ├── configmap.yaml
│   │       ├── secret.yaml
│   │       ├── order-api.yaml
│   │       ├── payment-service.yaml
│   │       └── notification-service.yaml
│   ├── day04/
│   │   ├── README.md
│   │   ├── SOLUTION.md
│   │   └── manifests/
│   │       ├── ingress.yaml
│   │       ├── networkpolicy.yaml
│   │       └── headless-service.yaml
│   ├── day05/
│   │   ├── README.md
│   │   ├── SOLUTION.md
│   │   └── manifests/
│   │       ├── postgres-statefulset.yaml
│   │       ├── pvc.yaml
│   │       ├── rbac.yaml
│   │       └── security-context.yaml
│   ├── day06/
│   │   ├── README.md
│   │   ├── SOLUTION.md
│   │   └── orderflow-chart/
│   │       ├── Chart.yaml
│   │       ├── values.yaml
│   │       ├── values-dev.yaml
│   │       ├── values-production.yaml
│   │       └── templates/
│   │           ├── _helpers.tpl
│   │           ├── deployment.yaml
│   │           ├── service.yaml
│   │           ├── ingress.yaml
│   │           ├── hpa.yaml
│   │           ├── pdb.yaml
│   │           ├── configmap.yaml
│   │           └── init-migration.yaml
│   └── day07/
│       ├── README.md
│       ├── SOLUTION.md
│       ├── debug-runbook.md
│       └── manifests/
│           ├── metrics-server.yaml
│           └── chaos-scenarios.yaml
└── docs/superpowers/
    ├── specs/
    │   └── 2026-10-06-k8s-docker-mastery-design.md
    └── plans/
```

---

## Content Day Skeleton

```markdown
# Day N — <Title>

## Why this matters
<1 paragraph — concrete, specific, tied to microservices/API gateway world>

## The layer this covers
<Where this sits in the stack: kernel → Docker → K8s object → design pattern>

## Core concepts

### <Concept 1>

**Problem:** <what problem this concept solves>

**How it works:** <mechanics>

**Practical implications:** <what this means for your daily work>

**When it's wrong:** <scenarios where this is the wrong choice>

### <Concept 2>
...

## Decision tree
<When to use what — flowchart or table>

## Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
2. ...

## Anti-patterns / Common mistakes
- **<Pattern name>:** <why it fails>
- ...

## Lab
See `labs/dayNN/`. The goal: <one line>. Success signal: <one line>.

## Key commands reference
| Command | What it does |
|---|---|
| `<cmd>` | <description> |

## Teardown
<checklist for cleaning up lab resources>
```

---

## Glossary Scope

~80+ terms organized by domain:

- **Container runtime:** OCI, containerd, runc, CRI, image spec, runtime spec
- **Linux primitives:** namespace (pid, net, mnt, uts, ipc, user), cgroup, OverlayFS, veth, bridge
- **Image/build:** layer, manifest, registry, tag, digest, multi-stage build, build context, .dockerignore
- **Docker networking:** bridge network, docker0, embedded DNS, port mapping, overlay, VXLAN
- **Docker storage:** named volume, bind mount, tmpfs, volume driver
- **Docker Compose:** service, profile, override file, build context, healthcheck
- **K8s architecture:** control plane, API server, etcd, scheduler, controller-manager, kubelet, kube-proxy
- **K8s workloads:** Pod, ReplicaSet, Deployment, DaemonSet, StatefulSet, Job, CronJob
- **K8s config:** ConfigMap, Secret, environment variable, volume mount
- **K8s networking:** Service (ClusterIP, NodePort, LoadBalancer, ExternalName), Endpoints, EndpointSlice, Ingress, IngressClass, CNI, CoreDNS, NetworkPolicy, Gateway API
- **K8s storage:** PersistentVolume, PersistentVolumeClaim, StorageClass, CSI, access modes (RWO, ROX, RWX), reclaim policy
- **K8s security:** RBAC, Role, ClusterRole, RoleBinding, ClusterRoleBinding, ServiceAccount, SecurityContext, Pod Security Admission, Pod Security Standards, seccomp
- **K8s patterns:** sidecar, init container, ambassador, adapter
- **K8s operations:** liveness probe, readiness probe, startup probe, HPA, VPA, PDB, graceful shutdown, preStop hook, terminationGracePeriodSeconds
- **K8s debugging:** CrashLoopBackOff, ImagePullBackOff, OOMKilled, Pending, Evicted, CreateContainerConfigError
- **Ecosystem:** Helm, Kustomize, ArgoCD, Flux, GitOps, metrics-server, Prometheus, EFK, Loki
- **EKS-specific:** managed node group, Fargate profile, IRSA, AWS Load Balancer Controller, EBS CSI Driver

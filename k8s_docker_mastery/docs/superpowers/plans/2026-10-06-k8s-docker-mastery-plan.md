# Docker & Kubernetes Mastery — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a 7-day learning path with content files, labs, Go microservice source code, K8s manifests, Helm charts, and supporting docs for mastering Docker & Kubernetes.

**Architecture:** Content-first authoring — shared microservice source code first, then day files paired with their labs in chronological order. Each task produces the files for one day (or a logical group), including content, lab README, SOLUTION, and all manifests/configs.

**Tech Stack:** Markdown (content), Go (OrderFlow microservices), Docker/Compose YAML, Kubernetes YAML manifests, Helm chart templates

**Spec:** `k8s_docker_mastery/docs/superpowers/specs/2026-10-06-k8s-docker-mastery-design.md`

## Global Constraints

- No real secrets, keys, tokens, or account IDs in any file — use placeholders with fill-in comments
- No git commands in subagent dispatches
- No running real infrastructure during authoring — labs are written, not executed
- Every exercise must ship with hints + solution sketches
- Every lab must ship with README.md + SOLUTION.md
- OrderFlow services are minimal Go (~100-150 lines each) using only stdlib `net/http`
- All labs are local-first (Docker Desktop / kind) — EKS is optional appendix only
- Content follows the day skeleton from the spec: Why this matters → The layer this covers → Core concepts → Decision tree → Exercises → Anti-patterns → Lab → Key commands → Teardown

## Review Focus

1. **Exercise completeness:** Every exercise must have hint + solution sketch — a bare problem with no guidance is the #1 quality failure in learning paths
2. **K8s manifest correctness:** YAML indentation, apiVersion accuracy (apps/v1, networking.k8s.io/v1), label selector consistency between Deployment and Service
3. **Go code compilability:** Each Go service must be syntactically valid with correct imports — `go vet` would pass if run
4. **Helm template syntax:** Go template delimiters `{{ }}`, correct `.Values` paths matching `values.yaml` keys, `_helpers.tpl` references matching template names
5. **Lab continuity:** Each day's lab builds on the previous — Day 3 manifests must reference the same image names from Day 1 Dockerfiles, Day 6 Helm chart must produce equivalent resources to Day 3-5 raw manifests

---

### Task 1: Shared OrderFlow Microservices + Project Scaffolding

**Files:**
- Create: `k8s_docker_mastery/README.md`
- Create: `k8s_docker_mastery/STRATEGY.md`
- Create: `k8s_docker_mastery/labs/shared/order-api/main.go`
- Create: `k8s_docker_mastery/labs/shared/order-api/go.mod`
- Create: `k8s_docker_mastery/labs/shared/order-api/Dockerfile`
- Create: `k8s_docker_mastery/labs/shared/order-api/Dockerfile.bad`
- Create: `k8s_docker_mastery/labs/shared/payment-service/main.go`
- Create: `k8s_docker_mastery/labs/shared/payment-service/go.mod`
- Create: `k8s_docker_mastery/labs/shared/payment-service/Dockerfile`
- Create: `k8s_docker_mastery/labs/shared/notification-service/main.go`
- Create: `k8s_docker_mastery/labs/shared/notification-service/go.mod`
- Create: `k8s_docker_mastery/labs/shared/notification-service/Dockerfile`

**Interfaces:**
- Produces: Three Go microservices used by all subsequent tasks. `order-api` listens on `:8080` with endpoints `GET /health`, `POST /orders`, `GET /orders`. `payment-service` listens on `:8081` with `GET /health`, `POST /payments`. `notification-service` listens on `:8082` with `GET /health`, `POST /notify`. All use stdlib `net/http` only.
- Produces: `README.md` with prerequisites, day index table, usage instructions.
- Produces: `STRATEGY.md` with the top 1% strategy, pattern loop, 80% traps, top 1% differentiators (from spec Strategy section).
- Produces: `Dockerfile.bad` for order-api — deliberately uses `golang:latest` as final image, runs as root, copies everything before `go mod download`, no `.dockerignore`, includes build tools in final image. Used in Day 1 lab.
- Produces: Production `Dockerfile` for each service — multi-stage (builder + scratch/distroless), non-root USER, `HEALTHCHECK`, `.dockerignore` implied.

- [ ] **Step 1: Create `README.md`**

Write the project README following the pattern in `aws_system_integrations/README.md`: title, description, prerequisites (Docker Desktop, kubectl, Helm, Go 1.21+, kind optional), how to use this path, day index table (7 days with theme and key topics), cost note (all local, EKS appendix optional).

- [ ] **Step 2: Create `STRATEGY.md`**

Write the strategy document from the spec's "Strategy" section: core mental model (Docker = namespaces + cgroups + OverlayFS; K8s = reconciliation loop), pattern loop (6 steps), "what the 80% waste time on" table, "what the top 1% do differently" list. Include the Container Orchestration Decision Framework summary (when K8s vs ECS/Fargate — full framework is in Day 7 content).

- [ ] **Step 3: Create `order-api` Go service**

`main.go` (~120 lines): In-memory order store (slice + mutex). Endpoints: `GET /health` → `{"status":"ok"}`, `POST /orders` (JSON body: `{"item":"x","qty":1}`) → creates order with UUID, returns 201, `GET /orders` → returns all orders. `GET /orders/{id}` → returns single order. Graceful shutdown on SIGTERM. Config from env vars: `PORT`, `PAYMENT_SERVICE_URL`, `NOTIFICATION_SERVICE_URL`. On `POST /orders`, call payment-service and notification-service (fire-and-forget HTTP POST, log errors but don't block). `go.mod` with module `orderflow/order-api`, Go 1.21.

- [ ] **Step 4: Create `payment-service` Go service**

`main.go` (~80 lines): `GET /health` → `{"status":"ok"}`, `POST /payments` (JSON body: `{"order_id":"x","amount":10.0}`) → logs payment, returns 200 with `{"status":"processed","order_id":"x"}`. Graceful shutdown. Config from env: `PORT`. `go.mod` with module `orderflow/payment-service`, Go 1.21.

- [ ] **Step 5: Create `notification-service` Go service**

`main.go` (~80 lines): `GET /health` → `{"status":"ok"}`, `POST /notify` (JSON body: `{"order_id":"x","message":"Order created"}`) → logs notification, returns 200 with `{"status":"sent","order_id":"x"}`. Graceful shutdown. Config from env: `PORT`. `go.mod` with module `orderflow/notification-service`, Go 1.21.

- [ ] **Step 6: Create Dockerfiles**

For each service, create a production-grade multi-stage `Dockerfile`:
- Stage 1 (`builder`): `golang:1.21-alpine`, `WORKDIR /app`, copy `go.mod` first → `go mod download` → copy source → `CGO_ENABLED=0 go build -o /app/server .`
- Stage 2: `gcr.io/distroless/static-debian12`, copy binary, `EXPOSE` port, non-root `USER nonroot:nonroot`, `HEALTHCHECK` using the binary (or skip for distroless — note this in comments), `ENTRYPOINT ["/app/server"]`

Create `Dockerfile.bad` for order-api only: `FROM golang:latest`, `COPY . .` before `go mod download`, `RUN go build`, no multi-stage, runs as root, no HEALTHCHECK — each bad practice marked with a comment explaining what's wrong (the learner discovers these in Day 1).

- [ ] **Step 7: Verify file structure**

Run: `find k8s_docker_mastery -type f | sort`
Expected: All 12 files listed in the Files section above, plus the spec file.

---

### Task 2: Day 1 — Docker Internals & Image Mastery (Content + Lab)

**Files:**
- Create: `k8s_docker_mastery/content/day01.md`
- Create: `k8s_docker_mastery/labs/day01/README.md`
- Create: `k8s_docker_mastery/labs/day01/SOLUTION.md`

**Interfaces:**
- Consumes: `labs/shared/order-api/Dockerfile`, `labs/shared/order-api/Dockerfile.bad` from Task 1
- Produces: Day 1 content covering Linux primitives (namespaces, cgroups, OverlayFS), Dockerfile instruction semantics, production image patterns. Lab uses order-api's bad vs good Dockerfile.

- [ ] **Step 1: Write `content/day01.md`**

Follow the day skeleton from spec. Sections:
- **Why this matters:** Connect to the learner's microservices world — every container they run in ECS/K8s is these primitives.
- **The layer this covers:** Kernel → Docker Engine → container. Diagram: userspace process → Docker Engine → containerd → runc → kernel (namespaces + cgroups + OverlayFS).
- **Core concepts:** (a) Namespaces — pid, net, mnt, uts, ipc, user — what each isolates, with one-line examples. (b) Cgroups v2 — cpu.max, memory.max, how `docker run --memory` maps. (c) OverlayFS — lowerdir (image layers), upperdir (container layer), workdir, merged view. How `docker commit` snapshots upperdir. (d) Container runtime hierarchy — Docker Engine → containerd → runc → kernel. OCI image and runtime specs. (e) Dockerfile instructions — RUN (layer creation), CMD vs ENTRYPOINT (exec vs shell form — the trap), COPY vs ADD, ARG vs ENV (build-time vs runtime), layer model and cache invalidation rules (any change invalidates all subsequent layers), `.dockerignore`, build context size. (f) Production patterns — multi-stage builds (why: separate build tools from runtime), base image selection (scratch vs alpine vs distroless — trade-offs table), layer ordering for cache (copy go.mod first → download → copy source), non-root USER, HEALTHCHECK, security scanning with trivy.
- **Decision tree:** Choosing base image (scratch for static Go binaries, distroless for minimal libc, alpine for debugging shell, debian-slim for broad compatibility).
- **Exercises:** 3 exercises with hints + solution sketches: (1) Analyze Dockerfile.bad — list all anti-patterns. (2) Calculate image size difference between bad and good Dockerfile. (3) Explain what happens kernel-side when `docker run --memory=10m` is set and the process exceeds it.
- **Anti-patterns:** Fat images, root user, missing .dockerignore, cache invalidation by early COPY, secrets in layers.
- **Lab pointer:** See `labs/day01/`.
- **Key commands reference:** Table with `docker build`, `docker history`, `docker inspect`, `docker run --memory`, `docker exec`, `dive` (third-party layer inspector).

- [ ] **Step 2: Write `labs/day01/README.md`**

Lab instructions:
1. Build order-api with `Dockerfile.bad` → note image size with `docker images`
2. Analyze layers with `docker history` and optionally `dive`
3. Identify each anti-pattern (5 listed, learner discovers)
4. Build with production `Dockerfile` → compare size
5. **Break it:** Run with `docker run --memory=10m` → trigger OOMKill → check exit code 137
6. **Break it:** Run without `--memory` flag, exec into container, inspect `/proc/self/cgroup`
7. Inspect namespaces: `docker inspect --format '{{.State.Pid}}'` → `ls -la /proc/<PID>/ns/`
8. **Success signal:** Production image < 20MB for a Go binary; OOMKill observed with exit 137; can list namespace types for a running container.

- [ ] **Step 3: Write `labs/day01/SOLUTION.md`**

Full solutions for each lab step with expected output, explanations of why each anti-pattern matters, and the exact size comparison numbers (bad: ~1GB, good: ~10-15MB).

- [ ] **Step 4: Verify exercise completeness**

Run: `grep -c "Hint:" k8s_docker_mastery/content/day01.md && grep -c "Solution sketch:" k8s_docker_mastery/content/day01.md`
Expected: Both counts ≥ 3 (matching number of exercises).

---

### Task 3: Day 2 — Docker Networking, Volumes & Compose (Content + Lab)

**Files:**
- Create: `k8s_docker_mastery/content/day02.md`
- Create: `k8s_docker_mastery/labs/day02/README.md`
- Create: `k8s_docker_mastery/labs/day02/SOLUTION.md`
- Create: `k8s_docker_mastery/labs/day02/docker-compose.yml`
- Create: `k8s_docker_mastery/labs/day02/docker-compose.override.yml`
- Create: `k8s_docker_mastery/labs/day02/.env.example`

**Interfaces:**
- Consumes: All three services' Dockerfiles from Task 1
- Produces: Day 2 content covering Docker networking, volumes, Compose. Compose stack wiring all 3 services + Postgres. Used conceptually by Day 3+ as the "local dev" baseline that K8s replaces.

- [ ] **Step 1: Write `content/day02.md`**

Follow day skeleton. Sections:
- **Why this matters:** Microservices need to talk — understanding Docker networking is the foundation for understanding K8s networking.
- **The layer this covers:** Docker Engine networking subsystem → Linux bridge, veth, iptables.
- **Core concepts:** (a) Bridge networks — docker0 default bridge, user-defined bridges (DNS resolution only works on user-defined), veth pairs connecting container netns to bridge. (b) Docker DNS — embedded server at 127.0.0.11, container name → IP resolution on user-defined networks. (c) Port mapping — iptables DNAT from host:port to container:port, `docker port` inspection. (d) Network modes — bridge (default), host (shares host netns), none (no networking), container (shares another container's netns). (e) Overlay networks — VXLAN encapsulation concept for multi-host (Swarm/K8s preview). (f) Volumes — named volumes (Docker manages location, survives container removal), bind mounts (host path → container path, for dev), tmpfs (in-memory, for secrets/temp). Volume lifecycle, `docker volume inspect`, uid/gid ownership issues. (g) Compose — service definitions, `build:` context, `depends_on` with `condition: service_healthy`, healthchecks in Compose, profiles, env_file, `.env` auto-load, override files (`docker-compose.override.yml` auto-loaded), Compose networking (default network named `<project>_default`, custom networks, aliases), `docker compose watch`.
- **Exercises:** 3 exercises with hints + solutions: (1) Two containers on different user-defined networks — can they ping each other? Why? (2) What happens to data in a Postgres container if you `docker rm` it without a named volume? (3) Explain the DNS resolution path when service-A calls `http://service-b:8080` in a Compose stack.
- **Anti-patterns:** Using `links` (deprecated), `depends_on` without health condition, bind-mounting node_modules, hardcoded IPs, no volume for DB data.
- **Lab pointer + Key commands.**

- [ ] **Step 2: Write `docker-compose.yml`**

Compose file wiring:
- `order-api`: build context `../shared/order-api`, port `8080:8080`, env vars for service URLs (`PAYMENT_SERVICE_URL=http://payment-service:8081`, `NOTIFICATION_SERVICE_URL=http://notification-service:8082`), healthcheck (`curl -f http://localhost:8080/health`), depends_on payment-service and notification-service (condition: service_healthy), network: `orderflow-net`
- `payment-service`: build context `../shared/payment-service`, port `8081:8081`, healthcheck, network: `orderflow-net`
- `notification-service`: build context `../shared/notification-service`, port `8082:8082`, healthcheck, network: `orderflow-net`
- `postgres`: image `postgres:16-alpine`, volume `pgdata:/var/lib/postgresql/data`, env from `.env.example` (POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB as placeholders), healthcheck (`pg_isready`), network: `orderflow-net`
- Named volume `pgdata`, custom network `orderflow-net` (bridge driver)

- [ ] **Step 3: Write `docker-compose.override.yml`**

Dev overrides: bind-mount source code for hot reload, expose debug ports, set `LOG_LEVEL=debug`.

- [ ] **Step 4: Write `.env.example`**

```
POSTGRES_USER=orderflow
POSTGRES_PASSWORD=changeme_local_only
POSTGRES_DB=orderflow
```

- [ ] **Step 5: Write `labs/day02/README.md`**

Lab instructions: (1) `docker compose up --build`, (2) test with `curl localhost:8080/orders`, (3) verify DNS: `docker compose exec order-api nslookup payment-service`, (4) **Break it:** rename a service in compose → observe DNS failure, (5) **Break it:** remove pgdata volume → restart → data lost, (6) inspect bridge network: `docker network inspect`, (7) **Success signal:** All 4 services healthy, curl returns orders, DNS resolution works between services.

- [ ] **Step 6: Write `labs/day02/SOLUTION.md`**

Full solutions with expected output for each step.

- [ ] **Step 7: Verify**

Run: `grep -c "Hint:" k8s_docker_mastery/content/day02.md && grep -c "Solution sketch:" k8s_docker_mastery/content/day02.md`
Expected: Both ≥ 3.

---

### Task 4: Day 3 — Kubernetes Core Objects (Content + Lab)

**Files:**
- Create: `k8s_docker_mastery/content/day03.md`
- Create: `k8s_docker_mastery/labs/day03/README.md`
- Create: `k8s_docker_mastery/labs/day03/SOLUTION.md`
- Create: `k8s_docker_mastery/labs/day03/manifests/namespace.yaml`
- Create: `k8s_docker_mastery/labs/day03/manifests/configmap.yaml`
- Create: `k8s_docker_mastery/labs/day03/manifests/secret.yaml`
- Create: `k8s_docker_mastery/labs/day03/manifests/order-api.yaml`
- Create: `k8s_docker_mastery/labs/day03/manifests/payment-service.yaml`
- Create: `k8s_docker_mastery/labs/day03/manifests/notification-service.yaml`

**Interfaces:**
- Consumes: Docker images built from Task 1 Dockerfiles (referenced as `orderflow/order-api:v1`, `orderflow/payment-service:v1`, `orderflow/notification-service:v1`)
- Produces: K8s namespace `orderflow`, ConfigMap with service URLs, Secret with DB credentials (base64 placeholder), Deployments + ClusterIP Services for all 3 services. These manifests are the foundation that Day 4-5 extend.

- [ ] **Step 1: Write `content/day03.md`**

Follow day skeleton. Sections:
- **Why this matters:** K8s is what runs your microservices in production — understanding the object model is how you stop cargo-culting YAML.
- **The layer this covers:** K8s control plane → API server → controllers → kubelet → container runtime.
- **Core concepts:** (a) Architecture — control plane (API server: the only entry point, all CRUD through it; etcd: single source of truth, never access directly; scheduler: bin-packing pods to nodes based on resource requests; controller-manager: runs all built-in controllers). Data plane (kubelet: node agent, watches API server for pod assignments, talks to container runtime; kube-proxy: maintains iptables/IPVS rules for Services; container runtime: containerd via CRI). The watch loop explained: controller watches API server → detects drift → reconciles. (b) Pod — why not just a container? → shared network namespace (localhost between containers), shared volumes, co-scheduling guarantee. Pod lifecycle (Pending → Running → Succeeded/Failed). Pod spec: containers, volumes, restartPolicy. (c) ReplicaSet — why not just pods? → desired count, self-healing (pod dies → RS creates replacement), label selectors. (d) Deployment — why not just ReplicaSets? → rolling update strategy (maxSurge, maxUnavailable), revision history, rollback capability. Deployment → creates RS → RS creates Pods. (e) Labels & selectors — how controllers find their objects. matchLabels in deployment.spec.selector must match template.metadata.labels. Service selector matches pod labels. (f) ConfigMap — non-sensitive config as key-value pairs or files. Mount as env vars or volume. (g) Secret — base64 encoding ≠ encryption. Encryption at rest (EncryptionConfiguration). Mount as env vars (visible in describe!) vs volume (file permissions, hot-reload).
- **Decision tree:** When to use ConfigMap vs Secret vs hardcoded. When to mount as env vs volume.
- **Exercises:** 3 exercises with hints + solutions: (1) A Deployment has `replicas: 3` but only 2 pods are Running — what do you check first? (2) You change a ConfigMap but pods don't pick up the change — why? (3) Draw the ownership chain: Deployment → ReplicaSet → Pod. What happens when you delete the Deployment?
- **Anti-patterns:** Config in images, naked pods, `kubectl run` for production, no resource requests/limits, default namespace.

- [ ] **Step 2: Write K8s manifests**

All manifests use `apiVersion` appropriate for their kind:
- `namespace.yaml`: Namespace `orderflow`
- `configmap.yaml`: ConfigMap `orderflow-config` in namespace `orderflow` with keys: `PAYMENT_SERVICE_URL: "http://payment-service:8081"`, `NOTIFICATION_SERVICE_URL: "http://notification-service:8082"`
- `secret.yaml`: Secret `orderflow-secrets` with `POSTGRES_PASSWORD: <base64-of-changeme_local_only>` and comment to replace
- `order-api.yaml`: Deployment (replicas: 2, image: `orderflow/order-api:v1`, container port 8080, envFrom configmap + secret, resources requests cpu:100m memory:64Mi limits cpu:200m memory:128Mi) + ClusterIP Service (port 8080, selector matching deployment labels)
- `payment-service.yaml`: Deployment (replicas: 2, image: `orderflow/payment-service:v1`, port 8081, resources) + ClusterIP Service (port 8081)
- `notification-service.yaml`: Deployment (replicas: 1, image: `orderflow/notification-service:v1`, port 8082, resources) + ClusterIP Service (port 8082)

All deployments use labels: `app: <service-name>`, `part-of: orderflow`. Selector matchLabels matches template labels.

- [ ] **Step 3: Write `labs/day03/README.md`**

Lab instructions: (1) Build and load images: `docker build -t orderflow/order-api:v1 labs/shared/order-api/`, (2) Apply manifests in order: namespace → configmap → secret → services, (3) Verify: `kubectl get all -n orderflow`, (4) Test: `kubectl port-forward svc/order-api 8080:8080 -n orderflow` → `curl localhost:8080/health`, (5) Scale: `kubectl scale deployment order-api --replicas=5 -n orderflow`, (6) Rolling update: change image tag to `v2` (nonexistent) → observe failed rollout → `kubectl rollout undo`, (7) **Break it:** Delete a pod → watch RS recreate, (8) **Break it:** Change label selector to mismatch → orphaned pods, (9) **Success signal:** 3 deployments running, port-forward works, rollback succeeds.

- [ ] **Step 4: Write `labs/day03/SOLUTION.md`**

Full solutions with expected kubectl output for each step.

- [ ] **Step 5: Verify**

Run: `grep -c "Hint:" k8s_docker_mastery/content/day03.md && grep -c "Solution sketch:" k8s_docker_mastery/content/day03.md`
Expected: Both ≥ 3.

---

### Task 5: Day 4 — Kubernetes Networking & Services (Content + Lab)

**Files:**
- Create: `k8s_docker_mastery/content/day04.md`
- Create: `k8s_docker_mastery/labs/day04/README.md`
- Create: `k8s_docker_mastery/labs/day04/SOLUTION.md`
- Create: `k8s_docker_mastery/labs/day04/manifests/ingress.yaml`
- Create: `k8s_docker_mastery/labs/day04/manifests/networkpolicy.yaml`
- Create: `k8s_docker_mastery/labs/day04/manifests/headless-service.yaml`

**Interfaces:**
- Consumes: Deployments and Services from Task 4 (Day 3 manifests already applied)
- Produces: Ingress resource routing `/api/orders` → order-api Service. NetworkPolicy restricting payment-service ingress. Headless service example for direct pod DNS.

- [ ] **Step 1: Write `content/day04.md`**

Follow day skeleton. Sections:
- **Why this matters:** Networking is where 60%+ of production K8s issues live — if you understand this layer, you can debug almost anything.
- **The layer this covers:** Pod network (CNI) → Service (kube-proxy/iptables) → Ingress (L7 controller) → external.
- **Core concepts:** (a) Pod networking model — K8s requirements (every pod routable IP, no NAT between pods), CNI interface (plugin installs, configures pod networking), pause container (holds the network namespace, other containers join it). Popular CNIs: Calico (BGP, NetworkPolicy), Cilium (eBPF, advanced policy), Flannel (simple overlay). (b) Service deep-dive — ClusterIP: virtual IP, kube-proxy watches API server, creates iptables DNAT rules mapping VIP:port → pod endpoints. How endpoint selection works (pod must be Ready + match selector). Explain with iptables chain walkthrough. NodePort: ClusterIP + `<nodeIP>:<nodePort>` on every node. LoadBalancer: NodePort + cloud provider provisions external LB. ExternalName: CNAME record, no proxying. Headless (clusterIP: None): DNS returns pod IPs directly, no load balancing — used by StatefulSets for stable DNS per pod. EndpointSlices (scalability improvement over Endpoints). Service DNS: `<svc>.<ns>.svc.cluster.local`, search domains, ndots:5 default and why it causes excessive DNS lookups. (c) Ingress — Ingress resource = config (host rules, path rules, TLS), Ingress Controller = implementation (nginx-ingress, traefik, etc.). L7 routing: path-based (`/api/orders` → order-api), host-based (`api.example.com` → order-api). TLS termination with Secret of type `kubernetes.io/tls`. IngressClass for multi-controller. Gateway API as the successor (brief). (d) NetworkPolicies — default: all traffic allowed (flat network). Deny-all baseline: empty ingress/egress rules. Explicit allow: podSelector, namespaceSelector, ipBlock. Ingress vs egress policies. Note: CNI must support NetworkPolicy (Calico, Cilium do; Flannel does not by default).
- **Exercises:** 3 exercises with hints + solutions: (1) A Service has no endpoints — what are the 3 most common causes? (2) Trace the full iptables path for a request from pod-A to ClusterIP service-B. (3) You set a deny-all NetworkPolicy but pods can still reach the internet — why?
- **Anti-patterns:** NodePort in production, hardcoded pod IPs, no NetworkPolicies, not understanding ClusterIP is iptables, DNS caching issues with ndots:5.

- [ ] **Step 2: Write K8s manifests**

- `ingress.yaml`: Ingress resource, `ingressClassName: nginx`, rules: host `orderflow.local`, paths: `/api/orders` → order-api service port 8080, `/api/payments` → payment-service port 8081. TLS commented out with instructions.
- `networkpolicy.yaml`: (a) Default deny-all for namespace `orderflow`. (b) Allow ingress to payment-service only from pods with label `app: order-api` in namespace `orderflow`. (c) Allow ingress to order-api from any (Ingress controller).
- `headless-service.yaml`: Headless service for payment-service (`clusterIP: None`) — demonstrates direct pod DNS resolution. Commented with explanation of when to use (StatefulSets, client-side load balancing).

- [ ] **Step 3: Write `labs/day04/README.md`**

Lab instructions: (1) Install nginx-ingress controller: `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml`, (2) Apply ingress manifest, (3) Test: `curl -H "Host: orderflow.local" http://localhost/api/orders`, (4) Apply NetworkPolicies, (5) Test isolation: exec into notification-service pod → try to curl payment-service → should fail, (6) Exec into order-api pod → curl payment-service → should succeed, (7) **Break it:** Change Service selector to mismatch → `kubectl describe endpoints` shows empty, (8) **Break it:** Remove NetworkPolicy → show unrestricted access, (9) Apply headless service → `nslookup payment-service-headless.orderflow.svc.cluster.local` → see pod IPs directly, (10) **Success signal:** Ingress routes correctly, NetworkPolicy blocks unauthorized traffic, headless service returns pod IPs.

- [ ] **Step 4: Write `labs/day04/SOLUTION.md`**

Full solutions with expected output.

- [ ] **Step 5: Verify**

Run: `grep -c "Hint:" k8s_docker_mastery/content/day04.md && grep -c "Solution sketch:" k8s_docker_mastery/content/day04.md`
Expected: Both ≥ 3.

---

### Task 6: Day 5 — Storage, Security & RBAC (Content + Lab)

**Files:**
- Create: `k8s_docker_mastery/content/day05.md`
- Create: `k8s_docker_mastery/labs/day05/README.md`
- Create: `k8s_docker_mastery/labs/day05/SOLUTION.md`
- Create: `k8s_docker_mastery/labs/day05/manifests/postgres-statefulset.yaml`
- Create: `k8s_docker_mastery/labs/day05/manifests/pvc.yaml`
- Create: `k8s_docker_mastery/labs/day05/manifests/rbac.yaml`
- Create: `k8s_docker_mastery/labs/day05/manifests/security-context.yaml`

**Interfaces:**
- Consumes: Namespace and Deployments from Task 4 (Day 3)
- Produces: Postgres StatefulSet with PVC, RBAC roles for order-api ServiceAccount, SecurityContext-hardened pod spec. These patterns are packaged into Helm in Task 7 (Day 6).

- [ ] **Step 1: Write `content/day05.md`**

Follow day skeleton. Sections:
- **Why this matters:** Security and storage are the production-readiness layer that most engineers skip — and then get paged at 3am for.
- **The layer this covers:** K8s storage subsystem (PV/PVC/StorageClass/CSI) + K8s security model (RBAC + SecurityContext + PSA).
- **Core concepts:** (a) Storage model — PersistentVolume (cluster resource, provisioned by admin or dynamically), PersistentVolumeClaim (namespace resource, user's request), StorageClass (template for dynamic provisioning, defines provisioner + parameters). Access modes: RWO (one node read-write), ROX (many nodes read-only), RWX (many nodes read-write). Reclaim policies: Retain (PV kept after PVC deleted), Delete (PV deleted with PVC). Volume lifecycle: provisioning → binding → using → releasing → reclaiming. CSI (Container Storage Interface) — standardized plugin model. (b) StatefulSets — why Deployments aren't enough: stable network identity (`pod-0.svc`), stable per-pod storage (`volumeClaimTemplates`), ordered startup/shutdown. Paired with headless service for DNS. When StatefulSet vs Deployment + external DB (managed RDS etc.). (c) SecurityContext — pod-level and container-level. `runAsNonRoot: true`, `runAsUser: 1000`, `readOnlyRootFilesystem: true` (use emptyDir for /tmp), `allowPrivilegeEscalation: false`, `capabilities: {drop: [ALL]}` (add back only what's needed). `seccompProfile: {type: RuntimeDefault}`. (d) Pod Security Admission (PSA) — namespace labels: `pod-security.kubernetes.io/enforce: restricted`, three levels: Privileged (no restrictions), Baseline (prevent known escalations), Restricted (heavily locked down). (e) RBAC — four objects: Role (namespace-scoped permissions), ClusterRole (cluster-scoped), RoleBinding (binds role to subject in namespace), ClusterRoleBinding (cluster-wide). Subjects: User, Group, ServiceAccount. ServiceAccounts: every pod gets one, `automountServiceAccountToken: false` unless needed. Default SA dangers. `kubectl auth can-i` for testing. Principle of least privilege.
- **Decision tree:** When StatefulSet vs Deployment. When to use Role vs ClusterRole. Which PSA level for which workload type.
- **Exercises:** 3 exercises with hints + solutions: (1) A PVC is stuck in Pending — what are the 3 most likely causes? (2) Your pod needs to write temp files but you set readOnlyRootFilesystem — how do you fix it without removing the restriction? (3) A ServiceAccount can list secrets in all namespaces — is this a Role or ClusterRole binding? What's the risk?
- **Anti-patterns:** Root containers, default SA, secrets as env vars, wildcard RBAC, Delete reclaim on production data, no PDB.

- [ ] **Step 2: Write K8s manifests**

- `postgres-statefulset.yaml`: StatefulSet `postgres` in namespace `orderflow`, replicas: 1, image: `postgres:16-alpine`, `volumeClaimTemplates` with 1Gi storage (RWO), env from Secret (POSTGRES_PASSWORD), container port 5432, SecurityContext (runAsNonRoot, runAsUser 999 for postgres). Paired headless service `postgres-headless`. Readiness probe: `pg_isready`.
- `pvc.yaml`: Standalone PVC example (for documentation) showing manual provisioning with a StorageClass reference. Commented annotations explaining each field.
- `rbac.yaml`: (a) ServiceAccount `order-api-sa` in namespace `orderflow`. (b) Role `order-api-role` — allows: get/list configmaps, get secrets (specific names only). (c) RoleBinding binding the role to the SA. (d) Comments showing what a bad wildcard RBAC looks like for contrast.
- `security-context.yaml`: Updated order-api Deployment spec with full SecurityContext: `runAsNonRoot: true`, `runAsUser: 1000`, `readOnlyRootFilesystem: true`, `allowPrivilegeEscalation: false`, `capabilities: {drop: [ALL]}`, `seccompProfile: {type: RuntimeDefault}`. EmptyDir volume mounted at `/tmp`. PSA namespace label: `pod-security.kubernetes.io/enforce: restricted`.

- [ ] **Step 3: Write `labs/day05/README.md`**

Lab instructions: (1) Apply Postgres StatefulSet, (2) Verify PVC bound: `kubectl get pvc -n orderflow`, (3) Insert data into Postgres, (4) Delete pod → observe StatefulSet recreates with same PVC → data survives, (5) Apply security-context.yaml to order-api, (6) **Break it:** Try to write file in container with readOnlyRootFilesystem → Permission denied, (7) Fix with emptyDir at /tmp, (8) Apply RBAC, (9) Test: `kubectl auth can-i list configmaps -n orderflow --as=system:serviceaccount:orderflow:order-api-sa` → yes, (10) Test: `kubectl auth can-i delete pods -n orderflow --as=system:serviceaccount:orderflow:order-api-sa` → no, (11) **Success signal:** Postgres data persists across pod restarts, order-api runs as non-root with read-only FS, RBAC correctly scoped.

- [ ] **Step 4: Write `labs/day05/SOLUTION.md`**

Full solutions with expected output.

- [ ] **Step 5: Verify**

Run: `grep -c "Hint:" k8s_docker_mastery/content/day05.md && grep -c "Solution sketch:" k8s_docker_mastery/content/day05.md`
Expected: Both ≥ 3.

---

### Task 7: Day 6 — Helm, Templating & Design Patterns (Content + Lab)

**Files:**
- Create: `k8s_docker_mastery/content/day06.md`
- Create: `k8s_docker_mastery/labs/day06/README.md`
- Create: `k8s_docker_mastery/labs/day06/SOLUTION.md`
- Create: `k8s_docker_mastery/labs/day06/orderflow-chart/Chart.yaml`
- Create: `k8s_docker_mastery/labs/day06/orderflow-chart/values.yaml`
- Create: `k8s_docker_mastery/labs/day06/orderflow-chart/values-dev.yaml`
- Create: `k8s_docker_mastery/labs/day06/orderflow-chart/values-production.yaml`
- Create: `k8s_docker_mastery/labs/day06/orderflow-chart/templates/_helpers.tpl`
- Create: `k8s_docker_mastery/labs/day06/orderflow-chart/templates/deployment.yaml`
- Create: `k8s_docker_mastery/labs/day06/orderflow-chart/templates/service.yaml`
- Create: `k8s_docker_mastery/labs/day06/orderflow-chart/templates/ingress.yaml`
- Create: `k8s_docker_mastery/labs/day06/orderflow-chart/templates/hpa.yaml`
- Create: `k8s_docker_mastery/labs/day06/orderflow-chart/templates/pdb.yaml`
- Create: `k8s_docker_mastery/labs/day06/orderflow-chart/templates/configmap.yaml`
- Create: `k8s_docker_mastery/labs/day06/orderflow-chart/templates/init-migration.yaml`

**Interfaces:**
- Consumes: All manifest patterns from Tasks 4-6 (Day 3-5). The Helm chart produces equivalent resources to the raw manifests but templated.
- Produces: Complete Helm chart for OrderFlow. Used in Day 7 lab for production simulation.

- [ ] **Step 1: Write `content/day06.md`**

Follow day skeleton. Sections:
- **Why this matters:** Raw YAML doesn't scale — Helm is how production teams manage K8s deployments across environments.
- **The layer this covers:** K8s ecosystem tooling → Helm → chart templates → rendered manifests → K8s objects.
- **Core concepts:** (a) Helm — why (package manager for K8s, parameterized deploys, release management, rollback). Chart structure: `Chart.yaml` (metadata, version, appVersion), `values.yaml` (defaults), `templates/` (Go templates), `charts/` (dependencies). Template syntax: `{{ .Values.image.tag }}`, `{{ include "chart.fullname" . }}`, `{{ if .Values.ingress.enabled }}`, `{{ range .Values.services }}`, `{{ toYaml . | nindent 8 }}`. Named templates in `_helpers.tpl` — `{{- define "chart.labels" }}`. Helm hooks (pre-install for migrations, post-install for notifications). Release lifecycle: `helm install` → `helm upgrade` → `helm rollback` → `helm uninstall`. `helm template` for local rendering/debugging. `helm diff` plugin for upgrade preview. Dependency management: `Chart.lock`, subcharts vs umbrella charts. (b) K8s design patterns — **Sidecar:** container that extends the main container (examples: Envoy proxy, log forwarder, config reloader). Runs alongside, shares pod network + volumes. When it's over-engineering: if the sidecar's functionality could be a library or a feature of the main container. **Init Container:** runs to completion before main containers start. Use cases: DB migration, config fetch from vault, wait-for-dependency. `initContainers[]` spec. **Ambassador:** outbound proxy in the same pod — simplifies external service access (e.g., cloud-sql-proxy for Cloud SQL). **Adapter:** normalizes output format — different containers produce different log formats, adapter container transforms to standard format. When to use each: decision table. (c) Production patterns — Resource requests vs limits: requests = scheduler guarantee (how much the scheduler reserves), limits = hard ceiling (kernel kills process if exceeded). QoS classes: Guaranteed (requests == limits for all containers), Burstable (at least one container has requests < limits), BestEffort (no requests or limits) — eviction priority order: BestEffort first, Burstable second, Guaranteed last. HPA: watches metrics-server → compares CPU/memory to target → scales replicas. Requires resource requests set. `behavior` field for scale-up/down rate limiting. VPA concept (adjusts requests/limits, not replicas). PDB: `minAvailable` or `maxUnavailable` — protects during voluntary disruptions (node drain, cluster upgrade). Probes: liveness (is process alive? failure → restart), readiness (can it serve? failure → remove from Service endpoints), startup (has it started? delays other probes for slow-starting apps). Each should test different things. Graceful shutdown: SIGTERM → `preStop` hook → `terminationGracePeriodSeconds` → SIGKILL. Application must handle SIGTERM. Pod topology spread constraints and anti-affinity (spread replicas across nodes/zones).
- **Exercises:** 3 exercises with hints + solutions: (1) Your HPA isn't scaling — what's the first thing to check? (2) Design a sidecar vs init container: you need to run a DB migration before the app starts AND continuously forward logs. Which pattern for each? (3) You set liveness and readiness probes to the same endpoint. The endpoint calls the database. The database goes down. What happens and why is it bad?
- **Anti-patterns:** Hardcoded Helm values, identical probes, HPA without resource requests, no PDB, liveness probe on external dependency, terminationGracePeriodSeconds: 0.

- [ ] **Step 2: Write Helm chart files**

- `Chart.yaml`: name `orderflow`, version `0.1.0`, appVersion `1.0.0`, description.
- `values.yaml`: Structure with `orderApi:`, `paymentService:`, `notificationService:` sections each containing `image:` (repository, tag, pullPolicy), `replicaCount`, `resources:` (requests/limits), `service:` (port, type), `probes:` (liveness, readiness, startup paths and ports). Top-level: `ingress:` (enabled, host, paths), `hpa:` (enabled, minReplicas, maxReplicas, targetCPU), `pdb:` (enabled, minAvailable), `namespace: orderflow`.
- `values-dev.yaml`: Low resources, 1 replica, HPA disabled, PDB disabled.
- `values-production.yaml`: Higher resources, 3 replicas, HPA enabled (min:2, max:10, target:70), PDB enabled (minAvailable:1).
- `_helpers.tpl`: `chart.name`, `chart.fullname` (release-name prefix), `chart.labels` (standard K8s labels: app.kubernetes.io/name, instance, version, managed-by), `chart.selectorLabels`.
- `deployment.yaml`: Templated Deployment using `{{ range }}` over services list or individual service blocks from values. Includes SecurityContext, resource requests/limits, probes, env from ConfigMap. Init container for order-api only (runs DB migration).
- `service.yaml`: Templated ClusterIP Service.
- `ingress.yaml`: Conditional `{{ if .Values.ingress.enabled }}`. nginx IngressClass.
- `hpa.yaml`: Conditional HPA targeting deployment.
- `pdb.yaml`: Conditional PDB.
- `configmap.yaml`: Templated ConfigMap with service URLs.
- `init-migration.yaml`: Init container spec (or embedded in deployment template) — uses `postgres:16-alpine` image, runs `psql` to create tables, waits for postgres to be ready.

- [ ] **Step 3: Write `labs/day06/README.md`**

Lab instructions: (1) `helm template orderflow labs/day06/orderflow-chart/ -f labs/day06/orderflow-chart/values-dev.yaml` — inspect rendered output, (2) `helm install orderflow labs/day06/orderflow-chart/ -f labs/day06/orderflow-chart/values-dev.yaml -n orderflow --create-namespace`, (3) Verify all resources created, (4) `helm upgrade` with changed values (increase replicas), (5) `helm rollback orderflow 1`, (6) Install with production values, (7) **Break it:** Set memory limit to 20Mi → OOMKilled → find right size with `kubectl top`, (8) **Break it:** Set readiness probe to wrong port → traffic blackhole during rollout, (9) **Success signal:** Helm chart installs cleanly with both dev and production values, HPA scales, PDB prevents full drain.

- [ ] **Step 4: Write `labs/day06/SOLUTION.md`**

Full solutions with expected output.

- [ ] **Step 5: Verify**

Run: `grep -c "Hint:" k8s_docker_mastery/content/day06.md && grep -c "Solution sketch:" k8s_docker_mastery/content/day06.md`
Expected: Both ≥ 3.
Run: `helm lint k8s_docker_mastery/labs/day06/orderflow-chart/` (if helm available)

---

### Task 8: Day 7 — Observability, Debugging & Production Synthesis (Content + Lab)

**Files:**
- Create: `k8s_docker_mastery/content/day07.md`
- Create: `k8s_docker_mastery/labs/day07/README.md`
- Create: `k8s_docker_mastery/labs/day07/SOLUTION.md`
- Create: `k8s_docker_mastery/labs/day07/debug-runbook.md`
- Create: `k8s_docker_mastery/labs/day07/manifests/metrics-server.yaml`
- Create: `k8s_docker_mastery/labs/day07/manifests/chaos-scenarios.yaml`

**Interfaces:**
- Consumes: Helm chart from Task 7 (Day 6). Deployed OrderFlow stack is the target for debugging exercises.
- Produces: Day 7 content covering observability, debugging mastery, container orchestration decision framework, and production readiness. Debug runbook template. Chaos scenarios for failure simulation.

- [ ] **Step 1: Write `content/day07.md`**

Follow day skeleton. Sections:
- **Why this matters:** The difference between "I can deploy" and "I can operate in production."
- **The layer this covers:** K8s operational layer — observability, debugging, architectural decisions.
- **Core concepts:** (a) Observability — USE method (Utilization, Saturation, Errors) for infrastructure; RED method (Rate, Errors, Duration) for services. metrics-server: deploys into kube-system, scrapes kubelet `/metrics/resource`, enables `kubectl top nodes` and `kubectl top pods`. Logging architecture: app → stdout/stderr → container runtime log driver → kubelet → node log file `/var/log/pods/`. Why stdout contract matters (K8s only collects stdout/stderr). Log aggregation patterns: EFK (Elasticsearch + Fluentd + Kibana), Loki + Promtail + Grafana — concepts and when each fits. Prometheus concepts: metrics types (counter: monotonically increasing, gauge: can go up/down, histogram: distribution buckets). Scraping model (pull-based). (b) Debugging mastery — The decision tree (detailed flowchart): `kubectl get pods` → check STATUS → branch on status. **ImagePullBackOff**: wrong image/tag, private registry (need imagePullSecrets), rate limiting. **CrashLoopBackOff**: check `kubectl logs` and `kubectl logs --previous` — app crash, wrong CMD/ENTRYPOINT, missing config/secret, OOMKilled (check `kubectl describe` for Last State). **Pending**: `kubectl describe pod` → Events → reasons: Insufficient cpu/memory (scale cluster or reduce requests), no matching node (taints/tolerations), PVC not bound. **OOMKilled**: `kubectl describe pod` → `lastState.terminated.reason: OOMKilled`. Container limit too low or memory leak. Container-level vs pod-level. **Evicted**: node under DiskPressure, MemoryPressure. Check `kubectl describe node`. **CreateContainerConfigError**: referenced ConfigMap or Secret doesn't exist. Advanced: `kubectl debug` for ephemeral containers (attach debug container to distroless pod), `kubectl port-forward` (ad-hoc service access), `kubectl exec` (run commands inside container), network debug pod (`nicolaka/netshoot`). (c) Container orchestration decision framework — Full coverage from spec: Step 1 (do you need containers?), Step 2 (ECS/Fargate vs EKS — full comparison tables), Step 3 (decision tree), Step 4 (migration signals — when outgrowing ECS), common decision mistakes. The control-vs-burden spectrum diagram. Your current ECS Fargate setup as a case study. (d) Production readiness — 12-factor app mapped to K8s: (I) Codebase → Git repo, (II) Dependencies → container image, (III) Config → ConfigMap/Secret, (IV) Backing services → Service/ExternalName, (V) Build/release/run → CI/CD pipeline, (VI) Processes → stateless pods, (VII) Port binding → container ports, (VIII) Concurrency → HPA, (IX) Disposability → graceful shutdown, (X) Dev/prod parity → same image everywhere, (XI) Logs → stdout, (XII) Admin processes → Jobs/CronJobs. Namespace strategy (per-team vs per-env). Label conventions (app.kubernetes.io/name, version, component, part-of, managed-by). GitOps concept (ArgoCD/Flux: repo → controller → cluster sync). CI/CD pipeline: build → test → scan (trivy) → push → update manifest → sync. Deployment strategies: rolling update (default), blue-green (two deployments, service switch), canary (weighted routing via Ingress or service mesh).
- **Decision tree:** K8s failure debugging flowchart. Container orchestration selection tree.
- **Exercises:** 4 exercises with hints + solutions: (1) Pod is OOMKilled but `kubectl logs` shows nothing — where do you look? (2) `kubectl top pods` returns "metrics not available" — what's wrong? (3) Given scenario: 5-service startup, 3-person team, pure AWS — recommend ECS or K8s and justify. (4) Given scenario: 30-service fintech, multi-region, compliance requirements, dedicated platform team — recommend orchestration strategy.
- **Anti-patterns:** Logging to files in containers, no monitoring, restart-as-debugging, not checking events, aggressive liveness probes, adopting K8s without evaluation.

- [ ] **Step 2: Write `labs/day07/manifests/metrics-server.yaml`**

Reference manifest for metrics-server installation (or kubectl apply URL with comments). Include the `--kubelet-insecure-tls` flag needed for Docker Desktop.

- [ ] **Step 3: Write `labs/day07/manifests/chaos-scenarios.yaml`**

Collection of deliberately broken manifests for debugging practice:
- Scenario 1: Deployment with nonexistent image tag → ImagePullBackOff
- Scenario 2: Deployment with wrong CMD → CrashLoopBackOff
- Scenario 3: Deployment with memory limit 5Mi → OOMKilled
- Scenario 4: Deployment referencing nonexistent ConfigMap → CreateContainerConfigError
- Scenario 5: Deployment with resource requests exceeding node capacity → Pending
Each scenario separated by `---` with comments naming the expected failure.

- [ ] **Step 4: Write `labs/day07/debug-runbook.md`**

Template runbook with 6 sections (one per common failure mode): symptom, diagnosis steps, commands to run, root cause, fix, prevention. Pre-filled for ImagePullBackOff as an example; others as templates for the learner to complete during the lab.

- [ ] **Step 5: Write `labs/day07/README.md`**

Lab instructions: (1) Install metrics-server, (2) Verify `kubectl top nodes` and `kubectl top pods` work, (3) Deploy Helm chart from Day 6, (4) Apply chaos-scenarios.yaml one at a time, (5) For each: identify the failure, diagnose using only kubectl, document in runbook, (6) **Decision exercise:** Write a 1-paragraph recommendation for each of 3 scenarios (5-service startup, 30-service fintech, 8-service monolith migration), (7) **Success signal:** All 5 failure modes diagnosed and documented, decision exercise completed.

- [ ] **Step 6: Write `labs/day07/SOLUTION.md`**

Full solutions for each debugging scenario and decision exercise.

- [ ] **Step 7: Verify**

Run: `grep -c "Hint:" k8s_docker_mastery/content/day07.md && grep -c "Solution sketch:" k8s_docker_mastery/content/day07.md`
Expected: Both ≥ 4.

---

### Task 9: Glossary + EKS Appendix

**Files:**
- Create: `k8s_docker_mastery/content/GLOSSARY.md`
- Create: `k8s_docker_mastery/content/appendix-eks.md`

**Interfaces:**
- Consumes: All terminology from Days 1-7 content
- Produces: Comprehensive glossary (~80+ terms) and optional EKS appendix. These are reference documents, not sequential learning.

- [ ] **Step 1: Write `content/GLOSSARY.md`**

~80+ terms organized by domain as specified in the spec:
- **Container runtime** (8 terms): OCI, containerd, runc, CRI, image spec, runtime spec, Docker Engine, shim
- **Linux primitives** (8 terms): namespace (pid, net, mnt, uts, ipc, user), cgroup, OverlayFS, veth, bridge, iptables
- **Image/build** (10 terms): layer, manifest, registry, tag, digest, multi-stage build, build context, .dockerignore, distroless, scratch
- **Docker networking** (6 terms): bridge network, docker0, embedded DNS, port mapping, overlay, VXLAN
- **Docker storage** (4 terms): named volume, bind mount, tmpfs, volume driver
- **Docker Compose** (6 terms): service, profile, override file, build context, healthcheck, depends_on
- **K8s architecture** (7 terms): control plane, API server, etcd, scheduler, controller-manager, kubelet, kube-proxy
- **K8s workloads** (8 terms): Pod, ReplicaSet, Deployment, DaemonSet, StatefulSet, Job, CronJob, pause container
- **K8s config** (4 terms): ConfigMap, Secret, environment variable, volume mount
- **K8s networking** (12 terms): Service, ClusterIP, NodePort, LoadBalancer, ExternalName, Endpoints, EndpointSlice, Ingress, IngressClass, CNI, CoreDNS, NetworkPolicy, Gateway API
- **K8s storage** (7 terms): PersistentVolume, PersistentVolumeClaim, StorageClass, CSI, RWO, ROX, RWX, reclaim policy
- **K8s security** (10 terms): RBAC, Role, ClusterRole, RoleBinding, ClusterRoleBinding, ServiceAccount, SecurityContext, Pod Security Admission, Pod Security Standards, seccomp
- **K8s patterns** (4 terms): sidecar, init container, ambassador, adapter
- **K8s operations** (10 terms): liveness probe, readiness probe, startup probe, HPA, VPA, PDB, graceful shutdown, preStop hook, terminationGracePeriodSeconds, QoS class
- **K8s debugging** (6 terms): CrashLoopBackOff, ImagePullBackOff, OOMKilled, Pending, Evicted, CreateContainerConfigError
- **Ecosystem** (8 terms): Helm, Kustomize, ArgoCD, Flux, GitOps, metrics-server, Prometheus, EFK
- **EKS-specific** (5 terms): managed node group, Fargate profile, IRSA, AWS Load Balancer Controller, EBS CSI Driver

Each term: one-line definition, then 1-2 sentences of practical context. No documentation copy — plain-English explanations a working engineer would give a colleague.

- [ ] **Step 2: Write `content/appendix-eks.md`**

EKS production appendix covering:
- **EKS cluster setup:** `eksctl create cluster` with example config. Managed node groups vs Fargate profiles — decision table (node groups for: DaemonSets, GPU, persistent volumes; Fargate for: no node management, per-pod isolation, burstier workloads).
- **IRSA:** How it works (OIDC provider → IAM role → ServiceAccount annotation → STS AssumeRoleWithWebIdentity → temporary credentials injected as env vars). Why node-level IAM is dangerous (any pod on the node gets the role). Step-by-step setup.
- **AWS Load Balancer Controller:** Replaces nginx-ingress with AWS-native ALB. Ingress annotations (`alb.ingress.kubernetes.io/scheme: internet-facing`, target-type, health-check). NLB for non-HTTP.
- **EBS CSI Driver:** Required for dynamic PV provisioning on EKS (built-in EBS provisioner deprecated). gp3 StorageClass. Installation via EKS add-on.
- **Lab:** Deploy OrderFlow Helm chart on EKS with IRSA for order-api (e.g., S3 access for order receipts), ALB Ingress, EBS PVCs. Full teardown checklist.
- **Exercises:** 2 exercises with hints + solutions: (1) Your pod can't assume its IAM role — troubleshooting steps. (2) PVC stuck in Pending on EKS — is the EBS CSI driver installed?
- **Teardown checklist:** eksctl delete cluster, verify ALB deleted, verify EBS volumes deleted, verify IAM roles cleaned up. Cost note: ~$2.50/hour, design lab for < 2 hours.

- [ ] **Step 3: Verify glossary completeness**

Run: `grep -c "^### \|^**" k8s_docker_mastery/content/GLOSSARY.md`
Expected: 80+ term entries.

---

### Task 10: Final Verification & Cross-Reference Check

**Files:**
- Modify: Any files needing fixes from verification

**Interfaces:**
- Consumes: All files from Tasks 1-9
- Produces: Verified, consistent, complete learning path

- [ ] **Step 1: Verify all files exist**

Run: `find k8s_docker_mastery -type f | sort | wc -l`
Expected: ~55+ files (content, labs, manifests, Go source, Helm chart, docs).

- [ ] **Step 2: Verify exercise completeness across all days**

Run: `for f in k8s_docker_mastery/content/day*.md; do echo "$f:"; grep -c "Hint:" "$f"; grep -c "Solution sketch:" "$f"; done`
Expected: Every day file has equal counts of Hints and Solution sketches, minimum 3 per day.

- [ ] **Step 3: Verify lab completeness**

Run: `for d in k8s_docker_mastery/labs/day*/; do echo "$d:"; ls "$d"README.md "$d"SOLUTION.md 2>/dev/null; done`
Expected: Every day lab directory has both README.md and SOLUTION.md.

- [ ] **Step 4: Verify image name consistency**

Run: `grep -r "orderflow/" k8s_docker_mastery/labs/ --include="*.yaml" --include="*.yml" | grep "image:" | sort -u`
Expected: Consistent image names across Dockerfiles, K8s manifests, and Helm values.

- [ ] **Step 5: Verify no credentials**

Run: `grep -ri "password\|secret\|token\|key" k8s_docker_mastery/ --include="*.yaml" --include="*.yml" --include="*.go" --include="*.env*" | grep -v "changeme\|placeholder\|example\|REPLACE\|TODO\|configmap\|Secret\|secret.yaml\|secretName\|ServiceAccount\|secretKeyRef\|POSTGRES_PASSWORD"` — should return minimal or no results that contain actual secrets.

- [ ] **Step 6: Cross-reference day continuity**

Manually verify: Day 3 manifests reference same image names as Day 1 Dockerfiles. Day 4 manifests extend Day 3 namespace. Day 5 manifests work alongside Day 3 deployments. Day 6 Helm chart produces equivalent resources. Day 7 uses Day 6 Helm chart. Fix any inconsistencies.

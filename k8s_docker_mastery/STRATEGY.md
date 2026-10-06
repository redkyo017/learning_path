# The Top 1% Strategy for Docker & Kubernetes Mastery

You already run containers and microservices every day. The gap is not "how do I type the command"; it is knowing *why* it works, *how it fails*, and *what to check first*. This file is the method; [`README.md`](./README.md) has the setup and schedule, [`content/CHEATSHEET.md`](./content/CHEATSHEET.md) the commands, [`content/RECALL.md`](./content/RECALL.md) the drills.

## The Core Mental Model

The top 1% of engineers do not treat Docker as "a command-line tool" or Kubernetes as "a complex cloud platform." They see:

1. **Docker is a user-friendly wrapper around three Linux kernel primitives:**
   - **Namespaces** (eight types: mnt, pid, net, ipc, uts, user, cgroup, time) for isolation. The user namespace is *not* on by default: container root is host root unless you use rootless mode or `userns-remap`.
   - **Cgroups** (v2) for metering and hard limits (CPU, memory, I/O, PIDs). Memory over the limit means an OOM kill; CPU over the limit only throttles.
   - **Union mounts / OverlayFS** (lowerdir, upperdir, merged) for copy-on-write image layering.
   *Once you see containers through this lens, every signal-handling problem and OOM event is predictable.*

2. **Kubernetes is a declarative reconciliation loop engine:**
   - You declare **desired state** through the kube-apiserver (stored in etcd).
   - Controllers watch (informers: one LIST, then a WATCH, not polling) and compare it with **actual state** reported by the kubelets.
   - Each controller acts to close the gap: Observe → Diff → Act → Repeat.
   - Every object (`Pod`, `Deployment`, `Service`, `StatefulSet`, `HTTPRoute`) is a spec plus a controller (or a data plane that a controller programs).
   *Debugging Kubernetes never means randomly restarting pods; it means finding which controller is failing to reconcile and why, in the events and status it writes.*

---

## The Engineering Pattern Loop

Apply this six-step loop to every topic:

1. **Name the concept** and the production problem it was invented to solve.
2. **Map it to the layer**: kernel primitive → container runtime → K8s controller → architectural pattern.
3. **Wire it**: build the minimal manifest or configuration.
4. **Break it**: exhaust memory, kill PID 1, misroute DNS, tamper with selectors, violate security constraints.
5. **Fix it**: apply the pattern the abstraction implies (probes, preStop, securityContext, NetworkPolicy).
6. **Know when NOT to use it**: find the boundary where the complexity outweighs the benefit.

---

## The Aggressive 7-Day Practice Protocol

Seven days is enough only if every hour is active practice. The protocol is the same each day (~3.5 hours; Day 7 about 4; the calendar is in the README).

### The daily loop (time-boxed)

| Block | Box | Rules |
|:---|:---|:---|
| **1. Predict + theory** | 45 min | Skim the day's "Why this matters" and write three predictions ("what happens if ..."). Read the concepts; for each exercise attempt the **Hint** first, open the **Solution sketch** only after writing your answer. |
| **2. Lab** | 90 min | Type commands, do not paste blind: before each step say aloud what you expect to see, then compare with "You should see". A mismatch is the most valuable moment of the day; stop and explain it. |
| **3. Break it** | 45 min | Redo the day's failure steps from signals only (status, `describe`, events, logs, exit code). Then invent one new failure the lab does not cover and diagnose it. |
| **4. Recall** | 30 min | Answer the day's drill and the matching [`RECALL.md`](./content/RECALL.md) section on paper, then open the `<details>`. Mark misses; they are tomorrow's first five minutes. |

**Time-box rule:** if a step is stuck for 15 minutes, read the lab's "Stuck? Hints", then `SOLUTION.md`, then move on and note it. Environment trouble (a wedged kindnet, an image not loaded) is not the lesson; the hint list covers it.

### The break-it-first rule

Before you build a good version of anything, **make the bad version fail on purpose** and read exactly how it fails: a root pod rejected by `restricted`, a 503 from a Service with a typo'd selector, a rollout that stalls on a missing tag, a container killed at its memory limit. You then recognise the failure in production in seconds, and you understand *why* the good pattern has each line. Never trust a pattern you have not seen fail without it.

### Spaced recall (days 2, 4 and 7)

Memory consolidates when retrieval is effortful and spaced, so reading again is the wrong tool.
- **Day 2:** 10 minutes closed-book on Day 1 questions from RECALL.md.
- **Day 4:** 10 minutes on Days 2-3.
- **Day 7:** 20 minutes on the Days 1-6 questions you marked as missed, then the **final 20-question mixed self-test** in RECALL.md, closed book, timed (30 minutes): 50 minutes on top of the day's normal recall, so Day 7 runs about 4 hours (its break-it block is 30 minutes).
- **After day 7:** re-run the self-test on day 10 and day 21. A question you miss twice goes on your own cheat-sheet card.

### The "explain it out loud" test

At the end of each day, explain the day to an imaginary colleague, out loud, without notes, in five minutes, ending with "and here is how it breaks." If you hesitate, you have found a gap. Concrete targets: Day 1 *what happens between `docker run` and `execve`*; Day 3 *what happens when I `kubectl apply` a Deployment*; Day 4 *the path of a request from `curl http://localhost/orders` to a pod IP*; Day 6 *why a healthy rolling update can return 503s*; Day 7 *a Gateway returns 503; what do I check, in order*.

---

## What 80% of Engineers Waste Time On

| Trap | Why it fails | What to do instead (and where this course practises it) |
|:---|:---|:---|
| **Copy-pasting Dockerfiles** | Build tools, root user, and a huge attack surface end up in production images. | Multi-stage, numeric non-root `USER 65532:65532`, distroless, BuildKit cache mounts (Day 1: you write the Dockerfile yourself). |
| **A shell as PID 1** | Signals never reach the app; `docker stop` / pod deletion waits the whole grace period, then SIGKILL (137). | Exec-form `ENTRYPOINT`, `exec "$@"` in wrappers, `--init` if needed (Day 1 `docker stop` timing). |
| **Readiness = liveness** (or a database check in liveness) | One dependency outage fails every pod's liveness, the kubelet restarts them all, and the cold-start storm deepens the outage. | `/health` (process alive) for liveness, `/ready` (can serve traffic) for readiness, `startupProbe` for slow starts (Day 6). |
| **Debugging a distroless image with `exec sh`** | There is no shell; people rebuild images with debug tools baked in. | `kubectl debug --image=nicolaka/netshoot --target=<container>` ephemeral containers; `--copy-to` for crashing pods (Days 2, 4, 7). |
| **Trusting a rolling update to be zero-downtime** | Endpoint removal and SIGTERM race; the Go app stops accepting while the gateway still routes to it. | `lifecycle.preStop.sleep` and/or an app-level drain; `terminationGracePeriodSeconds` ≥ preStop + drain + shutdown timeout (Day 6: measure the errors with 0 vs 10 s). |
| **Assuming NetworkPolicy works** | The API server accepts the object on any cluster; only an enforcing CNI blocks traffic (kindnet, Calico, Cilium do; the Docker Desktop kubeadm provisioner does not). Egress default-deny also kills DNS. | Always test the block *and* the allow; pair egress deny with a DNS allow (Day 4). |
| **Ignoring requests/limits and QoS** | The scheduler is blind; OOM kills and node-pressure evictions look random. HPA shows `<unknown>` without CPU requests. | Set requests; know Guaranteed/Burstable/BestEffort; read `OOMKilled` and exit 137 (Days 6, 7). |
| **Believing the first error text** | `ImagePullBackOff` "pull access denied" often means a mistyped tag; `StartError` is the runtime, not a crash; an OOM kill leaves no log line. | Read `Reason`, exit code, and which component wrote the event (Day 7 failure table). |
| **Learning the edge as annotations** | Ingress annotations are non-portable and ingress-nginx is retired. | Gateway API roles and typed routes; know what is still controller-specific (Day 4). |
| **Not knowing Envoy's failure behaviour** | A backend with zero endpoints returns 503, but when endpoints exist and too few are healthy or ready (below the default 50% panic threshold, so also when *all* are not ready), Envoy's **panic routing** still sends traffic to them (observed live on Envoy Gateway). "Not ready" does not always mean "gets no traffic" at the data plane. | Check EndpointSlice readiness *and* the route status and proxy access log together; keep at least 2 replicas (Days 6, 7). |
| **Using `kubectl port-forward` as proof** | It bypasses the gateway and NetworkPolicy ingress rules. | Test through the real path (`curl http://localhost/...`) as well. |
| **Leaving cloud resources running** | A forgotten NAT gateway or ALB bills after the cluster is gone. | Ordered teardown with "nothing left" checks (EKS appendix). |
| **Memorising YAML schemas** | Breaks across API versions. | Learn the controller model; use `kubectl explain` and `--dry-run=server`. |
| **Defaulting to Kubernetes for everything** | Operational cost for small teams. | The orchestration decision framework (Day 7). |

---

## What the Top 1% Do Differently

- **They explain the kernel sequence** between `docker run` (or Pod scheduling) and the target's `execve`.
- **They prioritise failure over the happy path:** pod termination, node failure, partitions and cascading restarts are designed in from day one.
- **They build deterministic, cache-friendly, scanned images:** instructions ordered by change frequency, cache mounts, digest pinning, SBOM.
- **They read the event stream first:** `describe`, events, conditions, route status, then logs.
- **They enforce security at the boundary:** non-root numeric UID, `restricted` PSA, dropped capabilities, read-only root, NetworkPolicy, least-privilege RBAC.
- **They measure instead of believing:** count the errors during a rollout, prove a policy blocks, prove a limit kills.

---

## For the API-Gateway Engineer: What You Know → Where It Lives

| What you already know | Kubernetes / Gateway API / mesh concept | Where |
|:---|:---|:---|
| Upstream pool / backend cluster | `Service` + EndpointSlices (the gateway's data plane reads pod IPs from them) | Day 4 |
| Route table: host/path/header match | `HTTPRoute` / `GRPCRoute` matches; most specific match wins, not rule order | Day 4 |
| Gateway instance owned by the platform team | `Gateway` (+ `GatewayClass` = the implementation); `allowedRoutes` decides who may attach; cross-namespace refs need a `ReferenceGrant` | Day 4 |
| Weighted routing / canary | `backendRefs[].weight`, header match to force the canary | Day 4, 7 |
| Health checks and outlier ejection | readiness probe → EndpointSlice `ready`; Envoy outlier detection; panic routing when too few are healthy | Days 6, 7 |
| Drain / graceful deregistration | `preStop` sleep, readiness flip on SIGTERM, grace period sizing | Day 6 |
| Rate limiting, JWT auth, retries, timeouts | Implementation policy CRDs attached with `targetRefs` (Envoy Gateway: `BackendTrafficPolicy`, `SecurityPolicy`); not in the portable core | Days 4, 7 |
| Retry storms and circuit breaking | Retry budgets, circuit-breaker thresholds, one retry layer, idempotency | Day 7 |
| Service-to-service auth | Service mesh mTLS with SPIFFE identity from the ServiceAccount; authorization by identity | Day 7 |
| Firewall rules between services | `NetworkPolicy` (L3/L4, by labels) and mesh authorization (L7, by identity) | Days 4, 7 |
| Config reload | Envoy's xDS: control plane pushes listeners/routes/clusters/endpoints without restart | Day 7 |
| Blue/green deploy | Two Deployments + a route or selector switch; rollback is instant at double capacity | Day 7 |
| Access logs for debugging | Envoy access log fields `response_code`, `response_code_details`, `response_flags`; empty-body 503 = no endpoints, 404 = no route | Day 7 |

---

## Container Orchestration Decision Framework Summary

Choose the orchestration tier from workload characteristics and operational capacity, not hype:

```
                      [Is Containerization Required?]
                                  │
                  ┌───────────────┴───────────────┐
                  ▼                               ▼
          No: Event-driven / bursty       Yes: Microservices, env parity
          → AWS Lambda / Serverless               │
                                                  ▼
                                      [Services < 15, Pure AWS,
                                       No Dedicated Platform Team?]
                                                  │
                                  ┌───────────────┴───────────────┐
                                  ▼                               ▼
                          Yes: ECS on Fargate             No: Complex mesh, multi-cloud,
                          (Zero node ops, AWS native)         custom CRDs/operators needed
                                                                  │
                                                                  ▼
                                                      Kubernetes (EKS / Local)
```

*(Day 7, `content/day07.md` section 4, has the full framework and its worked cases.)*

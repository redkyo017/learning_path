# Docker & Kubernetes Mastery

A 7-day aggressive, pattern-first path for a backend / API-gateway engineer who already works with containers and microservices by habit and wants to **recall and consolidate** that knowledge systematically: kernel primitives, image craft, networking, Kubernetes controllers, security, Helm, graceful shutdown, the Gateway API, debugging, and the architecture decisions around them.

Everything runs locally on Docker Desktop ($0). An optional EKS appendix runs on your own AWS account.

Orientation files (read these once, keep them open while you work):
- [`STRATEGY.md`](./STRATEGY.md): the mental models, the daily practice protocol, the mistakes that waste time, and a mapping from API-gateway concepts to Kubernetes.
- [`content/CHEATSHEET.md`](./content/CHEATSHEET.md): one page of commands and decision rules (debug tree, exit codes, probes, QoS, PSA, NetworkPolicy, Gateway API, Helm 4, graceful shutdown).
- [`content/RECALL.md`](./content/RECALL.md): cumulative recall questions per day plus a 20-question mixed self-test.
- [`content/GLOSSARY.md`](./content/GLOSSARY.md): terms, one paragraph each.

---

## Start here

Do this once (about 20-30 minutes, mostly downloads). Every command in the labs runs **from this directory** (`k8s_docker_mastery/`).

1. **Enable `#` comments in zsh (do this first).** Every lab README pastes command blocks that contain `#` comments, and a fresh macOS zsh does not treat `#` as a comment in interactive mode (you get `command not found: #` or a parse error on lines with parentheses). Enable it for this shell and persist it:
   ```bash
   setopt interactivecomments
   echo 'setopt interactivecomments' >> ~/.zshrc
   ```
2. **Docker Desktop with Kubernetes.** Open the Docker Desktop Dashboard → **Kubernetes** view → **Create cluster** → choose **kind** (recommended; the labs and their outputs are verified on it; **kubeadm** is the alternative) → **Create**. Docker Desktop 4.38 or newer offers kind; if your version offers or requires the containerd image store, enable it as prompted (the verified setup here runs kind with the overlay2 store). On older versions use Settings → Kubernetes → Enable Kubernetes (kubeadm) → Apply & restart. Wait until Kubernetes shows as running. Reference: https://docs.docker.com/desktop/use-desktop/kubernetes/
3. **Point kubectl at it and check the node.**
   ```bash
   kubectl config use-context docker-desktop
   kubectl get nodes
   ```
   You should see one `Ready` node: `desktop-control-plane` on the kind provisioner (`docker-desktop` on the kubeadm provisioner).
4. **Tools.**
   ```bash
   brew install helm            # Helm 4 (the course uses 4.x flags such as --rollback-on-failure)
   helm version --short         # must start with v4
   go version                   # optional: Go 1.25 or newer (builds run in golang:1.27-alpine, so a local Go is only for reading/running the code)
   ```
   You also need `curl`, `jq` and `lsof`, which macOS provides or Homebrew installs. `kubectl` ships with Docker Desktop.
5. **Build and load the three OrderFlow images** into the cluster (needed before Day 3):
   ```bash
   bash labs/shared/load-images.sh          # builds orderflow/{order-api,payment-service,notification-service}:v1 and loads them
   ```
   Re-run it any time pods show `ImagePullBackOff` for `orderflow/*` images. Day 3 also uses `bash labs/shared/load-images.sh v2`.
6. **metrics-server** (HPA on Day 6 and `kubectl top` on Day 7 need it; the file is upstream v0.9.0 plus `--kubelet-insecure-tls`, required on Docker Desktop):
   ```bash
   kubectl apply -f labs/shared/metrics-server.yaml
   kubectl rollout status deploy/metrics-server -n kube-system --timeout=120s
   ```
   `kubectl top nodes` starts working about a minute later.
7. *(Optional)* AWS CLI v2, `eksctl` and a personal AWS account for the EKS appendix (see the cost note below).

### Which Kubernetes provisioner do you have?

Docker Desktop offers two, and plain `kind` is the third option. The labs are written for the first row and tell you where the others differ.

| | Docker Desktop **kind** provisioner (recommended) | Docker Desktop **kubeadm** provisioner | Plain **kind** (`kind create cluster`) |
|:---|:---|:---|:---|
| Context / node | `docker-desktop` / `desktop-control-plane` (a container) | `docker-desktop` / `docker-desktop` | `kind-<name>` / `<name>-control-plane` |
| Locally built images visible to the cluster? | **No.** Must be loaded (otherwise `ImagePullBackOff`) | Yes (shares the Docker engine's image store) | **No.** Must be loaded |
| How to load images | `bash labs/shared/load-images.sh` (does `docker save \| docker exec -i desktop-control-plane ctr -n k8s.io images import -`) | Nothing to do (the script says so) | `bash labs/shared/load-images.sh` (runs `kind load docker-image`) |
| NetworkPolicy enforced? | **Yes** (kindnet) | **No**: objects are accepted and ignored (Day 4 Step 7 and Day 7 Step 8 will not block) | Yes (kindnet) |
| Reaching the Gateway from the Mac | `curl http://localhost/...` (Docker Desktop publishes the LoadBalancer port) | same (`http://localhost` works on both Docker Desktop provisioners) | needs MetalLB / cloud-provider-kind; use the `kubectl port-forward` fallback from Day 4 Step 3 (also the fallback if port 80 is busy) |
| Node-level steps (`docker exec` into the node) | work | use `kubectl debug node/...` instead | work (`<name>-control-plane`) |

If a day behaves differently from its "You should see" lines, check this table first. Always test NetworkPolicy enforcement rather than assuming it.

---

## How to use this path

1. **Daily loop, ~3.5 hours** (details and the full protocol in [`STRATEGY.md`](./STRATEGY.md)):

   | Block | Time | What |
   |:---|:---|:---|
   | Theory | 45 min | Read `content/dayNN.md`: concepts, decision trees, anti-patterns. Attempt the exercises' **Hint** before the **Solution sketch** |
   | Lab | 90 min | `labs/dayNN/README.md`: start with its "Start here" steps, run the commands, compare with the "You should see" lines |
   | Break it | 45 min | Re-do the day's failure steps without looking: predict the symptom, trigger it, read the signals, fix it. Then invent one extra failure |
   | Recall | 30 min | The day's `## Recall drill`, then the matching section of [`content/RECALL.md`](./content/RECALL.md), answers closed until you have written yours |

2. **The pattern loop** on every topic: Name it → Map it to its layer → Wire it → Break it → Fix it → Know when NOT to use it.
3. **Do not skip "break it".** Operators debug failure modes; the happy path teaches little.
4. **OrderFlow** is the reference app (`order-api`, `payment-service`, `notification-service`, Postgres) in `labs/shared/`. The Go services are distroless (no shell), so you debug with `kubectl debug` ephemeral containers, never `kubectl exec ... sh`. `order-api` keeps orders in memory and does not use Postgres; Postgres is there to teach volumes and StatefulSets.

### How each day begins

- **Days 1-2** use the Docker engine only: no Kubernetes state to prepare.
- **Days 3-7** each start from a clean namespace and fresh images:
  ```bash
  bash labs/shared/reset.sh          # deletes and recreates namespace orderflow (and any Helm release), unlabeled
  bash labs/shared/load-images.sh    # idempotent; Day 3 also loads v2
  ```
  Each lab's Prerequisites / Step 1 then rebuilds whatever that day needs from zero, so you can start any day on a clean cluster (for example after a laptop restart).

### What persists across days

| Survives `reset.sh` (platform layer) | Created from day | Needed by |
|:---|:---|:---|
| Envoy Gateway in `envoy-gateway-system`, GatewayClass `eg`, Gateway `edge` in `gateway-infra` | Day 4 | Days 6, 7 (route through `http://localhost`) |
| metrics-server in `kube-system` | Start here (step 6) | Day 6 HPA, Day 7 `kubectl top` |
| Loaded images `orderflow/*:v1` (and `v2`) | Start here / each day | Days 3-7 |
| Gateway API CRDs (cluster-wide) | Day 4 | Days 6, 7 |

Everything in namespace `orderflow` is disposable and rebuilt each day. Day 4's teardown deliberately keeps the edge; its optional full uninstall is in the Day 4 Teardown.

---

## Day index and schedule

| Day | Theme | Key topics | Hands-on lab (what you will actually do) |
|:---|:---|:---|:---|
| **1** — [`day01.md`](./content/day01.md) | Docker internals & image mastery | 8 namespace types, cgroups v2, OverlayFS, OCI manifest/index, PID 1 and signals, BuildKit cache/secret mounts, multi-stage distroless, multi-arch, SBOM | Inspect a bad image; write the multi-stage Dockerfile yourself; look at namespaces/cgroups/overlay inside the Docker VM; OOM kill at `--memory=32m`; the shell-wrapper PID 1 trap |
| **2** — [`day02.md`](./content/day02.md) | Docker networking, volumes & Compose | bridge + veth + embedded DNS (127.0.0.11), isolation as firewall rules, DNAT/MASQUERADE, volumes vs bind mounts, Compose healthchecks, profiles, env precedence, `compose watch` | 4-service OrderFlow stack with Postgres; inspect the plumbing with netshoot; break DNS and a volume; distroless debugging |
| **3** — [`day03.md`](./content/day03.md) | Kubernetes core objects & the reconciliation loop | control plane vs data plane, informers, ownership/GC, Deployments, rolling updates, ConfigMap/Secret behaviour | Apply hand-written manifests; scale, orphan and adopt; v2 rollout, stuck `v99` rollout, `rollout undo`; relabel a pod; ConfigMap env vs volume vs `subPath` |
| **4** — [`day04.md`](./content/day04.md) | Kubernetes networking, Services & the Gateway API | CNI/kubelet, kube-proxy and conntrack, Service types, EndpointSlices, `ndots:5`, Gateway API roles, NetworkPolicy (AND vs OR, egress + DNS) | Envoy Gateway edge (`http://localhost`), canary by header and weight, broken selector, headless DNS, enforced NetworkPolicies, node dataplane rules |
| **5** — [`day05.md`](./content/day05.md) | Storage, security & RBAC | PV/PVC/StorageClass, WaitForFirstConsumer, StatefulSet, PSA levels and modes, `securityContext`, RBAC | Postgres StatefulSet that passes `restricted`; PVC survives StatefulSet delete; read-only rootfs; `auth can-i`; Delete vs Retain |
| **6** — [`day06.md`](./content/day06.md) | Helm 4, design patterns & graceful shutdown | chart, hooks, SSA and Helm 4 flags, native sidecar, init container, probes, QoS, HPA, PDB, spread, preStop and the endpoint race | Install the OrderFlow chart under `restricted`; upgrade/rollback; HPA 2→6; OOM and bad-readiness breaks; measure dropped requests with preStop 0 vs 10 s |
| **7** — [`day07.md`](./content/day07.md) | Observability, debugging & production synthesis | RED/USE, debug tree, exit codes, ephemeral containers, mesh/mTLS/xDS, retries and rate limits, orchestration decisions | Install the chart as "production", break it 9 ways (OOM, crashloop, selector 503, DNS, ...) and diagnose from signals; node debugging; architecture decision drill |
| **Appendix** — [`appendix-eks.md`](./content/appendix-eks.md) *(optional, costs money)* | Production EKS | Pod Identity vs IRSA, AWS Load Balancer Controller, EBS CSI gp3, Auto Mode and Karpenter, teardown discipline | Graviton cluster, ECR push, ALB Ingress, identity check, ordered teardown ([`labs/eks`](./labs/eks/README.md)) |

### The 7-day schedule

~3.5 hours per day, except Day 7 (about 4 hours). Spaced recall sessions use [`content/RECALL.md`](./content/RECALL.md): 10 minutes on Day 1 during Day 2, 10 minutes on Days 2-3 during Day 4, and on Day 7 a 20-minute re-test of your misses plus the 30-minute timed self-test.

| Day | Theory 45 | Lab 90 | Break it 45 (Day 7: 30) | Recall 30 (Day 7: 80) |
|:---|:---|:---|:---|:---|
| 1 | `day01.md` | `labs/day01` | Steps 6-7 again: OOM with a different limit, a wrapper script that does/doesn't `exec` | Day 1 drill + RECALL Day 1 |
| 2 | `day02.md` | `labs/day02` | Wrong service URL, `down -v`, restart vs `up -d` | RECALL Day 2 + **spaced: Day 1 (10 min)** |
| 3 | `day03.md` | `labs/day03` | `v99` rollout, relabel, orphan, ConfigMap staleness | RECALL Day 3 |
| 4 | `day04.md` | `labs/day04` | Selector and `targetPort` typos, egress default-deny without DNS, AND vs OR | RECALL Day 4 + **spaced: Days 2-3 (10 min)** |
| 5 | `day05.md` | `labs/day05` | Root pod under `restricted`, delete StatefulSet, `Retain` reclaim | RECALL Day 5 |
| 6 | `day06.md` | `labs/day06` | OOM release, bad readiness path, preStop 0 vs 10 s, PDB refusal | RECALL Day 6 |
| 7 | `day07.md` | `labs/day07` | Run the 9 scenarios from signals only (no tenth today) | RECALL Day 7 (30) + **misses from Days 1-6 (20) + timed 20-question self-test (30)** |

Spare time goes to the optional EKS appendix (tear it down the same day).

---

## Cost note

- Days 1-7 run **100% locally on Docker Desktop at $0**.
- The optional EKS appendix costs about **$0.30-0.40 per hour** while the cluster exists (control plane $0.10/h, two `t4g.medium` nodes, one NAT gateway, an ALB, public IPv4 addresses): roughly **$7-10 per day if left running**, ~$250 per month. A one-hour lab is well under a dollar. Follow the ordered teardown in `labs/eks/README.md` and finish with its "nothing left" checks; a forgotten NAT gateway or ALB keeps billing after the cluster is gone. Details: the cost table in [`content/appendix-eks.md`](./content/appendix-eks.md).

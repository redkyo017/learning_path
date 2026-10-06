# Day 7 Lab Solution: Observability, Systematic Debugging & Strategic Synthesis

Every output below was captured on the live run: Docker Desktop, kind provisioner, node `desktop-control-plane`, Kubernetes v1.34.3, kindnet CNI, Envoy Gateway v1.9.2, metrics-server v0.9.0, Helm v4.3.0. Names/IDs/timestamps differ on your machine; the **signals** (STATUS, Reason, exit code, message text) are what to compare. Output is trimmed with `...`.

---

## Part 1: Baseline and metrics (Step 1)

```text
$ kubectl get pods -n orderflow
NAME                                      READY   STATUS      RESTARTS   AGE
orderflow-db-migration-cqb4z              0/1     Completed   0          4s
orderflow-notification-7697fb8c6d-th4hh   1/1     Running     0          22s
orderflow-order-api-6dc79954c-jz9bq       2/2     Running     0          22s
orderflow-payment-688cdfcd87-ktlwb        1/1     Running     0          22s
orderflow-postgres-0                      1/1     Running     0          22s

$ curl -s http://localhost/orders
[]

$ kubectl top nodes
NAME                    CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
desktop-control-plane   227m         2%       2048Mi          25%

$ kubectl top pods -n orderflow
NAME                                      CPU(cores)   MEMORY(bytes)
orderflow-notification-7697fb8c6d-th4hh   1m           4Mi
orderflow-order-api-6dc79954c-dth66       2m           5Mi
orderflow-payment-688cdfcd87-ktlwb        1m           4Mi
orderflow-postgres-0                      4m           27Mi

$ kubectl get apiservice v1beta1.metrics.k8s.io
NAME                     SERVICE                      AVAILABLE   AGE
v1beta1.metrics.k8s.io   kube-system/metrics-server   True        103m
```
The order-api pod is `2/2` because of the Day 6 native sidecar. Your CPU/memory numbers will differ.

---

## Part 2: The nine scenarios

### Scenario 1: ImagePullBackOff (`scenario=imagepull`)
```text
$ kubectl get pods -n orderflow -l scenario=imagepull
NAME                                  READY   STATUS             RESTARTS   AGE
chaos-01-imagepull-678db94958-hk545   0/1     ImagePullBackOff   0          45s     (at ~15 s: ErrImagePull)

Events:
  Normal   Pulling    30s (x2 over 45s)  kubelet  Pulling image "orderflow/order-api:v99.9.9"
  Warning  Failed     28s (x2 over 42s)  kubelet  Failed to pull image "orderflow/order-api:v99.9.9": failed to pull and unpack image "docker.io/orderflow/order-api:v99.9.9": failed to resolve reference "docker.io/orderflow/order-api:v99.9.9": pull access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed
  Warning  Failed     28s (x2 over 42s)  kubelet  Error: ErrImagePull
  Normal   BackOff    14s (x2 over 42s)  kubelet  Back-off pulling image "orderflow/order-api:v99.9.9"
  Warning  Failed     14s (x2 over 42s)  kubelet  Error: ImagePullBackOff
```
- **Root cause:** tag `v99.9.9` does not exist. **The message is misleading**: "pull access denied ... may require authorization" is what Docker Hub produces for a missing repository/tag, because it cannot distinguish "missing" from "private". An honest registry says `manifest unknown`/`not found`.
- **Fix:** `kubectl set image deployment/chaos-01-imagepull order-api=orderflow/order-api:v1 -n orderflow` → new pod `1/1 Running` in 15 s (image already on the node).
- **Exit code:** none: no container was ever created, RESTARTS stays 0.

### Scenario 2: CrashLoopBackOff (`scenario=crashloop`, `PORT=notanumber`)
```text
$ kubectl get pods -n orderflow -l scenario=crashloop
NAME                                  READY   STATUS             RESTARTS      AGE
chaos-02-crashloop-59c9764b68-x2772   0/1     CrashLoopBackOff   3 (23s ago)   61s      (earlier: STATUS Error)

$ kubectl logs -l scenario=crashloop -n orderflow --previous
2026/10/06 15:08:41 invalid PORT "notanumber": not a number: strconv.Atoi: parsing "notanumber": invalid syntax

    Last State:     Terminated
      Reason:       Error
      Exit Code:    1
      Started:      Tue, 06 Oct 2026 22:08:41 +0700
      Finished:     Tue, 06 Oct 2026 22:08:41 +0700
      PORT:  notanumber
Events:
  Normal   Pulled   4s (x5 over 89s)  kubelet  Container image "orderflow/payment-service:v1" already present on machine
  Normal   Started  4s (x5 over 89s)  kubelet  Started container payment-service
  Warning  BackOff  4s (x7 over 88s)  kubelet  Back-off restarting failed container payment-service in pod ...
```
- **Root cause:** the app validates `PORT`, calls `log.Fatalf`, exits **1**. The process ran, so there are logs.
- **Fix:** `kubectl set env deployment/chaos-02-crashloop PORT- -n orderflow` → `1/1 Running`, log `payment-service listening on port 8081`.
- **Gotchas:** the restart counter went 0 → 3 in 60 s, then slows (10 s, 20 s, 40 s ... back-off). Once `--previous` printed `unable to retrieve container logs for containerd://...` when run during a container swap; the retry worked.

### Scenario 3: StartError / RunContainerError (`scenario=starterror`)
```text
$ kubectl get pods -n orderflow -l scenario=starterror
NAME                                   READY   STATUS              RESTARTS     AGE
chaos-03-starterror-7b49fb554d-k5pqg   0/1     RunContainerError   3 (8s ago)   45s     (later: CrashLoopBackOff)

$ kubectl logs -l scenario=starterror -n orderflow --previous
(empty)

    Last State:     Terminated
      Reason:       StartError
      Message:      failed to create containerd task: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: exec: "/nonexistent-binary": stat /nonexistent-binary: no such file or directory
      Exit Code:    128
      Started:      Thu, 01 Jan 1970 08:00:00 +0800
Events:
  Warning  Failed   8s (x4 over 44s)  kubelet  Error: failed to create containerd task: ... exec: "/nonexistent-binary": stat /nonexistent-binary: no such file or directory
  Warning  BackOff  8s (x4 over 43s)  kubelet  Back-off restarting failed container payment-service in pod ...
```
- **Root cause:** `command: ["/nonexistent-binary", "--run"]` overrides the image's entrypoint with a path that is not in the (distroless) image. The runtime fails before any process exists: **exit 128, no logs**, `Started` is the epoch placeholder. Compare Scenario 2 (exit 1, logs).
- **Fix:** remove `command:` (the image's `ENTRYPOINT ["/app/server"]` runs) or use the right path.

### Scenario 4: OOMKilled (`scenario=oomkill`)
`order-api` with `ENABLE_DEBUG_ALLOC=1`, limit `64Mi`; a `curlimages/curl` container in the same pod calls `/debug/alloc?mb=100` every 10 s.
```text
chaos-04-oomkill-8469cb9c6d-pc4sz   2/2   Running            0              12s
chaos-04-oomkill-8469cb9c6d-pc4sz   1/2   OOMKilled          1 (13s ago)    24s
chaos-04-oomkill-8469cb9c6d-pc4sz   2/2   Running            2 (15s ago)    36s
chaos-04-oomkill-8469cb9c6d-pc4sz   1/2   OOMKilled          2 (27s ago)    48s
chaos-04-oomkill-8469cb9c6d-pc4sz   1/2   CrashLoopBackOff   2 (19s ago)    60s
chaos-04-oomkill-8469cb9c6d-pc4sz   2/2   Running            3 (31s ago)    72s
...                                 1/2   OOMKilled          4 (61s ago)    2m13s

    Last State:     Terminated
      Reason:       OOMKilled
      Exit Code:    137

$ kubectl get pod ... -o jsonpath='{...lastState.terminated.reason} {...exitCode}'
OOMKilled 137
$ kubectl logs -l scenario=oomkill -c order-api -n orderflow --previous
2026/10/06 15:12:07 order-api listening on port 8080
```
Kernel side, from the node (Step 11):
```text
[10841.940570] Memory cgroup out of memory: Killed process 93853 (server) total-vm:1362900kB, anon-rss:65036kB, file-rss:5324kB, shmem-rss:0kB, UID:65532 pgtables:212kB oom_score_adj:996
```
- **Root cause:** the process was asked to hold 100 MiB inside a 64 MiB cgroup; the kernel OOM killer sent SIGKILL (137 = 128 + 9). The sidecar keeps calling, so every restart dies again.
- **What is absent:** no `OOMKilled` Event, nothing in the log (SIGKILL cannot be handled); `dmesg` is not in `kubectl get events`.
- **Fix** (for a real case): find the cause (leak vs. undersized), set `GOMEMLIMIT` to ~80-90% of the limit, then raise `resources.limits.memory`. Here the "fix" is deleting the trigger.

### Scenario 5: CreateContainerConfigError (`scenario=missing-config`)
```text
$ kubectl get pods -n orderflow -l scenario=missing-config
NAME                                       READY   STATUS                       RESTARTS   AGE
chaos-05-missing-config-6b6cd57b6d-tkz4r   0/1     CreateContainerConfigError   0          30s

      LOG_LEVEL:  <set to the key 'LOG_LEVl' of config map 'chaos-app-config'>  Optional: false
  Warning  Failed  3s (x4 over 30s)  kubelet  Error: couldn't find key LOG_LEVl in ConfigMap orderflow/chaos-app-config
$ kubectl get configmap chaos-app-config -n orderflow -o jsonpath='{.data}'
{"LOG_LEVEL":"info"}
```
- **Root cause:** the ConfigMap exists, the **key** does not (typo `LOG_LEVl`). The kubelet cannot build the environment: the container never starts (RESTARTS 0, no exit code, no logs).
- **Fix:** patch the data (`{"data":{"LOG_LEVl":"info"}}`) or correct the pod's key. After the patch the same pod became `1/1 Running` within 25 s without being recreated: the kubelet retries. A missing ConfigMap/Secret *object* gives the same STATUS with `configmap "x" not found`.

### Scenario 6: Pending (`scenario=pending`)
```text
NAME                                READY   STATUS    RESTARTS   AGE   IP       NODE     ...
chaos-06-pending-8577f45559-wdh4r   0/1     Pending   0          10s   <none>   <none>

Events:
  Warning  FailedScheduling  10s  default-scheduler  0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory. no new claims to deallocate, preemption: 0/1 nodes are available: 1 Preemption is not helpful for scheduling.

Allocatable:
  cpu:                8
  ephemeral-storage:  61202244Ki
```
- **Root cause:** requests `cpu: 128`, `memory: 256Gi` vs. 8 CPUs allocatable (your Docker Desktop VM size sets this number). The scheduler binds by **requests** only. No container events exist because nothing was ever created.
- **Fix:** `kubectl set resources deployment/chaos-06-pending -n orderflow --requests=cpu=50m,memory=32Mi` → `1/1 Running` in 10 s.

### Scenario 7: DNS failure (`scenario=dns` + `scenario=dns-fix`)
```text
$ kubectl get pods -n orderflow -l scenario=dns
NAME                            READY   STATUS    RESTARTS   AGE
chaos-07-dns-78ddfdb5fc-pdwth   2/2     Running   0          22s

$ kubectl logs -l scenario=dns -c order-api -n orderflow --tail=2
... [order-api] call to /notify failed for order 35991cd2305c5955: Post "http://orderflow-notification:8082/notify": context deadline exceeded (Client.Timeout exceeded while awaiting headers)
... [order-api] call to /payments failed for order 35991cd2305c5955: Post "http://orderflow-payment:8081/payments": context deadline exceeded (Client.Timeout exceeded while awaiting headers)

$ kubectl logs $POD -n orderflow -c dns-dbg          # ephemeral netshoot container
search orderflow.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.96.0.10
options ndots:5
;; communications error to 10.96.0.10#53: timed out
;; no servers could be reached

nslookup rc=1
curl: (28) Resolving timed out after 3003 milliseconds
curl rc=28
```
After `kubectl apply -f ... -l scenario=dns-fix`:
```text
(order-api log, --since=10s: no new failures)
;; Got recursion not available from 10.96.0.10     (harmless CoreDNS noise)
Server:		10.96.0.10
** server can't find orderflow-paymnt: NXDOMAIN
{"status":"ok","service":"payment-service"}
```
- **Root cause:** `chaos-dns-deny-egress` selects the pods and has `policyTypes: [Egress]` with **no rules**: nothing may leave, including UDP/TCP 53 to CoreDNS. The pod stays Running/Ready (kubelet probes originate on the node; loopback traffic from the curl sidecar is never filtered), so nothing looks wrong until you read the app log.
- **Why the app log is not explicit:** order-api's 3 s client timeout fires during name resolution, so Go reports `context deadline exceeded`, not `no such host`. The debug container, sharing the pod's network namespace and therefore subject to the same policy, shows the truth: `timed out` to `10.96.0.10#53`.
- **Two different DNS signals:** *timeout* = DNS unreachable (this scenario); *NXDOMAIN / `lookup ... no such host`* = DNS reachable, name wrong (the `orderflow-paymnt` typo above). On one earlier run, in the seconds while the allow policy was converging, order-api logged `dial tcp: lookup orderflow-payment on 10.96.0.10:53: no such host`; it disappeared on its own.
- **Fix:** `chaos-dns-allow-egress`: UDP+TCP 53 to `kube-system` pods `k8s-app=kube-dns`, plus `app=payment-service:8081` and `app=notification-service:8082`.
- **Needs** NetworkPolicy enforcement (kindnet here: yes; Docker Desktop kubeadm provisioner: no).

### Scenario 8: Service without endpoints → Gateway 503 (`scenario=selector`)
```text
$ kubectl get pods -n orderflow -l scenario=selector
chaos-08-selector-759d6d6595-d856d   1/1   Running   0   40s
$ kubectl get endpointslices -n orderflow -l kubernetes.io/service-name=chaos-08-selector
NAME                      ADDRESSTYPE   PORTS     ENDPOINTS   AGE
chaos-08-selector-b64gr   IPv4          <unset>   <unset>     40s

$ curl -s -i http://localhost/chaos-selector
HTTP/1.1 503 Service Unavailable
date: Tue, 06 Oct 2026 15:16:03 GMT
content-length: 0

Accepted=True Accepted
BackendsAvailable=False EndpointsNotFound
ResolvedRefs=True ResolvedRefs
```
Envoy access log line for that request: `"response_code":503,"response_code_details":"direct_response","upstream_cluster":null`, i.e. Envoy answered itself; no upstream was ever contacted. The route status text: `Failed to find endpoints: no ready endpoints for the related Service orderflow/chaos-08-selector.`
- **Root cause:** Service selector `app: chaos-08-typo`, pod label `app: chaos-08`.
- **Fix:** `kubectl patch service chaos-08-selector -n orderflow -p '{"spec":{"selector":{"app":"chaos-08"}}}'` → within seconds `HTTP/1.1 200 OK`, `{"status":"ok","service":"order-api"}` (the route rewrites the path to `/health`).

### Scenario 9: Readiness failing (`scenario=readiness`)
```text
chaos-09-readiness-856cc4c749-zxwh9   0/1   Running   0   41s
$ kubectl get endpointslices ... -o jsonpath='{.items[0].endpoints[0].conditions}'
{"ready":false,"serving":false,"terminating":false}
    Readiness:    http-get http://:8080/readyz delay=0s timeout=1s period=5s #success=1 #failure=3
  Warning  Unhealthy  3s (x9 over 39s)  kubelet  Readiness probe failed: HTTP probe failed with statuscode: 404
```
- **Root cause:** the probe path `/readyz` does not exist (the app serves `/ready`); liveness `/health` passes, so the pod is never restarted, just never Ready. The EndpointSlice lists the address with `ready: false`; callers via the Service get nothing (`curl: (7) Failed to connect`).
- **Fix:** patch the probe path to `/ready` → `1/1` in ~20 s.
- **Through the Gateway it still answers 200 (Envoy panic routing).** With the route attached (rewrite to `/health`): `200 200 200 200 200 200 200 200 200 200`, and the Envoy access log shows `"upstream_host":"10.244.0.227:8080"`, the not-ready pod. In-cluster via the Service: `curl: (7) Failed to connect ... Could not connect to server`. Envoy Gateway passes the not-ready endpoint to Envoy as a non-healthy host; below the panic threshold (default 50% healthy) Envoy fails open and balances across **all** hosts. So the Gateway is not a readiness gate: verify with EndpointSlices and an in-cluster call.

### Scenario 9c: one ready replica behind the same Service (`scenario=readiness-ready`)
```text
NAME                                  READY   STATUS    RESTARTS   AGE   IP
chaos-09-readiness-856cc4c749-l2cs2   0/1     Running   0          59s   10.244.0.227
chaos-09c-ready-6c96989cf9-w2cf9      1/1     Running   0          10s   10.244.0.228
10.244.0.227 ready=false
10.244.0.228 ready=true

$ (30 curls to /chaos-readiness, then count upstream_host in the Envoy access log)
  30 "upstream_host":"10.244.0.228:8080"
```
1 of 2 hosts healthy = 50%, not below the threshold: no panic, **all 30 requests went to the ready pod**, none to the unready one. (Allow ~30 s after the pod turns Ready for the change to reach Envoy, and ~10 s for the access log to flush; counting too early still shows the old pod.) Day 6 implication: a single-replica Deployment cannot rely on readiness to stop gateway traffic; keep at least 2 replicas.

### Step 10 answer
Exit codes seen: Scenario 2 → 1 (app), Scenario 3 → 128 (runtime), Scenario 4 → 137 (SIGKILL by OOM). Scenarios 1, 5, 6 have **no container** and therefore no exit code; Scenarios 7, 8, 9 have healthy or merely not-Ready processes (no exit code at all). The STATUS column alone: `ErrImagePull/ImagePullBackOff`, `CrashLoopBackOff`/`Error`, `RunContainerError`, `OOMKilled`, `CreateContainerConfigError`, `Pending`, and for 7-9 **`Running`**, which is why those need the logs/EndpointSlice/route status.

---

## Part 3: Ephemeral containers, `--copy-to`, node debugging (Step 11)

Non-root pod, ephemeral container with the default `general` profile:
```text
uid=65532 gid=65532 groups=65532
PID   USER     TIME  COMMAND
    1 65532     0:00 /app/server
   33 65532     0:00 sh -c id; ps aux; tcpdump -i any -c 1 -nn port 8080
tcpdump: any: You don't have permission to perform this capture on that device
(Attempt to create packet socket failed - CAP_NET_RAW may be required)
```
- `--target=order-api` shares the target's process namespace (PID 1 is `/app/server`) and, as always, the network namespace.
- `--profile=netadmin` (adds `NET_ADMIN`, `NET_RAW`) **did not help** while the pod-level `runAsUser: 65532` applied: `CapEff: 0000000000000000` (a non-root process starts with an empty effective set). Root plus the capability worked, via `--custom` JSON (`{"securityContext":{"runAsUser":0,"runAsNonRoot":false,"capabilities":{"add":["NET_RAW","NET_ADMIN"]}}}`):
```text
0
listening on lo, link-type EN10MB (Ethernet), snapshot length 262144 bytes
15:17:38.758355 IP 127.0.0.1.50724 > 127.0.0.1.8080: Flags [S], ...
15:17:38.758375 IP 127.0.0.1.8080 > 127.0.0.1.50724: Flags [S.], ...
15:17:38.758467 IP 127.0.0.1.50724 > 127.0.0.1.8080: Flags [P.], ... HTTP: GET /ready HTTP/1.1
4 packets captured
```
- Under the **`restricted`** Pod Security label the same request is rejected: `violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false ..., unrestricted capabilities ... must not include "NET_ADMIN", "NET_RAW", "SYS_PTRACE", runAsNonRoot != true, runAsUser=0`. `--profile=restricted` works (uid 65532, `ps` works, no raw sockets). Ephemeral containers **cannot be removed**; a rejected one still left earlier ones in the spec, and every later attempt failed PSA until the pod was deleted.

`--copy-to`:
```text
$ kubectl get pods -n orderflow -l scenario=crashloop
chaos-02-crashloop-59c9764b68-db2pt   0/1   CrashLoopBackOff   2 (20s ago)   36s
$ kubectl get pod crash-debug -n orderflow
crash-debug   1/1   Running   0   10s
$ kubectl exec crash-debug -n orderflow -- sh -c 'env | grep ^PORT='
PORT=notanumber
```
The copy carries no labels (not selected by `-l scenario=crashloop`, not adopted by the Deployment). Without `--profile`, kubectl 1.32 (this run) warns `--profile=legacy is deprecated`; from kubectl 1.36 the default is `general`. `general` adds `SYS_PTRACE`, which Pod Security `baseline`/`restricted` reject, so in such namespaces pass `--profile=baseline` or `--profile=restricted`.

Node debugging (`kubectl debug node/desktop-control-plane -n orderflow --image=busybox:1.37 --profile=sysadmin`; the pod lands in the namespace you give, `Completed`, delete it):
```text
[10841.940570] Memory cgroup out of memory: Killed process 93853 (server) total-vm:1362900kB, anon-rss:65036kB, file-rss:5324kB, shmem-rss:0kB, UID:65532 pgtables:212kB oom_score_adj:996
2026-10-06T15:00:07.345586Z stderr F 2026/10/06 15:00:07 order-api listening on port 8080
```
The second line is the **CRI log format** on disk (`/var/log/pods/<ns>_<pod>_<uid>/<container>/<restart#>.log`): timestamp, stream, `F`/`P` (full/partial), message. Not JSON. (JSON is the old Docker `json-file` driver; log shippers parse CRI, then optionally JSON *inside* the message.)

---

## Part 4: Strategic architecture decisions (Step 12)

### A: Seed-stage startup (5 services, 3 engineers, pure AWS)
**ECS on Fargate.** Product velocity is existential; EKS adds control-plane cost (~$73/month per cluster at standard pricing), version upgrades, add-on upkeep (CNI, CSI, LB controller) and Helm/YAML surface with no payoff at this size. ECS gives task IAM roles, ALB integration, Cloud Map/Service Connect discovery and no node ops. EKS Auto Mode lowers the node burden but not the Kubernetes API/learning burden. Revisit if the service count or platform needs (CRDs/operators, multi-cloud) grow.

### B: Enterprise fintech (30 services, 20+ engineers, PCI-DSS with mTLS, hybrid plan)
**Kubernetes (EKS).** A dedicated platform team (2-3) pays for itself at this scale; you need default-deny NetworkPolicy, workload identity (EKS Pod Identity), and an mTLS story. For **auditable mTLS workload identity** (the PCI requirement) use Istio (sidecar or ambient) or Linkerd. Cilium is the CNI choice for NetworkPolicy and transparent encryption (WireGuard/IPsec), not for identity: its mutual authentication is still Beta (disabled by default in 1.19, with the direction pointing at a ztunnel-based integration). Pick one identity control and prove it with policy and certificate-rotation evidence. Node strategy: Karpenter (or **EKS Auto Mode**, which bundles Karpenter-style provisioning plus managed core add-ons) to cut node operations while keeping the Kubernetes API. Hybrid plan: Kubernetes manifests/Gateway API/Helm/GitOps travel; ECS does not. "Kubernetes is the only portable runtime" is too strong (Nomad, plain VMs exist); it is the one with the broadest portable ecosystem.

### C: Monolith migration (8 services, 8 engineers, pure AWS, GitHub Actions)
**ECS on Fargate, with a review gate** at ~15-20 services or the first need for CRDs/operators/advanced scheduling. The team is already absorbing a decomposition; do not add cluster operations. The pipeline (build image → push to ECR → update service) maps directly onto ECS.

### D: The gateway engineer's questions
**(a) Where to rate-limit.** Layered, by what each layer can identify:
- **Edge gateway** (Envoy Gateway `BackendTrafficPolicy` rate limit, or AWS WAF/ALB): per-client/API-key/IP/route limits on *external* traffic, before it consumes any capacity. The default place for abuse and fairness. Global (shared counter via a rate-limit service) when limits must be exact across replicas; local (per-proxy token bucket) when approximate and cheap is fine.
- **Mesh** (sidecar/ambient/waypoint policy): service-to-service limits and quotas between *internal* callers; protects a dependency from a noisy neighbour; identity comes from the mTLS identity, not an API key.
- **App:** business rules the proxies cannot see (per-tenant plan limits, per-resource locks, expensive-operation budgets) and load shedding (return 429/503 early when saturated). The app is the last line of defence, so keep it even when proxies limit.
Do not rate-limit only in the app: the request already cost you a connection, a goroutine and a TLS handshake.

**(b) Retries and timeouts.** Timeouts at every hop, set *shorter downstream than upstream* (client 3 s → gateway 5 s → user 10 s) so work is abandoned rather than piled up. Retries only for idempotent calls (GET, or POST with an idempotency key), with exponential backoff + jitter, a small attempt count, and a **retry budget** (e.g. retries may add at most 10-20% extra requests per upstream; Envoy `retry_budget`, Linkerd retry budgets) so a failing dependency is not hit with 3-4x the load. Where: the mesh/gateway gives uniform policy without code changes (HTTPRoute `timeouts` is Standard channel; `retry` (GEP-1731) and retry budgets are still Experimental, so with Envoy Gateway retries come from `BackendTrafficPolicy.retry`); in-app gives per-call knowledge (idempotency, partial results). Never stack all layers blindly: three layers retrying 3 times is 27 attempts. **Circuit breaking** (max connections/pending requests, outlier detection that ejects failing hosts) complements retries by failing fast.

**(c) Canary with the Gateway API.** Day 4 `httproute-canary.yaml`: two `backendRefs` with `weight: 90` / `10` (weights are relative, not percentages) and a header match (`x-canary: true`) to force the canary for testers. Promote by editing weights (5 → 25 → 50 → 100) and watching RED metrics per backend. A mesh adds: weights per *service-to-service* hop (not just the edge), automated progressive delivery with metric analysis (Argo Rollouts/Flagger drive HTTPRoute weights), and mTLS-identity-aware policies. The edge gateway alone covers north-south canaries.

---

## Part 5: Observability vocabulary check
- **USE** (per resource: node, disk, NIC): utilization, saturation, errors. **RED** (per request-driven service): rate, errors, duration. The four golden signals add *saturation* to RED. Use RED for `order-api`, USE for the node and the Postgres volume.
- Where each signal lives: **metrics** in metrics-server (in memory, latest sample only, for `kubectl top`/HPA) or Prometheus (time series, you retain); **logs** in files on the node (CRI format), shipped by a DaemonSet; **events** are API objects stored in **etcd** with a short TTL (~1 h): great for "what just happened", never an audit trail or a log store.

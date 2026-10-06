# Kubernetes Production Incident Debugging Runbook

Standard triage protocol for container failure alerts on the OrderFlow platform. Every signal below was observed live in the Day 7 lab (Docker Desktop, kind provisioner, Kubernetes 1.34). Commands assume namespace `orderflow`; replace as needed. After the lab, append your own findings to the **Incident log** at the end.

---

## Rule 0: capture before you touch

```bash
kubectl get pods -n <ns> -o wide
kubectl describe pod <pod> -n <ns> > /tmp/describe.txt
kubectl logs <pod> -n <ns> --all-containers --previous > /tmp/logs-previous.txt 2>&1
kubectl get events -n <ns> --sort-by=.metadata.creationTimestamp
```
Deleting or restarting the pod first destroys `Last State`, the previous logs and the Events (Events live ~1 h by default, in etcd, and are not an audit log).

## Incident triage protocol

```
1. kubectl get pods -n <ns> -o wide                      → what is the STATUS and READY column?
2. Categorize:
   ├── ImagePullBackOff / ErrImagePull        ──► Section 1
   ├── CrashLoopBackOff / Error  (exit 1)     ──► Section 2
   ├── RunContainerError / StartError (128)   ──► Section 3
   ├── OOMKilled (exit 137)                   ──► Section 4
   ├── CreateContainerConfigError             ──► Section 5
   ├── Pending (NODE <none>)                  ──► Section 6
   ├── Running but calls fail / timeouts      ──► Section 7 (DNS, NetworkPolicy)
   ├── Running 1/1 but Gateway answers 5xx    ──► Section 8 (no endpoints, 503/504)
   ├── Running 0/1 (not Ready)                ──► Section 9 (readiness)
   └── Everything times out after a policy change ──► Section 10 (kindnet wedge)
3. Exit code? → table below.
```

## Exit-code table (`Last State: Terminated ... Exit Code:`)

| Code | Meaning | Typical cause in this course | Where to look |
|:--|:--|:--|:--|
| 0 | Process exited normally | Job finished; app exited on its own (a Deployment pod that exits 0 is still restarted) | `logs`; is it supposed to be long-running? |
| 1 | Application error | `log.Fatalf("invalid PORT ...")`, uncaught exception | `logs --previous` |
| 126 | Command found but not executable | Wrong file mode, wrong architecture binary, a directory as `command` | Last State message |
| 127 | Command not found (reported by a shell) | A shell command calling a missing tool, e.g. container `command: ["sh","-c","missing-tool"]`, or an entrypoint script. An exec-form entry that is itself missing never reaches a shell: under runc it is 128 / `StartError` | `logs` (`sh: missing-tool: not found`); image contents |
| 128 | Container could not be started by the runtime | Missing binary in `command:` of a distroless image (`StartError`): **no process ever ran, no logs** | Last State `Message:`, Events |
| 137 | 128 + 9 (SIGKILL) | **OOMKilled** (Reason says so) or killed after the grace period expired, or `kill -9` | `Reason`; node `dmesg` |
| 143 | 128 + 15 (SIGTERM) | The process received SIGTERM (rollout, delete, eviction) and did **not** handle it. An app that handles SIGTERM and exits cleanly (like OrderFlow's drain) shows `0` / `Completed` instead | Normal for a stop; abnormal only if restarts are unexpected |

`Reason` can be more specific than the code: `Error` (exit != 0), `OOMKilled`, `StartError`, `Completed`. Always read both. A non-zero code from a *runtime* failure (126-128) means the app never started; from the *app* (1, 2...) means it ran.

---

## Section 1: ImagePullBackOff / ErrImagePull

**Symptom:** STATUS `ErrImagePull` → `ImagePullBackOff`; READY `0/1`; RESTARTS 0 (the container never existed).

**Diagnosis**
```bash
kubectl describe pod <pod> -n <ns> | grep -A 12 '^Events:'
kubectl get deploy <name> -n <ns> -o jsonpath='{.spec.template.spec.containers[*].image}{"\n"}'
```
Observed: `Failed to pull image "orderflow/order-api:v99.9.9": ... pull access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed`.

**The wording lies.** For a *missing tag* on Docker Hub the registry answers with an authorization error, so containerd cannot tell "does not exist" from "private". Message → meaning:
- `pull access denied ... may require authorization` → tag/repo typo **or** missing `imagePullSecrets`. Verify the spelling first.
- `manifest unknown` / `not found` → tag does not exist (registries that answer honestly, e.g. ECR).
- `toomanyrequests` → Docker Hub rate limit; use a mirror/ECR pull-through cache.
- On the kind provisioner, a **locally built** image `orderflow/x:v1` not loaded into the node gives the same error → `bash labs/shared/load-images.sh`.

**Fix:** `kubectl set image deployment/<name> <container>=<repo>:<good-tag> -n <ns>`; private registry: `kubectl create secret docker-registry regcred --docker-server=<registry> --docker-username=<user> --docker-password=<pass> -n <ns>` and `imagePullSecrets: [{name: regcred}]`.

**Prevention:** immutable tags or digests; CI verifies the image exists before the manifest is updated; admission policy blocks `:latest`.

---

## Section 2: CrashLoopBackOff (the app ran and died)

**Symptom:** STATUS `Error` then `CrashLoopBackOff`; RESTARTS climbing; `Exit Code: 1`.

**Diagnosis**
```bash
kubectl logs <pod> -n <ns> --previous            # the fatal line is here
kubectl describe pod <pod> -n <ns> | grep -E -A5 'Last State:|Environment:'
```
Observed: `invalid PORT "notanumber": not a number: strconv.Atoi: parsing "notanumber": invalid syntax`, `Reason: Error`, `Exit Code: 1`, `PORT: notanumber`.

**Notes**
- `--previous` can print `unable to retrieve container logs for containerd://...` if you ask while the kubelet is swapping containers: retry.
- The restart counter goes up by **one** per restart. The *delay* doubles: 10 s, 20 s, 40 s ... capped at 5 min, reset after 10 min of running. In `Waiting/CrashLoopBackOff` you wait; it does not mean the restarts speed up.
- Cannot get a shell (distroless)? `kubectl debug <pod> --copy-to=dbg --container=<c> --image=busybox:1.37 --profile=general -- sleep 3600`, then `kubectl exec dbg -- env`. The copy has no labels, so it is not selected by the Service or ReplicaSet.

**Fix:** correct the env/config (`kubectl set env deployment/<name> PORT-`). **Prevention:** validate config at start and fail fast with a clear message (as OrderFlow does); readiness gates keep a bad rollout from taking traffic.

---

## Section 3: RunContainerError / StartError (exit 128, no logs)

**Symptom:** STATUS `RunContainerError` (later `CrashLoopBackOff`); `logs --previous` is **empty**.

**Diagnosis**
```bash
kubectl describe pod <pod> -n <ns> | grep -E -A5 'Last State:'
kubectl describe pod <pod> -n <ns> | grep '^  Warning'
```
Observed: `Reason: StartError`, `Exit Code: 128`, `exec: "/nonexistent-binary": stat /nonexistent-binary: no such file or directory`, Started `Thu, 01 Jan 1970`.

This is **not** a crashing app: the runtime (runc) could not `exec` the entrypoint. Causes: wrong `command:`/`args:` path, binary for the wrong architecture (`exec format error`), non-executable file (126), a `command` copied from a shell-based image into a distroless one. **Fix:** remove or correct `command:`. **Prevention:** do not override `command` unless you must; test the exact image with `docker run --entrypoint`.

---

## Section 4: OOMKilled (exit 137)

**Symptom:** STATUS `OOMKilled` / `CrashLoopBackOff`; `Last State: Terminated, Reason: OOMKilled, Exit Code: 137`; the previous log just ends (SIGKILL).

**Diagnosis**
```bash
kubectl describe pod <pod> -n <ns> | grep -E -B1 -A5 'Last State:'
kubectl top pod <pod> -n <ns> --containers       # current usage vs limit
kubectl debug node/<node> -n <ns> --image=busybox:1.37 --profile=sysadmin -- sh -c 'chroot /host dmesg | grep -i "killed process"'
```
Observed kernel line: `Memory cgroup out of memory: Killed process <pid> (server) ... anon-rss:65036kB ... UID:65532 ... oom_score_adj:996`. **There is no OOMKilled Event** and `dmesg` is not in `kubectl get events`; the proof is the container status and the node kernel log (delete the `node-debugger-*` pod afterwards). `anon-rss` ≈ the limit (64 Mi).

**Fix:** find *why* (leak vs undersized): profile; `GOMEMLIMIT` ~80-90% of the limit (the Go runtime does not read the cgroup limit); set requests == limits for memory on important pods; then raise the limit. **Prevention:** load test at the limit, alert on `container_memory_working_set_bytes / limit > 0.9`, VPA recommendations.

---

## Section 5: CreateContainerConfigError

**Symptom:** STATUS `CreateContainerConfigError`; RESTARTS 0.

**Diagnosis**
```bash
kubectl describe pod <pod> -n <ns> | grep -E 'Reason:|Error:|Warning'
kubectl get configmap,secret -n <ns>
kubectl get configmap <name> -n <ns> -o jsonpath='{.data}{"\n"}'
```
Observed: `Error: couldn't find key LOG_LEVl in ConfigMap orderflow/chaos-app-config` (object exists, **key** missing). If the object is missing: `configmap "x" not found` / `secret "x" not found`. Other causes: `runAsNonRoot` with a non-numeric image `USER` (`container has runAsNonRoot and image has non-numeric user`).

**Fix:** correct the key or create/patch the object; the kubelet retries by itself (pod went `1/1` without being recreated). `optional: true` on the reference silences it (use deliberately). **Prevention:** `helm template | kubectl apply --dry-run=server` and a render-time check; avoid hand-typed keys.

---

## Section 6: Pending (never scheduled)

**Symptom:** STATUS `Pending`; `NODE <none>`; no container events at all.

**Diagnosis**
```bash
kubectl describe pod <pod> -n <ns> | grep -A6 '^Events:'
kubectl describe node | grep -A6 -E '^Allocatable:|^Allocated resources:'
```
Observed: `FailedScheduling ... 0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory. ... Preemption is not helpful for scheduling.` Reads: `Insufficient cpu/memory` (requests too big), `didn't match Pod's node affinity/selector`, `had untolerated taint`, `unbound immediate PersistentVolumeClaims`, `didn't satisfy topology spread`. Scheduling uses **requests**, not usage or limits.

**Fix:** right-size requests, fix selector/tolerations, bind the PVC; with Karpenter / Cluster Autoscaler / EKS Auto Mode, "Insufficient" triggers a new node (not on this cluster). **Prevention:** requests from measurements; PriorityClasses for critical pods.

---

## Section 7: Running, but calls fail: DNS and NetworkPolicy

**Symptom:** pod `Running`/Ready (kubelet probes are not pod traffic, so egress policy does not affect them) but calls to peers fail: app log `context deadline exceeded (Client.Timeout exceeded while awaiting headers)`, or `lookup <svc> on 10.96.0.10:53: no such host`, or `connection refused`.

**Decide which of three failures it is**
| What you see | Meaning | Next |
|:--|:--|:--|
| `nslookup`: `communications error ... timed out` / curl `(28) Resolving timed out` | DNS **unreachable** from this pod: egress NetworkPolicy without UDP+TCP 53 to CoreDNS, CoreDNS down, kindnet wedge (Section 10) | `kubectl get netpol -n <ns>`; `kubectl get pods -n kube-system -l k8s-app=kube-dns` |
| `NXDOMAIN` / `no such host` | DNS reachable, **name wrong**: typo, wrong namespace, Service missing | `kubectl get svc -n <ns>`; use `<svc>.<ns>.svc.cluster.local` |
| Name resolves, curl `timed out` / `Connection refused` | DNS fine. Timeout: policy blocks the TCP port (or wedge); refused: nothing listening / no endpoints | `kubectl get endpointslices`, policies, port numbers |

**Diagnosis from inside the pod's network namespace** (app images are distroless; the output of a non-interactive `kubectl debug` goes to the container log):
```bash
POD=$(kubectl get pod -n <ns> -l <label> -o name | head -1)
kubectl debug $POD -n <ns> --image=nicolaka/netshoot --target=<container> --profile=general -q -c dns1 -- \
  sh -c 'cat /etc/resolv.conf; nslookup -timeout=2 <svc>.<ns>.svc.cluster.local; curl -sS -m 3 http://<svc>:<port>/health'
sleep 15; kubectl logs $POD -n <ns> -c dns1
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get netpol -n <ns>; kubectl describe netpol <name> -n <ns>
```
Observed with the egress-deny policy: `nameserver 10.96.0.10`, `options ndots:5`, `;; communications error to 10.96.0.10#53: timed out`, `curl: (28) Resolving timed out after 3003 milliseconds`. After allowing CoreDNS: `** server can't find orderflow-paymnt: NXDOMAIN` (typo) and `{"status":"ok","service":"payment-service"}` for the right name. Note `ndots:5`: a short name tries every search suffix first, multiplying queries (and timeouts); use the FQDN with a trailing dot in hot paths.

**Fix:** an egress policy must allow `UDP/TCP 53` to `kube-system` pods `k8s-app=kube-dns` (namespaceSelector AND podSelector in the **same** `to` element) plus the actual destinations (`labs/day07/manifests/chaos-scenarios.yaml`, `scenario=dns-fix`; Day 4 `networkpolicy-egress.yaml`). Policies are evaluated on pod IPs after Service DNAT, so allow pod selectors/ports, not ClusterIPs. **Prevention:** ship the DNS allow rule in the same change as any `default-deny` egress; CI test that resolves a name from a pod.
NetworkPolicy is enforced by kindnet on Docker Desktop's kind provisioner but **not** by the kubeadm provisioner; on EKS it needs the VPC CNI network policy feature, Calico or Cilium.

---

## Section 8: Gateway answers 503 / 504 (Envoy Gateway)

**Symptom:** `curl http://localhost/<path>` returns 5xx while the pods look fine.

**Diagnosis (outside in)**
```bash
curl -s -i http://localhost/<path>                      # who answered? headers, body, content-length
kubectl get httproute <name> -n <ns> -o jsonpath='{range .status.parents[0].conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
kubectl get svc <svc> -n <ns>; kubectl get endpointslices -n <ns> -l kubernetes.io/service-name=<svc>
kubectl get gateway -A; kubectl get pods -n envoy-gateway-system
kubectl logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=edge -c envoy --tail=5   # JSON access log: response_code, response_flags, response_code_details
```
| Gateway answer | Meaning | Check |
|:--|:--|:--|
| **503**, `content-length: 0`, access log `response_code_details: direct_response`, route condition `BackendsAvailable=False EndpointsNotFound` | The Service has **no endpoints at all** (selector typo, 0 replicas). Envoy Gateway answers itself; no pod was contacted. (An upstream cluster that exists but has *all* hosts unhealthy gives `503 UH` "no healthy upstream" instead.) | `kubectl get endpointslices`; compare Service `selector` with pod labels (`--show-labels`) |
| **200** from the app although the pods are `0/1` | **Envoy panic routing**: fewer than 50% of the Service's endpoints are healthy, so Envoy fails open and uses all of them | `kubectl get endpointslices` (`ready: false`); add ready replicas (Section 9) |
| 503 with `response_flags` `UF` / `URX` / `UH` | Upstream connection failure / retries exhausted / no healthy host | NetworkPolicy admitting the Envoy proxy namespace (`envoy-gateway-system`), pod crashing, port mismatch |
| **504** | Upstream did not answer within the route/request timeout | Slow dependency; app overloaded; HTTPRoute `timeouts.request`; an egress policy blocking the app's own downstream call |
| 404 from Envoy (empty body) | No route matched (path/host/headers, or route not `Accepted`, wrong `parentRefs`, `allowedRoutes`) | `kubectl get httproute` conditions `Accepted`, `ResolvedRefs` |
| 404 with a body like `404 page not found` | The request **reached the app**, which has no such path (a missing `URLRewrite`) | App routes |
| 500 / 502 | App error or reset connection | App logs, `logs --previous` |

Observed: selector typo → `HTTP/1.1 503 Service Unavailable`, `content-length: 0`, EndpointSlice `ENDPOINTS <unset>`, `Accepted=True`, `BackendsAvailable=False EndpointsNotFound`. Patching the Service selector turned the same URL to 200 within seconds.
**Envoy panic routing, not readiness enforcement:** with a pod that is Running `0/1` (EndpointSlice `ready: false`), Envoy Gateway v1.9.2 still sent requests to it (HTTP 200 from the app). Envoy Gateway passes the not-ready endpoint to Envoy as a *non-healthy* host; when fewer than the panic threshold (default 50%) of an upstream's hosts are healthy, Envoy **fails open** and load-balances across **all** hosts. Add one ready replica behind the same Service and traffic goes only to it (observed 30/30). So a single-replica or mostly-unready Service keeps receiving traffic. Verify readiness with `kubectl get endpointslices` and an in-cluster call, and keep at least 2 replicas.
**Prevention:** an HTTPRoute status alert (`BackendsAvailable=False`); selectors from one Helm helper; smoke test through the edge after every deploy.

---

## Section 9: Running 0/1: readiness failing

**Symptom:** `0/1 Running`, RESTARTS 0, no traffic (Service has no *ready* endpoints, in-cluster callers get `Connection refused`).

**Diagnosis**
```bash
kubectl describe pod <pod> -n <ns> | grep -E 'Readiness:|Unhealthy'
kubectl get endpointslices -n <ns> -l kubernetes.io/service-name=<svc> -o jsonpath='{.items[0].endpoints[0].conditions}{"\n"}'
```
Observed: `Readiness probe failed: HTTP probe failed with statuscode: 404` (probe path `/readyz`, app serves `/ready`), conditions `{"ready":false,"serving":false,"terminating":false}`. Via the gateway the route may still answer 200 (Envoy panic routing, Section 8). The pod is kept out of the Service by the EndpointSlice controller; the kubelet only reports the probe result. **Fix:** correct the probe path/port/timeouts; keep **liveness (`/health`, process alive) and readiness (`/ready`, can serve)** separate, otherwise a dependency blip restarts healthy pods. **Prevention:** a startupProbe for slow starters; test probes in the dev profile.

---

## Section 10: kindnet wedge: everything to policy-selected pods times out

**Symptom (Docker Desktop kind provisioner only):** after creating/deleting NetworkPolicies, *all* traffic to pods that ever had a policy is dropped, even with every policy deleted. Pods are Ready; probes pass (node-originated); pod-to-pod and Gateway traffic time out.

**Diagnosis:** `kubectl logs -n kube-system -l app=kindnet --tail=50` shows `Could not receive message error="netlink receive: no such file or directory"`.
**Fix (permitted in this course):** `kubectl rollout restart ds/kindnet -n kube-system` then `kubectl rollout status ds/kindnet -n kube-system`. Re-test. Not seen in every run; it is an environment bug, not an app bug. Rule of thumb: if the timeout survives deleting all policies, restart kindnet before debugging further.

---

## Incident log (append yours)

| Time | Scenario | STATUS seen | Command that gave the root cause | Root cause | Fix | Prevention |
|:--|:--|:--|:--|:--|:--|:--|
| | | | | | | |

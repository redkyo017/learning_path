# Day 7 Lab: Observability, Systematic Debugging & Strategic Synthesis

**Run every command from the course root** (`k8s_docker_mastery/`). Target cluster: Docker Desktop Kubernetes on the **kind provisioner** (context `docker-desktop`, node `desktop-control-plane`). Alternatives: Docker Desktop's *kubeadm* provisioner (node `docker-desktop`) sees local images directly (the `load-images.sh` step is a no-op) but does **not** enforce NetworkPolicy, so Step 8 (DNS) will not fail there; with plain `kind`, `load-images.sh` runs `kind load docker-image`, node name differs (use `kubectl get nodes`), and you reach the Gateway with the Day 4 port-forward fallback instead of `http://localhost`. Needs Helm 4 (`brew install helm`) and internet access for the node (`nicolaka/netshoot`, `curlimages/curl`, `busybox`, `postgres:16-alpine`).

## Start here — plain steps

1. Open a terminal in `k8s_docker_mastery/`. `kubectl config current-context` must print `docker-desktop`.
2. Run the **Prerequisites** (clean namespace, load images, check that `kubectl top nodes` works and the Gateway `edge` exists).
3. Install the Day 6 chart with the dev values (Step 1). You are done with this step when `curl http://localhost/orders` prints `[]` and `kubectl top pods` shows numbers.
4. Work through Steps 2-10, one failure each. The pattern is always the same: apply the scenario with `-l scenario=<name>`, wait the stated seconds, read **only the signals**, write the root cause in your incident log (end of `debug-runbook.md`), fix it, delete the scenario.
5. Step 11 is the ephemeral-container toolbox: `kubectl debug` with netshoot, why `tcpdump` fails in a non-root pod, `--copy-to`, and debugging the node itself.
6. Read [`debug-runbook.md`](./debug-runbook.md) (exit-code table, DNS, Gateway 503/504, kindnet wedge) and add a row per scenario to its incident log. Do Step 12 on paper and compare with [`SOLUTION.md`](./SOLUTION.md).
7. You are done when every "You should see" line matched. Run **Teardown** (it leaves the Gateway and metrics-server installed).

## Objective
Operate OrderFlow the way an on-call engineer does. Install the Day 6 chart as the "production" baseline, then break it nine different ways and diagnose each from signals only: the `STATUS` column, `Reason`, exit code, Events, `logs --previous`, the Gateway's answer. You also attach ephemeral debug containers to distroless pods, copy a crashing pod, debug a node, and finish with the architecture decision questions (including where a service mesh and rate limiting belong).

## Architecture

```
 Mac: curl http://localhost/<path>
   ▼
 Gateway edge (ns gateway-infra, Envoy proxies in envoy-gateway-system)
   ├─ /orders          → HTTPRoute orderflow (Day 6 chart) → Service orderflow-order-api
   └─ /chaos-selector  → HTTPRoute chaos-08-selector (this lab) → Service with a typo'd selector

 ns orderflow
   Day 6 release "orderflow" (dev values): order-api, payment, notification, postgres, migration Job
   chaos-01 .. chaos-09  one Deployment each; every object has label  scenario=<name>
```
Release naming: the Day 6 Services are `orderflow-order-api`, `orderflow-payment`, `orderflow-notification`. Scenario 7 calls the last two.

---

## Prerequisites

```bash
bash labs/shared/reset.sh                 # empty namespace orderflow (also removes a leftover Helm release)
bash labs/shared/load-images.sh           # builds orderflow/*:v1 and loads them into the node
kubectl top nodes                         # metrics-server installed? If not:
#   kubectl apply -f labs/shared/metrics-server.yaml && kubectl rollout status deploy/metrics-server -n kube-system --timeout=120s
kubectl get gateway edge -n gateway-infra # PROGRAMMED True. Missing? Day 4 Steps 2-3 install Envoy Gateway + labs/day04/manifests/gateway.yaml
```
*You should see: `loaded orderflow/<svc>:v1` three times; one node row with CPU/MEMORY (`kubectl top` needs about a minute after a fresh metrics-server install); `edge  eg  <address>  True`.* The shared `labs/shared/metrics-server.yaml` is metrics-server v0.9.0 with `--kubelet-insecure-tls` (needed on Docker Desktop/kind).

---

## Instructions

Pattern for Steps 2-9. `F` is the scenario file:
```bash
F=labs/day07/manifests/chaos-scenarios.yaml
```
(Every command block below assumes `F` is set in your shell. Set it once; if you open a new terminal, set it again.)

### Step 1: Baseline "production" release
```bash
helm install orderflow labs/day06/orderflow-chart -f labs/day06/orderflow-chart/values-dev.yaml -n orderflow --wait --timeout 300s
kubectl get pods -n orderflow
curl -s http://localhost/orders; echo
kubectl top pods -n orderflow
kubectl get apiservice v1beta1.metrics.k8s.io
```
*You should see: `orderflow-order-api` `2/2 Running` (native sidecar), payment/notification/postgres `1/1`, the migration Job `Completed`; `[]` from curl; CPU in millicores and memory in Mi per pod (a few Mi for the Go services, ~27Mi Postgres); `AVAILABLE True`.* If `kubectl top pods` says `metrics not available yet`, wait 30-60 s.

### Step 2: ImagePullBackOff
```bash
kubectl apply -f $F -l scenario=imagepull
sleep 45
kubectl get pods -n orderflow -l scenario=imagepull
kubectl describe pod -l scenario=imagepull -n orderflow | /usr/bin/grep -A 12 '^Events:'
```
*You should see: STATUS `ErrImagePull`, then `ImagePullBackOff`; Events with `Failed to pull image "orderflow/order-api:v99.9.9" ... pull access denied, repository does not exist or may require authorization`.* **The wording is misleading**: the tag simply does not exist (Docker Hub answers 401-style errors for unknown names, so the runtime cannot tell "missing" from "private"). Check the tag spelling before you hunt for credentials. Fix and clean up:
```bash
kubectl set image deployment/chaos-01-imagepull order-api=orderflow/order-api:v1 -n orderflow
sleep 15
kubectl get pods -n orderflow -l scenario=imagepull
kubectl delete -f $F -l scenario=imagepull
```
*You should see `1/1 Running` after the fix* (the image is already on the node, so no pull). Compare with runbook Section 1.

### Step 3: CrashLoopBackOff (the app starts and exits)
```bash
kubectl apply -f $F -l scenario=crashloop
sleep 60
kubectl get pods -n orderflow -l scenario=crashloop
kubectl logs -l scenario=crashloop -n orderflow --previous
kubectl describe pod -l scenario=crashloop -n orderflow | /usr/bin/grep -E -A4 'Last State:'
kubectl describe pod -l scenario=crashloop -n orderflow | /usr/bin/grep -E 'PORT:'
```
*You should see: STATUS `Error` then `CrashLoopBackOff`, RESTARTS climbing; the log line `invalid PORT "notanumber": not a number: strconv.Atoi: parsing "notanumber": invalid syntax`; `Last State: Terminated`, `Reason: Error`, `Exit Code: 1`; `PORT: notanumber` in the environment.* If `--previous` prints `unable to retrieve container logs for containerd://...`, you hit the moment the kubelet was replacing the container; run it again. Fix: `kubectl set env deployment/chaos-02-crashloop PORT- -n orderflow` (removes the variable; default port 8081), then `kubectl delete -f $F -l scenario=crashloop`. Runbook Section 2.

### Step 4: StartError — a *different* failure that looks similar
```bash
kubectl apply -f $F -l scenario=starterror
sleep 45
kubectl get pods -n orderflow -l scenario=starterror
kubectl logs -l scenario=starterror -n orderflow --previous
kubectl describe pod -l scenario=starterror -n orderflow | /usr/bin/grep -E -A5 'Last State:'
kubectl describe pod -l scenario=starterror -n orderflow | /usr/bin/grep -E '^  Warning'
```
*You should see: STATUS `RunContainerError` (later `CrashLoopBackOff` as the back-off kicks in); **empty** logs (or `previous terminated container ... not found`); `Reason: StartError`, `Exit Code: 128`, message `... exec: "/nonexistent-binary": stat /nonexistent-binary: no such file or directory`; Event `Error: failed to create containerd task ...`.* Compare with Step 3: there the process ran (exit 1, logs). Here the runtime could not exec anything, so there is nothing to log: no process, no `stderr`. Exit 128 is the runtime's, not the app's. Clean up: `kubectl delete -f $F -l scenario=starterror`. Runbook Section 3.

### Step 5: OOMKilled (exit 137)
The `order-api` image is distroless (no shell, no `curl`), so the pod carries a second container, `memory-hog-trigger` (`curlimages/curl`), that calls `localhost:8080/debug/alloc?mb=100` every 10 s. The route only exists because the scenario sets `ENABLE_DEBUG_ALLOC=1`. Limit: 64Mi.
```bash
kubectl apply -f $F -l scenario=oomkill
sleep 75
kubectl get pods -n orderflow -l scenario=oomkill
kubectl describe pod -l scenario=oomkill -n orderflow | /usr/bin/grep -E -B1 -A5 'Last State:'
kubectl get pod -l scenario=oomkill -n orderflow -o jsonpath='{.items[0].status.containerStatuses[?(@.name=="order-api")].lastState.terminated.reason}{" "}{.items[0].status.containerStatuses[?(@.name=="order-api")].lastState.terminated.exitCode}{"\n"}'
kubectl logs -l scenario=oomkill -c order-api -n orderflow --previous
```
*You should see: STATUS alternating between `OOMKilled` and `CrashLoopBackOff` (READY `1/2` or `2/2` while the new container is up; the trigger container never stops), RESTARTS growing every ~12 s at first, then slower as the back-off doubles; `Reason: OOMKilled`, `Exit Code: 137`; the previous log holds only `order-api listening on port 8080` (a SIGKILL leaves no goodbye).* Note what is **missing**: no `OOMKilled` Event. The proof is in the container status. The kernel's own line is on the node; Step 11 reads it with `kubectl debug node/`. Remediation for a *real* leak is profiling, then `GOMEMLIMIT` below the cgroup limit (Go does not read it), then the limit. If `logs --previous` says `unable to retrieve container logs`, wait a few seconds and retry. Clean up: `kubectl delete -f $F -l scenario=oomkill`.

### Step 6: CreateContainerConfigError
```bash
kubectl apply -f $F -l scenario=missing-config
sleep 30
kubectl get pods -n orderflow -l scenario=missing-config
kubectl describe pod -l scenario=missing-config -n orderflow | /usr/bin/grep -E 'LOG_LEVEL|Reason:|couldn'
kubectl get configmap chaos-app-config -n orderflow -o jsonpath='{.data}{"\n"}'
```
*You should see: STATUS `CreateContainerConfigError`, RESTARTS `0` (the container never started); `Error: couldn't find key LOG_LEVl in ConfigMap orderflow/chaos-app-config`; the ConfigMap holds `LOG_LEVEL`, not `LOG_LEVl`.* Fix the **data**, not the pod, and watch the kubelet retry on its own:
```bash
kubectl patch configmap chaos-app-config -n orderflow --type merge -p '{"data":{"LOG_LEVl":"info"}}'
sleep 25
kubectl get pods -n orderflow -l scenario=missing-config
kubectl delete -f $F -l scenario=missing-config
```
*You should see `1/1 Running` with no pod re-creation.* (A missing ConfigMap or Secret *object* gives the same STATUS with `configmap "x" not found`; see runbook Section 5.)

### Step 7: Pending
```bash
kubectl apply -f $F -l scenario=pending
sleep 10
kubectl get pods -n orderflow -l scenario=pending -o wide
kubectl describe pod -l scenario=pending -n orderflow | /usr/bin/grep -A3 '^Events:'
kubectl describe node | /usr/bin/grep -A8 '^Allocatable:'
```
*You should see: STATUS `Pending`, NODE `<none>`; `FailedScheduling ... 0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory`; the node's allocatable CPU/memory far below 128 CPUs / 256Gi.* Fix by right-sizing, then clean up:
```bash
kubectl set resources deployment/chaos-06-pending -n orderflow --requests=cpu=50m,memory=32Mi
sleep 10
kubectl get pods -n orderflow -l scenario=pending
kubectl delete -f $F -l scenario=pending
```
Other Pending causes read the same way, in the same Events block: `didn't match Pod's node affinity/selector` (nodeSelector/affinity), `had untolerated taint` (taints), `unbound immediate PersistentVolumeClaims` (storage). Real clusters with Karpenter/Cluster Autoscaler turn "Insufficient cpu" into a new node; here nothing does.

### Step 8: DNS failure (egress policy without port 53)
**Needs a CNI that enforces NetworkPolicy: kindnet on Docker Desktop's kind provisioner does; the kubeadm provisioner does not (the pod would stay healthy).**
The scenario runs `order-api` plus a curl sidecar that POSTs an order every 5 s. A NetworkPolicy gives these pods **no egress at all**. The pod is `2/2 Running` and Ready (kubelet probes are not pod traffic), yet every downstream call fails.
```bash
kubectl apply -f $F -l scenario=dns
kubectl rollout status deploy/chaos-07-dns -n orderflow --timeout=90s
sleep 20
kubectl get pods -n orderflow -l scenario=dns
kubectl logs -l scenario=dns -c order-api -n orderflow --tail=4
```
*You should see: `2/2 Running`; lines like `call to /payments failed for order ...: Post "http://orderflow-payment:8081/payments": context deadline exceeded (Client.Timeout exceeded while awaiting headers)`.* That message does not say "DNS": the client's 3 s timeout fires while still resolving. Prove where it dies from **inside the pod's network namespace** with an ephemeral container (the app image has no tools). Non-interactive form; the output lands in the debug container's log:
```bash
POD=$(kubectl get pod -n orderflow -l scenario=dns -o name | head -1)
kubectl debug $POD -n orderflow --image=nicolaka/netshoot --target=order-api --profile=general -q -c dns-dbg -- \
  sh -c 'cat /etc/resolv.conf; nslookup -timeout=2 -retry=1 orderflow-payment.orderflow.svc.cluster.local; echo "nslookup rc=$?"; curl -sS -m 3 http://orderflow-payment:8081/health; echo "curl rc=$?"'
sleep 20
kubectl logs $POD -n orderflow -c dns-dbg
```
*You should see: `nameserver 10.96.0.10`, `;; communications error to 10.96.0.10#53: timed out`, `nslookup rc=1`, `curl: (28) Resolving timed out after 3003 milliseconds`, `curl rc=28`.* (First run pulls netshoot, ~200 MB; `sleep 20` may need to be longer. Interactively you would use `kubectl debug -it ... -- bash`.) Now fix with the policy that allows CoreDNS (UDP+TCP 53) and the two services:
```bash
kubectl apply -f $F -l scenario=dns-fix
sleep 15
kubectl logs -l scenario=dns -c order-api -n orderflow --since=10s
kubectl debug $POD -n orderflow --image=nicolaka/netshoot --target=order-api --profile=general -q -c dns-dbg2 -- \
  sh -c 'nslookup -timeout=2 orderflow-paymnt; curl -sS -m 3 http://orderflow-payment:8081/health'
sleep 15
kubectl logs $POD -n orderflow -c dns-dbg2
```
*You should see: no new `failed` lines in the order-api log once the policy has synced (during the first seconds you may see `lookup orderflow-payment on 10.96.0.10:53: no such host` while it converges); in the debug log `** server can't find orderflow-paymnt: NXDOMAIN` (the typo'd name: **this** is the genuine "no such host") and `{"status":"ok","service":"payment-service"}`.* Two different DNS failures, two different signals: **timeout** = DNS unreachable (policy, CoreDNS down, kindnet wedge); **NXDOMAIN / no such host** = reachable but the name is wrong (typo, wrong namespace, Service missing). Clean up: `kubectl delete -f $F -l scenario=dns; kubectl delete -f $F -l scenario=dns-fix`. Runbook Section 7.

### Step 9: Service with no endpoints → Gateway 503; readiness failing
Two ways a healthy-looking Service can have nothing behind it.
**9a. Selector typo.** The pod is `1/1 Running`; the Service selects `app: chaos-08-typo`. An HTTPRoute sends `/chaos-selector` to it.
```bash
kubectl apply -f $F -l scenario=selector
sleep 40
kubectl get pods -n orderflow -l scenario=selector
kubectl get endpointslices -n orderflow -l kubernetes.io/service-name=chaos-08-selector
curl -s -i http://localhost/chaos-selector
kubectl get httproute chaos-08-selector -n orderflow -o jsonpath='{range .status.parents[0].conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
```
*You should see: pod `1/1 Running`; the EndpointSlice with `ENDPOINTS <unset>`; `HTTP/1.1 503 Service Unavailable` with `content-length: 0` (Envoy's own answer, the request never reached a pod); route conditions `Accepted=True`, `BackendsAvailable=False EndpointsNotFound`, `ResolvedRefs=True`.* Fix the selector and watch the same URL turn 200:
```bash
kubectl patch service chaos-08-selector -n orderflow -p '{"spec":{"selector":{"app":"chaos-08"}}}'
sleep 8
curl -s -i http://localhost/chaos-selector | /usr/bin/grep -E '^HTTP|status'
```
**9b. Readiness probe failing.** The probe path is `/readyz`; the app serves `/ready`. This scenario has a route (`/chaos-readiness`, rewritten to `/health`).
```bash
kubectl apply -f $F -l scenario=readiness
sleep 40
kubectl get pods -n orderflow -l scenario=readiness
kubectl get endpointslices -n orderflow -l kubernetes.io/service-name=chaos-09-readiness -o jsonpath='{.items[0].endpoints[0].conditions}{"\n"}'
kubectl describe pod -l scenario=readiness -n orderflow | /usr/bin/grep -E 'Unhealthy|Readiness:'
for i in $(seq 1 10); do curl -s -o /dev/null -w "%{http_code} " http://localhost/chaos-readiness; done; echo
```
*You should see: `0/1 Running` with RESTARTS 0 (liveness is fine); `{"ready":false,"serving":false,"terminating":false}`; `Readiness probe failed: HTTP probe failed with statuscode: 404`; and, surprisingly, ten `200`s through the Gateway.* The Service has no ready endpoint (prove it in-cluster, the Service sends the pod nothing):
```bash
POD=$(kubectl get pod -n orderflow -l scenario=readiness -o name | head -1)
kubectl debug $POD -n orderflow --image=nicolaka/netshoot --target=order-api --profile=general -q -c svc-check -- \
  sh -c 'curl -sS -m 3 http://chaos-09-readiness:8080/health; echo "curl rc=$?"'
sleep 15
kubectl logs $POD -n orderflow -c svc-check
```
*You should see `Failed to connect ... Could not connect to server` and `curl rc=7`.* Why does the Gateway answer 200? **Envoy panic routing.** Envoy Gateway hands the not-ready endpoint to Envoy as a *non-healthy* host; when fewer than the panic threshold (default 50%) of an upstream's hosts are healthy, Envoy **fails open** and load-balances across **all** hosts instead of returning errors. A Service whose only pod is unready therefore still gets traffic from the Gateway (while kube-proxy, in-cluster, sends none). Do not treat the Gateway as a readiness gate.

**9c. Add one ready replica behind the same Service.** A second Deployment carries the same `app: chaos-09` label and a correct probe:
```bash
kubectl apply -f $F -l scenario=readiness-ready
kubectl wait --for=condition=Ready pod -l variant=ready -n orderflow --timeout=90s
kubectl get pods -n orderflow -l app=chaos-09 -o wide
kubectl get endpointslices -n orderflow -l kubernetes.io/service-name=chaos-09-readiness -o jsonpath='{range .items[0].endpoints[*]}{.addresses[0]} ready={.conditions.ready}{"\n"}{end}'
sleep 30
for i in $(seq 1 30); do curl -s -o /dev/null http://localhost/chaos-readiness; done
sleep 10
kubectl logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=edge -c envoy --since=30s --tail=-1 | /usr/bin/grep chaos-09-readiness | /usr/bin/grep -o '"upstream_host":"[^"]*"' | sort | uniq -c
```
*You should see: two pods (one `0/1`, one `1/1`), endpoints `ready=false` and `ready=true`, and all 30 requests counted against the **ready** pod's IP (`30 "upstream_host":"<ready pod IP>:8080"`).* One of two healthy is 50%: no panic, so the unready pod gets nothing. Moral for Day 6: keep at least 2 replicas, or draining/unready pods may still receive traffic. Fix 9b's pod: `kubectl patch deployment chaos-09-readiness -n orderflow --type json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/ready"}]'`, wait 20 s, see `1/1`. Clean up: `kubectl delete -f $F -l scenario=selector; kubectl delete -f $F -l scenario=readiness; kubectl delete -f $F -l scenario=readiness-ready`. Runbook Sections 8 and 9.

### Step 10: Read the pattern
Fill the table in your notes (or the runbook sections) from memory of Steps 2-9: for each scenario write the STATUS you saw, the **one** command that gave the root cause, and the exit code if any. Then check the exit-code table in the runbook: 1 (app error), 128 (runtime could not start), 137 (SIGKILL: OOM or `kill -9`), 143 (SIGTERM, graceful stop). Which of the nine had an exit code at all? (Answer in SOLUTION.)

### Step 11: Ephemeral containers, `--copy-to`, node debugging
The Day 6 `order-api` pod is distroless and runs as UID 65532 with `readOnlyRootFilesystem`. You cannot `kubectl exec ... sh` into it. You can attach a container with tools **to its namespaces**:
```bash
POD=$(kubectl get pod -n orderflow -l app=order-api -o name | head -1)
kubectl debug $POD -n orderflow --image=nicolaka/netshoot --target=order-api --profile=general -q -c tools1 -- \
  sh -c 'id; ps aux; tcpdump -i any -c 1 -nn port 8080'
sleep 15
kubectl logs $POD -n orderflow -c tools1
```
*You should see: `uid=65532`; `ps` lists `/app/server` as PID 1 (because of `--target`, you share the target's process namespace); `tcpdump: any: You don't have permission to perform this capture on that device (... CAP_NET_RAW may be required)`.* Why: the pod-level `runAsUser: 65532` applies to the ephemeral container too, and a non-root process has no capabilities even if `--profile=netadmin` *adds* `NET_ADMIN`/`NET_RAW` (the effective set stays empty). To capture packets you must run the debug container as root with the capability, via a custom profile:
```bash
echo '{"securityContext":{"runAsUser":0,"runAsNonRoot":false,"capabilities":{"add":["NET_RAW","NET_ADMIN"]}}}' > /tmp/debug-root.json
kubectl debug $POD -n orderflow --image=nicolaka/netshoot --target=order-api --profile=general --custom=/tmp/debug-root.json -q -c tools2 -- \
  sh -c 'id -u; (curl -s -m 5 http://localhost:8080/health >/dev/null &); timeout 5 tcpdump -i lo -c 4 -nn port 8080'
sleep 15
kubectl logs $POD -n orderflow -c tools2
```
*You should see `0` and four packets (`[S]`, `[S.]`, `[.]`, `GET /ready`/`GET /health`).* Two caveats you must know: (1) under the **`restricted`** Pod Security Standard this is forbidden (`runAsUser=0`, added capabilities): use `--profile=restricted`, you get the tools but no raw sockets; (2) **ephemeral containers can never be removed** from a pod, and they count against PSA like any container. Recreate the pod to get rid of them (`kubectl delete $POD -n orderflow`; the Deployment replaces it).

`--copy-to` debugs a *crash* without touching the original: copy the pod, replace the container's image and command so it stays alive, then look around.
```bash
kubectl apply -f $F -l scenario=crashloop
sleep 25
CRASH=$(kubectl get pod -n orderflow -l scenario=crashloop -o name | head -1)
kubectl debug $CRASH -n orderflow --copy-to=crash-debug --container=payment-service --image=busybox:1.37 --profile=general -q -- sleep 3600
sleep 10
kubectl get pods -n orderflow -l scenario=crashloop
kubectl get pod crash-debug -n orderflow
kubectl exec crash-debug -n orderflow -- sh -c 'env | grep ^PORT='
kubectl delete pod crash-debug -n orderflow
kubectl delete -f $F -l scenario=crashloop
```
*You should see: the original still `CrashLoopBackOff`; `crash-debug` `1/1 Running` (the copy has **no labels**, so `-l scenario=crashloop` does not select it and the Deployment does not adopt it); `PORT=notanumber`.* Same environment, same config, now with a shell.

Node debugging. `kubectl debug node/...` starts a privileged pod on the node with the node's filesystem at `/host`. It is created in the namespace you pass, and you must delete it:
```bash
kubectl debug node/desktop-control-plane -n orderflow --image=busybox:1.37 --profile=sysadmin -q -- \
  sh -c 'chroot /host dmesg | grep -i -E "killed process" | tail -2; tail -n 2 /host/var/log/pods/orderflow_orderflow-order-api-*/order-api/0.log'
sleep 15
kubectl logs -n orderflow $(kubectl get pods -n orderflow -o name | grep node-debugger | head -1) | cut -c1-200
kubectl delete -n orderflow $(kubectl get pods -n orderflow -o name | grep node-debugger)
```
*You should see (if Step 5 ran earlier on this node): `Memory cgroup out of memory: Killed process <pid> (server) ... UID:65532 ... oom_score_adj:996` (the kernel's side of the OOM story; `dmesg` is **not** in `kubectl get events`), and a CRI log line such as `2026-10-06T15:00:07.345586Z stderr F 2026/10/06 15:00:07 order-api listening on port 8080`: RFC3339 timestamp, stream, `F` (full line; `P` = partial), message. That is the containerd/CRI format, **not JSON**.* Replace the node name with yours on other setups (`kubectl get nodes`; the node is named `docker-desktop` on the kubeadm provisioner). If the `grep` shows nothing, run Step 5 first.

### Step 12: Strategic architecture and mesh decisions
On paper, one paragraph each, then compare with [`SOLUTION.md`](./SOLUTION.md):
1. **Seed-stage startup:** 5 microservices, 3 full-stack engineers, pure AWS.
2. **Enterprise fintech:** 30 microservices, 20+ backend engineers, PCI-DSS requiring mTLS and granular pod network policy, hybrid-cloud plan.
3. **Monolith migration:** 8 services carved from a Django monolith, 8 engineers, pure AWS, GitHub Actions pipeline.
4. **Gateway engineer's questions:** (a) Where do you rate-limit: edge gateway, mesh, or app? (b) Your service calls a flaky dependency: where do retries and timeouts live, and what stops a retry storm? (c) How do you canary 5% of traffic to `order-api` v2 with the Gateway API you already know (Day 4 `httproute-canary.yaml`), and what does a mesh add?

---

## Success Signal
1. `kubectl top nodes` / `kubectl top pods` return values; the baseline release answers `[]` at `http://localhost/orders`.
2. Nine scenarios diagnosed from signals alone, each with a one-line root cause and fix in your notes or the runbook; you can tell Step 3 from Step 4 (exit 1 with logs vs exit 128 without), a timeout from an NXDOMAIN, and a Gateway-level 503 from an app-level one.
3. You attached an ephemeral container, explained why `tcpdump` needs more than `--profile=netadmin`, and read an OOM kill from the node's kernel log.
4. The decision questions are answered with trade-offs (operational burden vs control), including where a mesh and rate limiting belong.

---

## Stuck? Hints

- **`ImagePullBackOff` on `orderflow/*:v1` (not the v99 one)** → images are not on the node (kind provisioner does not see your Docker engine's images). → `bash labs/shared/load-images.sh`.
- **`kubectl top` says `Metrics API not available` / `metrics not available yet`** → metrics-server missing or still scraping. → `kubectl apply -f labs/shared/metrics-server.yaml`, `kubectl rollout status deploy/metrics-server -n kube-system`, wait 60 s; check `kubectl get apiservice v1beta1.metrics.k8s.io`.
- **Step 8: pods keep working, no DNS failure** → your cluster does not enforce NetworkPolicy (Docker Desktop kubeadm provisioner). → read the SOLUTION output instead, or switch to the kind provisioner. **Opposite problem: everything times out even after `dns-fix`/deleting policies** → kindnet's policy agent wedged (log `netlink receive: no such file or directory`) → `kubectl rollout restart ds/kindnet -n kube-system`.
- **`kubectl debug` prints nothing** → without `-it` the output goes to the debug container's log. → `kubectl logs <pod> -c <name>` after ~10-20 s (first netshoot pull is slow). Container names must be unique per pod: use a new `-c` each time.
- **Chaos Deployments show no pods / `FailedCreate`, or `kubectl debug` is rejected with `violates PodSecurity "restricted"`** → you skipped `reset.sh` after Day 6, so namespace `orderflow` still carries the `restricted` Pod Security label. → `bash labs/shared/reset.sh` (the label is gone; `--previous` hiccups: just retry, StartError has no logs by design).
- **`curl http://localhost/...` refused** → the Gateway's LB port is not published (not Docker Desktop, or `edge` not Programmed). → use the Day 4 port-forward fallback (`kubectl port-forward -n envoy-gateway-system svc/<proxy-svc> 8888:80`) and `http://localhost:8888`.

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

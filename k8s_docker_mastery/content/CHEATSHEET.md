# Docker & Kubernetes Cheat Sheet

One page of decision rules and commands. Commands assume namespace `orderflow`; add `-n orderflow` where shown. Distroless images have no shell: debug with `kubectl debug`, not `exec sh`. Details live in the day files; drills in [`RECALL.md`](./RECALL.md).

## 1. Debug decision tree (Day 7)

Always start: `kubectl get pods -n orderflow -o wide`, then read the signals in this order: STATUS → `describe` (Events, `Last State`, exit code) → `logs --previous` → EndpointSlices → route status.

| STATUS / symptom | Means | Decisive check | Fix direction |
|:---|:---|:---|:---|
| `Pending`, NODE `<none>` | Not scheduled (requests, selector, taint, unbound PVC) | `describe pod` → `FailedScheduling` | right-size requests, fix selector/taint/PVC |
| `ImagePullBackOff` | Never created (RESTARTS 0) | Event text; "pull access denied" often = wrong tag | fix tag/secret; kind provisioner: `load-images.sh` |
| `CreateContainerConfigError` | Missing ConfigMap/Secret/key | Event `couldn't find key` | fix reference |
| `CrashLoopBackOff` (`Error`) | App ran and exited non-zero | `logs --previous`, exit 1 | fix config/code |
| `RunContainerError` / `StartError`, exit 128 | Runtime could not start the process; **empty logs** | `Last State ... StartError` | fix `command`/image |
| `OOMKilled`, exit 137 | Cgroup memory limit; no log line, no event | `Last State: OOMKilled`; `dmesg` via node debug | raise limit, `GOMEMLIMIT`, find leak |
| `Running 0/1` | Readiness failing | `Readiness probe failed`, EndpointSlice `ready: false` | probe path/port/dependency |
| `Running 1/1`, gateway **503** (empty body) | Service has no endpoints | empty EndpointSlice; `HTTPRoute ... EndpointsNotFound` | fix selector/labels |
| gateway **404** empty body / `404 page not found` | no route matched / reached the app | route `Accepted`, path | fix route / app path |
| calls time out | DNS or policy | ephemeral `nslookup`: timeout = DNS unreachable, `NXDOMAIN` = wrong name | allow UDP+TCP 53 to CoreDNS |
| pods still get traffic while all not-ready | Envoy **panic routing** (below 50% healthy, default threshold) | proxy access log vs EndpointSlices | fix the probe path/port; keep >= 2 replicas. Once one pod is ready traffic moves to it; an empty slice 503s |

## 2. Exit codes

`0` ok · `1` app error · `126` not executable · `127` not found · `128` runtime could not start · `137` SIGKILL (OOM, or grace period expired; `128+9`) · `143` SIGTERM (graceful stop; `128+15`). Read `Reason` together with the code.

## 3. Probes and QoS (Day 6)

- **startup**: finished starting? failure → restart; pauses the other two. **readiness**: serve traffic now? failure → out of endpoints, no restart. **liveness**: stuck for good? failure → restart.
- Never put a database/external call in liveness. Course apps: `/health` = liveness, `/ready` = readiness (503 after SIGTERM).
- QoS: **Guaranteed** = every container has CPU and memory requests == limits; **Burstable** = something set; **BestEffort** = nothing. Evicted in that reverse order. Request > limit is rejected. Memory over limit = kill, CPU over limit = throttle.
- HPA `<unknown>`: missing CPU requests (any container) or no metrics-server (`kubectl top pods` first).

## 4. Graceful shutdown (Day 6)

Endpoint removal and SIGTERM start **in parallel**; the grace period includes preStop.

```
terminationGracePeriodSeconds  >=  preStop + drainDelay + appShutdownTimeout + margin
```
```yaml
lifecycle:
  preStop:
    sleep: {seconds: 10}     # built in (GA 1.34): works in distroless; exec ["sleep"] would not
```
Or app-level: on SIGTERM flip `/ready` to 503, keep serving `DRAIN_DELAY_SECONDS`, then `Shutdown`.

## 5. Pod Security `restricted` checklist (Day 5)

```yaml
spec:
  securityContext: {runAsNonRoot: true, runAsUser: 65532, seccompProfile: {type: RuntimeDefault}}
  containers:
    - securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: ["ALL"]}}   # + readOnlyRootFilesystem is YOUR choice (not in any PSS)
```
No label on a namespace = `privileged`. Modes: `enforce` rejects, `warn` warns, `audit` logs. Preview: `kubectl label --dry-run=server --overwrite ns orderflow pod-security.kubernetes.io/enforce=restricted`. Violations of Deployments/StatefulSets show up in ReplicaSet/StatefulSet **events**, not at `apply`.

## 6. NetworkPolicy patterns (Day 4)

- Enforced by the CNI: test the block *and* the allow (kubeadm provisioner ignores policies). Policies are a union of allows.
- Default deny: `podSelector: {}` + `policyTypes: [Ingress]` (and/or `Egress`). Egress deny **kills DNS**: allow UDP+TCP 53 to `k8s-app=kube-dns` in `kube-system`.
- AND vs OR: one `from` item with `namespaceSelector` **and** `podSelector` = AND; two items = OR.
- Edge traffic comes from the Envoy proxy pods in namespace `envoy-gateway-system` (label `app.kubernetes.io/name: envoy`). Ports in a policy are the container's port. Wedged kindnet: `kubectl rollout restart ds/kindnet -n kube-system`.

## 7. Gateway API (Day 4)

| Kind | Owner | Purpose |
|:---|:---|:---|
| `GatewayClass` | provider | which controller (`eg` = Envoy Gateway) |
| `Gateway` | platform | listeners, TLS, `allowedRoutes` |
| `HTTPRoute` / `GRPCRoute` | app team | matches, `backendRefs` + weights, filters |
| `ReferenceGrant` | target namespace | allow cross-namespace refs |

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata: {name: orderflow, namespace: orderflow}
spec:
  parentRefs: [{name: edge, namespace: gateway-infra}]
  rules:
    - matches: [{path: {type: PathPrefix, value: /orders}}]
      backendRefs:
        - {name: order-api, port: 8080, weight: 90}
        - {name: order-api-canary, port: 8080, weight: 10}   # weights are relative; a separate, more specific header-match rule forces the canary
```
Most specific match wins, not rule order. `kubectl get gatewayclass,gateway -A`; `kubectl get httproute orderflow -n orderflow -o jsonpath='{.status.parents[0].conditions}'` (`Accepted`, `ResolvedRefs`). From the Mac: `curl -i http://localhost/orders`.

## 8. Helm 4 (Day 6)

```bash
helm lint <chart> -f <values>
helm template <rel> <chart> -n <ns> -f <values> | kubectl apply --dry-run=server -f -
helm install <rel> <chart> -n <ns> -f <values> --wait --timeout 300s
helm upgrade <rel> <chart> -n <ns> -f <values> --set k=v --wait --rollback-on-failure --timeout 2m   # Helm 3: --atomic
helm history <rel> -n <ns>; helm rollback <rel> <N> -n <ns>        # creates a NEW revision; PVC data/CRDs not restored
helm get values <rel> -n <ns>                 # add --revision N for an older revision
helm get hooks <rel> -n <ns>
```
Helm 4: server-side apply by default, `--wait` uses kstatus, `--force-replace` replaces `--force`. Omit `replicas` in the template when an HPA is enabled. `helm uninstall` does not remove CRDs.

## 9. kubectl debug recipes (Days 4, 7)

```bash
kubectl debug -it <pod> -n orderflow --image=nicolaka/netshoot --target=<container> --profile=general -- bash       # shares netns (+ process ns), labels, NetworkPolicy
kubectl debug <pod> -n orderflow --image=curlimages/curl --target=<container> --profile=general -it -- sh           # test client as the pod
kubectl debug <pod> -n orderflow --copy-to=<pod>-dbg --container=<container> --image=busybox:1.37 --profile=general -it -- sh   # clone a crashing pod
kubectl debug node/<node> -it --image=busybox:1.37 --profile=sysadmin                                                  # node fs at /host; delete the pod afterwards
```
Ephemeral containers cannot be removed (recreate the pod). Non-root pods: `tcpdump` fails (no capabilities). Test client for the Gateway: `curl -i http://localhost/<path>`; `kubectl port-forward` bypasses the gateway and ingress policy.

## 10. Docker one-liners (Days 1-2)

```bash
docker run -d --memory=32m --memory-swap=32m <img>           # hard cap: over it = OOMKilled, 137
docker stop -t 10 <c>                                         # slow stop + 137 = PID 1 ignores SIGTERM (shell wrapper without exec)
docker inspect -f '{{.State.OOMKilled}} {{.State.ExitCode}}' <c>
docker run --rm -it --privileged --pid=host --cgroupns=host alpine nsenter -t 1 -m -u -n -i sh   # shell inside the Docker Desktop VM
docker compose up -d --wait; docker compose config            # recreate on config change (restart does not); resolved config
docker compose down                                           # containers + networks; add -v to delete volumes, --rmi local for built images
```
Compose env: `run -e` > `environment:` > `env_file:` > image `ENV`; shell and `.env` only feed `${}` interpolation.

## 11. Daily reset (Days 3-7)

```bash
bash labs/shared/reset.sh && bash labs/shared/load-images.sh   # clean orderflow namespace + images in the cluster
kubectl get gateway edge -n gateway-infra; kubectl top nodes   # edge (Day 4) and metrics-server still there?
```

# Day 6 Lab: Helm 4, the OrderFlow Chart, Design Patterns & Graceful Shutdown

**Run every command from the course root** (`k8s_docker_mastery/`). Target cluster: Docker Desktop Kubernetes on the **kind provisioner** (context `docker-desktop`, node `desktop-control-plane`). Alternatives: Docker Desktop's *kubeadm* provisioner (node `docker-desktop`) sees local images directly (the `load-images.sh` step is a no-op) but does not enforce NetworkPolicy (not used today); with plain `kind`, `load-images.sh` runs `kind load docker-image`, and reach the Gateway with the port-forward fallback from Day 4 Step 3 instead of `localhost`. Requires Helm 4 (`brew install helm`, then `helm version` shows `v4.x`) and internet access for the node (`postgres:16-alpine`, `busybox:1.37` are pulled from Docker Hub).

## Start here — plain steps

1. Open a terminal in `k8s_docker_mastery/`. `kubectl config current-context` must print `docker-desktop`, and `helm version --short` must start with `v4`.
2. Run the **Prerequisites**: clean namespace + images + the `restricted` label, check that the Day 4 Gateway `edge` and metrics-server exist (the commands to re-install them are there).
3. Render the chart (`helm lint`, `helm template`) and validate it against the real API server with `--dry-run=server` **before** installing.
4. `helm install` with the dev values. You should see `order-api` go through `Init:0/2` to **`2/2 Running`**, a Completed `orderflow-db-migration` Job whose logs show `CREATE TABLE`, and `curl http://localhost/orders` return `[]`.
5. Upgrade (`replicaCount=3`), look at `helm history`, then roll back to revision 1. Count the revisions: a rollback makes a **new** one.
6. Switch to the production profile, generate load and watch the HPA scale `order-api` from 2 to 6 pods.
7. Break it: an OOM kill (`OOMKilled`, exit 137) and a bad readiness path (new pods stay `1/2`, old ones keep serving). Roll back each time to the **last good revision**.
8. Run the graceful shutdown experiment (a load loop through the Gateway during `kubectl rollout restart`). You should see a handful of errors with preStop 0 and none with 10 s. Finally watch a PDB refuse an eviction. You are done when each "You should see" line matched. Run **Teardown**.

**Time:** realistically about 2 hours (14 Helm revisions, two load runs, several rollouts that each wait for Ready). Optional if you are short on time: the `helm diff` section, Step 9 (PDB) and the second half of Step 5 (extra load runs); Steps 1-4, 6-8 are the core.

## Objective
Install the whole OrderFlow platform from one Helm chart into a namespace enforcing the **`restricted`** Pod Security Standard: three services, a chart-managed Postgres, a **Helm hook Job** that migrates the schema, an init container, a **native sidecar**, an edge route through the Day 4 Gateway, HPA and PDB. Then upgrade, roll back, break it on purpose (OOM, bad readiness), scale it under load and finally **measure** how many requests a rolling update drops with `preStop` 0 vs 10 s.

## Architecture

```
 Mac: curl http://localhost/orders
   ▼
 Gateway edge (ns gateway-infra) ◄── HTTPRoute orderflow (chart: templates/httproute.yaml)
   ▼  /orders → Service orderflow-order-api
 Pod orderflow-order-api-… (2/2)
   ├─ init     wait-for-postgres        (pg_isready loop; exits when Postgres is up)
   ├─ sidecar  readiness-watcher        (initContainers + restartPolicy: Always; logs /ready transitions)
   └─ main     order-api                startup /health · readiness /ready · liveness /health
                                        preStop sleep → SIGTERM → drain → exit
 Services orderflow-payment, orderflow-notification   (internal; no route)
 StatefulSet orderflow-postgres-0 (+ headless Service, Secret orderflow-postgres-auth)
 Hook Job orderflow-db-migration   post-install,pre-upgrade:  CREATE TABLE orders …
 HPA orderflow-order-api-hpa · PDB orderflow-order-api-pdb · ConfigMap orderflow-order-api-config
```
Names with release `orderflow`: `orderflow-<service>` (the chart's `fullname` helper). Not `order-api`, and the ConfigMap is **not** `orderflow-config` (that one belongs to Day 3).

---

## Prerequisites

```bash
bash labs/shared/reset.sh                 # empty, unlabeled namespace orderflow (also removes a leftover release)
bash labs/shared/load-images.sh           # builds orderflow/*:v1 and loads them into the node
kubectl label ns orderflow --overwrite \
  pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/audit=restricted
```
*You should see: the namespace `Active` with only the `metadata.name` label after reset, `loaded orderflow/<svc>:v1` three times, `namespace/orderflow labeled`.* Every pod of this chart (including the hook Job and the init containers) must now pass `restricted`, or `helm install` fails.

Platform pieces from Day 4 (Envoy Gateway + edge Gateway) and metrics-server (README Start here step 6) must exist (they live outside `orderflow`, so `reset.sh` leaves them). Check, and install only what is missing (all commands are idempotent):
```bash
kubectl get gateway edge -n gateway-infra                 # PROGRAMMED True. Missing? Day 4 Steps 2-3:
#   helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm --version v1.9.2 -n envoy-gateway-system --create-namespace
#   kubectl wait -n envoy-gateway-system --timeout=120s --for=condition=Available deployment/envoy-gateway
#   kubectl apply -f labs/day04/manifests/gateway.yaml && kubectl wait --for=condition=Programmed gateway/edge -n gateway-infra --timeout=120s
kubectl top nodes                                         # works? metrics-server is installed. If not:
#   kubectl apply -f labs/shared/metrics-server.yaml && kubectl rollout status deploy/metrics-server -n kube-system --timeout=120s
```
*You should see: `edge  eg  <address>  True` and one node row with CPU/MEMORY.* (The HPA step needs `kubectl top` to work; give metrics-server a minute after installing.)

---

## Instructions

### Step 1: Lint, render, and validate against the API server
```bash
CHART=labs/day06/orderflow-chart
helm lint $CHART -f $CHART/values-dev.yaml
helm template orderflow $CHART -n orderflow -f $CHART/values-dev.yaml | /usr/bin/grep -E '^kind:|replicas:'
helm template orderflow $CHART -n orderflow -f $CHART/values-dev.yaml | kubectl apply --dry-run=server -f -
helm template orderflow $CHART -n orderflow -f $CHART/values-production.yaml | /usr/bin/grep -E '^kind: (HorizontalPodAutoscaler|PodDisruptionBudget)|replicas:'
```
*You should see: `1 chart(s) linted, 0 chart(s) failed` (plus an `icon is recommended` INFO); the dev render lists `Secret ConfigMap Service×4 Deployment×3 StatefulSet HTTPRoute Job` with `replicas: 1` for each Deployment; the server dry-run prints `... created (server dry run)` for every object (Pod Security would warn here if anything violated `restricted`); the production render contains the HPA and the PDB and **no** `replicas:` line for the order-api Deployment (the HPA owns it), only for payment (3), notification (2) and the StatefulSet (1).*

(Use `/usr/bin/grep` if your `grep` is an alias.) Run the server dry-run *before* installing: after install, `kubectl apply` warns about missing `last-applied-configuration` annotations because Helm 4 applied the objects server-side.

Try the render-time guard, then the optional Ingress:
```bash
helm template orderflow $CHART --set shutdown.preStopSleepSeconds=30 2>&1 | /usr/bin/grep Error
helm template orderflow $CHART --set ingress.enabled=true --set gateway.enabled=false --set ingress.className=alb \
  --set ingress.host=orderflow.example.com --set-string 'ingress.annotations.alb\.ingress\.kubernetes\.io/scheme=internet-facing' \
  --show-only templates/ingress.yaml
```
*You should see: `Error: execution error at (orderflow/templates/deployment.yaml:1:4): shutdown.terminationGracePeriodSeconds=45 is too short: need >= preStopSleepSeconds + drainDelaySeconds + 20 = 50`; and an Ingress with `ingressClassName: alb`, the annotation, host `orderflow.example.com`, path `/orders` `pathType: Prefix` to `orderflow-order-api:8080` (no rewrite annotation).*

### Step 2: Install (revision 1) under `restricted`
```bash
helm install orderflow $CHART -n orderflow -f $CHART/values-dev.yaml
kubectl get pods -n orderflow
```
*You should see: `STATUS: deployed`, `REVISION: 1`, and the NOTES. Helm returned only after the hook Job finished, which is why `orderflow-db-migration-…` is already `Completed`; `orderflow-order-api-…` shows `0/2 Init:0/2` then `1/2 PodInitializing`.* Now wait for it, then look at every piece:
```bash
kubectl wait --for=condition=Ready pod -l app=order-api -n orderflow --timeout=120s
kubectl get pods -n orderflow
kubectl logs job/orderflow-db-migration -n orderflow
kubectl exec orderflow-postgres-0 -n orderflow -- psql -U orderflow -d orderflow -c '\dt'
kubectl logs deploy/orderflow-order-api -n orderflow -c readiness-watcher
curl -i http://localhost/orders
curl -s -X POST http://localhost/orders -d '{"item":"book","qty":2}'; echo; curl -s http://localhost/orders
```
*You should see: `orderflow-order-api-…  2/2  Running` (the native sidecar counts in READY), `orderflow-postgres-0 1/1`, and the Completed Job; migration logs ending `CREATE TABLE`, `ALTER TABLE`, the `\d orders` table description and `migration complete` (the hook waited with `pg_isready` until Postgres was up); `\dt` lists `orders`; the watcher log `/ready: unknown -> not-ready` then `not-ready -> ready` (it started before the app); `HTTP/1.1 200 OK` with body `[]` through the Gateway, then the order you posted.* The first `wait-for-postgres` attempts can say `no response` while the Service's DNS record appears (about half a minute at worst): that is the init container doing its job.

Two honest notes. **order-api keeps orders in memory and never queries Postgres** (it is the course's simplest service); the table exists to show a real migration, and the init container to show the gate pattern. And every container in the release drops all capabilities: `helm get manifest orderflow -n orderflow | /usr/bin/grep -c 'drop:'` prints `6` (order-api, the init container, the sidecar, payment, notification, postgres; the hook Job is not part of the manifest but has the same block).

### Step 3: Upgrade, history, rollback (revisions 2 and 3)
```bash
helm upgrade orderflow $CHART -n orderflow -f $CHART/values-dev.yaml --set orderApi.replicaCount=3 --wait
helm history orderflow -n orderflow
kubectl get deploy orderflow-order-api -n orderflow
kubectl get jobs -n orderflow
helm rollback orderflow 1 -n orderflow --wait
helm history orderflow -n orderflow
kubectl get deploy orderflow-order-api -n orderflow
kubectl get secrets -n orderflow -l owner=helm
helm get values orderflow -n orderflow --revision 2
```
*You should see: after the upgrade, revision 2 `deployed` (revision 1 `superseded`), `orderflow-order-api 3/3`, and a **new** migration Job (the `pre-upgrade` hook ran again; it is idempotent); after the rollback revision **3** with description `Rollback to 1` (revisions 1 and 2 are `superseded`: history never rewinds), `1/1` replicas again (the rollback does not run `pre-upgrade` hooks), three Secrets `sh.helm.release.v1.orderflow.v1…v3`, and `replicaCount: 3` in revision 2's values.*

### Step 4: Production profile (revision 4): HPA and PDB
```bash
helm upgrade orderflow $CHART -n orderflow -f $CHART/values-production.yaml --wait
kubectl get deploy,hpa,pdb -n orderflow
kubectl get deploy orderflow-order-api -n orderflow -o jsonpath='{.spec.replicas}{"\n"}'
```
*You should see: revision 4. HPA `orderflow-order-api-hpa` (`Deployment/orderflow-order-api`, MINPODS 2, MAXPODS 10, target 70%, TARGETS `cpu: <unknown>/70%` for the first moments, then a percentage); PDB `orderflow-order-api-pdb` (`MAX UNAVAILABLE 1`, `ALLOWED DISRUPTIONS 1`); payment 3/3, notification 2/2; the order-api Deployment shows `replicas` 1 right after the upgrade: Helm was the only owner of the field (revision 3 rendered it) and the template no longer renders it, so the API server defaulted it to 1; within about 30 s the HPA raises it to its minimum of 2 (event `Current number of replicas below Spec.MinReplicas`).* That one-time dip is the cost of migrating an existing release to an HPA. From now on the HPA co-owns the field, so later upgrades that omit `replicas` leave its value alone (Steps 5 and 6 keep the HPA's count). The rule: render `replicas` only when `hpa.enabled` is false, or Helm and the HPA fight over it.

### Step 5: HPA under load (revision 5)
At 70% of a 110 m request (100 m app + 10 m sidecar) this laptop would barely cross the threshold, so lower the target to make the effect visible:
```bash
helm upgrade orderflow $CHART -n orderflow -f $CHART/values-production.yaml --set hpa.targetCPUUtilizationPercentage=30 --wait
(seq 1 100000 | xargs -P 16 -I{} curl -s -o /dev/null --max-time 5 http://localhost/orders) >/dev/null 2>&1 &
for i in 1 2 3 4 5 6; do sleep 15; kubectl get hpa -n orderflow --no-headers; done
```
*You should see (reference run): `cpu: 72%/30%  2  10  2`, then `cpu: 76%/30% … 2`, `49%/30% … 4`, `47%/30% … 6`, then utilization falling (`26%`, `22%`, `19%/30%`) with 6 replicas.* On a laptop the HPA may stop at 3-4 replicas instead (observed 34-44% CPU); that is fine, and the counts below hold for whatever replica count you reach (read `N` as your current count). The controller computes `ceil(2 × 76/30) = 6`, but the default scale-up policy limits each step (doubling or +4 pods per 15 s), so it got there in two steps. Stop the load and watch it:
```bash
pkill -f "xargs -P 16"
kubectl get hpa -n orderflow
kubectl get deploy orderflow-order-api -n orderflow
kubectl top pods -n orderflow -l app=order-api
```
*You should see: utilization falls to about 20% (`cpu: 20%/30%`), **but replicas stay where they were** (the reference run: `6/6`): the HPA's scale-down stabilization window is 300 s, so it waits five minutes of low utilization before removing pods. That is by design (no flapping).* Do not wait for it; the next upgrade leaves the replica count alone (HPA-owned).

### Step 6: BREAK IT, OOM kill (revisions 6 and 7)
`order-api` has an opt-in debug endpoint that allocates and touches memory (`ENABLE_DEBUG_ALLOC=1`, never for production). Lower the limit to **64Mi** (the request stays 64Mi: *requests must be ≤ limits*, so a limit of 15Mi would be rejected by the API server):
```bash
helm upgrade orderflow $CHART -n orderflow -f $CHART/values-production.yaml \
  --set hpa.targetCPUUtilizationPercentage=30 --set orderApi.enableDebugAlloc=true \
  --set orderApi.resources.limits.memory=64Mi --wait --timeout 120s
POD=$(kubectl get pods -n orderflow -l app=order-api -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n orderflow pod/$POD 18080:8080 >/dev/null 2>&1 &
PF=$!
sleep 3
curl -s "localhost:18080/debug/alloc?mb=20"; echo
curl -s -m 10 -w "curl exit=%{exitcode}\n" "localhost:18080/debug/alloc?mb=100"
kill $PF
sleep 5   # give the kubelet a moment to record the restart
kubectl get pods -n orderflow -l app=order-api
kubectl describe pod $POD -n orderflow | /usr/bin/grep -E "Last State|Reason:|Exit Code:|Restart Count"
```
*You should see: `{"allocated_mb":20,"retained_mb":20}` (20 MiB fits), then `curl exit=52` (empty reply: the process was killed mid-request); one pod `RESTARTS 1`, and in `describe` for `order-api`: `Last State: Terminated`, `Reason: OOMKilled`, `Exit Code: 137` (128 + SIGKILL), `Restart Count: 1`. The sidecar and the other pods are unaffected: the limit is per container.* (Counts here and in Step 7 depend on your current replica count N, the reference run had 6; after the HPA's 300 s scale-down window it is back at 2. Expect exactly one pod with RESTARTS 1 whatever N is.) (If `kubectl get pods` lists a pod from the previous ReplicaSet first, pick one that is `Running` and not `Terminating` for `POD`.)

Roll back to the **last good** revision. History now is 1-6 and the good production state is **revision 5**, not "current minus one", and not 4 (which had the default 70% target):
```bash
helm history orderflow -n orderflow | tail -3
helm rollback orderflow 5 -n orderflow --wait
kubectl get deploy orderflow-order-api -n orderflow -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}{"\n"}'
```
*You should see: revision **7** `deployed`, description `Rollback to 5`; memory limit `128Mi` again and no `ENABLE_DEBUG_ALLOC` in the Deployment.* (The OOM'd pods are gone because the rollback replaced them.)

### Step 7: BREAK IT, a bad readiness probe (revisions 8 to 11)
```bash
helm upgrade orderflow $CHART -n orderflow -f $CHART/values-production.yaml \
  --set hpa.targetCPUUtilizationPercentage=30 --set probes.readiness.path=/nonexistent
sleep 25
kubectl get pods -n orderflow
kubectl get deploy -n orderflow
kubectl get endpointslice -n orderflow -l kubernetes.io/service-name=orderflow-order-api \
  -o jsonpath='{range .items[0].endpoints[*]}{.addresses[0]}{" ready="}{.conditions.ready}{"\n"}{end}'
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/orders
```
*You should see: revision 8; new pods `1/2 Running` (the app runs, the sidecar is up, but `/nonexistent` is a 404 so they never become Ready) next to the old `2/2` ones; order-api Deployment `N-1` of `N` ready (reference run with N=6: `5/6`, `UP-TO-DATE 3`; fewer new pods if N is smaller); the order-api EndpointSlice lists the old pods as `ready=true` and the new ones as `ready=false` (reference: five and three); `curl` through the Gateway still returns `200`. A readiness failure removes the pod from rotation; nothing restarts.* The rolling update stalls with the old pods serving: exactly what readiness is for.

Recover by rolling back to the last good revision (**7**, not 5 and not 8):
```bash
helm rollback orderflow 7 -n orderflow --wait
```
*You should see revision **9**, `Rollback to 7`, all Deployments fully ready.*

Helm 4 can do that automatically: `--rollback-on-failure` waits (kstatus) and rolls back if the release does not become ready in `--timeout`:
```bash
helm upgrade orderflow $CHART -n orderflow -f $CHART/values-production.yaml \
  --set hpa.targetCPUUtilizationPercentage=30 --set probes.readiness.path=/nonexistent \
  --rollback-on-failure --wait --timeout 45s
helm history orderflow -n orderflow | tail -3
```
*You should see (after ~45 s) `UPGRADE FAILED: release orderflow failed, and has been rolled back due to rollback-on-failure being set: resource Deployment/orderflow/orderflow-order-api not ready ...`; history: revision **10** `failed`, revision **11** `deployed` with `Rollback to 9`.* (`--atomic` of Helm 3 is this flag; the old name is deprecated in Helm 4 but still accepted, with a warning.)

### Step 8: Graceful shutdown: preStop 0 vs 10 s (revisions 12 to 14)
Setup: two `order-api` replicas, the dev profile, no preStop yet. The load generator runs 8 parallel `curl` loops (about 60 requests/s in total) against `http://localhost/orders` for 70 s and records every HTTP status; while it runs, `kubectl rollout restart` replaces both pods. A status of `000` means curl got no HTTP response at all (connection reset/refused).
```bash
cat > "${TMPDIR:-/tmp}/rollout-load.sh" <<'EOF'
#!/usr/bin/env bash
OUT=$(mktemp); end=$((SECONDS+70))
for w in 1 2 3 4 5 6 7 8; do
  ( while [ $SECONDS -lt $end ]; do
      curl -s -o /dev/null -w '%{http_code}\n' --max-time 3 http://localhost/orders; sleep 0.1
    done ) >> "$OUT" &
done
sleep 5
kubectl rollout restart deploy/orderflow-order-api -n orderflow
kubectl rollout status deploy/orderflow-order-api -n orderflow --timeout=120s
wait
sort "$OUT" | uniq -c; rm -f "$OUT"
EOF
helm upgrade orderflow $CHART -n orderflow -f $CHART/values-dev.yaml \
  --set orderApi.replicaCount=2 --set shutdown.preStopSleepSeconds=0 --wait
bash "${TMPDIR:-/tmp}/rollout-load.sh"
```
*You should see (reference run, three repetitions): `4126 200 / 3 000 / 3 503`, `4142 200 / 3 000 / 2 503` and, from a faster loop without the 0.1 s sleep, `31307 200 / 37 503` (plus connection errors from the Mac itself running out of ports, which is why the loop sleeps). Always a few failed requests, never zero.* Revision **12**.

Now the same rollout with a 10 s `preStop`:
```bash
helm upgrade orderflow $CHART -n orderflow -f $CHART/values-dev.yaml \
  --set orderApi.replicaCount=2 --set shutdown.preStopSleepSeconds=10 --wait
bash "${TMPDIR:-/tmp}/rollout-load.sh"
bash "${TMPDIR:-/tmp}/rollout-load.sh"
```
*You should see (revision **13**): `4216 200` and `4161 200`: **every request succeeded**, twice.*

Why: with preStop 0 the kubelet sends SIGTERM at once while Envoy still has the pod in its endpoint list; the Go service closes its listener immediately, so a few requests hit a closing pod (`503` from the gateway, or a reset). With `preStop.sleep.seconds: 10` the pod keeps serving for 10 s while the endpoint removal propagates; only then does SIGTERM arrive (the pod's `terminationGracePeriodSeconds: 45` covers 10 s + the app's 20 s shutdown timeout, enforced by the chart). The app-level alternative needs no preStop: `DRAIN_DELAY_SECONDS` keeps the process serving, with `/ready` at 503, after SIGTERM:
```bash
helm upgrade orderflow $CHART -n orderflow -f $CHART/values-dev.yaml \
  --set orderApi.replicaCount=2 --set shutdown.preStopSleepSeconds=0 --set shutdown.drainDelaySeconds=10 --wait
bash "${TMPDIR:-/tmp}/rollout-load.sh"
```
*You should see (revision **14**): `4152 200`: zero errors again.* And watch the drain from the inside (log streams started **before** the delete, because logs vanish with the pod):
```bash
POD=$(kubectl get pods -n orderflow -l app=order-api -o name | head -1)
(kubectl logs -f $POD -n orderflow -c readiness-watcher > /tmp/watcher.log 2>&1 &); (kubectl logs -f $POD -n orderflow -c order-api > /tmp/app.log 2>&1 &)
sleep 2; kubectl delete $POD -n orderflow; sleep 2
cat /tmp/watcher.log /tmp/app.log
```
*You should see: the watcher `/ready: unknown -> not-ready`, `not-ready -> ready`, then (one poll after SIGTERM) `ready -> not-ready` and finally `watcher stopping`; the app `listening on port 8080`, `SIGTERM received, draining`, and 10 s later `order-api stopped`. The sidecar's last line comes after the app has stopped: sidecars are terminated after the main containers.* During those 10 s `curl`ing the pod's `/ready` returns 503 while the Gateway has already stopped sending it traffic.

### Step 9: PDB: what it protects, what it does not
A PDB gates **evictions**. Make the budget impossible to satisfy, then ask the API to evict a pod (the same call `kubectl drain` makes for every pod on a node; do not drain the Docker Desktop node):
```bash
helm upgrade orderflow $CHART -n orderflow -f $CHART/values-dev.yaml \
  --set orderApi.replicaCount=2 --set pdb.enabled=true --set pdb.minAvailable=2 --wait
sleep 15; kubectl get pdb -n orderflow
POD=$(kubectl get pods -n orderflow -l app=order-api --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
echo "{\"apiVersion\":\"policy/v1\",\"kind\":\"Eviction\",\"metadata\":{\"name\":\"$POD\",\"namespace\":\"orderflow\"}}" \
  | kubectl create --raw /api/v1/namespaces/orderflow/pods/$POD/eviction -f -
kubectl get pods -n orderflow -l app=order-api
```
*You should see: `MIN AVAILABLE 2`, `ALLOWED DISRUPTIONS 0`; `Error from server (TooManyRequests): Cannot evict pod as it would violate the pod's disruption budget.`; both pods untouched. (A `drain` would sit retrying this forever.)* Now the sane budget (`maxUnavailable: 1`) and the same eviction:
```bash
helm upgrade orderflow $CHART -n orderflow -f $CHART/values-dev.yaml --set orderApi.replicaCount=2 --set pdb.enabled=true --wait
sleep 15; kubectl get pdb -n orderflow
POD=$(kubectl get pods -n orderflow -l app=order-api --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
echo "{\"apiVersion\":\"policy/v1\",\"kind\":\"Eviction\",\"metadata\":{\"name\":\"$POD\",\"namespace\":\"orderflow\"}}" \
  | kubectl create --raw /api/v1/namespaces/orderflow/pods/$POD/eviction -f -
kubectl get pods -n orderflow -l app=order-api
```
*You should see: `MAX UNAVAILABLE 1`, `ALLOWED DISRUPTIONS 1`; `"status":"Success","code":201`; the evicted pod `Terminating` while the **Deployment** (not the PDB) starts a replacement; 20 s later two `2/2` pods again.* What the PDB did not do: create replicas, stop `kubectl delete pod`, or protect against a node crash or an OOM kill (in Step 6 the PDB did not prevent the OOM kill: it is an involuntary disruption; a PDB would not have changed that).

### Optional: `helm diff`
```bash
helm plugin install https://github.com/databus23/helm-diff --verify=false   # Helm 4 verifies plugin signatures by default
helm diff upgrade orderflow $CHART -n orderflow -f $CHART/values-production.yaml | head -30
```
*You should see a unified diff, e.g. `-   replicas: 1` / `+   replicas: 2` for notification (and, for the HPA, the resources the upgrade would add), without changing anything.*

---

## Success Signal
1. `helm lint` is clean and `helm template … | kubectl apply --dry-run=server -f -` succeeds in the `restricted` namespace.
2. `helm install` produces revision 1; `order-api` is `2/2`; the migration Job logged `CREATE TABLE`; `orders` exists in Postgres; `curl http://localhost/orders` returns 200 through the Gateway.
3. `helm history` after Step 3 shows revisions 1, 2, 3 (`Rollback to 1`).
4. HPA scaled `order-api` from 2 to 6 under load; the OOM left `OOMKilled` / 137; the bad readiness path left old pods serving.
5. The rollout with preStop 0 produced failed requests; with 10 s (or `DRAIN_DELAY_SECONDS=10`) none.
6. The PDB returned 429 for an over-budget eviction.

---

## Stuck? Hints
- **`helm install` fails with `violates PodSecurity "restricted:latest"`** → you edited a template and dropped `seccompProfile`, `allowPrivilegeEscalation: false`, `drop: ["ALL"]` or a numeric `runAsUser` → `helm template … | kubectl apply --dry-run=server -f -` names the missing field; the helpers `orderflow.podSecurityContext` / `containerSecurityContext` have all of them.
- **`... already exists` / `cannot re-use a name` / a ConfigMap `orderflow-config` collision** → leftovers from Day 3-5 in the namespace, or a half-failed release → `bash labs/shared/reset.sh` (it uninstalls the release too) and re-apply the PSA label.
- **`ImagePullBackOff` on `orderflow/*`** → images are not in the node → `bash labs/shared/load-images.sh`. For `postgres:16-alpine`/`busybox:1.37` the node needs internet.
- **`order-api` stuck at `Init:0/2`** → `wait-for-postgres` is waiting (`kubectl logs <pod> -c wait-for-postgres`): Postgres not Ready yet (`kubectl get pods`), or the DNS record for the headless Service has not appeared. It resolves by itself within about a minute. If `pg_isready` says `no attempt` the init container is running as a UID without a passwd entry; the chart sets `runAsUser: 70` for it. If the *hook* fails instead (`helm install` ends with `BackoffLimitExceeded` / `context deadline exceeded`), read `kubectl logs job/orderflow-db-migration -n orderflow`; after a re-install into a namespace whose Postgres PVC survived, a changed `postgres.auth.password` no longer matches the volume, so use `reset.sh` (it deletes the PVC).
- **`curl http://localhost/orders` → connection refused / 503 from Envoy** → the Gateway is not Programmed or no pod is Ready yet → `kubectl get gateway edge -n gateway-infra`, `kubectl get httproute -n orderflow` (`Accepted: True`). `http://localhost` works on Docker Desktop (kind or kubeadm); use the Day 4 port-forward fallback only on plain kind or if port 80 is busy. In the load test a few `000` statuses can also mean the Mac ran out of ephemeral ports: keep the `sleep 0.1`.
- **HPA `TARGETS <unknown>`** → metrics-server missing (`kubectl top pods` errors: apply `labs/shared/metrics-server.yaml`) or the pods are under a minute old.

---

## Teardown
```bash
helm uninstall orderflow -n orderflow --ignore-not-found
bash labs/shared/reset.sh
kubectl delete namespace orderflow --ignore-not-found
```
This removes the release, the Postgres PVC (with the namespace) and the `restricted` label. The Gateway `edge`, Envoy Gateway and metrics-server stay installed: they are shared platform pieces used by Day 7 (and Day 4 for the Gateway).

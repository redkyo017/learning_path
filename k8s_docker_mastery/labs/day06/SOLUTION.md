# Day 6 Lab Solution: Helm 4, OrderFlow Chart & Graceful Shutdown

Reference output from a live run on Docker Desktop Kubernetes (kind provisioner, k8s 1.34, context `docker-desktop`), Helm v4.3.0, Envoy Gateway v1.9.2, metrics-server v0.9.0. Pod name suffixes, timestamps, IPs and ages differ on your machine; revision numbers, counts and exit codes should match. Output is trimmed with `...`.

Convention in this file: `CHART=labs/day06/orderflow-chart`.

---

## Prerequisites
```text
$ bash labs/shared/reset.sh      →  namespace/orderflow Active, labels kubernetes.io/metadata.name=orderflow
$ bash labs/shared/load-images.sh →  loaded orderflow/order-api:v1 / payment-service:v1 / notification-service:v1
$ kubectl label ns orderflow --overwrite pod-security.kubernetes.io/enforce=restricted ...
namespace/orderflow labeled
$ kubectl get gateway edge -n gateway-infra
NAME   CLASS   ADDRESS      PROGRAMMED   AGE
edge   eg      172.21.0.5   True         26m
$ kubectl top nodes
NAME                    CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
desktop-control-plane   170m         2%       1674Mi          21%
```

## Step 1: Lint, render, validate
```text
$ helm lint $CHART -f $CHART/values-dev.yaml
==> Linting labs/day06/orderflow-chart
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed

$ helm template orderflow $CHART -n orderflow -f $CHART/values-dev.yaml | kubectl apply --dry-run=server -f -
secret/orderflow-postgres-auth created (server dry run)
configmap/orderflow-order-api-config created (server dry run)
service/orderflow-postgres created (server dry run)
service/orderflow-order-api created (server dry run)
service/orderflow-payment created (server dry run)
service/orderflow-notification created (server dry run)
deployment.apps/orderflow-order-api created (server dry run)
deployment.apps/orderflow-payment created (server dry run)
deployment.apps/orderflow-notification created (server dry run)
statefulset.apps/orderflow-postgres created (server dry run)
httproute.gateway.networking.k8s.io/orderflow created (server dry run)
job.batch/orderflow-db-migration created (server dry run)
```
No `Warning: would violate PodSecurity` lines: every pod, including the hook Job, is `restricted`-compliant.

Kinds and replicas of the dev render (`/usr/bin/grep -E '^kind:|replicas:'`): `Secret`, `ConfigMap`, four `Service`, three `Deployment` each with `replicas: 1`, `StatefulSet` (`replicas: 1`), `HTTPRoute`, `Job`.

Production render:
```text
kind: PodDisruptionBudget
  replicas: 3          # payment
  replicas: 2          # notification
kind: HorizontalPodAutoscaler
  replicas: 1          # the Postgres StatefulSet
```
There is no `replicas:` for the order-api Deployment: `hpa.enabled=true` omits it.

Render-time guard and optional Ingress:
```text
$ helm template orderflow $CHART --set shutdown.preStopSleepSeconds=30 2>&1 | /usr/bin/grep Error
Error: execution error at (orderflow/templates/deployment.yaml:1:4): shutdown.terminationGracePeriodSeconds=45 is too short: need >= preStopSleepSeconds + drainDelaySeconds + 20 = 50
```
The Ingress render (`ingress.enabled=true`, `gateway.enabled=false`, `className=alb`, host, annotation):
```yaml
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  ingressClassName: alb
  rules:
    -
      host: orderflow.example.com
      http:
        paths:
          - path: /orders
            pathType: Prefix
            backend:
              service:
                name: orderflow-order-api
                port:
                  number: 8080
```
It also passes `kubectl apply --dry-run=server` (`ingress.networking.k8s.io/orderflow-ingress created (server dry run)`). No rewrite annotation: with `Prefix` paths nothing needs rewriting.

## Step 2: Install (revision 1)
```text
$ helm install orderflow $CHART -n orderflow -f $CHART/values-dev.yaml
NAME: orderflow
NAMESPACE: orderflow
STATUS: deployed
REVISION: 1
DESCRIPTION: Install complete
NOTES:
OrderFlow v1 installed as release "orderflow" in namespace "orderflow".
Services:   orderflow-order-api, -payment, -notification
Database:   orderflow-postgres-0 (migration Job: orderflow-db-migration)
Edge:       HTTPRoute orderflow -> Gateway gateway-infra/edge
            curl http://localhost/orders

$ kubectl get pods -n orderflow            # right after helm returned (~16 s: it waited for the hook Job)
NAME                                      READY   STATUS            RESTARTS   AGE
orderflow-db-migration-99mh8              0/1     Completed         0          16s
orderflow-notification-7697fb8c6d-wcj5q   1/1     Running           0          16s
orderflow-order-api-5dcbf85559-dqlfm      1/2     PodInitializing   0          16s
orderflow-payment-688cdfcd87-w7dnh        1/1     Running           0          16s
orderflow-postgres-0                      1/1     Running           0          16s

$ kubectl get pods -n orderflow            # ~20 s later
orderflow-order-api-5dcbf85559-dqlfm      2/2     Running     0          36s
...
```
`helm install` blocks on hooks only (Helm 4's default `--wait=hookOnly`), so the Job is done when it returns; the Deployments are not waited for without `--wait`.
```text
$ kubectl logs job/orderflow-db-migration -n orderflow
orderflow-postgres:5432 - no response        # (repeated while Postgres starts)
orderflow-postgres:5432 - accepting connections
applying 2 migration statement(s)
CREATE TABLE
ALTER TABLE
schema now:
                             Table "public.orders"
   Column   |           Type           | Collation | Nullable |     Default
------------+--------------------------+-----------+----------+-----------------
 id         | text                     |           | not null |
 item       | text                     |           | not null |
 qty        | integer                  |           | not null |
 status     | text                     |           | not null | 'PENDING'::text
 created_at | timestamp with time zone |           | not null | now()
 note       | text                     |           |          |
Indexes:
    "orders_pkey" PRIMARY KEY, btree (id)

migration complete

$ kubectl exec orderflow-postgres-0 -n orderflow -- psql -U orderflow -d orderflow -c '\dt'
          List of relations
 Schema |  Name  | Type  |   Owner
--------+--------+-------+-----------
 public | orders | table | orderflow
(1 row)

$ kubectl logs deploy/orderflow-order-api -n orderflow -c readiness-watcher
14:24:13 /ready: unknown -> not-ready
14:24:15 /ready: not-ready -> ready

$ curl -i http://localhost/orders
HTTP/1.1 200 OK
content-type: application/json
...
[]
$ curl -s -X POST http://localhost/orders -d '{"item":"book","qty":2}'
{"id":"559f46217bb300b3","item":"book","qty":2,"status":"PENDING","created_at":"2026-10-06T14:24:34.500553846Z"}
```
Why this is the right design: the sidecar (`readiness-watcher`) is an `initContainers` entry with `restartPolicy: Always`, so it starts before the app (its first poll fails: `unknown -> not-ready`), and its `ready` state counts toward `2/2`. The init container `wait-for-postgres` only gates start-up; the **schema** is created once per release by the hook Job, not once per replica by an init container. The password comes from `Secret/orderflow-postgres-auth` (mounted as a file for Postgres, an env var from `secretKeyRef` for the Job's `psql`).

## Step 3: Upgrade, history, rollback
```text
$ helm upgrade orderflow $CHART -n orderflow -f $CHART/values-dev.yaml --set orderApi.replicaCount=3 --wait
STATUS: deployed
REVISION: 2
$ helm history orderflow -n orderflow
REVISION	UPDATED                 	STATUS    	CHART          	APP VERSION	DESCRIPTION
1       	Tue Oct  6 21:23:58 2026	superseded	orderflow-0.2.0	v1         	Install complete
2       	Tue Oct  6 21:24:47 2026	deployed  	orderflow-0.2.0	v1         	Upgrade complete
$ kubectl get deploy orderflow-order-api -n orderflow
orderflow-order-api   3/3     3            3           59s
$ kubectl get jobs -n orderflow
NAME                     STATUS     COMPLETIONS   DURATION   AGE
orderflow-db-migration   Complete   1/1           3s         10s       # the pre-upgrade hook ran again (before-hook-creation replaced the old Job)

$ helm rollback orderflow 1 -n orderflow --wait
Rollback was a success! Happy Helming!
$ helm history orderflow -n orderflow
1       	...	superseded	orderflow-0.2.0	v1	Install complete
2       	...	superseded	orderflow-0.2.0	v1	Upgrade complete
3       	...	deployed  	orderflow-0.2.0	v1	Rollback to 1
$ kubectl get deploy orderflow-order-api -n orderflow
orderflow-order-api   1/1     1            1           59s
$ kubectl get secrets -n orderflow -l owner=helm
NAME                              TYPE                 DATA   AGE
sh.helm.release.v1.orderflow.v1   helm.sh/release.v1   1      59s
sh.helm.release.v1.orderflow.v2   helm.sh/release.v1   1      10s
sh.helm.release.v1.orderflow.v3   helm.sh/release.v1   1      0s
```
`helm get values orderflow -n orderflow --revision 2` shows `orderApi.replicaCount: 3` (the dev overlay values plus the `--set`). A rollback is revision 3, not a rewind to 1.

## Step 4: Production profile (revision 4)
```text
$ helm upgrade orderflow $CHART -n orderflow -f $CHART/values-production.yaml --wait
REVISION: 4
$ kubectl get deploy,hpa,pdb -n orderflow
deployment.apps/orderflow-notification   2/2     2            2           76s
deployment.apps/orderflow-order-api      1/1     1            1           76s
deployment.apps/orderflow-payment        3/3     3            3           76s

NAME                                                          REFERENCE                        TARGETS              MINPODS   MAXPODS   REPLICAS   AGE
horizontalpodautoscaler.autoscaling/orderflow-order-api-hpa   Deployment/orderflow-order-api   cpu: <unknown>/70%   2         10        0          5s

NAME                                                 MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
poddisruptionbudget.policy/orderflow-order-api-pdb   N/A             1                 1                     5s
$ kubectl get deploy orderflow-order-api -n orderflow -o jsonpath='{.spec.replicas}{"\n"}'
1
```
About 30 s later: `kubectl get pods -l app=order-api` lists two `2/2` pods, and the HPA events show `SuccessRescale ... New size: 2; reason: Current number of replicas below Spec.MinReplicas`. For the first ~20 s after the new pods exist the HPA reports `FailedGetResourceMetric ... did not receive metrics for targeted pods (pods might be unready)`: metrics-server has not scraped them yet; this is the normal `<unknown>` window, not a defect.

## Step 5: HPA under load (revision 5)
```text
$ helm upgrade ... -f values-production.yaml --set hpa.targetCPUUtilizationPercentage=30 --wait
REVISION: 5
(load running: 16 parallel curl loops against http://localhost/orders)
orderflow-order-api-hpa   Deployment/orderflow-order-api   cpu: 72%/30%   2     10    2     3m15s
orderflow-order-api-hpa   Deployment/orderflow-order-api   cpu: 76%/30%   2     10    2     3m30s
orderflow-order-api-hpa   Deployment/orderflow-order-api   cpu: 49%/30%   2     10    4     3m45s
orderflow-order-api-hpa   Deployment/orderflow-order-api   cpu: 47%/30%   2     10    6     4m
orderflow-order-api-hpa   Deployment/orderflow-order-api   cpu: 26%/30%   2     10    6     4m15s
orderflow-order-api-hpa   Deployment/orderflow-order-api   cpu: 22%/30%   2     10    6     4m30s
orderflow-order-api-hpa   Deployment/orderflow-order-api   cpu: 19%/30%   2     10    6     4m45s
```
(An earlier run with the default 70% target hovered at 55-73%: a laptop barely saturates 2 pods at 100 m, which is why the lab lowers the target.) After stopping the load:
```text
$ kubectl get hpa -n orderflow --no-headers
orderflow-order-api-hpa   Deployment/orderflow-order-api   cpu: 20%/30%   2     10    6     5m14s
$ kubectl get deploy orderflow-order-api -n orderflow --no-headers
orderflow-order-api   6/6   6     6     6m25s
$ kubectl top pods -n orderflow -l app=order-api --no-headers | head -3
orderflow-order-api-5fdcdf6757-4k4qp   32m   8Mi
orderflow-order-api-5fdcdf6757-7f24g   19m   8Mi
orderflow-order-api-5fdcdf6757-n62ln   29m   9Mi
```
Utilization is computed from the containers' CPU requests (check `kubectl describe hpa` for exactly what your version counts; with the 100 m app request alone 76% is about 76 m, with the 10 m sidecar added about 84 m). (Note: on a laptop the HPA may stop at 3-4 replicas, observed 34-44% CPU, instead of this reference run's 6; the later counts below, 5/6 and so on, then become N-1 of N for your N.) Replicas stay at 6 because of the 300 s scale-down stabilization window. The next `helm upgrade` (revision 6) left the 6 replicas in place: the Deployment template does not render `replicas` while the HPA is enabled.

## Step 6: OOM (revisions 6 and 7)
```text
$ helm upgrade ... --set hpa.targetCPUUtilizationPercentage=30 --set orderApi.enableDebugAlloc=true --set orderApi.resources.limits.memory=64Mi --wait --timeout 120s
REVISION: 6
$ curl -s "localhost:18080/debug/alloc?mb=20"
{"allocated_mb":20,"retained_mb":20}
$ curl -s -m 10 -w "curl exit=%{exitcode}\n" "localhost:18080/debug/alloc?mb=100"
curl exit=52
$ kubectl get pods -n orderflow -l app=order-api
orderflow-order-api-6bd84ff977-9b6rg   2/2     Running   1 (5s ago)   32s
orderflow-order-api-6bd84ff977-h9wgz   2/2     Running   0            36s
...
$ kubectl describe pod orderflow-order-api-6bd84ff977-9b6rg -n orderflow | /usr/bin/grep -E "Reason:|Exit Code:|Last State|Restart Count"
      Reason:       Completed        # init container wait-for-postgres
      Exit Code:    0
    Restart Count:  0                # readiness-watcher
    Restart Count:  0
    Last State:     Terminated       # order-api
      Reason:       OOMKilled
      Exit Code:    137
    Restart Count:  1
```
Why 64Mi and not 15Mi: requests (64Mi) must be ≤ limits, so `limits.memory=15Mi` is rejected by the API server (`must be less than or equal to memory limit`) before anything runs; and a Go process idles at ~5-9 MiB, so even a legal low limit would not OOM without an allocator. 20 MiB fits; the retained 100 MiB on top exceeds 64Mi and the kernel OOM killer sends SIGKILL (exit 137 = 128 + 9). curl exit 52 is "empty reply from server".

Rollback:
```text
$ helm history orderflow -n orderflow | tail -3
4       ...	superseded	orderflow-0.2.0	v1	Upgrade complete
5       ...	superseded	orderflow-0.2.0	v1	Upgrade complete
6       ...	deployed  	orderflow-0.2.0	v1	Upgrade complete
$ helm rollback orderflow 5 -n orderflow --wait
Rollback was a success! Happy Helming!
$ helm history orderflow -n orderflow | tail -4
5       ...	superseded	orderflow-0.2.0	v1	Upgrade complete
6       ...	superseded	orderflow-0.2.0	v1	Upgrade complete
7       ...	deployed  	orderflow-0.2.0	v1	Rollback to 5
$ kubectl get deploy orderflow-order-api -n orderflow -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}{" "}{.spec.template.spec.containers[0].env}{"\n"}'
128Mi [{"name":"DRAIN_DELAY_SECONDS","value":"0"}]
```
The correct target is **5**: revision 4 is the production profile with the default 70% target, revision 5 is the last revision that was actually in the state you want to return to, and rolling back to "current - 1" would have worked here only by accident.

## Step 7: Broken readiness (revisions 8 to 11)
```text
$ helm upgrade ... --set hpa.targetCPUUtilizationPercentage=30 --set probes.readiness.path=/nonexistent
REVISION: 8
$ kubectl get pods -n orderflow             # after 25 s
orderflow-notification-5b58f48948-zd6nx   0/1     Running     0          25s
orderflow-notification-7697fb8c6d-brwbv   1/1     Running     0          6m41s
orderflow-notification-7697fb8c6d-wcj5q   1/1     Running     0          7m52s
orderflow-order-api-5fdcdf6757-2866f      2/2     Running     0          39s       (x5 old)
orderflow-order-api-668bc8c677-7gdwb      1/2     Running     0          25s       (x3 new)
orderflow-payment-b45464999-rkfds         0/1     Running     0          25s
...
$ kubectl get deploy -n orderflow
orderflow-notification   2/2     1            2           7m52s
orderflow-order-api      5/6     3            5           7m52s
orderflow-payment        3/3     1            3           7m52s
$ kubectl get endpointslice ... (order-api)
10.244.0.131 ready=true
10.244.0.130 ready=true
10.244.0.129 ready=true
10.244.0.133 ready=true
10.244.0.134 ready=true
10.244.0.137 ready=false
10.244.0.139 ready=false
10.244.0.136 ready=false
$ curl -s -o /dev/null -w "%{http_code}\n" http://localhost/orders
200
```
The new pods run (`Running`, sidecar ready) but their readiness probe gets 404, so the EndpointSlice marks them `ready=false` and the Gateway never sends them traffic. `maxUnavailable` (25% of 6 rounds down to 1) lets exactly one old pod go, so five serve. All three Deployments are affected because `probes.*` is shared by the three services.
```text
$ helm rollback orderflow 7 -n orderflow --wait
Rollback was a success! Happy Helming!                        # revision 9, "Rollback to 7"

$ helm upgrade ... --set probes.readiness.path=/nonexistent --rollback-on-failure --wait --timeout 45s
level=WARN msg="upgrade failed" name=orderflow error="resource Deployment/orderflow/orderflow-order-api not ready. status: InProgress, message: Updated: 3/6 ..."
Error: UPGRADE FAILED: release orderflow failed, and has been rolled back due to rollback-on-failure being set: resource Deployment/orderflow/orderflow-order-api not ready. status: InProgress, message: Updated: 3/6
resource Deployment/orderflow/orderflow-payment not ready. status: InProgress, message: Updated: 1/3
resource Deployment/orderflow/orderflow-notification not ready. status: InProgress, message: Updated: 1/2
context deadline exceeded
$ helm history orderflow -n orderflow | tail -4
8       ...	superseded	orderflow-0.2.0	v1	Upgrade complete
9       ...	superseded	orderflow-0.2.0	v1	Rollback to 7
10      ...	failed    	orderflow-0.2.0	v1	Upgrade "orderflow" failed: resource Deployment/orderflow/orderflow-order-api not ready. status: InProgress, message: Updated: ...
11      ...	deployed  	orderflow-0.2.0	v1	Rollback to 9
$ kubectl get deploy -n orderflow
orderflow-notification   2/2     2            2           9m1s
orderflow-order-api      6/6     6            6           9m1s
orderflow-payment        3/3     3            3           9m1s
```
(About 56 s in total: 45 s waiting plus the automatic rollback.) Note: `helm history` keeps only the latest 10 revisions by default (`--history-max`), so by this point revision 1 has already been pruned; that is why Step 3's Secrets were looked at early.

## Step 8: Graceful shutdown
The tallies below are the output of the load script (`uniq -c` of HTTP statuses) in the reference run; total requests per run are about 4100-4200.

preStop 0 (revision 12):
```text
   3 000
4126 200
   3 503
```
Further runs: `3 000 / 4142 200 / 2 503`, and with a faster loop (no `sleep 0.1`) `31307 200 / 37 503` (that run also logged thousands of `000` because the Mac exhausted its ephemeral ports: ignore those, and the reason the loop sleeps).

preStop 10 (revision 13), two runs:
```text
4216 200
```
```text
4161 200
```
`DRAIN_DELAY_SECONDS=10` with preStop 0 (revision 14):
```text
4152 200
```
Inside a draining pod (log streams started before the delete; app has `DRAIN_DELAY_SECONDS=10`):
```text
watcher:
14:41:44 /ready: unknown -> not-ready
14:41:46 /ready: not-ready -> ready
14:42:00 /ready: ready -> not-ready
watcher stopping
app:
2026/10/06 14:41:44 order-api listening on port 8080
2026/10/06 14:41:59 SIGTERM received, draining
2026/10/06 14:42:09 order-api stopped
```
Between SIGTERM (`:59`) and exit (`:09`) the pod answered `/ready` with 503 (`kubectl exec ... -c readiness-watcher -- wget -q -O- http://127.0.0.1:8080/ready` printed `wget: server returned error: HTTP/1.1 503 Service Unavailable`) and `curl http://localhost/orders` still returned 200 (served by the other pod); the sidecar's `watcher stopping` is printed only after the app has stopped.

Explanation: on pod deletion the endpoint removal and the kubelet's preStop/SIGTERM start at the same time. With no preStop, Go's `Shutdown` closes the listener at once while Envoy still has the pod's IP for a short moment: the few `503`/`000` per rollout are those requests. With a 10 s `preStop.sleep` (or an app-level 10 s drain) the pod keeps accepting while the removal propagates, and the rollout is error-free. `terminationGracePeriodSeconds: 45` ≥ 10 + 20 (app shutdown timeout) + margin; the chart's `validateShutdown` helper enforces `grace ≥ preStop + drain + 20` at render time.

## Step 9: PDB
```text
$ helm upgrade ... -f values-dev.yaml --set orderApi.replicaCount=2 --set pdb.enabled=true --set pdb.minAvailable=2 --wait
$ kubectl get pdb -n orderflow
NAME                      MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
orderflow-order-api-pdb   2               N/A               0                     65s
$ ... | kubectl create --raw /api/v1/namespaces/orderflow/pods/$POD/eviction -f -
Error from server (TooManyRequests): Cannot evict pod as it would violate the pod's disruption budget.
$ kubectl get pods -n orderflow -l app=order-api
orderflow-order-api-68c758cb54-f6lbx   2/2     Running   0          58s
orderflow-order-api-68c758cb54-jmgl8   2/2     Running   0          65s

$ helm upgrade ... --set orderApi.replicaCount=2 --set pdb.enabled=true --wait
$ kubectl get pdb -n orderflow
orderflow-order-api-pdb   N/A             1                 1                     84s
$ ... eviction
{"kind":"Status","apiVersion":"v1","metadata":{},"status":"Success","code":201}
$ kubectl get pods -n orderflow -l app=order-api
orderflow-order-api-68c758cb54-f6lbx   2/2     Terminating   0          77s
orderflow-order-api-68c758cb54-f8hk6   0/2     Init:0/2      0          0s       # replacement from the Deployment
orderflow-order-api-68c758cb54-jmgl8   2/2     Running       0          84s
(20 s later)
orderflow-order-api-68c758cb54-f8hk6   2/2     Running   0          20s
orderflow-order-api-68c758cb54-jmgl8   2/2     Running   0          104s
```
Following the README exactly, this step produces revisions 15 and 16 (the reference run had extra upgrades in between, so it showed 15-18; the README does not assert them). `ALLOWED DISRUPTIONS` is `current healthy - minAvailable` (2 - 2 = 0), or `maxUnavailable - already unavailable` (1). The PDB only answered the eviction call; the replacement pod came from the ReplicaSet. `kubectl drain` makes exactly this call per pod and retries on 429, which is why a zero-disruption PDB hangs a node upgrade. It would not have stopped `kubectl delete pod` (plain delete, no eviction) or the OOM kill in Step 6.

## Optional: `helm diff`
```text
$ helm plugin install https://github.com/databus23/helm-diff --verify=false
Installed plugin: diff
$ helm diff upgrade orderflow $CHART -n orderflow -f $CHART/values-production.yaml | head
orderflow, orderflow-notification, Deployment (apps) has changed:
  ...
-   replicas: 1
+   replicas: 2
```

---

## Teardown
```text
$ helm uninstall orderflow -n orderflow --ignore-not-found
$ bash labs/shared/reset.sh
$ kubectl delete namespace orderflow --ignore-not-found
namespace "orderflow" deleted
$ kubectl get ns
NAME                   STATUS   AGE
default                Active   ...
envoy-gateway-system   Active   ...
gateway-infra          Active   ...
kube-node-lease        Active   ...
kube-public            Active   ...
kube-system            Active   ...
local-path-storage     Active   ...
```
`orderflow` is gone; the Gateway, Envoy Gateway and metrics-server remain.

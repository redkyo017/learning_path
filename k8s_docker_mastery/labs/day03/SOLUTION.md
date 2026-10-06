# Day 3 Lab: Solution & Explanations

Outputs below come from a live run on Docker Desktop (kind provisioner, k8s 1.34). Pod-name suffixes and ages differ on every run; counts, ports and ReplicaSet/`pod-template-hash` values (derived from the template) are stable. Commands run from the course root.

## Detailed Step-by-Step Walkthrough

### 1–2. Reset, load images, apply, verify
```bash
kubectl get all -n orderflow
```
```text
NAME                                        READY   STATUS    RESTARTS   AGE
pod/notification-service-7ff58995f5-srdpf   1/1     Running   0          3s
pod/order-api-68bfbb75fc-hgph6              1/1     Running   0          3s
pod/order-api-68bfbb75fc-t7j2c              1/1     Running   0          3s
pod/payment-service-57c5477b99-cdccp        1/1     Running   0          3s
pod/payment-service-57c5477b99-wbs2b        1/1     Running   0          3s

NAME                           TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/notification-service   ClusterIP   10.96.18.251   <none>        8082/TCP   3s
service/order-api              ClusterIP   10.96.4.24     <none>        8080/TCP   3s
service/payment-service        ClusterIP   10.96.233.6    <none>        8081/TCP   3s

NAME                                   READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/notification-service   1/1     1            1           3s
deployment.apps/order-api              2/2     2            2           3s
deployment.apps/payment-service        2/2     2            2           3s

NAME                                              DESIRED   CURRENT   READY   AGE
replicaset.apps/notification-service-7ff58995f5   1         1         1       3s
replicaset.apps/order-api-68bfbb75fc              2         2         2       3s
replicaset.apps/payment-service-57c5477b99        2         2         2       3s
```
Ports: order-api 8080, payment-service **8081**, notification-service 8082 (the Service `targetPort` is the named container port `http`). Cluster IPs differ per run.

Why the probes differ: `/ready` returns 503 once the process receives SIGTERM, so the pod leaves the Service endpoints before it stops; `/health` stays 200 while the process runs, so liveness never restarts a pod merely because it is draining. The `startupProbe` (30 x 2 s on `/health`) holds liveness off until the process has started.

### 3. API access
```text
HTTP/1.1 200 OK        <- /health   {"status":"ok","service":"order-api"}
HTTP/1.1 200 OK        <- /ready
HTTP/1.1 201 Created   <- POST /orders  {"id":"c80a176d8f21cbb3","item":"K8s Book","qty":1,"status":"PENDING",...}
[pod/payment-service-57c5477b99-cdccp/payment-service] ... processing payment for order: c80a176d8f21cbb3, amount: $29.99
```
The payment log appears on only one of the two payment pods (the Service picked one); the downstream calls are fire-and-forget goroutines in `order-api`.

### 4. Scale and restore
After `kubectl scale ... --replicas=5`: 5 pods, 3 of them `0/1 Running` for a couple of seconds (readiness not yet passed). After `kubectl apply -f labs/day03/manifests/order-api.yaml`:
```text
NAME        READY   UP-TO-DATE   AVAILABLE   AGE
order-api   2/2     2            2           13s
```
`apply` compares the file with the last-applied state and the live object; `replicas: 2` in the file differs from the live 5, so it is set back to 2 (3 pods deleted). Imperative `scale` changes are not recorded in the file. If an HPA owns `replicas`, remove the field from the manifest so `apply` does not fight it.

### 5. Ownership, orphan delete, re-adoption
```text
NAME                         OWNER-KIND   OWNER
order-api-68bfbb75fc-hgph6   ReplicaSet   order-api-68bfbb75fc        <- pods owned by the RS
order-api-68bfbb75fc         Deployment   order-api                   <- RS owned by the Deployment

$ kubectl delete deploy order-api -n orderflow --cascade=orphan
NAME                                   DESIRED   CURRENT   READY   AGE
replicaset.apps/order-api-68bfbb75fc   2         2         2       13s       <- still there, still 2/2
NAME                   OWNER-KIND   OWNER
order-api-68bfbb75fc   <none>       <none>                                  <- ownerReference removed

$ kubectl apply -f labs/day03/manifests/order-api.yaml
deployment.apps/order-api created
NAME                   OWNER-KIND   OWNER
order-api-68bfbb75fc   Deployment   order-api                               <- adopted again; same pods (ages 15s)
```
Mechanics: `ownerReferences` (`controller: true, blockOwnerDeletion: true`) are what the garbage collector follows. Default delete (background) removes the owner and lets the GC delete dependents; `--cascade=foreground` keeps the owner until dependents are gone; `--cascade=orphan` strips the ownerReference from dependents. A new Deployment lists ReplicaSets matching its selector that have no controller owner and **adopts** those whose pod template matches (hash `68bfbb75fc`), so nothing restarts. Observed side-effect while testing: re-applying a file whose template differs from the orphaned live ReplicaSet (file says v1, orphan was v2) adopted the matching old v1 ReplicaSet and rolled back to it, so apply the same template you orphaned.

### 6. Rolling update v1 → v2
```text
NAME                         HASH         IMAGE                    APP_VERSION
order-api-68bfbb75fc-hgph6   68bfbb75fc   orderflow/order-api:v1   v1
order-api-68bfbb75fc-t7j2c   68bfbb75fc   orderflow/order-api:v1   v1
...
Waiting for deployment "order-api" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "order-api" rollout to finish: 1 old replicas are pending termination...
deployment "order-api" successfully rolled out

NAME                   DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES                   SELECTOR
order-api-574d4b49f5   2         2         2       6s    order-api    orderflow/order-api:v2   app=order-api,pod-template-hash=574d4b49f5
order-api-68bfbb75fc   0         0         0       22s   order-api    orderflow/order-api:v1   app=order-api,pod-template-hash=68bfbb75fc

NAME                         HASH         IMAGE                    APP_VERSION
order-api-574d4b49f5-8vqnt   574d4b49f5   orderflow/order-api:v2   v2
order-api-574d4b49f5-gwfqc   574d4b49f5   orderflow/order-api:v2   v2
order-api-68bfbb75fc-hgph6   68bfbb75fc   orderflow/order-api:v1   v1     <- still terminating when listed

REVISION  CHANGE-CAUSE
1         v1 baseline
2         v2: image + APP_VERSION
```
Why this is the honest observable: v1 and v2 are the same Go source, so the app returns identical responses. What Kubernetes reacts to is the **pod template change**: any change (image tag, env, probe, label) gives a new `pod-template-hash`, hence a new ReplicaSet and a rolling update governed by `maxSurge: 1` / `maxUnavailable: 0` (at most 3 pods, never fewer than 2 Ready). `APP_VERSION` is there so you can see the change on the pod, not because the app uses it.

### 7. Stuck rollout and undo
```text
deployment.apps/order-api image updated
Waiting for deployment "order-api" rollout to finish: 1 out of 2 new replicas have been updated...
error: deployment "order-api" exceeded its progress deadline
exit=1                                           (after ~45 s)

NAME                         READY   STATUS             RESTARTS   AGE
order-api-574d4b49f5-8vqnt   1/1     Running            0          49s
order-api-574d4b49f5-gwfqc   1/1     Running            0          52s
order-api-677c68477c-2876b   0/1     ImagePullBackOff   0          46s

Available=True MinimumReplicasAvailable
Progressing=False ProgressDeadlineExceeded

NAME        READY   UP-TO-DATE   AVAILABLE   AGE
order-api   2/2     1            2           55s
```
Why: `maxSurge: 1` allowed one extra pod (the `v99` one); it never became Ready, and `maxUnavailable: 0` forbids removing an old pod until it does, so both v2 pods keep serving. `UP-TO-DATE 1` counts the new-template pod, `AVAILABLE 2` the old ones. `progressDeadlineSeconds: 45` flips `Progressing` to `False`; the controller does nothing else. This step used `kubectl set image`, which only changes the image: the new pod's `APP_VERSION` stays `v2` while its image is `v99`, a quick way to see that image and env are independent template fields.

```text
$ kubectl rollout history deploy/order-api -n orderflow          # before undo
1  v1 baseline
2  v2: image + APP_VERSION
3  v99 (bad tag)

$ kubectl rollout undo deploy/order-api -n orderflow
deployment.apps/order-api rolled back

$ kubectl rollout history deploy/order-api -n orderflow          # after undo
1  v1 baseline
3  v99 (bad tag)
4  v2: image + APP_VERSION

order-api-574d4b49f5   2  2  2   orderflow/order-api:v2
order-api-677c68477c   0  0  0   orderflow/order-api:v99
order-api-68bfbb75fc   0  0  0   orderflow/order-api:v1
```
`undo` finds the previous revision's ReplicaSet (v2, hash `574d4b49f5`), copies its template back into the Deployment and scales it up; since a template change always creates a new revision number, the old revision 2 became **4** and disappeared as 2. Because the v2 ReplicaSet already had matching pods, the recovery took seconds.

### 8. Self-healing
```text
order-api-574d4b49f5-8vqnt   1/1   Terminating         0   49s
order-api-574d4b49f5-gwfqc   1/1   Running             0   52s
order-api-574d4b49f5-wbdnz   0/1   ContainerCreating   0   0s      <- replacement exists immediately
...6 s later: 2 pods Running
```
The ReplicaSet watch event for the pod's deletion (`deletionTimestamp` set) moves the pod out of the "active" count at once, so a replacement is created before the old container has stopped.

### 9. Label tampering and re-adoption
```text
order-api-574d4b49f5-gwfqc   1/1  Running  62s  orphaned-api      <- relabeled
order-api-574d4b49f5-wbdnz   1/1  Running  10s  order-api
order-api-574d4b49f5-zrmbx   1/1  Running  4s   order-api         <- created within 1-2 s of the relabel
ownerReferences=                                                   <- released
NAME              ADDRESSTYPE   PORTS   ENDPOINTS                     AGE
order-api-xxxxx   IPv4          8080    10.244.0.63,10.244.0.64       78s   <- only the two matching pods (EndpointSlice; Endpoints is deprecated since 1.33)

# after relabeling back:
order-api-574d4b49f5-gwfqc   ReplicaSet   order-api-574d4b49f5     <- re-adopted
order-api-574d4b49f5-wbdnz   ReplicaSet   order-api-574d4b49f5     <- zrmbx was deleted as surplus
```
Mechanics: the ReplicaSet controller reads pods from its informer cache (a LIST + WATCH, not repeated API calls), keeps those matching `app=order-api` **and** owned by it, and `claims`/`releases` pods accordingly. Relabeling out: release + create one replacement. Relabeling back: the unowned matching pod is adopted, count 3 > 2, so it deletes one pod (it prefers the newest/least-ready, here `zrmbx`). Note the Deployment's `pod-template-hash` label stayed on the orphan; only the `app` label was changed.

### 10. ConfigMap env vs volume vs subPath
```text
env:     hello-v1
volume:  hello-v1
subPath: hello-v1
configmap/demo-config patched
volume updated after 92s          <- expect roughly 60-90 s
env:     hello-v1                 <- never changes in a running container
volume:  hello-v2                 <- kubelet swapped the ..data symlink
subPath: hello-v1                 <- subPath is a bind mount of one file: never updated
lrwxrwxrwx    1 root     root     15 Oct  6 13:49 greeting -> ..data/greeting

$ kubectl patch cm demo-config-frozen ... 
The ConfigMap "demo-config-frozen" is invalid: data: Forbidden: field is immutable when `immutable` is set
```
Why: env vars are copied into the container's process environment at `execve`. A directory volume contains `greeting -> ..data/greeting` and `..data -> ..<timestamp>/`; on a change the kubelet writes a new timestamped directory and atomically repoints `..data`. A `subPath` mount resolves the path once at container start and bind-mounts that file, so it can never follow the symlink swap. The delay is up to one kubelet sync period (`syncFrequency`, 1 min default, plus jitter) plus watch propagation (default change-detection strategy `Watch`; the TTL applies only to the `Cache` strategy), so 60-90 s is normal even locally. `immutable: true` forbids edits to `data` (and the kubelet stops watching such objects). Even when the file changes, an app that reads it only at startup keeps its old values: apps must re-read or watch the file, or you restart the pods (`kubectl rollout restart`, or a checksum annotation in the template).

### Teardown check
```text
$ bash labs/shared/reset.sh && kubectl delete namespace orderflow
$ kubectl get ns     ->  default, kube-node-lease, kube-public, kube-system, local-path-storage   (no orderflow)
```

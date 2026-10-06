# Day 3 Lab: Kubernetes Core Objects, Workloads & Rolling Updates

**Run every command from the course root** (`k8s_docker_mastery/`). Target cluster: Docker Desktop Kubernetes on the **kind provisioner** (context `docker-desktop`, node `desktop-control-plane`). Alternatives: Docker Desktop's older *kubeadm* provisioner (node `docker-desktop`) sees local images directly, so `load-images.sh` has nothing to do; with plain `kind`, the script runs `kind load docker-image` for you.

## Start here — plain steps

1. Open a terminal in `k8s_docker_mastery/`. Check `kubectl config current-context` prints `docker-desktop` and `kubectl get nodes` shows one `Ready` node.
2. Run `bash labs/shared/reset.sh` (empty `orderflow` namespace) and `bash labs/shared/load-images.sh` then `bash labs/shared/load-images.sh v2` (builds and loads the `v1` and `v2` images into the cluster).
3. Apply the manifests in `labs/day03/manifests/` (config first, then the three services). You should see 5 pods `1/1 Running`, and `kubectl rollout status` ends with "successfully rolled out".
4. Port-forward `order-api`, `curl` `/health` and create an order. Scale to 5, then apply the file again and watch it return to 2.
5. Prove ownership: delete the Deployment with `--cascade=orphan`, see the ReplicaSet and pods survive, re-apply, and see the ReplicaSet adopted again with no new pods.
6. Roll out v2 (image and `APP_VERSION` env change together). Then roll out the non-existent tag `v99`: `rollout status` should fail after about 45 s with "exceeded its progress deadline" while both v2 pods keep serving. Run `rollout undo`.
7. Break it twice: delete a pod (replaced at once), relabel a pod (it leaves the ReplicaSet and a replacement appears), then relabel it back.
8. Run the ConfigMap demo pod (`labs/day03/demo/`): change the ConfigMap, wait 1-2 minutes, and watch the volume file change while the env var and the `subPath` file stay stale. You are done when each step's "You should see" line matched; run **Teardown** at the end.

## Objective
Deploy the OrderFlow microservices from hand-written manifests (Deployments, Services, ConfigMap, Secret), including probes, resources and a restrictive `securityContext`, then explore the controller hierarchy: ownership and garbage collection, rolling updates, a stuck rollout and `rollout undo`, self-healing, label tampering, and ConfigMap env vs volume behaviour.

`order-api`, `payment-service` and `notification-service` come from `labs/shared/` (read-only). They are distroless, serve `/health` (liveness) and `/ready` (readiness), run as UID 65532, and keep state in memory (`order-api` does not use Postgres; `POSTGRES_*` in the Secret is illustrative only).

---

## Architecture Diagram

```
                              kubectl apply -f manifests/   (workloads)   |   demo/ = Step 10 only
                                          │
                                          ▼
                      [Namespace: orderflow]   (created by reset.sh, no PSA label yet)
                                          │
        ┌─────────────────────────────────┼─────────────────────────────────┐
        ▼                                 ▼                                 ▼
[ConfigMap: orderflow-config]    [Secret: orderflow-secrets]        [Service: order-api]
(PORT, service URLs)              (POSTGRES_* placeholders)          (ClusterIP :8080)
        │                                 │                                 │
        └─────────────────┬───────────────┘                                 │
                          ▼                                                 ▼
               [Deployment: order-api] ◄────────────────────────────────────┘
               RollingUpdate maxSurge=1 maxUnavailable=0, progressDeadlineSeconds=45
                          │ ownerReference (controller=true)
                          ▼
               [ReplicaSet: order-api-<pod-template-hash>]
                          │ ownerReference
            ┌─────────────┴─────────────┐
            ▼                           ▼
     [Pod order-api-…]           [Pod order-api-…]
     readiness /ready, liveness /health, startup /health
```

---

## Instructions

### Step 1: Reset the namespace and load the images
```bash
bash labs/shared/reset.sh
bash labs/shared/load-images.sh        # v1
bash labs/shared/load-images.sh v2     # v2, used in Step 6
```
*You should see: `orderflow` namespace `Active` with no labels except the default one; "loaded orderflow/<svc>:v1" and `:v2` for all three services.* The v2 image is built from the same source as v1, so **the application cannot tell you which version it is** (no version field in any response). We therefore observe v1 → v2 through the Deployment itself: the image tag, the `pod-template-hash` / ReplicaSet, and an `APP_VERSION` env var that the rollout changes along with the image.

### Step 2: Apply Manifests in Sequence
`reset.sh` already created the namespace, so applying `namespace.yaml` prints a one-time warning that the namespace is "missing the `kubectl.kubernetes.io/last-applied-configuration` annotation". That is harmless: kubectl patches the annotation in, and the file's labels (`environment: local-lab`) **are** applied.
```bash
kubectl apply -f labs/day03/manifests/namespace.yaml
kubectl apply -f labs/day03/manifests/configmap.yaml
kubectl apply -f labs/day03/manifests/secret.yaml
kubectl apply -f labs/day03/manifests/payment-service.yaml
kubectl apply -f labs/day03/manifests/notification-service.yaml
kubectl apply -f labs/day03/manifests/order-api.yaml

for d in payment-service notification-service order-api; do
  kubectl rollout status deploy/$d -n orderflow --timeout=60s
done
kubectl get all -n orderflow
```
*You should see: 3 "successfully rolled out" lines; 5 pods `1/1 Running` (order-api 2, payment-service 2, notification-service 1); Services on ports 8080, 8081, 8082.*

Open `manifests/order-api.yaml` and find: `readinessProbe` on `/ready` vs `livenessProbe` on `/health`, the `startupProbe`, `securityContext` (`runAsNonRoot` with the numeric `runAsUser: 65532`, read-only root filesystem, all capabilities dropped), and `progressDeadlineSeconds: 45`. (The namespace has no Pod Security label yet; a later day adds a `restricted` label and these manifests are already written to comply.)

### Step 3: Test API Access via Port-Forward
```bash
kubectl port-forward svc/order-api 8080:8080 -n orderflow &
PF_PID=$!
sleep 2

curl -i http://localhost:8080/health
curl -i http://localhost:8080/ready
curl -i -X POST http://localhost:8080/orders \
  -H "Content-Type: application/json" \
  -d '{"item":"K8s Book","qty":1}'

kill $PF_PID 2>/dev/null || true
kubectl logs -l app=payment-service -n orderflow --tail=2 --prefix
```
*You should see: `200` on `/health` and `/ready`, `201 Created` with an order JSON, and (in the logs of one of the two payment pods) `processing payment for order: <id>`, proof that `order-api` reached `payment-service` through its Service DNS name.* (If port 8080 is busy on your Mac, use `18080:8080` and adjust the URLs.)

### Step 4: Scale, then restore the declared state
```bash
kubectl scale deployment order-api --replicas=5 -n orderflow
kubectl get pods -n orderflow -l app=order-api
kubectl rollout status deploy/order-api -n orderflow --timeout=60s
```
`kubectl scale` is **imperative**: it changes live state only. Scale back the declarative way, by re-applying the file whose `replicas: 2` is the source of truth:
```bash
kubectl apply -f labs/day03/manifests/order-api.yaml
kubectl get deploy order-api -n orderflow
```
*You should see: 3 extra pods created in parallel, then after the apply `READY 2/2` and 2 pods left (the surplus ones terminate).*

### Step 5: Ownership, garbage collection and `--cascade=orphan`
Who owns what:
```bash
kubectl get pods -n orderflow -l app=order-api -o custom-columns='NAME:.metadata.name,OWNER-KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name'
kubectl get rs -n orderflow -l app=order-api -o custom-columns='NAME:.metadata.name,OWNER-KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name'
```
Now delete **only** the Deployment, leaving its dependents:
```bash
kubectl delete deploy order-api -n orderflow --cascade=orphan
kubectl get deploy,rs,pods -n orderflow -l app=order-api
kubectl get rs -n orderflow -l app=order-api -o custom-columns='NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].name'
```
Re-create it from the same file:
```bash
kubectl apply -f labs/day03/manifests/order-api.yaml
kubectl get rs,pods -n orderflow -l app=order-api
kubectl get rs -n orderflow -l app=order-api -o custom-columns='NAME:.metadata.name,OWNER:.metadata.ownerReferences[0].name'
```
*You should see: pods and the ReplicaSet keep running (same names and ages) with no owner after the orphaning delete; after the apply the **same** ReplicaSet (same `pod-template-hash`) is owned by the new Deployment and no new pods are created. The Deployment found the ReplicaSet by selector and template hash.* Compare with plain `kubectl delete deploy order-api` (default background cascade), which would have deleted the ReplicaSet and pods via the garbage collector. (Do not try this with a different image in the file: a template with a new hash gets a new ReplicaSet and a rollout.)

### Step 6: Rolling update v1 → v2
Record the starting point, then change image **and** `APP_VERSION` in one patch (one template change = one rollout):
```bash
COLS='NAME:.metadata.name,HASH:.metadata.labels.pod-template-hash,IMAGE:.spec.containers[0].image,APP_VERSION:.spec.containers[0].env[?(@.name=="APP_VERSION")].value'
kubectl annotate deploy/order-api -n orderflow kubernetes.io/change-cause="v1 baseline" --overwrite
kubectl get pods -n orderflow -l app=order-api -o custom-columns="$COLS"

kubectl patch deploy order-api -n orderflow -p '{"spec":{"template":{"spec":{"containers":[{"name":"order-api","image":"orderflow/order-api:v2","env":[{"name":"APP_VERSION","value":"v2"}]}]}}}}'
kubectl annotate deploy/order-api -n orderflow kubernetes.io/change-cause="v2: image + APP_VERSION" --overwrite
kubectl rollout status deploy/order-api -n orderflow --timeout=60s

kubectl get rs -n orderflow -l app=order-api -o wide
kubectl get pods -n orderflow -l app=order-api -o custom-columns="$COLS"
kubectl rollout history deploy/order-api -n orderflow
```
*You should see: a new ReplicaSet (new hash) scaled to 2, the old one scaled to 0 but kept for rollback; pods on `orderflow/order-api:v2` with `APP_VERSION=v2`; history revisions 1 and 2 with your change-cause notes.* Because `maxSurge: 1, maxUnavailable: 0`, a v2 pod had to become Ready before each v1 pod was removed.

### Step 7: Stuck rollout (bad tag) and recovery
```bash
kubectl set image deploy/order-api order-api=orderflow/order-api:v99 -n orderflow
kubectl annotate deploy/order-api -n orderflow kubernetes.io/change-cause="v99 (bad tag)" --overwrite
kubectl rollout status deploy/order-api -n orderflow --timeout=60s; echo "exit=$?"

kubectl get pods -n orderflow -l app=order-api
kubectl get deploy order-api -n orderflow -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}{"\n"}{end}'
```
*You should see: after about 45 s `error: deployment "order-api" exceeded its progress deadline` and `exit=1`; one new pod in `ErrImagePull`/`ImagePullBackOff`, the two v2 pods still `1/1 Running`; conditions `Available=True` and `Progressing=False ProgressDeadlineExceeded`.* Kubernetes reports the failure and leaves the Deployment as is; it does **not** roll back. Without `progressDeadlineSeconds: 45` (default 600) and `--timeout`, this step would sit for ten minutes.

Roll back:
```bash
kubectl rollout history deploy/order-api -n orderflow
kubectl rollout undo deploy/order-api -n orderflow
kubectl rollout status deploy/order-api -n orderflow --timeout=60s
kubectl rollout history deploy/order-api -n orderflow
kubectl get rs -n orderflow -l app=order-api -o wide
```
*You should see: history 1, 2, 3 before and **1, 3, 4** after (undo re-activated the v2 ReplicaSet as the new revision 4); the bad ReplicaSet at 0 replicas; two `v2` pods.* Note the live Deployment is now v2 while `manifests/order-api.yaml` still says v1: a `kubectl apply` of the file would roll back to v1. In real life, the file in git is what you fix.

### Step 8: BREAK IT — Pod deletion & self-healing
```bash
POD_NAME=$(kubectl get pods -n orderflow -l app=order-api -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod $POD_NAME -n orderflow --wait=false
kubectl get pods -n orderflow -l app=order-api
sleep 6; kubectl get pods -n orderflow -l app=order-api
```
*You should see: the deleted pod `Terminating` while a brand-new pod is already `ContainerCreating`, then back to 2 Running.* The ReplicaSet controller saw 1 pod where it wanted 2 and created one; it didn't wait for the old one to finish terminating.

### Step 9: BREAK IT — Label tampering, orphaned pod, re-adoption
```bash
TARGET_POD=$(kubectl get pods -n orderflow -l app=order-api -o jsonpath='{.items[0].metadata.name}')
kubectl label pod $TARGET_POD -n orderflow app=orphaned-api --overwrite
sleep 4
kubectl get pods -n orderflow -L app
kubectl get pod $TARGET_POD -n orderflow -o jsonpath='ownerReferences={.metadata.ownerReferences}{"\n"}'
kubectl get endpointslices -n orderflow -l kubernetes.io/service-name=order-api
```
*You should see: 3 `order-api` pods in total (2 with `app=order-api`, a fresh replacement among them, plus yours with `app=orphaned-api`), an empty `ownerReferences`, and only the two matching pod IPs in the Service's EndpointSlice.* The ReplicaSet **released** the pod. It is no longer rolled, no longer served by the Service; it just runs. Now put the label back:
```bash
kubectl label pod $TARGET_POD -n orderflow app=order-api --overwrite
sleep 8
kubectl get pods -n orderflow -l app=order-api -o custom-columns='NAME:.metadata.name,OWNER-KIND:.metadata.ownerReferences[0].kind,OWNER:.metadata.ownerReferences[0].name'
```
*You should see: the pod is **re-adopted** (owner `ReplicaSet` again) and the ReplicaSet deletes one surplus pod, so you end with 2 pods.* (If you prefer to dispose of an orphan instead: `kubectl delete pod $TARGET_POD -n orderflow`.)

### Step 10: ConfigMap as env var vs volume vs `subPath`
```bash
kubectl apply -f labs/day03/demo/cfg-demo.yaml
kubectl wait --for=condition=Ready pod/cfg-demo -n orderflow --timeout=60s

show() {
  echo "env:     $(kubectl exec cfg-demo -n orderflow -- printenv GREETING)"
  echo "volume:  $(kubectl exec cfg-demo -n orderflow -- cat /etc/demo/greeting)"
  echo "subPath: $(kubectl exec cfg-demo -n orderflow -- cat /etc/demo-subpath/greeting)"
}
show

kubectl patch cm demo-config -n orderflow --type merge -p '{"data":{"greeting":"hello-v2"}}'
START=$(date +%s)
for i in $(seq 1 36); do   # poll every 5 s, give up after 180 s
  [ "$(kubectl exec cfg-demo -n orderflow -- cat /etc/demo/greeting)" = hello-v2 ] && break
  sleep 5
done
echo "volume now: $(kubectl exec cfg-demo -n orderflow -- cat /etc/demo/greeting) after $(( $(date +%s) - START ))s (gave up if still hello-v1)"
show
kubectl exec cfg-demo -n orderflow -- ls -l /etc/demo
```
*You should see: all three `hello-v1` at first; the volume file flips to `hello-v2` after a delay of roughly 60-90 s (up to one kubelet sync period, `syncFrequency` default 1 min plus jitter, plus watch propagation; the kubelet's default change-detection strategy is `Watch`) while `env` and `subPath` stay `hello-v1`; the `ls -l` shows `greeting -> ..data/greeting`, the symlink the kubelet swaps atomically.* The pod uses busybox because the app images are distroless (no shell); this pod is a naked pod on purpose, deleted in Teardown.

Immutable ConfigMap:
```bash
kubectl patch cm demo-config-frozen -n orderflow --type merge -p '{"data":{"greeting":"x"}}'
```
*You should see: `field is immutable when 'immutable' is set`.* Only delete and re-create (or a new name plus a rollout) changes it.

---

## Stuck? Hints

- **Pods `ErrImagePull` / `ImagePullBackOff` on `orderflow/*:v1`** → on the kind provisioner `docker build` alone does not put images where the cluster can see them → run `bash labs/shared/load-images.sh` (and `... v2`). Check with `docker exec desktop-control-plane crictl images | /usr/bin/grep orderflow`. (Kubeadm provisioner: nothing to load. Plain `kind`: the script uses `kind load`.) Only the `v99` pod should fail, on purpose. The `busybox:1.37` image of Step 10 (and any image not loaded by the script) is pulled from Docker Hub by the node, so it needs internet access and can hit anonymous pull rate limits; retry later if that pod sits in `ImagePullBackOff`.
- **`rollout status` seems to hang for ten minutes** → no `--timeout`, and `progressDeadlineSeconds` is 600 by default → always pass `--timeout=60s`; in this lab the Deployment sets 45 s.
- **Pods `Running` but `0/1` Ready, or `CreateContainerConfigError`** → readiness `/ready` failing or `runAsNonRoot` without a numeric user → `kubectl describe pod`, read the Events; the manifests set `runAsUser: 65532` already, keep that if you edit them.
- **Port-forward fails with "address already in use" / curl hits something else** → another process (for example a Compose lab) owns 8080 → use `18080:8080` and curl `localhost:18080`.
- **After a long session pods cannot reach each other (`call to /payments failed`) and kindnet logs `netlink receive: no such file or directory`** → the kindnet policy agent wedged (Docker Desktop kind provisioner) → `kubectl rollout restart ds/kindnet -n kube-system`.
- **ConfigMap volume does not change** → be patient (60-90 s is normal; up to ~2 min), you may be reading the `subPath` file, or the ConfigMap is `immutable`. `kubectl exec` into the pod shows the truth: `cat /etc/demo/greeting`.

---

## Teardown
```bash
kubectl delete -f labs/day03/demo/cfg-demo.yaml --ignore-not-found
bash labs/shared/reset.sh
kubectl delete namespace orderflow --ignore-not-found
```

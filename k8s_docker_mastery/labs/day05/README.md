# Day 5 Lab: Persistent Storage, Pod Security Hardening & RBAC

**Run every command from the course root** (`k8s_docker_mastery/`). Target cluster: Docker Desktop Kubernetes on the **kind provisioner** (context `docker-desktop`, node `desktop-control-plane`, StorageClasses `hostpath` and `standard (default)`, both `rancher.io/local-path`). Alternatives: Docker Desktop's *kubeadm* provisioner (node `docker-desktop`) sees local images directly, but its default StorageClass and data path differ (Step 8's `docker exec` peek does not apply); with plain `kind`, `load-images.sh` runs `kind load docker-image` and the default class is `standard` (local-path). The Pod Security and RBAC steps behave identically everywhere.

## Start here — plain steps

1. Open a terminal in `k8s_docker_mastery/`. `kubectl config current-context` must print `docker-desktop`. Envoy Gateway from Day 4 may stay installed; Day 5 does not use it.
2. Run `bash labs/shared/reset.sh` and `bash labs/shared/load-images.sh`, then `kubectl get storageclass` and apply the Day 3 ConfigMap and Secret (the only Day 3 files you need).
3. Apply a deliberately root workload (`legacy-root`), **preview** the `restricted` label with `--dry-run=server` (you should see warnings naming it), then enforce it and watch the root pod fail to come back.
4. Apply `postgres-statefulset.yaml`: you should see `postgres-0` `1/1 Running` under `restricted`, with a PVC `data-postgres-0` `Bound`. Insert a row.
5. Delete the pod, then delete the whole **StatefulSet**: the PVC stays, and after re-applying the StatefulSet the row is still there.
6. Apply `rbac.yaml` and `security-context.yaml`: two `order-api-hardened` pods `2/2 Running`. In the busybox `fs-probe` container, writing to `/` fails with `Read-only file system` and writing to `/tmp` works.
7. Run `kubectl auth can-i` (including `--list`) for the three ServiceAccounts and compare the answers with what you predicted.
8. Compare **Delete vs Retain** reclaim: after deleting both PVCs, one PV is gone and one is `Released` with its data still readable. You are done when each step's "You should see" line matched; run **Teardown** (it removes the PSA label too).

## Objective
Run Postgres as a StatefulSet that passes the `restricted` Pod Security Standard, prove how PVCs and PVs behave when pods, StatefulSets and claims are deleted (and what `Retain` changes), harden `order-api` with a read-only root filesystem and no API token, and verify least-privilege RBAC for three ServiceAccounts. `order-api` does **not** use Postgres (it keeps orders in memory); Postgres is here to teach storage. Images: `orderflow/order-api:v1` from `labs/shared/`, `postgres:16-alpine` and `busybox:1.37` pulled from Docker Hub (internet needed).

---

## Architecture Diagram

```
        namespace orderflow  ── label pod-security.kubernetes.io/enforce=restricted (Step 3)
                  │
   ┌──────────────┼──────────────────────────────────────────────┐
   ▼              ▼                                              ▼
[StatefulSet postgres]                  [Deployment order-api-hardened x2]        [RBAC]
 UID/GID 70 (postgres:16-alpine)         pod: order-api + fs-probe (busybox)       order-api-sa ─ Role (configmaps, 1 secret)
 rootfs read-only + emptyDirs            UID 65532, rootfs read-only, /tmp emptyDir payment-sa   ─ nothing
 password = mounted file                 no API token (automount false)            auditor-sa   ─ RoleBinding ► ClusterRole view
   │ volumeClaimTemplates                config from ConfigMap only
   ▼
[PVC data-postgres-0] ─ StorageClass standard (local-path, Delete, WaitForFirstConsumer)
   ▼
[PV pvc-...  nodeAffinity: desktop-control-plane]   survives: pod delete, StatefulSet delete
```

---

## Instructions

### Step 1: Reset, load images, look at storage
```bash
bash labs/shared/reset.sh
bash labs/shared/load-images.sh
kubectl get storageclass
kubectl apply -f labs/day03/manifests/configmap.yaml -f labs/day03/manifests/secret.yaml
```
*You should see: `orderflow` with no PSA labels; two StorageClasses, `standard (default)` with `RECLAIMPOLICY Delete` and `VOLUMEBINDINGMODE WaitForFirstConsumer`; `configmap/orderflow-config created` and `secret/orderflow-secrets created`.* (A namespace with no `pod-security.kubernetes.io/*` label enforces **nothing**: it is `privileged`.)

### Step 2: Preview, then enforce, Pod Security `restricted`
First create a workload that breaks the rules (it runs fine now, as root, with no seccomp profile):
```bash
kubectl apply -f labs/day05/manifests/legacy-root.yaml
kubectl rollout status deployment/legacy-root -n orderflow
```
Preview the label **without applying it**:
```bash
kubectl label --dry-run=server --overwrite ns orderflow pod-security.kubernetes.io/enforce=restricted
```
*You should see: `Warning: existing pods in namespace "orderflow" violate the new PodSecurity enforce level "restricted:latest"`, a line naming `legacy-root-...: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile`, and `namespace/orderflow labeled (server dry run)`.*

Now enforce (with `warn` and `audit` too, so tools and audit logs see violations the same way):
```bash
kubectl label ns orderflow --overwrite \
  pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/audit=restricted
kubectl get pods -n orderflow            # the running legacy pod is NOT evicted
kubectl delete pod -l app=legacy-root -n orderflow
kubectl get rs -n orderflow              # DESIRED 1, CURRENT 0
kubectl get events -n orderflow --field-selector reason=FailedCreate
```
*You should see: the old pod keeps running until you delete it; afterwards the ReplicaSet cannot create a replacement: `FailedCreate ... is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (...), unrestricted capabilities (...), runAsNonRoot != true (...), seccompProfile (...)`.* Enforcement happens at pod creation, and for controller-managed pods the error is in the **events**, not at `kubectl apply`.
```bash
kubectl delete -f labs/day05/manifests/legacy-root.yaml
```

### Step 3: Postgres StatefulSet under `restricted`
```bash
kubectl apply -f labs/day05/manifests/postgres-statefulset.yaml
kubectl rollout status statefulset/postgres -n orderflow --timeout=180s
kubectl get pods,pvc -n orderflow
kubectl get pv
kubectl get pv -o jsonpath='{.items[?(@.spec.claimRef.name=="data-postgres-0")].spec.nodeAffinity}{"\n"}'
```
*You should see: `postgres-0` `1/1 Running`; PVC `data-postgres-0` `Bound`, `STORAGECLASS standard`, `RWO`, `1Gi` (it stayed `Pending` until the pod was scheduled: `WaitForFirstConsumer`); a PV with reclaim policy `Delete`; and a node affinity pinning the volume to `desktop-control-plane`.* The manifest already carries the three fields `restricted` demands (pod `seccompProfile: RuntimeDefault`; container `allowPrivilegeEscalation: false` and `capabilities.drop: [ALL]`), `runAsUser: 70` (the image has no `USER`, so `runAsNonRoot` needs a numeric UID; 70 is the alpine image's own `postgres` user, Debian `postgres:16` uses 999, and other UIDs only work through the entrypoint's `nss_wrapper`), a read-only root filesystem with `emptyDir`s for `/var/run/postgresql` and `/tmp`, and the password read from a mounted file.
```bash
kubectl exec postgres-0 -n orderflow -- psql -U orderflow -d orderflow \
  -c "CREATE TABLE orders_ledger (id serial primary key, hash text); INSERT INTO orders_ledger (hash) VALUES ('block_001_persisted');"
kubectl exec postgres-0 -n orderflow -- sh -c 'id; env | grep PASSWORD'
```
*You should see: `CREATE TABLE`, `INSERT 0 1`; `uid=70(postgres)`; and the only env match is `POSTGRES_PASSWORD_FILE=/run/secrets/pg/password`: the password itself is not in the environment.*

### Step 4: Pod delete, StatefulSet delete, PVC survival
```bash
kubectl delete pod postgres-0 -n orderflow
kubectl wait --for=condition=Ready pod/postgres-0 -n orderflow --timeout=120s
kubectl exec postgres-0 -n orderflow -- psql -U orderflow -d orderflow -c "SELECT * FROM orders_ledger;"
```
*You should see the row `block_001_persisted`: the replacement `postgres-0` re-attached `data-postgres-0`.* Now the bigger test:
```bash
kubectl delete statefulset postgres -n orderflow
kubectl get pods,pvc,pv -n orderflow            # pod terminating/gone; PVC and PV still Bound
kubectl apply -f labs/day05/manifests/postgres-statefulset.yaml
kubectl rollout status statefulset/postgres -n orderflow --timeout=120s
kubectl exec postgres-0 -n orderflow -- psql -U orderflow -d orderflow -c "SELECT * FROM orders_ledger;"
kubectl get statefulset postgres -n orderflow -o jsonpath='{.spec.persistentVolumeClaimRetentionPolicy}{"\n"}'
```
*You should see: after the delete only the PVC and PV remain (`Bound`); after re-applying, the same row; and `{"whenDeleted":"Retain","whenScaled":"Retain"}`.* PVCs outlive their StatefulSet by default. Change `whenDeleted` to `Delete` in the manifest and the same experiment would destroy the data (try it on a throwaway copy).

### Step 5: Hardened `order-api`, ServiceAccounts and RBAC
```bash
kubectl apply -f labs/day05/manifests/rbac.yaml -f labs/day05/manifests/security-context.yaml
kubectl rollout status deployment/order-api-hardened -n orderflow --timeout=120s
kubectl get pods -n orderflow -l security-tier=hardened
```
*You should see: three ServiceAccounts, one Role and two RoleBindings created; two pods `2/2 Running` (containers `order-api` and the debug container `fs-probe`).* The pod uses `order-api-sa`, mounts **no** API token (`automountServiceAccountToken: false`) and gets only the ConfigMap, not the Secret (labelled `app=order-api-hardened`, so the Day 3 `order-api` Service, if you applied it, never selects these pods).

### Step 6: BREAK IT — read-only root filesystem
```bash
POD=$(kubectl get pods -n orderflow -l security-tier=hardened -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -n orderflow -c order-api -- sh -c 'echo hi'                 # distroless: no shell
kubectl exec $POD -n orderflow -c fs-probe -- sh -c "echo hack > /exploit.txt"
kubectl exec $POD -n orderflow -c fs-probe -- sh -c "echo valid > /tmp/cache.txt && cat /tmp/cache.txt"
kubectl exec $POD -n orderflow -c fs-probe -- sh -c "id; grep -E 'CapEff|NoNewPrivs|Seccomp:' /proc/self/status; ls /var/run/secrets"
```
*You should see: the first command fail with `exec: "sh": executable file not found in $PATH` (that is why `fs-probe` exists: a busybox container with the same securityContext); `sh: can't create /exploit.txt: Read-only file system` (exit 1); `valid`; and `uid=65532`, `CapEff: 0000000000000000`, `NoNewPrivs: 1`, `Seccomp: 2`, and no `/var/run/secrets` directory (no token).* In a real Deployment, remove `fs-probe` and use `kubectl debug` ephemeral containers.

### Step 7: Audit RBAC with `kubectl auth can-i`
```bash
for sa in order-api-sa payment-sa auditor-sa; do
  echo "## $sa"; S=system:serviceaccount:orderflow:$sa
  for q in get:configmaps list:pods delete:pods get:secrets get:secrets/orderflow-secrets list:secrets; do
    echo -n "$q: "; kubectl auth can-i ${q%%:*} ${q#*:} -n orderflow --as=$S
  done
done
kubectl auth can-i --list -n orderflow --as=system:serviceaccount:orderflow:order-api-sa
kubectl auth can-i --list -n orderflow --as=system:serviceaccount:orderflow:auditor-sa
kubectl auth can-i list pods -n default --as=system:serviceaccount:orderflow:auditor-sa
```
*You should see: `order-api-sa`: `get configmaps` yes, `get secrets` **no** but `get secrets/orderflow-secrets` yes, `list secrets` no; `payment-sa`: all `no`; `auditor-sa`: `list pods` yes, `delete pods` no, `get secrets` no. `--list` for `order-api-sa` shows `configmaps [get list watch]` and `secrets [orderflow-secrets] [get]` plus the default `selfsubject*` rows; for `auditor-sa` it shows the `view` set (pods, deployments, configmaps...) with no `secrets`. `auditor-sa` in namespace `default`: `no`: a RoleBinding to a ClusterRole is scoped to its namespace.*

### Step 8: Retain vs Delete reclaim policy
```bash
kubectl apply -f labs/day05/manifests/reclaim-demo.yaml     # StorageClass day05-retain, PVCs keep-me / lose-me, pod reclaim-writer
kubectl wait --for=condition=Ready pod/reclaim-writer -n orderflow --timeout=120s
kubectl logs reclaim-writer -n orderflow
kubectl get pv                                              # one Retain, two Delete (postgres + lose-me)
kubectl delete pod reclaim-writer -n orderflow --now
kubectl delete pvc keep-me lose-me -n orderflow
sleep 8; kubectl get pv
```
*You should see: `important-data` and `disposable-data` in the logs; then, after deleting the claims, the `lose-me` PV is **gone** and the `day05-retain` PV is `Released` (claim `orderflow/keep-me`, policy `Retain`), next to the still-`Bound` Postgres volume.* Prove the data is still on disk, then recover it:
```bash
docker exec desktop-control-plane ls /var/local-path-provisioner/     # Docker Desktop (kind) only; shows the keep-me directory
KEEP=$(kubectl get pv -o jsonpath='{range .items[?(@.spec.storageClassName=="day05-retain")]}{.metadata.name}{end}')
kubectl patch pv $KEEP -p '{"spec":{"claimRef":null}}'      # Released -> Available
kubectl apply -f - <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {name: recovered, namespace: orderflow}
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: day05-retain
  volumeName: $KEEP
  resources: {requests: {storage: 64Mi}}
---
apiVersion: v1
kind: Pod
metadata: {name: reclaim-reader, namespace: orderflow}
spec:
  automountServiceAccountToken: false
  restartPolicy: Never
  securityContext: {runAsNonRoot: true, runAsUser: 65532, runAsGroup: 65532, seccompProfile: {type: RuntimeDefault}}
  containers:
    - name: reader
      image: busybox:1.37
      command: ["cat", "/keep/file.txt"]
      securityContext: {allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: {drop: ["ALL"]}}
      volumeMounts: [{name: keep, mountPath: /keep, readOnly: true}]
  volumes:
    - name: keep
      persistentVolumeClaim: {claimName: recovered}
YAML
sleep 12; kubectl logs reclaim-reader -n orderflow
```
*You should see `important-data`: the retained volume re-bound to a new claim with its data intact.* Clean up the demo volume properly: switch it to `Delete` so the provisioner removes the directory too.
```bash
kubectl delete pod reclaim-reader -n orderflow --now
kubectl patch pv $KEEP -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}'
kubectl delete pvc recovered -n orderflow
sleep 10; kubectl get pv                                    # only the Postgres volume is left
```

---

## Stuck? Hints
- **`postgres-0` never appears and `kubectl get sts` shows `0/1`** → the namespace is `restricted` and the pod spec is missing `seccompProfile`, `allowPrivilegeEscalation: false` or `capabilities.drop: [ALL]` → `kubectl get events -n orderflow --field-selector reason=FailedCreate` lists every missing field.
- **`CreateContainerConfigError: container has runAsNonRoot and image will run as root`** (or `... non-numeric user (...)`) → the image has no `USER`, or a named one, and kubelet cannot verify it → set a numeric `runAsUser` (70 for `postgres:16-alpine`, 999 for `postgres:16`).
- **Postgres `CrashLoopBackOff`: `Permission denied` / `could not change permissions of directory`** → initdb cannot chmod the root-owned mount point → `PGDATA` must be a subdirectory of the mount (as in the manifest); on block/CSI volumes also keep `fsGroup` set.
- **PVC `Pending` and no pod yet** → normal with `WaitForFirstConsumer`; it binds when a pod using it is scheduled. If the pod exists and the PVC stays `Pending`, `kubectl describe pvc` events.
- **`ImagePullBackOff` on `order-api`** → the node cannot see the Docker image → `bash labs/shared/load-images.sh`. For `postgres` / `busybox`: the node needs internet to pull them.
- **A `Released` PV will not bind to a new PVC** → it still points at the old claim → clear `spec.claimRef` (Step 8) or delete and re-create the PV object.

---

## Teardown
Removes everything Day 5 created, **including the `restricted` Pod Security label** (`reset.sh` recreates `orderflow` unlabeled, and the final delete removes the namespace so Day 6 starts clean). Deleting the namespace deletes the Postgres PVC and, with it, the PV.
```bash
bash labs/shared/reset.sh
kubectl delete namespace orderflow
kubectl delete pv $(kubectl get pv -o jsonpath='{range .items[?(@.spec.storageClassName=="day05-retain")]}{.metadata.name}{" "}{end}') 2>/dev/null || true   # leftover Retain PV, if Step 8 was interrupted
kubectl delete storageclass day05-retain --ignore-not-found
kubectl get pv                          # nothing from this lab should remain
```

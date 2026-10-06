# Day 5 Lab: Solution & Explanations

Output below was captured on Docker Desktop Kubernetes (kind provisioner, k8s 1.34). PV/PVC names and ages differ on your machine.

## Step 1: storage classes

```text
$ kubectl get storageclass
NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
hostpath             rancher.io/local-path   Delete          WaitForFirstConsumer   false                  186d
standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false                  186d
```
Two classes, one provisioner; `standard` is the default, so a PVC without `storageClassName` gets it (the Postgres PVC shows `STORAGECLASS standard`). Reclaim `Delete` is the default for dynamic provisioning, and `WaitForFirstConsumer` is why PVCs read `Pending` until a pod exists.

## Step 2: Pod Security Admission

```text
$ kubectl label --dry-run=server --overwrite ns orderflow pod-security.kubernetes.io/enforce=restricted
Warning: existing pods in namespace "orderflow" violate the new PodSecurity enforce level "restricted:latest"
Warning: legacy-root-7b56c75788-jvh57: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
namespace/orderflow labeled (server dry run)
```
The dry run evaluates the label against **existing pods** and changes nothing. After the real label, the running pod stays; deleting it shows the enforcement:
```text
$ kubectl get rs -n orderflow
NAME                     DESIRED   CURRENT   READY   AGE
legacy-root-7b56c75788   1         0         0       48s
$ kubectl get events -n orderflow --field-selector reason=FailedCreate
... Warning   FailedCreate   replicaset/legacy-root-7b56c75788   Error creating: pods "legacy-root-7b56c75788-mszkm" is forbidden: violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false (container "legacy" must set securityContext.allowPrivilegeEscalation=false), unrestricted capabilities (container "legacy" must set securityContext.capabilities.drop=["ALL"]), runAsNonRoot != true (pod or container "legacy" must set securityContext.runAsNonRoot=true), seccompProfile (pod or container "legacy" must set securityContext.seccompProfile.type to "RuntimeDefault" or "Localhost")
```
Remember: no label means `privileged`; `readOnlyRootFilesystem` is not checked at any level; admission runs at pod creation, and for Deployments/StatefulSets you find the rejection in events, not at `apply`.

## Step 3: Postgres under `restricted`

```text
$ kubectl get pods,pvc -n orderflow
NAME             READY   STATUS    RESTARTS   AGE
pod/postgres-0   1/1     Running   0          11s
NAME                                    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/data-postgres-0   Bound    pvc-c832a56d-a743-4221-a05f-03265b437bfe   1Gi        RWO            standard       11s
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                       STORAGECLASS   ...
pvc-c832a56d-a743-4221-a05f-03265b437bfe   1Gi        RWO            Delete           Bound    orderflow/data-postgres-0   standard       ...
$ kubectl get pv -o jsonpath='{.items[?(@.spec.claimRef.name=="data-postgres-0")].spec.nodeAffinity}'
{"required":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"kubernetes.io/hostname","operator":"In","values":["desktop-control-plane"]}]}]}}
$ kubectl exec postgres-0 -n orderflow -- psql -U orderflow -d orderflow -c "CREATE TABLE ...; INSERT ..."
CREATE TABLE
INSERT 0 1
$ kubectl exec postgres-0 -n orderflow -- sh -c 'id; env | grep PASSWORD'
uid=70(postgres) gid=70(postgres) groups=70(postgres)
POSTGRES_PASSWORD_FILE=/run/secrets/pg/password
```
Why each field is there:
- **Pod `seccompProfile`, container `allowPrivilegeEscalation: false` and `capabilities.drop: [ALL]`**: the three things the original manifest was missing; `restricted` rejects the pod without them. `runAsNonRoot: true` plus numeric `runAsUser` is the fourth.
- **UID 70**: `postgres:16-alpine` has no `USER` (it starts as root), so `runAsNonRoot` needs a numeric `runAsUser`; 70 is the image's own `postgres` UID/GID (Debian `postgres:16` is 999). Other UIDs such as 999 also work via the entrypoint's `nss_wrapper` fake passwd entry, as long as the directories it writes are writable. `fsGroup: 70` is for block/CSI volumes; on local-path (hostPath-type, provisioned `0777`) it has no effect and the volume is writable because of the mode.
- **Read-only rootfs** needs two `emptyDir`s (`/var/run/postgresql` for the socket and lock, `/tmp`) on top of the data volume.
- **Password via `POSTGRES_PASSWORD_FILE`** pointing at a mounted Secret key: nothing sensitive in the environment.
- **`PGDATA` in a subdirectory**: initdb must chmod its data directory to `0700`, which it cannot do on a root-owned mount root; the entrypoint creates the subdirectory as the postgres user (block volumes add a `lost+found` problem on top). (Postgres 18 images moved to a versioned directory under `/var/lib/postgresql`; check the mount path before upgrading.)
- **PV `nodeAffinity`**: the data lives on that node; "the volume follows the pod" holds only within the volume's node/zone.

## Step 4: PVC survival

```text
$ kubectl delete pod postgres-0 -n orderflow   ... SELECT * FROM orders_ledger;
 id |        hash
----+---------------------
  1 | block_001_persisted
$ kubectl delete statefulset postgres -n orderflow
statefulset.apps "postgres" deleted
$ kubectl get pods,pvc,pv -n orderflow
pod/postgres-0   1/1   Terminating   0   7s      (the pod is going away; the PVC and PV are not)
persistentvolumeclaim/data-postgres-0   Bound   pvc-c832a56d-...   1Gi   RWO   standard   25s
persistentvolume/pvc-c832a56d-...       1Gi   RWO   Delete   Bound   orderflow/data-postgres-0   standard   22s
$ kubectl apply -f labs/day05/manifests/postgres-statefulset.yaml   ... SELECT * FROM orders_ledger;
  1 | block_001_persisted
$ kubectl get statefulset postgres -n orderflow -o jsonpath='{.spec.persistentVolumeClaimRetentionPolicy}'
{"whenDeleted":"Retain","whenScaled":"Retain"}
```
The pod is replaceable; the PVC (and the PV behind it) is what holds the data. The new StatefulSet adopts `data-postgres-0` by name. With `whenDeleted: Delete` the PVC would go with the StatefulSet and, on a `Delete` class, the data too.

## Step 5/6: hardened `order-api`, read-only rootfs

```text
$ kubectl get pods -n orderflow -l security-tier=hardened
order-api-hardened-74cfbd7476-j6qvx   2/2   Running   0   3s
order-api-hardened-74cfbd7476-mkjml   2/2   Running   0   3s
$ kubectl exec $POD -n orderflow -c order-api -- sh -c 'echo hi'
error: ... exec: "sh": executable file not found in $PATH
$ kubectl exec $POD -n orderflow -c fs-probe -- sh -c "echo hack > /exploit.txt"
sh: can't create /exploit.txt: Read-only file system
command terminated with exit code 1
$ kubectl exec $POD -n orderflow -c fs-probe -- sh -c "echo valid > /tmp/cache.txt && cat /tmp/cache.txt"
valid
$ kubectl exec $POD -n orderflow -c fs-probe -- sh -c "id; grep -E 'CapEff|NoNewPrivs|Seccomp:' /proc/self/status; ls /var/run/secrets"
uid=65532 gid=65532 groups=65532
CapEff:	0000000000000000
NoNewPrivs:	1
Seccomp:	2
ls: /var/run/secrets: No such file or directory
```
`readOnlyRootFilesystem: true` mounts the container root `MS_RDONLY`; any `open(O_WRONLY|O_CREAT)` on it returns `EROFS`, while the `emptyDir` at `/tmp` is a separate writable mount. `CapEff` all zero = `drop: [ALL]`; `NoNewPrivs: 1` = `allowPrivilegeEscalation: false`; `Seccomp: 2` = filter mode (`RuntimeDefault`); no `/var/run/secrets` = no ServiceAccount token (`automountServiceAccountToken: false`). Because `order-api` is distroless, the `fs-probe` container with the same securityContext stands in for it.

## Step 7: RBAC

```text
## order-api-sa
get:configmaps: yes
list:pods: no
delete:pods: no
get:secrets: no
get:secrets/orderflow-secrets: yes
list:secrets: no
## payment-sa
get:configmaps: no
...                      (all six: no)
## auditor-sa
get:configmaps: yes
list:pods: yes
delete:pods: no
get:secrets: no
get:secrets/orderflow-secrets: no
list:secrets: no

$ kubectl auth can-i --list -n orderflow --as=system:serviceaccount:orderflow:order-api-sa
Resources                                       Non-Resource URLs   Resource Names        Verbs
selfsubjectreviews.authentication.k8s.io        []                  []                    [create]
selfsubjectaccessreviews.authorization.k8s.io   []                  []                    [create]
selfsubjectrulesreviews.authorization.k8s.io    []                  []                    [create]
configmaps                                      []                  []                    [get list watch]
secrets                                         []                  [orderflow-secrets]   [get]
...                                             (plus /version, /healthz, /api* discovery URLs for every authenticated identity)

$ kubectl auth can-i --list -n orderflow --as=system:serviceaccount:orderflow:auditor-sa   (excerpt: no secrets row)
configmaps  [get list watch]    pods  [get list watch]    deployments.apps  [get list watch]  ...
$ kubectl auth can-i list pods -n default --as=system:serviceaccount:orderflow:auditor-sa
no
```
- `get secrets` is `no` while `get secrets/orderflow-secrets` is `yes`: `resourceNames` narrows `get` to one object. It cannot narrow `list`/`watch`, so never grant those on secrets.
- `payment-sa` shows only what any authenticated identity gets: a ServiceAccount starts with nothing.
- `auditor-sa` gets the ClusterRole `view` through a **RoleBinding**: the rules apply only in `orderflow` (`default` is `no`), and `view` deliberately omits Secrets and Roles.
- The Role on `order-api-sa` is moot at runtime for the hardened pods: they mount no token. RBAC belongs to the identity; the token is the only way a process in the pod can use it.

## Step 8: Retain vs Delete

```text
$ kubectl logs reclaim-writer -n orderflow
important-data
disposable-data
$ kubectl get pv      (while bound)
pvc-98536ebc-...   64Mi   RWO   Retain   Bound   orderflow/keep-me           day05-retain
pvc-c832a56d-...   1Gi    RWO   Delete   Bound   orderflow/data-postgres-0   standard
pvc-e27138a4-...   64Mi   RWO   Delete   Bound   orderflow/lose-me           standard
$ kubectl delete pvc keep-me lose-me -n orderflow ; kubectl get pv
pvc-98536ebc-...   64Mi   RWO   Retain   Released   orderflow/keep-me           day05-retain
pvc-c832a56d-...   1Gi    RWO   Delete   Bound      orderflow/data-postgres-0   standard
$ docker exec desktop-control-plane ls /var/local-path-provisioner/
pvc-98536ebc-..._orderflow_keep-me
pvc-c832a56d-..._orderflow_data-postgres-0
$ kubectl patch pv $KEEP -p '{"spec":{"claimRef":null}}'    -> STATUS Available
$ kubectl logs reclaim-reader -n orderflow
important-data
```
`lose-me` (default class, `Delete`): PV and directory removed with the claim. `keep-me` (`Retain`): PV `Released`, directory intact, but **not** reusable until `claimRef` is cleared; a new PVC with `volumeName: <pv>` and the same class re-binds it with the data. Retain is protection against accidental PVC deletion, not a backup. Switching the PV to `Delete` before removing the last claim lets the provisioner clean the directory (the `ls` is empty of `keep-me` afterwards).

## Teardown proof

The Teardown commands (`reset.sh`, `kubectl delete namespace orderflow`, the leftover-PV delete and `kubectl delete storageclass day05-retain --ignore-not-found`) leave `kubectl get pv` empty (`No resources found`), no `orderflow` namespace, and an empty `/var/local-path-provisioner/` on the node. The restricted label disappears with the namespace; `reset.sh` recreates it unlabeled.

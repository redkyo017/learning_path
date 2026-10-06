# Day 5 — Storage, Security & Role-Based Access Control (RBAC)

## Why this matters

Deploying stateless web services on Kubernetes is straightforward. But enterprise production systems must store persistent data and pass strict security and compliance audits (SOC2, PCI-DSS, ISO27001).

When engineers treat container storage naively, they encounter data corruption, dangling volumes that cost thousands of dollars, or pods stuck indefinitely in `ContainerCreating` waiting for a disk detach lock. And when engineers treat security naively, they leave pods running as UID 0 (root), grant cluster-admin service accounts to public-facing gateways, and mount host root filesystems.

Senior cloud architects master the storage lifecycle: decoupling physical infrastructure from pod requests using `StorageClasses` and `PersistentVolumeClaims`, and using `StatefulSets` for workloads that require stable network identity and dedicated storage. Simultaneously, they implement defense-in-depth security: locking down the Linux kernel boundary with `SecurityContext`, enforcing cluster-wide admission guardrails with Pod Security Standards (PSS/PSA), and constraining identity with least-privilege RBAC.

---

## The layer this covers

```
 kubectl apply ─► API server ─► authentication ─► RBAC authorization ─► admission (Pod Security Admission) ─► etcd
                                  (who are you?)    (may you do this?)    (is this pod spec acceptable?)
                                                                                     │
                                                                                     ▼  kubelet + container runtime
┌────────────────────────────────────────────────────────────────────────┐
│ Pod securityContext (what the kernel will let the process do)          │
│   runAsNonRoot + numeric runAsUser, seccompProfile: RuntimeDefault     │
│   allowPrivilegeEscalation: false, capabilities.drop: [ALL]            │
│   readOnlyRootFilesystem: true (good practice; NOT required by PSS)    │
└───────────────────────────────────┬────────────────────────────────────┘
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│ Storage                                                                │
│   [StatefulSet postgres] ─ volumeClaimTemplates ─► [PVC data-postgres-0]│
│                                                         │ StorageClass  │
│                                                         ▼ (provisioner, │
│   [PV: nodeAffinity -> node/zone]  ◄── bound, reclaimPolicy ──┘ binding  │
│        │                                                      mode)     │
│        ▼ mounted at /var/lib/postgresql/data                           │
└────────────────────────────────────────────────────────────────────────┘
```

Two different gates guard two different things. **RBAC** decides what an *identity* may ask the API server to do. **Pod Security Admission** decides what a *pod spec* may ask the node to do. Neither replaces the other, and neither limits what a process does *inside* a container once it runs: that is the `securityContext`'s job.

---

## Core concepts

### 1. The storage architecture

Kubernetes decouples storage administration from consumption with three objects:

```
[Developer request]            [Admin / platform template]       [Backing storage]
PersistentVolumeClaim (PVC) ──► StorageClass (provisioner) ──► PersistentVolume (PV)
 namespaced                      cluster-scoped                   cluster-scoped
```

1. **PersistentVolume (PV):** a piece of storage with a lifecycle independent of any pod. Created by an admin (static) or by a provisioner (dynamic). A PV carries `nodeAffinity` when the storage is only reachable from some nodes or zones.
2. **PersistentVolumeClaim (PVC):** a namespaced request for size, access mode and class. Pods reference PVCs, never PVs.
3. **StorageClass:** names the provisioner (`ebs.csi.aws.com`, `rancher.io/local-path`), its parameters, the `reclaimPolicy` copied onto the PVs it creates, and the `volumeBindingMode`.

Look at what your cluster has, before writing any manifest:

```bash
kubectl get storageclass
# NAME                 PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION
# hostpath             rancher.io/local-path   Delete          WaitForFirstConsumer   false
# standard (default)   rancher.io/local-path   Delete          WaitForFirstConsumer   false      <- Docker Desktop (kind)
```

A PVC without `storageClassName` gets the class annotated `storageclass.kubernetes.io/is-default-class: "true"`. `storageClassName: ""` means "no class: bind only to a pre-created PV". Note `RECLAIMPOLICY Delete` on the default class: **dynamically provisioned data dies with its PVC unless you change that.**

#### `volumeBindingMode`: Immediate vs WaitForFirstConsumer

- **`Immediate`:** the PV is created as soon as the PVC exists, before anyone knows where the pod will run. With zonal storage (EBS) the volume may be created in a zone where the pod cannot be scheduled (CPU, taints, anti-affinity), leaving the pod `Pending` forever.
- **`WaitForFirstConsumer`:** the PVC stays `Pending` ("waiting for first consumer to be created before binding") until a pod using it is scheduled; the scheduler picks a node first, then the provisioner creates the volume where that pod can reach it. This is the right default for zonal or node-local storage and is what Docker Desktop's classes use. A `Pending` PVC with no pod is **normal**, not an error.

#### Access modes: what they mean for scheduling

| Mode | Short | Meaning | Typical backing |
|:---|:---|:---|:---|
| ReadWriteOnce | RWO | read-write by **one node** at a time (several pods on that node may share it) | EBS, GCE PD, Azure Disk, local-path |
| ReadOnlyMany | ROX | read-only by many nodes | NFS, CephFS, EFS, read-only snapshots |
| ReadWriteMany | RWX | read-write by many nodes | EFS, NFS, CephFS |
| ReadWriteOncePod | RWOP | read-write by **one pod** in the whole cluster (stable since 1.29) | CSI drivers that support it |

Access modes are used for PV/PVC matching, and enforced differently per mode: **RWOP** is enforced by the scheduler and kubelet (a second pod using the claim stays `Pending`/unschedulable); **RWO** is enforced through volume attach for attachable volumes (an EBS volume cannot be attached to a second node), while node-local volumes such as local-path simply live on one node. The driver decides what it can actually honour. RWO is why a Deployment with `replicas: 3` and one RWO PVC works only when all pods land on the same node, and why a rolling update of a single-replica Deployment on RWO can deadlock the new pod on `Multi-Attach error` while the old pod still holds the disk.

#### Volume node/zone affinity

A dynamically provisioned volume is not a free-floating disk. Its PV records where it lives:

```bash
kubectl get pv <name> -o jsonpath='{.spec.nodeAffinity}'
# {"required":{"nodeSelectorTerms":[{"matchExpressions":[{"key":"kubernetes.io/hostname","operator":"In","values":["desktop-control-plane"]}]}]}}
```

On EBS the key is `topology.kubernetes.io/zone`. The scheduler uses it to constrain the pod, so "the volume follows the pod" is only true inside that boundary: pod `postgres-0` can reschedule across nodes **in the same zone** (EBS detaches/attaches), never to another zone. With local-path it is pinned to one node, so if that node dies the data is unreachable until the node returns. That is one reason local-path is a lab tool, not production storage.

#### Reclaim policies and the PV lifecycle

```
provisioned ─► Available ─► Bound (PVC) ─► Released (PVC deleted) ─► Delete: PV + backing data removed
                                                                   └► Retain: PV kept, data kept, needs an admin
```

- **`Delete`** (default for dynamically provisioned PVs): deleting the PVC deletes the PV **and the data**.
- **`Retain`:** the PV becomes `Released`; the data survives but the PV is not reusable until an admin clears `spec.claimRef` (or deletes and re-creates the PV object) and scrubs or re-binds it. A `Released` PV does not bind to a new PVC on its own, because it still points at the old claim.
- You can change the policy on a live PV: `kubectl patch pv <name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'`. Do this *before* you delete anything precious, and for production databases prefer a StorageClass with `Retain` plus snapshots/backups. Retain is not a backup: it protects against an accidental PVC delete, not against corruption or `DROP TABLE`.

---

### 2. StatefulSets vs Deployments

A Deployment's pods are interchangeable: one template, random names, any pod can replace any other. A database replica is not interchangeable. A StatefulSet gives each replica an identity:

1. **Stable network identity:** pods are `postgres-0`, `postgres-1`; with a headless Service (`clusterIP: None`, referenced by `spec.serviceName`) each gets a DNS name `postgres-0.postgres-headless.orderflow.svc.cluster.local` that survives restarts, even though the IP changes.
2. **Stable, per-pod storage:** `volumeClaimTemplates` creates one PVC per ordinal (`data-postgres-0`). A deleted/rescheduled `postgres-0` re-attaches the same PVC.
3. **Ordered operation:** `podManagementPolicy: OrderedReady` (default) starts pod N+1 only after pod N is Ready and terminates in reverse order. `Parallel` launches and deletes all pods at once (use it for peers that need no ordering; it does not change per-pod storage or naming). Rolling updates always go from the highest ordinal down; `updateStrategy.rollingUpdate.partition` holds back lower ordinals for canarying.

#### PVCs survive the StatefulSet, by default

Deleting a StatefulSet or scaling it down **does not delete its PVCs**. That is deliberate (data safety) and a classic cost leak. Since 1.32 (GA) you control it:

```yaml
persistentVolumeClaimRetentionPolicy:
  whenDeleted: Retain   # Retain (default) | Delete: PVCs deleted with the StatefulSet
  whenScaled:  Retain   # Retain (default) | Delete: PVC of a removed ordinal deleted on scale-down
```

`Delete` plus a PVC whose class has reclaim `Delete` means "`kubectl delete sts` destroys the data": right for caches and CI, wrong for databases. The lab demonstrates the default: delete the StatefulSet, recreate it, and the table is still there. On recreate, the new StatefulSet adopts the existing PVC by name (`data-postgres-0`).

#### When *not* to run Postgres yourself

A StatefulSet gives you identity and storage, **not** a database operator: no failover, backups, point-in-time recovery or version upgrades. Production options: a managed service (RDS/Aurora, Cloud SQL) or an operator (CloudNativePG, Zalando, Crunchy). Single-instance Postgres in a StatefulSet is for development and learning.

---

### 3. Linux hardening with `securityContext`

A container is a process on the host kernel. Everything the process may do is a kernel decision, and `securityContext` is how you shrink that surface. The hardened shape used throughout this lab:

```yaml
spec:
  securityContext:                  # pod level
    runAsNonRoot: true
    runAsUser: 65532                # numeric! see the trap below
    runAsGroup: 65532
    fsGroup: 65532                  # group ownership applied to mounted volumes
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: order-api
      securityContext:              # container level
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
```

- **`runAsNonRoot: true`:** kubelet refuses to start the container if it would run as UID 0. **The trap:** kubelet can only verify a *numeric* UID. If the image says `USER postgres` (a name) and you set only `runAsNonRoot: true`, the container fails with `CreateContainerConfigError: container has runAsNonRoot and image has non-numeric user (postgres), cannot verify user is non-root`. Fix: set `runAsUser` to the numeric UID that matches what the image expects (which is why Day 3 uses 65532 for distroless). The reverse trap: an image with **no** `USER` instruction runs as root, and `runAsNonRoot: true` alone fails with `container has runAsNonRoot and image will run as root`. `postgres:16-alpine` is such an image (it starts as root and drops to `postgres` itself), so this lab sets `runAsUser: 70`, the image's own `postgres` UID, so the users and directories baked into the image line up (the Debian `postgres:16` image uses 999). Other UIDs can work too, because the entrypoint fakes a passwd entry with `nss_wrapper`, but only if every directory it writes is writable for them.
- **`allowPrivilegeEscalation: false`:** sets the kernel's `no_new_privs` bit: `setuid` binaries and file capabilities can no longer raise privileges. (It is also forced `true` when the container is privileged or has `CAP_SYS_ADMIN`.)
- **`capabilities.drop: ["ALL"]`:** the runtime's default set is about 14 capabilities (containerd/Docker: `CHOWN`, `DAC_OVERRIDE`, `FSETID`, `FOWNER`, `MKNOD`, `NET_RAW`, `SETGID`, `SETUID`, `SETFCAP`, `SETPCAP`, `NET_BIND_SERVICE`, `SYS_CHROOT`, `KILL`, `AUDIT_WRITE`). `SYS_ADMIN`, `NET_ADMIN` and `SYS_PTRACE` are **not** in it; they must be added explicitly, which is exactly what Baseline forbids. Drop everything, then add back only what you can justify (`NET_BIND_SERVICE` is the one `restricted` allows, for binding ports below 1024).
- **`seccompProfile: RuntimeDefault`:** filters syscalls with the runtime's default profile (blocks about 40+ dangerous syscalls). Without it a Kubernetes pod runs **unconfined** (`Seccomp: 0`), unlike plain `docker run`, which applies the default profile. Kubelet's `--seccomp-default` flips this per node.
- **`readOnlyRootFilesystem: true`:** mounts the container's root `MS_RDONLY`; writes fail with `EROFS`. It stops droppers and tampering with binaries. **It is not part of any Pod Security Standard**, so `restricted` namespaces accept writable root filesystems. Anything legitimately written (temp files, sockets, caches) needs a writable volume such as an `emptyDir` mounted at that path.
- **`fsGroup`:** for volume types that support ownership management (block/CSI volumes such as EBS), kubelet makes the volume group-owned by that GID and group-writable, so a non-root user can write to a fresh PVC (fresh filesystems also contain a root-owned `lost+found`). It does **not** apply to `hostPath`-style volumes such as local-path, which are writable only because the provisioner creates the directory `0777`. Large volumes can make this slow (`fsGroupChangePolicy: OnRootMismatch` skips it when ownership already matches).
- **`emptyDir`** lives on the **node's disk** by default and survives container restarts but not pod deletion. `medium: Memory` makes it a tmpfs, backed by RAM and **counted against the container's memory limit**; `sizeLimit` evicts the pod when exceeded.

**Distroless means no shell**, so you cannot `kubectl exec ... sh` into `order-api`. To probe its read-only root the lab adds a debug-only `busybox` container (`fs-probe`) with the *identical* securityContext to the same pod. In production use `kubectl debug` ephemeral containers instead.

---

### 4. Pod Security Admission (PSA)

Pod Security Admission is a built-in admission controller (stable since 1.25; the successor of PodSecurityPolicy, removed in 1.25) that checks **pod specs** against the three Pod Security Standards. You configure it with **namespace labels**:

| Standard | Intent | What it adds / forbids (cumulative) |
|:---|:---|:---|
| **privileged** | unrestricted | nothing is checked: for CNI, CSI node drivers, system daemons |
| **baseline** | block known privilege escalations | forbids `hostNetwork`/`hostPID`/`hostIPC`, `hostPath` volumes, `privileged: true`, `hostPort`, adding capabilities beyond the default set minus `NET_RAW` (so no `SYS_ADMIN`, and `NET_RAW` cannot be added back), most `procMount`/sysctl/AppArmor/SELinux overrides |
| **restricted** | current hardening best practice | everything in baseline **plus**: `runAsNonRoot: true` and no `runAsUser: 0`, `allowPrivilegeEscalation: false`, seccomp `RuntimeDefault` or `Localhost`, `capabilities.drop` containing `ALL` (only `NET_BIND_SERVICE` may be added), only a safe list of volume types |

Three things the usual cheat sheet gets wrong:
- **A namespace with no `pod-security.kubernetes.io/*` label is `privileged`, not baseline.** Out of the box nothing is enforced (a cluster admin can change the cluster-wide default in the `AdmissionConfiguration`).
- **`readOnlyRootFilesystem` is not checked** at any level.
- **PSA only validates pods.** It does not mutate (it will not add `seccompProfile` for you), it checks workload *templates* (Deployment, StatefulSet, Job...) only to emit warnings, and **enforcement acts at pod creation**: pods that already run are untouched until they are recreated. The failure then shows up in the **ReplicaSet/StatefulSet events** (`FailedCreate ... violates PodSecurity`), not at `kubectl apply`, so a "successful" apply followed by `0/1 READY` is the symptom.

#### Three modes, each with its own level and version

| Mode label | Effect on violation |
|:---|:---|
| `enforce` | the pod is **rejected** |
| `warn` | the user gets a warning in the API response; the pod is admitted |
| `audit` | an annotation is added to the audit-log event; the pod is admitted |

Each takes `pod-security.kubernetes.io/<mode>=<level>` and optional `<mode>-version=<v1.34|latest>` (pin the version so an upgrade does not suddenly tighten a namespace). Standard rollout: set `warn` and `audit` first, fix what they report, then `enforce`.

**Preview before you enforce**, with a server-side dry run against the pods that already exist:

```bash
kubectl label --dry-run=server --overwrite ns orderflow pod-security.kubernetes.io/enforce=restricted
# Warning: existing pods in namespace "orderflow" violate the new PodSecurity enforce level "restricted:latest"
# Warning: legacy-root-...: allowPrivilegeEscalation != false, unrestricted capabilities, runAsNonRoot != true, seccompProfile
# namespace/orderflow labeled (server dry run)
```

Exemptions (usernames, runtimeClasses, namespaces) exist only in the cluster-wide admission configuration. `kube-system` and other platform namespaces typically run `privileged`.

---

### 5. Role-Based Access Control (RBAC)

Authentication ("who are you?": certificates, OIDC tokens, ServiceAccount tokens) happens first; RBAC authorization then answers "may *this identity* do *this verb* on *this resource*?". RBAC is **additive and deny-by-default**: there are no deny rules; an identity can do the union of everything bound to it.

```
[Subject]                     [Binding]                      [Role]
ServiceAccount order-api-sa ─► RoleBinding order-api-binding ─► Role order-api-role
                              (namespace orderflow)             configmaps: get,list,watch
                                                                secrets/orderflow-secrets: get
```

| Object | Scope | Use |
|:---|:---|:---|
| `Role` | one namespace | rules for that namespace's resources |
| `RoleBinding` | one namespace | grants a Role **or a ClusterRole** to subjects *inside this namespace only* |
| `ClusterRole` | cluster | cluster-scoped resources (nodes, PVs), non-resource URLs, or a reusable rule set |
| `ClusterRoleBinding` | cluster | grants a ClusterRole in **every** namespace plus cluster-scoped resources |

**RoleBinding → ClusterRole** is the idiom that avoids copy-pasting rules: bind the built-in `view` (read-only, **excludes Secrets and Roles**), `edit` (read/write most namespaced objects, can read Secrets and use any ServiceAccount, so it is effectively privilege escalation inside the namespace) or `admin` to a subject in one namespace. Aggregated ClusterRoles (`aggregationRule` with label selectors such as `rbac.authorization.k8s.io/aggregate-to-view: "true"`) are how CRD authors extend `view`/`edit`/`admin` for their custom resources without editing the built-ins.

#### ServiceAccounts

Every pod runs as a ServiceAccount (`default` if you do not say). Since 1.24 no long-lived token Secret is created; a pod gets a **short-lived, audience-bound projected token** mounted at `/var/run/secrets/kubernetes.io/serviceaccount/token` unless you opt out. Principles:

- one ServiceAccount per workload, named after it; never bind permissions to `default`;
- `automountServiceAccountToken: false` on the ServiceAccount **and/or** the pod spec (the pod field wins) for anything that never calls the API: a compromised web app then has no credential to steal;
- note what `can-i` reports: **RBAC is attached to the ServiceAccount, not the pod**. In this lab `order-api-sa` has a Role, but the pod mounts no token, so even that Role is unreachable from inside the container. The Role models "what this identity may do if a workload asks for the token".

#### Auditing permissions

```bash
SA=system:serviceaccount:orderflow:order-api-sa
kubectl auth can-i get configmaps -n orderflow --as=$SA                 # yes
kubectl auth can-i get secrets -n orderflow --as=$SA                    # no  (resourceNames only covers one object)
kubectl auth can-i get secrets/orderflow-secrets -n orderflow --as=$SA  # yes
kubectl auth can-i --list -n orderflow --as=$SA                         # everything it can do in the namespace
```

`--list` is the audit tool: it prints *all* effective rules including the defaults every authenticated identity gets (`selfsubjectreviews`, `/version`, `/healthz`...). Your own `can-i` needs `impersonate` rights for `--as`.

Limits of `resourceNames`: it restricts `get`, `update`, `patch`, `delete` on a **named** object. It does not constrain a plain `list` or `watch` (the request names no object, so a `list` returns all of them and granting `list` on secrets exposes every secret's data); it only applies to them when the client sends `fieldSelector=metadata.name=<name>`, which you cannot require. It never constrains `create`. Do not grant `list`/`watch` on secrets.

#### Secrets: env var, volume, or external

| Delivery | Exposure |
|:---|:---|
| `env` / `envFrom` | in the process environment: inherited by child processes, visible in `/proc/<pid>/environ`, printed by crash reporters and "debug" endpoints, shown by `kubectl exec ... env`; **cannot be rotated without a restart** |
| volume mount (tmpfs) | file with `defaultMode` permissions (0440 + `fsGroup` here); updates propagate to the pod (except `subPath` mounts); apps read it with `*_FILE`-style options. Preferred |
| external secret manager | secrets never live in Git or (optionally) etcd: **External Secrets Operator** syncs from AWS Secrets Manager/Vault/GCP SM into Kubernetes Secrets; the **Secrets Store CSI driver** mounts them straight into the pod |

A Kubernetes `Secret` is base64, **not encryption**. Anyone with `get` on it reads it, and without etcd encryption at rest (`EncryptionConfiguration`, KMS provider on EKS) it sits in plaintext in etcd. In this lab Postgres reads its password from a mounted file (`POSTGRES_PASSWORD_FILE`), and the hardened `order-api` is not given the Secret at all (it does not use it).

---

## Decision tree: storage & access

```
Need persistent data?
├── Database / stateful peer set ──► StatefulSet + volumeClaimTemplates (RWO), StorageClass with WaitForFirstConsumer
│     └── precious data? ──► reclaimPolicy Retain, retention policy Retain, backups; or a managed DB / operator
├── Shared read/write files across nodes ──► RWX storage class (EFS/NFS/CephFS), not a Deployment on RWO
└── Scratch / temp / sockets             ──► emptyDir (disk) or emptyDir{medium: Memory} (RAM, counts to limit)

Need Kubernetes API permissions?
├── None (most apps)           ──► dedicated ServiceAccount, automountServiceAccountToken: false
├── Within one namespace       ──► Role (or ClusterRole such as `view`) + RoleBinding
└── Cluster-wide / cluster-scoped objects ──► ClusterRole + ClusterRoleBinding (rare for apps; operators/controllers)
```

---

## Exercises

### Exercise 1: The Pending PVC
A PVC requesting `50Gi` with `accessModes: [ReadWriteMany]` stays `Pending` on an EBS-backed cluster. A second PVC on the Docker Desktop cluster is `Pending` too, but `kubectl describe pvc` says "waiting for first consumer to be created before binding". Explain both and name the first three checks.

**Hint:** One is an error, the other is the system working as designed. `kubectl describe pvc` Events first.

**Solution sketch:**
1. `kubectl describe pvc <name> -n <ns>` and read **Events**; then `kubectl get storageclass` for provisioner, default class, `volumeBindingMode`.
2. EBS (`ebs.csi.aws.com`) supports only RWO/RWOP: an RWX request fails provisioning with an event from the CSI controller. RWX needs EFS/NFS/CephFS.
3. The second PVC is fine: `WaitForFirstConsumer` waits for a pod to be scheduled. Create the pod that mounts it; if the pod is then unschedulable, `kubectl describe pod` shows `volume node affinity conflict` or similar, which is the real problem.
4. Also check: no default StorageClass (PVC with no class stays Pending), the provisioner pods are crashing (`kubectl get pods -n kube-system` / `local-path-storage`), quota exceeded.

---

### Exercise 2: Read-only filesystem
After setting `readOnlyRootFilesystem: true`, a container logs `open /tmp/app.pid: read-only file system`. Fix it without disabling the setting, and say whether `emptyDir` uses RAM.

**Hint:** Find the exact paths the app writes; mount a volume at each.

**Solution sketch:**
```yaml
spec:
  volumes:
    - name: tmp-dir
      emptyDir: {}            # node disk; add `medium: Memory` for tmpfs (counted in the memory limit)
  containers:
    - name: app
      volumeMounts:
        - name: tmp-dir
          mountPath: /tmp
```
The rest of the filesystem stays immutable. Mount one volume per writable path (Postgres needs `/var/run/postgresql` and `/tmp`). `emptyDir` uses node disk unless `medium: Memory`; a tmpfs counts against the container's memory limit and can OOM-kill it. Find write paths by reading `kubectl logs` for `EROFS`, or run the container once without the setting and `strace`/inspect.

---

### Exercise 3: Default ServiceAccount
A pod without `serviceAccountName` is compromised via RCE. What does the attacker find under `/var/run/secrets/kubernetes.io/serviceaccount/`, what can they do with it, and how do you prevent it?

**Hint:** Two settings control it: who the pod runs as, and whether a token is mounted at all.

**Solution sketch:**
1. A projected, short-lived JWT for the namespace's `default` ServiceAccount (plus the CA and namespace). It is valid as long as the pod lives.
2. It is only as powerful as the bindings on `default`. Check `kubectl auth can-i --list --as=system:serviceaccount:<ns>:default`: if anyone granted `default` something (or a ClusterRoleBinding to `system:serviceaccounts`), the attacker has it. At minimum every authenticated identity can read discovery endpoints, which helps reconnaissance.
3. Prevent: a dedicated ServiceAccount per workload with only the Role it needs, `automountServiceAccountToken: false` on the ServiceAccount and the pod when the app does not call the API, and no bindings on `default`.

---

### Exercise 4: Postgres rejected by `restricted`
You label a namespace `enforce=restricted` and apply a Postgres StatefulSet that only sets `runAsUser`/`fsGroup`. `kubectl apply` succeeds but no pod appears. Why, how do you see it, and what is the minimum fix?

**Hint:** Where do admission errors for pods created by a controller appear?

**Solution sketch:**
`apply` accepts the StatefulSet (PSA only *warns* on templates); the StatefulSet controller then fails to create the pod. `kubectl describe statefulset postgres` / `kubectl get events` show `create Pod postgres-0 failed ... violates PodSecurity "restricted:latest": allowPrivilegeEscalation != false ..., unrestricted capabilities ..., seccompProfile ...`. Fix in the pod spec, not the namespace: pod `seccompProfile: {type: RuntimeDefault}`, container `allowPrivilegeEscalation: false` and `capabilities: {drop: ["ALL"]}`, with `runAsNonRoot: true` and a numeric `runAsUser` (70 is the image's own UID for `postgres:16-alpine`, 999 for `postgres:16`). Then verify with `kubectl label --dry-run=server`.

---

### Exercise 5: Least-privilege audit
`auditor-sa` is bound to the ClusterRole `view` by a **RoleBinding** in `orderflow`. Predict (then check): can it list pods in `orderflow`? in `default`? read secrets? list roles? What changes if you swap the RoleBinding for a **ClusterRoleBinding**?

**Hint:** The binding's scope, not the role's, decides where the rules apply. Look at what `view` omits.

**Solution sketch:** pods in `orderflow`: yes. Pods in `default`: no (RoleBinding is namespaced). Secrets: no (`view` excludes them: it would expose ServiceAccount tokens and credentials). Roles/RoleBindings: no. With a ClusterRoleBinding it can read the same kinds in **every** namespace, and cluster-scoped resources `view` covers (namespaces), which is rarely what you want for an app identity. Verify with `kubectl auth can-i --list --as=... -n <ns>`.

---

### Exercise 6: Did the data survive?
(a) `kubectl delete pod postgres-0`; (b) `kubectl delete statefulset postgres`; (c) `kubectl delete pvc data-postgres-0` on a class with `reclaimPolicy: Delete`; (d) same on `Retain`. For each, is the data preserved, and what must you do to get it back?

**Hint:** Which object owns the data: pod, StatefulSet, PVC or PV?

**Solution sketch:** (a) kept; the same PVC is re-attached by the replacement pod. (b) kept: PVC survives (retention policy `whenDeleted: Retain`); re-create the StatefulSet and it re-adopts `data-postgres-0`. (c) **gone**: the PV and backing directory/disk are deleted. (d) kept on disk but PV is `Released`: clear `spec.claimRef` (or re-create the PV object), create a PVC with `volumeName: <pv>` and the same class, mount it; a `Released` PV never binds on its own. Safest long-term answer: `Retain` + volume snapshots/backups.

---

## Anti-patterns / Common mistakes

1. **Running as root, or `runAsNonRoot` with a non-numeric image `USER`:** the first widens the blast radius of any breakout; the second fails at start with `cannot verify user is non-root`. Use numeric UIDs.
2. **Believing `readOnlyRootFilesystem` is part of `restricted`:** it is not enforced by any Pod Security level. Set it yourself.
3. **Assuming a namespace without labels is "baseline":** it is `privileged`. Label it, and roll out `warn`/`audit` before `enforce`.
4. **Wildcard RBAC (`*` verbs on `*` resources)** and binding anything to `default`; granting `list`/`watch` on secrets (reads all of them); using `edit`/`admin` where `view` is enough.
5. **Secrets as env vars** (visible in `/proc`, crash dumps, child processes, `exec ... env`; no live rotation). Mount files; for anything serious use an external manager (External Secrets Operator, Secrets Store CSI driver) and etcd encryption at rest.
6. **`Delete` reclaim policy and `whenDeleted: Delete` for data you cannot rebuild.** Use `Retain` and real backups.
7. **Forgetting that PVCs outlive StatefulSets:** deleted StatefulSets leave PVCs (and cost). Clean up deliberately.
8. **Mounting `emptyDir` with `medium: Memory` for big scratch data:** it eats the pod's memory limit.
9. **Databases as Deployments on RWO volumes:** rolling updates collide on `Multi-Attach`, replicas share one disk. Use a StatefulSet, or better an operator or managed DB.
10. **No PodDisruptionBudget** on stateful or critical workloads (covered on Day 6).

---

## Recall drill

1. What does a namespace with no `pod-security.kubernetes.io/*` labels enforce, and which securityContext field commonly assumed to be in `restricted` is not?
2. Name the three PSA modes and what each does on a violation. Which one fires at `kubectl apply` of a Deployment?
3. Why does `WaitForFirstConsumer` leave a PVC `Pending`, and why is that good for zonal storage?
4. You delete a StatefulSet. What happens to its PVCs, and which field changes it?
5. PVC deleted: what happens to the data with reclaim `Delete` vs `Retain`, and what state is the PV in afterwards?
6. Which Kubernetes object does a RoleBinding to ClusterRole `view` grant access in, and what does `view` leave out?
7. Command to list everything a ServiceAccount can do in a namespace?
8. Why is a secret in an env var worse than one in a mounted file?

<details>
<summary>Answers</summary>

1. `privileged` (nothing enforced). `readOnlyRootFilesystem` is not in any Pod Security Standard.
2. `enforce` rejects; `warn` returns a client warning; `audit` annotates the audit log. `warn` (and a dry-run) shows at apply time for workload templates; `enforce` rejections of controller-created pods appear in ReplicaSet/StatefulSet events.
3. The scheduler must choose a node first so the volume is provisioned where the pod can run; without a pod there is no node/zone to choose.
4. Kept (data safe, cost continues). `persistentVolumeClaimRetentionPolicy.whenDeleted` / `whenScaled` (`Retain` default, `Delete`), GA in 1.32.
5. `Delete`: PV and data removed. `Retain`: data kept, PV `Released`, needs claimRef cleared before reuse.
6. Only the RoleBinding's namespace. `view` excludes Secrets and Role/RoleBinding objects (and cannot write).
7. `kubectl auth can-i --list -n <ns> --as=system:serviceaccount:<ns>:<sa>`.
8. Inherited by child processes, in `/proc/<pid>/environ`, in crash dumps/logs, shown by `exec ... env`, and not updatable without a restart.
</details>

---

## Lab
See [`labs/day05/`](../labs/day05/).
- **The goal:** Preview then enforce the `restricted` Pod Security Standard and watch a root workload get rejected; run Postgres as a hardened StatefulSet (password from a mounted file, read-only rootfs); prove PVCs survive pod **and StatefulSet** deletion with data intact; run `order-api` with a dedicated ServiceAccount, no API token and a read-only rootfs (shown with a busybox `fs-probe` container); compare Retain vs Delete reclaim; audit three ServiceAccounts with `kubectl auth can-i` including `--list`.
- **Success signal:** `postgres-0` is `1/1 Running` in a `restricted` namespace and the `orders_ledger` row survives `kubectl delete statefulset postgres`; `fs-probe` prints `Read-only file system`; `order-api-sa` can `get configmaps` but not `list secrets`; a Retain PV is `Released` with its file still readable after the PVC is gone, while the Delete PV vanished.

---

## Key commands reference

| Command | Purpose |
|:---|:---|
| `kubectl get storageclass` | provisioner, default class, reclaim policy, binding mode |
| `kubectl get pv,pvc -n <ns>` | binding state; `Released` PVs; `kubectl get pv <n> -o jsonpath='{.spec.nodeAffinity}'` for volume affinity |
| `kubectl label --dry-run=server --overwrite ns <ns> pod-security.kubernetes.io/enforce=restricted` | preview which existing pods would violate a level |
| `kubectl label ns <ns> pod-security.kubernetes.io/{enforce,warn,audit}=restricted` | turn the three PSA modes on |
| `kubectl get events -n <ns> --field-selector reason=FailedCreate` | why a controller cannot create pods (PSA, quota) |
| `kubectl auth can-i <verb> <resource>[/<name>] -n <ns> --as=system:serviceaccount:<ns>:<sa>` | test one permission |
| `kubectl auth can-i --list -n <ns> --as=...` | all effective permissions of a subject |
| `kubectl patch pv <n> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'` | protect a live volume |

---

## Teardown
Removes everything Day 5 created, **including the `restricted` Pod Security label**: `reset.sh` recreates `orderflow` without it, and the last command removes the namespace so Day 6 starts clean. The PV of `data-postgres-0` is removed when the namespace deletes its PVC.
```bash
bash labs/shared/reset.sh
kubectl delete namespace orderflow
kubectl delete pv $(kubectl get pv -o jsonpath='{range .items[?(@.spec.storageClassName=="day05-retain")]}{.metadata.name}{" "}{end}') 2>/dev/null || true   # leftover Retain PV, if Step 8 was interrupted
kubectl delete storageclass day05-retain --ignore-not-found
kubectl get pv                          # nothing from this lab should remain
```

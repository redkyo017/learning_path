# Day 3 — Kubernetes Core Objects & The Reconciliation Loop

## Why this matters

Docker Compose works wonders for a single developer machine. But in production, servers fail, network cables get disconnected, and traffic spikes demand dynamic horizontal autoscaling. In production, you don't want an imperative tool that you have to tell: "start container X, now restart container Y." You want a declarative system that you can hand a desired specification to, saying: "Keep exactly 3 healthy instances of `order-api` running at all times."

Kubernetes is that declarative system. Yet many backend developers view Kubernetes as an impenetrable mountain of boilerplate YAML. They copy-paste manifests, struggle when pods enter `CrashLoopBackOff`, and resort to `kubectl delete pod` hoping magic happens.

To master Kubernetes, you must understand the **Reconciliation Loop** and the **Controller Hierarchy**. A `Deployment` does not manage containers; it manages `ReplicaSets`. A `ReplicaSet` does not manage processes; it manages `Pods`. And a `Pod` is not a container—it is a co-scheduling sandbox. Once this hierarchy clicks, every field in a manifest becomes intuitive.

---

## The layer this covers

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Kubernetes Control Plane                        │
│                                                                        │
│   kubectl apply -f deployment.yaml                                     │
│        │                                                               │
│        ▼                                                               │
│   [kube-apiserver] ◄───CRUD───► [etcd] (Single Source of Truth)        │
│        ▲      ▲                                                        │
│        │      │ watch                                                  │
│        │      └──────────────────────────┐                             │
│        ▼                                 ▼                             │
│   [kube-scheduler]              [kube-controller-manager]              │
│   (Assigns Pods to Nodes)       (DeploymentController,                 │
│                                  ReplicaSetController, etc.)           │
└────────┬─────────────────────────────────┬─────────────────────────────┘
         │                                 │
         │ Assign Node                     │ Reconcile Loop
         ▼                                 ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Worker Node (Data Plane)                        │
│                                                                        │
│   [kubelet] ──(Watches apiserver for Pods assigned to THIS node)       │
│        │                                                               │
│        ▼ gRPC (CRI)                                                    │
│   [containerd] ──► [runc] ──► Spawns Pause container + App container   │
│                                                                        │
│   [kube-proxy] ──(Programs local iptables/nftables rules for Services)  │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Core concepts

### 1. Control Plane vs Data Plane Architecture

Kubernetes separates cluster management from workload execution:

- **Control Plane:**
  - **`kube-apiserver`:** The stateless REST API front-end. It is the **only** component that directly talks to `etcd`. All other components (scheduler, controller-manager, kubelet) communicate strictly through the API server via streaming **watches** (HTTP chunked/streamed responses, resumable from a `resourceVersion`).
  - **`etcd`:** A distributed, consistent key-value store implementing the Raft consensus algorithm. It holds the entire desired and actual cluster state.
  - **`kube-scheduler`:** Filters and scores available worker nodes based on resource requests (`requests.cpu`, `requests.memory`), affinity rules, taints, and tolerations, writing a node binding back to the API server.
  - **`kube-controller-manager`:** Runs core reconciliation control loops in a single process.

- **Data Plane (Worker Nodes):**
  - **`kubelet`:** The primary node agent. Watches the API server for PodSpecs assigned to its node. Instructs the container runtime (via the Container Runtime Interface - CRI) to pull images, configure storage volumes, and start/stop containers. Continuously reports pod status and node health back to the API server.
  - **`kube-proxy`:** Maintains network routing rules on each node to forward traffic sent to virtual Service IPs (`ClusterIP`) to backend Pod endpoints. Modes: `iptables` (the long-time default), `nftables` (GA in 1.33, the modern replacement; needs a recent kernel) and `ipvs` (**deprecated** since 1.35, still present but headed for removal). Some CNIs (Cilium) replace kube-proxy entirely. Docker Desktop's kind provisioner runs kube-proxy in iptables mode (`kubectl -n kube-system get cm kube-proxy -o yaml | /usr/bin/grep mode`).
  - **Container Runtime (`containerd`):** Executes low-level OCI runtime commands to run containers.

---

### 2. The Universal Reconciliation Loop

The heartbeat of Kubernetes is the reconciliation loop:

```
Observe actual state → Compare with desired state → Act → Repeat
```

Every Kubernetes controller executes this loop continuously.
- If you declare `replicas: 3` and only 2 pods exist, the ReplicaSet controller issues a `CreatePod` call.
- If a worker node crashes and its 1 pod disappears, the controller notices that actual count is 2 and schedules a replacement.
- Self-healing is not a special feature; it is an organic side-effect of the reconciliation loop constantly driving actual state toward desired state.

**Controllers do not poll the API server.** Each controller runs an **informer** (client-go): one initial `LIST`, then a long-lived `WATCH` that streams change events into a local in-memory cache plus a work queue. The reconcile function reads from that cache (cheap) and only writes to the API server when it must act. Consequences worth knowing: (1) the loop is *level-triggered* — it reconciles "current vs desired" for an object key, not "handle event X", so a missed or duplicate event is harmless; (2) a periodic *resync* re-queues everything as a safety net; (3) reads can be slightly stale, which is why a controller may briefly create one pod too many and then correct it.

---

### 3. The Workload Object Hierarchy

```
[Deployment] (Manages rollout strategy, versions, history, rollbacks)
     │
     └──► [ReplicaSet] (Manages exact replica count & self-healing)
               │
               └──► [Pod] (Co-scheduling sandbox: shared NetNS + Volumes)
                         │
                         ├──► Pause Container (Holds IP & NetNS)
                         └──► Application Container (order-api process)
```

#### A. Pod — The Atomic Unit of Scheduling
Why does Kubernetes schedule Pods instead of individual containers?
- A Pod is an environment containing one or more tightly coupled containers that share:
  1. **The same Network Namespace (`NET`):** Containers inside the same Pod share the exact same IP address and port space. They can communicate with each other over `localhost`!
  2. **The same IPC Namespace (`IPC`):** Containers can use shared memory (POSIX/SysV).
  3. **Shared Storage Volumes:** Volumes defined in a Pod are mounted into containers at designated paths.
- **The Pause Container:** When a Pod starts, the kubelet first launches an ultra-lightweight infrastructure container (`pause`). The pause container creates the Pod's network namespace. When application containers crash or restart, the network namespace remains active, keeping the Pod IP stable.

#### B. ReplicaSet — The Scaler
- Guarantees that a specified number of Pod replicas are running at any given time.
- Uses **Label Selectors** (`matchLabels`) to discover which Pods belong to it.
- If an unmanaged Pod (no controller `ownerReference`) exists with matching labels, the ReplicaSet **adopts** it, and if that pushes the count above `replicas` it deletes a surplus pod.

#### B2. Ownership: `ownerReferences`, garbage collection and `--cascade`
Every object a controller creates carries `metadata.ownerReferences` pointing at its owner (`Pod → ReplicaSet → Deployment`, with `controller: true` and `blockOwnerDeletion: true`). The **garbage collector** controller deletes dependents whose owners are gone:

| Delete mode | Command | Effect |
|:---|:---|:---|
| Background (default) | `kubectl delete deploy x` | Owner removed immediately, GC deletes ReplicaSets and Pods afterwards |
| Foreground | `kubectl delete deploy x --cascade=foreground` | Owner stays (`deletionTimestamp` set) until dependents with `blockOwnerDeletion` are gone |
| Orphan | `kubectl delete deploy x --cascade=orphan` | Only the owner is deleted; dependents lose their `ownerReference` and keep running |

Adoption/release is purely selector-based: change a Pod's labels so it no longer matches and the ReplicaSet **releases** it (removes the ownerReference) and creates a replacement; make it match again and the ReplicaSet **re-adopts** it. This is a legitimate debugging trick: relabel a misbehaving pod to pull it out of its Service and ReplicaSet while keeping it alive for inspection. `--cascade=orphan` is how you migrate a workload between controllers or re-create a Deployment without restarting pods; when you re-apply a Deployment whose pod template hashes to an existing orphaned ReplicaSet, that ReplicaSet is adopted again with no new pods.

#### B3. `pod-template-hash`
The Deployment controller hashes the pod template (`spec.template`) and adds it as the label `pod-template-hash` to the ReplicaSet name, selector and every Pod it creates. That is what keeps two ReplicaSets of the same Deployment (old and new) from fighting over the same pods even though both select `app: order-api`. Anything that changes the template (image, env, resources, labels, probes) produces a new hash and therefore a new ReplicaSet and a rollout; changing `replicas` does not touch the template, so it never rolls.

#### C. Deployment — The Orchestrator of Deployments
- Manages the lifecycle of ReplicaSets.
- Enables **Zero-Downtime Rolling Updates**:
  1. Creates a new ReplicaSet (`v2`).
  2. Scales up `v2` while incrementally scaling down `v1` governed by `maxSurge` and `maxUnavailable`.
  3. Preserves `revisionHistoryLimit` (default 10) old ReplicaSets, scaled to 0, so you can execute `kubectl rollout undo`.
- **A rollout only progresses while new pods become Ready.** With `maxUnavailable: 0` a pod that never passes readiness stalls the rollout and the old pods keep serving. After `progressDeadlineSeconds` (default 600 s) without progress the Deployment gets condition `Progressing=False, reason=ProgressDeadlineExceeded` and `kubectl rollout status` exits non-zero. **Kubernetes only reports this; it never rolls back automatically.** CI/CD (or Argo Rollouts/Flagger) has to run `kubectl rollout undo`. Always pass `--timeout` to `rollout status` in scripts so a stuck rollout cannot hang a pipeline.
- **Revision numbers:** each template change creates a revision; `rollout undo` re-activates an old ReplicaSet and gives it a **new, higher** revision number (the old number disappears from `rollout history`). Record why with the `kubernetes.io/change-cause` annotation.
- **Imperative vs declarative:** `kubectl scale`, `set image` and `patch` change live state only; the next `kubectl apply -f` of the original file reverts them (replicas back to the file's value, image back to the file's tag). Keep the file as the source of truth, and when an HPA owns `replicas`, remove `replicas` from the manifest so apply does not fight it.

#### D. Pods are cattle: node failure and eviction
A *naked* Pod (no controller) is not "permanently deleted on reboot": a kubelet restart or node reboot restarts its containers in place (the Pod object survives while the node comes back), and a static pod always does. What it never gets is **rescheduling**: if the node is gone for good, nothing recreates it elsewhere. When a node's Ready condition goes `False` the control plane taints it `node.kubernetes.io/not-ready`; when it goes `Unknown` (heartbeats lost) it taints it `node.kubernetes.io/unreachable`. The `DefaultTolerationSeconds` admission plugin gives **every** pod (naked ones too) a toleration of 300 s for both taints, so after roughly 5 minutes (plus the node-monitor grace period) the pods are evicted, i.e. deleted. A controller-managed pod is then recreated on another node; a naked pod is simply gone. A naked pod survives only if the node returns within that window. Tune `tolerationSeconds` per workload if you need faster failover.

---

### 4. Configuration: ConfigMaps & Secrets

Applications must adhere to 12-Factor principles: strict separation of config from code.

#### A. ConfigMap
Used for non-sensitive configuration parameters (URLs, ports, feature flags).
Can be consumed in two ways:
1. **Environment Variables (`envFrom` / `valueFrom`):** Injected at container start. Simple, but a snapshot: changing the ConfigMap never changes a running container's environment.
2. **Volume Mounts:** Mounted as files. The kubelet refreshes the files after the ConfigMap changes, but **not instantly**: the delay is up to one kubelet sync period (`syncFrequency`, 1 minute by default, plus jitter) plus the propagation delay of the kubelet's watch on the ConfigMap (default `configMapAndSecretChangeDetectionStrategy: Watch`; the TTL only matters for the `Cache` strategy). Expect roughly 60-90 s, even on a local cluster. The update is atomic: the mount is a `..data` symlink that the kubelet swaps to a new timestamped directory, so a reader never sees a half-written file. **The application must re-read the file** (or watch it with inotify); a process that loaded the file at startup keeps its old copy.

Gotchas, all demonstrated in the lab:
- **`subPath` mounts never update.** A `subPath` mount bind-mounts one file out of the volume instead of exposing the symlinked directory, so the kubelet cannot swap it. Mount the whole directory (or restart the pod) if you need reloads.
- **Reload by rollout:** for env vars, `subPath`, or apps that only read config at startup, change the pod template (e.g. a checksum annotation, which Helm charts do, or `kubectl rollout restart`) so the ReplicaSet rolls pods.
- **`immutable: true`** (ConfigMap and Secret): the data can never be edited, only deleted and recreated. It protects against a typo breaking every pod at once, and the kubelet stops watching the object (less apiserver load at scale). Pair it with versioned names (`app-config-v7`) and roll the Deployment to switch.
- ConfigMap and Secret size limit is 1 MiB; both are namespaced, and a pod can only reference one in its own namespace.

#### B. Secret
- Used for passwords, API keys, and TLS certificates.
- Stored as base64-encoded strings in YAML. **Crucial:** Base64 is an encoding, **not** encryption. Anyone with read access to the Secret can decode it (`base64 -d`).
- Production security requires enabling **Encryption at Rest** in the API server (`EncryptionConfiguration` with a KMS provider, e.g. AWS KMS) and strict RBAC controls; on managed clusters (EKS) this is a cluster option.
- When mounted as a volume, Secrets reside in a memory-backed `tmpfs` inside the node, ensuring sensitive data is never written to unencrypted node disk storage.

---

## Decision tree: Configuration Delivery

```
Is the configuration value sensitive (passwords, tokens, private keys)?
├── Yes ──► Secret
│           ├── Single token / small secret ──► env (or external secret operator)
│           └── Certificates / keys         ──► volume mount (tmpfs backed)
└── No  ──► ConfigMap
            ├── Static startup flags        ──► envFrom (snapshot at container start)
            └── Reloaded at runtime         ──► volume mount (directory, not subPath; app must re-read)
```

---

## Exercises

### Exercise 1 — The Reconciliation Mystery
You inspect a cluster and run:
```bash
kubectl get deployment order-api -n orderflow
```
Output shows `UP-TO-DATE: 3`, but `AVAILABLE: 2` and `READY: 2/3`.
What is the systematic sequence of `kubectl` commands to diagnose why the 3rd pod is not ready?

**Hint:** Start from the controller layer and work downward toward container logs. Note the symptom first: `UP-TO-DATE: 3` means three pods exist with the current template; `AVAILABLE: 2` means one has not been Ready for `minReadySeconds`, so that pod exists but is not Ready (a Pending or unschedulable pod would also show up here).

**Solution sketch:**
0. Controller layer: `kubectl rollout status deploy/order-api -n orderflow --timeout=30s` and `kubectl describe deploy order-api -n orderflow` (the `Conditions:` block shows `Available`/`Progressing` and any `ProgressDeadlineExceeded`).
1. Check pod status: `kubectl get pods -n orderflow -l app=order-api -o wide` (Identify which pod is Pending or Crashing).
2. Inspect events: `kubectl describe pod <failing-pod> -n orderflow` (Look at the `Events:` table at the bottom. Check for failed scheduling, image pull errors, probe failures, or OOMKilled events).
3. If container started and crashed: `kubectl logs <failing-pod> -n orderflow --previous` (Check why the previous container instance terminated). If it is Running but `0/1` Ready, the readiness probe is failing: compare `kubectl describe pod` (`Readiness probe failed: ...`) with what the endpoint really returns.
4. Confirm the effect on traffic: the pod's IP should be absent from `kubectl get endpointslices -n orderflow -l kubernetes.io/service-name=order-api`.

---

### Exercise 2 — ConfigMap Update Without Pod Restart
You have a ConfigMap mounted as a volume at `/etc/config/settings.json`. You update the ConfigMap in the cluster.
1. Does the file inside the running container update?
2. If you instead injected the ConfigMap value via `env:`, does the environment variable update in the running container?

**Hint:** Think about Linux process environment tables vs filesystem directory updates.

**Solution sketch:**
1. **Volume Mount:** **Yes, with a delay, and only for a whole-directory mount.** The kubelet's periodic sync swaps the `..data` symlink to a new directory (roughly 60-90 s: one kubelet sync period plus watch propagation). A `subPath` mount of the same file never updates. The app must also re-read the file.
2. **Environment Variable:** **No.** In Linux, a process's environment variables (`/proc/$$/environ`) are initialized when the `execve` syscall executes and cannot be modified externally by the parent OS. Changing the ConfigMap requires restarting or recreating the Pod to update environment variables.

---

### Exercise 3 — Orphaned Pods via Label Tampering
You have a Deployment with selector `app: order-api` managing 3 pods. You manually edit one running Pod using `kubectl edit pod` and change its label to `app: rogue-api`.
1. What does the ReplicaSet controller do immediately?
2. What happens to the pod with `app: rogue-api`?

**Hint:** Remember how ReplicaSet selectors work.

**Solution sketch:**
1. The ReplicaSet controller counts pods matching its selector. When you change the label, the pod no longer matches, so the controller **releases** it (removes the ownerReference) and the count drops from 3 to 2. It then creates a **new** 3rd pod to satisfy `replicas: 3`.
2. The modified pod is now **orphaned**: no owner, not part of any rollout or rollback, no longer behind the Service (its label no longer matches the Service selector either), and it keeps running until deleted by hand. If you set the label back, the ReplicaSet adopts it again and deletes a surplus pod.

---

## Anti-patterns / Common mistakes

1. **Deploying "Naked" Pods:** Creating `kind: Pod` directly without a controller. A kubelet restart or node reboot restarts the containers in place, but a pod is never *rescheduled*: if its node is lost, or the pod is deleted or evicted, nothing recreates it. No rollouts, no scaling, no self-healing.
2. **Mutable image tags (`:latest`, or re-pushing `:v1`):** The usual explanation ("K8s won't pull a new `:latest`") is wrong: for `:latest` the default `imagePullPolicy` is already `Always`. The real problems are: (a) the pod template is byte-identical, so **no rollout happens** when you push a new image under the same tag; (b) nothing pins what is running: pods created at different times can run different digests, and a node restart or reschedule silently pulls whatever the tag points to now; (c) `rollout undo` goes back to the same tag, i.e. possibly the same broken image. Use immutable version tags (or `image@sha256:...` digests), and let CI change the tag in the manifest.
3. **Omitting Resource Requests & Limits:** Without `resources.requests`, the scheduler cannot make informed bin-packing decisions, leading to node overloading and unpredictable evictions.
4. **Treating Kubernetes Secrets as "Encrypted":** Believing base64 encoding protects secrets. Without KMS envelope encryption and RBAC restriction, secrets are plain-text.
5. **Putting Everything in `default` Namespace:** Neglecting namespaces leads to resource naming collisions, inability to set `ResourceQuotas`, and chaotic RBAC policies.
6. **Baking config into images:** Different image per environment (or secrets in the image) defeats "build once, deploy everywhere", leaks credentials through image layers, and forces a rebuild for a one-line change. Inject config at runtime via ConfigMap/Secret.
7. **`kubectl run` / `kubectl create` for production workloads:** Imperative commands leave no reviewable manifest, no history, and (for `run`) create a naked pod. Keep manifests in git and `kubectl apply` them; use `kubectl run` only for throwaway debugging pods.
8. **Readiness and liveness on the same endpoint:** Readiness removes a pod from Service endpoints (do not send traffic); liveness restarts the container. A dependency blip that fails a shared probe turns into a restart storm. Use `/ready` and `/health` (as the lab does) and a `startupProbe` for slow starters.
9. **Treating `kubectl scale`/`set image` as the source of truth:** Live edits vanish on the next `kubectl apply -f`. Edit the file.
10. **Relying on a rollout to "fail safe":** A stuck rollout stays stuck (`ProgressDeadlineExceeded`); only your pipeline can undo it.

---

## Recall drill

Answer from memory first, then open the answers.

1. Which component is the only one that talks to etcd, and how do controllers learn about changes without polling?
2. You change only `replicas` in a Deployment. Does a new ReplicaSet appear? What about changing an env var?
3. A bad image tag with `maxUnavailable: 0`: what do users see, and what does `kubectl rollout status` do after the deadline?
4. `kubectl delete deploy x --cascade=orphan`: what happens to the ReplicaSets and Pods, and what happens when you re-apply the same manifest?
5. You relabel one pod of a 3-replica ReplicaSet to `app=debug`. How many pods run, and who owns the relabeled one?
6. Why does a ConfigMap-backed env var stay stale, and why does a `subPath` file stay stale while a plain volume file updates?
7. After `rollout undo`, why does `rollout history` show revision 4 where you expected 2?
8. Name two reasons `image: order-api:latest` is a bad idea that have nothing to do with `imagePullPolicy`.

<details>
<summary>Answers</summary>

1. The kube-apiserver. Controllers use informers: one LIST, then a long-lived WATCH feeding a local cache and work queue; reconcile reads the cache.
2. `replicas` does not change the pod template, so no new ReplicaSet and no rollout (the existing ReplicaSet is just rescaled). An env change alters the template hash: new ReplicaSet and a rolling update.
3. Users see nothing: the new pod never becomes Ready, `maxUnavailable: 0` keeps the old pods serving. After `progressDeadlineSeconds` the Deployment reports `ProgressDeadlineExceeded` and `rollout status` exits non-zero (or when `--timeout` fires first). No automatic rollback.
4. Only the Deployment object is deleted. The ReplicaSets lose their ownerReference to the Deployment (the Pods never referenced the Deployment; they still point at their ReplicaSet) and everything keeps running. Re-applying creates a new Deployment which adopts the ReplicaSet whose template matches; pods are not recreated.
5. Only two pods still match, so the ReplicaSet creates a replacement; four pods run in total. The relabeled pod has no owner (released), is out of the Service, and stays until deleted.
6. Env vars are fixed at container start. A plain volume is a symlinked directory the kubelet atomically swaps; a `subPath` is a bind mount of a single file, which cannot follow the swap.
7. Undo re-activates an old ReplicaSet under a new, higher revision number; the old number is consumed (history showed 1, 3, 4).
8. No rollout when the tag's content changes (template unchanged), and no pin: different pods/nodes may run different digests; rollbacks are not reproducible.

</details>

---

## Lab
See [`labs/day03/`](../labs/day03/).
- **The goal:** Handcraft declarative Kubernetes manifests for the OrderFlow microservices (probes, securityContext, resources), deploy them to the `orderflow` namespace, prove ownership and garbage collection (orphan and re-adopt a ReplicaSet), perform a rolling update (v1 to v2), trigger and recover from a stuck rollout, prove self-healing, tamper with labels, and compare ConfigMap env vs volume reload.
- **Success signal:** Deployments run 100% healthy, `rollout status` times out with `ProgressDeadlineExceeded` on the bad tag and `rollout undo` recovers, a deleted pod is replaced, and the ConfigMap volume file changes while the env var and the `subPath` file stay stale.

---

## Key commands reference

| Command | Purpose |
|:---|:---|
| `kubectl apply -f manifest.yaml` | Declaratively apply desired state to cluster |
| `kubectl get pods -n <ns> -o wide` | List pods with IP addresses and assigned nodes |
| `kubectl describe pod <name> -n <ns>` | Inspect pod events, container states, and failure reasons |
| `kubectl logs <name> -c <container> --previous` | Read logs from previous crashed instance of container |
| `kubectl rollout status deployment/<name> --timeout=60s` | Watch a rollout; exits non-zero on timeout or `ProgressDeadlineExceeded` |
| `kubectl rollout undo deployment/<name>` | Roll back to the previous revision (gets a new revision number) |
| `kubectl rollout history deployment/<name>` | List revisions (use `kubernetes.io/change-cause` for notes) |
| `kubectl scale deployment <name> --replicas=5` | Imperative, live-only replica change (re-apply the file to revert) |
| `kubectl delete deploy <name> --cascade=orphan` | Delete only the Deployment; keep its ReplicaSets and Pods |
| `kubectl get pods -o custom-columns=...` / `-o jsonpath=...` | Show owners, images, env without the whole YAML |

---

## Teardown
```bash
kubectl delete -f labs/day03/demo/cfg-demo.yaml --ignore-not-found
bash labs/shared/reset.sh
kubectl delete namespace orderflow --ignore-not-found
```
*(`reset.sh` deletes and recreates the empty namespace; the final delete removes it. Deleting the namespace terminates all Deployments, ReplicaSets, Pods, Services, ConfigMaps and Secrets created in this lab. Day 4 starts with `reset.sh` again.)*

# Docker & Kubernetes Engineering Glossary

A comprehensive, plain-English reference of essential container and cloud-native concepts. Every term provides a concise definition followed by practical context from real-world systems engineering.

---

## 1. Container Runtime Tier

**OCI (Open Container Initiative)**: An open governance industry standard specifying container image formats and runtime behaviors. Ensures that an image built with Docker can run seamlessly on containerd, CRI-O, or Podman.

**containerd**: An industry-standard core container runtime managing the complete container lifecycle—image transfer, execution, snapshotting, and network attachments. Originally built by Docker, it now serves as the default runtime underneath Kubernetes.

**runc**: The lightweight, CLI-based reference implementation of the OCI runtime specification. It interacts directly with the Linux kernel to create namespaces, mount cgroups, and execute containerized binaries.

**CRI (Container Runtime Interface)**: The gRPC plugin interface that allows the Kubernetes kubelet to communicate with various container runtimes without recompiling Kubernetes. containerd and CRI-O implement CRI.

**OCI Image Specification**: Standard format defining what constitutes a container image, consisting of layered tarballs, a configuration JSON (entrypoint, env vars), and a manifest linking them by SHA256 hashes.

**OCI Runtime Specification**: Standard specifying how an unpacked OCI image on disk must be executed as a container, including namespaces, resource limits, capabilities, and mount points.

**Docker Engine**: The complete developer-facing container platform consisting of the Docker CLI, the dockerd background daemon, an API layer, BuildKit, and the embedded containerd runtime.

**containerd-shim**: A minimal daemon process that sits between containerd and runc for each running container. Keeps container stdio pipes open and preserves the exit status even if the main containerd daemon restarts.

---

## 2. Linux Primitives Tier

**PID Namespace**: Linux kernel isolation primitive that provides a process with its own private process ID hierarchy. The container's primary process appears as PID 1 inside the container while appearing as a standard unprivileged PID on the host.

**Network Namespace (netns)**: Linux isolation primitive providing an independent network stack—including loopback interface, IP routing tables, firewall rules, and port bindings. Every Kubernetes Pod shares a single network namespace.

**Mount Namespace (mnt)**: Linux isolation primitive that isolates the file system mount points seen by a group of processes. Allows a container to see its own root filesystem (`/`) without seeing the host's underlying storage tree.

**UTS Namespace**: Linux isolation primitive that allows a container to define its own hostname and domain name independently from the host operating system.

**IPC Namespace**: Linux isolation primitive that isolates System V IPC mechanisms and POSIX message queues. Prevents processes in different containers from communicating via shared memory.

**cgroup Namespace / time Namespace**: The seventh and eighth namespace types. The cgroup namespace gives a container a virtualised view of the cgroup hierarchy (its own cgroup appears as `/`); the time namespace gives it its own boot/monotonic clock offsets. With mnt, pid, net, ipc, uts and user there are eight types.

**User Namespace**: Linux isolation primitive that maps UIDs and GIDs inside the container to different UIDs and GIDs on the host, so root inside can be an unprivileged UID outside. It is **not enabled by default** in Docker (it needs `userns-remap` or rootless mode) and Kubernetes pods use it only with `hostUsers: false`; otherwise container root is host root, limited only by capabilities, seccomp and LSMs.

**cgroups (Control Groups)**: Linux kernel mechanism for metering, limiting, and isolating physical resource consumption (CPU, memory, disk I/O, network bandwidth) across process hierarchies. Cgroups v2 provides a unified hierarchy used by modern container runtimes.

**OverlayFS**: A copy-on-write union filesystem that stacks multiple directories into a single unified mount point. Merges read-only image layers (`lowerdir`) with an ephemeral container read-write layer (`upperdir`).

**veth (Virtual Ethernet Pair)**: A virtual networking pipe connecting two isolated network namespaces. Traffic transmitted into one end of the veth pair emerges instantly on the peer interface in another namespace or Linux bridge.

**Linux Bridge**: A kernel-level software network switch (`docker0` or `cbr0`) that connects multiple veth pairs, enabling containers on the same host to exchange Ethernet frames.

**iptables / nftables**: The Linux kernel packet filtering and NAT subsystem. Powers Docker port publishing and, in the default iptables mode, kube-proxy's Service load balancing via DNAT rules. kube-proxy also has an `nftables` mode (GA in Kubernetes 1.33) and an `ipvs` mode (deprecated since 1.35).

---

## 3. Image & Build Tier

**Image Layer**: An immutable filesystem changeset representing the files added, modified, or deleted by a single Dockerfile instruction (`RUN`, `COPY`, `ADD`). Stored on disk as a content-addressable tarball.

**Image Manifest**: A JSON document detailing an image's architecture, layers (by cryptographic digest), and configuration blob. Client runtimes download the manifest first to determine which layers must be fetched.

**Container Registry**: A centralized server system (e.g. Docker Hub, Amazon ECR, GitHub Packages) that stores, indexes, and distributes versioned OCI image manifests and layer blobs over HTTPS.

**Image Tag**: A human-readable pointer assigned to an image manifest (e.g. `order-api:v1.2.0` or `latest`). Tags are mutable by default; a tag can be pointed to a new image digest at any time.

**Image Digest**: An immutable, cryptographically secure SHA256 hash uniquely identifying an image's manifest content (e.g. `@sha256:45b23d...`). Pulling by digest guarantees bit-for-bit repeatability.

**Multi-stage Build**: Dockerfile authoring pattern that utilizes multiple `FROM` instructions to isolate compilers, SDKs, and build tooling into temporary stages, copying only compiled runtime binaries into a minimal final production image.

**Build Context**: The local file directory tree sent to the Docker daemon or BuildKit engine at build time. Files omitted via `.dockerignore` are excluded from the context transfer.

**.dockerignore**: A configuration file defining pattern-based exclusions for the Docker build context. Prevents secrets, `.git` history, and local dependencies (e.g. `node_modules`, compiled binaries) from inflating build upload sizes.

**Distroless Image**: Ultra-minimal container images provided by Google that contain strictly an application and its runtime dependencies (e.g. glibc, CA certificates), omitting package managers, shells (`sh`, `bash`), and standard core utilities.

**Scratch Base Image**: An explicitly empty container image (`FROM scratch`) containing zero files. Ideal for statically compiled Go or Rust binaries that require no C runtime libraries or base filesystem.

---

## 4. Docker Networking Tier

**Bridge Network**: The default user-defined virtual network driver in Docker. Containers attached to the same user-defined bridge communicate with each other over private virtual Ethernet links with automated DNS name resolution.

**docker0**: The default Linux bridge created automatically by Docker Engine on host boot. Legacy containers attached to default `docker0` do not receive automated DNS name resolution.

**Embedded Docker DNS**: The built-in DNS server running at `127.0.0.11` within user-defined Docker networks. Intercepts DNS queries and resolves container names to private IP addresses.

**Port Mapping**: Instructs Docker Engine to configure host-level `iptables` DNAT rules that forward incoming traffic on a specific host interface port into a target container's private port.

**Overlay Network**: A multi-host virtual networking driver that encapsulates Layer 2 Ethernet frames inside Layer 4 UDP packets (VXLAN). Enables containers located on different physical VMs to communicate seamlessly as if on a single local subnet.

**VXLAN (Virtual Extensible LAN)**: Network virtualization technology utilizing UDP encapsulation to create scalable Layer 2 overlay networks across Layer 3 physical underlying networks.

---

## 5. Docker Storage Tier

**Named Volume**: A persistent storage directory managed by Docker (`/var/lib/docker/volumes/` on the engine host; on Docker Desktop that path is inside its Linux VM, not on the Mac). Survives container removal and is only deleted by `docker volume rm` or `docker compose down -v`.

**Bind Mount**: A direct mapping of an explicit file or directory on the host machine into a container's filesystem. Useful in local development for live hot-reloading of source code into containers.

**tmpfs Mount**: An ephemeral, memory-backed storage mount point inside the container. Written data never touches the host's non-volatile storage disk; purged immediately when the container terminates.

**Volume Driver**: A plugin enabling Docker to mount external network storage systems (such as AWS EBS, NFS, or Ceph) directly as container volumes.

---

## 6. Docker Compose Tier

**Compose Service**: A declarative definition of a computing workload in `docker-compose.yml`, specifying its build context or image, exposed ports, environment variables, healthchecks, and volume dependencies.

**Compose Profile**: A mechanism for grouping services conditionally (e.g. `profiles: ["debug"]`). Services assigned to a profile are not started by default unless explicitly invoked via `--profile`.

**Compose Override File**: A secondary Compose file (`docker-compose.override.yml`) that Docker Compose automatically merges with `docker-compose.yml`. Commonly used to inject local development volume bind mounts without dirtying Git.

**Compose Healthcheck**: A directive in a service definition that instructs Compose to periodically execute a test command inside the container to assess operational readiness before dependent services boot.

**depends_on (with conditions)**: Compose dependency directive specifying service boot ordering. When coupled with `condition: service_healthy`, Compose halts downstream container startups until upstream dependencies pass health checks.

**Compose Environment Precedence**: How the value of a variable *inside a container* is chosen, highest first: `docker compose run -e` > the service's `environment:` > `env_file:` > the image's `ENV`. The shell environment and the project `.env` file are different: they only feed `${VAR}` **interpolation** in the Compose file (shell beats `.env` beats `${VAR:-default}`), and a `.env` value reaches a container only if the service lists it in `environment:` or `env_file:`. Check the result with `docker compose config`.

---

## 7. Kubernetes Architecture Tier

**Control Plane**: The central brain of a Kubernetes cluster consisting of `kube-apiserver`, `etcd`, `kube-scheduler`, and `kube-controller-manager`. Manages desired state declarations and schedules workloads across worker nodes.

**API Server (kube-apiserver)**: The central REST entry point to the Kubernetes control plane. All tools (`kubectl`, controllers, kubelets) interact exclusively with the API server; it validates, mutates, and persists declarative state to `etcd`.

**etcd**: A distributed, strongly consistent key-value datastore using the Raft consensus algorithm. Functions as the single source of truth for all Kubernetes cluster state, configuration, and secrets.

**kube-scheduler**: Control plane component that watches for newly created Pods with no assigned node, evaluates node constraints (resource requests, taints, affinity), and binds each Pod to the most optimal worker node.

**kube-controller-manager**: Control plane daemon that runs core Kubernetes reconciliation loops (DeploymentController, NodeController, EndpointSliceController), continuously reconciling observed state with declared state.

**kubelet**: The primary node-level agent running on every worker node. Watches the API server for Pods assigned to its node, instructs the container runtime via CRI to create or delete containers, and reports node health.

**kube-proxy**: Node-level network daemon that watches Services and EndpointSlices on the API server and programs the node's dataplane (`iptables` by default, or `nftables`, or the deprecated `ipvs`) to load balance virtual ClusterIP traffic to Pod IPs. It balances per TCP connection (conntrack), which is why a long-lived gRPC connection sticks to one pod.

---

## 8. Kubernetes Workloads Tier

**Pod**: The smallest deployable computing unit in Kubernetes. Represents a group of one or more co-located containers sharing a network namespace (localhost), IPC, and storage volumes.

**ReplicaSet**: A low-level workload controller that guarantees a specified count of identical Pod replicas matching a label selector are running at any given moment.

**Deployment**: A higher-level declarative controller that manages declarative rollout updates and rollbacks of ReplicaSets and Pods without service downtime.

**DaemonSet**: A workload controller that ensures an instance of a Pod runs on every matching node in the cluster. Standard choice for node-level agents such as log collectors (`fluentbit`) or monitoring daemons (`node-exporter`).

**StatefulSet**: A workload controller designed for stateful applications requiring stable network identities (`pod-0.service`), ordered graceful deployments/terminations, and persistent per-pod storage mappings (`volumeClaimTemplates`).

**Job**: A batch workload controller that runs one or more Pods until a specified number of successful completions (exit code 0) is achieved, then terminates.

**CronJob**: A controller that schedules and runs Kubernetes Jobs periodically according to a standard cron syntax expression.

**Pause Container**: An ultra-minimal container deployed automatically inside every Kubernetes Pod that reserves and holds open the shared Linux network namespace while application containers boot and restart.

---

## 9. Kubernetes Configuration Tier

**ConfigMap**: An API object used to store non-confidential configuration data as key-value pairs or complete configuration files. Injected into containers as environment variables, command-line arguments, or mounted volume files.

**Secret**: An API object used to hold sensitive data (passwords, tokens, TLS certificates) stored as base64-encoded strings. Can be mounted as files or environment variables; should be encrypted at rest via cluster EncryptionConfiguration.

**Environment Variable Injection**: The process of mapping ConfigMap or Secret keys directly into container process environment variables via `env:` or `envFrom:` directives.

**Volume Mount Injection**: Projecting ConfigMap or Secret keys as files in a container directory. A whole-directory mount is updated by the kubelet after a delay (roughly a minute or two, via an atomic symlink swap), but the application must re-read the file; a `subPath` mount of a single file is **never** updated, and environment variables are fixed at container start.

---

## 10. Kubernetes Networking Tier

**Service**: An abstract REST object defining a logical set of Pods and a policy to access them. Provides a stable virtual IP address (ClusterIP) and DNS name that survives individual Pod terminations.

**ClusterIP**: The default Kubernetes Service type. Allocates an internal virtual IP accessible only from within the cluster, load-balanced across matching Pods by `kube-proxy`.

**NodePort**: A Service type that exposes the service on an identical static port (range 30000–32767) across the external IP of every node in the cluster.

**LoadBalancer**: A Service type that automatically provisions a cloud provider's native external load balancer (e.g. AWS NLB, GCP Network LB) routing traffic into a NodePort/ClusterIP service.

**ExternalName**: A Service type that maps a Kubernetes internal DNS name directly to an external CNAME DNS record (e.g. `db.rds.amazonaws.com`) without proxying network traffic.

**Endpoints / EndpointSlice**: API objects that list the Pod IPs and ports behind a Service. **EndpointSlice** (up to 100 endpoints per object, with per-endpoint `ready`/`serving`/`terminating` conditions) is the current API; the older `Endpoints` object is deprecated since 1.33. The EndpointSlice controller (in kube-controller-manager) maintains them, and kube-proxy and gateway data planes consume them.

**Ingress**: An API object that defines Layer 7 HTTP/HTTPS routing rules (hostnames, paths, SSL/TLS termination) for exposing cluster services to external traffic.

**IngressClass**: A cluster resource associating Ingress objects with a controller implementation (e.g. `nginx`, `alb`). Note that the community ingress-nginx project was retired in March 2026; new designs should use the Gateway API.

**CNI (Container Network Interface)**: The standardized plugin specification governing how network interfaces are provisioned and IP addresses allocated for Pods. Popular implementations include Calico, Cilium, and AWS VPC CNI.

**CoreDNS**: The default cluster-internal DNS server running in Kubernetes. Resolves service names (`service.namespace.svc.cluster.local`) and headless service pod records.

**NetworkPolicy**: An API object that configures Layer 3 and Layer 4 allow-rules between Pods, namespaces and CIDR blocks. It is **enforced by the CNI, not the API server**: an enforcing CNI (kindnet on the Docker Desktop kind provisioner, Calico, Cilium) blocks traffic; the Docker Desktop kubeadm provisioner accepts the objects and ignores them. Policies are additive (a union of allows), a pod is isolated for a direction only if a policy selects it for that direction, and egress default-deny also blocks DNS unless you allow it.

**Gateway API**: The role-oriented, typed successor to Ingress (see **Gateway API kinds** below). Routing, weights, header matches and filters are in the spec instead of controller annotations; advanced policy (rate limit, auth, retries) is still implementation-specific. Envoy Gateway is the implementation used in this course.

**Gateway API kinds**: `GatewayClass` (which controller implements Gateways; owned by the infrastructure provider), `Gateway` (listeners: port, protocol, TLS, and `allowedRoutes` that say which namespaces may attach routes; owned by the platform team), `HTTPRoute` / `GRPCRoute` (matches on path, header, method or gRPC service, plus `backendRefs` with weights and filters; owned by app teams, attached with `parentRefs`), and `ReferenceGrant` (lets a route or listener reference a Service or Secret in another namespace). The most specific match wins, not the first rule; route status conditions (`Accepted`, `ResolvedRefs`) tell you why an attachment failed.

**Envoy Gateway / xDS**: Envoy Gateway is a controller that turns Gateway API objects into Envoy proxy deployments (in `envoy-gateway-system`). Envoy is configured dynamically over the xDS APIs (listeners, routes, clusters, endpoints, secrets) without reloads.

**Panic Routing**: Envoy behaviour when too few endpoints of a backend are healthy: below the panic threshold (default 50% healthy) it ignores health status and spreads traffic over all endpoints rather than concentrating it on the few healthy ones. Observed on Envoy Gateway: when *all* endpoints of a backend are not ready, traffic is still sent to them, and as soon as one pod becomes ready traffic moves to it; only a backend with **no** endpoints at all (empty EndpointSlice) gets an immediate `503`. Keep at least 2 replicas so one unready pod does not trigger it.

**Service Mesh**: An infrastructure layer that applies gateway-style features between services (east-west): mTLS with workload identity, retries, timeouts, circuit breaking, traffic splitting and per-hop telemetry, without application code changes. Sidecar meshes run a proxy per pod; ambient/sidecarless designs use a per-node L4 agent and optional per-namespace L7 waypoint proxies. Adopt one for many teams and uniform mTLS, not for five services.

**mTLS (mutual TLS)**: TLS in which both sides present certificates, so each peer authenticates the other and traffic is encrypted. In a mesh each workload gets a short-lived certificate whose identity (a SPIFFE ID such as `spiffe://cluster.local/ns/orderflow/sa/order-api`) derives from its ServiceAccount; authorization policies then say which identity may call what.

---

## 11. Kubernetes Storage Tier

**PersistentVolume (PV)**: A piece of cluster-wide storage provisioned by an administrator or dynamically created by a StorageClass. Possesses a lifecycle independent of any individual Pod that uses it.

**PersistentVolumeClaim (PVC)**: A user's request for storage, specifying size, access modes, and optional StorageClass. When matched, Kubernetes binds the PVC to a suitable PersistentVolume.

**StorageClass**: An API object that defines dynamic volume provisioning parameters and the CSI provisioner plugin (e.g. `ebs.csi.aws.com`).

**CSI (Container Storage Interface)**: An industry-standard interface that allows storage vendors to develop out-of-tree plugins for volume provisioning, attaching, and mounting in Kubernetes.

**RWO (ReadWriteOnce)**: A PersistentVolume access mode allowing the volume to be mounted as read-write by Pods located on a single cluster node only (standard for AWS EBS).

**ROX (ReadOnlyMany)**: A PersistentVolume access mode allowing the volume to be mounted read-only by multiple Pods running across different cluster nodes simultaneously.

**RWX (ReadWriteMany)**: A PersistentVolume access mode allowing the volume to be mounted as read-write simultaneously by multiple Pods running on different nodes (standard for NFS or AWS EFS).

**Reclaim Policy**: Configuration on a PersistentVolume determining what happens to underlying disk data when its bound PVC is deleted: `Retain` (preserves disk for manual recovery) or `Delete` (deletes storage asset immediately).

---

## 12. Kubernetes Security & RBAC Tier

**RBAC (Role-Based Access Control)**: Security authorization mechanism regulating access to Kubernetes API resources based on the roles assigned to users, groups, and ServiceAccounts.

**Role**: A namespace-scoped RBAC object that defines a set of permissions (API groups, resources, and allowed verbs such as `get`, `list`, `watch`).

**ClusterRole**: A cluster-scoped RBAC object that defines permissions across all namespaces or over cluster-level resources (such as `Nodes`, `Namespaces`, and `PersistentVolumes`).

**RoleBinding**: An RBAC object that grants permissions defined in a Role (or ClusterRole) to subjects (users, groups, ServiceAccounts) within a specific namespace.

**ClusterRoleBinding**: An RBAC object that grants permissions defined in a ClusterRole to subjects across all namespaces in the entire cluster.

**ServiceAccount**: An identity created within Kubernetes that pods use to authenticate against the Kubernetes API server when executing programmatic requests.

**SecurityContext**: PodSpec configuration defining operating system privilege and access control settings for a Pod or container (e.g. `runAsNonRoot`, `readOnlyRootFilesystem`, `capabilities.drop`).

**Pod Security Admission (PSA)**: Built-in admission controller (stable since 1.25) that checks **pod specs** against the Pod Security Standards, configured by namespace labels `pod-security.kubernetes.io/<mode>=<level>`. Modes: `enforce` (reject), `warn` (client warning), `audit` (audit-log annotation). A namespace with no label is `privileged` (nothing enforced). It does not mutate pods, acts at pod creation (failures show in ReplicaSet/StatefulSet events, not at `apply`), and `readOnlyRootFilesystem` is not checked at any level. Preview with `kubectl label --dry-run=server`.

**Pod Security Standards (PSS)**: The three cumulative profiles PSA applies: **privileged** (unrestricted), **baseline** (blocks known escalations such as hostPath, hostNetwork, privileged, extra capabilities) and **restricted** (baseline plus `runAsNonRoot`, `allowPrivilegeEscalation: false`, seccomp `RuntimeDefault`/`Localhost`, `capabilities.drop: [ALL]`, safe volume types).

**seccomp (Secure Computing Mode)**: A Linux kernel security facility that restricts the system calls a container process can make. `RuntimeDefault` is the recommended production baseline.

---

## 13. Kubernetes Architectural Patterns Tier

**Sidecar Pattern**: An auxiliary container in the same Pod as the application, sharing localhost and volumes (log shipping, proxying, mesh data plane). Since Kubernetes 1.33 the proper form is a **native sidecar** (see below).

**Native Sidecar**: An entry in `initContainers` with `restartPolicy: Always` (GA in 1.33). It starts before the app containers and keeps running, is restarted if it exits, and is stopped *after* the app containers, fixing the start/stop ordering problems of regular sidecars. Its resource requests count toward the Pod total (and HPA CPU utilisation).

**Init Container**: A specialized container running sequentially to completion before any application containers boot. Used for dependency validation, schema migrations, and configuration retrieval.

**Ambassador Pattern**: A co-located container within the same Pod that proxies and simplifies outbound connections from the application to complex external systems (e.g. cloud SQL proxies, Redis clusters).

**Adapter Pattern**: A container located in the Pod that intercepts and normalizes heterogeneous application outputs (metrics, log formats) to conform to centralized enterprise interfaces.

---

## 14. Kubernetes Reliability & Operations Tier

**Liveness Probe**: Probe that decides whether the process is stuck beyond recovery. On failure the kubelet restarts the container (SIGTERM, grace period, SIGKILL). Never include external dependencies, or a dependency outage restarts every pod at once.

**Readiness Probe**: Probe that decides whether a container should receive traffic now. On failure the kubelet marks the Pod not Ready, the EndpointSlice controller sets the endpoint `ready: false` (the Pod is removed from rotation), and the container is **not** restarted. Rolling updates also wait for it. Keep it separate from liveness and put dependency checks here, not in liveness.

**Startup Probe**: Healthcheck probe that verifies whether a slow-starting application has completed its initial initialization. Disables liveness and readiness evaluations until it succeeds.

**Horizontal Pod Autoscaler (HPA)**: Controller that automatically scales the replica count of a Deployment or StatefulSet based on observed CPU/memory utilization or custom Prometheus metrics.

**Vertical Pod Autoscaler (VPA)**: Controller that automatically analyzes real-world workload resource usage and adjusts container CPU/memory requests and limits over time.

**PodDisruptionBudget (PDB)**: Policy limiting **voluntary** disruptions (evictions through the Eviction API: `kubectl drain`, node upgrades, autoscalers) with `minAvailable` or `maxUnavailable`. It does not protect against involuntary loss (node crash, OOM kill, `kubectl delete pod`) and never creates replicas; a budget allowing zero disruptions blocks node drains. `unhealthyPodEvictionPolicy: AlwaysAllow` keeps unready pods from stalling a drain.

**Graceful Shutdown**: What happens when a Pod is deleted: it becomes `Terminating`, and **in parallel** (a) the EndpointSlice controller removes it from Services and the change propagates to kube-proxy and gateway data planes, while (b) the kubelet runs the `preStop` hook and then sends `SIGTERM`. After `terminationGracePeriodSeconds` (counted from the start, **including** preStop time) it sends `SIGKILL`. Because (a) is slower than (b), an app that stops accepting at once can drop requests during a healthy rollout (the endpoint-propagation race); fix with a preStop sleep and/or an app-level drain. Rule: grace period ≥ preStop + drain delay + shutdown timeout + margin.

**preStop Hook**: Lifecycle hook the kubelet runs **before** it sends `SIGTERM`; its duration counts against the grace period. The built-in `sleep` action (`lifecycle.preStop.sleep.seconds`, GA in 1.34) works in distroless images, unlike `exec: ["sleep", ...]`. Used to let endpoint removal propagate before the app stops accepting.

**terminationGracePeriodSeconds**: Total time (default 30 s) the kubelet allows from the start of termination for the `preStop` hook **plus** the container's shutdown after `SIGTERM`, before `SIGKILL` (exit 137). Must exceed preStop + drain delay + the app's own shutdown timeout. Never 0.

**QoS (Quality of Service) Class**: Class Kubernetes assigns from requests and limits: **Guaranteed** (every container has CPU *and* memory requests equal to limits), **Burstable** (at least one request or limit set, but not Guaranteed), **BestEffort** (nothing set). It determines eviction order under node memory pressure (BestEffort first, Guaranteed last).

---

## 15. Kubernetes Debugging Tier

**CrashLoopBackOff**: State indicating that a container repeatedly starts, encounters a fatal error or panic, exits, and is restarted by the kubelet with an exponentially increasing back-off delay.

**ImagePullBackOff**: State indicating that the kubelet attempted and failed to retrieve a container image from a registry, backing off exponentially between subsequent retry attempts.

**OOMKilled**: The kernel cgroup memory controller killed the container with SIGKILL because it exceeded `limits.memory` (exit code 137, `Last State: OOMKilled`). There is no Kubernetes event and no application log line; the kernel message is in the node's `dmesg`. Exceeding a CPU limit only throttles.

**Pending (Pod State)**: Pod phase meaning the Pod is accepted but its containers are not running yet. With `<none>` in the NODE column it is unscheduled (`FailedScheduling` event: insufficient CPU/memory *requests*, node selector or affinity, untolerated taint, unbound PVC). After scheduling it can stay Pending/`ContainerCreating` while images are pulled or volumes mount.

**Evicted (Pod State)**: Status of a Pod the kubelet terminated because of node pressure (disk, memory, PID); it remains as `Failed` until cleaned up. Not the same as `kubectl drain`, which uses the Eviction API (honouring PDBs) and leaves no `Evicted` pods.

**CreateContainerConfigError**: The kubelet cannot build the container's configuration, typically a referenced ConfigMap/Secret or key that does not exist. The container never started (RESTARTS 0); the kubelet retries by itself once the reference exists. Do not confuse with `StartError`/`RunContainerError` (exit 128): the runtime could not exec the process and there are no logs.

**Ephemeral Container**: A temporary container added to a running Pod with `kubectl debug --image=<img> --target=<container>`; it shares the pod's network namespace (and, with `--target`, the process namespace) and labels, so it is subject to the same NetworkPolicy. It is the way to debug distroless images. It cannot be removed (recreate the pod) and the pod's `securityContext` applies, which is why `tcpdump` fails in a non-root pod.

---

## 16. Cloud-Native Ecosystem Tier

**Helm**: The package manager for Kubernetes: charts (templates + `values.yaml`) install as versioned releases with a revision history (`helm history`, `helm rollback` creates a new revision). Helm 4 (current) applies with server-side apply by default, waits with kstatus, and renames `--atomic` to `--rollback-on-failure` and `--force` to `--force-replace`. Hooks (`helm.sh/hook`) run Jobs at lifecycle points such as `pre-upgrade`.

**Server-Side Apply (SSA)**: Applying objects with the API server tracking which field manager owns each field (`kubectl apply --server-side`, Helm 4 default for new installs). Conflicts between managers (Helm vs an HPA on `replicas`, Helm vs `kubectl edit`) surface as explicit conflicts instead of silent overwrites.

**Kustomize**: A template-free configuration customization engine built natively into `kubectl` that uses overlay layers to patch base YAML manifests across different environments.

**ArgoCD**: A declarative, GitOps-based continuous delivery controller for Kubernetes that continuously monitors Git repositories and reconciles drift in target clusters.

**Flux**: A set of open and flexible continuous and progressive delivery solutions for Kubernetes built natively on the GitOps Toolkit.

**GitOps**: An operational framework where declarative infrastructure and application manifests stored in Git serve as the single source of truth for automated deployment and reconciliation.

**metrics-server**: A lightweight, scalable cluster metrics aggregator that collects resource usage metrics from kubelets and exposes them through the Kubernetes Metrics API.

**Prometheus**: An open-source systems monitoring and alerting toolkit built around a multi-dimensional time-series data model and a powerful query language (PromQL).

**EFK Stack**: An enterprise logging architecture combining Elasticsearch (indexing/search), Fluentd or Fluentbit (node log aggregation), and Kibana (visualization).

---

## 17. EKS Production Tier

**Managed Node Group**: An Amazon EKS feature that automates the provisioning, lifecycle management, and security updates of Amazon EC2 worker nodes for EKS clusters.

**EKS Fargate Profile**: Declares which Pods run on AWS Fargate serverless capacity without EC2 nodes. Limits: no DaemonSets, no privileged pods, no EBS volumes; prefer Auto Mode or Karpenter when you just want "no node management".

**IRSA (IAM Roles for Service Accounts)**: Maps an IAM role to a ServiceAccount through the cluster's OIDC issuer: the role's trust policy federates the OIDC provider with a condition on the ServiceAccount, the ServiceAccount carries an `eks.amazonaws.com/role-arn` annotation, and the SDK calls `sts:AssumeRoleWithWebIdentity` (env `AWS_ROLE_ARN`, `AWS_WEB_IDENTITY_TOKEN_FILE`). Still right for Fargate, legacy SDKs and clusters outside EKS; **EKS Pod Identity** is the default choice on EKS.

**EKS Pod Identity**: The default way to give EKS pods AWS credentials. The `eks-pod-identity-agent` add-on runs on each node; you create a Pod Identity **association** (cluster + namespace + ServiceAccount → IAM role) and the role trusts the service principal `pods.eks.amazonaws.com`. No OIDC provider and no ServiceAccount annotation; pods get `AWS_CONTAINER_CREDENTIALS_FULL_URI`. Associations can name a `targetRoleARN` for cross-account access.

**EKS Auto Mode**: An EKS mode where AWS operates the nodes and core components (compute scaling, load balancing, block storage, DNS, networking); Karpenter is the engine inside it. You trade control over nodes for less operations work.

**Karpenter**: An open-source node provisioner that launches right-sized instances directly from the requirements of pending pods (instance diversity, Spot, consolidation) instead of fixed node groups. It needs accurate resource requests. Runs inside Auto Mode or installed on its own.

**AWS Load Balancer Controller**: An in-cluster controller that provisions and configures AWS Application Load Balancers (ALBs) for Ingress resources and Network Load Balancers (NLBs) for Services.

**EBS CSI Driver**: The Container Storage Interface plugin that allows Amazon EKS clusters to dynamically provision and attach Amazon EBS persistent block storage volumes to Kubernetes Pods.

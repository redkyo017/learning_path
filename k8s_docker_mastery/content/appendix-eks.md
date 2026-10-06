# Appendix: Amazon EKS Production Experience

> Optional and billable. Written for October 2026 (Kubernetes 1.36/1.37 on EKS, Helm 4, AWS Load Balancer Controller v3.x, EKS Pod Identity). Versions move: the lab README tells you where to look up the current one instead of trusting a number printed here.

## Why this matters

Local Kubernetes (Docker Desktop / kind) teaches the API abstractions. On EKS the same manifests meet AWS infrastructure, and four things are different enough to be worth one paid afternoon:
- **Identity.** A pod must call AWS APIs without long-lived keys: **EKS Pod Identity** (default choice) or **IRSA** (alternative).
- **Storage.** A PVC becomes an EBS volume in one Availability Zone, created by the **EBS CSI driver**.
- **Ingress.** An `Ingress` becomes a real Application Load Balancer created by the **AWS Load Balancer Controller** (or the Auto Mode equivalent).
- **Compute and cost.** Managed node groups, Fargate, **EKS Auto Mode**, **Karpenter**, and a bill that runs while you sleep.

The deliverable of this appendix is the same OrderFlow Helm chart from Day 6, installed with one overlay file (`values-eks.yaml`), plus a teardown that provably leaves nothing behind.

---

## Core concepts

### 1. Cluster architecture and node strategies

AWS runs the control plane (`kube-apiserver`, `etcd`, controllers) across several AZs (about $0.10/h per cluster). You choose how worker capacity is provided:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                      AWS-managed control plane  ($0.10/h)                    │
└──────────────────────────────────────┬───────────────────────────────────────┘
        ┌──────────────────────────────┼──────────────────────────────┐
        ▼                              ▼                              ▼
┌────────────────────┐   ┌────────────────────────────┐   ┌────────────────────────┐
│ Managed node group │   │ EKS Auto Mode              │   │ Fargate profile        │
│ you pick instances │   │ AWS runs nodes + core      │   │ one microVM per pod    │
│ (ASG), you patch   │   │ add-ons; Karpenter-based   │   │ no DaemonSets, no EBS  │
│ AMIs by rolling    │   │ (managed Karpenter)        │   │ (EFS only)             │
└────────────────────┘   └────────────────────────────┘   └────────────────────────┘
        Karpenter (self-managed) can replace the node-group autoscaler on a standard cluster.
```

| Requirement | Managed node group (EC2) | EKS Auto Mode | Fargate |
|:---|:---|:---|:---|
| Who manages nodes, AMI patching | You (rolling update) | AWS (nodes are replaced at most every 21 days) | AWS (no nodes) |
| DaemonSets (log agents, node-exporter) | Yes | Yes | No (use sidecars) |
| Persistent volumes | EBS gp3 (CSI add-on) | EBS (built in, CSI provisioner `ebs.csi.eks.amazonaws.com`) | EFS only |
| GPU, custom AMI, Spot tuning | Full control | Limited to what NodeClass/NodePool expose | No GPU |
| Scaling | Cluster Autoscaler or Karpenter you install | Built in (Karpenter semantics) | Per pod, automatic |
| Pod start latency | seconds (image cached) | seconds to a minute (node may be provisioned) | 30-60 s (microVM) |
| Extra cost | none | management fee on top of the EC2 price (per-instance, percentage) | pay per pod vCPU/GB, usually more per unit |
| Use it when | you need control, or learn the layers (this lab) | most new clusters: less to operate | rare: strict per-pod isolation or bursty tiny jobs; **not** a default recommendation |

Fargate is over-recommended in older material. It cannot run DaemonSets, privileged pods or EBS volumes, and each pod pays a startup penalty. Prefer Auto Mode (or Karpenter) when you want "no node management".

### 2. Cluster creation with `eksctl`

`eksctl` turns a `ClusterConfig` into CloudFormation stacks (VPC, subnets, NAT, control plane, node group, add-ons). The lab file is `labs/eks/cluster.yaml`:

```yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: orderflow-eks
  region: us-east-1
  version: "1.36"            # check: aws eks describe-cluster-versions --default-only
vpc:
  nat:
    gateway: Single          # one NAT gateway: ~$0.045/h. Default HighlyAvailable = one per AZ, 3x the cost
addons:
  - name: vpc-cni
  - name: coredns
  - name: kube-proxy
  - name: eks-pod-identity-agent
  - name: aws-ebs-csi-driver
    podIdentityAssociations:
      - serviceAccountName: ebs-csi-controller-sa
        namespace: kube-system
        permissionPolicyARNs: [arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy]
managedNodeGroups:
  - name: ng-arm64
    instanceType: t4g.medium  # Graviton, arm64
    desiredCapacity: 2
    privateNetworking: true
```
Decisions encoded here:
- **Version.** A standard-support version, looked up rather than copied: Kubernetes versions leave support after about 14 months, and a version in extended support can still be created but costs about $0.60/h per cluster instead of $0.10, and 1.30 and older cannot be created (the oldest creatable is 1.31, whose extended support ends 2026-11-26). EKS 1.37 became available on 2026-10-01; this lab keeps `1.36`, which is fine, but the README has you compare with the current default.
- **Architecture.** `t4g` is Graviton (arm64), so an image built on an Apple Silicon Mac runs unchanged. Intel/AMD nodes (`t3`, `m6i`...) need `docker buildx build --platform linux/amd64`. A mismatch shows as `exec format error`. Multi-arch (`--platform linux/amd64,linux/arm64`) removes the question.
- **One NAT gateway** is a lab economy: if its AZ fails, private nodes lose egress. Production keeps one per AZ.
- **No `iam.withOIDC`.** Pod Identity does not need an OIDC provider.

### 3. Pod identity: EKS Pod Identity first, IRSA second

**Anti-pattern: node-instance-role permissions.** Any pod on the node can reach the instance metadata service and inherit the node role. Give the node role only what nodes need (pull images, join the cluster); give workloads their own identity.

**EKS Pod Identity (default).**
1. The `eks-pod-identity-agent` add-on runs a DaemonSet that serves credentials on a link-local address (`169.254.170.23`).
2. You create an IAM role whose **trust policy** trusts the service `pods.eks.amazonaws.com` (actions `sts:AssumeRole`, `sts:TagSession`). The policy contains no cluster identifier, so one role can be reused across clusters.
3. You create a **Pod Identity association**: cluster + namespace + ServiceAccount name → role ARN (`aws eks create-pod-identity-association`, or `podIdentityAssociations` in eksctl).
4. When a pod using that ServiceAccount is **created**, EKS injects `AWS_CONTAINER_CREDENTIALS_FULL_URI` and `AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE`. The AWS SDK's default credential chain (container credentials provider) picks them up: no code change, no ServiceAccount annotation.
5. Changing the association later is an AWS API call, not a Kubernetes change; existing pods must be restarted to pick up a new association.

**IRSA (IAM Roles for Service Accounts), the alternative.** The cluster has an OIDC issuer; you register it as an IAM OIDC provider; the role's trust policy federates that provider with a condition on `<issuer>:sub = system:serviceaccount:<ns>:<sa>`; you annotate the ServiceAccount with `eks.amazonaws.com/role-arn`. The EKS **pod identity webhook** (its name predates Pod Identity; it now also injects the Pod Identity variables) injects `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE` plus a projected token, and the SDK calls `sts:AssumeRoleWithWebIdentity`.

| | EKS Pod Identity | IRSA |
|:---|:---|:---|
| Setup | add-on + association (API call) | OIDC provider + trust policy per cluster/SA + annotation |
| Trust policy | one generic policy (`pods.eks.amazonaws.com`) | contains the cluster's OIDC issuer; edit per cluster |
| Role reuse across clusters | Yes, as is | No (trust policy per issuer) |
| Role session tags (cluster, namespace, pod) for ABAC | Yes, added automatically | No |
| Runs on Fargate | **No** | Yes |
| Cross-account | Yes: `targetRoleARN` on the association (`--target-role-arn`; EKS chains the roles) | Direct federation per account |
| Works outside EKS (EKS Anywhere, self-managed) | No (EKS only) | Yes |
| Per-cluster IAM limits | none of the OIDC provider count limits | provider count and trust-policy size limits |
| Use it for | **new workloads on EC2 / Auto Mode nodes** | Fargate pods, legacy workloads/SDKs without Pod Identity support, clusters outside EKS |

Verifying either: run `aws sts get-caller-identity` in a pod that uses the ServiceAccount (lab Step 8). The ARN must be an `assumed-role/<your role>` ARN, not the node role.

### 4. AWS Load Balancer Controller (ALB / NLB)

The controller watches `Ingress` objects whose `ingressClassName` is `alb` (and `Service` of type `LoadBalancer` for NLB) and creates **ALBs, listeners, rules, target groups and security groups**. **It is not installed by EKS** (except in Auto Mode): you install it, and it needs its own AWS permissions (the IAM policy from the **same release** of the controller repository, `docs/install/iam_policy.json`) delivered by Pod Identity:

```
IAM policy (iam_policy.json of the pinned release)
   → role orderflow-lbc-role (trust: pods.eks.amazonaws.com)
   → association  kube-system / aws-load-balancer-controller → role
   → helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system
        --set clusterName=... --set serviceAccount.create=true --set serviceAccount.name=aws-load-balancer-controller
        --set region=... --set vpcId=...
```
Chart repository: `helm repo add eks https://aws.github.io/eks-charts`.

How OrderFlow uses it: the chart already has an optional Ingress (`ingress.*` values). The overlay `labs/day06/orderflow-chart/values-eks.yaml` sets, in values (not in `--set` flags: annotation keys contain dots and slashes that `--set` mangles):

| Key | Value | Why |
|:---|:---|:---|
| `ingress.className` | `alb` | `spec.ingressClassName`. The old `kubernetes.io/ingress.class` annotation is deprecated |
| `ingress.paths[].pathType` | `Prefix` | ALB supports `Prefix`/`Exact`; nginx-style regex paths do not exist here |
| `alb.ingress.kubernetes.io/scheme` | `internet-facing` | default is `internal`: no public DNS name |
| `alb.ingress.kubernetes.io/target-type` | `ip` | ALB sends to **pod IPs** (VPC CNI): no NodePort hop, no `kube-proxy` in the path |
| `alb.ingress.kubernetes.io/healthcheck-path` | `/ready` | target health follows readiness: a draining pod (503) leaves rotation |
| `gateway.enabled` | `false` | the Envoy Gateway `HTTPRoute` is a local-cluster choice; one edge per cluster |

HTTPS is the same Ingress plus `listen-ports: '[{"HTTP":80},{"HTTPS":443}]'` and `alb.ingress.kubernetes.io/certificate-arn` (an ACM certificate) and a host. Public subnets need the tag `kubernetes.io/role/elb=1` for discovery (eksctl sets it).

### 5. Amazon EBS CSI driver and the gp3 default

In-tree EBS provisioning is gone: you need the **EBS CSI driver** (an EKS add-on) *and* AWS permissions for its controller ServiceAccount (`ebs-csi-controller-sa`): in this lab a Pod Identity association with `AmazonEBSCSIDriverPolicy`, created by eksctl from the `addons[].podIdentityAssociations` block. The cluster needs a **default** StorageClass: without one, a PVC with no `storageClassName` (the chart's Postgres PVC) stays Pending. Since EKS 1.30 new clusters have no default class (the add-on can create one: `defaultStorageClass.enabled` in its configuration), and an old `gp2` class, if present, still works through CSI migration. This lab defines `gp3` as the default:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer     # create the volume in the AZ the pod is scheduled to
allowVolumeExpansion: true
parameters: {type: gp3, encrypted: "true"}
```
(`labs/eks/storageclass-gp3.yaml`; on a cluster older than 1.30 also unset the `is-default-class` annotation on `gp2`: a harmless no-op on newer ones.) An EBS volume lives in **one AZ**: a pod that needs it can only run there. A StatefulSet's PVC is not deleted by `helm uninstall`, and with `reclaimPolicy: Delete` the EBS volume goes when the PVC does: delete the PVC while the CSI driver still runs.

### 6. Pod Security still applies

EKS enforces nothing by default, but the chart from Day 6 is written for `restricted`. Label the namespace as locally (`pod-security.kubernetes.io/enforce=restricted`): the same pods are admitted, which is the point of testing under `restricted` early. System namespaces (`kube-system`) are where the privileged add-ons (`aws-node`, EBS CSI node) live.

### 7. EKS Auto Mode and Karpenter

**EKS Auto Mode** (`autoModeConfig.enabled: true` in eksctl, or `--compute-config` on the API) makes AWS operate the data plane: it runs the nodes (immutable AMI, replaced regularly), and the core controllers: compute autoscaling (Karpenter), **load balancing**, **block storage**, pod networking, CoreDNS. You do **not** install the AWS Load Balancer Controller or the EBS CSI add-on. What changes for OrderFlow:
- Ingress: the controller is `eks.amazonaws.com/alb`; you create an `IngressClass` (+ `IngressClassParams` with `scheme`, subnets) and use that class instead of installing the Helm chart. Most `alb.ingress.kubernetes.io/*` annotations still work; class-level settings (scheme, subnets, group name) move to `IngressClassParams`, and a few are unsupported (`kubernetes.io/ingress.class`, `group.name`, `waf-acl-id`/`web-acl-id`, `dry-run-plan`, `create-acm-cert`, `acm-pca-arn`). Check the Auto Mode ALB docs.
- Storage: provisioner `ebs.csi.eks.amazonaws.com` (not `ebs.csi.aws.com`); PVCs bound to a class of the old provisioner do not work.
- Nodes come from `NodePool`/`NodeClass` objects (built-in `general-purpose` and `system` pools); there are no node groups to size, but you pay an Auto Mode management fee on top of the EC2 price.
- Trade-off: less to patch and tune, less control (no custom AMI, no SSH).

**Karpenter** is the autoscaler under Auto Mode and can run on a standard cluster (a controller you install, with its own Pod Identity role and a node role): instead of resizing node groups it watches **unschedulable pods** and launches the cheapest EC2 instance types that fit, then **consolidates** (removes or replaces under-used nodes). Shape of the configuration (Karpenter v1 API):
```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata: {name: general}
spec:
  template:
    spec:
      nodeClassRef: {group: karpenter.k8s.aws, kind: EC2NodeClass, name: default}
      requirements:
        - {key: kubernetes.io/arch, operator: In, values: ["arm64"]}
        - {key: karpenter.sh/capacity-type, operator: In, values: ["on-demand", "spot"]}
  limits: {cpu: "16"}                        # hard ceiling on what this pool may launch
  disruption: {consolidationPolicy: WhenEmptyOrUnderutilized}
```
(Illustrative, not part of the lab: not applied or validated.) Karpenter respects the same pod-level inputs you already wrote: resource **requests**, `topologySpreadConstraints`, PDBs and `terminationGracePeriodSeconds` decide how fast nodes can be consolidated without errors.

### 8. What it costs

Prices are `us-east-1` on-demand, approximate (October 2026; check the pricing pages before relying on them).

| Item | Rate | per hour |
|:---|:---|---:|
| EKS control plane | $0.10 per cluster-hour | 0.100 |
| 2 × `t4g.medium` | ~$0.034 each | 0.067 |
| NAT gateway (1) | $0.045/h + $0.045/GB processed | 0.045 + traffic |
| Application Load Balancer | $0.0225/h + LCUs | ~0.03 |
| Public IPv4 addresses (NAT EIP + 2-3 ALB IPs) | $0.005/h each | ~0.020 |
| EBS (2 × 20 GB node disks gp3, 5 GB Postgres) | ~$0.08/GB-month | ~0.006 |
| Data transfer, image pulls through NAT, logs | usage | ~0.02-0.1 |
| **Total** | | **about $0.30-0.40/h (~$7-10/day)** |

A one-hour lab costs well under a dollar. A forgotten cluster costs about $250 a month, and a forgotten NAT gateway or ALB bills even after the cluster is gone. Three HA NAT gateways instead of one adds $0.09/h (plus 2 more Elastic IPs at $0.005/h each).

---

## Exercises

### Exercise 1: The pod has no AWS identity
A pod uses ServiceAccount `reports` in namespace `orderflow`. You create the role and an association for `orderflow/reports`. The app still logs `Unable to locate credentials` (or, on some setups, `AccessDenied ... assumed-role/...NodeInstanceRole`). What do you check?

**Hint:** Identity is injected when a pod is **created**, and only if the association matches namespace and ServiceAccount exactly.

**Solution sketch:**
1. `aws eks list-pod-identity-associations --cluster-name $CLUSTER`: is there an entry for `orderflow` / `reports`? Names are exact and case-sensitive.
2. `kubectl get pod <pod> -o jsonpath='{.spec.serviceAccountName}'`: does the pod really use `reports`, or `default`?
3. `kubectl get pod <pod> -o jsonpath='{.spec.containers[0].env[*].name}'`: are `AWS_CONTAINER_CREDENTIALS_FULL_URI` and `AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE` present? If not, the pod started before the association: `kubectl rollout restart deploy/<name>`.
4. `kubectl get ds eks-pod-identity-agent -n kube-system`: the agent must run on that node.
5. Role trust policy: principal `pods.eks.amazonaws.com`, actions `sts:AssumeRole` **and** `sts:TagSession`. A trust policy copied from an IRSA role (`Federated`/`AssumeRoleWithWebIdentity`) fails.
6. Old SDK? Pod Identity needs an AWS SDK recent enough to support the container credentials provider with the token file; update the SDK, do not add keys.

### Exercise 2: Postgres PVC stays Pending
`kubectl get pvc -n orderflow` shows `data-orderflow-postgres-0 Pending gp3`; the event says `Waiting for a volume to be created, either by external provisioner "ebs.csi.aws.com" ...`. Cause?

**Hint:** Two different controllers are involved: the scheduler (first consumer) and the CSI provisioner (AWS permissions).

**Solution sketch:**
1. With `WaitForFirstConsumer` the PVC is `Pending` until the pod is scheduled: `kubectl get pod orderflow-postgres-0`. If the pod is `Pending` too, fix scheduling first (topology spread, capacity).
2. Scheduled but still waiting: `kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver`; none = the add-on is missing (`aws eks list-addons`).
3. Running but provisioning fails: `kubectl logs -n kube-system deploy/ebs-csi-controller -c csi-provisioner` shows `UnauthorizedOperation` / `no credentials` → the controller ServiceAccount `ebs-csi-controller-sa` has no Pod Identity association (or the pods predate it): list associations, create it with `AmazonEBSCSIDriverPolicy`, `kubectl rollout restart deploy/ebs-csi-controller -n kube-system`.
4. PVC with no `storageClassName` and no default class (EKS 1.30+ creates none): it stays Pending with no provisioner event at all. `kubectl get storageclass` shows nothing `(default)`: apply the `gp3` default class (or name a class in the PVC). A class with provisioner `kubernetes.io/aws-ebs` (`gp2`) still works via CSI migration, but only with the EBS CSI driver installed.

### Exercise 3: The Ingress never gets an address
`kubectl get ingress -n orderflow` shows no ADDRESS after 10 minutes. List the causes in the order you check them.

**Hint:** Is anything watching this Ingress class, and can it call AWS?

**Solution sketch:**
1. `spec.ingressClassName` must be `alb` (`kubectl get ingress orderflow-ingress -o yaml`) and `kubectl get ingressclass` must list `alb` (created by the controller chart). A leftover `nginx` class from the local labs is a classic.
2. `kubectl get deploy -n kube-system aws-load-balancer-controller`: installed and Available?
3. Its log: `AccessDenied` / `no EC2 IMDS role found` = missing association (or pod older than the association → restart); `couldn't auto-discover subnets` = subnet tags (`kubernetes.io/role/elb=1` for internet-facing, `kubernetes.io/role/internal-elb=1` for internal); `vpcId`/`region` missing in the Helm values on nodes without metadata access.
4. Events on the Ingress (`kubectl describe ingress`): `FailedBuildModel` names the annotation or the backend that is wrong (e.g. a `Service` that does not exist, `target-type: ip` with a non-routable setup).
5. ADDRESS present but the URL fails: DNS takes a few minutes; then target health (`aws elbv2 describe-target-health`), then the pod's readiness (`/ready`) and the security group between ALB and pods (the controller manages it with the cluster security group).

### Exercise 4: Why does `eksctl delete cluster` fail on the VPC?
Teardown stops with `DELETE_FAILED` on the VPC stack: `The vpc ... has dependencies and cannot be deleted`. What was skipped, and how do you recover?

**Hint:** Who created the ALB and its security group, and who was supposed to delete them?

**Solution sketch:**
1. The ALB, target groups and a security group were created by the **controller**, not by CloudFormation. If the cluster (and with it the controller) is deleted first, nothing removes them, and their network interfaces/SGs block VPC deletion. That is why teardown deletes the Ingress first and verifies the ALB is gone.
2. Recovery: find leftovers in the VPC: `aws elbv2 describe-load-balancers`, `aws ec2 describe-security-groups --filters Name=vpc-id,Values=<vpc>`, `aws ec2 describe-network-interfaces --filters Name=vpc-id,Values=<vpc>`; delete the ALB, then the target groups, then the controller-created SGs; re-run `eksctl delete cluster ... --wait`.
3. The same logic applies to EBS volumes of PVCs (CSI driver) and to `Service type=LoadBalancer` NLBs.

---

## Anti-patterns / Common mistakes
- **A cluster as a fire-and-forget lab.** No teardown verification, a forgotten NAT gateway/ALB/EBS volume bills for weeks. Tag everything (`tags:` in `cluster.yaml`) and run the "nothing left" commands.
- **Deleting the cluster before the Ingress and PVCs.** Leaks the ALB, target groups, SGs and EBS volumes (see Exercise 4).
- **Broad node-role policies instead of per-workload identity.** Every pod on the node gets them.
- **Mixing up the two mechanisms.** IRSA trust policy on a Pod Identity role (or the reverse); an annotation on a ServiceAccount that Pod Identity ignores.
- **Copying a version number.** A pinned `1.29` can no longer be created. Look up the default version, the controller release, and match the controller's IAM policy to its version.
- **Arch mismatch.** Building on a Mac (arm64) and running on `t3` (amd64), or the reverse: `exec format error`. Pick Graviton or build `linux/amd64`/multi-arch.
- **`--set` for annotation keys.** `alb.ingress.kubernetes.io/scheme` contains dots and a slash: put annotations in a values file (`values-eks.yaml`).
- **Regex/rewrite annotations from ingress-nginx.** ALB has `Prefix`/`Exact` paths only; rewrite in the app or use another edge.
- **`DoNotSchedule` spread with too few nodes/zones.** The pods stay Pending; you need nodes in at least as many zones as the spread requires.
- **No default StorageClass, or two.** None: PVCs without a class stay Pending (EKS 1.30+ creates none); two: behaviour is unpredictable. Exactly one default.
- **Fargate "because serverless".** No DaemonSets, no EBS, slower starts. Reach for Auto Mode first.

---

## Recall drill
Answer from memory, then open the block.

1. Which add-on delivers credentials to pods under Pod Identity, and which two env vars show it worked?
2. What does the trust policy of a Pod Identity role trust, and what binds the role to a ServiceAccount?
3. Name three cases where IRSA is still the right choice.
4. Which component creates the ALB from an Ingress, and what permissions does it need from where?
5. Why `WaitForFirstConsumer` for EBS, and what does it imply for pod placement?
6. In what order do you tear down, and which two AWS checks prove the controller-created resources are gone?
7. What do Auto Mode and Karpenter each decide?

<details>
<summary>Answers</summary>

1. `eks-pod-identity-agent`; `AWS_CONTAINER_CREDENTIALS_FULL_URI` and `AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE` (IRSA: `AWS_ROLE_ARN`, `AWS_WEB_IDENTITY_TOKEN_FILE`).
2. The service principal `pods.eks.amazonaws.com` (`sts:AssumeRole`, `sts:TagSession`); a Pod Identity **association** (cluster + namespace + ServiceAccount → role). No annotation.
3. Fargate pods; legacy workloads/SDKs without Pod Identity support; clusters outside EKS (EKS Anywhere, self-managed). Cross-account is no longer a reason: Pod Identity associations take a `targetRoleARN`.
4. The AWS Load Balancer Controller (installed by Helm, or built into Auto Mode); an IAM policy from its release's `iam_policy.json`, attached to a role associated with its ServiceAccount.
5. The EBS volume exists in one AZ; delaying creation until the pod is scheduled makes the volume match the pod's zone. Afterwards the pod can only run in that zone.
6. Chart (Ingress → ALB) → verify ALB/TGs/SG gone → PVCs → verify volumes gone → uninstall controller → `eksctl delete cluster --wait` → IAM, ECR, log groups → NAT/EIP check. Checks: `aws elbv2 describe-load-balancers` / target groups, and `aws ec2 describe-volumes --filters Name=tag-key,Values=kubernetes.io/created-for/pvc/name`.
7. Auto Mode: AWS operates nodes and core controllers (LB, storage, DNS, networking). Karpenter: which instances to launch for pending pods and when to consolidate; it is the engine inside Auto Mode and also installable on its own.
</details>

---

## Lab

Hands-on: **`labs/eks/README.md`** (plain steps, expected output in `labs/eks/SOLUTION.md`). Files: `labs/eks/cluster.yaml` (eksctl), `labs/eks/storageclass-gp3.yaml`, `labs/eks/iam/pod-identity-trust.json`, and the chart overlay `labs/day06/orderflow-chart/values-eks.yaml`. Outline:
1. `eksctl create cluster -f labs/eks/cluster.yaml` (Graviton nodes, five add-ons, EBS CSI Pod Identity).
2. ECR: three repositories, `aws ecr get-login-password | docker login`, `docker buildx build --platform linux/arm64 --push`.
3. gp3 default StorageClass.
4. AWS Load Balancer Controller: IAM policy (pinned release) → role → association → `helm install` from `https://aws.github.io/eks-charts`.
5. `helm install orderflow ... -f values-eks.yaml` in a `restricted` namespace; reach the ALB DNS name.
6. Pod Identity check: `aws sts get-caller-identity` from a pod with its own ServiceAccount, and from one without.
7. Teardown (below), including the verification commands.

Cost: about $0.30-0.40 per hour. Do not leave it overnight.

---

## Teardown
Order matters. The ALB, its target groups and security groups are created by the **controller**, and the EBS volumes by the **CSI driver**: delete their Kubernetes objects while those controllers still run, and check AWS (not just `kubectl`) after each step. A cluster deleted first leaves them behind, and a leftover ALB ENI or security group makes the VPC deletion fail.

```bash
export AWS_REGION=us-east-1 CLUSTER=orderflow-eks        # same values as the lab
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 1. Remove the chart: this deletes the Ingress, and the controller (still running) deletes the ALB.
helm uninstall orderflow -n orderflow --cascade foreground --wait --ignore-not-found
kubectl delete pod identity-demo identity-control -n orderflow --ignore-not-found

# 2. Verify the ALB, target groups and its security group are really gone (all three must print an empty list; ALB takes 1-3 min).
for i in {1..30}; do
  n=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "length(LoadBalancers[?starts_with(LoadBalancerName,'k8s-orderflo')])" --output text)
  [ "$n" = "0" ] && break; sleep 10
done
aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "LoadBalancers[?starts_with(LoadBalancerName,'k8s-orderflo')].LoadBalancerArn"
aws elbv2 describe-target-groups --region "$AWS_REGION" --query "TargetGroups[?starts_with(TargetGroupName,'k8s-orderflo')].TargetGroupArn"
aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=tag:elbv2.k8s.aws/cluster,Values=$CLUSTER" --query 'SecurityGroups[].GroupId'

# 3. Delete the Postgres PVC while the EBS CSI driver still runs (StatefulSet PVCs survive helm uninstall), then the namespace.
kubectl delete pvc --all -n orderflow --wait=true
kubectl delete namespace orderflow --ignore-not-found

# 4. Verify the EBS volume is gone ([] = nothing left; "deleting" is fine for a few seconds).
aws ec2 describe-volumes --region "$AWS_REGION" --filters "Name=tag-key,Values=kubernetes.io/created-for/pvc/name" "Name=tag:kubernetes.io/created-for/pvc/namespace,Values=orderflow" --query 'Volumes[].[VolumeId,State]'

# 5. Uninstall the AWS Load Balancer Controller, then delete the cluster (15 min; --wait blocks until the stacks are gone).
helm uninstall aws-load-balancer-controller -n kube-system --ignore-not-found
eksctl delete cluster -f labs/eks/cluster.yaml --wait

# 6. Delete what you created outside the cluster: IAM roles/policy, ECR repositories, log groups.
aws iam detach-role-policy --role-name orderflow-lbc-role --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/orderflow-AWSLoadBalancerControllerIAMPolicy"
aws iam delete-role --role-name orderflow-lbc-role
aws iam delete-role --role-name orderflow-identity-demo
aws iam delete-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/orderflow-AWSLoadBalancerControllerIAMPolicy"
for svc in order-api payment-service notification-service; do
  aws ecr delete-repository --region "$AWS_REGION" --repository-name "orderflow/$svc" --force
done
aws logs describe-log-groups --region "$AWS_REGION" --log-group-name-prefix "/aws/eks/$CLUSTER" --query 'logGroups[].logGroupName'
#   anything listed (only if you enabled control-plane logging): aws logs delete-log-group --region "$AWS_REGION" --log-group-name <name>

# 7. Final check: nothing billable is left (every command should print [] or an empty table).
aws eks list-clusters --region "$AWS_REGION" --query clusters
aws ec2 describe-nat-gateways --region "$AWS_REGION" --filter "Name=state,Values=pending,available,deleting" --query 'NatGateways[].[NatGatewayId,State]'
aws ec2 describe-addresses --region "$AWS_REGION" --query 'Addresses[?AssociationId==null].[AllocationId,PublicIp]'
aws ec2 describe-volumes --region "$AWS_REGION" --filters "Name=status,Values=available" --query 'Volumes[].VolumeId'
aws cloudformation list-stacks --region "$AWS_REGION" --stack-status-filter DELETE_FAILED --query 'StackSummaries[].StackName'

# 8. Point kubectl back at the local cluster.
kubectl config use-context docker-desktop
```
`describe-nat-gateways` also lists NAT gateways of other projects in the account: only the ones in the VPC `eksctl-orderflow-eks-cluster` are yours. `describe-addresses` and `describe-volumes` list unattached resources account-wide; judge by tags (`aws ec2 describe-addresses` shows `Tags`). Delete the generated files (they contain your account ID): `rm -rf "${TMPDIR:-/tmp}/orderflow-eks"`.

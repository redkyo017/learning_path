# EKS Lab: OrderFlow on Amazon EKS (Graviton, Pod Identity, ALB, EBS gp3)

**Run every command from the course root** (`k8s_docker_mastery/`). This lab is **optional and costs real money** (about $0.30-0.40 per hour while the cluster exists, see the cost table in `content/appendix-eks.md`). It needs an AWS account, `aws` CLI v2 with working credentials, `eksctl`, `kubectl`, `helm` 4, and Docker. Nothing here runs on the Docker Desktop cluster; the EKS context that `eksctl` creates becomes your current context, and the last teardown step switches back to `docker-desktop`.

## Start here — plain steps

1. Open a terminal in `k8s_docker_mastery/`. `aws sts get-caller-identity` must print your account, and `eksctl version`, `helm version --short` (v4) and `docker info` must work.
2. Set the four variables in **Step 1**. Everything below uses them.
3. `eksctl create cluster -f labs/eks/cluster.yaml` (15-20 minutes). When it ends you should see 2 nodes `Ready` with `ARCH arm64`, and 5 add-ons `ACTIVE`.
4. Create three ECR repositories, log Docker in, tag and push the three `v1` images. You should see `aws ecr describe-images` list `v1` three times.
5. Install the AWS Load Balancer Controller (IAM role + Pod Identity association + Helm) and make `gp3` the default StorageClass. You should see the controller `2/2 Available` and `gp3 (default)`.
6. Create the `orderflow` namespace with the `restricted` label and `helm install` the chart with `values-eks.yaml`. You should see all pods `Running`, an Ingress with an ALB hostname, and `curl http://<alb-dns>/orders` return `[]`.
7. Run the Pod Identity check: a pod with its own ServiceAccount prints your **role** ARN; a pod without one does not.
8. Run **Teardown** in the written order and finish with the "nothing left" commands. You are done when all of them print empty lists. **Do not stop before this step.**

## Objective
Create a small EKS cluster, push the three OrderFlow images to ECR, give the AWS Load Balancer Controller and the EBS CSI driver their AWS permissions with **EKS Pod Identity**, install the Day 6 chart with the EKS overlay (`values-eks.yaml`: ALB Ingress, ECR images, gp3 volume, zone spreading, `restricted` PSA still on), reach it through the ALB, prove a pod gets its own IAM identity, and tear everything down in the order that leaves nothing billing.

## Architecture

```
 Mac: curl http://<alb-dns>/orders
   ▼
 ALB (internet-facing, 2+ public subnets)  ◄── created by the AWS Load Balancer Controller from Ingress orderflow-ingress (className alb)
   ▼  target-type ip: straight to pod IPs, health check GET /ready
 Pods (private subnets, 2 × t4g.medium arm64, one per AZ)  — namespace orderflow, restricted PSA
   order-api ×2, payment ×2, notification ×1, postgres-0 (PVC → EBS gp3 via ebs.csi.aws.com)
 kube-system: aws-node (vpc-cni), coredns, kube-proxy, eks-pod-identity-agent, ebs-csi-*, aws-load-balancer-controller
 AWS identities: Pod Identity associations  ebs-csi-controller-sa → AmazonEBSCSIDriverPolicy role (eksctl)
                                            aws-load-balancer-controller → orderflow-lbc-role (you)
                                            orderflow/identity-demo → orderflow-identity-demo (you)
 Egress: private subnets → 1 NAT gateway (single AZ: a lab economy, not an HA design)
```

---

## Instructions

### Step 1: Variables and tools
```bash
export AWS_REGION=us-east-1            # must equal metadata.region in labs/eks/cluster.yaml
export CLUSTER=orderflow-eks           # must equal metadata.name in labs/eks/cluster.yaml
export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
export GEN="${TMPDIR:-/tmp}/orderflow-eks" && mkdir -p "$GEN"   # generated files (they contain your account ID) stay outside the repo
echo "$REGISTRY"
```
*You should see `<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com` with your 12-digit account.* Variables do not survive a new terminal: re-run this step first. Check the Kubernetes version the cluster file asks for is still the default:
```bash
aws eks describe-cluster-versions --region "$AWS_REGION" --default-only --query 'clusterVersions[].clusterVersion' --output text
grep -n 'version:' labs/eks/cluster.yaml
```
*You should see the same minor version in both. This lab was written with `1.36` while the default had moved to `1.37`: if AWS prints a different one, edit `version:` in `cluster.yaml` (older standard-support versions still work, they are just closer to the end of support).*

### Step 2: Create the cluster
```bash
eksctl create cluster -f labs/eks/cluster.yaml
kubectl config current-context
kubectl get nodes -L kubernetes.io/arch,topology.kubernetes.io/zone
aws eks list-addons --region "$AWS_REGION" --cluster-name "$CLUSTER" --query addons
aws eks list-pod-identity-associations --region "$AWS_REGION" --cluster-name "$CLUSTER" --query 'associations[].[namespace,serviceAccount]'
```
*You should see (after 15-20 min): a context like `<you>@orderflow-eks.us-east-1.eksctl.io`; two nodes `Ready`, `arm64`, in two different zones; the five add-ons; one association `kube-system ebs-csi-controller-sa`.* `eksctl` runs CloudFormation stacks; if it fails, `eksctl delete cluster -f labs/eks/cluster.yaml --wait` cleans up and you can retry.

### Step 3: ECR repositories and image push
```bash
for svc in order-api payment-service notification-service; do
  aws ecr create-repository --region "$AWS_REGION" --repository-name "orderflow/$svc" \
    --image-scanning-configuration scanOnPush=true --image-tag-mutability IMMUTABLE --query 'repository.repositoryUri' --output text
done
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"
```
Build for the nodes' architecture (Graviton = arm64; an Apple Silicon Mac builds arm64 by default, `--platform` just makes it explicit) and push:
```bash
for svc in order-api payment-service notification-service; do
  docker buildx build --platform linux/arm64 -t "$REGISTRY/orderflow/$svc:v1" --push "labs/shared/$svc"
done
for svc in order-api payment-service notification-service; do
  aws ecr describe-images --region "$AWS_REGION" --repository-name "orderflow/$svc" --query 'imageDetails[].imageTags'
done
```
*You should see three repository URIs, `Login Succeeded`, and `[["v1"]]` three times.* **Intel/AMD nodes instead** (e.g. you changed the nodegroup to `t3.medium`): build with `--platform linux/amd64`. An arm64 image on an amd64 node ends in `exec format error` (CrashLoopBackOff). Postgres and busybox come from the ECR Public mirror (`public.ecr.aws/docker/library/...`, set in `values-eks.yaml`), nothing to push.

### Step 4: gp3 as the default StorageClass
```bash
kubectl apply -f labs/eks/storageclass-gp3.yaml
kubectl patch storageclass gp2 -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl get storageclass
```
*You should see `gp3 (default) ebs.csi.aws.com Delete WaitForFirstConsumer true` and `gp2` without `(default)`.* Why a default class at all: without one, a PVC that names no `storageClassName` (like the chart's Postgres PVC) stays `Pending` forever. Since EKS 1.30 new clusters do **not** mark `gp2` as default, so the `gp2` patch is a harmless no-op there (`NotFound` or `patched (no change)` is fine); it only matters on older clusters. (`gp2` still works through CSI migration once the EBS CSI driver is installed.)

### Step 5: AWS Load Balancer Controller (IAM policy, Pod Identity role, Helm)
Pin the controller release and download **that release's** IAM policy (the policy changes between versions):
```bash
export LBC_VERSION=v3.6.0      # latest release when written; check https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases
curl -fsSLo "$GEN/lbc-iam-policy.json" \
  "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/$LBC_VERSION/docs/install/iam_policy.json"
export LBC_POLICY_ARN=$(aws iam create-policy --policy-name orderflow-AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://$GEN/lbc-iam-policy.json --query Policy.Arn --output text)
aws iam create-role --role-name orderflow-lbc-role \
  --assume-role-policy-document file://labs/eks/iam/pod-identity-trust.json --query Role.Arn --output text
aws iam attach-role-policy --role-name orderflow-lbc-role --policy-arn "$LBC_POLICY_ARN"
aws eks create-pod-identity-association --region "$AWS_REGION" --cluster-name "$CLUSTER" \
  --namespace kube-system --service-account aws-load-balancer-controller \
  --role-arn "arn:aws:iam::$ACCOUNT_ID:role/orderflow-lbc-role" --query 'association.associationId' --output text
```
*You should see a policy ARN, a role ARN, and an association id `a-...`.* The trust policy (`labs/eks/iam/pod-identity-trust.json`) trusts the service `pods.eks.amazonaws.com`; the **association** is what binds the role to namespace + ServiceAccount (no OIDC provider, no annotation on the ServiceAccount).
```bash
helm repo add eks https://aws.github.io/eks-charts && helm repo update eks
helm search repo eks/aws-load-balancer-controller --versions | head -4      # from v3 the chart version equals the app version (v2.x charts were 1.x)
export LBC_CHART_VERSION=3.6.0                                              # = $LBC_VERSION without the v
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --version "$LBC_CHART_VERSION" \
  --set clusterName="$CLUSTER" --set serviceAccount.create=true --set serviceAccount.name=aws-load-balancer-controller \
  --set region="$AWS_REGION" --set vpcId="$(aws eks describe-cluster --region "$AWS_REGION" --name "$CLUSTER" --query cluster.resourcesVpcConfig.vpcId --output text)"
kubectl rollout status deploy/aws-load-balancer-controller -n kube-system --timeout=180s
kubectl get pod -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller -o jsonpath='{.items[0].spec.containers[0].env[*].name}'; echo
```
*You should see `deployment ... successfully rolled out`, and an env list that includes `AWS_CONTAINER_CREDENTIALS_FULL_URI` and `AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE`* (injected by EKS because of the association; this is the Pod Identity fingerprint, the IRSA fingerprint is `AWS_ROLE_ARN` + `AWS_WEB_IDENTITY_TOKEN_FILE`). `vpcId` and `region` are set explicitly so the controller does not depend on reading them from instance metadata.

### Step 6: Install OrderFlow with the EKS overlay
```bash
kubectl create namespace orderflow
kubectl label ns orderflow pod-security.kubernetes.io/enforce=restricted pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/warn=restricted pod-security.kubernetes.io/audit=restricted
sed -e "s|<ACCOUNT_ID>|$ACCOUNT_ID|g" -e "s|<REGION>|$AWS_REGION|g" \
  labs/day06/orderflow-chart/values-eks.yaml > "$GEN/values-eks.generated.yaml"
helm install orderflow labs/day06/orderflow-chart -n orderflow -f "$GEN/values-eks.generated.yaml" --wait --timeout 10m
kubectl get pods,pvc,ingress -n orderflow -o wide
```
*You should see: `STATUS: deployed`; order-api/payment `2/2` and `1/1` pods spread over two nodes, `orderflow-postgres-0` Running, the migration Job Completed, `data-orderflow-postgres-0 Bound ... gp3`, and an Ingress `orderflow-ingress` with CLASS `alb` and, after 1-3 minutes, an ADDRESS `k8s-orderflo-orderflo-<hash>-<n>.us-east-1.elb.amazonaws.com`.* The restricted label is **not** relaxed on EKS: the same chart passes the same policy.

### Step 7: Reach it through the ALB
```bash
for i in {1..30}; do
  ALB=$(kubectl get ingress orderflow-ingress -n orderflow -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
  [ -n "$ALB" ] && break; sleep 10
done
echo "$ALB"
curl -s --retry 20 --retry-delay 10 --retry-all-errors -o /dev/null -w '%{http_code}\n' "http://$ALB/orders"
curl -s "http://$ALB/orders"; echo
curl -s -X POST "http://$ALB/orders" -H 'Content-Type: application/json' -d '{"item":"widget","qty":2}'; echo
TG=$(aws elbv2 describe-target-groups --region "$AWS_REGION" --query "TargetGroups[?starts_with(TargetGroupName,'k8s-orderflo')].TargetGroupArn | [0]" --output text)
aws elbv2 describe-target-health --region "$AWS_REGION" --target-group-arn "$TG" --query 'TargetHealthDescriptions[].[Target.Id,Target.Port,TargetHealth.State]'
```
*You should see the ALB hostname, `200` (a new ALB's DNS name can take a few minutes: the retry flag covers it), `[]`, a created order, and two targets (the order-api **pod IPs**, port 8080) `healthy`.* Only `/orders` is routed: `/health` or `/` on the ALB returns the ALB's own 404. Payment and notification are not exposed (no path for them in the Ingress).

### Step 8: Prove Pod Identity (a pod gets its own role)
```bash
aws iam create-role --role-name orderflow-identity-demo \
  --assume-role-policy-document file://labs/eks/iam/pod-identity-trust.json --query Role.Arn --output text
kubectl create serviceaccount identity-demo -n orderflow
aws eks create-pod-identity-association --region "$AWS_REGION" --cluster-name "$CLUSTER" \
  --namespace orderflow --service-account identity-demo \
  --role-arn "arn:aws:iam::$ACCOUNT_ID:role/orderflow-identity-demo" --query 'association.associationId' --output text
for p in identity-demo identity-control; do
  sa=default; [ "$p" = identity-demo ] && sa=identity-demo
  kubectl apply -n orderflow -f - <<YAML
apiVersion: v1
kind: Pod
metadata: {name: $p}
spec:
  serviceAccountName: $sa
  restartPolicy: Never
  securityContext: {runAsNonRoot: true, runAsUser: 1000, seccompProfile: {type: RuntimeDefault}}
  containers:
    - name: aws
      image: public.ecr.aws/aws-cli/aws-cli:latest
      args: ["sts", "get-caller-identity", "--query", "Arn", "--output", "text"]
      env: [{name: HOME, value: /tmp}, {name: AWS_REGION, value: $AWS_REGION}]
      securityContext: {allowPrivilegeEscalation: false, capabilities: {drop: ["ALL"]}}
YAML
done
for p in identity-demo identity-control; do
  for i in {1..36}; do
    ph=$(kubectl get pod "$p" -n orderflow -o jsonpath='{.status.phase}')
    case "$ph" in Succeeded|Failed) break ;; esac
    sleep 5
  done
  echo "$p: $ph"
done
kubectl logs identity-demo -n orderflow
kubectl logs identity-control -n orderflow
```
*You should see: `arn:aws:sts::<ACCOUNT_ID>:assumed-role/orderflow-identity-demo/eks-...` from `identity-demo` (the **role you created**, session name starts with `eks-`), and from `identity-control` (default ServiceAccount, no association) either the **node role** (`...assumed-role/eksctl-orderflow-eks-nodegroup-ng-ar-NodeInstanceRole-...`) or an `Unable to locate credentials` error, depending on the nodes' metadata hop limit.* Either way the control pod does **not** get the demo identity: identity follows the ServiceAccount, not the node. If both print the node role, the association was created after the pod started or `eks-pod-identity-agent` is not running (Stuck? Hints).

---

## Success Signal
- `kubectl get nodes` shows 2 `Ready` arm64 nodes in 2 zones; `aws eks list-pod-identity-associations` lists 3 associations (EBS CSI, LBC, identity-demo).
- `helm status orderflow -n orderflow` is `deployed`; the PVC is `Bound` on `gp3`; no pod in `orderflow` is Pending or CrashLoopBackOff.
- `http://<alb-dns>/orders` returns 200; `describe-target-health` shows `healthy` targets.
- The identity pod prints the assumed-role ARN of `orderflow-identity-demo`.
- After Teardown: every verification command prints an empty list and `aws eks list-clusters` is `[]`.

## Stuck? Hints
- **Ingress has no ADDRESS after 5 minutes** → the controller did not create the ALB → `kubectl logs -n kube-system deploy/aws-load-balancer-controller | tail -30`. `AccessDenied`/`no credentials` = the Pod Identity association is missing or the controller pods started before it (create the association, then `kubectl rollout restart deploy/aws-load-balancer-controller -n kube-system`); `couldn't auto-discover subnets` = public subnets lack the `kubernetes.io/role/elb=1` tag (eksctl sets it; a custom VPC needs it); no log lines about the Ingress = `className` is not `alb`.
- **A pod in `orderflow` is Pending with `didn't match pod topology spread constraints`** → `values-eks.yaml` uses zone + `DoNotSchedule` and both nodes ended up in the same zone, or a node is full → `kubectl get nodes -L topology.kubernetes.io/zone`; fix the nodegroup (add a node in the other AZ) or temporarily `--set topologySpread.constraints[0].whenUnsatisfiable=ScheduleAnyway`.
- **`data-orderflow-postgres-0` stays Pending** → `kubectl describe pvc`: `waiting for first consumer` is normal until the pod is scheduled; if the pod is scheduled and it still waits, the CSI controller has no AWS permission → `kubectl logs -n kube-system deploy/ebs-csi-controller -c csi-provisioner`, `aws eks list-pod-identity-associations` must list `ebs-csi-controller-sa`; then `kubectl rollout restart deploy/ebs-csi-controller -n kube-system`.
- **`ImagePullBackOff` / `exec format error` on the three services** → `ImagePullBackOff`: wrong account/region in the generated values (`grep image: "$GEN/values-eks.generated.yaml"`) or the tag was not pushed. `exec format error`: image architecture differs from the node (`docker buildx imagetools inspect "$REGISTRY/orderflow/order-api:v1"` shows the platform vs `kubectl get nodes -L kubernetes.io/arch`); rebuild with the matching `--platform`.
- **`eksctl create cluster` fails on `vpc-cni`/`coredns` add-on or the nodegroup `CREATE_FAILED`** → quota or capacity for `t4g.medium` in the AZ → read the CloudFormation event (`eksctl utils describe-stacks`); retry another region/AZ or an `amd64` type, always `eksctl delete cluster ... --wait` first.
- **Teardown: `eksctl delete cluster` hangs on the VPC / `DELETE_FAILED`** → an ALB, target group or security group made by the controller is still there. Re-run the teardown verification commands of steps 2 and 4, delete the leftovers by id, retry the delete.

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

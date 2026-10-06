# EKS Lab: reference solution and expected output

> **Provenance, read this first.** Unlike the other days, this lab was **not run live**: it creates billable AWS resources and the course author's task was static validation only. What *was* verified: every YAML/JSON file parses, `helm template ... -f values-eks.yaml` renders 12 objects (no HTTPRoute, one Ingress with `ingressClassName: alb`, ECR image refs) and `kubectl apply --dry-run=client` accepts them. The outputs below are **what the commands are documented to print**, with account IDs, hashes and IPs as placeholders. Where the shape depends on AWS (ALB hostname, session name suffix, timings) it is marked `...`. If your output differs in *shape* (not in the hashes), the Stuck? Hints cover the likely causes.

## Step 1: variables
```
123456789012.dkr.ecr.us-east-1.amazonaws.com      # i.e. <ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com
1.37                                               # whatever the current default is; cluster.yaml's version may differ (1.36 is a supported version)
```

## Step 2: cluster (15-20 min)
```
$ kubectl get nodes -L kubernetes.io/arch,topology.kubernetes.io/zone
NAME                            STATUS   ROLES    AGE   VERSION   ARCH    ZONE
ip-192-168-xx-xx.ec2.internal   Ready    <none>   5m    v1.36.x   arm64   us-east-1a
ip-192-168-yy-yy.ec2.internal   Ready    <none>   5m    v1.36.x   arm64   us-east-1b
$ aws eks list-addons ... --query addons
["aws-ebs-csi-driver", "coredns", "eks-pod-identity-agent", "kube-proxy", "vpc-cni"]
$ aws eks list-pod-identity-associations ... --query 'associations[].[namespace,serviceAccount]'
[["kube-system", "ebs-csi-controller-sa"]]
```
Why the nodes are in two zones: the nodegroup spans the cluster's AZs and the ASG balances. If both nodes share a zone, see the Stuck? hint about topology spread.

## Step 3: ECR
Three `repositoryUri`s `<REGISTRY>/orderflow/<svc>`, `Login Succeeded`, three `[["v1"]]`. Repositories are `IMMUTABLE`: pushing `v1` twice fails with `tag invalid: The image tag 'v1' already exists`; bump the tag (`v2`) and `--set orderApi.image.tag=v2`, do not delete the tag.

## Step 4: StorageClass
```
NAME            PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION
gp2             kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   false      # only on clusters older than 1.30
gp3 (default)   ebs.csi.aws.com         Delete          WaitForFirstConsumer   true
```

## Step 5: AWS Load Balancer Controller
- `create-policy` prints `arn:aws:iam::<ACCOUNT_ID>:policy/orderflow-AWSLoadBalancerControllerIAMPolicy`; `create-role` prints `arn:aws:iam::<ACCOUNT_ID>:role/orderflow-lbc-role`; the association id is `a-...`.
- `rollout status`: `deployment "aws-load-balancer-controller" successfully rolled out` (2 replicas by default; on 2 small nodes that is fine).
- Env names include `AWS_STS_REGIONAL_ENDPOINTS AWS_DEFAULT_REGION AWS_REGION AWS_CONTAINER_CREDENTIALS_FULL_URI AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE` (exact list/order differs by version); `AWS_CONTAINER_CREDENTIALS_FULL_URI` is `http://169.254.170.23/v1/credentials`. If it is absent the pod started before the association: `kubectl rollout restart`.

## Step 6: chart
```
NAME                                     READY   STATUS      ...
orderflow-db-migration-xxxxx             0/1     Completed
orderflow-notification-...               1/1     Running
orderflow-order-api-...  (x2)            2/2     Running      # main + native sidecar
orderflow-payment-...    (x2)            1/1     Running
orderflow-postgres-0                     1/1     Running
persistentvolumeclaim/data-orderflow-postgres-0   Bound   pvc-...   5Gi   RWO   gp3
ingress/orderflow-ingress   alb   *   k8s-orderflo-orderflo-<hash>-<n>.us-east-1.elb.amazonaws.com   80
```
`helm install ... --wait` takes 2-4 minutes (first image pulls through the NAT, EBS attach). The `ADDRESS` appears 1-3 minutes after the Ingress is created, `--wait` does not wait for it.

## Step 7: ALB
```
200
[]
{"id":"...", ...}                                         # the created order (JSON; fields as in Day 2)
[["192.168.xx.xx", 8080, "healthy"], ["192.168.yy.yy", 8080, "healthy"]]
```
Targets are pod IPs (target-type ip), not node IPs and not NodePorts. They become `healthy` after 2 successful `/ready` checks at 10 s (about 20-30 s after registration); `initial`/`unhealthy` before that.

## Step 8: Pod Identity
```
identity-demo:    arn:aws:sts::<ACCOUNT_ID>:assumed-role/orderflow-identity-demo/eks-orderflow-e-identity-d-<uuid>
identity-control: arn:aws:sts::<ACCOUNT_ID>:assumed-role/eksctl-orderflow-eks-nodegroup-ng-ar-NodeInstanceRole-<id>/i-<instance>
                  (or: Unable to locate credentials, when the IMDS hop limit stops containers reaching the node role)
```
The session name is `eks-<cluster>-<pod>-<uuid>`, truncated by AWS; only the prefix `eks-` and the role name matter.

## Exercises in the appendix: sketches checked here
- **Exercise 1 (Pod Identity not applied):** the control pod above *is* the failure; `kubectl rollout restart` after creating an association fixes pods that started earlier. Association check: `aws eks list-pod-identity-associations --cluster-name $CLUSTER`.
- **Exercise 3 (ALB for the wrong class):** with `className: nginx` and no nginx controller the Ingress has no ADDRESS and the LBC log has no lines for it.

## Teardown: expected results
```
step 2: []   []   []                       # ALB, target groups, SG (ALB deletion takes 1-3 minutes after helm uninstall)
step 4: []                                  # no volume tagged for a PVC (a volume in "deleting" can show for a few seconds)
step 5: eksctl: "all cluster resources were deleted"
step 6: delete-repository prints the repository JSON; log groups: []
step 7: []  []  []  []  []                 # clusters, NAT gateways, unattached EIPs, available volumes, DELETE_FAILED stacks
```
Time: `helm uninstall` + ALB gone ~3 min; `eksctl delete cluster --wait` ~10-15 min. Cost of forgetting: ~$7-10 per day until you run it.

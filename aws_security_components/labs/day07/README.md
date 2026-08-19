# Day 7 lab — VPC-only Secrets Manager access

## Authorized testing

> **This lab targets only your own AWS account and your own
> `labs/base` deployment.** No step here calls, scans, or touches any
> resource you do not own and control. See
> [`content/ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md#authorized-testing-statement)
> for the sprint-wide statement this repeats.

## Objective

Prove, with a real before/after signal, that "the app runs in a VPC"
does **not** by itself make a resource VPC-only — and then make it
actually VPC-only using a VPC endpoint + endpoint policy + a
resource-policy condition on `aws:SourceVpce`, layered with a scoped
security group and NACL.

## Prereqs

- `labs/base` is applied and healthy (`terraform output` in `labs/base`
  shows `secret_arn`, `vpc_id`, `private_subnet_ids`).
- Your CLI credentials (used for the OUTSIDE-VPC test below) can call
  `secretsmanager:GetSecretValue` on the base secret — true by default
  if you're using the AdministratorAccess-style identity this sprint's
  README assumes for a personal sandbox account. If not, temporarily
  grant your own principal that one permission on that one secret ARN
  for the duration of this test, then remove it again.
- `terraform validate` passes in this directory (manual HCL review —
  Terraform is not installed in the authoring environment; run this
  yourself before `apply`).

## THE BREAK — reachable from outside the VPC

Before applying anything in this directory, run this from **your own
laptop or AWS CloudShell** (i.e. a location that is not inside the
base VPC):

```bash
SECRET_ARN=$(cd ../base && terraform output -raw secret_arn)
aws secretsmanager get-secret-value --secret-id "$SECRET_ARN"
```

**Expected (the break):** `200` — the call succeeds and returns the
secret's metadata (and its value, if you've set one out-of-band per
`labs/base/README.md`). Nothing about "it's deployed inside a VPC"
stopped this. The base secret has an identity-level `Allow` for the
task role (`iam.tf`, `ReadOwnSecret`) but **no resource policy at
all** — any caller with the IAM permission can reach it from anywhere.
This is [`ANTIPATTERNS.md` #3](../../content/ANTIPATTERNS.md) in
concrete form: the *allow* path (the app reading its own secret) was
tested and works; the path that should be *denied* (everyone else,
from anywhere) was never tested until just now.

Record the exact output (redact any real secret value before pasting
it anywhere) in `SOLUTION.md`.

## THE HARDEN — VPC endpoint + endpoint policy + `aws:SourceVpce`

```bash
cd labs/day07
terraform init
terraform plan    # review: 1 SG, 1 interface endpoint, 1 secret resource
                   # policy, 1 custom NACL + 4 NACL rules
terraform apply
```

This creates:

1. A security group for the endpoint's ENIs (443 inbound from the base
   VPC CIDR).
2. A Secrets Manager **interface** VPC endpoint in base's **private**
   subnets, with `private_dns_enabled = true` and an endpoint policy
   scoped to exactly the base secret's two read actions.
3. A **secret resource policy** on the base secret: explicit `Deny` on
   `GetSecretValue`/`DescribeSecret` unless `aws:SourceVpce` equals
   this new endpoint's ID.
4. A custom NACL on the private subnets — least-exposure backstop (see
   Exercise 1 in the content file for what it does and doesn't add on
   top of the SG).

### Test 1 — outside the VPC, again (must now fail)

Re-run the exact same command from Step "THE BREAK":

```bash
aws secretsmanager get-secret-value --secret-id "$SECRET_ARN"
```

**Expected (the harden):** `AccessDeniedException`. The explicit Deny
in the secret's new resource policy wins regardless of your identity
policy's Allow — see the content file's "engine lens." The exact
wording isn't pinned down here — **record your actual returned text**
in `SOLUTION.md`; for a `aws:SourceVpce`-conditioned resource-policy
denial the message should at minimum name the condition/resource
policy as the reason, not just say "not authorized."

### Test 2 — inside the VPC (must still succeed)

The app itself does **not** call `secretsmanager:GetSecretValue` at
runtime — `app.py`'s `/whoami` only echoes the secret's ARN string, it
never reads the value. So "the app stays healthy" is not a usable
signal here. Instead, get a real shell **inside the running Fargate
task** (which lives inside the VPC, in the public subnets) with ECS
Exec, and issue the identical CLI call from there, using the task
role's own credentials:

```bash
CLUSTER=$(cd ../base && terraform output -raw ecs_cluster_arn)
SERVICE=$(cd ../base && terraform output -raw ecs_service_name)
TASK_ARN=$(aws ecs list-tasks --cluster "$CLUSTER" --service-name "$SERVICE" --query 'taskArns[0]' --output text)

aws ecs execute-command \
  --cluster "$CLUSTER" --task "$TASK_ARN" --container app \
  --interactive --command "/bin/sh"

# inside the container:
aws secretsmanager get-secret-value --secret-id "$SECRET_ARN"
```

Base's `aws_ecs_service.app` sets `enable_execute_command = true` and
the task role carries the four `ssmmessages:*` actions ECS Exec needs
(see `labs/base/ecs.tf` and `iam.tf`), so this should work against a
freshly-applied base. If your task predates that setting (i.e. you
applied base before this flag existed and haven't redeployed since),
force a new deployment first so a task actually running with ECS Exec
enabled comes up: `aws ecs update-service --cluster "$CLUSTER"
--service "$SERVICE" --force-new-deployment`, then re-fetch `TASK_ARN`.

**Expected:** `200`, secret returned — from inside the VPC, through
the endpoint (private DNS resolves the standard
`secretsmanager.<region>.amazonaws.com` name to the endpoint's private
IP for anything resolving it inside this VPC), the same action that
was just denied from outside now succeeds, using the task role's
credentials, not your own. Record this side by side with Test 1 in
`SOLUTION.md`.

### Test 3 — reachability proof (least exposure)

Use VPC Reachability Analyzer to prove the *only* path in is the one
you intended:

```bash
# attachments[0] assumes the task has a single ENI attachment, true for
# this workload's awsvpc-mode Fargate task (one ENI per task) — if you've
# changed the task definition to attach more than one, index accordingly.
TASK_ENI=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
ENDPOINT_ENI=$(aws ec2 describe-vpc-endpoints \
  --vpc-endpoint-ids "$(terraform output -raw secretsmanager_endpoint_id)" \
  --query 'VpcEndpoints[0].NetworkInterfaceIds[0]' --output text)

PATH_ID=$(aws ec2 create-network-insights-path \
  --source "$TASK_ENI" --destination "$ENDPOINT_ENI" \
  --protocol tcp --destination-port 443 \
  --query 'NetworkInsightsPath.NetworkInsightsPathId' --output text)

ANALYSIS_ID=$(aws ec2 start-network-insights-analysis \
  --network-insights-path-id "$PATH_ID" \
  --query 'NetworkInsightsAnalysis.NetworkInsightsAnalysisId' --output text)

aws ec2 describe-network-insights-analyses --network-insights-analysis-ids "$ANALYSIS_ID"
```

**Expected:** `"NetworkPathFound": true` for the task ENI → endpoint
ENI path on 443 (the intended path works). Record the analysis ID and
result in `SOLUTION.md`. Clean up the path afterward:
`aws ec2 delete-network-insights-path --network-insights-path-id "$PATH_ID"`
(free to create/delete; no ongoing cost).

## Teardown

Interface VPC endpoints bill hourly — **tear this down the same day**.

- [ ] Delete any Network Insights path/analysis created in Test 3 (no
      cost, but tidy up): `aws ec2 delete-network-insights-path ...`
- [ ] `cd labs/day07 && terraform destroy` — destroys the endpoint, its
      SG, the custom NACL + rules, and the secret resource policy.
- [ ] Confirm the base secret is back to no resource policy:
      `aws secretsmanager get-resource-policy --secret-id "$SECRET_ARN"`
      should return no policy (or 404/`ResourceNotFoundException` on
      the policy, not the secret itself).
- [ ] `labs/base`'s own persistent resources (the secret, the S3
      bucket, the KMS key) are untouched by this destroy — leave them
      up per the base README's teardown model.
- [ ] `aws ec2 describe-vpc-endpoints` no longer lists the day-07
      endpoint (confirms the hourly charge has stopped).

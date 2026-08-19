# Day 5 SOLUTION — Secrets & certificates

Expected outputs and fix rationale. Read `README.md` first for the
commands themselves; this file records what "correct" looks like and why.

## THE BREAK — expected finding

```bash
terraform apply         # harden = false (default)

aws ecs describe-task-definition \
  --task-definition "$(terraform output -raw demo_task_definition_family)" \
  --query 'taskDefinition.containerDefinitions[0].environment'
```

Expected:

```json
[
    {"name": "APP_BUCKET", "value": "aws-sec-lab-appdata-<account_id>"},
    {"name": "AWS_REGION", "value": "us-east-1"},
    {"name": "APP_API_KEY", "value": "REPLACE_ME_LEAKED_PLACEHOLDER_NOT_A_REAL_SECRET"}
]
```

**The finding:** `APP_API_KEY` is a plaintext value in the task
definition's `environment` list, not a `secrets`/`valueFrom` reference.
This is a labeled placeholder (never a real credential) but the
*mechanism* of the leak is real: this value is now visible to
- anyone with `ecs:DescribeTaskDefinition` (frequently granted broadly --
  it looks like an innocuous read permission),
- Terraform state for this module (`terraform show`),
- CloudTrail's `RegisterTaskDefinition` event body,
- and every place the task definition JSON is copy-pasted for
  debugging, onboarding docs, or a support ticket.

That is [`ANTIPATTERNS.md` #10, secret sprawl](../../content/ANTIPATTERNS.md#10-secret-sprawl):
one secret, now living in more places than the one system of record
(Secrets Manager) that can actually rotate or audit it.

## THE HARDEN — expected state

```bash
# terraform.tfvars: harden = true
terraform apply

aws ecs describe-task-definition \
  --task-definition "$(terraform output -raw demo_task_definition_family)" \
  --query 'taskDefinition.containerDefinitions[0].{environment: environment, secrets: secrets}'
```

Expected:

```json
{
    "environment": [
        {"name": "APP_BUCKET", "value": "aws-sec-lab-appdata-<account_id>"},
        {"name": "AWS_REGION", "value": "us-east-1"}
    ],
    "secrets": [
        {
            "name": "APP_API_KEY",
            "valueFrom": "arn:aws:secretsmanager:us-east-1:<account_id>:secret:aws-sec-lab/app-secret-XXXXXX"
        }
    ]
}
```

**Fix rationale:** `secrets[].valueFrom` tells the ECS agent (using the
**task execution role**, granted by `aws_iam_role_policy.task_execution_secrets`
in `main.tf`) to resolve the current Secrets Manager value at launch and
inject it as an env var the container process sees -- the value is never
written into the task definition JSON, Terraform state, or CloudTrail's
`RegisterTaskDefinition` body. One source of truth (base's
`aws_secretsmanager_secret.app_secret`), referenced by ARN. This is the
corrective side of anti-pattern #10.

If the execution role's inline policy is missing or wrong, the task fails
to reach `RUNNING` with a `ResourceInitializationError: unable to
pull secrets` in `aws ecs describe-tasks ... --query 'tasks[0].stoppedReason'`
-- that failure mode is itself confirmation the wiring is real (a
plaintext env var can never fail this way; only a resolved secret can).

### Rotation

```bash
aws secretsmanager describe-secret --secret-id "$(terraform output -raw secret_arn)" \
  --query '{RotationEnabled: RotationEnabled, RotationRules: RotationRules, RotationLambdaARN: RotationLambdaARN}'
```

Expected:

```json
{
    "RotationEnabled": true,
    "RotationRules": {"AutomaticallyAfterDays": 30},
    "RotationLambdaARN": "arn:aws:lambda:us-east-1:<account_id>:function:aws-sec-lab-day05-rotate-app-secret"
}
```

To force an out-of-schedule rotation and watch it actually run (safe --
this is a placeholder value, not a real credential downstream):

```bash
aws secretsmanager rotate-secret --secret-id "$(terraform output -raw secret_arn)"
aws logs tail "/aws/lambda/aws-sec-lab-day05-rotate-app-secret" --since 5m
```

Expected log lines show all four steps (`createSecret`, `setSecret`,
`testSecret`, `finishSecret`) completing without a raised exception, and
`describe-secret --query VersionIdsToStages` shows the new version at
`AWSCURRENT`.

### HTTPS

```bash
curl -Ik "$(terraform output -raw alb_https_url)"
```

Expected: `HTTP/1.1 200` (or whatever status the app itself returns) over
a completed TLS handshake. With the public DNS-validated path, drop `-k`
and it still succeeds (publicly trusted chain). With the self-signed
fallback, `-k` is required -- `curl` without it reports `SSL certificate
problem: self-signed certificate`, which is the *expected*, harmless
failure mode of that path (see README prerequisites), not a
misconfiguration.

```bash
curl -I "http://$(cd ../base && terraform output -raw alb_dns_name)/"
```

Expected:

```
HTTP/1.1 301 Moved Permanently
Location: https://<alb-dns-name-or-domain>/
```

### Resource-policy deny (test the deny path)

Run as any principal that is **not** the task execution role or the
rotation Lambda's role:

```bash
aws secretsmanager get-secret-value --secret-id "$(terraform output -raw secret_arn)"
```

Expected:

```
An error occurred (AccessDeniedException) when calling the GetSecretValue operation:
User: arn:aws:iam::<account_id>:user/<you> is not authorized to perform:
secretsmanager:GetSecretValue on resource: ... because no identity-based
policy allows the secretsmanager:GetSecretValue action
```

(Exact wording varies by whether it's the resource policy's explicit Deny
or a simple lack-of-Allow — either way the call is denied, which is the
signal. If you want to see the *resource-policy* Deny specifically fire
rather than a generic lack-of-Allow, call it as a role that *does* have
an identity policy granting `secretsmanager:GetSecretValue` on this ARN --
e.g. base's task role, which has exactly that grant in `labs/base/iam.tf`
-- and confirm it is *still* denied. That is the resource-policy door
overriding an identity-policy Allow, checked in that order for a reason:
see the IAM evaluation order in [`GLOSSARY.md`](../../content/GLOSSARY.md#r).)

This is [`ANTIPATTERNS.md` #3](../../content/ANTIPATTERNS.md#3-never-actually-testing-a-deny)
in practice: `AccessDenied` here is the thing you were trying to prove,
not a bug to chase away.

## Reproducibility note (anti-pattern #2)

Every step above is `terraform apply`/`aws cli` — no console click was
used to create or fix anything. The one console-adjacent step (checking
`describe-task-definition`, `describe-secret`, `describe-listeners`) is
read-only inspection, consistent with
[`ANTIPATTERNS.md` #2](../../content/ANTIPATTERNS.md#2-console-clicking-instead-of-terraform):
the console/CLI is a verification tour, never how the fix itself was
made.

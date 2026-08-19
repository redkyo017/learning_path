# `labs/day05` — Secrets & certificates

Layers on `labs/base` (must already be applied). This lab does not edit
any file in `labs/base` -- everything here is either a standalone
resource or an additive resource attached to a base-owned resource by
ARN/name (see "How this layers on base without editing it" below).

> **Authorized testing only.** This lab's "break" targets only a
> standalone task-definition family registered by this same Terraform
> module, in your own AWS account. Nothing here targets any account,
> resource, or workload you do not own. See
> [`../../content/ANTIPATTERNS.md#authorized-testing-statement`](../../content/ANTIPATTERNS.md#authorized-testing-statement).

## Objective

1. **Break:** find a secret that leaked into a task definition's plaintext
   environment variables.
2. **Harden:** move it into Secrets Manager (base's existing
   `aws_secretsmanager_secret.app_secret`) with rotation, reference it from
   the task via the ECS `secrets` block instead of a plaintext value, and
   add an HTTPS listener with an ACM certificate to base's ALB (with an
   HTTP->HTTPS redirect).

## Prerequisites

- `labs/base` applied and up (`terraform output` in `labs/base` should
  succeed). This module reads its outputs via `terraform_remote_state`.
- Terraform >= 1.6, AWS provider >= 5.0, plus the `hashicorp/archive` and
  `hashicorp/tls` providers (both local-only, no AWS calls of their own --
  declared in `main.tf`, pulled automatically by `terraform init`).
- **Terraform is not run by this document's author** -- you run
  `terraform init/plan/apply/destroy` yourself.
- **The ACM domain prerequisite (read before you set `harden=true`):** a
  **public** ACM certificate can only be **issued** for a domain you
  actually control, proven by DNS validation. There is no way around this
  for a real public cert. This lab handles both cases honestly:
  - **You own a domain, and its hosted zone is in Route53 in this
    account:** set `domain_name` and `route53_zone_id` in your
    `terraform.tfvars` -- you get a real, publicly-trusted DNS-validated
    ACM certificate.
  - **You don't:** leave both blank. The module automatically falls back
    to **importing a self-signed certificate into ACM** (via the `tls`
    provider -- generated locally, no domain needed, free). You get a
    fully real TLS listener and handshake; the only thing missing is
    public trust, so `curl` needs `-k` and a browser will show a warning.
    This still teaches 100% of the ALB/ACM/listener plumbing.
  - A **third** option exists conceptually -- **ACM Private CA**, for
    issuing certs trusted only within your own org (no public domain
    validation needed at all) -- but it is **never provisioned in this
    lab**: the CA itself bills a flat ~$400/month regardless of how many
    certs you issue from it, which blows the whole sprint's <$15 budget
    for one exercise. See the content file's "ACM domain prerequisite"
    section for what it's for and why it's discussed, not deployed.

## How this layers on base without editing it

| What | Where | Why it's safe to attach without editing `labs/base` |
|---|---|---|
| `aws_iam_role_policy.task_execution_secrets` | attached to base's **task execution role**, by name (derived from its ARN) | A new, separate inline-policy resource in *this* state; base's `iam.tf` is untouched. Required because the ECS `secrets` block is resolved by the execution role at launch, and base's execution role only has the standard `AmazonECSTaskExecutionRolePolicy` today. |
| `aws_secretsmanager_secret_policy.app_secret` | attached to base's **secret**, by ARN | A resource policy is a top-level resource keyed by the secret ARN, not something you edit inside the `aws_secretsmanager_secret` resource. |
| `aws_secretsmanager_secret_rotation.app_secret` | attached to base's **secret**, by ARN | Same reasoning -- a standalone resource type, takes `secret_id` directly. |
| `aws_lb_listener.https` | attached to base's **ALB**, by ARN | A new listener (port 443) on an existing load balancer is an independent resource; it does not modify the existing HTTP:80 listener. |
| `aws_lb_listener_rule.redirect_to_https` | attached to base's **HTTP listener**, by ARN | A wildcard (`/*`) listener rule always wins over the listener's own `default_action` when it matches, so this achieves the redirect without changing that listener's resource definition. |
| `data.aws_lb_listener.http` | reads base's HTTP listener, by ARN | Read-only lookup, used only to discover the existing target group ARN (base's outputs don't expose it) so the new HTTPS listener forwards to the same running tasks. |

## THE BREAK

Apply with `harden = false` (the default):

```bash
cd labs/day05
cp terraform.tfvars.example terraform.tfvars
# edit region/project to match your labs/base apply
terraform init
terraform plan
terraform apply
```

This registers a standalone task-definition family
(`<project>-day05-app`) -- no live service, so no extra hourly cost --
that mirrors what a rushed teammate might ship: a placeholder API key
hardcoded straight into the container's environment block.

**Find it:**

```bash
aws ecs describe-task-definition \
  --task-definition "$(terraform output -raw demo_task_definition_family)" \
  --query 'taskDefinition.containerDefinitions[0].environment'
```

**Expected (the break):**

```json
[
    {"name": "APP_BUCKET", "value": "..."},
    {"name": "AWS_REGION", "value": "us-east-1"},
    {"name": "APP_API_KEY", "value": "REPLACE_ME_LEAKED_PLACEHOLDER_NOT_A_REAL_SECRET"}
]
```

The value is a labeled placeholder, never a real credential -- but the
finding is real: anyone who can call `ecs:DescribeTaskDefinition` (a very
common, often broadly-granted read permission) can read it, which is a
far bigger blast radius than "who has `secretsmanager:GetSecretValue` on
one ARN." See `content/ANTIPATTERNS.md#10-secret-sprawl`.

## THE HARDEN

```bash
# in terraform.tfvars, set harden = true (fill in domain_name/route53_zone_id
# if you have them; otherwise leave both "" for the self-signed fallback)
terraform apply
```

This:

1. Registers a new revision of the **same** task-definition family with
   the secret removed from `environment` and pulled via the `secrets`
   block instead (`valueFrom = <base's secret ARN>`).
2. Turns on Secrets Manager rotation for base's real secret (a small
   generic rotation Lambda at `rotation_lambda/rotate_app_secret.py`) plus
   a resource policy scoping who may ever call `GetSecretValue` on it.
3. Adds an ACM certificate (public+DNS-validated, or self-signed+imported
   -- see prerequisites above) and an HTTPS:443 listener to base's ALB,
   plus a redirect rule so HTTP:80 requests 301 to HTTPS.

**Verify the secret is gone from the task def:**

```bash
aws ecs describe-task-definition \
  --task-definition "$(terraform output -raw demo_task_definition_family)" \
  --query 'taskDefinition.containerDefinitions[0].{environment: environment, secrets: secrets}'
```

**Expected (the harden):**

```json
{
    "environment": [
        {"name": "APP_BUCKET", "value": "..."},
        {"name": "AWS_REGION", "value": "us-east-1"}
    ],
    "secrets": [
        {"name": "APP_API_KEY", "valueFrom": "arn:aws:secretsmanager:...:secret:aws-sec-lab/app-secret-..."}
    ]
}
```

No secret value anywhere in that output -- signal met.

**Verify HTTPS is live:**

```bash
# Public DNS-validated cert:
curl -I "$(terraform output -raw alb_https_url)"

# Self-signed fallback -- -k is required and expected (see prerequisites):
curl -Ik "$(terraform output -raw alb_https_url)"

# Either way, confirm the redirect:
curl -I "http://$(cd ../base && terraform output -raw alb_dns_name)/"
# expect: HTTP/1.1 301 Moved Permanently
#         Location: https://.../
```

**Verify the secret resource-policy Deny holds** (test the deny path --
run this as any principal that is *not* the task execution role or the
rotation Lambda's role, e.g. your own admin CLI identity):

```bash
aws secretsmanager get-secret-value --secret-id "$(terraform output -raw secret_arn)"
# expect: An error occurred (AccessDeniedException) ... explicit deny in a resource-based policy
```

That `AccessDeniedException` is a **success signal**, not a bug -- see
`content/ANTIPATTERNS.md#3-never-actually-testing-a-deny`. (Note: only
`GetSecretValue` is denied. `put-secret-value`, used by `labs/base`'s
own "set the secret value" step, still works for whoever applied base.)

## Full expected output / rationale

See [`SOLUTION.md`](SOLUTION.md).

## Teardown

**Order matters: destroy this lab's layer *before* running `labs/base`'s
daily teardown.** This lab's HTTPS listener, redirect rule, and the
target-group lookup all depend on base's ALB and HTTP listener still
existing -- if base's daily teardown runs first, this module's next
`plan`/`destroy` will fail trying to read a listener that's gone.

```bash
cd labs/day05
terraform destroy
```

Then confirm:

- [ ] `terraform state list` is empty (or the command errors because the
      state file is gone -- either is fine).
- [ ] No HTTPS:443 listener remains on base's ALB (`aws elbv2 describe-listeners
      --load-balancer-arn <base alb_arn>` shows only the HTTP:80 listener).
- [ ] No listener rule remains on the HTTP:80 listener beyond its own
      default action.
- [ ] If you used the public-cert path: the ACM certificate is gone, and
      the Route53 DNS validation `CNAME` record it created is gone too
      (`terraform destroy` deletes both -- confirm in Route53 if you want
      to be sure your zone is clean).
- [ ] The rotation Lambda, its role/policy, and the secret rotation +
      resource policy on base's secret are gone. **Base's secret itself
      (`aws_secretsmanager_secret.app_secret`) is untouched** -- it's
      base's persistent resource, stays up for the whole sprint, and this
      lab never destroys it.
- [ ] The demo task-definition family (`<project>-day05-app`) has no
      active (non-`INACTIVE`) revisions -- `terraform destroy` deregisters
      the one it created; deregistering costs nothing either way.

**Cost note:** ACM certificates -- public/DNS-validated or
self-signed/imported -- are **free** either way; you only pay for **ACM
Private CA** (~$400/month for the CA itself), which is exactly why this
lab never provisions one. The HTTPS listener itself adds a few cents of
LCU usage while it's up, same order of magnitude as the existing HTTP
listener. The rotation Lambda is pay-per-invocation and effectively free
at this scale.

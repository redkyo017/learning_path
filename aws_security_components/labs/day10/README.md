# `labs/day10` — Governance & multi-account

Layers on `labs/base` (apply base first — see its README). This lab is
**mostly design + `terraform plan`-level** for the org-wide pieces (SCPs
require an AWS Organization a single-account learner doesn't have), plus
two things that ARE real and applied: a demo IAM role proving the ABAC +
permission-boundary intersection, and ABAC tags applied for real onto
`labs/base` resources.

> **Authorized testing only.** Everything here targets your own account
> and your own `labs/base` deployment. See
> [`../../content/ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md#authorized-testing-statement).

## Prereqs

- `labs/base` applied (`terraform apply` there first — its `terraform.tfstate`
  is read via `terraform_remote_state`).
- AWS CLI v2 and `python3` on PATH (used by
  `scripts/tag-base-resources.sh`, invoked via `local-exec` — this script
  makes real AWS calls when YOU run `terraform apply`, not during authoring).
- Copy `terraform.tfvars.example` → `terraform.tfvars` and adjust if needed
  (defaults work as-is against a fresh `labs/base`).

## What this creates (real, applied resources)

- `aws_iam_role.abac_demo_role` — trust policy allows your account's root
  to assume it (so you can test with `aws sts assume-role` using your own
  admin credentials). Tagged `Project`/`Environment`/`DataClassification`.
- `aws_iam_role_policy.abac_demo_role_identity` — **the break**: a broad
  identity `Allow` for `s3:GetObject`/`s3:PutObject` on `Resource: "*"`.
  Taken alone, this reaches every bucket in the account.
- `aws_iam_policy.abac_boundary` — **the harden**: a permission boundary
  that only permits that same action when the target resource's `Project`
  tag matches the caller's own `Project` tag
  (`aws:ResourceTag/Project` == `aws:PrincipalTag/Project`). Attached to
  `abac_demo_role` at creation via `permissions_boundary`.
- `null_resource.apply_abac_tags` — runs
  `scripts/tag-base-resources.sh` to apply the same `Project` tag (plus
  `Environment`/`DataClassification`) onto `labs/base`'s task role, S3
  bucket, Secrets Manager secret, and DynamoDB table — WITHOUT editing
  `labs/base`'s own `.tf` files or state.

## What this only plans (org-level, gated off by default)

- `aws_organizations_policy.deny_cloudtrail_tamper` — the SCP answer to
  Exercise 1 ("write an SCP that denies disabling CloudTrail org-wide").
  `count = var.enable_org_resources ? 1 : 0`, and `enable_org_resources`
  defaults to `false`, so `terraform plan`/`apply` never attempts an
  Organizations API call unless you deliberately flip it on from a real
  Organizations **management account**.
- `output.scp_policy_json` is always readable (it's a `data` source, not a
  created resource) — review the JSON with `terraform plan` /
  `terraform output scp_policy_json` regardless of the toggle.

## THE BREAK

1. `terraform apply` (with `enable_org_resources = false`, the default).
2. Note the role's identity policy alone (`abac_demo_role_identity`) would
   grant `s3:GetObject`/`s3:PutObject` on ANY bucket if it were the only
   control in play — confirm by reading the policy:
   ```
   terraform show -json | jq '.values.root_module.resources[] | select(.address=="aws_iam_role_policy.abac_demo_role_identity")'
   ```
   **Expected:** `Resource: "*"` in the policy document — no bucket-level
   restriction anywhere in the identity policy on its own.

## THE HARDEN

1. Confirm the boundary is attached:
   ```
   aws iam get-role --role-name "$(terraform output -raw abac_demo_role_arn | sed 's#.*/##')" \
     --query 'Role.PermissionsBoundary'
   ```
   **Expected:** the ARN of `abac_boundary`, not null.
2. Run the ABAC + permission-boundary proof via the IAM Policy Simulator
   (console: IAM → Policy simulator → select `abac_demo_role`) or the CLI
   (`aws iam simulate-principal-policy`), simulating `s3:GetObject`
   against two resource ARNs:
   - the base app bucket (now tagged `Project=aws-sec-lab` by
     `null_resource.apply_abac_tags`) — pass that tag as a
     `resource-context-entries` value in the simulation.
   - any other bucket ARN NOT carrying that tag.

   **Expected (recorded in `SOLUTION.md`):** `allowed` for the tagged
   bucket, `implicitDeny` for the untagged one — same identity policy,
   same role, different effective permission, because the boundary's
   `Condition` only matches one of them.
3. Separately (SCP precedence — simulator does **not** model SCPs, see
   `SOLUTION.md`): read the written trace proving the SCP `Deny` from
   Exercise 1 wins over any identity `Allow`, unconditionally.

## Exercises

See `content/day10-governance-multiaccount.md` — 4 exercises with hints +
solution sketches, including "write an SCP that denies disabling
CloudTrail org-wide" (answered by `main.tf`'s
`data.aws_iam_policy_document.deny_cloudtrail_tamper`).

## Teardown

```
cd labs/day10
terraform destroy
```

Checklist:

- [ ] `aws_iam_role.abac_demo_role` destroyed (confirm:
      `aws iam get-role --role-name aws-sec-lab-day10-abac-demo` → error).
- [ ] `aws_iam_policy.abac_boundary` destroyed.
- [ ] `aws_iam_role_policy.abac_demo_role_identity` destroyed (inline
      policy — goes with the role automatically, but Terraform destroys it
      as its own resource first).
- [ ] ABAC tags on `labs/base` resources: **leave them** — tags are free,
      and `labs/base`'s own lifecycle (not this module's `destroy`) owns
      those resources. Nothing here re-runs an "untag" step.
- [ ] Org-level SCP: nothing to destroy if `enable_org_resources` stayed
      `false` (the default) — it was never created. If you flipped it on
      against a real Organization, destroy the SCP attachment and policy
      same-day, same as every other day-specific resource.
- [ ] `labs/base` itself is untouched — confirm with
      `cd ../base && terraform plan` showing no changes.

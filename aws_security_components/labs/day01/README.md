# Day 1 lab — tighten the task role's S3 grant

> **Authorized testing only.** Every command below targets IAM
> resources in **your own** deployed `labs/base/` workload, in **your
> own** AWS account. Nothing here is to be pointed at any account,
> role, or resource you do not own and are not explicitly authorized to
> test. See [`content/ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md)
> "Authorized-testing statement" — this lab's break/harden is the
> canonical example that statement covers.

## Objective

`labs/base/iam.tf` gives the ECS task role (`aws_iam_role.task`) one
statement (`BroadButWorkloadScopedAppDataAccess`) that's intentionally
broad **within** the `app_data` bucket: `Get`/`Put`/`Delete`/`List`
across the whole bucket, when the app only actually needs `Get`/`Put`
on one object prefix. This lab:

1. **Breaks** it — proves, with the IAM policy simulator, that unneeded
   actions and unneeded scope currently evaluate as `allowed`.
2. **Hardens** it — layers a second, explicit-Deny identity policy onto
   the *same* role (without editing `labs/base/iam.tf`, which every
   other day of this sprint also depends on) that removes exactly that
   excess.
3. **Re-proves** the same calls now come back `explicitDeny`, while the
   app's actual in-prefix usage still comes back `allowed`.

See [`content/day01-iam-engine.md`](../../content/day01-iam-engine.md)
for the full evaluation-order theory this lab is built on — in
particular "Least privilege without editing the original grant," which
explains *why* an explicit-Deny overlay is the right tool here.

## Prerequisites

- `labs/base` has been `terraform apply`'d and its state file exists at
  `labs/base/terraform.tfstate` (this lab reads its outputs via
  `terraform_remote_state`).
- AWS CLI configured with credentials for the same account/region as
  base, with `iam:SimulatePrincipalPolicy` permission (a read-only,
  side-effect-free call — it does not require the target role's own
  credentials).
- Terraform >= 1.6, AWS provider >= 5.0 — same as base. **Terraform is
  not run by this document's author.** Every `terraform`/`aws` command
  below is yours to run; nothing here executes on your behalf.
- `jq` is convenient but not required (all commands below use
  `--query`/`-raw` instead).

## Step 0 — capture the role and bucket ARNs from base

```bash
cd ../base
TASK_ROLE_ARN=$(terraform output -raw task_role_arn)
BUCKET_ARN=$(terraform output -raw app_bucket_arn)
echo "$TASK_ROLE_ARN"
echo "$BUCKET_ARN"
cd ../day01
```

Keep this shell session open — every command below reuses these two
variables.

> **Note on the hardcoded `app-data`/`other-prefix` literals below.** THE
> BREAK's traces run *before* this module is applied, so they can't yet
> read this module's own Terraform outputs — the resource ARNs are built
> by hand from `$BUCKET_ARN` plus a literal prefix. That literal must
> match `var.app_object_prefix` (default `"app-data"` — see
> `variables.tf`) for the in-prefix case, and must NOT match it for the
> out-of-prefix case; if you change `app_object_prefix` from its default,
> update these commands to match. Once the module IS applied (from THE
> HARDEN onward), you can use the equivalent outputs instead of retyping
> the literal:
> ```bash
> terraform output -raw in_prefix_test_resource_arn        # .../app-data/example.txt
> terraform output -raw out_of_prefix_test_resource_arn    # .../other-prefix/example.txt
> ```

## THE BREAK — prove the over-broad grant, before touching anything

Run these **before** applying this lab's Terraform. Each is one of the
three required policy-evaluation traces; a fourth (in-prefix `GetObject`)
is included as a contrast so you can see what "already fine" looks
like next to what's broken.

**Trace 1 — `s3:DeleteObject`, the app never calls this action:**

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "$TASK_ROLE_ARN" \
  --action-names s3:DeleteObject \
  --resource-arns "${BUCKET_ARN}/app-data/example.txt"
```

**Expected (before harden):** `EvalDecision: "allowed"` — the base
statement's `Action` list includes `s3:DeleteObject` with no scope
limitation beyond "somewhere in this bucket." This is the break: the
app never deletes anything, but the role can.

**Trace 2 (run now, before harden) — `s3:ListBucket`, the second
unneeded action:**

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "$TASK_ROLE_ARN" \
  --action-names s3:ListBucket \
  --resource-arns "$BUCKET_ARN"
```

**Expected (before harden):** `EvalDecision: "allowed"` — same story as
Trace 1: the base statement's `Action` list includes `s3:ListBucket`
with nothing scoping it down, and the app never actually calls it.

**Trace 3 (run now, before harden, for contrast) — `s3:GetObject`
outside the app's actual prefix:**

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "$TASK_ROLE_ARN" \
  --action-names s3:GetObject \
  --resource-arns "${BUCKET_ARN}/other-prefix/example.txt"
```

**Expected (before harden):** `EvalDecision: "allowed"` — the base
grant has no prefix restriction at all, so anywhere in the bucket is in
scope, not just the app's actual working prefix.

Record all three outputs (or just note the `EvalDecision` values) — you'll
re-run the identical commands after hardening and diff the verdicts.

## Apply the day01 module

```bash
cp terraform.tfvars.example terraform.tfvars   # edit if your base region differs
terraform init
terraform plan
terraform apply
```

This attaches one additional inline IAM policy
(`day01-deny-out-of-scope-s3-access`) to the **same** task role. It
does not create, modify, or destroy anything in `labs/base` — the
original over-broad statement in `labs/base/iam.tf` is left exactly as
it was.

## THE HARDEN — re-run the same three traces

**Trace 1 again — `s3:DeleteObject`:**

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "$TASK_ROLE_ARN" \
  --action-names s3:DeleteObject \
  --resource-arns "${BUCKET_ARN}/app-data/example.txt"
```

**Expected (after harden):** `EvalDecision: "explicitDeny"`, with
`MatchedStatements` naming the day01 overlay's `DenyDeleteAndListWholeBucket`
statement — not the base statement, which is still there and still
says `Allow`, but the explicit Deny in the *other* identity policy now
attached to the same role wins.

**Trace 2 — `s3:ListBucket`, the second unneeded action:**

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "$TASK_ROLE_ARN" \
  --action-names s3:ListBucket \
  --resource-arns "$BUCKET_ARN"
```

**Expected (after harden):** `EvalDecision: "explicitDeny"`, matched
statement `DenyDeleteAndListWholeBucket`.

**Trace 3 again — `s3:GetObject` outside the app's prefix:**

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "$TASK_ROLE_ARN" \
  --action-names s3:GetObject \
  --resource-arns "${BUCKET_ARN}/other-prefix/example.txt"
```

**Expected (after harden):** `EvalDecision: "explicitDeny"`, matched
statement `DenyGetPutOutsideAppPrefix`.

**Contrast check — confirm the app's actual usage still works:**

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "$TASK_ROLE_ARN" \
  --action-names s3:GetObject s3:PutObject \
  --resource-arns "${BUCKET_ARN}/app-data/example.txt"
```

**Expected (after harden):** both `EvalDecision: "allowed"` — the
overlay only denies `DeleteObject`/`ListBucket` and out-of-prefix
`Get`/`Put`; in-prefix `Get`/`Put` is untouched and still comes from
the original base `Allow`.

Exact expected JSON fragments and the equivalent live-call
`AccessDenied` error text are recorded in [`SOLUTION.md`](SOLUTION.md).

## Why the simulator, not a live `aws s3api` call

The task role's trust policy (`data.aws_iam_policy_document.ecs_tasks_assume`
in `labs/base/iam.tf`) only allows `ecs-tasks.amazonaws.com` to assume
this role — deliberately, so nothing else in the account can. That
means your own IAM identity cannot `sts:AssumeRole` into it to get real
temporary credentials for a live test, and weakening the trust policy
just to make this lab's test easier would itself be a security
regression. The simulator evaluates the role's real, live attached
policies (exactly what's shown above) without ever needing to hold its
credentials — see `content/day01-iam-engine.md`'s tools section for
what it does and doesn't cover. (A genuinely live credential-theft path
against this same role exists — via the app's SSRF endpoint — but
that's Day 8/11's lesson, not today's.)

## Teardown checklist

This lab's only footprint is one free, inline IAM policy — no hourly
billing impact, nothing to wait on.

```bash
terraform destroy
```

Confirm:

- [ ] `terraform state list` (in `labs/day01`) is empty.
- [ ] `aws iam list-role-policies --role-name <task-role-name>` no
      longer lists `day01-deny-out-of-scope-s3-access`.
- [ ] Re-running Trace 1/2/3 above against `$TASK_ROLE_ARN` returns to
      `allowed` again (base's original over-broad statement is
      untouched and still there) — this confirms the lesson is
      re-runnable from a clean "before" state.
- [ ] `labs/base` itself is **not** touched — do not run
      `terraform destroy` inside `labs/base`; base stays up for the
      rest of the sprint per the top-level teardown model.

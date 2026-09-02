# Day 2 lab — PROMOTE: a CodePipeline V2 promotion machine

This lab provisions a CodePipeline V2 pipeline —
`Source → Build → DeployStaging → Approval → DeployProd` — with its own
CodePipeline-driven CodeBuild project for the `Build` stage, running Day 1's
`buildspec.yml` reused unedited (Day 1's project stays as-is, since a
project's source/artifacts types commit it to one invocation mode — see
`content/day02.md`), plus an IAM OIDC identity provider and role scoped for
GitHub Actions to push images to the foundation ECR repo with no long-lived
AWS credentials at all.

## Goal

Stand up a pipeline where **one image digest travels from source to a
prod-approval gate without ever being rebuilt**, and a GitHub Actions
workflow that authenticates to AWS purely via a short-lived OIDC token.

## Success signal

- `aws codepipeline get-pipeline-state --name <pipeline_name>` shows the
  execution progressing `Source → Build → DeployStaging → Approval` stage
  by stage, with exactly **one** `Build` action having run.
- The digest recorded in the `Build` stage's `imageDetail.json` output
  matches the digest `DeployStaging` and `DeployProd` both consumed as
  input — you can confirm this by inspecting each action's execution
  details in the console, or by downloading the artifact zips from the S3
  bucket named in this stack's `artifact_bucket_name` output.
- In short: **one digest travels from source to prod-approval without a
  rebuild.**

## Prerequisites

- `labs/foundation/` already applied (Day 1).
- `labs/day01/` done — this lab does not read Day 1's Terraform state (it
  declares its own CodeBuild project rather than reusing Day 1's; see
  `content/day02.md`'s "one buildspec, two CodeBuild projects" passage for
  why), but you should still have done Day 1 first: this lab reuses Day 1's
  `buildspec.yml` file verbatim, and the lab builds on Day 1's artifact
  identity concepts.
- Day 0 complete: a CodeConnections → GitHub connection in `AVAILABLE`
  state, and your own GitHub repo containing `app/`.

## Run steps

```bash
cd labs/day02
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

- `codeconnection_arn` — the connection ARN from Day 0, step 4.
- `github_owner`, `github_repo` — your GitHub username and repo from Day 0,
  step 6.
- `github_branch` — leave as `main` unless you're using something else.

```bash
terraform init
terraform plan
terraform apply
```

Once applied, wire up GitHub Actions (optional but recommended, so you can
compare both promotion mechanisms side by side):

```bash
terraform output github_oidc_role_arn
```

Copy `github-actions-workflow.yml.example` to `.github/workflows/build.yml`
in your own repo, replace `<YOUR_GHA_OIDC_ROLE_ARN>` with that output and
`<YOUR_ECR_REPOSITORY_NAME>` with the foundation stack's
`ecr_repository_name` output, and push to `main`. Watch the job authenticate
via OIDC — no `AWS_ACCESS_KEY_ID` secret anywhere in the repo.

Trigger the CodePipeline pipeline by pushing a change under `app/` on
`github_branch` (the pipeline's `trigger` block only starts an execution
for pushes touching `app/**` on that branch — a docs-only push won't start
it), or start an execution manually:

```bash
aws codepipeline start-pipeline-execution --name "$(terraform output -raw pipeline_name)"
```

Watch it progress:

```bash
aws codepipeline get-pipeline-state --name "$(terraform output -raw pipeline_name)"
```

When it reaches the `Approval` stage, open the pipeline in the console, read
the `Build` stage's `imageDetail.json` to see the digest being promoted,
then approve.

## Break it / Fix it

**The break:** swap the OIDC role's correct trust policy for the
commented-out wildcard variant.

1. Open `oidc.tf`. Comment out the real `aws_iam_role.gha_oidc` resource
   block (the one using `StringEquals` on both `:aud` and `:sub`).
2. Uncomment **Variant A** (`gha_oidc_wildcard_sub`, using `StringLike` and
   `repo:${var.github_owner}/${var.github_repo}:*`) and rename it back to
   `gha_oidc` so it replaces the role in place, so
   `aws_iam_role_policy.gha_oidc_ecr_push`'s `role = aws_iam_role.gha_oidc.id`
   reference still resolves.
3. `terraform apply` and confirm the trust policy on the role now uses the
   wildcard.
4. **Reason about — do not perform** — what a pull request opened from a
   fork of your repo could now reach with the temporary credentials this
   trust policy would hand out. Work through Exercise 2 in
   `content/day02.md` if you haven't already; the enumerated blast radius
   is also in `SOLUTION.md` below.
5. Restore the original block (delete or re-comment the wildcard variant,
   uncomment/restore the correct `StringEquals` version), `terraform apply`
   again, and confirm the trust policy is back to the exact-match form.
6. Write one sentence stating exactly what the wildcard granted — put it in
   your own notes, or compare against the one-sentence answer in
   `SOLUTION.md`.

**Do not actually open a pull request from a fork to test this against a
real AWS account.** The exercise is to reason through the blast radius, not
to demonstrate it — see `SOLUTION.md` for why "prove it happened" isn't the
point here.

## What Day 3 changes

`DeployStaging` and `DeployProd` in this lab are placeholder CodeBuild
actions that just echo the digest they received — real deployment work.
Day 3 replaces both with actual CodeDeploy blue/green actions against an
ECS Fargate service behind an ALB, with a CloudWatch alarm wired as an
automatic rollback trigger. The pipeline shape (five stages, one digest
promoted through all of them) does not change — only what `DeployStaging`
and `DeployProd` actually do changes.

## Teardown

See `teardown.md`. Short version: `terraform destroy`, then handle the S3
bucket if it isn't empty, then `bash ../verify-teardown.sh`. Leave
`labs/foundation/` running.

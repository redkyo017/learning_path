# Teardown — Day 5, and the end of the whole path

This is not just this lab's teardown. Day 5 is the last day, so this file is also the **end-of-week
sequence** for everything you've built since Day 0. Follow the order below exactly — it isn't
arbitrary. Later steps depend on earlier ones being fully gone (the foundation VPC can't be deleted
while an ALB or ENI still references it, exactly as `labs/foundation/teardown.md` describes).

## Step 1 — stop the canary FIRST

**Before anything else, including `terraform destroy` in this directory.** A running Synthetics
canary is a self-scheduling process — it fires every 5 minutes on its own, independent of whether you
touch Terraform. If you start tearing other things down while the canary is still running, it keeps
invoking its Lambda and writing new objects into its S3 artifact bucket every 5 minutes, which means
whatever you deleted from that bucket a moment ago gets partially repopulated before you get back to
it. Stop it first so it stays stopped:

```bash
aws synthetics stop-canary --name <name_prefix>-readyz
```

Confirm it's actually stopped, not just told to stop (Synthetics canaries take a few seconds to
transition):

```bash
aws synthetics get-canary --name <name_prefix>-readyz \
  --query 'Canary.Status.State'
# wait for "STOPPED", not "STOPPING"
```

## Step 2 — empty the capstone pipeline's artifact bucket, then destroy `labs/day05`

The capstone pipeline (Ruling C5) has its own S3 artifact bucket, `aws_s3_bucket.pipeline_artifacts`,
created **without** `force_destroy` — the same deliberate choice, for the same reason, as Day 2's
pipeline artifact bucket (see `labs/day02/teardown.md`). If the pipeline ran even once in Step 2 of
`README.md`, this bucket holds at least one execution's source/build zips, and `terraform destroy`
will fail on it:

```bash
cd labs/day05
BUCKET=$(terraform output -raw capstone_artifact_bucket_name 2>/dev/null || echo "<name_prefix>-capstone-artifacts-<ACCOUNT_ID>")
aws s3 rm "s3://${BUCKET}" --recursive
terraform destroy
```

This removes the p99 alarm, the composite alarm, the capstone pipeline (and its CodeBuild project,
IAM roles, and artifact bucket once emptied above), the canary itself, its IAM role, its S3 artifact
bucket, and the dashboard. Two things `terraform destroy` here removes even though they were never
declared as their own resource in `main.tf`:

- **The canary's Lambda function** — `aws_synthetics_canary` creates one behind the scenes to
  actually execute `canary.js.example` on schedule. Destroying the canary resource removes it, but if
  you ever deleted "the canary" by hand in the console instead of through Terraform, check for an
  orphaned `cwsyn-<name>-*` Lambda function separately.
- **The canary's S3 artifact bucket contents** — `force_destroy = true` in `main.tf` means `terraform
  destroy` empties and removes *this* bucket (the canary's, not the pipeline's above) even if the
  canary wrote objects into it since the last apply.

Verify no orphan remains:

```bash
aws synthetics get-canary --name <name_prefix>-readyz 2>&1 | grep -i "ResourceNotFoundException" \
  && echo "canary gone, good" || echo "canary still present, investigate"

aws s3api head-bucket --bucket <name_prefix>-canary-artifacts-<ACCOUNT_ID> 2>&1 \
  | grep -i "Not Found" && echo "bucket gone, good" || echo "bucket still present, investigate"
```

**One more thing `terraform destroy` never removes: the canary's own CloudWatch log group.**
`aws_synthetics_canary` causes AWS to auto-create `/aws/lambda/cwsyn-<name_prefix>-readyz-<id>` the
first time the canary runs, with **never-expire retention** — it is not a Terraform resource in
`main.tf`, so `terraform destroy` has nothing to target. Left alone, this is a slow, permanent
leak: exactly the "never-expiring log retention" anti-pattern named in `content/day05.md`. Find and
delete it:

```bash
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/lambda/cwsyn-<name_prefix>-readyz" \
  --query 'logGroups[].logGroupName' --output text

aws logs delete-log-group --log-group-name "/aws/lambda/cwsyn-<name_prefix>-readyz-<id>"
```

## Step 3 — destroy `labs/day03` (the ALB)

This is the resource that dominated the week's cost (see `content/day05.md` Core Concepts §9) and it
must go now, not later — every step after this one depends on the ALB (and anything attached to it:
target group, security group, ENIs) being gone before the shared VPC underneath it can be removed.

```bash
cd ../day03
terraform destroy
```

If this fails partway, see `labs/foundation/teardown.md`'s "common failure" section — it's almost
always a leftover ENI or security group still attached to the VPC because something here didn't fully
clear.

## Step 4 — destroy `labs/day02` — empty the S3 artifact bucket FIRST

CodePipeline's artifact bucket accumulates build/deploy artifacts over the week and, like the canary
bucket above, `terraform destroy` fails on a non-empty bucket unless the bucket was created with
`force_destroy = true`. Check, and empty it by hand if needed, before destroying:

```bash
cd ../day02
BUCKET=$(terraform output -raw artifact_bucket_name)
aws s3 rm "s3://${BUCKET}" --recursive
terraform destroy
```

## Step 5 — destroy `labs/day01`, if still present

By this point in the week you may well have already torn Day 1 down after its own session — this
step is a **verification pass, not an assumed-live destroy**. Check first:

```bash
cd ../day01
terraform show 2>&1 | head -5
```

If it shows real resources, destroy it:

```bash
terraform destroy
```

If it shows an empty state (or no state file), there's nothing to do here — move on.

## Step 6 — destroy `labs/foundation`, if still present

Same verification-pass framing as Step 5. This should be the very last Terraform-managed thing left
standing from the whole path — see `labs/foundation/teardown.md` for why it has to be last (every
other lab reads its VPC and ECR repo via `terraform_remote_state`, so destroying it early breaks
labs that haven't run yet; by Day 5's end nothing should be relying on it anymore).

```bash
cd ../foundation
terraform show 2>&1 | head -5   # verify it's still there before assuming so
terraform destroy               # if it is
```

## Step 7 — run the verification script

```bash
cd ..
bash verify-teardown.sh
```

**Require a clean result before you consider the week done.** A clean Terraform exit code only proves
Terraform cleared what it tracked in state — it says nothing about resources CodeDeploy, ECS, or
CloudWatch Synthetics created outside Terraform's view (the canary's Lambda function is exactly that
kind of resource). This script's read-only `describe-*`/`list-*` calls are the independent check.

## Step 8 — the 24-hour Cost Explorer check

Come back **tomorrow**, not today, and check Cost Explorer filtered to the `Project` tag
(`<name_prefix>`, default `awsdevops`) you've been stamping on every resource all week via
`default_tags`. Some charges — Synthetics canary runs, data transfer, the last hour of an ALB's
existence — land in billing with up to a 24-hour delay, so a $0 check performed five minutes after
Step 7 can look clean and still be wrong.

```text
Cost Explorer → Filter → Tag → Project = <name_prefix> → Group by: Service
```

Confirm the trend is flat-to-zero from this point forward. If something is still accruing, it's
almost always the canary (Step 1) or the ALB (Step 3) — go back and re-verify those two first.

**Finishing the week with a verified $0 run rate is itself a professional habit worth keeping** — not
a chore tacked onto the end of a lab. The same discipline (tag everything, verify teardown with a
read-only script instead of trusting memory, check billing a day later because some charges lag) is
exactly what keeps a real team's AWS bill from becoming a surprise instead of a forecast.

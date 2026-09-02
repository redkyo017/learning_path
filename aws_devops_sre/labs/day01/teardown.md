# Teardown — Day 1

**Leave `labs/foundation/` running.** It stays up for the whole week; only
this day's lab gets destroyed now. See `../foundation/teardown.md` if
you're not sure why.

**Before you destroy: it's worth knowing exactly what Day 2 does and does
not need from this stack.** Day 2 declares its own CodeBuild project for
CodePipeline to drive — it does not read this stack's
`codebuild_project_name` output via `terraform_remote_state` (see
`content/day02.md`'s passage on why one CodeBuild project can't serve both a
standalone `GITHUB`-source build and a `CODEPIPELINE`-source one). So
`terraform destroy` here is safe to run at the end of any session; it will
not break Day 2's `terraform apply`. The one thing Day 2 (and every day
after it) still needs is `labs/foundation/` — **do not destroy that** — for
its VPC and ECR repository outputs.

## Steps

1. **Destroy this lab's resources.**

   ```bash
   cd labs/day01
   terraform destroy
   ```

   This removes the CodeBuild project, its IAM role and inline policy, and
   the CloudWatch Logs group (`aws_cloudwatch_log_group.codebuild` is
   Terraform-managed here, so it's destroyed along with everything else in
   state).

2. **Check for a log group Terraform doesn't know about.**

   CodeBuild will auto-create the `/aws/codebuild/awsdevops-build` log
   group the moment a build actually runs, even if that run happened
   before `terraform apply` finished (for example, if you ran
   `start-build` while `apply` was still mid-flight, or against a project
   from a previous partial apply). An auto-created log group is a real AWS
   resource but it is never imported into Terraform state just because the
   project that wrote to it is in state — so `terraform destroy` will not
   find it if it somehow diverged from the one this stack manages. In
   practice this rarely happens (the log group in state is the one the
   project always writes to), but it's worth a manual check:

   ```bash
   aws logs describe-log-groups \
     --log-group-name-prefix /aws/codebuild/awsdevops-build \
     --query 'logGroups[*].logGroupName'
   ```

   If anything is still listed after `terraform destroy` completed, delete
   it directly:

   ```bash
   aws logs delete-log-group --log-group-name /aws/codebuild/awsdevops-build
   ```

3. **Run the teardown verification script.**

   ```bash
   bash ../verify-teardown.sh
   ```

   This is a read-only audit — it never deletes anything itself, it only
   tells you what's still billable. Run it after every `terraform destroy`
   in this path, not just this one.

## Cost after teardown

**$0.00.** CodeBuild bills per build-minute with no hourly meter, so there
is nothing left accruing once the project is destroyed. The ECR image you
pushed during the lab is well under a cent to store and is meant to stay —
it's the evidence this lab's Success Criterion asks for, and Day 2's own
pipeline will push new images alongside it rather than requiring this one —
so there's no need to delete it from `labs/foundation/`'s ECR repository.

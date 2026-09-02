# Teardown — foundation stack

**Do not destroy this stack until after Day 5.** Every day lab in this path
reads the VPC, subnets, and ECR repository this stack creates via
`terraform_remote_state`. Destroying it early breaks every lab that hasn't
run yet, and can leave later labs' Terraform state pointing at resources
that no longer exist.

## End-of-week sequence

Run these in order, only after you have finished (and torn down) Day 1
through Day 5:

1. **Confirm every day lab is already destroyed.** From each `labs/dayNN/`
   directory: `terraform destroy`. This stack should be the last thing left
   standing.

2. **Destroy the foundation stack:**

   ```bash
   cd labs/foundation
   terraform destroy
   ```

3. **Run the teardown verification script:**

   ```bash
   bash ../verify-teardown.sh
   ```

4. **Manually check the AWS Console (or CLI) for anything that survived:**
   - No ECR repository named `${name_prefix}-sample` (default:
     `awsdevops-sample`).
   - No VPC tagged `Project = ${name_prefix}` (default: `awsdevops`).
   - No leftover Elastic IPs, ENIs, or security groups referencing that VPC.

## The common failure: destroy fails on the VPC

If you run `terraform destroy` in `labs/foundation/` and it fails trying to
delete the VPC (or a subnet), the almost-certain cause is that **something
from a day lab is still attached to this VPC** — most commonly:

- **Day 3's ALB** — if it (or its target group, or its security group) still
  exists, the VPC can't be deleted underneath it.
- **A leftover ENI** — Fargate tasks (Day 3) or other ENI-owning resources
  that weren't fully destroyed leave dangling network interfaces attached to
  the public subnets, which blocks subnet deletion.

**The fix is not to force-delete the VPC.** Go back to the day lab that
still owns the offending resource, `terraform destroy` it there first, then
retry `terraform destroy` here.

This ordering dependency — day labs before the foundation stack, always — is
itself the lesson: shared infrastructure that other stacks build on top of
can only be torn down after everything built on top of it is gone. It's the
same dependency direction you'd hit tearing down a shared VPC in a real
multi-team AWS account.

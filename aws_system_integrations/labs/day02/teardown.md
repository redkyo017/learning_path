# Day 2 Lab — Teardown

## Estimated cost if left running

| Resource | Rate | Per day |
|---|---|---|
| ALB | ~$0.0225/hour base + LCU usage | ~$0.54+ |
| 2 × t3.micro EC2 | ~$0.0104/hour each | ~$0.50 combined |
| **Total** | | **~$1.05/day** |

Destroy the lab immediately after completing exercises.

---

## Step 1 — Terraform destroy

```bash
cd aws_system_integrations/labs/day02
terraform destroy
```

Review the destroy plan. Confirm by typing `yes` when prompted.

Terraform will destroy resources in dependency order:
1. `aws_lb_listener_rule.header_v2`
2. `aws_lb_listener.http`
3. `aws_lb.main`
4. `aws_lb_target_group_attachment.v1`, `aws_lb_target_group_attachment.v2`
5. `aws_lb_target_group.v1`, `aws_lb_target_group.v2`
6. `aws_instance.api_v1`, `aws_instance.api_v2`
7. `aws_security_group.ec2`, `aws_security_group.alb`

---

## Step 2 — Verify in the AWS console

After `terraform destroy` completes, confirm in the console:

- **ALB deleted:** EC2 → Load Balancers → confirm no entry named `lab-day02-alb`
- **Target groups deleted:** EC2 → Target Groups → confirm no entries named `lab-day02-v1-tg` or `lab-day02-v2-tg`
- **EC2 instances terminated:** EC2 → Instances → filter by Name `lab-day02-*` → state should be `terminated` (not stopped — terminated)
- **Security groups deleted:** EC2 → Security Groups → confirm no entries named `lab-day02-alb-sg` or `lab-day02-ec2-sg`
- [ ] WAF Web ACL deleted: `aws wafv2 list-web-acls --scope REGIONAL --region $AWS_REGION` → verify no lab-day02* entries

---

## Step 3 — Manual security group cleanup (if needed)

Security groups with active ENI dependencies may not be deleted by `terraform destroy` if the dependency graph is not fully resolved. If you see security groups remaining after destroy:

```bash
# Find the security group IDs:
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=lab-day02-*" \
  --query "SecurityGroups[*].[GroupId,GroupName]" \
  --output table \
  --region ap-southeast-1

# Delete each by ID:
aws ec2 delete-security-group \
  --group-id sg-XXXXXXXXXXXXXXXXX \
  --region ap-southeast-1
```

If delete fails with `DependencyViolation`, a network interface is still referencing the security group. Find the ENI:

```bash
aws ec2 describe-network-interfaces \
  --filters "Name=group-id,Values=sg-XXXXXXXXXXXXXXXXX" \
  --query "NetworkInterfaces[*].[NetworkInterfaceId,Status,Description]" \
  --output table \
  --region ap-southeast-1
```

If the ENI is an orphaned ALB ENI, wait 5–10 minutes after the ALB is deleted — ALB ENIs are cleaned up asynchronously.

---

## Step 4 — Confirm no Terraform state drift

```bash
terraform show
```

The output should be empty (no resources in state). If resources remain, re-run `terraform destroy` or remove them manually and then run `terraform state rm <resource_address>`.

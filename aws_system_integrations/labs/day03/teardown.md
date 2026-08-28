# Day 3 Lab — Teardown Checklist

Interface Endpoints cost **$0.01/hour per AZ** even when idle. Two endpoints across two AZs in this lab = $0.04/hour (~$29/month if left running). Run teardown promptly after you finish.

---

## Primary teardown

```bash
terraform destroy
```

Confirm the plan shows all resources being destroyed, then type `yes`.

---

## Post-destroy verification checklist

After `terraform destroy` completes, verify the following manually in the AWS console or CLI. Terraform occasionally fails to clean up certain resources if a dependency is in an unusual state.

### VPC Endpoints (highest priority — hourly cost)

```bash
aws ec2 describe-vpc-endpoints \
  --filters "Name=tag:Environment,Values=day03lab" \
  --query "VpcEndpoints[*].{ID:VpcEndpointId,State:State,Type:VpcEndpointType}"
```

Expected: empty list. If any endpoint shows `deleting` or `available`, manually delete:
```bash
aws ec2 delete-vpc-endpoints --vpc-endpoint-ids vpce-XXXXXXXX
```

### VPC Endpoint Service (PrivateLink provider)

```bash
aws ec2 describe-vpc-endpoint-services \
  --filters "Name=tag:Environment,Values=day03lab" \
  --query "ServiceDetails[*].{Name:ServiceName,State:ServiceState}"
```

Expected: empty list.

### NLB (accrues hourly cost if not deleted)

```bash
aws elbv2 describe-load-balancers \
  --query "LoadBalancers[?contains(LoadBalancerName,'day03lab')]"
```

Expected: empty list.

### Lambda Function

```bash
aws lambda list-functions \
  --query "Functions[?contains(FunctionName,'day03lab')].FunctionName"
```

Expected: empty list.

### EC2 Instance (mock vault)

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Environment,Values=day03lab" \
            "Name=instance-state-name,Values=running,stopped,pending" \
  --query "Reservations[*].Instances[*].{ID:InstanceId,State:State.Name}"
```

Expected: empty list or `terminated`.

### S3 Bucket

The bucket has `force_destroy = true` set — Terraform destroy will empty and delete it automatically. If `terraform destroy` fails for any reason and manual cleanup is needed:
```bash
# Only run this if terraform destroy failed to clean up the bucket
aws s3 rm s3://day03lab-transaction-logs-<account_id> --recursive
aws s3 rb s3://day03lab-transaction-logs-<account_id>
```

### CloudWatch Log Groups (VPC Flow Logs)

Flow Logs to CloudWatch are charged at **~$0.50/GB ingested** and **$0.03/GB/month** stored. Delete the log group:
```bash
aws logs delete-log-group \
  --log-group-name /vpc/flow-logs/day03lab-consumer
```

### Route 53 Private Hosted Zone

Private Hosted Zones cost $0.50/month. Verify deleted:
```bash
aws route53 list-hosted-zones \
  --query "HostedZones[?Name=='internal.example.com.']"
```

### VPCs

```bash
aws ec2 describe-vpcs \
  --filters "Name=tag:Environment,Values=day03lab" \
  --query "Vpcs[*].{ID:VpcId,CIDR:CidrBlock}"
```

Expected: empty list.

---

## Estimated cost if left running

| Resource | Rate | Monthly estimate |
|----------|------|-----------------|
| SQS Interface Endpoint (2 AZs) | $0.01/hr × 2 | ~$14.60 |
| Vault Interface Endpoint (2 AZs) | $0.01/hr × 2 | ~$14.60 |
| NLB (vault) | ~$0.008/hr LCU + fixed | ~$16.00 |
| EC2 t3.micro (mock vault) | ~$0.0116/hr | ~$8.50 |
| VPC Flow Logs (low traffic) | ~$0.50/GB | < $1.00 |
| **Total if forgotten** | | **~$55/month** |

Gateway Endpoints (S3) are free. IAM roles, security groups, route tables, and subnets are free.

---

## Notes

- Do not run `terraform destroy` against a production account.
- If `terraform destroy` fails mid-way, run it again — Terraform will retry only the remaining resources.
- If you created a real `terraform.tfvars` file with sensitive values, delete it after teardown: `rm terraform.tfvars`.

# Day 41 Lab: Teardown

## Important Note

This is an **authored lab**. No Terraform resources are created. There is nothing to tear down.

## Reference: If This Were a Real Deployment

If you had run `terraform apply` on this Day 41 lab, here's what you would need to clean up:

### ALB and Related Resources
```bash
# Delete listeners
aws elbv2 delete-listener \
  --listener-arn arn:aws:elasticloadbalancing:ap-southeast-1:...:listener/app/dev-wso2-gw/.../... \
  --region ap-southeast-1

# Delete target group
aws elbv2 delete-target-group \
  --target-group-arn arn:aws:elasticloadbalancing:ap-southeast-1:...:targetgroup/dev-wso2-gw/... \
  --region ap-southeast-1

# Delete load balancer
aws elbv2 delete-load-balancer \
  --load-balancer-arn arn:aws:elasticloadbalancing:ap-southeast-1:...:loadbalancer/app/dev-wso2-gw/... \
  --region ap-southeast-1
```

### Security Groups
```bash
aws ec2 delete-security-group \
  --group-id sg-xxxxxxxx \
  --region ap-southeast-1
```

### Task Definitions (GW, TM)
```bash
aws ecs deregister-task-definition \
  --task-definition dev-wso2-gw:1 \
  --region ap-southeast-1
aws ecs deregister-task-definition \
  --task-definition dev-wso2-tm:1 \
  --region ap-southeast-1
```

### Easier Approach: Use Terraform

```bash
cd labs/phase3/day41
terraform destroy -var-file=terraform.tfvars
```

**Note:** When destroying, Terraform will:
1. Delete the ALB and listeners
2. Delete the target group
3. Delete security groups
4. Deregister task definitions
5. Delete log groups
6. Delete IAM roles (if no dependencies remain)
7. Delete ECS cluster (if empty)

## What Terraform Would Track

If this lab were deployed, Terraform would add to Day 40 resources:
- 2 more ECS task definitions (GW, TM)
- 2 more CloudWatch log groups (GW, TM)
- 1 Application Load Balancer
- 1 ALB target group
- 2 ALB listeners (HTTPS + HTTP)
- 1 ALB security group

Total new resources: ~9 (plus all Day 40 resources)

## Cleanup Order

If manually deleting (not using Terraform):
1. Deregister task definitions
2. Delete ALB (listeners and target groups are deleted automatically)
3. Delete security groups
4. Delete ECS cluster (if empty)
5. Delete IAM roles
6. Delete CloudWatch log groups

## Cost Implications

If these resources were deployed:
- **ALB:** ~$16/month (US region; varies by region)
- **NAT gateway:** ~$32/month (if used)
- **ECS tasks:** ~$0.001 per vCPU-hour (Fargate pricing)
- **CloudWatch logs:** Minimal for 7-day retention

**Recommendation:** Always use `terraform destroy` to ensure complete cleanup and avoid surprise charges.

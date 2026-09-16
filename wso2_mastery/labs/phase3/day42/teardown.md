# Day 42 Lab: Teardown

## Important Note

This is an **authored lab**. No Terraform resources are created. There is nothing to tear down.

## Reference: If This Were a Real Deployment

If you had run `terraform apply` on this Day 42 lab, here's what you would need to clean up (in reverse order of creation):

### Auto Scaling and Load Balancer

```bash
# Delete autoscaling policies (they disable themselves; no explicit delete needed)
# Delete autoscaling targets
aws application-autoscaling deregister-scalable-target \
  --service-namespace ecs \
  --resource-id service/dev-wso2/dev-wso2-gw \
  --scalable-dimension ecs:service:DesiredCount \
  --region ap-southeast-1

aws application-autoscaling deregister-scalable-target \
  --service-namespace ecs \
  --resource-id service/dev-wso2/dev-wso2-tm \
  --scalable-dimension ecs:service:DesiredCount \
  --region ap-southeast-1

# Delete ALB listeners
aws elbv2 delete-listener --listener-arn arn:aws:elasticloadbalancing:... --region ap-southeast-1

# Delete target group
aws elbv2 delete-target-group --target-group-arn arn:aws:elasticloadbalancing:... --region ap-southeast-1

# Delete load balancer
aws elbv2 delete-load-balancer --load-balancer-arn arn:aws:elasticloadbalancing:... --region ap-southeast-1
```

### Security Groups (must be done after ALB is deleted)

```bash
# Delete security groups
aws ec2 delete-security-group --group-id sg-gw-xxxxxxxx --region ap-southeast-1
aws ec2 delete-security-group --group-id sg-cp-xxxxxxxx --region ap-southeast-1
aws ec2 delete-security-group --group-id sg-is-xxxxxxxx --region ap-southeast-1
aws ec2 delete-security-group --group-id sg-tm-xxxxxxxx --region ap-southeast-1
aws ec2 delete-security-group --group-id sg-alb-xxxxxxxx --region ap-southeast-1
```

### Task Definitions and ECS Resources

```bash
# Deregister task definitions
aws ecs deregister-task-definition --task-definition dev-wso2-cp:1 --region ap-southeast-1
aws ecs deregister-task-definition --task-definition dev-wso2-is:1 --region ap-southeast-1
aws ecs deregister-task-definition --task-definition dev-wso2-gw:1 --region ap-southeast-1
aws ecs deregister-task-definition --task-definition dev-wso2-tm:1 --region ap-southeast-1

# Delete ECS cluster (must be empty)
aws ecs delete-cluster --cluster dev-wso2 --region ap-southeast-1
```

### IAM Roles

```bash
# Delete task role policy and role
aws iam delete-role-policy --role-name dev-wso2-ecs-task --policy-name wso2-secrets-read
aws iam delete-role --role-name dev-wso2-ecs-task
aws iam delete-role-policy --role-name dev-wso2-ecs-execution --policy-name AmazonECSTaskExecutionRolePolicy
aws iam delete-role --role-name dev-wso2-ecs-execution
```

### CloudWatch Log Groups

```bash
aws logs delete-log-group --log-group-name /ecs/dev/wso2-cp --region ap-southeast-1
aws logs delete-log-group --log-group-name /ecs/dev/wso2-is --region ap-southeast-1
aws logs delete-log-group --log-group-name /ecs/dev/wso2-gw --region ap-southeast-1
aws logs delete-log-group --log-group-name /ecs/dev/wso2-tm --region ap-southeast-1
```

## Easier Approach: Terraform Destroy

```bash
cd labs/phase3/day42
terraform destroy -var-file=terraform.tfvars
```

Terraform handles all dependencies in reverse order and is much safer than manual cleanup.

## What Terraform Would Track

Total resources created in Day 42 (all three days combined):
- 1 ECS cluster
- 1 ECS cluster capacity provider configuration
- 4 ECS task definitions (CP, IS, GW, TM)
- 2 IAM roles (execution, task)
- 1 IAM role policy (task secrets)
- 4 CloudWatch log groups
- 1 Application Load Balancer
- 1 ALB target group
- 2 ALB listeners (HTTPS + HTTP)
- 5 Security groups (ALB, GW, CP, IS, TM)
- 2 App Auto Scaling targets (GW, TM)
- 2 App Auto Scaling policies (GW, TM)

**Total: ~27 AWS resources**

## Cost Estimate (if deployed for 1 month)

| Resource | Estimated Cost | Notes |
|----------|---|---|
| ALB | $16 | ~$0.16/day in most regions |
| ECS Fargate tasks (4 @ 1 vCPU/task avg) | $60 | ~$0.001/vCPU-hour |
| CloudWatch logs (7-day retention, 4 log groups) | $5 | Minimal with 7-day retention |
| ECS cluster | $0 | No charge for cluster itself |
| IAM roles, SGs, autoscaling | $0 | No charge |
| **Total** | ~$81 | Rough estimate; vary by region and actual traffic |

**Recommendation:** Always run `terraform destroy` to avoid surprise AWS bills.

## Preventing Accidental Resource Costs

Add to `terraform.tfvars` or use `-auto-approve=false` (default) to confirm destroys:
```hcl
# Always use interactive approval for destroy
terraform destroy  # (prompts for confirmation)
```

Or use AWS Cost Explorer to monitor charges in real-time.

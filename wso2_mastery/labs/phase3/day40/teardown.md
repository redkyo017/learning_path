# Day 40 Lab: Teardown

## Important Note

This is an **authored lab**. No Terraform resources are created. There is nothing to tear down.

## Reference: If This Were a Real Deployment

If you had run `terraform apply` on this Day 40 lab, here's what you would need to clean up:

1. **Delete ECS task definitions** (if any tasks were running):
   ```bash
   aws ecs deregister-task-definition \
     --task-definition dev-wso2-cp:1 \
     --region ap-southeast-1
   aws ecs deregister-task-definition \
     --task-definition dev-wso2-is:1 \
     --region ap-southeast-1
   ```

2. **Delete ECS cluster** (if empty):
   ```bash
   aws ecs delete-cluster \
     --cluster dev-wso2 \
     --region ap-southeast-1
   ```

3. **Delete IAM roles**:
   ```bash
   aws iam delete-role-policy \
     --role-name dev-wso2-ecs-task \
     --policy-name wso2-secrets-read
   aws iam delete-role \
     --role-name dev-wso2-ecs-execution
   aws iam delete-role \
     --role-name dev-wso2-ecs-task
   ```

4. **Delete CloudWatch log groups**:
   ```bash
   aws logs delete-log-group \
     --log-group-name /ecs/dev/wso2-cp \
     --region ap-southeast-1
   aws logs delete-log-group \
     --log-group-name /ecs/dev/wso2-is \
     --region ap-southeast-1
   ```

**Easier approach:** Use `terraform destroy`:
```bash
cd labs/phase3/day40
terraform destroy -var-file=terraform.tfvars
```

## What Terraform Would Track

If this lab were deployed, Terraform would create:
- 1 ECS cluster
- 1 ECS cluster capacity provider configuration
- 2 ECS task definitions (CP, IS)
- 2 IAM roles (execution, task)
- 1 IAM role policy (task secrets)
- 2 CloudWatch log groups

Total: ~9 AWS resources (not costly, but good to clean up).

## Why We Don't Apply

This lab is designed as a **study and validation tool**, not an interactive deployment. Running `terraform apply` is not necessary to learn the concepts. Instead:

1. Read the HCL code carefully.
2. Run `terraform validate` to check syntax.
3. Run `terraform plan` to see what would be created (without applying).
4. Study the outputs and understand the resource dependencies.

This approach lets you learn AWS architecture without incurring cloud costs or managing live resources.

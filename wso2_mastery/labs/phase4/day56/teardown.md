# Day 56 Teardown

## Authored Lab — No Teardown Required

This is an **authored lab** — it demonstrates Terraform syntax and patterns without applying resources to AWS.

### What This Means

- No ECS cluster, services, or autoscaling resources were created.
- No AWS API calls were made.
- `terraform validate` checked syntax only; no authentication or backend state was used.
- Nothing to clean up.

### If You Run `terraform apply` (Not Recommended)

If you ignore the warnings and actually apply this Terraform:

```bash
terraform apply
```

**STOP.** This is an educational lab. If you proceed, AWS resources will be created:
- 4 ECS task definitions (~$0/month each)
- 4 ECS services with 1 task each running continuously (~$120–150/month for 1 vCPU / 2 GB each)
- Autoscaling targets and policies (~$0/month)
- CloudWatch alarms (~$0.10/month)

**To clean up if you applied:**

```bash
terraform destroy
# Confirm with 'yes' when prompted
```

This will delete all AWS resources defined in the Terraform code.

---

## Learning Approach

Use this lab to:
1. **Study the HCL patterns** — Read main.tf, variables.tf, outputs.tf.
2. **Validate syntax** — Run `terraform validate` to practice common Terraform patterns.
3. **Answer exercises** — Modify the Terraform to add new resources (e.g., another autoscaling policy).
4. **Plan a real deployment** — Use this as a template; fill in real values and deploy in a non-prod environment.

---

## Next Steps

- Move to Day 57: Capacity planning worksheet.
- When ready for a real deployment, fill in variables.tf with actual AWS resource IDs and ECR image URIs.
- Test in a dev environment first; validate autoscaling behavior before prod.

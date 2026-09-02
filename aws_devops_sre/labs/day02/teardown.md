# Teardown — Day 2 lab

```bash
cd labs/day02
terraform destroy
```

`terraform destroy` reliably leaves two things behind that it does not
clean up on its own. Check both before you consider this lab torn down.

## 1. Objects in the S3 artifact bucket

`aws_s3_bucket.artifacts` is created without `force_destroy = true` in this
lab, on purpose — that's what makes the failure below a lesson instead of a
surprise. Every pipeline execution writes at least one zip (source output,
build output, and so on) into this bucket, and **S3 refuses to delete a
non-empty bucket.** If you've run the pipeline even once before running
`terraform destroy`, expect it to fail on the bucket with something like:

```
Error: deleting S3 Bucket (awsdevops-pipeline-artifacts-123456789012):
BucketNotEmpty: The bucket you tried to delete is not empty
```

Empty it, then destroy again:

```bash
aws s3 rm "s3://$(terraform output -raw artifact_bucket_name)" --recursive
terraform destroy
```

(If you've already lost the Terraform output because the state was
partially destroyed, the bucket name is `<name_prefix>-pipeline-artifacts-<account_id>`
— default `awsdevops-pipeline-artifacts-123456789012`, with your real
account ID.)

## 2. The GitHub OIDC identity provider, if another role still references it

`aws_iam_openid_connect_provider.github_actions` (the IAM OIDC provider for
`token.actions.githubusercontent.com`) is scoped to this Terraform state and
will be destroyed along with everything else here — **unless** you (or a
later lab) created a second IAM role elsewhere in this AWS account that also
trusts this same OIDC provider. IAM will refuse to delete an OIDC provider
that's still referenced as a `Federated` principal by another role's trust
policy:

```
Error: deleting IAM OIDC Provider: DeleteConflictException: Unable to
delete Identity Provider. It is still being used
```

Check what still trusts it before you assume this is a bug in the destroy:

```bash
aws iam list-open-id-connect-providers
# for each provider ARN that looks like it's for token.actions.githubusercontent.com:
aws iam get-open-id-connect-provider --open-id-connect-provider-arn <ARN>
```

There's no single CLI call that lists "every role trusting this provider" —
if destroy fails here, the practical fix is to check any other role you
created by hand (or in another lab) with a `Federated` principal pointing at
this provider's ARN, delete or repoint that role's trust policy, then
`terraform destroy` again.

## 3. Verify

```bash
bash ../verify-teardown.sh
```

This is a read-only audit — it never deletes anything itself. It won't
specifically call out this lab's pipeline or OIDC role by name, but it will
flag other billable resources (NAT gateways, load balancers, running Fargate
tasks) that should never have existed in this lab in the first place.

## Leave `labs/foundation/` running

Do **not** destroy `labs/foundation/` after this lab. It stays up for the
whole week — Day 3, Day 4, and Day 5 all read its VPC and ECR repository
outputs via `terraform_remote_state`. It is only destroyed once, at the very
end, after Day 5.

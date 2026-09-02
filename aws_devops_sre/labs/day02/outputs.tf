output "pipeline_name" {
  description = "CodePipeline V2 pipeline name. Not consumed as a Terraform input by any later day — Day 5's DORA metrics are gathered via AWS CLI with the learner substituting this name."
  value       = aws_codepipeline.this.name
}

output "artifact_bucket_name" {
  description = "S3 bucket holding pipeline execution artifacts (zips, including imageDetail.json)."
  value       = aws_s3_bucket.artifacts.bucket
}

output "github_oidc_role_arn" {
  description = "IAM role GitHub Actions assumes via OIDC to push images to the foundation ECR repo. Paste into github-actions-workflow.yml.example's role-to-assume."
  value       = aws_iam_role.gha_oidc.arn
}

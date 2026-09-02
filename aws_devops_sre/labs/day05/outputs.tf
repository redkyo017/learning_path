output "capstone_pipeline_name" {
  description = "Capstone pipeline name (Ruling C5). Push to var.github_branch to trigger it — see README.md Step 2."
  value       = aws_codepipeline.capstone.name
}

output "capstone_artifact_bucket_name" {
  description = "S3 bucket holding the capstone pipeline's execution artifacts. Created without force_destroy — empty it by hand before `terraform destroy`, see teardown.md."
  value       = aws_s3_bucket.pipeline_artifacts.bucket
}

output "canary_artifact_bucket_name" {
  description = "S3 bucket holding the Synthetics canary's screenshots/logs. Created with force_destroy = true."
  value       = aws_s3_bucket.canary_artifacts.bucket
}

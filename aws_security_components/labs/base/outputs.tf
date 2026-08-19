# ---------------------------------------------------------------------------
# The outputs contract. Every later day-lab module reads these — via
# `terraform_remote_state` pointed at this state, or via documented data
# sources — so the NAMES below must not change. See README "Outputs
# contract".
# ---------------------------------------------------------------------------

output "vpc_id" {
  description = "ID of the base VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (2 AZs). ALB and the Fargate task ENIs live here."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (2 AZs). No default internet route — reserved for day-lab add-ons."
  value       = aws_subnet.private[*].id
}

output "alb_arn" {
  description = "ARN of the base ALB."
  value       = aws_lb.app.arn
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB (direct origin, bypassing CloudFront)."
  value       = aws_lb.app.dns_name
}

output "alb_listener_arn" {
  description = "ARN of the ALB's HTTP:80 listener."
  value       = aws_lb_listener.http.arn
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution in front of the ALB."
  value       = aws_cloudfront_distribution.app.id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster."
  value       = aws_ecs_cluster.this.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service running the app task."
  value       = aws_ecs_service.app.name
}

output "task_role_arn" {
  description = "ARN of the app's runtime IAM role (the one Day 8/11's SSRF lab steals credentials for, and Day 1 tightens)."
  value       = aws_iam_role.task.arn
}

output "task_execution_role_arn" {
  description = "ARN of the ECS task execution role (image pull + log shipping only)."
  value       = aws_iam_role.task_execution.arn
}

output "app_bucket_name" {
  description = "Name of the app-data S3 bucket."
  value       = aws_s3_bucket.app_data.bucket
}

output "app_bucket_arn" {
  description = "ARN of the app-data S3 bucket."
  value       = aws_s3_bucket.app_data.arn
}

output "db_endpoint" {
  description = <<-EOT
    DOCUMENTED STAND-IN: the DB tier is a DynamoDB table (see data.tf design
    note), not an instance with a network endpoint. This value is the
    regional DynamoDB service endpoint plus the table name, not a
    per-resource connection string. Use aws_dynamodb_table.app_data.name
    (exposed here) with the AWS SDK/CLI rather than treating this as a host
    to connect a driver to.
  EOT
  value = "https://dynamodb.${var.region}.amazonaws.com (table=${aws_dynamodb_table.app_data.name})"
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret. The secret has NO value until you set one out-of-band — see README."
  value       = aws_secretsmanager_secret.app_secret.arn
}

output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key used for S3 app-data and DynamoDB encryption-at-rest."
  value       = aws_kms_key.app_data.arn
}

output "kms_key_id" {
  description = "Key ID of the customer-managed KMS key used for S3 app-data and DynamoDB encryption-at-rest."
  value       = aws_kms_key.app_data.key_id
}

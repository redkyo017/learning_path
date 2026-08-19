output "cloudtrail_arn" {
  description = "ARN of the Day 8 CloudTrail trail."
  value       = aws_cloudtrail.this.arn
}

output "cloudtrail_log_bucket" {
  description = "Name of the dedicated CloudTrail log-destination bucket (not the app_data bucket)."
  value       = aws_s3_bucket.trail_logs.id
}

output "guardduty_detector_id" {
  description = "GuardDuty detector ID. Day 9's EventBridge rule and this lab's sample-findings step both need this."
  value       = aws_guardduty_detector.this.id
}

output "securityhub_standard_subscription_arn" {
  description = "ARN of the enabled AWS Foundational Security Best Practices standard subscription."
  value       = aws_securityhub_standards_subscription.fsbp.id
}

output "macie_classification_job_id" {
  description = "ID of the one-time Macie classification job against the base app_data bucket."
  value       = aws_macie2_classification_job.app_data.id
}

output "detective_graph_arn" {
  description = "ARN of the Detective behavior graph (accumulates history for the Day 11-12 capstone)."
  value       = aws_detective_graph.this.arn
}

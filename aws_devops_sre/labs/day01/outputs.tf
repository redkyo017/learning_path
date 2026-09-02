output "codebuild_project_name" {
  description = "Used to trigger this project by hand (`aws codebuild start-build --project-name ...`). Day 2 declares its own CodePipeline-driven CodeBuild project rather than reading this output — see content/day02.md, Core concept 6, for why one project can't serve both invocation modes."
  value       = aws_codebuild_project.build.name
}

output "codebuild_role_arn" {
  description = "The CodeBuild service role's ARN — useful for auditing exactly what this project is allowed to do."
  value       = aws_iam_role.codebuild.arn
}

output "log_group_name" {
  description = "CloudWatch Logs group that holds this project's build output (1-day retention)."
  value       = aws_cloudwatch_log_group.codebuild.name
}

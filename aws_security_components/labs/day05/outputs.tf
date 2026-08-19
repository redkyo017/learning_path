output "demo_task_definition_arn" {
  description = "ARN of whichever demo task-definition revision exists right now: the leaky one (harden=false) or the hardened one (harden=true)."
  value       = try(aws_ecs_task_definition.leaky_demo[0].arn, try(aws_ecs_task_definition.hardened_demo[0].arn, null))
}

output "demo_task_definition_family" {
  description = "Family name of the demo task definition -- pass this to `aws ecs describe-task-definition --task-definition <family>` to inspect the CURRENT (latest) revision, or add `:1`/`:2` etc. to inspect a specific one."
  value       = "${local.name_prefix}-app"
}

output "secret_arn" {
  description = "Pass-through of base's secret ARN, for convenience in lab commands."
  value       = data.terraform_remote_state.base.outputs.secret_arn
}

output "rotation_lambda_arn" {
  description = "ARN of the rotation Lambda (null until harden=true)."
  value       = try(aws_lambda_function.rotate_app_secret[0].arn, null)
}

output "rotation_enabled" {
  description = "Whether this apply turned on Secrets Manager rotation for base's secret."
  value       = var.harden
}

output "cert_arn" {
  description = "ARN of the ACM certificate actually in use: the public DNS-validated cert if you supplied a domain + Route53 zone, otherwise the imported self-signed fallback. null until harden=true."
  value       = local.cert_arn
}

output "cert_type" {
  description = "Which cert path was taken -- \"public-dns-validated\", \"self-signed-imported\", or \"none\" (harden=false)."
  value       = var.harden ? (local.use_public_cert ? "public-dns-validated" : "self-signed-imported") : "none"
}

output "https_listener_arn" {
  description = "ARN of the new HTTPS:443 listener on base's ALB. null until harden=true."
  value       = try(aws_lb_listener.https[0].arn, null)
}

output "alb_https_url" {
  description = "Convenience URL to curl once harden=true. With the self-signed fallback, curl needs -k (insecure) since the cert isn't publicly trusted -- that is expected, see README."
  value       = var.harden ? "https://${data.terraform_remote_state.base.outputs.alb_dns_name}/" : null
}

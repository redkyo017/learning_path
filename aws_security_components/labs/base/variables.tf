variable "region" {
  description = "AWS region for the base workload. Every day-lab module must use the same region."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short name/prefix used in every resource name and tag. Keep it short, lowercase, and hyphen-only — it is used verbatim in the S3 bucket name (which must be globally unique, lowercase, no underscores), IAM role names, and log groups."
  type        = string
  default     = "aws-sec-lab"
}

variable "vpc_cidr" {
  description = "CIDR block for the base VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "Two /24 CIDRs for the public subnets (one per AZ). ALB and the Fargate task ENIs live here (NAT-free design — see README)."
  type        = list(string)
  default     = ["10.42.0.0/24", "10.42.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Two /24 CIDRs for the private subnets (one per AZ). Reserved for day-lab add-ons (e.g. an RDS instance, VPC endpoints); nothing in the base workload requires them today."
  type        = list(string)
  default     = ["10.42.10.0/24", "10.42.11.0/24"]
}

variable "app_image" {
  description = <<-EOT
    Container image URI for the app task. The base workload ships the app source at
    labs/base/app/ (a tiny Flask app with a deliberate server-side URL-fetch endpoint
    used by the Day 8/11 SSRF lab). Build it and push it to your own ECR repo BEFORE
    the first apply, then set this to that image URI, e.g.:
      <account_id>.dkr.ecr.<region>.amazonaws.com/aws-sec-lab-app:latest
    The default below is a placeholder and will fail to pull — Terraform will still
    plan/create everything else; only the ECS service will fail to reach RUNNING
    until you supply a real image. See README "Build and push the app image".
  EOT
  type        = string
  default     = "REPLACE_ME.dkr.ecr.us-east-1.amazonaws.com/aws-sec-lab-app:latest"
}

variable "app_container_port" {
  description = "TCP port the app container listens on."
  type        = number
  default     = 8080
}

variable "fargate_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU — cheapest valid Fargate size)."
  type        = number
  default     = 256
}

variable "fargate_memory" {
  description = "Fargate task memory in MiB (512 is the minimum paired with 256 CPU units)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of Fargate tasks to run. Keep at 1 for a learning lab — this is not a HA exercise."
  type        = number
  default     = 1
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention for the app log group. Short by default to bound cost during a multi-day sprint."
  type        = number
  default     = 3
}

variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window on destroy. 0 = force-delete immediately (no 7-30 day pending-deletion tail) — matches the daily teardown workflow. Set higher only if you want an undo window and don't mind the trailing cost."
  type        = number
  default     = 0
}

variable "tags" {
  description = "Extra tags merged onto every resource."
  type        = map(string)
  default     = {}
}

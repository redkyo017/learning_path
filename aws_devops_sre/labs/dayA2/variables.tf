variable "aws_region" {
  description = "AWS region for all resources in this stack."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to every resource name in this stack."
  type        = string
  default     = "awsdevops"
}

variable "image_tag" {
  description = <<-EOT
    Image tag to run — the git short-SHA tag Day 1's CodeBuild pushed to
    ECR. Deliberately has NO default.

    Find it with the CLI rather than the console, which is the point of
    this appendix:

      aws ecr describe-images \
        --repository-name awsdevops-sample \
        --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' \
        --output text
  EOT
  type        = string
}

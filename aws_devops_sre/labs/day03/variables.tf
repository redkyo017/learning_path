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
    Image tag to deploy — e.g. the git short-SHA tag Day 1's CodeBuild
    pushed to ECR. Deliberately has NO default.

    On Day 5, CodePipeline substitutes the image reference into
    taskdef.json.example automatically (see that file's <IMAGE1_NAME>
    placeholder). Here on Day 3 you type the tag by hand instead. That is
    intentional: typing it makes the hand-off from "Day 1 built and pushed
    this exact digest" to "Day 3 is deploying this exact digest" a visible,
    concrete step — before Day 5 hides it behind pipeline automation.
  EOT
  type        = string
}

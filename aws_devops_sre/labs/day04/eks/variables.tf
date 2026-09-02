variable "aws_region" {
  description = "AWS region for all resources in this path."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix applied to every resource name so teardown verification can find them."
  type        = string
  default     = "awsdevops"
}

variable "cluster_version" {
  description = "Kubernetes version for the (never-applied) EKS control plane."
  type        = string
  default     = "1.30"
}

variable "node_instance_type" {
  description = "Instance type for the managed node group. t3.medium keeps a small reference cluster cheap relative to control-plane cost, without pretending nodes are free."
  type        = string
  default     = "t3.medium"
}

variable "node_desired_size" {
  description = "Desired node count for the managed node group."
  type        = number
  default     = 2
}

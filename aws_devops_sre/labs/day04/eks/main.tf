# EKS reference stack — AUTHORED, NEVER APPLIED. See README.md.
#
# This is here so a future dedicated EKS path has working, readable
# Terraform to start from. Day 4 itself runs entirely on a local `kind`
# cluster (see ../kind-cluster.yaml) and creates zero AWS resources.
#
# It reads the same foundation VPC every other day lab in this path reads,
# via the standard remote-state block, so it would slot into the existing
# `labs/foundation` output contract if it were ever applied.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.name_prefix
      ManagedBy = "terraform"
      Path      = "aws_devops_sre"
    }
  }
}

data "terraform_remote_state" "foundation" {
  backend = "local"
  config  = { path = "../../foundation/terraform.tfstate" }
}

data "aws_caller_identity" "current" {}

# --- EKS control plane ---------------------------------------------------
# Cost: ~$0.10/hour (~$73/month), flat, whether or not any Pod is running.
# This is the single line item that makes this stack unsuitable for a
# "leave it up for the week" lab — it is the whole reason Day 4 uses kind
# instead.
resource "aws_eks_cluster" "this" {
  name     = "${var.name_prefix}-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = data.terraform_remote_state.foundation.outputs.public_subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}

# Cost: $0 — an IAM role has no cost by itself.
resource "aws_iam_role" "eks_cluster" {
  name = "${var.name_prefix}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "eks.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Cost: $0 — attaching a managed policy has no cost by itself.
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- Managed node group ---------------------------------------------------
# Cost: node_desired_size * t3.medium on-demand price, roughly
# ~$0.0416/hour each in us-east-1 -> ~$60/month for 2 nodes. This is in
# addition to the control-plane cost above, not instead of it — EKS never
# bundles compute into the control-plane price the way ECS Fargate bundles
# it into the per-task price.
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name_prefix}-eks-nodes"
  node_role_arn   = aws_iam_role.eks_node.arn
  subnet_ids      = data.terraform_remote_state.foundation.outputs.public_subnet_ids

  instance_types = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_desired_size + 1
    min_size     = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_node_worker_policy,
    aws_iam_role_policy_attachment.eks_node_cni_policy,
    aws_iam_role_policy_attachment.eks_node_registry_policy,
  ]
}

# Cost: $0 — an IAM role has no cost by itself. This is the ECS "execution
# role" analog from content/day04.md's mapping table: it's what lets the
# node itself function (pull images, register with the cluster), separate
# from what an individual Pod's *application* is allowed to do — that
# separation is exactly why IRSA (below) exists instead of just granting
# application permissions on this role.
resource "aws_iam_role" "eks_node" {
  name = "${var.name_prefix}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "ec2.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Cost: $0 each — attaching a managed policy has no cost by itself.
resource "aws_iam_role_policy_attachment" "eks_node_worker_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_node_cni_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_node_registry_policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# --- OIDC provider for IRSA ------------------------------------------------
# Cost: $0 — an IAM OIDC identity provider resource has no charge by itself.
# This is what makes IRSA possible at all: it registers the EKS cluster's
# own OIDC issuer as a trusted identity provider in IAM, the same role an
# IdP plays for GitHub Actions OIDC in Day 2.
data "tls_certificate" "eks_oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint]
}

# --- IRSA worked example ----------------------------------------------------
# Cost: $0 — an IAM role has no cost by itself.
#
# This trust policy is the SAME SHAPE as Day 2's GitHub Actions OIDC trust
# policy (labs/day02/oidc.tf): both are `sts:AssumeRoleWithWebIdentity`
# against an IAM OIDC provider, gated by a StringEquals condition on that
# provider's `sub` claim. The only things that differ between IRSA here and
# Day 2's GitHub OIDC role are (a) which OIDC provider is trusted — this
# cluster's issuer vs. token.actions.githubusercontent.com — and (b) the
# shape of the `sub` claim itself — a Kubernetes ServiceAccount identity
# (system:serviceaccount:<namespace>:<name>) vs. a GitHub Actions workflow
# identity (repo:<owner>/<repo>:ref:refs/heads/<branch>). See
# content/day04.md Core concepts #7 for the full walkthrough.
#
# <OIDC_ISSUER> below is a placeholder standing in for
# aws_iam_openid_connect_provider.eks.url with the "https://" prefix
# stripped, which is how IAM condition keys reference it once applied.
resource "aws_iam_role" "irsa_sample_app" {
  name = "${var.name_prefix}-irsa-awsdevops-sample"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "<OIDC_ISSUER>:sub" = "system:serviceaccount:default:awsdevops-sample"
            "<OIDC_ISSUER>:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Example scoped permission for the IRSA role above — deliberately minimal
# (read-only ECR pull) rather than broad, to model "scope the role to what
# the Pod actually needs" instead of "grant AdministratorAccess and move
# on." Cost: $0 — attaching a managed policy has no cost by itself.
resource "aws_iam_role_policy_attachment" "irsa_sample_app_ecr_readonly" {
  role       = aws_iam_role.irsa_sample_app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

output "cluster_endpoint" {
  description = "EKS API server endpoint (only meaningful if this stack is ever applied)."
  value       = aws_eks_cluster.this.endpoint
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN for IRSA — annotate a ServiceAccount's eks.amazonaws.com/role-arn with a role trusting this provider."
  value       = aws_iam_openid_connect_provider.eks.arn
}

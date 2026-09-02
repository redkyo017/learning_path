# Day 1 — PRODUCE: one CodeBuild project that turns a commit into an
# immutable, identifiable container image in the foundation stack's ECR
# repository.
#
# Cost: approximately $0.20 per lab session (see content/day01.md and
# ../../COST.md) — CodeBuild bills per build-minute, ECR image storage for
# one ~15 MB image is a fraction of a cent. There is no hourly meter here:
# leaving this stack applied overnight costs nothing extra, unlike Day 3's
# Fargate/ALB.
#
# No VPC configuration block on this project, on purpose. Attaching
# CodeBuild to a VPC only matters when the build needs to reach something
# that lives inside one (an internal artifact repo, a private database). This
# build only needs the public internet (to clone from GitHub) and the ECR
# API (a public AWS endpoint) — both reachable without a VPC. Attaching to a
# VPC anyway would mean giving this project private subnets, and a private
# subnet with no NAT gateway can't reach the internet or the ECR API at all.
# The only way to make that work would be adding a NAT gateway (~$32/month,
# the single most common accidental cost in a path like this) or a set of
# VPC interface endpoints — both real options in production, both
# deliberately out of scope for a lab that is supposed to cost cents. See
# ../../COST.md for the full "three traps" breakdown.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
      Day       = "day01"
    }
  }
}

data "terraform_remote_state" "foundation" {
  backend = "local"
  config  = { path = "../foundation/terraform.tfstate" }
}

# --- CodeBuild service role --------------------------------------------
# One role, scoped to exactly what a build needs to do: write its own logs,
# and authenticate + push to exactly one ECR repository. This is not the
# pipeline role (Day 2 creates that, for CodePipeline itself to call
# codebuild:StartBuild) and it is not an ECR resource policy (which would
# grant cross-account pull access on the repository side) — three different
# trust boundaries that get conflated as "IAM for the pipeline" if you're
# not careful. See content/day01.md, Core concept 7.

resource "aws_iam_role" "codebuild" {
  name = "${var.name_prefix}-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.name_prefix}-build-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "WriteBuildLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        # Both forms are needed: the bare ARN for the group itself, and the
        # ":*" form for the log streams CodeBuild creates inside it.
        Resource = [
          aws_cloudwatch_log_group.codebuild.arn,
          "${aws_cloudwatch_log_group.codebuild.arn}:*",
        ]
      },
      {
        Sid    = "EcrAuth"
        Effect = "Allow"
        # ecr:GetAuthorizationToken issues a registry-wide docker login
        # token. It cannot be scoped to a single repository ARN — the API
        # call itself doesn't take a repository as input, it authenticates
        # you to the whole registry — so "*" here is not a shortcut, it is
        # the only resource value AWS's IAM policy grammar accepts for this
        # action. The five actions below are what actually keep this role
        # scoped to one repository.
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "EcrPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
        ]
        Resource = data.terraform_remote_state.foundation.outputs.ecr_repository_arn
      },
    ]
  })
}

# --- Build logs ----------------------------------------------------------

resource "aws_cloudwatch_log_group" "codebuild" {
  name              = "/aws/codebuild/${var.name_prefix}-build"
  retention_in_days = 1
}

# --- The build project ----------------------------------------------------
# ARM_CONTAINER + BUILD_GENERAL1_SMALL: the Go binary cross-compiles cleanly
# to arm64 (see app/Dockerfile), and ARM build-minutes cost roughly 30% less
# than the x86 equivalent. See content/day01.md, Core concept 3, for the
# Lambda-compute alternative and why it doesn't apply here (privileged mode,
# needed for `docker build`, is not available on Lambda compute).

resource "aws_codebuild_project" "build" {
  name          = "${var.name_prefix}-build"
  description   = "Builds app/ into a container image and pushes it to ECR by commit-derived tag."
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 15

  artifacts {
    # NO_ARTIFACTS here is a Day-1-specific choice: this project is started
    # by hand via `aws codebuild start-build`, so there is no pipeline stage
    # waiting to collect an artifact. The buildspec still writes
    # imageDetail.json (see buildspec.yml) — with NO_ARTIFACTS, CodeBuild
    # simply doesn't upload it anywhere; you can still see its contents in
    # the build logs. Day 2 does NOT repoint this project at CodePipeline —
    # a project's source/artifacts types commit it to one invocation mode
    # (see content/day02.md, Core concept 6), so Day 2 declares its own
    # CODEPIPELINE-sourced project instead and reuses this buildspec.yml
    # file, unedited, to drive it. This project stays GITHUB/NO_ARTIFACTS
    # so `aws codebuild start-build` keeps working standalone.
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    # Required to run `docker build` / `docker push` at all — CodeBuild
    # starts a Docker daemon inside the build container only when this is
    # true. See content/day01.md, Core concept 5, for what this grants (and
    # doesn't) versus running arbitrary root-equivalent workloads.
    privileged_mode = true

    environment_variable {
      name  = "REPO_URI"
      value = data.terraform_remote_state.foundation.outputs.ecr_repository_url
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = data.terraform_remote_state.foundation.outputs.ecr_repository_name
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }

  source {
    type = "GITHUB"
    # Standalone CodeBuild GitHub sources (unlike CodePipeline's
    # CodeConnections source action, which Day 2 uses) need a one-time
    # account-level GitHub authorization of their own. The first
    # `terraform apply` after you set github_repo_url will prompt you to
    # finish this in the console (CodeBuild → Build projects → this project
    # → Edit → Source → Connect to GitHub) if it hasn't been done yet — this
    # is separate from the CodeConnections handshake in Day 0, step 4.
    location        = var.github_repo_url
    git_clone_depth = 1
    buildspec       = file("${path.module}/buildspec.yml")
  }

  cache {
    type = "LOCAL"
    modes = [
      "LOCAL_DOCKER_LAYER_CACHE",
      "LOCAL_SOURCE_CACHE",
    ]
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild.name
      stream_name = "build-log"
    }
  }
}

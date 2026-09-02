# Day 2 — PROMOTE: CodePipeline V2 as a promotion machine.
#
# Cost: approximately $0.30 for a normal ~2h lab session.
#   - CodePipeline V2 bills ~$0.002/action-minute after 100 free
#     action-minutes/month — a handful of manual executions in this lab
#     stays well inside the free tier.
#   - CodeBuild (this lab's own pipeline-build project, running Day 1's
#     buildspec.yml reused unedited, plus this lab's small
#     deploy-placeholder project) bills per build-minute on ARM_CONTAINER /
#     BUILD_GENERAL1_SMALL.
#   - The S3 artifact bucket and the GitHub OIDC role/provider are
#     effectively free at this scale.
# See labs/day02/README.md and teardown.md for the exact commands and what
# terraform destroy does NOT clean up on its own.

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
    }
  }
}

data "aws_caller_identity" "current" {}

# --- Shared state from earlier stacks -----------------------------------

data "terraform_remote_state" "foundation" {
  backend = "local"
  config  = { path = "../foundation/terraform.tfstate" }
}

# Day 2 does NOT read Day 1's terraform.tfstate. Earlier drafts of this lab
# pointed the pipeline's Build action straight at Day 1's CodeBuild project
# (via data.terraform_remote_state.day01.outputs.codebuild_project_name) —
# that doesn't work, and not because of a typo: Day 1's project is declared
# with source { type = "GITHUB" } and artifacts { type = "NO_ARTIFACTS" },
# because it's meant to be started by hand with `aws codebuild start-build`.
# A CodeBuild project driven by a CodePipeline action must instead declare
# source { type = "CODEPIPELINE" } and artifacts { type = "CODEPIPELINE" } —
# those two invocation modes are mutually exclusive on one project. See
# content/day02.md, Core concept 6, for the full explanation. This lab
# declares its own CodeBuild project below (aws_codebuild_project.build)
# rather than reusing Day 1's, and the only thing that carries over is the
# buildspec file itself — reused verbatim, unedited, via a relative
# `file()` reference into labs/day01/. That's what "build once" actually
# means here: one set of build instructions, not one Terraform resource.

# --- Pipeline artifact bucket --------------------------------------------
# What CodePipeline actually moves between stages is a zip of small files
# (including imageDetail.json, which points at an image digest in ECR) —
# never the container image itself. This bucket is where those zips live.

resource "aws_s3_bucket" "artifacts" {
  # Bucket names are globally unique across all of AWS, so the account ID
  # suffix is here for that reason alone. The account ID is not a secret,
  # but it still shouldn't be hardcoded into a file that might get copied
  # to another account — data.aws_caller_identity.current keeps it dynamic.
  bucket = "${var.name_prefix}-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"

  # No force_destroy here, deliberately: see teardown.md for why a
  # non-empty bucket blocking `terraform destroy` is a lesson, not a bug.
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-pipeline-artifacts"
    status = "Enabled"

    # Cost hygiene: pipeline artifacts are working data, not something you
    # need to keep around. Expiring after 7 days keeps this bucket from
    # quietly accumulating every execution's zip forever.
    filter {}

    expiration {
      days = 7
    }
  }
}

# --- CodePipeline service role -------------------------------------------

resource "aws_iam_role" "codepipeline" {
  name = "${var.name_prefix}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.name_prefix}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ArtifactBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketVersioning",
        ]
        Resource = [
          aws_s3_bucket.artifacts.arn,
          "${aws_s3_bucket.artifacts.arn}/*",
        ]
      },
      {
        Sid      = "ListArtifactBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.artifacts.arn]
      },
      {
        Sid    = "StartAndCheckBuilds"
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds",
        ]
        Resource = [
          aws_codebuild_project.build.arn,
          aws_codebuild_project.deploy_placeholder.arn,
        ]
      },
      {
        # The IAM action prefix here is still "codestar-connections" even
        # though the AWS service itself was renamed to "CodeConnections".
        # This is a genuine trip hazard: searching IAM Visual Editor for
        # "CodeConnections" actions finds nothing, because every action
        # name (and every ARN) still says codestar-connections underneath.
        Sid      = "UseGitHubConnection"
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = [var.codeconnection_arn]
      },
    ]
  })
}

# --- Build CodeBuild project (CodePipeline-invoked) -----------------------
# This is Day 2's own CodeBuild project, driven by the pipeline's Build
# action — not Day 1's. See the comment above data.aws_caller_identity /
# the removed remote-state block for why one project can't serve both
# invocation modes, and content/day02.md Core concept 6 for the full lesson.
# What's reused from Day 1 is the buildspec file, unedited, via the
# `file()` reference below — same install/pre_build/build/post_build
# commands, same IMAGE_TAG derivation, same imageDetail.json output. The
# environment variables the buildspec depends on (REPO_URI, IMAGE_REPO_NAME,
# AWS_DEFAULT_REGION) are supplied the same way Day 1 supplies them: as
# project-level environment_variable blocks, not re-declared in the file.

resource "aws_cloudwatch_log_group" "build" {
  name              = "/aws/codebuild/${var.name_prefix}-pipeline-build"
  retention_in_days = 1
}

resource "aws_iam_role" "build" {
  name = "${var.name_prefix}-pipeline-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "build" {
  name = "${var.name_prefix}-pipeline-build-policy"
  role = aws_iam_role.build.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = [
          aws_cloudwatch_log_group.build.arn,
          "${aws_cloudwatch_log_group.build.arn}:*",
        ]
      },
      {
        # Same split as Day 1's build role (main.tf, labs/day01): the
        # registry-wide auth token can't be scoped to one repository, the
        # actual push actions can and should be.
        Sid      = "EcrAuth"
        Effect   = "Allow"
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
      {
        # CodeBuild's own service role needs S3 access to the pipeline
        # artifact bucket whenever the action's input/output artifacts are
        # type CODEPIPELINE — separate from, and in addition to, the
        # CodePipeline service role's own S3 permissions above.
        Sid    = "ArtifactBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
        ]
        Resource = ["${aws_s3_bucket.artifacts.arn}/*"]
      },
    ]
  })
}

resource "aws_codebuild_project" "build" {
  name          = "${var.name_prefix}-pipeline-build"
  description   = "CodePipeline-invoked twin of Day 1's build project. Same buildspec, CODEPIPELINE source/artifacts instead of GITHUB/NO_ARTIFACTS."
  service_role  = aws_iam_role.build.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    # Needed to run `docker build` / `docker push` — the buildspec this
    # project runs is identical to Day 1's, and Day 1's requires this for
    # the same reason (see content/day01.md, Core concept 5).
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
    type = "CODEPIPELINE"

    # Reused verbatim from Day 1 — not copied, not re-edited. Same file on
    # disk, referenced by relative path. This is the whole "build once"
    # claim from content/day02.md, Core concept 6, made literal in Terraform.
    buildspec = file("${path.module}/../day01/buildspec.yml")
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
      group_name = aws_cloudwatch_log_group.build.name
    }
  }
}

# --- Deploy placeholder CodeBuild project --------------------------------
# DeployStaging and DeployProd both invoke this same CodeBuild project.
# Day 3 replaces both of these stages with real CodeDeploy blue/green
# actions against ECS Fargate — this placeholder exists purely so the
# pipeline's stage shape (Source -> Build -> DeployStaging -> Approval ->
# DeployProd) is complete and runnable today, without pulling Day 3's ECS
# service, target groups, and ALB forward into this lab.

resource "aws_cloudwatch_log_group" "deploy_placeholder" {
  name              = "/aws/codebuild/${var.name_prefix}-deploy-placeholder"
  retention_in_days = 1
}

resource "aws_iam_role" "deploy_placeholder" {
  name = "${var.name_prefix}-deploy-placeholder-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "deploy_placeholder" {
  name = "${var.name_prefix}-deploy-placeholder-policy"
  role = aws_iam_role.deploy_placeholder.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = ["${aws_cloudwatch_log_group.deploy_placeholder.arn}:*"]
      },
      {
        # CodeBuild's own service role needs S3 access to the pipeline
        # artifact bucket whenever the action's input/output artifacts
        # are type CODEPIPELINE — this is separate from, and in addition
        # to, the CodePipeline service role's own S3 permissions above.
        Sid    = "ArtifactBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
        ]
        Resource = ["${aws_s3_bucket.artifacts.arn}/*"]
      },
    ]
  })
}

resource "aws_codebuild_project" "deploy_placeholder" {
  name         = "${var.name_prefix}-deploy-placeholder"
  service_role = aws_iam_role.deploy_placeholder.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type            = "ARM_CONTAINER"
    privileged_mode = false
  }

  source {
    type = "CODEPIPELINE"

    buildspec = <<-EOT
      version: 0.2
      phases:
        build:
          commands:
            - echo "Placeholder deploy stage — Day 3 replaces this with real CodeDeploy blue/green on ECS Fargate."
            - echo "Consuming the digest recorded by the Build stage (see imageDetail.json in this action's input artifact):"
            - cat imageDetail.json 2>/dev/null || echo "imageDetail.json not found in input artifact — check the Build stage's output artifact configuration."
    EOT
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.deploy_placeholder.name
    }
  }
}

# --- The pipeline itself --------------------------------------------------

resource "aws_codepipeline" "this" {
  name          = "${var.name_prefix}-pipeline"
  role_arn      = aws_iam_role.codepipeline.arn
  pipeline_type = "V2"

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifacts.bucket
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceOutput"]

      configuration = {
        ConnectionArn        = var.codeconnection_arn
        FullRepositoryId     = "${var.github_owner}/${var.github_repo}"
        BranchName           = var.github_branch
        DetectChanges        = "true"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceOutput"]
      output_artifacts = ["BuildOutput"]

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "DeployStaging"

    action {
      name            = "DeployStaging"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["BuildOutput"]

      configuration = {
        ProjectName = aws_codebuild_project.deploy_placeholder.name
      }
    }
  }

  stage {
    name = "Approval"

    action {
      name     = "PromoteToProd"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"

      configuration = {
        # A meaningful approval names the artifact, not the stage. Whoever
        # approves this should open the Build stage's execution details,
        # read imageDetail.json, and confirm the digest shown there is the
        # one they intend to promote — not click through on trust.
        CustomData = "Approve promotion to prod of the image digest recorded in imageDetail.json by the Build stage of this execution. Open this execution's Build stage details in the console and confirm the digest before approving."
      }
    }
  }

  stage {
    name = "DeployProd"

    action {
      name            = "DeployProd"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["BuildOutput"]

      configuration = {
        ProjectName = aws_codebuild_project.deploy_placeholder.name
      }
    }
  }

  # V2-only feature: trigger filters. Without this block the pipeline would
  # start an execution on every push to every branch of the connected repo
  # (the connection is repo-wide; the Source action's BranchName only picks
  # which branch's commit is checked out, it doesn't gate what triggers a
  # run). This trigger narrows execution starts to pushes on
  # var.github_branch that touch app/** — a push that only edits docs/ or
  # this lab's own Terraform does not start a pipeline execution.
  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "Source"

      push {
        branches {
          includes = [var.github_branch]
        }

        file_paths {
          includes = ["app/**"]
        }
      }
    }
  }
}

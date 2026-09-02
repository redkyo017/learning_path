# Day 5 lab — MEASURE: composite alarms, a synthetic canary, a
# four-golden-signals dashboard observing the Day 3 stack, and (Ruling C5,
# see below) the capstone pipeline itself.
#
# COST while this lab is up (Day 3's ALB is NOT included — that's Day 3's
# cost, already accounted for there; it must be up for this lab to have
# anything to observe, see Step 0 in README.md):
#   - p99 latency alarm ............ ~$0.10/alarm-month (first 10 free per account)
#   - composite alarm ............... ~$0.50/alarm-month (billed separately from,
#                                      NOT part of, the 10-free-alarm tier above —
#                                      see Core Concepts §5 in content/day05.md)
#   - Synthetics canary, rate(5 min) . ~$0.0012/run x 12 runs/h  = ~$0.014/h
#   - canary's S3 artifact bucket .... a few KB of screenshots/logs; ~$0/month
#   - canary's Lambda function ....... invoked on the canary's schedule; ~$0/month
#     at this volume
#   - CloudWatch dashboard ........... first 3 dashboards/account free
#   - capstone CodeBuild project ..... ~$0.0034/build-min (ARM_SMALL), a handful
#                                      of build-minutes for the one commit Step 2
#                                      pushes through
#   - capstone CodePipeline (V2) ..... ~$0.002/action-min, 100 free action-min/mo —
#                                      one manual run of this lab stays inside that
#   - capstone artifact S3 bucket .... a few KB of zipped source/build artifacts
#   Total added by this lab: well under a dollar for a normal session. The
#   number that actually matters this week is Day 3's ALB — see Core Concepts
#   §9 in content/day05.md.
#
# THE DAY 3 STACK MUST BE APPLIED BEFORE THIS LAB. It was destroyed at the
# end of Day 3 on purpose (see labs/day03/teardown.md) — leaving an ALB up
# for two nights between sessions costs real money for zero learning value.
# README.md Step 0 walks through `cd ../day03 && terraform apply` before
# anything here. Without it, the `data "terraform_remote_state" "day03"`
# block below still reads a state file, but every alarm and the dashboard
# will have nothing live to observe.
#
# RULING (C5) — the capstone pipeline is built HERE, on Day 5, not inherited
# from an earlier day. Day 2's pipeline has echo-only placeholder deploy
# stages and is torn down at the end of Day 2's own session; by Day 5 there
# is no live pipeline anywhere in the path that can actually trigger a
# CodeDeploy blue/green deployment. Rather than pretend one exists, this lab
# assembles Source -> Build -> Deploy itself: a CodeConnections GitHub
# source, a CodeBuild project reusing Day 1's buildspec.yml UNCHANGED (read
# directly from ../day01/buildspec.yml — no Day 1 remote-state dependency,
# since Day 1 may well be torn down by now), and a CodeDeployToECS action
# against the Day 3 deployment group this file already reads via
# `data.terraform_remote_state.day03`. That is the point of the capstone: on
# the last day, you build the whole chain yourself instead of trusting one
# was handed to you — see content/day05.md and README.md Step 2.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
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

# --- Ruling (a): no Day 2 remote-state dependency ---------------------------
# Day 5 does not read Day 2's remote state — by this point in the week, Day
# 2's own stack is very likely already torn down, so a remote-state block
# pointed at it would fail to plan even if we wanted one. This lab reads
# Day 3's remote state (below) for the CodeDeploy application/deployment
# group and ECS cluster/service names, and the foundation stack's remote
# state (below that) for the ECR repository this lab's own capstone build
# project (Ruling C5) pushes to. DORA metrics in README.md/SOLUTION.md are
# gathered via AWS CLI against Day 3's CodeDeploy application/deployment
# group, using the literal `terraform output` values from ../day03 — not a
# Day 2 pipeline name, which this lab's pipeline (Ruling C5, below) makes
# moot anyway.

data "terraform_remote_state" "day03" {
  backend = "local"
  config = {
    path = "../day03/terraform.tfstate"
  }
}

# The foundation stack (VPC + ECR repo) stays up all week — see COST.md
# "What stays up all week" — so, unlike Day 1 or Day 2, reading it here on
# Day 5 is safe: it cannot have been torn down out from under this apply.
# The capstone build project below needs its ECR repository outputs.
data "terraform_remote_state" "foundation" {
  backend = "local"
  config = {
    path = "../foundation/terraform.tfstate"
  }
}

# Day 3's remote state exposes alb_dns_name but not the ALB's ARN or
# arn_suffix — and CloudWatch's LoadBalancer dimension needs the
# arn_suffix, not the DNS name. Rather than adding a new Day 3 output
# (which would mean re-editing an already-torn-down-and-reapplied stack),
# we look the ALB up directly here, by the name Day 3 gives it under this
# path's "${name_prefix}-<purpose>" convention.
data "aws_lb" "day03" {
  name = "${var.name_prefix}-alb"
}

# --- Capstone pipeline (Ruling C5) ----------------------------------------
# Source (CodeConnections -> GitHub) -> Build (CodeBuild, Day 1's buildspec
# unchanged) -> Deploy (CodeDeployToECS against Day 3's deployment group).
# See the RULING comment at the top of this file for why this pipeline is
# owned by Day 5 instead of inherited from Day 2.

# --- Pipeline artifact bucket ---------------------------------------------
# Same shape, and the same deliberate choice, as Day 2's artifact bucket: no
# force_destroy. A non-empty bucket blocking `terraform destroy` is a lesson
# about CodePipeline leaving artifacts behind, not a bug to paper over here.
# See teardown.md for the empty-then-destroy sequence this requires.

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "${var.name_prefix}-capstone-artifacts-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name = "${var.name_prefix}-capstone-artifacts"
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    id     = "expire-pipeline-artifacts"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}

# --- Deploy templates: appspec.yaml + taskdef.json as a pipeline source ---
# The CodeDeployToECS action needs an appspec.yaml and a taskdef.json (with
# an <IMAGE1_NAME> placeholder it substitutes with the digest the Build
# stage just pushed) as INPUT artifacts. Day 1's buildspec.yml is reused
# UNCHANGED (see RULING above) and only ever writes imageDetail.json — it
# does not, and must not, also emit these templates. So they're rendered
# from this lab's own .tftpl files (values plugged in via Terraform, exactly
# like every other resource here) and uploaded to the artifact bucket as a
# small zip, which a second Source-stage action pulls in as a plain S3
# artifact. This is the documented pattern for an ECS blue/green pipeline
# whose appspec/taskdef live outside the application's own source repo.

data "archive_file" "pipeline_templates" {
  type        = "zip"
  output_path = "${path.module}/.terraform-pipeline-templates/templates.zip"

  source {
    content = templatefile("${path.module}/taskdef.json.tftpl", {
      name_prefix = var.name_prefix
      region      = var.aws_region
      account_id  = data.aws_caller_identity.current.account_id
    })
    filename = "taskdef.json"
  }

  source {
    content = templatefile("${path.module}/appspec.yaml.tftpl", {
      name_prefix = var.name_prefix
    })
    filename = "appspec.yaml"
  }
}

resource "aws_s3_object" "pipeline_templates" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  key    = "templates/templates.zip"
  source = data.archive_file.pipeline_templates.output_path
  etag   = data.archive_file.pipeline_templates.output_md5
}

# --- Capstone build project ------------------------------------------------
# Deliberately its own CodeBuild project, not a reuse of Day 1's — Day 1's
# project is source-type GITHUB / artifacts-type NO_ARTIFACTS, started by
# hand via the CLI; a CodePipeline Build action requires source-type
# CODEPIPELINE / artifacts-type CODEPIPELINE (it consumes the pipeline's own
# SourceOutput artifact and produces BuildOutput for the Deploy stage, it
# does not clone from GitHub itself). What IS reused, unchanged, is the
# buildspec.yml file's content — same build, same image, same digest logic,
# only the thing driving it differs, which is exactly Day 1's own framing of
# that file (see the comment at the top of labs/day01/buildspec.yml).

resource "aws_cloudwatch_log_group" "capstone_build" {
  name              = "/aws/codebuild/${var.name_prefix}-capstone-build"
  retention_in_days = 1
}

resource "aws_iam_role" "capstone_build" {
  name = "${var.name_prefix}-capstone-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "capstone_build" {
  name = "${var.name_prefix}-capstone-build-policy"
  role = aws_iam_role.capstone_build.id

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
        Resource = [
          aws_cloudwatch_log_group.capstone_build.arn,
          "${aws_cloudwatch_log_group.capstone_build.arn}:*",
        ]
      },
      {
        # Same split as Day 1's build role: GetAuthorizationToken cannot be
        # scoped to a single repository ARN, the push actions below are what
        # actually keep this role scoped to one repository.
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
        # CodePipeline service role's own S3 permissions below.
        Sid    = "ArtifactBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
        ]
        Resource = ["${aws_s3_bucket.pipeline_artifacts.arn}/*"]
      },
    ]
  })
}

resource "aws_codebuild_project" "capstone_build" {
  name          = "${var.name_prefix}-capstone-build"
  description   = "Capstone pipeline Build stage — reuses Day 1's buildspec.yml unchanged."
  service_role  = aws_iam_role.capstone_build.arn
  build_timeout = 15

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type                        = "ARM_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true # required for `docker build`/`docker push` — same as Day 1

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
    # Reused unchanged — see the RULING comment at the top of this file and
    # the comment at the top of labs/day01/buildspec.yml itself.
    buildspec = file("${path.module}/../day01/buildspec.yml")
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.capstone_build.name
    }
  }
}

# --- Capstone pipeline service role ----------------------------------------

resource "aws_iam_role" "capstone_pipeline" {
  name = "${var.name_prefix}-capstone-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "capstone_pipeline" {
  name = "${var.name_prefix}-capstone-pipeline-policy"
  role = aws_iam_role.capstone_pipeline.id

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
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*",
        ]
      },
      {
        Sid      = "ListArtifactBucket"
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [aws_s3_bucket.pipeline_artifacts.arn]
      },
      {
        # Same trip hazard noted in Day 2's oidc.tf-adjacent comments: the
        # IAM action prefix is still "codestar-connections" even though the
        # service itself was renamed CodeConnections.
        Sid      = "UseGitHubConnection"
        Effect   = "Allow"
        Action   = ["codestar-connections:UseConnection"]
        Resource = [var.codeconnection_arn]
      },
      {
        Sid    = "StartAndCheckBuilds"
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild",
          "codebuild:BatchGetBuilds",
        ]
        Resource = [aws_codebuild_project.capstone_build.arn]
      },
      {
        # What actually starts and drives the blue/green deployment against
        # Day 3's deployment group — the CodeDeployToECS action wraps these
        # calls, it doesn't grant its own permissions.
        Sid    = "DriveCodeDeploy"
        Effect = "Allow"
        Action = [
          "codedeploy:CreateDeployment",
          "codedeploy:GetApplication",
          "codedeploy:GetApplicationRevision",
          "codedeploy:GetDeployment",
          "codedeploy:GetDeploymentConfig",
          "codedeploy:RegisterApplicationRevision",
        ]
        Resource = [
          "arn:aws:codedeploy:${var.aws_region}:${data.aws_caller_identity.current.account_id}:application:${data.terraform_remote_state.day03.outputs.codedeploy_app_name}",
          "arn:aws:codedeploy:${var.aws_region}:${data.aws_caller_identity.current.account_id}:deploymentgroup:${data.terraform_remote_state.day03.outputs.codedeploy_app_name}/${data.terraform_remote_state.day03.outputs.codedeploy_group_name}",
          "arn:aws:codedeploy:${var.aws_region}:${data.aws_caller_identity.current.account_id}:deploymentconfig:*",
        ]
      },
      {
        # RegisterTaskDefinition has no resource-level scoping in the ECS
        # API — "*" is not a shortcut here, same reasoning as EcrAuth above.
        # DescribeTaskDefinition and DescribeServices ARE scoped, below.
        Sid      = "RegisterTaskDefinition"
        Effect   = "Allow"
        Action   = ["ecs:RegisterTaskDefinition"]
        Resource = "*"
      },
      {
        Sid    = "DescribeEcs"
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeTaskDefinition",
        ]
        Resource = [
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/${data.terraform_remote_state.day03.outputs.ecs_cluster_name}/${data.terraform_remote_state.day03.outputs.ecs_service_name}",
          "arn:aws:ecs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:task-definition/${var.name_prefix}-task:*",
        ]
      },
      {
        # The new task definition revision RegisterTaskDefinition creates
        # names an execution role and a task role (this lab's rendered
        # taskdef.json.tftpl points at Day 3's ${name_prefix}-ecs-execution
        # / ${name_prefix}-ecs-task, by the same naming-convention lookup
        # this file already uses for the ALB, above) — ECS needs to pass
        # this pipeline's permission to assume those roles along, or
        # RegisterTaskDefinition succeeds but the task never starts.
        Sid    = "PassEcsRoles"
        Effect = "Allow"
        Action = ["iam:PassRole"]
        Resource = [
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-ecs-execution",
          "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}-ecs-task",
        ]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ecs-tasks.amazonaws.com"
          }
        }
      },
    ]
  })
}

# --- The capstone pipeline itself ------------------------------------------

resource "aws_codepipeline" "capstone" {
  name          = "${var.name_prefix}-capstone-pipeline"
  role_arn      = aws_iam_role.capstone_pipeline.arn
  pipeline_type = "V2"

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.pipeline_artifacts.bucket
  }

  stage {
    name = "Source"

    action {
      name             = "SourceCode"
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

    action {
      # Second parallel Source action: pulls the rendered appspec.yaml +
      # taskdef.json zip (uploaded above) in as a plain S3 artifact. See the
      # "Deploy templates" comment above for why these can't come from the
      # Build stage's own output.
      name             = "DeployTemplates"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["TemplateOutput"]

      configuration = {
        S3Bucket             = aws_s3_object.pipeline_templates.bucket
        S3ObjectKey          = aws_s3_object.pipeline_templates.key
        PollForSourceChanges = "false"
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
        ProjectName = aws_codebuild_project.capstone_build.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      input_artifacts = ["BuildOutput", "TemplateOutput"]

      configuration = {
        ApplicationName                = data.terraform_remote_state.day03.outputs.codedeploy_app_name
        DeploymentGroupName            = data.terraform_remote_state.day03.outputs.codedeploy_group_name
        TaskDefinitionTemplateArtifact = "TemplateOutput"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "TemplateOutput"
        AppSpecTemplatePath            = "appspec.yaml"
        Image1ArtifactName             = "BuildOutput"
        # The name RegisterTaskDefinition's <IMAGE1_NAME> placeholder in
        # taskdef.json.tftpl gets substituted with — must match exactly.
        Image1ContainerName = "IMAGE1_NAME"
      }
    }
  }

  # Same V2 trigger-filter reasoning as Day 2: without this, every push to
  # every branch of the connected repo starts an execution. This narrows
  # execution starts to pushes on var.github_branch that touch app/**.
  trigger {
    provider_type = "CodeStarSourceConnection"

    git_configuration {
      source_action_name = "SourceCode"

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

# --- Notifications -----------------------------------------------------
# One SNS topic all of this lab's alarms notify. No email is subscribed by
# default (var.notification_email defaults to ""), so this lab can be
# authored and `terraform fmt`-checked with no real address anywhere in the
# repo. Set notification_email in your own terraform.tfvars to actually
# receive the page.

resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-day05-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  count = var.notification_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# --- p99 latency alarm ---------------------------------------------------
# Golden signal: latency. Day 3 already alarms on errors
# (HTTPCode_Target_5XX_Count, reused below as rollback_alarm_name) but has
# nothing watching latency. extended_statistic = "p99" instead of Average:
# a slow tail hurts real users long before the average moves.

resource "aws_cloudwatch_metric_alarm" "p99_latency" {
  alarm_name          = "${var.name_prefix}-p99-latency"
  alarm_description   = "p99 TargetResponseTime on the Day 3 ALB exceeded 1s for 3 consecutive periods."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  period              = 60
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p99"
  threshold           = 1.0 # seconds
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = data.aws_lb.day03.arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.name_prefix}-p99-latency"
  }
}

# --- Composite alarm: page only on a real user-facing outage -------------
# Combines Day 3's own 5XX rollback alarm with the p99 alarm above.
#
# TRADEOFF (see content/day05.md Core Concepts §5 and Exercise 4): requiring
# BOTH alarms to be in ALARM state before this pages cuts single-signal
# noise — a latency blip with no error increase, or a low-volume error
# burst that hasn't moved p99, won't wake anyone up. The failure mode this
# accepts: a real outage that trips only ONE of the two underlying alarms
# (e.g. errors spike but median-fast failures keep p99 under threshold)
# pages slower than a single-alarm design would have, because it's waiting
# on a second signal that may never arrive. That's a deliberate choice for
# a *page*; a dashboard should still show both alarms individually so nothing
# is lost for diagnosis.
#
# Composite alarms are billed as their own line item (~$0.50/alarm-month),
# separate from the ~$0.10/alarm-month standard-resolution alarms below
# them — see the cost comment at the top of this file. The first 10
# standard alarms per account are free either way, and this whole path
# stays well under that.

resource "aws_cloudwatch_composite_alarm" "outage" {
  alarm_name        = "${var.name_prefix}-real-outage"
  alarm_description = "Real user-facing outage: both the Day 3 5XX rate alarm AND this lab's p99 latency alarm are in ALARM."

  alarm_rule = "ALARM(\"${data.terraform_remote_state.day03.outputs.rollback_alarm_name}\") AND ALARM(\"${aws_cloudwatch_metric_alarm.p99_latency.alarm_name}\")"

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.name_prefix}-real-outage"
  }
}

# --- Synthetic canary ------------------------------------------------------
# The one signal in this lab that still produces data with zero real
# traffic — exactly the situation between exercises in this lab, and
# exactly the situation at 3am in production. See content/day05.md Core
# Concepts §6.

# TEARDOWN TRAP #1: this bucket is created FOR you by pointing a canary at
# it — nothing about "I created one canary" suggests a bucket also exists.
# force_destroy = true (like the foundation ECR repo's force_delete) so
# `terraform destroy` can remove it even if the canary has written
# screenshots/logs into it. The lifecycle rule additionally expires
# objects after 1 day so a canary left running between sessions doesn't
# quietly accumulate storage.
resource "aws_s3_bucket" "canary_artifacts" {
  bucket        = "${var.name_prefix}-canary-artifacts-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "${var.name_prefix}-canary-artifacts"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "canary_artifacts" {
  bucket = aws_s3_bucket.canary_artifacts.id

  rule {
    id     = "expire-after-1-day"
    status = "Enabled"

    filter {}

    expiration {
      days = 1
    }
  }
}

resource "aws_s3_bucket_public_access_block" "canary_artifacts" {
  bucket = aws_s3_bucket.canary_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# TEARDOWN TRAP #2: aws_synthetics_canary also creates a Lambda function
# behind the scenes to actually run canary.js.example on the schedule
# below. It is named after this canary and is NOT a separate Terraform
# resource in this file — `terraform destroy` on the canary resource
# removes it, but a manual console deletion of "the canary" alone can
# leave it (and its own CloudWatch log group) behind. teardown.md calls
# this out again, in order, as the first step of end-of-path teardown.

data "archive_file" "canary" {
  type        = "zip"
  output_path = "${path.module}/.terraform-canary-build/canary.zip"

  source {
    content  = file("${path.module}/canary.js.example")
    filename = "nodejs/node_modules/canary.js"
  }
}

resource "aws_iam_role" "canary" {
  name = "${var.name_prefix}-canary-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "canary" {
  name = "${var.name_prefix}-canary-policy"
  role = aws_iam_role.canary.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3Artifacts"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
        ]
        Resource = [
          aws_s3_bucket.canary_artifacts.arn,
          "${aws_s3_bucket.canary_artifacts.arn}/*",
        ]
      },
      {
        Sid      = "S3ListForConsole"
        Effect   = "Allow"
        Action   = ["s3:ListAllMyBuckets"]
        Resource = "*"
      },
      {
        Sid      = "Logs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/cwsyn-*"
      },
      {
        Sid      = "CloudWatchMetrics"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "CloudWatchSynthetics"
          }
        }
      },
      {
        Sid      = "XRay"
        Effect   = "Allow"
        Action   = ["xray:PutTraceSegments"]
        Resource = "*"
      },
    ]
  })
}

resource "aws_synthetics_canary" "readyz" {
  name                 = "${var.name_prefix}-readyz"
  artifact_s3_location = "s3://${aws_s3_bucket.canary_artifacts.bucket}/canary/"
  execution_role_arn   = aws_iam_role.canary.arn
  handler              = "canary.handler"
  zip_file             = data.archive_file.canary.output_path

  # Pin an exact runtime version, same reasoning as pinning images by
  # digest elsewhere in this path. CHECK THE CURRENT SUPPORTED VERSION at
  # https://docs.aws.amazon.com/AmazonSynthetics/latest/APIReference/API_UpdateCanary.html
  # before applying — AWS deprecates old canary runtimes on a schedule.
  runtime_version = var.canary_runtime_version

  schedule {
    expression = "rate(5 minutes)"
  }

  run_config {
    timeout_in_seconds = 30
    environment_variables = {
      TARGET_URL = "http://${data.aws_lb.day03.dns_name}/readyz"
    }
  }

  start_canary = true

  tags = {
    Name = "${var.name_prefix}-readyz-canary"
  }

  depends_on = [aws_iam_role_policy.canary]
}

resource "aws_cloudwatch_metric_alarm" "canary_failure" {
  alarm_name          = "${var.name_prefix}-canary-failure"
  alarm_description   = "The readyz canary failed its last run (success percent < 100)."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  period              = 300
  namespace           = "CloudWatchSynthetics"
  metric_name         = "SuccessPercent"
  statistic           = "Average"
  threshold           = 100
  treat_missing_data  = "breaching"

  dimensions = {
    CanaryName = aws_synthetics_canary.readyz.name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Name = "${var.name_prefix}-canary-failure"
  }
}

# --- Dashboard: the four golden signals, one place -----------------------
# Latency, traffic, errors, saturation, all reading the Day 3 stack.
# content/day05.md Core Concepts §3 is the mapping this dashboard encodes.

resource "aws_cloudwatch_dashboard" "golden_signals" {
  dashboard_name = "${var.name_prefix}-golden-signals"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Latency — TargetResponseTime (p99)"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", data.aws_lb.day03.arn_suffix, { stat = "p99" }]
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "Traffic — RequestCount"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", data.aws_lb.day03.arn_suffix, { stat = "Sum" }]
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Errors — HTTPCode_Target_5XX_Count"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", data.aws_lb.day03.arn_suffix, { stat = "Sum" }]
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "Saturation — ECS CPUUtilization / MemoryUtilization"
          region = var.aws_region
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", data.terraform_remote_state.day03.outputs.ecs_cluster_name, "ServiceName", data.terraform_remote_state.day03.outputs.ecs_service_name, { stat = "Average" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", data.terraform_remote_state.day03.outputs.ecs_cluster_name, "ServiceName", data.terraform_remote_state.day03.outputs.ecs_service_name, { stat = "Average" }]
          ]
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 24
        height = 4
        properties = {
          title  = "Canary SuccessPercent (works at zero real traffic)"
          region = var.aws_region
          metrics = [
            ["CloudWatchSynthetics", "SuccessPercent", "CanaryName", aws_synthetics_canary.readyz.name, { stat = "Average" }]
          ]
          period = 300
          view   = "timeSeries"
        }
      }
    ]
  })
}

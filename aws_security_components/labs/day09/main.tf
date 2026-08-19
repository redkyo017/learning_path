terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.4"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------------------------------------------------------------------------
# Shared data sources / locals
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

# Reference labs/base's outputs — do NOT edit labs/base itself. This lab
# only reads task_role_arn from it (the principal Day 8's break compromised
# and today's Lambda quarantines).
data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "${path.module}/../base/terraform.tfstate"
  }
}

locals {
  name_prefix = "${var.project}-day09"

  common_tags = merge(
    {
      Project   = var.project
      ManagedBy = "terraform"
      Layer     = "day09"
    },
    var.tags
  )

  task_role_arn = data.terraform_remote_state.base.outputs.task_role_arn
}

# ===========================================================================
# PART 1 — GuardDuty finding -> EventBridge -> quarantine Lambda
#
# GuardDuty needs no Terraform resource here: Day 8 already enabled the
# detector, and every finding it emits is published automatically to this
# account's default EventBridge event bus. This module only adds the rule
# and the target.
# ===========================================================================

# --- Deny-all permission boundary (the "full lockout" containment tool) ---

resource "aws_iam_policy" "quarantine_boundary" {
  name        = "${local.name_prefix}-quarantine-boundary"
  description = "Attached as a PERMISSIONS BOUNDARY (never as an identity policy) by the quarantine Lambda. Its only statement is an explicit Deny on everything, so the intersection with any identity policy is empty regardless of what that identity policy grants."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyEverythingUntilInvestigated"
      Effect   = "Deny"
      Action   = "*"
      Resource = "*"
    }]
  })

  tags = local.common_tags
}

# --- Lambda execution role, scoped to exactly the base task role's ARN ---
# (never iam:* / Resource:"*" — see ANTIPATTERNS.md #6 and content/day09's
# note on why the remediation Lambda's own permissions are the real risk.)

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "quarantine_lambda" {
  name               = "${local.name_prefix}-quarantine-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "quarantine_lambda" {
  name = "${local.name_prefix}-quarantine-lambda-policy"
  role = aws_iam_role.quarantine_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ScopedRoleContainmentOnly"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:PutRolePermissionsBoundary",
          "iam:PutRolePolicy",
          "iam:TagRole"
        ]
        # Scoped to the ONE role this lab is allowed to quarantine.
        # Do not widen this to "*" — this statement is why a bug in the
        # Lambda can't touch any other role in the account.
        Resource = local.task_role_arn
      },
      {
        Sid    = "OwnLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.name_prefix}-quarantine:*"
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "quarantine_lambda" {
  name              = "/aws/lambda/${local.name_prefix}-quarantine"
  retention_in_days = var.lambda_log_retention_days
  tags              = local.common_tags
}

data "archive_file" "quarantine_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_src/quarantine.py"
  output_path = "${path.module}/build/quarantine.zip"
}

resource "aws_lambda_function" "quarantine" {
  function_name    = "${local.name_prefix}-quarantine"
  role             = aws_iam_role.quarantine_lambda.arn
  handler          = "quarantine.handler"
  runtime          = "python3.12"
  timeout          = 30
  memory_size      = 128
  filename         = data.archive_file.quarantine_zip.output_path
  source_code_hash = data.archive_file.quarantine_zip.output_base64sha256

  environment {
    variables = {
      TASK_ROLE_ARN           = local.task_role_arn
      QUARANTINE_BOUNDARY_ARN = aws_iam_policy.quarantine_boundary.arn
      MIN_SEVERITY             = tostring(var.min_severity)
    }
  }

  depends_on = [aws_cloudwatch_log_group.quarantine_lambda]
  tags       = local.common_tags
}

# --- EventBridge rule: only High-or-above-severity GuardDuty findings ---

resource "aws_cloudwatch_event_rule" "guardduty_high_severity" {
  name        = "${local.name_prefix}-guardduty-high-severity"
  description = "Matches GuardDuty findings at or above var.min_severity (default 7 = the Medium/High boundary). See content/day09 exercise 1 for the pattern derivation."

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    "detail-type" = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", var.min_severity] }]
    }
  })
}

resource "aws_cloudwatch_event_target" "quarantine_lambda" {
  rule = aws_cloudwatch_event_rule.guardduty_high_severity.name
  arn  = aws_lambda_function.quarantine.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.quarantine.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_high_severity.arn
}

# ===========================================================================
# PART 2 — AWS Config: a public-bucket rule with a built-in remediation
#
# Self-contained: recorder, delivery channel, one managed rule, one
# automatic remediation, and a throwaway demo bucket to flag. Recording is
# scoped to AWS::S3::Bucket only (not all_supported) to keep Config's
# per-recorded-item cost near zero for this lab.
# ===========================================================================

data "aws_iam_policy_document" "config_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "config" {
  name               = "${local.name_prefix}-config-role"
  assume_role_policy = data.aws_iam_policy_document.config_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "config_managed" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_s3_bucket" "config_delivery" {
  bucket        = "${local.name_prefix}-config-delivery-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = local.common_tags
}

data "aws_iam_policy_document" "config_delivery_bucket" {
  statement {
    sid     = "AWSConfigBucketPermissionsCheck"
    effect  = "Allow"
    actions = ["s3:GetBucketAcl"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    resources = [aws_s3_bucket.config_delivery.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid     = "AWSConfigBucketDelivery"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
    resources = ["${aws_s3_bucket.config_delivery.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/Config/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "config_delivery" {
  bucket = aws_s3_bucket.config_delivery.id
  policy = data.aws_iam_policy_document.config_delivery_bucket.json
}

resource "aws_config_configuration_recorder" "this" {
  name     = "${local.name_prefix}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = false
    include_global_resource_types = false
    resource_types                = ["AWS::S3::Bucket"]
  }
}

resource "aws_config_delivery_channel" "this" {
  name           = "${local.name_prefix}-delivery-channel"
  s3_bucket_name = aws_s3_bucket.config_delivery.bucket

  depends_on = [
    aws_config_configuration_recorder.this,
    aws_s3_bucket_policy.config_delivery
  ]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true
  depends_on = [aws_config_delivery_channel.this]
}

# --- The demo target: a scratch bucket deliberately made public ---
# Holds no real data. Exists only so Config has something to flag today;
# destroyed at end of day along with everything else in this module.

resource "aws_s3_bucket" "config_demo" {
  bucket        = "${local.name_prefix}-config-demo-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.config_demo_bucket_force_destroy
  tags          = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "config_demo" {
  bucket                  = aws_s3_bucket.config_demo.id
  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

data "aws_iam_policy_document" "config_demo_public_read" {
  statement {
    sid     = "PublicReadDeliberateForDemo"
    effect  = "Allow"
    actions = ["s3:GetObject"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = ["${aws_s3_bucket.config_demo.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "config_demo_public_read" {
  bucket     = aws_s3_bucket.config_demo.id
  policy     = data.aws_iam_policy_document.config_demo_public_read.json
  depends_on = [aws_s3_bucket_public_access_block.config_demo]
}

# --- The Config rule + its automatic remediation ---

resource "aws_config_config_rule" "s3_public_read_prohibited" {
  name = "${local.name_prefix}-s3-public-read-prohibited"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }

  scope {
    compliance_resource_types = ["AWS::S3::Bucket"]
  }

  depends_on = [aws_config_configuration_recorder_status.this]
  tags       = local.common_tags
}

# SSM Automation execution role, scoped only to the demo bucket — the same
# "never iam:*, never Resource:*" discipline as the quarantine Lambda above.
data "aws_iam_policy_document" "remediation_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "remediation_automation" {
  name               = "${local.name_prefix}-config-remediation-role"
  assume_role_policy = data.aws_iam_policy_document.remediation_assume.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy" "remediation_automation" {
  name = "${local.name_prefix}-config-remediation-policy"
  role = aws_iam_role.remediation_automation.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ScopedPublicAccessBlockFixOnly"
      Effect = "Allow"
      Action = [
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketPublicAccessBlock",
        "s3:GetBucketPolicyStatus"
      ]
      Resource = aws_s3_bucket.config_demo.arn
    }]
  })
}

resource "aws_config_remediation_configuration" "s3_public_read_fix" {
  config_rule_name = aws_config_config_rule.s3_public_read_prohibited.name
  resource_type    = "AWS::S3::Bucket"
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWSConfigRemediation-ConfigureS3BucketPublicAccessBlock"
  # target_version intentionally omitted — let AWS resolve the current
  # published version of the managed document rather than pin one that
  # this manual-review process cannot verify is still current.

  automatic                  = true
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60

  parameter {
    name         = "AutomationAssumeRole"
    static_value = aws_iam_role.remediation_automation.arn
  }
  parameter {
    name           = "BucketName"
    resource_value = "RESOURCE_ID"
  }
  parameter {
    name         = "RestrictPublicBuckets"
    static_value = "true"
  }
  parameter {
    name         = "BlockPublicAcls"
    static_value = "true"
  }
  parameter {
    name         = "IgnorePublicAcls"
    static_value = "true"
  }
  parameter {
    name         = "BlockPublicPolicy"
    static_value = "true"
  }
}

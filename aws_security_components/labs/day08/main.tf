# ---------------------------------------------------------------------------
# Day 8 — Detection. Layers on labs/base via terraform_remote_state.
#
# Enables: a scoped CloudTrail trail (management events + S3 data events on
# the base app_data bucket only), GuardDuty, Security Hub (+ the AWS
# Foundational Security Best Practices standard), Macie (+ a one-time
# classification job on app_data), and a Detective behavior graph.
#
# Does NOT create any hourly-billing compute/edge resources — those are all
# in labs/base and follow base's own daily teardown cadence. Everything
# this module creates is meant to stay up overnight into Day 9 — see
# README "Teardown".
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../base/terraform.tfstate"
  }
}

locals {
  name_prefix     = "${var.project}-day08"
  app_bucket_arn  = data.terraform_remote_state.base.outputs.app_bucket_arn
  app_bucket_name = data.terraform_remote_state.base.outputs.app_bucket_name

  common_tags = merge(
    {
      Project   = var.project
      ManagedBy = "terraform"
      Layer     = "day08-detection"
    },
    var.tags
  )
}

# ---------------------------------------------------------------------------
# CloudTrail — the foundation. A dedicated, private log bucket (NOT the
# app_data bucket — never mix trail logs with the workload's own data),
# scoped to management events (always on, free) plus S3 data events for
# ONLY the base app_data bucket (never account-wide — see day content
# "CloudTrail" section and Exercise 3 on the cost/coverage tradeoff of that
# choice).
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "trail_logs" {
  bucket = "${local.name_prefix}-cloudtrail-${data.aws_caller_identity.current.account_id}"
  # This bucket persists all the way to the Day 12 final sweep (unlike the
  # detection services, which come down at end of Day 9 — see README
  # "Teardown"), so by the time it's actually destroyed it will hold
  # several days of log objects. force_destroy avoids a destroy-time error
  # on a non-empty bucket.
  force_destroy = true
  tags          = merge(local.common_tags, { Name = "${local.name_prefix}-cloudtrail" })
}

resource "aws_s3_bucket_public_access_block" "trail_logs" {
  bucket                  = aws_s3_bucket.trail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail_logs" {
  # Default SSE-S3 (AES256), not the base workload's CMK: using that CMK
  # here would require editing its key policy to trust the CloudTrail
  # service, and this module must not edit labs/base. SSE-S3 is AWS's own
  # documented default for a CloudTrail log bucket and costs nothing extra.
  bucket = aws_s3_bucket.trail_logs.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Short retention — trail logs are cheap to store but this keeps the bucket
# from growing unbounded across a multi-day sprint (mirrors the "keep it
# cheap" discipline in STRATEGY.md).
resource "aws_s3_bucket_lifecycle_configuration" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id
  rule {
    id     = "expire-trail-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = var.trail_log_retention_days
    }
  }
}

# Bucket policy for a CloudTrail destination bucket with Object Ownership =
# "Bucket owner enforced" (ACLs disabled — see aws_s3_bucket_ownership_
# controls above, matching labs/base's own convention). AWS's current
# guidance for this ownership mode drops the legacy AWSCloudTrailAclCheck /
# `s3:x-amz-acl` conditions entirely (those are for the older ACL-based
# bucket setup, and requiring an ACL header here would make CloudTrail's
# PutObject request fail against an ACLs-disabled bucket) — access is
# scoped purely via aws:SourceArn to THIS trail only (not "any trail in the
# account").
data "aws_iam_policy_document" "trail_logs_bucket_policy" {
  statement {
    sid    = "AWSCloudTrailWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail_logs.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${var.region}:${data.aws_caller_identity.current.account_id}:trail/${local.name_prefix}-trail"]
    }
  }

  statement {
    sid    = "AWSCloudTrailBucketExistenceCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail_logs.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cloudtrail:${var.region}:${data.aws_caller_identity.current.account_id}:trail/${local.name_prefix}-trail"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail_logs" {
  bucket = aws_s3_bucket.trail_logs.id
  policy = data.aws_iam_policy_document.trail_logs_bucket_policy.json
}

resource "aws_cloudtrail" "this" {
  name           = "${local.name_prefix}-trail"
  s3_bucket_name = aws_s3_bucket.trail_logs.id

  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true

  # Management events: on by default at no extra cost, but declared
  # explicitly so the trail's scope is visible in code, not implied.
  event_selector {
    read_write_type           = "All"
    include_management_events = true

    # Data events scoped to ONLY the base workload's app_data bucket — the
    # exact bucket the shared incident's stolen credentials are used
    # against. NOT account-wide (see day content + Exercise 3).
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${local.app_bucket_arn}/"]
    }
  }

  tags = local.common_tags

  depends_on = [aws_s3_bucket_policy.trail_logs]
}

# ---------------------------------------------------------------------------
# GuardDuty
# ---------------------------------------------------------------------------

resource "aws_guardduty_detector" "this" {
  enable = true
  # Fifteen minutes (vs. the six-hour default) so Day 9's EventBridge rule
  # gets a finding to react to without a long wait.
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Security Hub — account + one standard (AWS Foundational Security Best
# Practices). CIS AWS Foundations is deliberately NOT enabled here to keep
# finding volume and per-check cost down for a 2-day trial window (see day
# content "Security Hub" section).
# ---------------------------------------------------------------------------

resource "aws_securityhub_account" "this" {}

resource "aws_securityhub_standards_subscription" "fsbp" {
  standards_arn = "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0"
  depends_on    = [aws_securityhub_account.this]
}

# ---------------------------------------------------------------------------
# Macie — account + a ONE-TIME classification job on app_data only (not a
# scheduled job, not account-wide — see day content "Macie" section and
# ANTIPATTERNS.md #9).
# ---------------------------------------------------------------------------

resource "aws_macie2_account" "this" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
}

resource "aws_macie2_classification_job" "app_data" {
  name     = "${local.name_prefix}-appdata-scan"
  job_type = "ONE_TIME"

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [local.app_bucket_name]
    }
  }

  depends_on = [aws_macie2_account.this]
}

# ---------------------------------------------------------------------------
# Detective — graph only. No dedicated exercise today (needs history to
# accumulate); see day content "Detective" section. The Day 11-12 capstone
# is where this graph actually gets queried.
# ---------------------------------------------------------------------------

resource "aws_detective_graph" "this" {
  tags = local.common_tags
}

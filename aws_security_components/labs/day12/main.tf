# ---------------------------------------------------------------------------
# Day 12 — IR capstone: defend. This module has THREE jobs, matched to the
# runbook's ERADICATE phase (CONTAIN and RECOVER are CLI steps — see
# labs/capstone/defend-runbook.md and README.md; a live incident can't wait
# on a plan/apply cycle, so this module codifies only the PERMANENT fix):
#
#   1. (optional) stand up a short-lived "leaked long-lived access key"
#      fixture that simulates Day 11's initial-access identity. Day 11
#      deliberately did NOT create a real second IAM identity for this
#      (see labs/capstone/attack-runbook.md's rationale — it narrated the
#      "leaked key" using the deployer's own credentials, to avoid its own
#      instance of secret sprawl). So this module creates one now, purely
#      so CONTAIN Step 1 has a real, concrete key to revoke — and it gets
#      destroyed same-day in the final sweep, same reasoning Day 11 used.
#   2. Layer an explicit-Deny tightening policy on the EXISTING base task
#      role (looked up, not re-declared) — this is the permanent fix for
#      the identity-policy door the Day 11 attack actually walked through.
#   3. Attach a WAF rule to the base ALB blocking SSRF-to-metadata payloads
#      in the /fetch?url= query string — the permanent fix for the
#      request-layer entry point.
#
# NAMING-CONVENTION NOTE: labs/base's outputs.tf does not export the KMS
# key ARN or the DynamoDB table ARN directly. Both are looked up here via
# data sources using the naming convention labs/base/data.tf documents
# (bucket = "${project}-appdata-${account_id}" via the task_role/app_bucket
# outputs; table = "${project}-appdata"; KMS alias =
# "alias/${project}-app-data"). If you changed `project` from the default
# in labs/base, keep the same value here.
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

data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../base/terraform.tfstate"
  }
}

# --- Look up base resources by their documented naming convention ---------
# (not re-declared / not managed by this module — this module only ADDS
# policy and WAF resources on top of what base already created.)

data "aws_dynamodb_table" "app_data" {
  name = "${var.project}-appdata"
}

data "aws_kms_alias" "app_data" {
  name = "alias/${var.project}-app-data"
}

locals {
  task_role_arn = data.terraform_remote_state.base.outputs.task_role_arn
  # Same technique Day 1's module uses: base's role ARNs have no custom
  # path (arn:aws:iam::<account>:role/<name>), so the friendly name is
  # everything after the last "/" — aws_iam_role_policy.role requires
  # the friendly name, not the ARN.
  task_role_name = regex("[^/]+$", local.task_role_arn)
  app_bucket_arn = data.terraform_remote_state.base.outputs.app_bucket_arn
  alb_arn        = data.terraform_remote_state.base.outputs.alb_arn
  table_arn      = data.aws_dynamodb_table.app_data.arn
  kms_key_arn    = data.aws_kms_alias.app_data.target_key_arn

  common_tags = merge(
    {
      Project = var.project
      ManagedBy = "terraform"
      Layer   = "day12-defend"
    },
    var.tags
  )
}

# ---------------------------------------------------------------------------
# 1. Leaked-credential fixture (CONTAIN target). SECURITY NOTE: this
#    resource intentionally creates a real, valid IAM access key that this
#    lab treats as "already compromised" for teaching purposes. Terraform
#    state (local, gitignored — see repo .gitignore) will contain the
#    secret key material in plaintext. Never print it outside your own
#    terminal, never commit .terraform/ or *.tfstate*, and delete the key
#    (Step CONTAIN-1 in the runbook) before you do anything else. This is
#    Antipattern #8 and #10 made concrete on purpose.
# ---------------------------------------------------------------------------

resource "aws_iam_user" "leaked" {
  count = var.create_leaked_user_fixture ? 1 : 0
  name  = var.leaked_user_name
  tags = merge(local.common_tags, {
    Purpose = "Simulates Day 11's leaked long-lived access key (initial access). Recon-only. Treat as already compromised."
  })
}

resource "aws_iam_user_policy" "leaked_recon_only" {
  count = var.create_leaked_user_fixture ? 1 : 0
  name  = "${var.leaked_user_name}-recon-only"
  user  = aws_iam_user.leaked[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReconOnly"
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "iam:GetUser",
          "s3:ListAllMyBuckets",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "leaked" {
  count = var.create_leaked_user_fixture ? 1 : 0
  user  = aws_iam_user.leaked[0].name
}

# ---------------------------------------------------------------------------
# 2. ERADICATE — explicit-Deny tightening layered on the EXISTING task
#    role. Explicit Deny is evaluated first in the order, so this closes
#    the excess grant regardless of what base's original identity policy
#    allows — no need to touch or re-author that policy.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "eradicate_tighten" {
  statement {
    sid       = "DenyS3DeleteAnywhereInBucket"
    effect    = "Deny"
    actions   = ["s3:DeleteObject", "s3:DeleteObjectVersion"]
    resources = ["${local.app_bucket_arn}/*"]
  }

  statement {
    sid           = "DenyS3ReadWriteOutsideAllowedPrefix"
    effect        = "Deny"
    actions       = ["s3:GetObject", "s3:PutObject"]
    not_resources = ["${local.app_bucket_arn}/${var.app_object_prefix}/*"]
  }

  statement {
    sid       = "DenyDynamoDBBulkScan"
    effect    = "Deny"
    actions   = ["dynamodb:Scan"]
    resources = [local.table_arn]
  }

  # Day 11's EC2 dry-run pivot check (attack-runbook.md stage 6) may have
  # returned DryRunOperation (permission check passed) or
  # UnauthorizedOperation (already denied), depending on exactly what your
  # account's task role carried at the time you ran it — see your own
  # attack-SOLUTION.md. Either way, the task role has no legitimate reason
  # to call ANY EC2 action, so this closes the pivot permanently and
  # provably rather than relying on an absence-of-grant that's easy to
  # accidentally widen later.
  statement {
    sid       = "DenyEc2ComputePivot"
    effect    = "Deny"
    actions   = ["ec2:*"]
    resources = ["*"]
  }

  # Antipattern #5 tie-in: "who can decrypt?" — Decrypt/GenerateDataKey are
  # legitimately needed when S3/DynamoDB/Secrets Manager use this CMK on
  # the app's behalf, but a DIRECT `aws kms decrypt` call using stolen
  # task-role creds (to decrypt exfiltrated ciphertext offline) is not a
  # legitimate use. kms:ViaService is absent/different on a direct call,
  # so this Deny fires only for the direct-call path.
  statement {
    sid       = "DenyDirectKmsUseNotViaTrustedService"
    effect    = "Deny"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [local.kms_key_arn]
    condition {
      test     = "StringNotEquals"
      variable = "kms:ViaService"
      values = [
        "s3.${var.region}.amazonaws.com",
        "dynamodb.${var.region}.amazonaws.com",
        "secretsmanager.${var.region}.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role_policy" "eradicate_tighten" {
  name   = "${var.project}-task-day12-eradicate-deny"
  role   = local.task_role_name
  policy = data.aws_iam_policy_document.eradicate_tighten.json
}

# ---------------------------------------------------------------------------
# 3. ERADICATE — WAF rule on the base ALB (REGIONAL scope — the base
#    workload's ALB has a public DNS name that bypasses CloudFront, so a
#    CloudFront-only Web ACL would leave that path open; the ALB is the one
#    chokepoint both the direct path and the CloudFront path share).
#    COST NOTE: WAF Web ACLs bill ~$5/month + ~$1/rule + per-request — this
#    is a "day-specific pricey resource" per the shared teardown model and
#    MUST be destroyed same-day (see README teardown checklist), not left
#    up past this lab.
# ---------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "capstone_defend" {
  name        = "${var.project}-day12-defend-acl"
  description = "Day 12 eradication control: blocks SSRF-to-cloud-metadata payloads against the app's /fetch endpoint at the edge, before the vulnerable code path ever runs."
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "block-metadata-ssrf-in-url-param"
    priority = 1

    action {
      block {}
    }

    statement {
      or_statement {
        dynamic "statement" {
          for_each = var.waf_metadata_block_patterns
          content {
            byte_match_statement {
              search_string         = statement.value
              positional_constraint = "CONTAINS"

              field_to_match {
                query_string {}
              }

              text_transformation {
                priority = 0
                type     = "URL_DECODE"
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "day12-block-metadata-ssrf"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-day12-defend-acl"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = local.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.capstone_defend.arn
}

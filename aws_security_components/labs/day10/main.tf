# ---------------------------------------------------------------------------
# Day 10 — Governance & multi-account
#
# Layers on labs/base via terraform_remote_state (base must be applied
# first). Three things happen here:
#
#   1. An SCP (deny-list, denies CloudTrail tamper org-wide) — PLAN-ONLY by
#      default (var.enable_org_resources = false). A single-account learner
#      has no Organization to attach it to; review the JSON + `terraform
#      plan` output, don't expect `apply` to succeed without a real org.
#   2. A demo IAM role + a permission boundary that keys on ABAC tags — REAL,
#      applied resources, cheap (an IAM role and two managed policies cost
#      nothing to keep, and are destroyed same-day per the lab README).
#   3. ABAC tags applied for real onto base-workload resources, via a
#      merge-safe AWS CLI script (NOT by editing labs/base — its resources
#      stay owned by base's own state).
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
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
  # --- Names/ARNs extracted from base outputs -------------------------------
  task_role_arn = data.terraform_remote_state.base.outputs.task_role_arn
  # regex() with exactly ONE capture group returns that captured string
  # directly (not wrapped in a list) — do not index this with [0].
  task_role_name = regex("role/([^/]+)$", local.task_role_arn)

  app_bucket_name = data.terraform_remote_state.base.outputs.app_bucket_name
  app_bucket_arn  = data.terraform_remote_state.base.outputs.app_bucket_arn

  secret_arn = data.terraform_remote_state.base.outputs.secret_arn

  # base's db_endpoint output is a DOCUMENTED STAND-IN string, not a bare
  # ARN (see labs/base/outputs.tf) — pull the table name out of it and
  # reconstruct the ARN, rather than editing base to add a new output.
  # Same single-capture-group rule applies here — no [0] indexing.
  dynamodb_table_name = regex("table=([^)]+)\\)", data.terraform_remote_state.base.outputs.db_endpoint)
  dynamodb_table_arn  = "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${local.dynamodb_table_name}"

  # NOTE: the base KMS CMK is intentionally NOT tagged here — its ARN is not
  # part of base's outputs contract (see labs/base/outputs.tf), and adding
  # one means editing labs/base, which this day's constraints forbid. Tag it
  # manually (`aws kms tag-resource --key-id <id> --tags ...`) if you want
  # full ABAC coverage across every base resource.

  abac_tags = {
    Project            = var.abac_project_tag
    Environment        = var.abac_environment_tag
    DataClassification = var.abac_classification_tag
  }
}

# ---------------------------------------------------------------------------
# 1. ORG-LEVEL — SCP, plan-only unless you have a real Organization.
#    count = 0 by default so `terraform plan`/`apply` never attempts to
#    reach an Organizations API that doesn't exist for a single account.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "deny_cloudtrail_tamper" {
  statement {
    sid    = "DenyCloudTrailTamper"
    effect = "Deny"
    actions = [
      "cloudtrail:StopLogging",
      "cloudtrail:DeleteTrail",
      "cloudtrail:UpdateTrail",
    ]
    resources = ["*"]
  }
}

resource "aws_organizations_policy" "deny_cloudtrail_tamper" {
  count       = var.enable_org_resources ? 1 : 0
  name        = "${var.project}-deny-cloudtrail-tamper"
  description = "SCP: deny org-wide CloudTrail disable/delete/silent-narrow. Exercise 1 answer."
  type        = "SERVICE_CONTROL_POLICY"
  content     = data.aws_iam_policy_document.deny_cloudtrail_tamper.json
}

resource "aws_organizations_policy_attachment" "deny_cloudtrail_tamper" {
  count      = var.enable_org_resources ? 1 : 0
  policy_id  = aws_organizations_policy.deny_cloudtrail_tamper[0].id
  target_id  = var.org_scp_target_id
}

# ---------------------------------------------------------------------------
# 2. REAL — demo role + ABAC-conditioned permission boundary.
#
#    "The break": abac_demo_role's own identity policy alone allows
#    s3:GetObject/PutObject on ANY bucket (Resource = "*") — a stand-in for
#    "if this were the only control, it would reach every bucket in the
#    account, not just the tagged one."
#
#    "The harden": the permission boundary attached to the SAME role only
#    permits that action when the resource's Project tag matches the role's
#    own Project tag (aws:PrincipalTag comes from the role's own tags,
#    below) — the effective permission is the INTERSECTION of the identity
#    policy and the boundary, so the broad identity Allow is narrowed down
#    to just the correctly tagged bucket. See SOLUTION.md for the
#    simulator/trace proof.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "abac_boundary" {
  statement {
    sid    = "ABACScopedS3Access"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/Project"
      values   = ["$${aws:PrincipalTag/Project}"]
    }
  }
  statement {
    # Boundaries are an allow-list ceiling — anything not explicitly
    # allowed above is already capped out. This statement just makes the
    # ceiling's shape legible in the console/plan output; it grants
    # nothing beyond what statement 1 already allows.
    sid       = "ExplicitlyNothingElse"
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "abac_boundary" {
  name        = "${var.project}-day10-abac-boundary"
  description = "Permission boundary: caps identity grants to resources whose Project tag matches the principal's own Project tag."
  policy      = data.aws_iam_policy_document.abac_boundary.json
}

data "aws_iam_policy_document" "abac_demo_role_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "abac_demo_role" {
  name                 = var.demo_role_name
  assume_role_policy   = data.aws_iam_policy_document.abac_demo_role_trust.json
  permissions_boundary = aws_iam_policy.abac_boundary.arn

  # The role's OWN tags populate aws:PrincipalTag/* for any session that
  # assumes it (unless a session tag with the same key overrides it) — this
  # is what lets the boundary's Condition compare against a real value
  # without requiring the caller to pass session tags at AssumeRole time.
  tags = local.abac_tags
}

data "aws_iam_policy_document" "abac_demo_role_identity" {
  statement {
    sid    = "BroadS3AllowTheBreak"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "abac_demo_role_identity" {
  name   = "${var.project}-day10-broad-s3-identity-policy"
  role   = aws_iam_role.abac_demo_role.id
  policy = data.aws_iam_policy_document.abac_demo_role_identity.json
}

# ---------------------------------------------------------------------------
# 3. REAL — apply the ABAC tag scheme onto base-workload resources, without
#    editing labs/base. Each AWS CLI call below uses that service's own
#    additive tag-resource API (merge, not replace) EXCEPT S3, whose
#    put-bucket-tagging call is authoritative — the script reads existing
#    tags first and merges, specifically so it doesn't wipe out base's own
#    Project/ManagedBy/Layer tags. See content/day10-...md "Anti-patterns
#    today" for why that merge step matters.
# ---------------------------------------------------------------------------

resource "null_resource" "apply_abac_tags" {
  triggers = {
    project        = var.abac_project_tag
    environment    = var.abac_environment_tag
    classification = var.abac_classification_tag
    task_role      = local.task_role_name
    bucket         = local.app_bucket_name
    secret_arn     = local.secret_arn
    table_arn      = local.dynamodb_table_arn
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/tag-base-resources.sh '${local.task_role_name}' '${local.app_bucket_name}' '${local.secret_arn}' '${local.dynamodb_table_arn}' '${var.abac_project_tag}' '${var.abac_environment_tag}' '${var.abac_classification_tag}'"
  }
}

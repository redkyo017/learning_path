# ---------------------------------------------------------------------------
# Day 3 — KMS foundations lab.
#
# Layers on labs/base's EXISTING customer-managed key (aws_kms_key.app_data)
# and EXISTING S3 bucket (aws_s3_bucket.app_data). Creates NO new CMK.
#
# What this module creates:
#   - Two test IAM roles: "principal_a" (the INTENDED reader) and
#     "principal_b" (an UNINTENDED reader that, by a realistic copy-paste
#     mistake, got the exact same KMS + S3 identity-policy grant as A).
#   - Optionally (enable_key_policy_hardening = true) an aws_kms_key_policy
#     resource that REPLACES base's key policy with an explicit
#     administrators-only + principal-A-only-for-usage policy.
#
# THE BREAK  (enable_key_policy_hardening = false, the default):
#   base's CMK has no explicit key policy of its own, so it carries the
#   AWS default — a statement granting the account root ARN "kms:*", which
#   AWS documents as "delegate to IAM." Because BOTH principal_a and
#   principal_b carry an identical identity-policy grant, BOTH can decrypt.
#   That's the mistake: the encrypted-at-rest checkbox was true the whole
#   time, and it didn't stop the wrong principal at all.
#
# THE HARDEN (enable_key_policy_hardening = true):
#   the key policy is replaced with (1) a key-administrators statement
#   scoped to MANAGEMENT actions only (never kms:Decrypt/Encrypt/
#   GenerateDataKey — see content/day03-kms-foundations.md on why the
#   admin statement must exclude usage actions or the "delegate to IAM"
#   loophole reopens), and (2) a usage statement naming ONLY principal_a's
#   role ARN. principal_b's identity policy is UNCHANGED — still grants
#   kms:Decrypt — and it is no longer enough, because the resource-based
#   door (checked before identity policy in the evaluation order) no
#   longer names principal_b at all.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # aws_kms_key_policy (manage a key's policy independently of the
      # aws_kms_key resource that created it — exactly what's needed here,
      # since labs/base owns aws_kms_key.app_data and this module must not
      # edit labs/base) requires a reasonably recent provider.
      version = ">= 5.15"
    }
  }
}

provider "aws" {
  region = var.region
}

# --- Reference the base workload -------------------------------------------
# base's LOCAL state (the standard pattern for layering a day module on the
# persistent base workload). Gives us the app-data S3 bucket. The CMK itself
# is resolved below via its well-known alias for illustration.

data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../base/terraform.tfstate"
  }
}

# base/data.tf creates this alias unconditionally as
# "alias/${var.project}-app-data" where var.project is base's own `project`
# variable (default "aws-sec-lab"). Keep this module's `project` variable
# equal to whatever value you deployed base with.
data "aws_kms_alias" "app_data" {
  name = "alias/${var.project}-app-data"
}

locals {
  name_prefix   = "day03"
  bucket_name   = data.terraform_remote_state.base.outputs.app_bucket_name
  bucket_arn    = data.terraform_remote_state.base.outputs.app_bucket_arn
  cmk_arn       = data.aws_kms_alias.app_data.target_key_arn
  cmk_key_id    = data.aws_kms_alias.app_data.target_key_id
  test_prefix   = "day03/"

  common_tags = merge(
    {
      Project   = var.project
      ManagedBy = "terraform"
      Layer     = "day03"
    },
    var.tags
  )
}

# --- Trust policy shared by both test principals ----------------------------
# Trusted principal = the learner's OWN IAM identity (the one they run the
# AWS CLI as day to day). They assume INTO principal_a/b with
# `aws sts assume-role` to run the break/harden tests as each principal.

data "aws_iam_policy_document" "assume_by_learner" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [var.learner_principal_arn]
    }
  }
}

# --- The identity-policy grant, IDENTICAL for A and B -----------------------
# This is deliberate: A and B never differ in their identity policy. The
# only thing that changes between break and harden is the KMS KEY policy.
# That is the entire point of the lesson — identity policy alone cannot be
# the thing that tells these two principals apart; only the resource-based
# door can.

data "aws_iam_policy_document" "kms_and_s3_usage" {
  statement {
    sid       = "UseAppDataKey"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [local.cmk_arn]
  }

  statement {
    sid       = "ReadWriteTestPrefix"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${local.bucket_arn}/${local.test_prefix}*"]
  }

  statement {
    sid       = "ListBucketForTestPrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.bucket_arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.test_prefix}*"]
    }
  }
}

# --- Principal A: the INTENDED reader ---------------------------------------

resource "aws_iam_role" "principal_a" {
  name               = "${local.name_prefix}-principal-a-role"
  assume_role_policy = data.aws_iam_policy_document.assume_by_learner.json
  tags               = merge(local.common_tags, { Name = "${local.name_prefix}-principal-a-role", Intent = "intended-reader" })
}

resource "aws_iam_role_policy" "principal_a" {
  name   = "${local.name_prefix}-principal-a-policy"
  role   = aws_iam_role.principal_a.id
  policy = data.aws_iam_policy_document.kms_and_s3_usage.json
}

# --- Principal B: the UNINTENDED reader (copy-paste mistake) ---------------

resource "aws_iam_role" "principal_b" {
  name               = "${local.name_prefix}-principal-b-role"
  assume_role_policy = data.aws_iam_policy_document.assume_by_learner.json
  tags               = merge(local.common_tags, { Name = "${local.name_prefix}-principal-b-role", Intent = "UNINTENDED-reader-should-be-denied" })
}

resource "aws_iam_role_policy" "principal_b" {
  name   = "${local.name_prefix}-principal-b-policy"
  role   = aws_iam_role.principal_b.id
  policy = data.aws_iam_policy_document.kms_and_s3_usage.json # identical to A on purpose
}

# --- THE HARDEN: replace base CMK's key policy ------------------------------

data "aws_iam_policy_document" "hardened_key_policy" {
  # Key administrators: management actions ONLY. Deliberately excludes
  # kms:Decrypt / kms:Encrypt / kms:GenerateDataKey* / kms:ReEncrypt* — a
  # broad "kms:*" here would silently re-open the same IAM-delegation
  # loophole this harden is meant to close (see content file).
  statement {
    sid    = "KeyAdministration"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [var.learner_principal_arn]
    }
    actions = [
      "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
      "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
      "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
      "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
    ]
    resources = ["*"]
  }

  # Usage: ONLY principal_a. principal_b is not named here — and is not
  # covered by the administrators statement either, so principal_b's
  # unchanged identity-policy grant of kms:Decrypt now has nothing on the
  # resource-based side to pair with.
  statement {
    sid    = "AllowIntendedPrincipalUsageOnly"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.principal_a.arn]
    }
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = ["*"]
  }
}

resource "aws_kms_key_policy" "app_data_hardened" {
  count  = var.enable_key_policy_hardening ? 1 : 0
  key_id = local.cmk_key_id
  policy = data.aws_iam_policy_document.hardened_key_policy.json
}

# ---------------------------------------------------------------------------
# Day 4 — KMS advanced + data at rest
#
# Layers on labs/base via terraform_remote_state. Does NOT modify any file
# under labs/base. The one resource here that touches a base-owned object
# is aws_kms_key_policy.app_data — it manages the EXISTING base CMK's key
# policy (a KMS key has exactly one policy document; this resource sets the
# whole thing, referenced by key_id, not a new key). On `destroy`, the AWS
# provider reverts the key to AWS's default key policy (root-delegates-to-
# IAM) — the same state base itself leaves the key in, since base's data.tf
# never sets an explicit `policy` on aws_kms_key.app_data. See README
# "Teardown" for why that matters.
#
# THE BREAK / HARDEN TOGGLE: var.break_key_policy. false (default) = the
# locked policy (kms:ViaService-scoped decrypt). true = the broken policy
# (same statement, Condition block removed). Flip it, re-apply, re-test —
# that one-variable diff is the whole lab. See content/day04-*.md and
# SOLUTION.md.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # aws_kms_key_policy (used below) requires a provider version that
      # ships that resource — added in hashicorp/terraform-provider-aws
      # v4.59, well within base's own ">= 5.0" floor, so no bump beyond
      # base's constraint is actually needed. Manual review note (no
      # `terraform init` was run to confirm provider resolution — see
      # report).
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  name_prefix = "${var.project}-day04"

  # data.aws_caller_identity.current.arn is an STS ASSUMED-ROLE SESSION arn
  # (arn:...:sts::<acct>:assumed-role/<role>/<session>) whenever you're
  # authenticated via SSO/AssumeRole, which is the common case — and IAM
  # rejects a session ARN as a trust-policy Principal (it wants the
  # underlying role, not one specific session of it). Detect that shape and
  # fall back to the underlying role's IAM arn; leave IAM-user callers
  # (arn:...:iam::<acct>:user/<name>) untouched.
  caller_arn      = data.aws_caller_identity.current.arn
  caller_is_role  = can(regex("^arn:[^:]+:sts::[0-9]+:assumed-role/", local.caller_arn))
  trust_principal = local.caller_is_role ? "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${split("/", local.caller_arn)[1]}" : local.caller_arn
}

# --- Base state ---------------------------------------------------------

data "terraform_remote_state" "base" {
  backend = "local"
  config = {
    path = "../base/terraform.tfstate"
  }
}

# The base CMK has no output in base/outputs.tf (Day 4 is the first day to
# need it) and labs/base is off-limits to edit, so we resolve it the same
# way any other principal outside base's own state would: by its published
# alias. Base names the alias alias/${var.project}-app-data (see
# labs/base/data.tf, aws_kms_alias.app_data) — var.project here MUST match
# the project value base was applied with (see README).
data "aws_kms_alias" "app_data" {
  name = "alias/${var.project}-app-data"
}

# --- "Stolen credential" simulation --------------------------------------
#
# We can't literally steal the live ECS task role's credentials here without
# the SSRF chain that Day 8/11 builds — that's a different day's lesson.
# Instead this role is deliberately given essentially the same KMS statement
# shape the real task role already carries (see labs/base/iam.tf, Sid
# "DecryptAppDataKey": kms:Decrypt + kms:GenerateDataKey on this CMK, no
# kms:ViaService condition) plus the same narrow S3 read the app uses — the
# one difference is this sim role's statement also grants kms:DescribeKey,
# which the real task role's statement does not have; that extra action
# doesn't change the lesson (DescribeKey isn't what the exfil path needs),
# it's just not a byte-for-byte mirror. It
# exists only so you (the account owner) can assume it with your own
# credentials and observe exactly what a holder of the task role's
# permissions could and couldn't do. Trust policy only allows YOUR current
# caller identity to assume it.

resource "aws_iam_role" "exfil_sim" {
  name = "${local.name_prefix}-exfil-sim-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowSelfAssume"
      Effect    = "Allow"
      Principal = { AWS = local.trust_principal }
      Action    = "sts:AssumeRole"
    }]
  })
  tags = merge(var.tags, { Name = "${local.name_prefix}-exfil-sim-role", Day = "04" })
}

resource "aws_iam_role_policy" "exfil_sim" {
  name = "${local.name_prefix}-exfil-sim-policy"
  role = aws_iam_role.exfil_sim.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Mirrors labs/base/iam.tf's "DecryptAppDataKey" statement exactly:
        # unconditioned kms:Decrypt/GenerateDataKey. Deliberately NOT scoped
        # here either — the point of this lab is that the fix belongs on
        # the KEY policy side (aws_kms_key_policy.app_data below), not
        # here. See content "The engine lens".
        Sid      = "MirrorTaskRoleKMSGrant"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
        Resource = [data.aws_kms_alias.app_data.target_key_arn]
      },
      {
        # Scoped to exactly one object (least privilege on the identity
        # side) so the only interesting variable in this lab is the key
        # policy, not this statement.
        Sid      = "ReadOneTestObject"
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = ["${data.terraform_remote_state.base.outputs.app_bucket_arn}/${var.test_object_key}"]
      }
    ]
  })
}

# --- A small SSE-KMS test object (proves the legitimate via-S3 path) ------

resource "aws_s3_object" "exfil_test_object" {
  bucket                 = data.terraform_remote_state.base.outputs.app_bucket_name
  key                    = var.test_object_key
  content                = "day04 lab test object — not sensitive, safe to encrypt/decrypt/delete during this lab."
  server_side_encryption = "aws:kms"
  kms_key_id             = data.aws_kms_alias.app_data.target_key_arn
  tags                   = merge(var.tags, { Name = "${local.name_prefix}-exfil-test-object", Day = "04" })
}

# --- The key policy itself: locked vs. broken ------------------------------

data "aws_iam_policy_document" "key_policy_locked" {
  # Required on every key policy: without this (or an equivalent), IAM
  # identity policies stop mattering at all for this key, including for
  # you as the account owner/admin — see content "Anti-patterns today".
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # THE LOCK: decrypt for the simulated task-role principal is only
  # honored when the request arrives via S3 or DynamoDB — never a direct
  # KMS API call. This is what a stolen-credential direct decrypt attempt
  # is supposed to run into.
  statement {
    sid    = "AllowDecryptViaServiceOnly"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.exfil_sim.arn]
    }
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values = [
        "s3.${var.region}.amazonaws.com",
        "dynamodb.${var.region}.amazonaws.com",
      ]
    }
  }
}

data "aws_iam_policy_document" "key_policy_broken" {
  statement {
    sid    = "EnableIAMUserPermissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # *** THE BREAK — this statement is the ENTIRE diff from the locked
  # policy above. Same Sid family, same principal, same actions, same
  # resource — the Condition block is gone. That's it. That's the whole
  # misconfiguration. See SOLUTION.md "Which statement opened it". ***
  statement {
    sid    = "AllowDecryptAnySource"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.exfil_sim.arn]
    }
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = ["*"]
  }
}

resource "aws_kms_key_policy" "app_data" {
  key_id = data.aws_kms_alias.app_data.target_key_id
  policy = var.break_key_policy ? data.aws_iam_policy_document.key_policy_broken.json : data.aws_iam_policy_document.key_policy_locked.json
}

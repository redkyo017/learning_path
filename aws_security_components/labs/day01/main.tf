# ---------------------------------------------------------------------------
# Day 1 lab — tighten the base task role's S3 grant WITHOUT editing
# labs/base/iam.tf (every other day of this sprint layers on that same
# base, so it can't be edited out from under them).
#
# TECHNIQUE: attach a SECOND identity-based policy to the same role
# (aws_iam_role.task, referenced by name via the base's task_role_arn
# output) containing explicit Deny statements for exactly the excess
# breadth called out in iam.tf's design comment:
#   - s3:DeleteObject and s3:ListBucket — the app never calls either.
#   - s3:GetObject / s3:PutObject outside the app's actual object
#     prefix — the app only ever needs one prefix, not the whole
#     bucket.
#
# Per the canonical evaluation order (explicit Deny -> SCP/RCP ->
# resource-based policy -> identity-based policy -> permission boundary
# -> session policy), an explicit Deny in ANY identity-based policy
# attached to a principal wins over an Allow in any OTHER
# identity-based policy attached to that same principal. That's what
# lets this overlay cancel out the base statement's excess breadth
# without ever touching the base statement itself. See
# content/day01-iam-engine.md "Least privilege without editing the
# original grant" for the full explanation.
#
# NOTE ON THE SECOND DENY STATEMENT'S SCOPE: DenyGetPutOutsideAppPrefix
# uses NotResource, which (by IAM grammar) applies across the whole
# partition, not just this bucket. That's intentionally left broad here
# because the base task role is never granted s3:GetObject/PutObject on
# ANY bucket other than app_data in the first place (see iam.tf) — there
# is nothing else in scope for this Deny to unintentionally block. In an
# account where this role held broader S3 grants elsewhere, you would
# additionally scope this statement's Resource to this bucket's ARN
# pattern to avoid over-reach.
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
    path = var.base_state_path
  }
}

locals {
  task_role_arn = data.terraform_remote_state.base.outputs.task_role_arn
  # IAM role ARNs from this base workload have no custom path
  # (arn:aws:iam::<account>:role/<name>), so the friendly name is
  # everything after the last "/". aws_iam_role_policy.role requires the
  # friendly name, not the ARN.
  task_role_name = regex("[^/]+$", local.task_role_arn)
  app_bucket_arn = data.terraform_remote_state.base.outputs.app_bucket_arn
}

resource "aws_iam_role_policy" "day01_tighten_app_data_access" {
  name = "day01-deny-out-of-scope-s3-access"
  role = local.task_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Trace D / harden step 1 (see content/day01-iam-engine.md):
        # the app never calls either action, regardless of prefix.
        Sid    = "DenyDeleteAndListWholeBucket"
        Effect = "Deny"
        Action = [
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          local.app_bucket_arn,
          "${local.app_bucket_arn}/*"
        ]
      },
      {
        # Harden step 2: restrict GetObject/PutObject to the app's
        # documented object prefix (var.app_object_prefix) — see that
        # variable's description for why this prefix, not the literal
        # app.py, is the source of truth for "what the app actually
        # uses" today.
        Sid         = "DenyGetPutOutsideAppPrefix"
        Effect      = "Deny"
        Action      = ["s3:GetObject", "s3:PutObject"]
        NotResource = ["${local.app_bucket_arn}/${var.app_object_prefix}/*"]
      }
    ]
  })
}

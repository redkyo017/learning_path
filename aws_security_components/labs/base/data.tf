# ---------------------------------------------------------------------------
# Data tier: KMS CMK, S3 "app data" bucket, DynamoDB stand-in for the DB
# tier, and a value-less Secrets Manager secret.
#
# COST/DESIGN DECISION — DB TIER:
# A small RDS instance (db.t4g.micro) is billed per-hour (~$0.016/hr) plus
# gp3 storage, and takes 5-10 minutes to create/destroy — expensive in
# LEARNER TIME across 12 daily up/down cycles even though the dollar cost is
# small. DynamoDB in PAY_PER_REQUEST mode has no idle/hourly charge, no
# storage minimum, and is ready in seconds, while still using a
# customer-managed KMS key for encryption-at-rest — the actual teaching
# point (SSE-KMS, key policy, grants) transfers directly to RDS if a later
# day wants to swap it in. That is the cheapest option that still teaches
# encryption-at-rest, so it is the default here. `db_endpoint` documents
# this stand-in explicitly (see outputs.tf).
# ---------------------------------------------------------------------------

resource "aws_kms_key" "app_data" {
  description             = "${local.name_prefix} CMK for S3 app-data bucket + DynamoDB table encryption-at-rest"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = merge(local.common_tags, { Name = "${local.name_prefix}-app-data-key" })
}

resource "aws_kms_alias" "app_data" {
  name          = "alias/${local.name_prefix}-app-data"
  target_key_id = aws_kms_key.app_data.key_id
}

# --- S3 "app data" bucket ---------------------------------------------------

resource "aws_s3_bucket" "app_data" {
  bucket = "${local.name_prefix}-appdata-${data.aws_caller_identity.current.account_id}"
  tags   = merge(local.common_tags, { Name = "${local.name_prefix}-appdata" })
}

resource "aws_s3_bucket_public_access_block" "app_data" {
  bucket                  = aws_s3_bucket.app_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_data" {
  bucket = aws_s3_bucket.app_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.app_data.arn
    }
    bucket_key_enabled = true
  }
}

# --- DynamoDB stand-in for the DB tier --------------------------------------

resource "aws_dynamodb_table" "app_data" {
  name         = "${local.name_prefix}-appdata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.app_data.arn
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-appdata-table" })
}

# --- Secrets Manager — resource only, NO value in Terraform ----------------
# The value is set out-of-band after apply:
#   aws secretsmanager put-secret-value \
#     --secret-id <secret_arn output> \
#     --secret-string '<your-placeholder-value>'
# See README "Set the secret value".

resource "aws_secretsmanager_secret" "app_secret" {
  name                    = "${local.name_prefix}/app-secret"
  description             = "Placeholder app secret — value set out-of-band, never in Terraform."
  recovery_window_in_days = var.secret_recovery_window_days
  tags                    = local.common_tags
}

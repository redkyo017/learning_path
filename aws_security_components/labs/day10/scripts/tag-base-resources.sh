#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Applies the Day 10 ABAC tag scheme (Project, Environment,
# DataClassification) onto labs/base resources, WITHOUT editing labs/base
# itself — this is invoked by main.tf's null_resource.apply_abac_tags via
# local-exec, using ARNs/names read from base's remote state.
#
# IAM / Secrets Manager / DynamoDB TagResource-style calls are ADDITIVE —
# they add/update the keys given and leave any other existing tag alone.
# S3's PutBucketTagging call is AUTHORITATIVE (full replace) — this script
# reads the bucket's current tags first and merges, specifically so it does
# NOT wipe out labs/base's own Project/ManagedBy/Layer tags (applied by
# base's common_tags). See content/day10-governance-multiaccount.md,
# "Anti-patterns today", for why this merge step is not optional.
#
# Requires: AWS CLI v2, python3 (stdlib only — no extra pip install), and
# credentials with iam:TagRole, secretsmanager:TagResource,
# dynamodb:TagResource, s3:GetBucketTagging, s3:PutBucketTagging.
#
# Usage:
#   tag-base-resources.sh <role_name> <bucket_name> <secret_arn> \
#                          <dynamodb_table_arn> <project> <environment> \
#                          <classification>
# ---------------------------------------------------------------------------
set -euo pipefail

ROLE_NAME="$1"
BUCKET="$2"
SECRET_ARN="$3"
TABLE_ARN="$4"
PROJECT="$5"
ENVIRONMENT="$6"
CLASSIFICATION="$7"

echo "[day10] Tagging IAM role: ${ROLE_NAME}"
aws iam tag-role --role-name "${ROLE_NAME}" --tags \
  "Key=Project,Value=${PROJECT}" \
  "Key=Environment,Value=${ENVIRONMENT}" \
  "Key=DataClassification,Value=${CLASSIFICATION}"

echo "[day10] Tagging Secrets Manager secret: ${SECRET_ARN}"
aws secretsmanager tag-resource --secret-id "${SECRET_ARN}" --tags \
  "Key=Project,Value=${PROJECT}" \
  "Key=Environment,Value=${ENVIRONMENT}" \
  "Key=DataClassification,Value=${CLASSIFICATION}"

echo "[day10] Tagging DynamoDB table: ${TABLE_ARN}"
aws dynamodb tag-resource --resource-arn "${TABLE_ARN}" --tags \
  "Key=Project,Value=${PROJECT}" \
  "Key=Environment,Value=${ENVIRONMENT}" \
  "Key=DataClassification,Value=${CLASSIFICATION}"

echo "[day10] Tagging S3 bucket (merge-safe, read-before-write): ${BUCKET}"
EXISTING_JSON=$(aws s3api get-bucket-tagging --bucket "${BUCKET}" \
  --query 'TagSet' --output json 2>/dev/null || echo '[]')

MERGED_JSON=$(PROJECT="${PROJECT}" ENVIRONMENT="${ENVIRONMENT}" \
  CLASSIFICATION="${CLASSIFICATION}" EXISTING_JSON="${EXISTING_JSON}" \
  python3 <<'PYEOF'
import json
import os

existing = json.loads(os.environ["EXISTING_JSON"])
merged = {tag["Key"]: tag["Value"] for tag in existing}
merged.update(
    {
        "Project": os.environ["PROJECT"],
        "Environment": os.environ["ENVIRONMENT"],
        "DataClassification": os.environ["CLASSIFICATION"],
    }
)
print(json.dumps([{"Key": k, "Value": v} for k, v in merged.items()]))
PYEOF
)

aws s3api put-bucket-tagging --bucket "${BUCKET}" \
  --tagging "{\"TagSet\": ${MERGED_JSON}}"

echo "[day10] Done. Verify with: aws s3api get-bucket-tagging --bucket ${BUCKET}"

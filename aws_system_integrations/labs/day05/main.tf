###############################################################################
# Day 5 Lab — Inbound Webhook Receiver with Idempotency
#
# Scenario: Stripe-style payment webhook receiver.
#   External provider POSTs signed payload to API GW.
#   Validator Lambda: checks HMAC-SHA256 (secret from Secrets Manager) +
#     DynamoDB conditional idempotency write + SQS enqueue.
#   Consumer Lambda: SQS event source mapping, logs event, marks completed.
#
# NEVER run terraform apply against a production account.
# NEVER commit real credentials to version control.
# Signing secret is a placeholder — update it via Secrets Manager after apply.
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  # Credentials: set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY env vars,
  # or use AWS SSO (`aws sso login`). Never hardcode here.
}

###############################################################################
# DATA SOURCES
###############################################################################

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

###############################################################################
# LOCALS
###############################################################################

locals {
  prefix = "webhook-${var.environment}"
}

###############################################################################
# SECRETS MANAGER
# Stores the HMAC-SHA256 signing secret shared with the external provider.
# Value is a placeholder — update via Console or CLI after terraform apply.
# NEVER put the real secret in terraform.tfvars or main.tf.
###############################################################################

resource "aws_secretsmanager_secret" "webhook_signing_secret" {
  name                    = "webhook-signing-secret-${var.environment}"
  description             = "HMAC-SHA256 signing secret for webhook signature validation (Day 5 lab)"
  recovery_window_in_days = 0 # Immediate deletion — lab only, not production

  tags = {
    Environment = var.environment
    Lab         = "day05"
  }
}

resource "aws_secretsmanager_secret_version" "webhook_signing_secret_placeholder" {
  secret_id     = aws_secretsmanager_secret.webhook_signing_secret.id
  secret_string = "REPLACE_BEFORE_RUNNING_DO_NOT_USE_AS_IS"
  # After terraform apply, update with:
  #   aws secretsmanager put-secret-value \
  #     --secret-id webhook-signing-secret-<environment> \
  #     --secret-string "your-real-signing-secret"
}

###############################################################################
# DYNAMODB — IDEMPOTENCY STORE
# Partition key: event_id (the unique ID from the provider payload, e.g. Stripe
# event ID). TTL attribute: expires_at (Unix timestamp, set to now + 86400).
###############################################################################

resource "aws_dynamodb_table" "idempotency" {
  name         = "webhook_idempotency_${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "event_id"

  attribute {
    name = "event_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Environment = var.environment
    Lab         = "day05"
  }
}

###############################################################################
# SQS — WEBHOOK QUEUE + DLQ
# Consumer Lambda reads from webhook-queue.
# Messages that fail maxReceiveCount=3 times land in the DLQ.
###############################################################################

resource "aws_sqs_queue" "webhook_dlq" {
  name                       = "${local.prefix}-dlq"
  message_retention_seconds  = 1209600 # 14 days — inspect failed messages

  tags = {
    Environment = var.environment
    Lab         = "day05"
  }
}

resource "aws_sqs_queue" "webhook_queue" {
  name                       = "${local.prefix}-queue"
  message_retention_seconds  = 86400 # 1 day — lab only
  visibility_timeout_seconds = 30    # Must be >= Consumer Lambda timeout

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.webhook_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Environment = var.environment
    Lab         = "day05"
  }
}

###############################################################################
# IAM — VALIDATOR LAMBDA ROLE
# Permissions: SecretsManager:GetSecretValue, DynamoDB:PutItem + UpdateItem,
#              SQS:SendMessage, CloudWatch Logs basic execution.
###############################################################################

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "validator_lambda" {
  name               = "${local.prefix}-validator-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Environment = var.environment
    Lab         = "day05"
  }
}

data "aws_iam_policy_document" "validator_permissions" {
  statement {
    sid     = "SecretsManagerRead"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.webhook_signing_secret.arn
    ]
  }

  statement {
    sid    = "DynamoDBIdempotency"
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:GetItem"
    ]
    resources = [
      aws_dynamodb_table.idempotency.arn
    ]
  }

  statement {
    sid     = "SQSSendMessage"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]
    resources = [
      aws_sqs_queue.webhook_queue.arn
    ]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
  }
}

resource "aws_iam_role_policy" "validator_permissions" {
  name   = "${local.prefix}-validator-policy"
  role   = aws_iam_role.validator_lambda.id
  policy = data.aws_iam_policy_document.validator_permissions.json
}

###############################################################################
# IAM — CONSUMER LAMBDA ROLE
# Permissions: SQS:ReceiveMessage + DeleteMessage + GetQueueAttributes,
#              DynamoDB:UpdateItem, CloudWatch Logs.
###############################################################################

resource "aws_iam_role" "consumer_lambda" {
  name               = "${local.prefix}-consumer-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Environment = var.environment
    Lab         = "day05"
  }
}

data "aws_iam_policy_document" "consumer_permissions" {
  statement {
    sid    = "SQSRead"
    effect = "Allow"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes"
    ]
    resources = [
      aws_sqs_queue.webhook_queue.arn
    ]
  }

  statement {
    sid     = "DynamoDBUpdateStatus"
    effect  = "Allow"
    actions = ["dynamodb:UpdateItem"]
    resources = [
      aws_dynamodb_table.idempotency.arn
    ]
  }

  statement {
    sid    = "CloudWatchLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"]
  }
}

resource "aws_iam_role_policy" "consumer_permissions" {
  name   = "${local.prefix}-consumer-policy"
  role   = aws_iam_role.consumer_lambda.id
  policy = data.aws_iam_policy_document.consumer_permissions.json
}

###############################################################################
# VALIDATOR LAMBDA
# Inline Python: HMAC-SHA256 validation + DynamoDB idempotency + SQS enqueue.
# In production, package this as a deployment zip. Inline is used here for
# lab readability — no external dependencies, no build step required.
###############################################################################

resource "aws_lambda_function" "validator" {
  function_name = "webhook-validator-${var.environment}"
  role          = aws_iam_role.validator_lambda.arn
  runtime       = "python3.12"
  handler       = "index.handler"
  timeout       = 10 # Seconds — short because we only validate + enqueue

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.idempotency.name
      SQS_QUEUE_URL       = aws_sqs_queue.webhook_queue.url
      SECRET_NAME         = aws_secretsmanager_secret.webhook_signing_secret.name
      AWS_REGION_NAME     = var.aws_region
    }
  }

  # Inline Lambda code via filename from archive_file data source.
  # Using a local_file + archive_file approach for inline code without a zip.
  filename         = data.archive_file.validator_code.output_path
  source_code_hash = data.archive_file.validator_code.output_base64sha256

  tags = {
    Environment = var.environment
    Lab         = "day05"
  }

  depends_on = [
    aws_iam_role_policy.validator_permissions
  ]
}

# Write the validator Python source to a temp file then zip it.
resource "local_file" "validator_source" {
  filename = "${path.module}/.lambda_build/validator/index.py"
  content  = <<-PYTHON
import json
import hmac
import hashlib
import time
import os
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.client("dynamodb")
sqs      = boto3.client("sqs")
sm       = boto3.client("secretsmanager")

# Cache signing secret for the Lambda lifetime (avoids Secrets Manager call
# on every invocation after the first warm execution).
_signing_secret = None

def get_signing_secret():
    global _signing_secret
    if _signing_secret is None:
        response = sm.get_secret_value(SecretId=os.environ["SECRET_NAME"])
        _signing_secret = response["SecretString"]
    return _signing_secret

def handler(event, context):
    # API GW HTTP API proxy integration: raw body in event["body"]
    raw_body  = event.get("body", "")
    headers   = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    signature_header = headers.get("x-webhook-signature", "")

    # 1. Validate HMAC-SHA256 signature
    secret = get_signing_secret()
    expected_hmac = hmac.new(
        secret.encode("utf-8"),
        raw_body.encode("utf-8"),
        hashlib.sha256
    ).hexdigest()
    # Header format: "sha256=<hex_digest>"
    received_hmac = signature_header.removeprefix("sha256=")

    if not hmac.compare_digest(expected_hmac, received_hmac):
        # DO NOT log the received signature — could leak partial secret info
        print("Signature validation failed")
        return {"statusCode": 403, "body": json.dumps({"error": "invalid signature"})}

    # 2. Parse payload
    try:
        payload = json.loads(raw_body)
    except json.JSONDecodeError:
        return {"statusCode": 400, "body": json.dumps({"error": "invalid JSON"})}

    event_id = payload.get("id")
    if not event_id:
        return {"statusCode": 400, "body": json.dumps({"error": "missing event id"})}

    # 3. DynamoDB conditional idempotency write
    expires_at = int(time.time()) + 86400  # 24 hours TTL
    try:
        dynamodb.put_item(
            TableName=os.environ["DYNAMODB_TABLE_NAME"],
            Item={
                "event_id":   {"S": event_id},
                "status":     {"S": "processing"},
                "expires_at": {"N": str(expires_at)},
                "event_type": {"S": payload.get("type", "unknown")}
            },
            ConditionExpression="attribute_not_exists(event_id)"
        )
    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            # Duplicate event — idempotent acknowledge
            print(f"Duplicate event detected: {event_id} — returning 200 (no-op)")
            return {"statusCode": 200, "body": json.dumps({"message": "duplicate, already accepted"})}
        raise  # Unexpected DynamoDB error — surface to Lambda runtime

    # 4. Enqueue to SQS for async processing
    sqs.send_message(
        QueueUrl=os.environ["SQS_QUEUE_URL"],
        MessageBody=raw_body,
        MessageAttributes={
            "EventId": {"DataType": "String", "StringValue": event_id}
        }
    )

    print(f"Accepted new event: {event_id}")
    return {"statusCode": 200, "body": json.dumps({"message": "accepted"})}
  PYTHON
}

data "archive_file" "validator_code" {
  type        = "zip"
  source_file = local_file.validator_source.filename
  output_path = "${path.module}/.lambda_build/validator.zip"
}

###############################################################################
# CONSUMER LAMBDA
# Inline Python: reads from SQS event source, logs event, updates DynamoDB.
###############################################################################

resource "local_file" "consumer_source" {
  filename = "${path.module}/.lambda_build/consumer/index.py"
  content  = <<-PYTHON
import json
import os
import boto3

dynamodb = boto3.client("dynamodb")

def handler(event, context):
    for record in event.get("Records", []):
        body = record.get("body", "{}")
        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            print(f"Could not parse record body: {body[:200]}")
            continue

        event_id   = payload.get("id", "UNKNOWN")
        event_type = payload.get("type", "UNKNOWN")

        print(f"Processing event: id={event_id} type={event_type}")

        # Update DynamoDB status to "completed"
        dynamodb.update_item(
            TableName=os.environ["DYNAMODB_TABLE_NAME"],
            Key={"event_id": {"S": event_id}},
            UpdateExpression="SET #s = :completed",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":completed": {"S": "completed"}}
        )

        print(f"Marked completed: {event_id}")

    return {"statusCode": 200}
  PYTHON
}

data "archive_file" "consumer_code" {
  type        = "zip"
  source_file = local_file.consumer_source.filename
  output_path = "${path.module}/.lambda_build/consumer.zip"
}

resource "aws_lambda_function" "consumer" {
  function_name = "webhook-consumer-${var.environment}"
  role          = aws_iam_role.consumer_lambda.arn
  runtime       = "python3.12"
  handler       = "index.handler"
  timeout       = 25 # Must be < SQS visibility_timeout_seconds (30)

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.idempotency.name
    }
  }

  filename         = data.archive_file.consumer_code.output_path
  source_code_hash = data.archive_file.consumer_code.output_base64sha256

  tags = {
    Environment = var.environment
    Lab         = "day05"
  }

  depends_on = [
    aws_iam_role_policy.consumer_permissions
  ]
}

# SQS event source mapping — Consumer Lambda reads from webhook-queue
resource "aws_lambda_event_source_mapping" "sqs_to_consumer" {
  event_source_arn = aws_sqs_queue.webhook_queue.arn
  function_name    = aws_lambda_function.consumer.arn
  batch_size       = 1 # Process one webhook at a time for simplicity in this lab
  enabled          = true
}

###############################################################################
# API GATEWAY HTTP API
# Single route: POST /webhook
# Lambda proxy integration to Validator Lambda.
###############################################################################

resource "aws_apigatewayv2_api" "webhook_api" {
  name          = "${local.prefix}-api"
  protocol_type = "HTTP"
  description   = "Day 5 lab: inbound webhook receiver"

  tags = {
    Environment = var.environment
    Lab         = "day05"
  }
}

resource "aws_apigatewayv2_integration" "validator_integration" {
  api_id                 = aws_apigatewayv2_api.webhook_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.validator.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "webhook_route" {
  api_id    = aws_apigatewayv2_api.webhook_api.id
  route_key = "POST /webhook"
  target    = "integrations/${aws_apigatewayv2_integration.validator_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.webhook_api.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Environment = var.environment
    Lab         = "day05"
  }
}

# Allow API GW to invoke the Validator Lambda
resource "aws_lambda_permission" "api_gw_invoke_validator" {
  statement_id  = "AllowAPIGWInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.validator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.webhook_api.execution_arn}/*/*"
}

###############################################################################
# OUTPUTS
###############################################################################

output "api_gateway_url" {
  description = "Webhook endpoint URL — POST to this URL with a signed payload"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/webhook"
}

output "secrets_manager_secret_name" {
  description = "Secrets Manager secret name — update with your real signing secret before testing"
  value       = aws_secretsmanager_secret.webhook_signing_secret.name
}

output "dynamodb_table_name" {
  description = "DynamoDB idempotency table name"
  value       = aws_dynamodb_table.idempotency.name
}

output "sqs_queue_url" {
  description = "SQS webhook queue URL"
  value       = aws_sqs_queue.webhook_queue.url
}

output "validator_lambda_name" {
  description = "Validator Lambda function name"
  value       = aws_lambda_function.validator.function_name
}

output "consumer_lambda_name" {
  description = "Consumer Lambda function name"
  value       = aws_lambda_function.consumer.function_name
}

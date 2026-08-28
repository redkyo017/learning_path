terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Lambda source code — written to scratchpad files, then zipped by archive_file
# ---------------------------------------------------------------------------

resource "local_file" "account_mock_src" {
  filename = "${path.module}/.lambda_src/account_mock.py"
  content  = <<-PYTHON
    import json

    def handler(event, context):
        return {
            "statusCode": 200,
            "body": json.dumps({
                "balance": 12450.00,
                "currency": "USD",
                "account_id": "acc-001"
            })
        }
  PYTHON
}

resource "local_file" "transaction_mock_src" {
  filename = "${path.module}/.lambda_src/transaction_mock.py"
  content  = <<-PYTHON
    import json

    def handler(event, context):
        transactions = [
            {"id": "tx001", "amount": -45.00,   "description": "Coffee shop"},
            {"id": "tx002", "amount": -120.00,  "description": "Electricity bill"},
            {"id": "tx003", "amount": 5000.00,  "description": "Salary deposit"},
            {"id": "tx004", "amount": -380.00,  "description": "Grocery store"},
            {"id": "tx005", "amount": -15.00,   "description": "Streaming service"},
        ]
        return {
            "statusCode": 200,
            "body": json.dumps({"transactions": transactions})
        }
  PYTHON
}

resource "local_file" "bff_aggregator_src" {
  filename = "${path.module}/.lambda_src/bff_aggregator.py"
  content  = <<-PYTHON
    import json
    import os
    import boto3
    from concurrent.futures import ThreadPoolExecutor, as_completed

    ACCOUNT_FUNCTION   = os.environ["ACCOUNT_FUNCTION_NAME"]
    TRANSACTION_FUNCTION = os.environ["TRANSACTION_FUNCTION_NAME"]
    UPSTREAM_TIMEOUT_S = int(os.environ.get("UPSTREAM_TIMEOUT_S", "5"))

    client = boto3.client("lambda")

    def invoke(fn_name):
        """Invoke a Lambda function synchronously and return parsed body."""
        resp = client.invoke(
            FunctionName=fn_name,
            InvocationType="RequestResponse",
        )
        payload = json.loads(resp["Payload"].read())
        return json.loads(payload.get("body", "{}"))

    def handler(event, context):
        results = {}
        errors  = {}

        with ThreadPoolExecutor(max_workers=2) as pool:
            futures = {
                pool.submit(invoke, ACCOUNT_FUNCTION):     "account",
                pool.submit(invoke, TRANSACTION_FUNCTION): "transactions",
            }
            for future in as_completed(futures, timeout=UPSTREAM_TIMEOUT_S):
                key = futures[future]
                try:
                    results[key] = future.result()
                except Exception as exc:
                    errors[key] = str(exc)

        merged = {}
        if "account" in results:
            merged["balance"]  = results["account"].get("balance")
            merged["currency"] = results["account"].get("currency")
        if "transactions" in results:
            merged["transactions"] = results["transactions"].get("transactions", [])

        if errors:
            merged["_errors"] = errors

        return {
            "statusCode": 200 if not errors else 207,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps(merged),
        }
  PYTHON
}

resource "local_file" "jwt_authorizer_src" {
  filename = "${path.module}/.lambda_src/jwt_authorizer.py"
  content  = <<-PYTHON
    import json

    def handler(event, context):
        """
        Simple Lambda authorizer for lab purposes.
        Accepts any non-empty Bearer token.
        In production, verify the JWT signature against a JWKS endpoint.
        """
        sources = event.get("identitySource") or [""]
        # identitySource under payload_format_version 2.0 is a list
        token = sources[0].replace("Bearer ", "").strip()

        # Resolve the resource ARN before deciding allow/deny
        method_arn = event.get("routeArn", event.get("methodArn", "*"))
        # Generalise to all routes in this API so a single decision covers the stage
        arn_parts  = method_arn.split(":")
        arn_prefix = ":".join(arn_parts[:6])
        stage_arn  = arn_prefix + ":*"

        if not token:
            # Return an explicit Deny — API GW responds 403.
            # Raising an exception here would surface as a 500 to the client.
            return {
                "principalId": "anonymous",
                "policyDocument": {
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Action": "execute-api:Invoke",
                            "Effect": "Deny",
                            "Resource": stage_arn,
                        }
                    ],
                },
            }

        policy = {
            "principalId": "mobile-user",
            "policyDocument": {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Action": "execute-api:Invoke",
                        "Effect": "Allow",
                        "Resource": stage_arn,
                    }
                ],
            },
            "context": {
                "userId": "demo-user-001",
            },
        }
        return policy
  PYTHON
}

# ---------------------------------------------------------------------------
# Archive zip files for each Lambda
# ---------------------------------------------------------------------------

data "archive_file" "account_mock_zip" {
  type        = "zip"
  source_file = local_file.account_mock_src.filename
  output_path = "${path.module}/.lambda_zip/account_mock.zip"
  depends_on  = [local_file.account_mock_src]
}

data "archive_file" "transaction_mock_zip" {
  type        = "zip"
  source_file = local_file.transaction_mock_src.filename
  output_path = "${path.module}/.lambda_zip/transaction_mock.zip"
  depends_on  = [local_file.transaction_mock_src]
}

data "archive_file" "bff_aggregator_zip" {
  type        = "zip"
  source_file = local_file.bff_aggregator_src.filename
  output_path = "${path.module}/.lambda_zip/bff_aggregator.zip"
  depends_on  = [local_file.bff_aggregator_src]
}

data "archive_file" "jwt_authorizer_zip" {
  type        = "zip"
  source_file = local_file.jwt_authorizer_src.filename
  output_path = "${path.module}/.lambda_zip/jwt_authorizer.zip"
  depends_on  = [local_file.jwt_authorizer_src]
}

# ---------------------------------------------------------------------------
# IAM — shared Lambda execution role
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${var.environment}-lambda-exec-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

# Basic CloudWatch Logs permissions
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow BFF aggregator to invoke the mock Lambdas
data "aws_iam_policy_document" "bff_invoke" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [
      aws_lambda_function.account_mock.arn,
      aws_lambda_function.transaction_mock.arn,
    ]
  }
}

resource "aws_iam_policy" "bff_invoke" {
  name   = "${var.environment}-bff-invoke-policy"
  policy = data.aws_iam_policy_document.bff_invoke.json
}

resource "aws_iam_role_policy_attachment" "bff_invoke" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.bff_invoke.arn
}

# ---------------------------------------------------------------------------
# Mock account service Lambda
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "account_mock" {
  function_name    = "${var.environment}-account-mock"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "account_mock.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.account_mock_zip.output_path
  source_code_hash = data.archive_file.account_mock_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }
}

resource "aws_cloudwatch_log_group" "account_mock" {
  name              = "/aws/lambda/${aws_lambda_function.account_mock.function_name}"
  retention_in_days = 3
}

# ---------------------------------------------------------------------------
# Mock transaction service Lambda
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "transaction_mock" {
  function_name    = "${var.environment}-transaction-mock"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "transaction_mock.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.transaction_mock_zip.output_path
  source_code_hash = data.archive_file.transaction_mock_zip.output_base64sha256
  timeout          = 10
  memory_size      = 128

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }
}

resource "aws_cloudwatch_log_group" "transaction_mock" {
  name              = "/aws/lambda/${aws_lambda_function.transaction_mock.function_name}"
  retention_in_days = 3
}

# ---------------------------------------------------------------------------
# BFF aggregator Lambda
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "bff_aggregator" {
  function_name    = "${var.environment}-bff-aggregator"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "bff_aggregator.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.bff_aggregator_zip.output_path
  source_code_hash = data.archive_file.bff_aggregator_zip.output_base64sha256
  timeout          = 15  # BFF timeout < API GW integration timeout (29s)
  memory_size      = 256  # Higher memory for concurrent upstream calls

  environment {
    variables = {
      ACCOUNT_FUNCTION_NAME     = aws_lambda_function.account_mock.function_name
      TRANSACTION_FUNCTION_NAME = aws_lambda_function.transaction_mock.function_name
      UPSTREAM_TIMEOUT_S        = "5"
      ENVIRONMENT               = var.environment
    }
  }
}

resource "aws_cloudwatch_log_group" "bff_aggregator" {
  name              = "/aws/lambda/${aws_lambda_function.bff_aggregator.function_name}"
  retention_in_days = 3
}

# ---------------------------------------------------------------------------
# JWT authorizer Lambda
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "jwt_authorizer" {
  function_name    = "${var.environment}-jwt-authorizer"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "jwt_authorizer.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.jwt_authorizer_zip.output_path
  source_code_hash = data.archive_file.jwt_authorizer_zip.output_base64sha256
  timeout          = 5
  memory_size      = 128

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }
}

resource "aws_cloudwatch_log_group" "jwt_authorizer" {
  name              = "/aws/lambda/${aws_lambda_function.jwt_authorizer.function_name}"
  retention_in_days = 3
}

# ---------------------------------------------------------------------------
# HTTP API Gateway
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_api" "banking_bff" {
  name          = "${var.environment}-banking-bff"
  protocol_type = "HTTP"
  description   = "Day 01 lab — Mobile banking BFF"

  cors_configuration {
    allow_headers = ["Authorization", "Content-Type"]
    allow_methods = ["GET", "OPTIONS"]
    allow_origins = ["*"]  # Restrict to your domain in production
  }
}

# Lambda permission — allow API GW to invoke the BFF aggregator
resource "aws_lambda_permission" "apigw_bff" {
  statement_id  = "AllowAPIGWInvokeBFF"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.bff_aggregator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.banking_bff.execution_arn}/*/*"
}

# Lambda permission — allow API GW to invoke the authorizer
resource "aws_lambda_permission" "apigw_authorizer" {
  statement_id  = "AllowAPIGWInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jwt_authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.banking_bff.execution_arn}/*/*"
}

# ---------------------------------------------------------------------------
# Lambda authorizer attached to API
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id                            = aws_apigatewayv2_api.banking_bff.id
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = aws_lambda_function.jwt_authorizer.invoke_arn
  identity_sources                  = ["$request.header.Authorization"]
  name                              = "${var.environment}-jwt-authorizer"
  authorizer_payload_format_version = "2.0"

  # Cache the authorizer result for 60s — reduces re-auth Lambda calls
  # Set to 0 to disable caching (useful for testing, costly in production)
  authorizer_result_ttl_in_seconds  = 60

  enable_simple_responses = false
}

# ---------------------------------------------------------------------------
# BFF Lambda integration
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_integration" "bff_summary" {
  api_id                 = aws_apigatewayv2_api.banking_bff.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.bff_aggregator.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"

  # API GW will return 504 if the BFF Lambda does not respond within this window
  timeout_milliseconds   = 20000  # 20s — below the 29s API GW maximum
}

# ---------------------------------------------------------------------------
# Route: GET /summary → JWT authorizer → BFF Lambda
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_route" "summary" {
  api_id             = aws_apigatewayv2_api.banking_bff.id
  route_key          = "GET /summary"
  target             = "integrations/${aws_apigatewayv2_integration.bff_summary.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

# ---------------------------------------------------------------------------
# Default stage — with throttling (simulates usage plan for HTTP API)
# ---------------------------------------------------------------------------

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.banking_bff.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 10   # requests per second
    throttling_burst_limit = 20   # token bucket burst
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format = jsonencode({
      requestId       = "$context.requestId"
      httpMethod      = "$context.httpMethod"
      routeKey        = "$context.routeKey"
      status          = "$context.status"
      responseLatency = "$context.responseLatency"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigateway/${var.environment}-banking-bff"
  retention_in_days = 3
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "api_endpoint" {
  description = "Base URL for the banking BFF API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "summary_url" {
  description = "Full URL for the /summary endpoint"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}/summary"
}

output "bff_lambda_name" {
  description = "BFF aggregator Lambda function name"
  value       = aws_lambda_function.bff_aggregator.function_name
}

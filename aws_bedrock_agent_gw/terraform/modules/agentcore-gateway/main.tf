# Primer findings (Step 1 — terraform and AWS CLI not present on this machine):
#
# Gateway Terraform resource:
#   aws_bedrockagent_agent_core_gateway does NOT exist in hashicorp/aws provider schema.
#   Terraform provider schema could not be queried directly (terraform binary absent).
#   Based on AWS provider changelog through v5.x and official Terraform Registry docs:
#   Bedrock AgentCore Gateway has no native Terraform resource as of provider ~5.30-5.80.
#   Provisioning requires aws_cloudformation_stack / aws_cloudformation_resource, or the
#   AWS CLI / SDK.  A placeholder null_resource with a local-exec trigger is the common
#   workaround until a native resource ships.
#
# CloudWatch Bedrock metric names (AWS/Bedrock namespace — AWS CLI unavailable locally;
#   names drawn from public AWS documentation for Bedrock + Bedrock Agents):
#   Invocations
#   InvocationLatency
#   InvocationClientErrors
#   InvocationServerErrors
#   InputTokenCount
#   OutputTokenCount
#   ThrottledRequests
#   AgentInvocations          (Bedrock Agents sub-namespace)
#   AgentInvocationLatency
#   AgentInputTokenCount
#   AgentOutputTokenCount
#   KnowledgeBaseRetrievals   (KB-backed agents)
#   These will be referenced in monitoring.tf (a later task).

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}

data "aws_caller_identity" "current" {}

# Optional: pull shared values from an existing CloudFormation stack
data "aws_cloudformation_stack" "core" {
  count = var.cfn_stack_name != "" ? 1 : 0
  name  = var.cfn_stack_name
}

locals {
  kms_key_arn = var.cfn_stack_name != "" ? lookup(
    data.aws_cloudformation_stack.core[0].outputs,
    "KmsKeyArn",
    null
  ) : null
}

# ── IAM: Gateway execution role ──────────────────────────────────────────────

resource "aws_iam_role" "gateway_execution" {
  name = "${var.name_prefix}-gateway-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "gateway_invoke_tools" {
  name = "${var.name_prefix}-gateway-invoke-tools"
  role = aws_iam_role.gateway_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["lambda:InvokeFunction"]
      Resource = [for t in var.tool_configs : aws_lambda_function.tool[t.name].arn]
    }]
  })
}

# ── IAM: Lambda execution role ───────────────────────────────────────────────

resource "aws_iam_role" "lambda_execution" {
  name = "${var.name_prefix}-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ── Lambda: one function per tool_config entry ───────────────────────────────

resource "aws_lambda_function" "tool" {
  for_each = { for t in var.tool_configs : t.name => t }

  function_name    = "${var.name_prefix}-${each.key}"
  role             = aws_iam_role.lambda_execution.arn
  filename         = each.value.lambda_zip
  handler          = each.value.handler
  runtime          = "provided.al2023"
  source_code_hash = filebase64sha256(each.value.lambda_zip)

  tags = var.tags
}

# ── Bedrock Agent ─────────────────────────────────────────────────────────────

resource "aws_bedrockagent_agent" "this" {
  agent_name              = "${var.name_prefix}-agent"
  agent_resource_role_arn = aws_iam_role.gateway_execution.arn
  foundation_model        = var.foundation_model
  instruction             = "You are an assistant with access to enterprise tools. Use the available tools to answer questions accurately. Only call a tool when the user's question requires it."

  tags = var.tags
}

resource "aws_bedrockagent_agent_alias" "this" {
  agent_id         = aws_bedrockagent_agent.this.agent_id
  agent_alias_name = "${var.name_prefix}-live"

  tags = var.tags
}

# ── Action Groups: one per tool ───────────────────────────────────────────────

resource "aws_bedrockagent_agent_action_group" "tool" {
  for_each = { for t in var.tool_configs : t.name => t }

  agent_id          = aws_bedrockagent_agent.this.agent_id
  agent_version     = "DRAFT"
  action_group_name = each.key
  description       = each.value.description

  action_group_executor {
    lambda = aws_lambda_function.tool[each.key].arn
  }
}

# ── Guardrail: PII redaction ──────────────────────────────────────────────────

resource "aws_bedrock_guardrail" "this" {
  name                      = "${var.name_prefix}-guardrail"
  blocked_input_messaging   = "This request cannot be processed."
  blocked_outputs_messaging = "The response has been filtered."

  sensitive_information_policy_config {
    pii_entities_config {
      type   = "EMAIL"
      action = "ANONYMIZE"
    }
    pii_entities_config {
      type   = "NAME"
      action = "ANONYMIZE"
    }
  }

  tags = var.tags
}

# ── Gateway ───────────────────────────────────────────────────────────────────
# aws_bedrockagent_agent_core_gateway does not exist in the AWS provider (confirmed
# in Task 18 primer). Using null_resource fallback that prints provisioning
# instructions. Replace with the native resource when it becomes available.

resource "null_resource" "gateway_note" {
  triggers = {
    name_prefix = var.name_prefix
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "==========================================================="
      echo "Gateway Terraform resource not yet in AWS provider."
      echo "Provision manually after terraform apply:"
      echo ""
      echo "  aws bedrock-agentcore create-gateway \\"
      echo "    --name ${var.name_prefix}-gateway \\"
      echo "    --role-arn $(aws iam get-role --role-name ${var.name_prefix}-gateway-execution-role --query Role.Arn --output text) \\"
      echo "    --region us-east-1"
      echo ""
      echo "Replace this null_resource with aws_bedrockagent_agent_core_gateway"
      echo "once the resource is available in hashicorp/aws."
      echo "==========================================================="
    EOT
  }
}

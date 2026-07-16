# Day 5 — Platform Engineering for AgentCore

Read this before the Day 5 labs. Budget: 30 minutes.

---

## Console as Verification Tool

### The Rule

**Terraform provisions. Console verifies. Never the other way.**

When you provision resources in the AWS console directly, you create a state problem: the real infrastructure exists, but Terraform knows nothing about it. On the next `terraform apply`, Terraform sees a gap between its state file (which shows the resource missing) and reality (where it exists). The result is unpredictable—it may try to recreate, delete, or silently leave things broken. All of this bypasses code review, making it impossible to audit who changed what and why.

### Two Legitimate Console Purposes

1. **Verification** — After `terraform apply`, open the console to visually confirm that the created resource looks correct (correct subnets, correct role trust, correct Lambda runtime).
2. **Debugging** — Use X-Ray service maps to trace request paths, CloudWatch Logs Insights to search logs, or Bedrock Playground to test agent instructions in real time.

Never create or modify resources in the console as a workaround for Terraform.

### The 30-Second Verification Loop

After `terraform apply` completes:

1. Read terraform outputs — note `agent_id`, `dashboard_url`, `lambda_arn`.
2. IAM console → Roles → Search for `bgw-gateway-execution-role` → Confirm exists and trust policy shows `bedrock.amazonaws.com`.
3. Lambda console → Functions → Search for `bgw-hr-tool` → Confirm exists and Status is "Active".
4. Bedrock console → Agents → Search for agent name → Confirm Status is "PREPARED".
5. Open the `dashboard_url` output in a browser → Confirm CloudWatch dashboard widgets render (no "no data" or 404).

If any step fails, **the problem is in Terraform**. Do not fix it in the console. Instead:
- Roll back with `terraform plan` to see what changed.
- Fix the root cause in the `.tf` file.
- Run `terraform apply` again.

---

## Terraform for AgentCore

### AWS Provider Bedrock Resource Inventory

| Resource Type | Terraform | Purpose | Key Attributes |
|---|---|---|---|
| Bedrock Agent | `aws_bedrockagent_agent` | Creates a conversational agent with instructions and model binding | `agent_name`, `foundation_model`, `instruction`, `agent_role_arn` |
| Agent Alias | `aws_bedrockagent_agent_alias` | Named pointer to an agent version; enables blue-green deployments | `agent_id`, `agent_alias_name`, `agent_version` |
| Action Group | `aws_bedrockagent_agent_action_group` | Wires a Lambda function as a tool to an agent | `agent_id`, `action_group_name`, `lambda_arn`, `tool_definition` (JSON schema) |
| Guardrail | `aws_bedrock_guardrail` | Content filtering and PII redaction rules | `name`, `description`, `content_policy_config`, `pii_entities_config` |
| IAM Role | `aws_iam_role` | Execution role for agents and Lambda functions | `name`, `assume_role_policy` |
| Lambda Function | `aws_lambda_function` | Backing function for tool invocation | `filename` or `s3_*`, `function_name`, `role`, `handler`, `runtime` |
| CloudWatch Dashboard | `aws_cloudwatch_dashboard` | JSON dashboard visualizing metrics | `dashboard_name`, `dashboard_body` (JSON string) |
| CloudWatch Alarm | `aws_cloudwatch_metric_alarm` | Alert on metric breach (error rate, latency, cost) | `alarm_name`, `metric_name`, `threshold`, `comparison_operator`, `evaluation_periods` |

### Module Pattern and Minimal Interface

The module `aws_bedrockagent_module` accepts a small set of inputs and encapsulates all resource creation. Two gateways can use the same module:

```hcl
module "hr_gateway" {
  source = "./modules/aws_bedrockagent_module"
  
  name_prefix      = "bgw-hr"
  foundation_model = "anthropic.claude-3-sonnet-20240229-v1:0"
  instruction      = file("${path.module}/prompts/hr-agent.txt")
  tools_config     = [
    {
      name   = "get_employee"
      lambda = aws_lambda_function.get_employee_hr.arn
      schema = file("${path.module}/tools/get_employee.json")
    }
  ]
  tags = { team = "hr-platform" }
}

module "finance_gateway" {
  source = "./modules/aws_bedrockagent_module"
  
  name_prefix      = "bgw-finance"
  foundation_model = "anthropic.claude-3-sonnet-20240229-v1:0"
  instruction      = file("${path.module}/prompts/finance-agent.txt")
  tools_config     = [
    {
      name   = "get_budget"
      lambda = aws_lambda_function.get_budget_finance.arn
      schema = file("${path.module}/tools/get_budget.json")
    }
  ]
  tags = { team = "finance-platform" }
}
```

Both are isolated by `name_prefix`. All Lambda functions created for the HR gateway have `bgw-hr-*` in their names. IAM role permissions are scoped to resources matching that prefix, so the finance team cannot invoke HR Lambda functions.

### CloudFormation Integration Pattern

Many organizations run existing infrastructure via CloudFormation. The module integrates without forcing a full CFN rewrite:

```hcl
variable "cfn_stack_name" {
  type        = string
  description = "Optional CloudFormation stack to import KMS key and VPC"
  default     = ""
}

data "aws_cloudformation_stack" "core" {
  count = var.cfn_stack_name != "" ? 1 : 0
  name  = var.cfn_stack_name
}

locals {
  kms_key_arn = var.cfn_stack_name != "" ? data.aws_cloudformation_stack.core[0].outputs["KmsKeyArn"] : null
  subnet_ids  = var.cfn_stack_name != "" ? split(",", data.aws_cloudformation_stack.core[0].outputs["SubnetIds"]) : []
}
```

When `cfn_stack_name = ""` (the default), the module works standalone. When set to a real stack name, it pulls KMS key ARN, subnet IDs, and other shared resources from that stack. This allows Terraform and CloudFormation to coexist without conflicts.

### State Isolation with S3 Backend

Terraform state files are stored in S3 with a structure that bounds blast radius:

```
s3://company-tf-state-bucket/
  prod/
    core-networking/
      terraform.tfstate
    core-iam/
      terraform.tfstate
  ai-platform/
    day05-lab/
      terraform.tfstate
    hr-gateway-prod/
      terraform.tfstate
    finance-gateway-prod/
      terraform.tfstate
```

A `terraform destroy` run in `ai-platform/day05-lab/` reads and modifies only `day05-lab/terraform.tfstate`. It cannot touch `core-networking` or `hr-gateway-prod`. Each state file is independent, so failures are scoped.

---

## DevOps/SRE Operational Layer

### What to Measure

| Metric | CloudWatch Metric Name | Alert Threshold | Why It Matters |
|---|---|---|---|
| Error Rate | `InvocationClientErrors` + `InvocationServerErrors` | > 0 errors in 5 min | Any errors indicate agent or tool failure; must be investigated immediately |
| Latency (P99) | `InvocationLatency` (milliseconds) | > 10,000 ms | Users wait; latency > 10 sec is poor UX; indicates overload or cold starts |
| Cost | `EstimatedCharges` (Bedrock) | > monthly budget / 30 days | AI inference is expensive; runaway costs can deplete budget in hours |

### CloudWatch Alarm Design

Two critical properties:

**`evaluation_periods`** — Controls how many consecutive breaches before firing.
- `evaluation_periods = 1` with `period = 60 seconds` → Alarm fires on the first minute of breach (noisy; single spike triggers).
- `evaluation_periods = 5` with `period = 60 seconds` → Alarm fires only after 5 consecutive minutes of breach (robust; ignores blips).

For an error alarm, use `evaluation_periods = 1` (catch errors immediately). For latency, use `evaluation_periods = 5` (tolerate occasional spikes).

**`treat_missing_data = "notBreaching"`** — Handles zero traffic gracefully.
- An agent with 100 requests/min generates error metrics every minute.
- At night with zero traffic, CloudWatch sees no data points.
- Without this setting, an alarm might fire on "missing data" (false positive).
- Setting this to `notBreaching` means: if there are no data points, do not trigger the alarm.

### CI/CD for Agent Aliases

The alias-as-pointer pattern enables zero-downtime deployments:

```
Alias "live" → Version 3  (current production, 100% traffic)
              ↓ [developer deploys new code]
Alias "live" → Version 4  (new version, 100% traffic)
              ↓ [if errors spike]
Alias "live" → Version 3  (rollback in 30 seconds)
```

A typical deployment pipeline:

1. `terraform apply` → Creates new agent version (Version N+1).
2. `aws bedrock-agent prepare-agent --agent-id xxx --agent-version N+1` → Prepares new version.
3. `aws bedrock-agent update-agent-alias --agent-alias-name live --agent-version N+1` → Moves alias to new version.
4. Wait 5 minutes; if error alarm fires, rollback: `aws bedrock-agent update-agent-alias --agent-alias-name live --agent-version N` → Restores old version.

Rollback is fast (seconds) because you are only updating a pointer, not re-provisioning.

### Cost Governance via Tags

Every resource created by the module must have three tags:

```hcl
tags = {
  project     = "ai-platform"
  team        = "hr-platform"
  cost-center = "engineering-ai"
}
```

In AWS Cost Explorer, filter by `cost-center = engineering-ai` to see total spend. Resources created without tags are invisible to cost tracking. Retroactive tagging (adding tags months later) does not affect historical cost data. Tag resources from day 1.

---

## Exercise Questions

1. **Console Drift Problem**: A colleague updates the Lambda function environment variables (`HR_DB_URL`) directly in the console to fix a typo. The agent works. What problem does this create? How do you recover without losing the corrected value?

2. **Agent Replacement Detection**: You run `terraform plan` and see `aws_bedrockagent_agent` will be destroyed and recreated (forces replacement). Your agent alias `live` is currently pointing to version 3. What do you check before running `terraform apply` to ensure the alias remains valid?

3. **Error Alarm Diagnostic**: The `bgw-invocation-errors` alarm fires at 3 AM. Walk through your first three diagnostic steps. (Do not say "check logs" — be specific about which service and which query.)

4. **Isolation with Modules**: Two teams, HR and Finance, both call the same `aws_bedrockagent_module`. HR uses `name_prefix = "bgw-hr"` and Finance uses `name_prefix = "bgw-finance"`. If the Finance team runs `terraform destroy` on their state file, can it affect HR's resources? Explain why or why not.

5. **Billing Investigation**: Your billing alarm fires on July 15. You open AWS Cost Explorer and see a spike started on July 12. Which AWS service do you open first to drill into the spike, and what filter do you apply to isolate the spike to a specific component (agent, Lambda, etc.)?

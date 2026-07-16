# Day 5 — Platform Engineering for AgentCore

**Date:** 2026-07-16
**Owner:** hunghan
**Goal:** Extend the 4-day AgentCore mastery plan with Console-as-verification, Terraform IaC, and DevOps/SRE operational patterns — the full platform engineering layer an integration team needs to run AI infra as a self-service platform for other teams.

---

## Purpose & Success Criteria

"Day 5 mastered" means three things simultaneously:
1. **Observe** — can navigate the AWS console to verify any resource the SDK or Terraform created; can read an X-Ray service map and correlate a trace ID to a CloudWatch Logs Insights query in under 2 minutes
2. **Provision reproducibly** — can write and apply a Terraform module that stands up a complete AgentCore Gateway stack from scratch; module is reusable by other teams with a 5-variable interface
3. **Operate** — can set up CloudWatch alarms and a dashboard for a live Gateway; can execute the "agent stopped working" incident runbook end-to-end; understands cost tagging for AI spend attribution

By end of Day 5, the learner can hand another engineer in the integration team a Terraform module and a runbook, and that engineer can deploy a production-ready AgentCore Gateway without any further guidance.

---

## Context

The learner has completed Days 1–4:
- Days 1–3: Gateway foundations, OpenAPI tool registration, auth, guardrails, X-Ray (all via Go SDK)
- Day 4: Evaluations, Identity/Policy, Memory (all via Go SDK)

This plan does NOT modify any Day 1–4 content. Day 5 is additive.

**Firm context:** Mixed CloudFormation + Terraform shop. The integration team owns AI infra end-to-end under a self-service model — other teams consume a Gateway module rather than provisioning resources themselves. Terraform experience: proficient. No need for Terraform fundamentals.

---

## Console Philosophy

**Rule: Terraform provisions. Console verifies. Never the other way.**

Console access in this plan serves two purposes only:
1. **Verification** — after a `terraform apply`, open the console to confirm the resource exists and looks right
2. **Debugging** — X-Ray service maps, CloudWatch Logs Insights, Bedrock Playground for prompt iteration

The console cheat sheet (`content/console-cheatsheet.md`) encodes the mapping from SDK/Terraform operations to console navigation paths. It is a permanent reference, not a one-time exercise.

---

## Folder Layout

```
aws_bedrock_agent_gw/
├── content/
│   ├── day05.md                              # Theory doc (30 min read)
│   ├── console-cheatsheet.md                 # SDK→console map + X-Ray navigation tips
│   └── runbook-agent-stopped.md              # Incident runbook
├── terraform/
│   ├── modules/
│   │   └── agentcore-gateway/               # Reusable self-service module
│   │       ├── main.tf                       # Roles, Lambda, Gateway, Guardrails
│   │       ├── variables.tf
│   │       ├── outputs.tf
│   │       └── monitoring.tf                 # CloudWatch dashboard + SNS alarms
│   └── environments/
│       └── day05-lab/                        # Working example that calls the module
│           ├── main.tf
│           ├── variables.tf
│           └── terraform.tfvars.example
├── .github/
│   └── workflows/
│       └── deploy-gateway.yml                # CI/CD pipeline stub (plan/apply + alias promotion)
└── docs/superpowers/
    ├── specs/2026-07-16-day5-platform-engineering-design.md
    └── plans/2026-07-16-day5-platform-engineering-plan.md
```

---

## Day 5 Time Allocation (6–7 hrs)

| Block | Duration | Content |
|---|---|---|
| Console exploration | 1.5 hrs | Console-as-verification walkthrough; Bedrock Playground |
| Terraform primer | 30 min | Verify Bedrock resource names in AWS provider; `terraform init` |
| Terraform module build | 2.5 hrs | `agentcore-gateway` module + `day05-lab` environment |
| DevOps/SRE layer | 1.5 hrs | Alarms, runbook, cost tagging, CI/CD pipeline pattern |
| Teach-it-back | 30 min | Architecture narrative exercise + exercise questions |

---

## Section 1: Console Exploration

### Console-as-verification walkthrough

After each `terraform apply`, verify in the console:

| Resource | Console path |
|---|---|
| IAM role | IAM → Roles → search `bgw-` |
| Lambda function | Lambda → Functions → `bgw-hr-tool` |
| Bedrock Agent | Amazon Bedrock → Agents → `bgw-*` |
| Agent alias | Amazon Bedrock → Agents → [agent] → Aliases |
| Gateway | Amazon Bedrock → AgentCore → Gateway (verify path on Day 5 — UI may differ) |
| Guardrail | Amazon Bedrock → Guardrails |
| X-Ray traces | CloudWatch → X-Ray traces → filter by annotation |
| CloudWatch dashboard | CloudWatch → Dashboards → `bgw-gateway-ops` |
| CloudWatch alarms | CloudWatch → Alarms → filter `bgw-` |
| Cost by tag | AWS Cost Explorer → Group by tag: `cost-center` |

### Bedrock Playground

The Playground lets you iterate prompts against a deployed agent without writing code.
- Location: Amazon Bedrock → Agents → [agent] → Test
- Use case: tune the agent `Instruction` and verify tool selection improves without a redeploy
- Key difference from API: Playground shows which tools were considered, not just called

### X-Ray navigation tips (covered in detail in console-cheatsheet.md)

Core workflow:
1. Invoke agent via Go SDK → note the `$metadata.requestId` from the response
2. CloudWatch → X-Ray traces → search by annotation `BedrockAgentId = <id>` or by time window
3. Click a trace → expand segments: Agent → Gateway → Lambda (tool) → downstream response
4. Cross-reference: click any segment → copy trace ID → CloudWatch Logs Insights query:
   ```
   fields @timestamp, @message
   | filter @requestId = "<trace-id>"
   | sort @timestamp asc
   ```

---

## Section 2: Console Cheat Sheet

File: `content/console-cheatsheet.md`

A permanent, scannable reference. Structure:

### Part 1: SDK/Terraform → Console navigation table

~15 rows mapping each major operation to its console path. Example rows:

| Operation | SDK method | Terraform resource | Console path |
|---|---|---|---|
| Create IAM role | `iam.CreateRole` | `aws_iam_role` | IAM → Roles → Create role |
| Create Lambda | `lambda.CreateFunction` | `aws_lambda_function` | Lambda → Functions → Create function |
| Create agent | `bedrockagent.CreateAgent` | `aws_bedrockagent_agent` | Bedrock → Agents → Create |
| Create agent alias | `bedrockagent.CreateAgentAlias` | `aws_bedrockagent_agent_alias` | Bedrock → Agents → [agent] → Aliases |
| Invoke agent | `bedrockagentruntime.InvokeAgent` | n/a | Bedrock → Agents → [agent] → Test |
| Create guardrail | `bedrock.CreateGuardrail` | `aws_bedrock_guardrail` | Bedrock → Guardrails → Create |
| View X-Ray traces | n/a | n/a | CloudWatch → X-Ray traces |
| View invocation logs | n/a | n/a | CloudWatch → Log groups → `/aws/bedrock/agents/` |
| Run evaluation | `bedrock.CreateEvaluationJob` | n/a (no TF resource yet) | Bedrock → Evaluations |
| View cost by tag | n/a | `aws_cost_anomaly_monitor` | Cost Explorer → Group by tag |

### Part 2: X-Ray navigation tips (5 numbered tips)

1. Finding traces for a specific agent: filter by `annotation.BedrockAgentId`
2. Reading a service map: identify latency hotspots by segment colour (green < 500ms, yellow < 2s, red > 2s)
3. Correlating trace ID to CloudWatch Logs: copy segment trace ID → Logs Insights query
4. Filtering by error: X-Ray traces → filter `error = true` → identify which segment faulted first
5. Comparing two invocations: open two trace detail tabs, compare segment timings side-by-side

### Part 3: Bedrock Playground quick-reference

- How to switch between agent aliases in the Playground (important for comparing versions)
- How to view tool traces in the Playground UI
- How to reset session to test from a clean state

---

## Section 3: Terraform Module

### Terraform version requirements

- Terraform >= 1.5 (for `check` blocks and `import` block support)
- AWS provider >= 5.30 (Bedrock agent resources stable)
- Backend: S3 + DynamoDB lock (same backend the firm uses for core infra)

### Day 5 Terraform primer (required before building the module)

Before writing Terraform for the Gateway, verify the exact resource names in the current AWS provider:

```bash
# Check which bedrockagent resources exist in current provider
terraform providers schema -json | jq '.provider_schemas."registry.terraform.io/hashicorp/aws".resource_schemas | keys | map(select(startswith("aws_bedrockagent")))'

# Also check:
terraform providers schema -json | jq '.provider_schemas."registry.terraform.io/hashicorp/aws".resource_schemas | keys | map(select(startswith("aws_bedrock_")))'
```

Known resources (as of AWS provider ~5.x):
- `aws_bedrockagent_agent` ✓
- `aws_bedrockagent_agent_alias` ✓
- `aws_bedrockagent_agent_action_group` ✓
- `aws_bedrock_guardrail` ✓

Gateway-specific resource (`aws_bedrockagent_agent_core_gateway` or similar): **verify in primer** — Gateway is newer than agents. If no Terraform resource exists yet, the module falls back to provisioning Gateway via a `null_resource` + local-exec AWS CLI call, with a prominent TODO comment.

### Module interface (`modules/agentcore-gateway/variables.tf`)

```hcl
variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names. Must start with bgw-."
  validation {
    condition     = startswith(var.name_prefix, "bgw")
    error_message = "name_prefix must start with bgw."
  }
}

variable "foundation_model" {
  type    = string
  default = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "tool_configs" {
  type = list(object({
    name        = string
    lambda_zip  = string
    handler     = string
    description = string
  }))
  description = "One entry per tool. Each becomes a Lambda function + Gateway tool."
}

variable "cfn_stack_name" {
  type        = string
  default     = ""
  description = "Optional. Name of an existing CloudFormation stack to pull VpcId, KmsKeyArn from."
}

variable "alarm_sns_arn" {
  type        = string
  default     = ""
  description = "Optional. SNS topic ARN for CloudWatch alarm notifications."
}

variable "monthly_cost_threshold_usd" {
  type        = number
  default     = 0
  description = "Optional. If > 0, creates a CloudWatch billing alarm at this USD threshold per month."
}

variable "tags" {
  type = map(string)
  default = {}
  description = "Tags applied to all resources. Include project, team, cost-center."
}
```

### Module resources (`modules/agentcore-gateway/main.tf`)

The module creates:
1. **IAM execution role** (`aws_iam_role`) — trust: `bedrock.amazonaws.com`; permission: `lambda:InvokeFunction` on module-created Lambdas only
2. **Lambda execution role** (`aws_iam_role`) — trust: `lambda.amazonaws.com`; AWSLambdaBasicExecutionRole
3. **Lambda functions** (`aws_lambda_function`) — one per `tool_configs` entry; zipped from `lambda_zip`
4. **Bedrock agent** (`aws_bedrockagent_agent`) — wires `foundation_model` + agent instruction
5. **Agent alias** (`aws_bedrockagent_agent_alias`) — points to `DRAFT` initially; update after prepare
6. **Action group** (`aws_bedrockagent_agent_action_group`) — one per tool
7. **Guardrail** (`aws_bedrock_guardrail`) — PII redaction enabled
8. **Gateway** — see primer note; `aws_bedrockagent_agent_core_gateway` or CLI fallback

**CFN integration (when `cfn_stack_name` is non-empty):**
```hcl
data "aws_cloudformation_stack" "core" {
  count = var.cfn_stack_name != "" ? 1 : 0
  name  = var.cfn_stack_name
}

locals {
  kms_key_arn = var.cfn_stack_name != "" ? data.aws_cloudformation_stack.core[0].outputs["KmsKeyArn"] : null
}
```

### Module outputs (`modules/agentcore-gateway/outputs.tf`)

```hcl
output "agent_id"             { value = aws_bedrockagent_agent.this.agent_id }
output "agent_alias_id"       { value = aws_bedrockagent_agent_alias.this.agent_alias_id }
output "execution_role_arn"   { value = aws_iam_role.gateway_execution.arn }
output "lambda_arns"          { value = { for t in var.tool_configs : t.name => aws_lambda_function.tool[t.name].arn } }
output "dashboard_url"        { value = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${var.name_prefix}-gateway-ops" }
```

### Monitoring (`modules/agentcore-gateway/monitoring.tf`)

**CloudWatch dashboard** (`aws_cloudwatch_dashboard`):
- Widget 1: Agent invocation count (5-min period)
- Widget 2: Agent invocation error rate
- Widget 3: P99 latency
- Widget 4: Lambda error count per tool

**SNS alarms** (`aws_cloudwatch_metric_alarm`, only when `alarm_sns_arn` non-empty):
- Error rate > 5% for 5 consecutive minutes
- P99 latency > 10 000ms for 5 consecutive minutes

### Day 5 lab environment (`environments/day05-lab/`)

`main.tf` calls the module with the bgw-hr-tool Lambda from Days 1–3:

```hcl
module "day05_gateway" {
  source = "../../modules/agentcore-gateway"

  name_prefix      = "bgw"
  foundation_model = "anthropic.claude-3-haiku-20240307-v1:0"

  tool_configs = [{
    name        = "hr-tool"
    lambda_zip  = "../../../aws/lambda/hr-tool/hr-tool.zip"
    handler     = "main"
    description = "HR employee and department lookup"
  }]

  tags = {
    project     = "bgw"
    team        = "integration"
    cost-center = "ai-platform"
  }
}
```

`terraform.tfvars.example` — a copy-paste starting point with all required variables filled in for us-east-1.

---

## Section 4: DevOps/SRE Operational Layer

### Incident runbook (`content/runbook-agent-stopped.md`)

A 5-step "agent stopped working" diagnostic. For each step: what to check, where to look (console path + CLI command), what a healthy vs unhealthy result looks like.

1. **Check X-Ray** — find the last successful trace; note the timestamp and which segment last responded; determines whether the failure is at agent, Gateway, Lambda, or downstream
2. **Verify IAM trust chain** — `aws iam simulate-principal-policy` on the execution role; confirms whether a policy change broke the 3-party trust
3. **Check Lambda logs** — CloudWatch Logs Insights on `/aws/lambda/bgw-hr-tool`; look for cold start timeouts, memory exhaustion, runtime errors
4. **Verify Gateway tool registration** — confirm the tool is still registered and the OpenAPI spec is valid; a spec change that introduces a syntax error silently breaks discovery
5. **Roll back agent alias** — `aws bedrock-agent update-agent-alias` pointing `LIVE` alias back to the last known-good agent version; restore service, then investigate offline

### CI/CD pipeline pattern

GitHub Actions stub (`.github/workflows/deploy-gateway.yml`):
- **On PR:** `terraform fmt -check`, `terraform validate`, `terraform plan` → post plan output as PR comment
- **On merge to main:** `terraform apply -auto-approve`
- **Post-apply:** `aws bedrock-agent prepare-agent` + `aws bedrock-agent update-agent-alias` to promote the new agent version to the `LIVE` alias
- Secrets: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` or OIDC role assumption (recommended for enterprise)

### Cost governance

**Tagging strategy (enforced in module):**
```hcl
tags = {
  project     = "bgw"
  team        = "integration"
  cost-center = "ai-platform"
}
```

**CloudWatch billing alarm** (in `monitoring.tf`, optional):
```hcl
resource "aws_cloudwatch_metric_alarm" "bedrock_monthly_cost" {
  alarm_name          = "${var.name_prefix}-bedrock-monthly-budget"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 86400
  statistic           = "Maximum"
  threshold           = var.monthly_cost_threshold_usd
  dimensions = { ServiceName = "AmazonBedrock" }
}
```

**Cost Explorer filter:** Group by tag `cost-center` → isolate all AI platform spend across teams.

---

## Section 5: Teach-It-Back

### Architecture narrative exercise

Write without notes:
> "Draw the full Day 5 architecture. Show the Terraform module boundary — what goes inside the module and what the caller provides. Then show the operational layer: where alarms fire, where the runbook starts, how CI/CD moves an agent from development to the LIVE alias."

### Exercise questions

1. A colleague says "I updated the Lambda code, why didn't the agent pick it up?" Walk through the deployment steps they missed.
2. Your billing alarm fires — Bedrock charges are 3× the expected amount. What are the two most likely causes, and which AWS console view do you check first?
3. An agent alias is pointing to a broken agent version. What is the fastest path to restore service without redeploying Terraform?
4. A new team wants to adopt AgentCore Gateway. What inputs do they provide to the Terraform module, and what outputs do they consume?
5. X-Ray shows 200ms at the Gateway segment and 8 000ms at the Lambda segment. Which team owns the problem, and what is the first thing you check?

---

## Global Constraints

- Terraform >= 1.5, AWS provider >= 5.30
- All resource names prefixed `bgw-` (enforced via `variable "name_prefix"` validation)
- Region: us-east-1
- Console: observe/verify only — no provisioning via console
- Module must work standalone (`cfn_stack_name` and `alarm_sns_arn` are optional)
- Same module can be called multiple times with different `name_prefix` values for multi-team isolation
- All resources tagged with `project`, `team`, `cost-center`
- Gateway Terraform resource: if `aws_bedrockagent_agent_core_gateway` does not exist in current provider version, fall back to `null_resource` + `local-exec` AWS CLI; document the limitation clearly

---

## What's Out of Scope

- Multi-region failover (valuable, but a separate project)
- Terraform Cloud / Atlantis setup (assumed firm already has this)
- Knowledge Bases (RAG) — covered in a separate plan
- CDK/Pulumi equivalents — Go CDK is interesting but a separate track

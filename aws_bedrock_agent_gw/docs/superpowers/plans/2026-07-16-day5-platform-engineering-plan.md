# Day 5 — Platform Engineering for AgentCore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the full platform engineering layer for AgentCore — a reusable Terraform module, console verification reference, incident runbook, monitoring alarms, and CI/CD pipeline stub that an integration team can use to run AI infra as a self-service platform.

**Architecture:** A Terraform module (`modules/agentcore-gateway/`) encapsulates IAM, Lambda, Bedrock Agent, Guardrails, and monitoring into a single callable interface. A lab environment (`environments/day05-lab/`) demonstrates a real call to the module. Reference docs (`console-cheatsheet.md`, `runbook-agent-stopped.md`) encode operational knowledge. A GitHub Actions workflow stub wires Terraform plan/apply to CI/CD with automatic agent alias promotion on merge.

**Tech Stack:** Terraform >= 1.5, AWS provider >= 5.30, null provider >= 3.0, GitHub Actions, AWS CLI

## Global Constraints

- Terraform >= 1.5, AWS provider >= 5.30
- All resource names prefixed `bgw-` (enforced via `validation` block in variables.tf)
- Region: us-east-1 throughout
- Console: observe/verify only — never provision via console
- Module must work standalone (`cfn_stack_name`, `alarm_sns_arn`, `monthly_cost_threshold_usd` are all optional)
- Same module callable with different `name_prefix` values for multi-team isolation
- All resources tagged: `project`, `team`, `cost-center` recommended
- Go Lambda runtime: `provided.al2023`
- Gateway Terraform resource: use `aws_bedrockagent_agent_core_gateway` if it exists in the current provider; fall back to `null_resource` with local-exec note if not (verified in Task 18 Step 1 primer)
- Tasks numbered 16–21 (continuing from Days 1–4: Tasks 0–15)

---

## Task 16: Day 5 Theory — `content/day05.md`

**Files:**
- Create: `aws_bedrock_agent_gw/content/day05.md`

**Interfaces:**
- Produces: conceptual foundation for Tasks 17–21; learner reads this before starting labs

- [ ] **Step 1: Write content/day05.md**

```markdown
# Day 5 — Platform Engineering for AgentCore

Read this before the Day 5 labs. Budget: 30 minutes.

---

## 1. Console as Verification Tool

### The rule

Terraform provisions. Console verifies. Never the other way.

Provisioning via console produces resources that are invisible to Terraform
state, unchecked by code review, and unreproducible in other environments.
The moment you click "Create" in the console for a resource your Terraform
also manages, you have state drift — and the next `terraform apply` may
overwrite or destroy it silently.

Console access in this plan has two legitimate purposes:
1. **Verification** — after `terraform apply`, open the console to confirm
   the resource looks right (correct name, correct role, correct config)
2. **Debugging** — X-Ray service maps, CloudWatch Logs Insights, Bedrock
   Playground for iterating prompts without redeploying

### What to verify after `terraform apply`

For each resource created by the module, there is a console location to
verify it. See `content/console-cheatsheet.md` for the full table.

The 30-second verification loop:
1. `terraform apply` completes — read the outputs (agent_id, dashboard_url)
2. Open IAM → confirm `bgw-gateway-execution-role` exists, trust shows `bedrock.amazonaws.com`
3. Open Lambda → confirm `bgw-hr-tool` exists and is Active
4. Open Bedrock → Agents → confirm agent exists and is in PREPARED state
5. Open the dashboard_url output → confirm dashboard widgets are rendering

If any step fails, the problem is in Terraform, not in the console.

---

## 2. Terraform for AgentCore

### AWS provider Bedrock resource inventory

Verify on Day 5 primer (Task 18 Step 1). Known stable resources:

| Terraform resource | What it creates |
|---|---|
| `aws_bedrockagent_agent` | Bedrock Agent (name, model, instruction, IAM role) |
| `aws_bedrockagent_agent_alias` | Named alias pointing to an agent version |
| `aws_bedrockagent_agent_action_group` | Wires a Lambda (or API schema) to an agent |
| `aws_bedrock_guardrail` | Content filtering + PII redaction config |
| `aws_bedrock_guardrail_version` | Pinned version of a guardrail |
| `aws_iam_role` | IAM role (not Bedrock-specific, but required) |
| `aws_lambda_function` | Lambda function backing a tool |
| `aws_cloudwatch_dashboard` | CloudWatch dashboard (JSON body) |
| `aws_cloudwatch_metric_alarm` | Alarm on a CloudWatch metric |

Gateway resource (`aws_bedrockagent_agent_core_gateway`): check in primer.
If it exists, use it. If not, fall back to CLI provisioning via `null_resource`
and document the limitation — this is a temporary gap as the provider catches up.

### Module pattern

A well-designed module presents a minimal interface — callers provide what
varies between teams (tool names, Lambda code, tags) and the module owns
what stays constant (IAM trust policies, Bedrock resource wiring, guardrail
config).

```
module "hr_gateway" {
  source = "../../modules/agentcore-gateway"

  name_prefix  = "bgw-hr"
  tool_configs = [{ name = "hr-tool", lambda_zip = "hr-tool.zip", ... }]
  tags         = { project = "hr", team = "integration", cost-center = "hr-platform" }
}
```

Another team deploying a finance gateway:
```
module "finance_gateway" {
  source = "../../modules/agentcore-gateway"

  name_prefix  = "bgw-finance"
  tool_configs = [{ name = "finance-tool", lambda_zip = "finance-tool.zip", ... }]
  tags         = { project = "finance", team = "integration", cost-center = "finance-platform" }
}
```

Both call the same module. Both are isolated by `name_prefix`. IAM policy
scopes Lambda invoke permissions to only that prefix's tools.

### CFN integration

Many firms have existing CloudFormation stacks that hold shared values:
VPC IDs, KMS key ARNs, shared bucket names. The module consumes these
via a data source rather than requiring the caller to look them up:

```hcl
data "aws_cloudformation_stack" "core" {
  count = var.cfn_stack_name != "" ? 1 : 0
  name  = var.cfn_stack_name
}

locals {
  kms_key_arn = var.cfn_stack_name != ""
    ? lookup(data.aws_cloudformation_stack.core[0].outputs, "KmsKeyArn", null)
    : null
}
```

When `cfn_stack_name = ""` (the default), the module works standalone.
When set, the module pulls values from the existing CFN stack. This is
how you integrate a new Terraform module into a mixed CFN+TF environment
without migrating the CFN stacks.

### State isolation

Separate Terraform state keys for AI infra:

```
s3://your-tf-state-bucket/
  core-infra/                    ← existing CFN or TF core infra
  ai-infra/
    day05-lab/terraform.tfstate  ← this module's state
    hr-gateway/terraform.tfstate ← future: HR team's gateway
    finance-gateway/             ← future: Finance team's gateway
```

Isolation means: a `terraform destroy` in `ai-infra/day05-lab/` cannot
affect core networking or shared IAM. Blast radius is bounded.

---

## 3. DevOps/SRE Operational Layer

### What to measure

Three signals matter for an AgentCore Gateway in production:

| Signal | Metric | Alarm threshold | Why |
|---|---|---|---|
| Error rate | `InvocationClientErrors` | > 0 for 5 min | Any errors need investigation |
| Latency | `InvocationLatency` P99 | > 10 000 ms | Users experience this |
| Cost | `EstimatedCharges` (Bedrock) | > budget/month | AI spend is hard to predict |

Evaluation score drift (from Day 4) is a fourth signal — checked on a
scheduled basis (weekly), not in real-time alarms.

### CloudWatch alarm design

Two properties determine alarm quality:

1. **`evaluation_periods`** — how many consecutive data points must breach
   before the alarm fires. Setting this to 1 means a single spike triggers
   an alert (noisy). Setting it to 5 with `period = 60` means 5 consecutive
   minutes of breach — a real problem, not a transient spike.

2. **`treat_missing_data`** — for an agent that has zero traffic at night,
   missing data points should not trigger the alarm. Set to `"notBreaching"`.

### CI/CD for agent aliases

An agent alias is a pointer to a specific agent version. This is the
mechanism for zero-downtime deploys:

```
Alias "live" → version 3  (current production)
              ↓ deploy new code
Alias "live" → version 4  (new version)
```

The CI/CD pipeline:
1. `terraform apply` — updates IAM, Lambda, action groups (safe to apply live)
2. `prepare-agent` — Bedrock creates a new numbered version from DRAFT
3. `update-agent-alias` — moves "live" pointer to the new version
4. If tests fail post-deploy: `update-agent-alias` moves "live" back to
   the previous version (rollback in < 30 seconds)

This is why the agent alias is distinct from the agent — the alias is the
stable reference, the version underneath it can change.

### Cost governance

Cost attribution requires consistent tagging from day 1. Once charges
accumulate with missing or inconsistent tags, retroactive attribution is
impossible.

Required tags on every resource:
- `project` — which product/feature this serves
- `team` — who owns it (for chargeback)
- `cost-center` — finance code for billing allocation

In AWS Cost Explorer: filter by tag `cost-center = ai-platform` to see
all AI infrastructure spend across teams, broken down by resource type.

---

## 4. Exercise Questions

1. Your colleague updates a Lambda function's environment variables via the
   AWS console. What problem does this create, and how do you fix it without
   losing the change?

2. A `terraform plan` shows that your Bedrock agent will be replaced
   (`forces replacement`). Before applying, what do you check to ensure
   the alias stays pointing at a valid version during the replacement?

3. An alarm fires: `bgw-invocation-errors` is in ALARM state. Walk through
   the first three steps you take to diagnose the problem.

4. Two teams each call the `agentcore-gateway` module with different
   `name_prefix` values. Can one team's `terraform destroy` affect the
   other team's resources? Explain why.

5. A billing alarm fires at month-end. CloudWatch shows the spike started
   3 days ago. Which AWS service do you open first to identify which agent
   drove the spike, and what filter do you apply?
```

- [ ] **Step 2: Verify the file**

```bash
wc -l aws_bedrock_agent_gw/content/day05.md
```

Expected: ≥ 200 lines. All 4 sections present.

---

## Task 17: Console Cheat Sheet + Runbook

**Files:**
- Create: `aws_bedrock_agent_gw/content/console-cheatsheet.md`
- Create: `aws_bedrock_agent_gw/content/runbook-agent-stopped.md`

**Interfaces:**
- Produces: permanent operational reference documents; no code dependencies

- [ ] **Step 1: Write console-cheatsheet.md**

```markdown
# AWS Console Cheat Sheet — AgentCore Gateway

**Rule: Terraform provisions. Console verifies. Never the other way.**

---

## Part 1: SDK / Terraform Operation → Console Navigation

| Operation | SDK method | Terraform resource | Console path |
|---|---|---|---|
| Create IAM role | `iam.CreateRole` | `aws_iam_role` | IAM → Roles → search `bgw-` |
| Attach IAM policy | `iam.PutRolePolicy` | `aws_iam_role_policy` | IAM → Roles → [role] → Permissions |
| Create Lambda | `lambda.CreateFunction` | `aws_lambda_function` | Lambda → Functions → `bgw-*` |
| View Lambda logs | n/a | n/a | Lambda → Functions → [fn] → Monitor → CloudWatch Logs |
| Create Bedrock agent | `bedrockagent.CreateAgent` | `aws_bedrockagent_agent` | Bedrock → Agents → Create |
| Prepare agent | `bedrockagent.PrepareAgent` | (done via CLI post-apply) | Bedrock → Agents → [agent] → Prepare |
| Create agent alias | `bedrockagent.CreateAgentAlias` | `aws_bedrockagent_agent_alias` | Bedrock → Agents → [agent] → Aliases |
| Create action group | `bedrockagent.CreateAgentActionGroup` | `aws_bedrockagent_agent_action_group` | Bedrock → Agents → [agent] → Action groups |
| Invoke agent (test) | `bedrockagentruntime.InvokeAgent` | n/a | Bedrock → Agents → [agent] → Test |
| Create guardrail | `bedrock.CreateGuardrail` | `aws_bedrock_guardrail` | Bedrock → Guardrails |
| Run evaluation | `bedrock.CreateEvaluationJob` | n/a (no TF resource) | Bedrock → Evaluations |
| View X-Ray traces | n/a | n/a | CloudWatch → X-Ray traces |
| View agent logs | n/a | n/a | CloudWatch → Log groups → `/aws/bedrock/agents/` |
| View dashboard | n/a | `aws_cloudwatch_dashboard` | CloudWatch → Dashboards → `bgw-gateway-ops` |
| View alarms | n/a | `aws_cloudwatch_metric_alarm` | CloudWatch → Alarms → search `bgw-` |
| View cost by tag | n/a | n/a | Cost Explorer → Group by tag → `cost-center` |

---

## Part 2: X-Ray Navigation Tips

**Tip 1 — Find traces for a specific agent invocation**

Go to CloudWatch → X-Ray traces.
Filter expression:
```
annotation.BedrockAgentId = "YOUR_AGENT_ID"
```
Or filter by time window if you know when the invocation happened (within the last 30 days).

**Tip 2 — Read a service map to find latency hotspots**

CloudWatch → X-Ray → Service map.
Each node is a service (Agent, Gateway, Lambda, downstream API).
Colour coding: green < 500ms, yellow 500ms–2s, red > 2s.
Click a red/yellow node to drill into its traces.

**Tip 3 — Correlate trace ID to CloudWatch Logs**

In the trace detail, click any segment → copy the Trace ID.
Go to CloudWatch → Log groups → `/aws/bedrock/agents/` → Logs Insights.
Run:
```
fields @timestamp, @message
| filter @requestId = "YOUR_TRACE_ID"
| sort @timestamp asc
```
This shows the full event sequence for that invocation.

**Tip 4 — Filter to error traces only**

X-Ray traces → filter expression:
```
fault = true OR error = true
```
Click the first faulted trace. The red segment in the waterfall view is
the component that first returned an error — that is where to start.

**Tip 5 — Compare two invocations side-by-side**

Open a known-good trace in one browser tab.
Open a failing trace in another tab.
Compare segment timings column by column.
The segment that changed between good and failing is the root cause.

---

## Part 3: Bedrock Playground Quick Reference

**Location:** Amazon Bedrock → Agents → [your agent] → Test

**Switch between aliases:**
In the Test panel, click the alias dropdown (top right of the chat window).
Switch between `live`, `DRAFT`, or any named alias to compare versions.

**View tool call traces:**
In the Test panel, enable "Show trace" (toggle in the top right).
Expand the trace panel after each message to see:
- Which tools the agent considered
- Which it called
- The exact parameters passed
- The raw tool response

**Reset session:**
Click "New session" (top right) to clear session memory.
Use this to test the agent from a clean state without creating a new alias.

**Important:** Changes made in the Playground (e.g., editing the agent
instruction) are saved to the DRAFT version, NOT to the alias in production.
After iterating in the Playground, run `prepare-agent` + `update-agent-alias`
to promote the changes.
```

- [ ] **Step 2: Write runbook-agent-stopped.md**

```markdown
# Runbook: Agent Stopped Working

**Use this runbook when:** an AgentCore Gateway agent is not responding,
returning errors, or producing incorrect outputs where it was previously working.

**Start here:** confirm the symptom before starting the steps.
- Agent returns HTTP 5xx errors → start at Step 1
- Agent returns wrong answers (no error) → start at Step 4 (tool registration)
- Agent is slow (> 30s response) → check Step 3 (Lambda logs) first

---

## Step 1: Check X-Ray for Last Successful Trace

**Goal:** establish when the failure started and which segment faulted first.

**Console:**
CloudWatch → X-Ray traces → filter `annotation.BedrockAgentId = "YOUR_AGENT_ID"`
→ set time range to last 1 hour.

**CLI:**
```bash
aws xray get-trace-summaries \
  --start-time $(date -u -v-1H +%s 2>/dev/null || date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --filter-expression 'annotation.BedrockAgentId = "YOUR_AGENT_ID"' \
  --region us-east-1 \
  --query 'TraceSummaries[*].{Id:Id,Duration:Duration,HasError:HasError,Time:ResponseTime}' \
  --output table
```

**Healthy result:** traces visible, no fault segments.
**Unhealthy result:** no traces (agent never reached), or traces with fault=true.

**If no traces at all:** the failure is before the agent (caller IAM, network,
API Gateway if present). Skip to Step 2.

**If traces show fault in the Gateway segment:** skip to Step 4.
**If traces show fault in the Lambda segment:** go to Step 3.

---

## Step 2: Verify IAM Trust Chain

**Goal:** confirm all three layers of the IAM trust chain are intact.

**Layer 1 — Caller can invoke the agent:**
```bash
aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::ACCOUNT_ID:role/CALLER_ROLE" \
  --action-names "bedrock:InvokeAgent" \
  --resource-arns "arn:aws:bedrock:us-east-1:ACCOUNT_ID:agent-alias/AGENT_ID/ALIAS_ID" \
  --region us-east-1
```
Expected: `EvalDecision: allowed`

**Layer 2 — Gateway execution role trust policy:**
```bash
aws iam get-role \
  --role-name bgw-gateway-execution-role \
  --query 'Role.AssumeRolePolicyDocument.Statement[0].Principal'
```
Expected: `{"Service": "bedrock.amazonaws.com"}`

**Layer 3 — Gateway execution role can invoke tool Lambdas:**
```bash
aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::ACCOUNT_ID:role/bgw-gateway-execution-role" \
  --action-names "lambda:InvokeFunction" \
  --resource-arns "arn:aws:lambda:us-east-1:ACCOUNT_ID:function:bgw-hr-tool" \
  --region us-east-1
```
Expected: `EvalDecision: allowed`

**If any layer shows `implicitDeny` or `explicitDeny`:** a recent IAM change
broke that layer. Check `aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=PutRolePolicy` for recent changes.

---

## Step 3: Check Lambda Logs

**Goal:** confirm the tool Lambda is running and not crashing.

**Console:**
CloudWatch → Log groups → `/aws/lambda/bgw-hr-tool` → Log streams →
most recent stream → scan for ERROR or REPORT lines.

**CLI (last 100 log events):**
```bash
LOG_GROUP="/aws/lambda/bgw-hr-tool"
LOG_STREAM=$(aws logs describe-log-streams \
  --log-group-name "$LOG_GROUP" \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --query 'logStreams[0].logStreamName' \
  --output text \
  --region us-east-1)

aws logs get-log-events \
  --log-group-name "$LOG_GROUP" \
  --log-stream-name "$LOG_STREAM" \
  --limit 100 \
  --region us-east-1 \
  --query 'events[*].message' \
  --output text
```

**Healthy REPORT line:** `REPORT RequestId: ... Duration: 45.12 ms  Billed Duration: 46 ms  Memory Size: 128 MB  Max Memory Used: 22 MB`
**Unhealthy:** `errorType: Runtime.ExitError` or `Task timed out after 3.00 seconds`

**Common causes:**
- Cold start timeout (first invocation after idle period): increase Lambda timeout
- Memory exhaustion: increase Lambda memory
- Runtime crash: check the error message before REPORT

---

## Step 4: Verify Gateway Tool Registration

**Goal:** confirm the tool is still registered, the action group is enabled,
and the OpenAPI/Lambda association is intact.

```bash
AGENT_ID="YOUR_AGENT_ID"

# List action groups
aws bedrock-agent list-agent-action-groups \
  --agent-id "$AGENT_ID" \
  --agent-version DRAFT \
  --region us-east-1 \
  --query 'actionGroupSummaries[*].{Name:actionGroupName,State:actionGroupState,Lambda:actionGroupExecutor.lambda}'

# If a group shows State: DISABLED, re-enable it:
aws bedrock-agent update-agent-action-group \
  --agent-id "$AGENT_ID" \
  --agent-version DRAFT \
  --action-group-id "ACTION_GROUP_ID" \
  --action-group-name "hr-tool" \
  --action-group-state ENABLED \
  --region us-east-1
```

**After any action group change:** run `prepare-agent` and update the alias
(Step 5 rollback flow, but forward instead of backward).

---

## Step 5: Roll Back Agent Alias to Last Known-Good Version

**Goal:** restore service immediately by pointing the alias back to the
previous working version. Investigate the broken version offline.

```bash
AGENT_ID="YOUR_AGENT_ID"
ALIAS_ID="YOUR_ALIAS_ID"

# List available versions (most recent first)
aws bedrock-agent list-agent-versions \
  --agent-id "$AGENT_ID" \
  --region us-east-1 \
  --query 'agentVersionSummaries[*].{Version:agentVersion,Status:agentStatus,Updated:updatedAt}' \
  --output table

# Roll back to the last good version (replace N with version number)
GOOD_VERSION="N"
aws bedrock-agent update-agent-alias \
  --agent-id "$AGENT_ID" \
  --agent-alias-id "$ALIAS_ID" \
  --agent-alias-name "live" \
  --routing-configuration "[{\"agentVersion\": \"$GOOD_VERSION\"}]" \
  --region us-east-1

echo "Alias rolled back to version $GOOD_VERSION"
```

**Verify rollback worked:**
```bash
aws bedrock-agent get-agent-alias \
  --agent-id "$AGENT_ID" \
  --agent-alias-id "$ALIAS_ID" \
  --region us-east-1 \
  --query 'agentAlias.routingConfiguration'
```

**After service is restored:** open a Terraform branch, identify what changed
in the broken version, fix it, test in a staging alias first, then re-deploy.
```

- [ ] **Step 3: Verify both files exist**

```bash
wc -l aws_bedrock_agent_gw/content/console-cheatsheet.md aws_bedrock_agent_gw/content/runbook-agent-stopped.md
```

Expected: both files present, each ≥ 80 lines.

---

## Task 18: Terraform Module Foundation

**Files:**
- Create: `aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/variables.tf`
- Create: `aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/main.tf` (IAM + Lambda resources only)

**Interfaces:**
- Produces:
  - `aws_iam_role.gateway_execution` — referenced by Task 19 (agent resource_role_arn)
  - `aws_iam_role.lambda_execution` — referenced by Task 19 (lambda role)
  - `aws_lambda_function.tool[name]` — referenced by Task 19 (action group executor)
  - All variables — consumed by Tasks 19, 20, 21

- [ ] **Step 1: Terraform primer — verify Bedrock resource names**

Before writing any Terraform, confirm what `aws_bedrockagent_*` resources exist in the current provider version.

Create a temporary directory:
```bash
mkdir -p /tmp/tf-check && cat > /tmp/tf-check/main.tf << 'EOF'
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.30" }
  }
}
EOF
cd /tmp/tf-check && terraform init -upgrade 2>&1 | tail -5
terraform providers schema -json 2>/dev/null \
  | python3 -c "
import json, sys
s = json.load(sys.stdin)
rs = s['provider_schemas']['registry.terraform.io/hashicorp/aws']['resource_schemas']
for k in sorted(rs):
    if 'bedrock' in k.lower():
        print(k)
"
```

Expected output includes at minimum:
```
aws_bedrock_guardrail
aws_bedrock_guardrail_version
aws_bedrockagent_agent
aws_bedrockagent_agent_action_group
aws_bedrockagent_agent_alias
aws_bedrockagent_agent_knowledge_base_association
aws_bedrockagent_knowledge_base
```

Check if `aws_bedrockagent_agent_core_gateway` appears. If it does, note the exact resource name — use it in Task 19 instead of the `null_resource` fallback. If it does not appear, the `null_resource` fallback in Task 19 is correct.

Also verify the CloudWatch metric namespace for Bedrock agent invocations:
```bash
aws cloudwatch list-metrics \
  --namespace "AWS/Bedrock" \
  --region us-east-1 \
  --query 'Metrics[].MetricName' \
  --output text | tr '\t' '\n' | sort -u
```

Note the exact metric names — they are used verbatim in Task 20's `monitoring.tf`.

- [ ] **Step 2: Create the module directory structure**

```bash
mkdir -p aws_bedrock_agent_gw/terraform/modules/agentcore-gateway
mkdir -p aws_bedrock_agent_gw/terraform/environments/day05-lab
```

- [ ] **Step 3: Write variables.tf**

`aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/variables.tf`:
```hcl
variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names. Must start with 'bgw'."
  validation {
    condition     = startswith(var.name_prefix, "bgw")
    error_message = "name_prefix must start with 'bgw'."
  }
}

variable "foundation_model" {
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
  description = "Bedrock foundation model ID for the agent."
}

variable "tool_configs" {
  type = list(object({
    name        = string
    lambda_zip  = string
    handler     = string
    description = string
  }))
  description = "One entry per tool. Each becomes a Lambda function and a Bedrock action group."
}

variable "cfn_stack_name" {
  type        = string
  default     = ""
  description = "Optional. Name of an existing CloudFormation stack. Pulls KmsKeyArn output when present."
}

variable "alarm_sns_arn" {
  type        = string
  default     = ""
  description = "Optional. SNS topic ARN for CloudWatch alarm notifications. No alarms created when empty."
}

variable "monthly_cost_threshold_usd" {
  type        = number
  default     = 0
  description = "Optional. If > 0, creates a CloudWatch billing alarm at this USD threshold per month."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources. Recommended keys: project, team, cost-center."
}
```

- [ ] **Step 4: Write main.tf (IAM + Lambda foundation)**

`aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/main.tf`:
```hcl
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

# Allow gateway execution role to invoke the module's tool Lambdas
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
```

- [ ] **Step 5: Validate the foundation**

```bash
cd aws_bedrock_agent_gw/terraform/modules/agentcore-gateway
terraform init
terraform validate
```

Expected:
```
Success! The configuration is valid.
```

If validate fails, check the error — most common: wrong provider source string or HCL syntax error.

Also run format check:
```bash
terraform fmt -check
```

If it reports formatting issues, auto-fix them:
```bash
terraform fmt
```

---

## Task 19: Terraform Module Agent Layer

**Files:**
- Modify: `aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/main.tf` (append agent resources)
- Create: `aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/outputs.tf`

**Interfaces:**
- Consumes: `aws_iam_role.gateway_execution.arn`, `aws_lambda_function.tool[name].arn` from Task 18
- Produces:
  - `aws_bedrockagent_agent.this.agent_id` — used in outputs.tf and monitoring.tf
  - `aws_bedrockagent_agent_alias.this.agent_alias_id` — used in outputs.tf

- [ ] **Step 1: Append Bedrock agent resources to main.tf**

Append to the end of `aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/main.tf`:
```hcl

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
#
# Verify aws_bedrockagent_agent_core_gateway existence in Task 18 Step 1 primer.
#
# If the resource EXISTS in your provider version, replace the null_resource
# below with:
#
# resource "aws_bedrockagent_agent_core_gateway" "this" {
#   name     = "${var.name_prefix}-gateway"
#   role_arn = aws_iam_role.gateway_execution.arn
#   tags     = var.tags
# }
#
# If the resource does NOT exist yet, keep this null_resource — it prints
# the CLI command to run manually and marks the gap for future migration.

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
      echo "    --role-arn <execution-role-arn> \\"
      echo "    --region us-east-1"
      echo ""
      echo "Replace this null_resource with aws_bedrockagent_agent_core_gateway"
      echo "once the resource is available in hashicorp/aws >= X.Y."
      echo "==========================================================="
    EOT
  }
}
```

- [ ] **Step 2: Create outputs.tf**

`aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/outputs.tf`:
```hcl
output "agent_id" {
  description = "Bedrock Agent ID"
  value       = aws_bedrockagent_agent.this.agent_id
}

output "agent_alias_id" {
  description = "Bedrock Agent alias ID"
  value       = aws_bedrockagent_agent_alias.this.agent_alias_id
}

output "execution_role_arn" {
  description = "ARN of the Gateway IAM execution role"
  value       = aws_iam_role.gateway_execution.arn
}

output "lambda_arns" {
  description = "Map of tool name to Lambda function ARN"
  value       = { for k, v in aws_lambda_function.tool : k => v.arn }
}

output "dashboard_url" {
  description = "CloudWatch dashboard console URL (available after monitoring.tf is applied)"
  value       = "https://console.aws.amazon.com/cloudwatch/home#dashboards:name=${var.name_prefix}-gateway-ops"
}
```

- [ ] **Step 3: Validate**

```bash
cd aws_bedrock_agent_gw/terraform/modules/agentcore-gateway
terraform validate && terraform fmt -check
```

Expected: `Success! The configuration is valid.`

---

## Task 20: Terraform Monitoring

**Files:**
- Create: `aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/monitoring.tf`

**Interfaces:**
- Consumes: `aws_bedrockagent_agent.this.agent_id` from Task 19, `var.alarm_sns_arn`, `var.monthly_cost_threshold_usd`
- Produces: `aws_cloudwatch_dashboard.gateway_ops`, `aws_cloudwatch_metric_alarm.error_rate`, `.latency_p99`, `.monthly_cost`

- [ ] **Step 1: Note on CloudWatch metric names**

Before writing, verify the exact metric names from the Task 18 primer output. The plan uses:
- Namespace: `AWS/Bedrock`
- Metric `InvocationCount` — total agent invocations
- Metric `InvocationClientErrors` — client-side errors (4xx equivalents)
- Metric `InvocationLatency` — end-to-end latency in milliseconds

If the primer returned different metric names (e.g. `UserErrors` instead of `InvocationClientErrors`), substitute the correct names throughout this file.

- [ ] **Step 2: Write monitoring.tf**

`aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/monitoring.tf`:
```hcl
# ── CloudWatch Dashboard ──────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "gateway_ops" {
  dashboard_name = "${var.name_prefix}-gateway-ops"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Agent Invocations (5 min)"
          metrics = [["AWS/Bedrock", "InvocationCount", "AgentId", aws_bedrockagent_agent.this.agent_id]]
          period  = 300
          stat    = "Sum"
          region  = "us-east-1"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "Invocation Errors"
          metrics = [["AWS/Bedrock", "InvocationClientErrors", "AgentId", aws_bedrockagent_agent.this.agent_id]]
          period  = 300
          stat    = "Sum"
          region  = "us-east-1"
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "P99 Latency (ms)"
          metrics = [["AWS/Bedrock", "InvocationLatency", "AgentId", aws_bedrockagent_agent.this.agent_id]]
          period  = 300
          stat    = "p99"
          region  = "us-east-1"
          view    = "timeSeries"
        }
      }
    ]
  })
}

# ── CloudWatch Alarms (only when alarm_sns_arn is provided) ───────────────────

resource "aws_cloudwatch_metric_alarm" "error_rate" {
  count = var.alarm_sns_arn != "" ? 1 : 0

  alarm_name          = "${var.name_prefix}-invocation-errors"
  alarm_description   = "AgentCore Gateway invocation errors — investigate immediately"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "InvocationClientErrors"
  namespace           = "AWS/Bedrock"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_sns_arn]

  dimensions = {
    AgentId = aws_bedrockagent_agent.this.agent_id
  }
}

resource "aws_cloudwatch_metric_alarm" "latency_p99" {
  count = var.alarm_sns_arn != "" ? 1 : 0

  alarm_name          = "${var.name_prefix}-latency-p99"
  alarm_description   = "AgentCore Gateway P99 latency exceeded 10 seconds"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 5
  metric_name         = "InvocationLatency"
  namespace           = "AWS/Bedrock"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 10000
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.alarm_sns_arn]

  dimensions = {
    AgentId = aws_bedrockagent_agent.this.agent_id
  }
}

# ── Billing Alarm (only when monthly_cost_threshold_usd > 0) ─────────────────
# Note: billing metrics are only available in us-east-1 regardless of resource region.

resource "aws_cloudwatch_metric_alarm" "monthly_cost" {
  count = var.monthly_cost_threshold_usd > 0 ? 1 : 0

  alarm_name          = "${var.name_prefix}-bedrock-monthly-budget"
  alarm_description   = "Bedrock monthly charges exceeded ${var.monthly_cost_threshold_usd} USD"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = 86400
  statistic           = "Maximum"
  threshold           = var.monthly_cost_threshold_usd
  treat_missing_data  = "notBreaching"
  alarm_actions       = var.alarm_sns_arn != "" ? [var.alarm_sns_arn] : []

  dimensions = {
    ServiceName = "AmazonBedrock"
  }
}
```

- [ ] **Step 3: Validate the complete module**

```bash
cd aws_bedrock_agent_gw/terraform/modules/agentcore-gateway
terraform validate && terraform fmt -check
```

Expected: `Success! The configuration is valid.`

List all files in the module:
```bash
ls -1 aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/
```

Expected:
```
main.tf
monitoring.tf
outputs.tf
variables.tf
```

---

## Task 21: Lab Environment + CI/CD Stub

**Files:**
- Create: `aws_bedrock_agent_gw/terraform/environments/day05-lab/main.tf`
- Create: `aws_bedrock_agent_gw/terraform/environments/day05-lab/variables.tf`
- Create: `aws_bedrock_agent_gw/terraform/environments/day05-lab/terraform.tfvars.example`
- Create: `aws_bedrock_agent_gw/.github/workflows/deploy-gateway.yml`

**Interfaces:**
- Consumes: `modules/agentcore-gateway` from Tasks 18–20
- Produces: working environment that calls the module; CI/CD pipeline that automates plan/apply/promote

- [ ] **Step 1: Write environments/day05-lab/main.tf**

`aws_bedrock_agent_gw/terraform/environments/day05-lab/main.tf`:
```hcl
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.30"
    }
  }

  # Uncomment and configure for shared team use:
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "ai-infra/day05-lab/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "your-terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
    }
  }
}

module "day05_gateway" {
  source = "../../modules/agentcore-gateway"

  name_prefix      = var.name_prefix
  foundation_model = var.foundation_model
  tool_configs     = var.tool_configs
  tags             = var.tags
}

output "agent_id" {
  value = module.day05_gateway.agent_id
}

output "agent_alias_id" {
  value = module.day05_gateway.agent_alias_id
}

output "execution_role_arn" {
  value = module.day05_gateway.execution_role_arn
}

output "lambda_arns" {
  value = module.day05_gateway.lambda_arns
}

output "dashboard_url" {
  value = module.day05_gateway.dashboard_url
}
```

- [ ] **Step 2: Write environments/day05-lab/variables.tf**

`aws_bedrock_agent_gw/terraform/environments/day05-lab/variables.tf`:
```hcl
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "name_prefix" {
  type    = string
  default = "bgw"
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
}

variable "tags" {
  type    = map(string)
  default = {}
}
```

- [ ] **Step 3: Write terraform.tfvars.example**

`aws_bedrock_agent_gw/terraform/environments/day05-lab/terraform.tfvars.example`:
```hcl
aws_region       = "us-east-1"
name_prefix      = "bgw"
foundation_model = "anthropic.claude-3-haiku-20240307-v1:0"

tool_configs = [
  {
    name        = "hr-tool"
    lambda_zip  = "../../../aws/lambda/hr-tool/hr-tool.zip"
    handler     = "main"
    description = "HR employee and department lookup. Use for questions about employees, departments, and org structure."
  }
]

tags = {
  project     = "bgw"
  team        = "integration"
  cost-center = "ai-platform"
}
```

- [ ] **Step 4: Validate the lab environment**

```bash
cd aws_bedrock_agent_gw/terraform/environments/day05-lab
terraform init
terraform validate
```

Expected: `Success! The configuration is valid.`

Run format check:
```bash
terraform fmt -check
```

- [ ] **Step 5: Create the GitHub Actions workflow directory and file**

```bash
mkdir -p aws_bedrock_agent_gw/.github/workflows
```

`aws_bedrock_agent_gw/.github/workflows/deploy-gateway.yml`:
```yaml
name: Deploy AgentCore Gateway

on:
  push:
    branches: [main]
    paths: ['aws_bedrock_agent_gw/terraform/**']
  pull_request:
    branches: [main]
    paths: ['aws_bedrock_agent_gw/terraform/**']

env:
  TF_WORKING_DIR: aws_bedrock_agent_gw/terraform/environments/day05-lab
  AWS_REGION: us-east-1

permissions:
  id-token: write       # Required for OIDC role assumption
  contents: read
  pull-requests: write  # Required to post plan as PR comment

jobs:
  terraform:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ${{ env.TF_WORKING_DIR }}

    steps:
      - uses: actions/checkout@v4

      # OIDC-based authentication (recommended for enterprise — no long-lived keys)
      # Replace AWS_OIDC_ROLE_ARN secret with your firm's deployment role ARN
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_OIDC_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~> 1.5"

      - name: Terraform Init
        run: terraform init

      - name: Terraform Format Check
        run: terraform fmt -check

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        id: plan
        run: terraform plan -no-color -out=tfplan
        continue-on-error: true

      - name: Post Plan as PR Comment
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const plan = `${{ steps.plan.outputs.stdout }}`;
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `### Terraform Plan\n\`\`\`hcl\n${plan}\n\`\`\``
            });

      - name: Fail if Plan Failed
        if: steps.plan.outcome == 'failure'
        run: exit 1

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: terraform apply -auto-approve tfplan

      # After apply: prepare agent and promote alias to the new version
      # This achieves zero-downtime deploys — the alias is the stable reference
      - name: Promote Agent Alias to LIVE
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: |
          AGENT_ID=$(terraform output -raw agent_id)
          ALIAS_ID=$(terraform output -raw agent_alias_id)

          echo "Preparing agent $AGENT_ID..."
          aws bedrock-agent prepare-agent \
            --agent-id "$AGENT_ID" \
            --region "$AWS_REGION"

          # Poll until PREPARED (max 60 seconds)
          for i in $(seq 1 12); do
            STATUS=$(aws bedrock-agent get-agent \
              --agent-id "$AGENT_ID" \
              --query 'agent.agentStatus' \
              --output text \
              --region "$AWS_REGION")
            echo "Status: $STATUS (attempt $i/12)"
            [ "$STATUS" = "PREPARED" ] && break
            sleep 5
          done

          if [ "$STATUS" != "PREPARED" ]; then
            echo "ERROR: Agent did not reach PREPARED state after 60s. Aborting alias promotion."
            exit 1
          fi

          # Get the latest version number (list-agent-versions returns newest first)
          AGENT_VERSION=$(aws bedrock-agent list-agent-versions \
            --agent-id "$AGENT_ID" \
            --query 'agentVersionSummaries[0].agentVersion' \
            --output text \
            --region "$AWS_REGION")

          echo "Promoting alias $ALIAS_ID to version $AGENT_VERSION..."
          aws bedrock-agent update-agent-alias \
            --agent-id "$AGENT_ID" \
            --agent-alias-id "$ALIAS_ID" \
            --agent-alias-name "live" \
            --routing-configuration "[{\"agentVersion\": \"$AGENT_VERSION\"}]" \
            --region "$AWS_REGION"

          echo "Done. Agent $AGENT_ID version $AGENT_VERSION is now LIVE."
```

- [ ] **Step 6: Verify all Day 5 files exist**

```bash
find aws_bedrock_agent_gw/content -name "day05.md" -o -name "console-cheatsheet.md" -o -name "runbook-agent-stopped.md"
find aws_bedrock_agent_gw/terraform -name "*.tf" | sort
find aws_bedrock_agent_gw/.github -name "*.yml"
```

Expected output:
```
aws_bedrock_agent_gw/content/console-cheatsheet.md
aws_bedrock_agent_gw/content/day05.md
aws_bedrock_agent_gw/content/runbook-agent-stopped.md
aws_bedrock_agent_gw/terraform/environments/day05-lab/main.tf
aws_bedrock_agent_gw/terraform/environments/day05-lab/variables.tf
aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/main.tf
aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/monitoring.tf
aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/outputs.tf
aws_bedrock_agent_gw/terraform/modules/agentcore-gateway/variables.tf
aws_bedrock_agent_gw/.github/workflows/deploy-gateway.yml
```

Plus `terraform.tfvars.example` (not matched by `*.tf`):
```bash
ls aws_bedrock_agent_gw/terraform/environments/day05-lab/
```

Expected: `main.tf  terraform.tfvars.example  variables.tf`

- [ ] **Step 7: Final terraform validate on both directories**

```bash
cd aws_bedrock_agent_gw/terraform/modules/agentcore-gateway
terraform validate

cd ../environments/day05-lab
terraform validate
```

Both must output: `Success! The configuration is valid.`

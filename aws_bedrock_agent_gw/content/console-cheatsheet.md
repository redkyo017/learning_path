# AWS Console Cheat Sheet — AgentCore Gateway

**Rule: Terraform provisions. Console verifies. Never the other way.**

---

## Part 1: SDK / Terraform → Console Navigation

| Operation | SDK method | Terraform resource | Console path |
|---|---|---|---|
| Create IAM role | `iam.CreateRole` | `aws_iam_role` | IAM → Roles → search `bgw-` |
| Attach IAM policy | `iam.PutRolePolicy` | `aws_iam_role_policy` | IAM → Roles → [role] → Permissions |
| Create Lambda | `lambda.CreateFunction` | `aws_lambda_function` | Lambda → Functions → `bgw-*` |
| View Lambda logs | n/a | n/a | Lambda → [fn] → Monitor → CloudWatch Logs |
| Create Bedrock agent | `bedrockagent.CreateAgent` | `aws_bedrockagent_agent` | Bedrock → Agents → Create |
| Prepare agent | `bedrockagent.PrepareAgent` | (CLI post-apply) | Bedrock → Agents → [agent] → Prepare |
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

Show filter expression: `annotation.BedrockAgentId = "YOUR_AGENT_ID"`

Mention: also filter by time window if known.

---

**Tip 2 — Read a service map to find latency hotspots**

Path: CloudWatch → X-Ray → Service map.

Colour coding: green < 500ms, yellow 500ms–2s, red > 2s. Click red/yellow node → drill into traces.

---

**Tip 3 — Correlate trace ID to CloudWatch Logs**

Steps: trace detail → copy Trace ID → CloudWatch → Log groups → `/aws/bedrock/agents/` → Logs Insights.

Show the exact Logs Insights query:

```
fields @timestamp, @message
| filter @requestId = "YOUR_TRACE_ID"
| sort @timestamp asc
```

---

**Tip 4 — Filter to error traces only**

Filter expression: `fault = true OR error = true`

Click the first faulted trace. The red segment in the waterfall view is the component that first returned an error.

---

**Tip 5 — Compare two invocations side-by-side**

Open a known-good trace in one browser tab, failing trace in another. The segment that changed between good and failing is the root cause.

---

## Part 3: Bedrock Playground Quick Reference

**Location:** Amazon Bedrock → Agents → [your agent] → Test

**Switch between aliases:** alias dropdown top right of chat window. Switch between `live`, `DRAFT`, or any named alias to compare versions.

**View tool call traces:** enable "Show trace" toggle top right. After each message: expand trace panel to see which tools were considered, which were called, exact parameters, and raw tool response.

**Reset session:** "New session" button top right. Clears session memory for clean-state testing.

**Important:** Changes made in the Playground are saved to DRAFT, NOT to the alias in production. After iterating, run `prepare-agent` + `update-agent-alias` to promote.

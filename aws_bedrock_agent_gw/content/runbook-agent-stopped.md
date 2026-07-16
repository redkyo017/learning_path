# Runbook: Agent Stopped Working

**Use this runbook when:** an AgentCore Gateway agent is not responding,
returning errors, or producing incorrect outputs where it was previously working.

**Start here:** confirm the symptom first.
- Agent returns HTTP 5xx errors → start at Step 1
- Agent returns wrong answers (no error) → start at Step 4
- Agent is slow (> 30s response) → check Step 3 (Lambda logs) first

---

## Step 1: Check X-Ray for Last Successful Trace

Goal: establish when failure started and which segment faulted first.

Console path: CloudWatch → X-Ray traces → filter `annotation.BedrockAgentId = "YOUR_AGENT_ID"` → last 1 hour.

CLI command:

```bash
aws xray get-trace-summaries \
  --start-time $(date -u -v-1H +%s 2>/dev/null || date -u -d '1 hour ago' +%s) \
  --end-time $(date -u +%s) \
  --filter-expression 'annotation.BedrockAgentId = "YOUR_AGENT_ID"' \
  --region us-east-1 \
  --query 'TraceSummaries[*].{Id:Id,HasError:HasError,Duration:Duration}' \
  --output table
```

Healthy result: traces visible, no fault segments.
Unhealthy: no traces (failure before agent — check Step 2) or traces with fault=true.

Decision tree:
- No traces at all → Step 2 (IAM)
- Traces show fault in Gateway segment → Step 4 (tool registration)
- Traces show fault in Lambda segment → Step 3 (Lambda logs)

---

## Step 2: Verify IAM Trust Chain

Goal: confirm all three layers intact.

**Layer 1 — Caller can invoke agent:**

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::ACCOUNT_ID:role/CALLER_ROLE" \
  --action-names "bedrock:InvokeAgent" \
  --resource-arns "arn:aws:bedrock:us-east-1:ACCOUNT_ID:agent-alias/AGENT_ID/ALIAS_ID" \
  --region us-east-1
```

Expected: `EvalDecision: allowed`

---

**Layer 2 — Gateway execution role trust policy:**

```bash
aws iam get-role \
  --role-name bgw-gateway-execution-role \
  --query 'Role.AssumeRolePolicyDocument.Statement[0].Principal'
```

Expected: `{"Service": "bedrock.amazonaws.com"}`

---

**Layer 3 — Gateway execution role can invoke tool Lambda:**

```bash
aws iam simulate-principal-policy \
  --policy-source-arn "arn:aws:iam::ACCOUNT_ID:role/bgw-gateway-execution-role" \
  --action-names "lambda:InvokeFunction" \
  --resource-arns "arn:aws:lambda:us-east-1:ACCOUNT_ID:function:bgw-hr-tool" \
  --region us-east-1
```

Expected: `EvalDecision: allowed`

---

If any layer shows `implicitDeny` or `explicitDeny`: check recent CloudTrail for IAM policy changes:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=PutRolePolicy \
  --region us-east-1
```

---

## Step 3: Check Lambda Logs

Goal: confirm tool Lambda is running, not crashing.

Console: CloudWatch → Log groups → `/aws/lambda/bgw-hr-tool` → Log streams → most recent stream.

CLI (last 100 events):

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

Healthy REPORT line: `Duration: 45.12 ms  Billed Duration: 46 ms  Max Memory Used: 22 MB`
Unhealthy: `errorType: Runtime.ExitError` or `Task timed out after 3.00 seconds`

Common causes: cold start timeout (increase Lambda timeout), memory exhaustion (increase memory), runtime crash (read error before REPORT).

---

## Step 4: Verify Gateway Tool Registration

Goal: confirm action group is enabled and Lambda association is intact.

```bash
AGENT_ID="YOUR_AGENT_ID"
aws bedrock-agent list-agent-action-groups \
  --agent-id "$AGENT_ID" \
  --agent-version DRAFT \
  --region us-east-1 \
  --query 'actionGroupSummaries[*].{Name:actionGroupName,State:actionGroupState}'
```

If any group shows `State: DISABLED`, re-enable:

```bash
aws bedrock-agent update-agent-action-group \
  --agent-id "$AGENT_ID" \
  --agent-version DRAFT \
  --action-group-id "ACTION_GROUP_ID" \
  --action-group-name "hr-tool" \
  --action-group-state ENABLED \
  --region us-east-1
```

After any change: run `prepare-agent` + `update-agent-alias` to propagate to the live alias.

---

## Step 5: Roll Back Agent Alias to Last Known-Good Version

Goal: restore service immediately. Investigate broken version offline.

```bash
AGENT_ID="YOUR_AGENT_ID"
ALIAS_ID="YOUR_ALIAS_ID"

# List available versions (most recent first)
aws bedrock-agent list-agent-versions \
  --agent-id "$AGENT_ID" \
  --region us-east-1 \
  --query 'agentVersionSummaries[*].{Version:agentVersion,Status:agentStatus,Updated:updatedAt}' \
  --output table

# Roll back (replace N with last known-good version number)
GOOD_VERSION="N"
aws bedrock-agent update-agent-alias \
  --agent-id "$AGENT_ID" \
  --agent-alias-id "$ALIAS_ID" \
  --agent-alias-name "live" \
  --routing-configuration "[{\"agentVersion\": \"$GOOD_VERSION\"}]" \
  --region us-east-1

echo "Alias rolled back to version $GOOD_VERSION"
```

Verify rollback:

```bash
aws bedrock-agent get-agent-alias \
  --agent-id "$AGENT_ID" \
  --agent-alias-id "$ALIAS_ID" \
  --region us-east-1 \
  --query 'agentAlias.routingConfiguration'
```

After service restored: open a branch, identify what changed in the broken version, fix it, test in a staging alias first, then redeploy.

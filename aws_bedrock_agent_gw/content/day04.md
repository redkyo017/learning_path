# Day 4 — Full AgentCore Stack

Read this before the Day 4 labs. Budget: 30 minutes.

---

## 1. AgentCore Evaluations

### Why evaluations are not optional

X-Ray and CloudWatch tell you what happened at the infrastructure level: latency,
error rates, throttling events, Lambda cold starts, and model invocation counts.
They cannot tell you whether the agent's answer was correct.

Evaluations measure output quality. An agent can return HTTP 200 with a plausible,
wrong answer every time and look completely healthy in every operational dashboard.
Evaluations are the only mechanism that catches semantic failures.

| Concern | X-Ray / CloudWatch | Evaluations |
|---|---|---|
| Invocation errors | Yes | No |
| Latency percentiles | Yes | No |
| Answer correctness | No | Yes |
| Hallucination rate | No | Yes |
| Regression after prompt change | No | Yes |
| Tool selection accuracy | No | Yes |

The two tools are complementary, not interchangeable. Run both in production.

### How an evaluation job works

```
S3 bucket
(evaluation dataset — JSONL, one test case per line)
         |
         v
  Evaluation Job (BedrockAgent API — async)
         |
         v
  Agent invoked once per dataset row
  (same agent alias as production)
         |
         v
  Scoring engine
  (LLM-as-judge: compares agent response to referenceResponse)
         |
         v
  Results written to S3
  (JSON per case + aggregate summary)
```

The evaluation job is asynchronous. You submit it, poll for `COMPLETED` status,
then read results from the output S3 prefix. The agent being evaluated is the
actual production alias — not a stub. This means evaluations test the full
reasoning chain including tool selection.

### Two use cases

**Quality gate before release.** Run evaluations in CI before promoting a new
agent version. If average relevance falls below threshold, the pipeline fails and
the version does not deploy. This prevents shipping regressions in tool descriptions,
system prompts, or knowledge base updates.

**Regression detection.** Keep a fixed dataset that covers known-good cases.
After any change — prompt edit, tool description update, new knowledge base
documents — re-run evaluations and compare scores to the baseline. A drop of
more than 0.05 in average relevance warrants investigation before merging.

### Evaluation dataset format

Each row in the JSONL file is one test case. Required fields:

```jsonl
{"input": "Which department does Alice Chen work in?", "referenceResponse": "Alice Chen works in the Engineering department.", "sessionId": "eval-001"}
{"input": "How many employees are in the Finance team?", "referenceResponse": "The Finance team has 42 employees.", "sessionId": "eval-002"}
{"input": "Who is the direct manager of Bob Kim?", "referenceResponse": "Bob Kim's direct manager is Carol Davis.", "sessionId": "eval-003"}
```

`input` is what the evaluator sends to the agent.
`referenceResponse` is the ground-truth the scoring model compares against.
`sessionId` keeps each case isolated so context from one case does not bleed into
another.

Store the dataset at a deterministic S3 key so CI can reference it by path.
Version your datasets alongside your agent definitions — a dataset for v1.2 of an
agent should be kept even after v1.3 ships, so you can re-run history.

### Key metric: Relevance to reference

Relevance to reference is scored 0–1 per case. The scoring model compares the
agent's response to `referenceResponse` and assigns a score based on semantic
overlap and factual alignment.

Thresholds used in the Day 4 labs:
- Per case: >= 0.75 (any single case below this is flagged individually)
- Aggregate average: >= 0.85 (evaluation job is marked failed if average falls short)

A score below 0.75 on a specific case tells you the agent failed that question.
An average below 0.85 tells you the agent is unreliable across the dataset as a whole.
Both thresholds matter: a single critical question failing is just as important as
a broadly mediocre performance.

### How tool descriptions affect scores

The scoring model evaluates the agent's final answer, not the tool call. But tool
description quality directly causes wrong tool selection or incorrect parameters,
which produces wrong answers.

Vague description:
```
Name: get_employee_info
Description: Returns information about employees.
```

Precise description:
```
Name: get_employee_info
Description: Returns the department name, headcount of that department, and direct
             manager for a named employee. Input: employee full name (string).
             Returns JSON with fields: department (string),
             departmentHeadcount (int), manager (string).
```

With the vague description, a dataset of 10 HR questions often scores an average
relevance around 0.62. The agent uses the tool but cannot predict what fields it
returns, so it asks the wrong question or misinterprets the response. Replacing
the description with the precise version on the same dataset typically lifts
the average above 0.88. Nothing changed in the agent's model or the tool's code —
only the description.

This is the primary feedback loop evaluations enable: measure, identify the
failing cases, trace the failure to its root cause (almost always a description
or prompt issue), fix it, re-evaluate.

---

## 2. AgentCore Identity and Policy

### Two distinct concerns

**Identity** answers: who is this agent? When a supervisor agent calls a
sub-agent, the sub-agent needs to verify that the caller is a known, authorized
principal — not an arbitrary HTTP caller or a different agent from a different team.

**Policy** answers: what is this agent allowed to do? Even a fully verified,
trusted caller must be constrained to the operations its role explicitly permits.

Conflating the two is a common mistake. Treat them as separate enforcement points.

### Identity in practice: supervisor to sub-agent

```
Supervisor Agent
  ARN: arn:aws:bedrock:ap-southeast-1:123456789012:agent/SUP001
  Execution role: arn:aws:iam::123456789012:role/supervisor-role
       |
       | InvokeAgent call
       | caller identity propagated in request context
       v
HR Specialist Agent
  ARN: arn:aws:bedrock:ap-southeast-1:123456789012:agent/HR001
  Execution role: arn:aws:iam::123456789012:role/hr-agent-role
       |
       | Trust policy on hr-agent-role:
       |   Principal: arn:aws:iam::123456789012:role/supervisor-role
       |   Action: sts:AssumeRole
       v
  Tool execution proceeds only for the trusted supervisor
```

The trust policy on `hr-agent-role` is the enforcement point. If the caller's
identity does not match the trusted principal, the assume-role call fails at the
IAM layer and the tool is never reached. The HR agent's code does not need to
implement any caller verification logic — IAM handles it.

### Policy in practice: IAM-scoped tool access

```
Restricted execution role                   Full execution role
arn:.../agent-hr-restricted-role            arn:.../agent-admin-role
           |                                           |
           | Allow:                                    | Allow:
           |   bedrock:InvokeModel                     |   bedrock:InvokeModel
           |   dynamodb:GetItem on hr-table            |   dynamodb:* on all tables
           | Deny (explicit):                          |   s3:GetObject on all buckets
           |   dynamodb:GetItem on salary-table        |
           v                                           v
HR Agent                                    Admin Agent
(salary table blocked at IAM level)         (full data access)
```

The access constraint lives entirely in IAM. The HR agent's prompt does not say
"do not read salary data" — the role makes that API call impossible. An agent
operating under `agent-hr-restricted-role` cannot access salary records regardless
of what the model decides to do.

### Enterprise compliance pattern

For tools that access sensitive data — salary records, PII, financial records,
audit logs — create a dedicated execution role with least-privilege access to
that data. Assign that role only to agents that have completed a compliance review.
All other agents use roles that explicitly deny access to sensitive resources.

This produces three concrete benefits:
1. Every access decision is in CloudTrail (assume-role events, DynamoDB GetItem calls).
   Auditors can query who accessed what without relying on application-level logging.
2. The control surface is a single IAM policy document, not a distributed set of
   prompt instructions across multiple agent versions.
3. Revoking access is a single IAM change. No redeployment, no prompt engineering.

### Why IAM enforcement is more reliable than prompt-based restrictions

A prompt instruction such as "do not access salary data under any circumstances"
can be overridden by a sufficiently crafted user input or an adversarial prompt
injection through a tool response. IAM cannot be overridden by user input.

The agent's execution role determines which AWS API calls succeed at the
infrastructure level, independent of the model's reasoning. A denied API call
returns an `AccessDeniedException` no matter what the model intended.

Rule of thumb: use prompts to shape behavior (tone, format, reasoning approach);
use IAM to enforce limits (data access, service calls, cross-account operations).

---

## 3. AgentCore Memory

### Session memory vs long-term memory

| Dimension | Session Memory | Long-term Memory |
|---|---|---|
| Scope | Single conversation | Across multiple sessions |
| Storage | Managed, ephemeral | Persistent, indexed |
| Retention | Until session ends | Configurable (days) |
| Primary use case | Multi-turn coherence within one chat | User preferences, conversation history |
| Requires memoryId | No | Yes |
| Automatic summarization | No | Yes (SESSION_SUMMARY type) |
| Extra cost | None beyond invocation | Additional storage |

Session memory is on by default for any multi-turn invocation: the agent receives
the conversation history in each turn. Long-term memory requires explicit
configuration and a stable `memoryId` per user.

### How it works

`memoryId` ties a series of sessions to a user identity. When a session ends,
AgentCore generates a `SESSION_SUMMARY` and stores it under that `memoryId`.
On the next session with the same `memoryId`, the agent retrieves the summaries
and includes them in its context before processing the first user message.

The summary generation is automatic. You configure which memory types to enable
and how many days to retain them. AgentCore handles summarization and retrieval.
You only need to pass the correct `memoryId` on each invocation.

If the `memoryId` is omitted or wrong, no historical context is retrieved —
the agent starts each session with no knowledge of prior conversations.

### Enabling memory when creating an agent

```go
package main

import (
    "context"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/service/bedrockagent"
    "github.com/aws/aws-sdk-go-v2/service/bedrockagent/types"
)

func createAgentWithMemory(ctx context.Context, client *bedrockagent.Client) (*bedrockagent.CreateAgentOutput, error) {
    return client.CreateAgent(ctx, &bedrockagent.CreateAgentInput{
        AgentName:            aws.String("hr-assistant"),
        AgentResourceRoleArn: aws.String("arn:aws:iam::123456789012:role/hr-agent-role"),
        FoundationModel:      aws.String("anthropic.claude-3-5-sonnet-20241022-v2:0"),
        MemoryConfiguration: &types.MemoryConfiguration{
            EnabledMemoryTypes: []types.MemoryType{
                types.MemoryTypeSessionSummary,
            },
            StorageDays: aws.Int32(30), // retain summaries for 30 days
        },
    })
}
```

`StorageDays` controls how long summaries persist before automatic deletion.
Set it to match your data retention policy — 30 days is a common default; GDPR
contexts may require 7 or fewer.

### Passing memoryId when invoking an agent

```go
package main

import (
    "context"
    "fmt"
    "time"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/service/bedrockagentruntime"
)

func invokeAgentWithMemory(
    ctx context.Context,
    client *bedrockagentruntime.Client,
    agentID, agentAliasID, userID, inputText string,
) (*bedrockagentruntime.InvokeAgentOutput, error) {
    // SessionId changes each conversation — unique per chat session.
    // MemoryId stays constant for a given user — ties sessions together.
    sessionID := fmt.Sprintf("session-%s-%d", userID, time.Now().UnixMilli())

    return client.InvokeAgent(ctx, &bedrockagentruntime.InvokeAgentInput{
        AgentId:      aws.String(agentID),
        AgentAliasId: aws.String(agentAliasID),
        SessionId:    aws.String(sessionID),
        MemoryId:     aws.String("user-" + userID), // stable across all sessions for this user
        InputText:    aws.String(inputText),
    })
}
```

`SessionId` is per-conversation. `MemoryId` is per-user. This is the critical
distinction. Two conversations for the same user must share a `MemoryId` but
have different `SessionId` values. If `SessionId` were reused, the old session
history would be appended to rather than summarized and stored.

### When NOT to use memory

**Single-turn workloads.** If every agent call is independent — batch processing,
one-shot data extraction, document summarization — enabling memory adds latency
and storage cost with no benefit. The agent fetches summaries it will never use.

**High-throughput pipelines.** Memory retrieval adds a round-trip before the first
response token. At high request rates, this compounds into significant latency at
the tail. Profile the added latency in a load test before enabling memory on
any pipeline that has a P95 latency SLO.

**GDPR or right-to-erasure requirements without a deletion pipeline.** Long-term
memory stores user interaction summaries under a stable `memoryId`. If users have
the right to delete their data, you must implement a deletion flow that purges all
records for a given `memoryId`. Without that flow, enabling long-term memory
creates a compliance liability. Build the deletion path before you enable the
feature — retrofitting it later is harder than it looks.

---

## 4. Runtime and Registry

### Runtime: managed container execution

AgentCore Runtime packages an agent as a container and manages its lifecycle.
The platform handles image pulling, scaling, networking, and IAM credential
injection. You write a Dockerfile, push to ECR, and point the Runtime config
at your image URI.

**When to use Runtime instead of Lambda:**

| Criterion | AgentCore Runtime | Lambda |
|---|---|---|
| Dependency size | Large (> 250 MB unzipped) | Small (fits in deployment package) |
| Startup time tolerance | 2–8 seconds acceptable | Sub-second required |
| Execution duration | Long-running (up to 15 min) | Up to 15 minutes |
| Container customization | Full Dockerfile control | Limited to layers |
| GPU / hardware access | Supported | Not available |
| Use case fit | Heavy ML deps, custom runtimes | Lightweight glue code |

The Day 4 labs use Lambda for all tools (lightweight HTTP wrappers). Runtime
becomes relevant when a tool requires large libraries — a local embedding model,
a proprietary enterprise SDK, or a Python environment with scipy/torch dependencies
that exceed the Lambda package limit.

### Cold start behavior

The first invocation after a container is deployed starts cold. The container
image is pulled from ECR, the process starts, and initialization code runs.
For Go binaries with minimal deps, this is typically 1–3 seconds. For Python
environments with large imports, expect 6–15 seconds.

Subsequent invocations on a warm container skip image pull and process start.
Only your handler code runs, so latency drops to near-zero startup overhead.

**Mitigation options:**

Provisioned concurrency keeps N container instances warm at all times. Each
request hits a live container with no cold start. Cost: you pay for idle container
time even when there are no requests. Use it only for latency-critical paths.

Minimizing initialization defers expensive setup — loading config from SSM,
establishing DB connections — to first use rather than package init. The cold
start still happens, but it completes faster.

Smaller images reduce pull time. Use multi-stage builds in your Dockerfile to
exclude build tools from the final image. A 200 MB image pulls meaningfully
faster than a 1.5 GB image on cold start.

### Cost model

Runtime charges per invocation-second: the clock starts when the container
receives the request and stops when it returns the response. You are not charged
for idle time between invocations (unlike provisioned concurrency, which charges
for reserved capacity continuously).

Implication for design: a 10-second agent run costs 10x a 1-second run. Optimize
for response latency, not just correctness. Eliminate unnecessary tool calls,
reduce prompt verbosity, and prefer streaming responses to reduce perceived latency
even if wall-clock time stays the same.

### Registry: org-wide catalogue

Registry is a discovery and governance layer. Platform teams publish agent
definitions — ARN, version, description, owner, compliance tags — to the Registry.
Application teams query it to find approved agents rather than hardcoding ARNs or
sharing them out-of-band.

```
Platform Team
    |
    | Publishes:
    |   name: hr-assistant-v2
    |   ARN: arn:aws:bedrock:...:agent/HR002
    |   owner: platform-team@example.com
    |   tags: compliance-approved=true, env=prod
    v
[AgentCore Registry]
    |
    | App team queries:
    |   list agents where compliance-approved=true AND env=prod
    v
App Team receives ARN
    |
    v
Used directly in their supervisor agent or workflow
```

This decouples agent consumers from agent producers. When the platform team
updates an agent to a new alias, they update the Registry entry. App teams that
query by tag automatically resolve to the new ARN on their next lookup.

Registry is consulted at deploy time or startup — not per request. Cache the
resolved ARN in your application config rather than querying Registry on every
agent invocation.

### Full-stack architecture

```
Client (HTTP / SDK)
        |
        v
[Gateway]
  - Route request to correct agent alias
  - Authenticate caller (IAM SigV4, API key)
  - Enforce per-tool rate limits
  - Apply guardrails to tool inputs and outputs
        |
        +---------> [Memory]
        |             - Retrieve session summaries for memoryId
        |             - Store new session summary on close
        v
[Runtime]
  - Warm or cold-start container
  - Inject execution role credentials
  - Agent reasoning loop executes here
        |
        +---------> [Policy / IAM]
        |             - Evaluate permissions at each outbound API call
        |             - Deny if execution role lacks permission
        |
        +---------> Tool A (Lambda — HR lookup)
        |
        +---------> Tool B (Lambda — org chart)
        |
        +---------> Knowledge Base (S3 + vector index)
        v
Response streamed to client
        |
        v  (async, after response is sent)
[Evaluations]
  - Compare response to reference dataset
  - Score relevance 0-1 per case
  - Write aggregate results to S3
  - Fail CI pipeline if average drops below threshold

[Registry]   <-- consulted at deploy / startup, not per request
  - Org catalogue of approved agents
  - Platform team publishes; app teams discover
```

All six components are in play by end of Day 4. Days 1–3 covered Gateway,
Guardrails, X-Ray, and rate limiting. Day 4 adds Evaluations, Identity/Policy
enforcement, Memory, Runtime, and Registry.

---

## 5. Exercise Questions

Work through these before starting the labs. They test understanding, not recall.

**Question 1.**
An HR agent returns plausible but incorrect department names for roughly 15% of
employee queries. X-Ray shows no errors. CloudWatch shows no throttling.
Invocation latency is normal. Which AgentCore component or AWS service is the
correct tool for detecting and quantifying this failure mode, and why can't
X-Ray or CloudWatch catch it?

**Question 2.**
A compliance requirement states: no agent may invoke any tool that reads from the
`salary-records` DynamoDB table. You need to enforce this technically, not through
documentation or convention alone. At which layer do you enforce it, what is the
specific mechanism, and why is a prompt instruction insufficient?

**Question 3.**
A user asks the HR agent: "What was the outcome of the promotion discussion we had
last week?" The agent responds that it has no record of previous conversations.
`MemoryConfiguration` was set with `SESSION_SUMMARY` enabled when the agent was
created. What is the most likely misconfiguration in the invocation code?

**Question 4.**
A supervisor agent delegates a task to an HR specialist sub-agent. The HR agent
needs to verify that the caller is the authorized supervisor, not an arbitrary
external caller. Where does this verification live, and what specific AWS construct
enforces it at the infrastructure level?

**Question 5.**
An AgentCore Runtime container takes 8 seconds to cold-start. The team requires
at most 2 seconds on the first request after deployment. Which AgentCore component
is responsible for this behavior? Name two options for addressing it and describe
the cost or operational trade-off of each.

---

*End of Day 4 theory. Proceed to the labs.*

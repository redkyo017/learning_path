# LLM Integration Supplement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write `aws_bedrock_agent_gw/content/llm-integration.md` — a standalone reference covering how AgentCore Gateway interacts with both Bedrock-native LLMs and external LLMs, including model selection, the central integration point architecture, pros/cons, and best practices.

**Architecture:** Single markdown content file following the existing `content/dayNN.md` pattern. No code, no compilation. All verification is manual: file exists, all 9 spec sections present, model IDs match spec exactly.

**Tech Stack:** Markdown only.

## Global Constraints

- File location: `aws_bedrock_agent_gw/content/llm-integration.md` (new file — do NOT modify any existing file)
- No Go lab, no Terraform module changes, no changes to Days 1–5
- Not a git repository — no git commit steps
- All Bedrock model IDs verbatim from spec (exact strings, including version suffixes)
- Cross-region profile IDs use `us.` prefix verbatim
- Prose budget: 30-minute read (consistent with all other day files)
- No TBD, TODO, or placeholder content anywhere in the file

---

### Task 22: LLM Integration Supplement Content File

**Files:**
- Create: `aws_bedrock_agent_gw/content/llm-integration.md`

**Interfaces:**
- Consumes: spec at `aws_bedrock_agent_gw/docs/superpowers/specs/2026-07-17-llm-integration-design.md`
- Produces: standalone reference doc; referenced by learner after completing Day 1–5

- [ ] **Step 1: Create `aws_bedrock_agent_gw/content/llm-integration.md` with the complete content below**

Write the file with exactly this content (no additions, no removals):

```markdown
# LLM Integration — How AgentCore Gateway Interacts with Models

Read this after completing Day 1. Budget: 30 minutes.

---

## 1. The Two Interaction Paths

AgentCore Gateway is the common denominator across every LLM integration
pattern. LLMs come and go; the Gateway, tools, and auth mediation stay put.

```
Path A — Bedrock-native                 Path B — External MCP Client
──────────────────────────────          ──────────────────────────────
User Request                            External Application
      │                                         │
Bedrock Agents runtime                  MCP Client (SigV4-signed HTTP)
      │                                         │
Foundation Model (e.g. Claude Haiku)    External LLM (GPT-4, Claude API)
      │  "call tool X with args Y"               │  "call tool X with args Y"
      ▼                                         ▼
      ┌─────────────────────────────────────────────────┐
      │              AgentCore Gateway                  │
      │  Tool Registry │ Auth Mediation │ Observability  │
      └───────────────────────┬─────────────────────────┘
                              │
               ┌──────────────┴──────────────┐
               │                             │
        Lambda tools                HTTP / REST APIs
               │
          Tool Result
               │
      ▼ (both paths)
LLM continues reasoning → final response
```

The top half (which LLM, which runtime) changes per integration. The bottom
half (Gateway, Lambda, auth, observability) never changes.

---

## 2. Path A — Bedrock Agents Reasoning Loop

This is what happens inside a single Bedrock Agent invocation. Most engineers
assume the LLM calls Lambda directly — it does not.

**The loop, step by step:**

1. **Bedrock runtime assembles context.** It calls Gateway `tools/list`,
   assembles the list of available tools, and sends the LLM:
   `system_prompt (instruction) + user_message + tool_list`.

2. **LLM reasons and signals intent.** The LLM returns a *tool use signal* —
   structured JSON, not an execution:
   ```json
   { "tool": "getEmployee", "arguments": { "employeeId": "E001" } }
   ```
   The LLM has decided which tool to call and what to pass. It has not called
   anything yet.

3. **Bedrock runtime executes the call.** The runtime sends to Gateway:
   ```
   tools/call { name: "getEmployee", arguments: { employeeId: "E001" } }
   ```

4. **Gateway routes to Lambda.** Gateway invokes the Lambda function using
   the execution role (IAM Party 2 from Day 1). Lambda executes and returns
   the result. Auth mediation (API keys, OAuth tokens) happens here — the
   LLM never sees them.

5. **Result fed back to LLM.** The runtime sends the tool result back as a
   tool output message:
   ```
   Tool result: { "name": "Alice Smith", "department": "Engineering" }
   ```

6. **LLM reasons again.** The LLM may call another tool or emit its final
   response. If another tool call → repeat from step 2.

7. **Loop ends.** When the LLM emits text without a tool call signal, the
   Bedrock runtime returns the response to the caller.

**Key invariant:** the LLM never holds credentials. It never calls Lambda.
It only signals intent. The Bedrock runtime and Gateway execute.

---

## 3. Bedrock Model Selection

Not all Bedrock models support tool use. Use this table to choose.

| Model | Bedrock Model ID | Tool Support | Cost Tier | Latency | Best For |
|-------|-----------------|--------------|-----------|---------|----------|
| Claude 3 Haiku | `anthropic.claude-3-haiku-20240307-v1:0` | Full | Low | Fast | Simple routing, high-volume |
| Claude 3 Sonnet | `anthropic.claude-3-sonnet-20240229-v1:0` | Full | Medium | Medium | General production |
| Claude 3.5 Sonnet | `anthropic.claude-3-5-sonnet-20241022-v2:0` | Full (best) | Medium-High | Medium | Complex multi-step reasoning |
| Claude 3 Opus | `anthropic.claude-3-opus-20240229-v1:0` | Full | High | Slow | Highest accuracy, low-volume |
| Amazon Titan Text Premier | `amazon.titan-text-premier-v1:0` | Partial | Low | Fast | Cost-sensitive, AWS-native workloads |
| Llama 3.1 8B | `meta.llama3-1-8b-instruct-v1:0` | Partial | Low | Fast | Open-source requirement, simple tools |
| Llama 3.1 70B | `meta.llama3-1-70b-instruct-v1:0` | Good | Medium | Medium | Open-source with quality requirement |

**"Full" tool support** means the model reliably: (a) selects the correct
tool from a set, (b) extracts parameters with the right types and formats,
(c) handles multi-step tool chains without losing context.

**"Partial" support** means basic tool calls work but multi-step chains or
unusual parameter types may produce incorrect extraction. Test thoroughly
before production.

### Cross-Region Inference Profiles

In production, always use cross-region profile IDs (prefixed with `us.`).
They route requests across multiple AWS regions transparently, preventing
failures if one region has capacity issues.

```
# Dev / test — single region, lower cost
anthropic.claude-3-haiku-20240307-v1:0

# Production — always cross-region
us.anthropic.claude-3-haiku-20240307-v1:0
us.anthropic.claude-3-sonnet-20240229-v1:0
us.anthropic.claude-3-5-sonnet-20241022-v2:0
us.anthropic.claude-3-opus-20240229-v1:0
```

**Quick selection guide:**

- Cost-critical, high-volume (>50k req/month) → `us.anthropic.claude-3-haiku-20240307-v1:0`
- General production → `us.anthropic.claude-3-5-sonnet-20241022-v2:0`
- Highest-accuracy, compliance-critical → `us.anthropic.claude-3-opus-20240229-v1:0`
- Open-source requirement → `meta.llama3-1-70b-instruct-v1:0`

---

## 4. Path B — External LLM as MCP Client

AgentCore Gateway exposes a standard MCP HTTP endpoint. Any MCP-compatible
client can call it — Bedrock Agents runtime is not required.

This means GPT-4, Claude via the Anthropic API, or any custom application
using an MCP SDK can invoke your Lambda tools through the same Gateway that
your Bedrock agents use.

**Interaction sequence:**

```
External Application
      │
      │ 1. HTTP POST to Gateway MCP endpoint (SigV4-signed)
      │    Body: { method: "tools/list" }
      ▼
AgentCore Gateway
      │
      │ Returns tool schemas (name, description, input schema)
      ▼
External Application
      │
      │ 2. Passes tool schemas to External LLM as function definitions
      │    (OpenAI function format, Anthropic tool format, etc.)
      ▼
External LLM (GPT-4 / Claude API / etc.)
      │
      │ 3. Returns tool call signal:
      │    { tool: "getEmployee", arguments: { employeeId: "E001" } }
      ▼
External Application
      │
      │ 4. HTTP POST to Gateway MCP endpoint (SigV4-signed)
      │    Body: { method: "tools/call", params: { name: "getEmployee",
      │            arguments: { employeeId: "E001" } } }
      ▼
AgentCore Gateway → Lambda → Tool Result
      │
      │ 5. Returns tool result to External Application
      ▼
External Application feeds result back to External LLM → loop continues
```

**Authentication:**

- The *external LLM itself* never authenticates to AWS. The external LLM is
  just a reasoning engine called by your application — it never touches AWS.
- The *calling application* needs IAM credentials with
  `bedrock-agentcore:InvokeGateway` permission on the Gateway resource.
- All HTTP requests to the Gateway MCP endpoint must be SigV4-signed by the
  calling application. Use an AWS SDK (Go, Python, Java) to sign requests, or
  run the application on EC2/ECS with an IAM instance/task role.

**Enterprise use case:**

Your integration team's existing services use GPT-4 today. They can call
your AWS Lambda tools through the same Gateway — without migrating to Bedrock
Agents. Same tools, same auth mediation, same observability. Different driver.

---

## 5. AgentCore Gateway as Central Integration Point

### Why This Architecture Matters

Without a central Gateway, every LLM integration needs its own copy of:
- Tool definitions (OpenAPI specs or function schemas)
- Credential management (API keys, OAuth tokens)
- Auth logic (how to get and rotate tokens)
- Observability setup (logs, traces)

With a central Gateway, these exist exactly once. Any LLM integration that
points at the Gateway gets all of them automatically.

### Pros

| Benefit | What It Means in Practice |
|---------|--------------------------|
| LLM portability | Swap from Claude Haiku to Claude Sonnet (or GPT-4) by changing one variable — no tool code changes required |
| Credential centralization | No LLM, agent, or calling application ever holds API keys; all secrets stay in Gateway + Secrets Manager |
| Single observability layer | All tool calls, all models, one CloudWatch + X-Ray view; correlate errors across models easily |
| Immediate propagation | Add a new Lambda tool to the Gateway today; all LLMs and agents see it immediately without redeployment |
| Consistent governance | Guardrails, PII redaction, and topic denial are applied once at the Gateway, not per-LLM |
| Tool reuse | One Lambda function can serve 10 Bedrock agents and 3 external LLM integrations simultaneously |

### Cons

| Risk | Mitigation |
|------|-----------|
| Single point of failure — Gateway unavailable means all LLMs lose tool access | Use cross-region inference profiles in Bedrock; implement timeout + graceful degradation in external MCP clients |
| Latency overhead — every tool call routes through Gateway (~20–50 ms extra hop) | Acceptable for most agent workloads; pre-warm Lambda functions to reduce cold-start contribution |
| AWS vendor lock-in — Gateway is AWS-managed, not portable to GCP/Azure | MCP is an open standard; tools can be re-registered on a different MCP server if needed |
| External LLM auth complexity — calling applications need SigV4 signing | Use IAM roles on EC2/ECS; avoid long-lived access keys; use AWS SDK signing libraries |
| Model compatibility gaps — tool descriptions tuned for Claude may not route correctly on GPT-4 | Test every new tool with the least-capable model in your fleet before production |

### Best Practices

1. **Design for the weakest model in your fleet.** If a tool description works
   correctly on Claude 3 Haiku, it will work on every model above it. The
   reverse is not guaranteed — a description that requires Sonnet-level
   reasoning will silently misfire on Haiku.

2. **One Gateway per domain, not per LLM.** Create one HR Gateway and one
   Finance Gateway. Do not create a "Claude Gateway" and a "GPT-4 Gateway" —
   that defeats centralization and doubles your maintenance surface.

3. **Store the Gateway endpoint URL in Parameter Store.** The endpoint is a
   deployment artifact. Hardcoding it in application code means every endpoint
   rotation requires a code change. Retrieve it at startup from SSM Parameter
   Store.

4. **Use cross-region inference profiles in production.** Prefix model IDs
   with `us.` for all Bedrock-native integrations. No downside; significant
   availability upside on regional capacity events.

5. **Version-control OpenAPI specs.** A tool description change is a breaking
   change for any LLM that has cached or adapted to the old schema. Treat
   Gateway tool definitions like a public API contract — version and deprecate,
   don't silently mutate.

6. **Never create or update tools in the AWS console.** Console changes create
   state drift with Terraform. All tool registration goes through Terraform or
   the SDK (the same rule as for all resources in this project).

7. **Test each new tool with at least two model families before production.**
   Claude and GPT-4 parse tool descriptions differently. A description that
   produces perfect parameter extraction on Claude may produce type errors on
   GPT-4. Run both before production.

8. **Add `foundation_model` as a CloudWatch dimension.** When a tool-failure
   spike occurs at 3 AM, you need to know which LLM triggered it. Tag your
   custom CloudWatch metrics with the model ID so you can filter by model in
   the dashboard.

---

## 6. Console: Model Verification and Testing

### Verify After `terraform apply`

After provisioning, confirm the assigned model matches your `terraform.tfvars`:

1. AWS console → Bedrock → left nav **"Agents"** → click agent name (e.g. `bgw-hr-agent`)
2. **"Overview"** tab → scroll to "Agent details" → confirm **"Model"** field
   matches your `foundation_model` variable exactly.
3. If there is a mismatch: **do not change it in the console.** Fix
   `terraform.tfvars` and run `terraform apply` again.

### Bedrock Playground for Model Testing

Playground lets you test a model change before committing it to Terraform.
Use it to validate, not to configure.

1. Open agent in console → **"Test"** tab → **"Playground"**
2. Change the model dropdown to a different model (e.g. from Haiku to Sonnet)
3. Send the same test query — observe whether tool routing is correct and
   compare response quality
4. **Important:** Changes made in Playground are session-only. They do NOT
   persist to the agent configuration. Use Playground to decide, then update
   `terraform.tfvars` and apply.

---

## 7. Terraform: Model Management

### Swapping Models

Change `foundation_model` in your `terraform.tfvars` and run `terraform apply`.
Bedrock performs an in-place update — it does not destroy and recreate the
agent. Alias and version history are preserved.

**Operational caveat:** After the model change, the agent returns to
`UNPREPARED` status. You must re-run the prepare-agent step (or trigger the
CI/CD alias promotion pipeline from Day 5) before the agent can serve
requests again.

```hcl
# terraform.tfvars — dev environment (cheap, fast)
foundation_model = "anthropic.claude-3-haiku-20240307-v1:0"

# terraform.tfvars.prod — production (cross-region, higher quality)
foundation_model = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"
```

Apply the prod config explicitly:
```bash
terraform apply -var-file=terraform.tfvars.prod
```

### Complete Cross-Region Profile ID Reference

```hcl
# ── Standard (single-region) — dev/test only ──────────────────────────
"anthropic.claude-3-haiku-20240307-v1:0"
"anthropic.claude-3-sonnet-20240229-v1:0"
"anthropic.claude-3-5-sonnet-20241022-v2:0"
"anthropic.claude-3-opus-20240229-v1:0"

# ── Cross-region US — recommended for production ───────────────────────
"us.anthropic.claude-3-haiku-20240307-v1:0"
"us.anthropic.claude-3-sonnet-20240229-v1:0"
"us.anthropic.claude-3-5-sonnet-20241022-v2:0"
"us.anthropic.claude-3-opus-20240229-v1:0"

# ── Amazon and open-source (no cross-region profiles available) ────────
"amazon.titan-text-premier-v1:0"
"meta.llama3-1-8b-instruct-v1:0"
"meta.llama3-1-70b-instruct-v1:0"
```

**Note:** The current `variables.tf` has no validation on `foundation_model`.
An invalid model ID passes `terraform apply` silently and fails at agent
invocation time with a `ResourceNotFoundException`. Double-check the ID
string before applying.

---

## 8. Exercise Questions

Answer these without looking at the doc. If you cannot, re-read the relevant
section.

1. **Reasoning loop:** An agent calls a Lambda tool incorrectly — it passes
   `employeeId: "Alice Smith"` instead of `employeeId: "E001"`. At which step
   in the Path A reasoning loop did the failure occur? What is the fix and in
   which file?

2. **Model selection:** You are building a high-volume support agent that
   routes simple HR questions (100,000 requests/month). Your team also needs
   a quarterly compliance report agent (50 requests/month) that must never
   hallucinate. Which Bedrock model ID do you assign to each, and why?

3. **Central integration point:** Your team adds a new `listDepartments` tool
   to the Gateway. Three existing Bedrock agents and one external Python app
   using GPT-4 share the same Gateway. What is the earliest all four callers
   can use the new tool, and what action (if any) must each caller take?

4. **External MCP client:** A developer says "we cannot use the Gateway from
   our GPT-4 integration because GPT-4 doesn't have IAM credentials." Explain
   why this reflects a misunderstanding of Path B, and describe what actually
   needs IAM credentials.

5. **Best practice — single point of failure:** Your production Gateway
   returns 503 errors for 10 minutes due to a regional AWS incident. Describe
   two changes — one Terraform, one application-level — that would reduce the
   blast radius of this failure.
```

- [ ] **Step 2: Verify the file against the spec checklist**

Open `aws_bedrock_agent_gw/content/llm-integration.md` and confirm each item:

```
[ ] Section 1 present: "The Two Interaction Paths" with text diagram showing both paths
[ ] Section 2 present: "Path A — Bedrock Agents Reasoning Loop" with 7-step list
[ ] Section 3 present: model selection table with all 7 model rows and correct IDs
[ ] Section 3 present: cross-region profile cheatsheet (4 standard + 4 us. prefixed)
[ ] Section 4 present: "Path B — External LLM as MCP Client" with sequence diagram
[ ] Section 4 present: auth requirements explaining what needs IAM credentials
[ ] Section 5 present: "AgentCore Gateway as Central Integration Point" with architecture diagram
[ ] Section 5 present: Pros table (6 rows)
[ ] Section 5 present: Cons table (5 rows)
[ ] Section 5 present: Best Practices numbered list (8 items)
[ ] Section 6 present: console verification steps + Playground instructions
[ ] Section 7 present: model swap instructions with UNPREPARED caveat
[ ] Section 7 present: complete cross-region profile ID reference block
[ ] Section 8 present: 5 exercise questions
[ ] No "TBD", "TODO", or placeholder text anywhere
[ ] Model IDs match spec exactly (spot check: claude-3-haiku version suffix is -20240307-v1:0)
[ ] Prose budget: file is not significantly longer than other day files (~same density)
```

- [ ] **Step 3: Update the progress ledger**

Open `.superpowers/sdd/progress.md` and append under a new `## LLM Integration Supplement` heading:

```
## LLM Integration Supplement
Plan: aws_bedrock_agent_gw/docs/superpowers/plans/2026-07-17-llm-integration-plan.md
Written: 2026-07-17

- [ ] Task 22: LLM Integration Supplement — content/llm-integration.md
```

Mark Task 22 as `[x]` once Step 2 verification passes.

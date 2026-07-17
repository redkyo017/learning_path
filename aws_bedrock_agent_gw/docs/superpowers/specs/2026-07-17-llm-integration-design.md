# LLM Integration Supplement — Design Spec

**Date:** 2026-07-17
**Status:** Approved

---

## Problem Statement

The existing 5-day curriculum treats the foundation model as a one-line
configuration detail (`foundation_model = "anthropic.claude-3-haiku-..."`).
It never explains:

1. How Bedrock Agents drive the tool-calling reasoning loop with the LLM
2. Which Bedrock models support tool use and how to choose between them
3. How external LLMs (GPT-4, Claude via Anthropic API) can call the same
   Gateway tools as a plain MCP client, without using Bedrock Agents at all
4. Why AgentCore Gateway is architecturally valuable as a central integration
   point, and what the tradeoffs are

---

## Deliverable

One new file: `aws_bedrock_agent_gw/content/llm-integration.md`

No changes to existing day files. No new Go lab. No Terraform module changes.

---

## Content Structure

### Section 1 — The Two Interaction Paths

Text-based architecture diagram showing both paths side by side:

```
Path A — Bedrock-native          Path B — External MCP Client
─────────────────────────        ─────────────────────────────
User Request                     External Application
     │                                    │
Bedrock Agents runtime           MCP Client (SigV4 signed)
     │                                    │
Foundation Model (LLM)           External LLM (GPT-4, Claude API)
     │ "call tool X"                      │ "call tool X"
     ▼                                    ▼
AgentCore Gateway ←─────────────────────────────────────────
     │
Lambda / HTTP tool
     │
Tool Result
     ▼ (both paths)
LLM continues reasoning
```

Establishes upfront: the Gateway is the common denominator. The LLM model
and runtime are interchangeable; the Gateway and tools are stable.

---

### Section 2 — Path A: Bedrock Agents Reasoning Loop

Step-by-step explanation of what happens inside a single agent invocation:

1. Bedrock runtime sends to LLM: system prompt (instruction) + user message + tool list from Gateway `tools/list`
2. LLM returns a "tool use" signal — not an execution, just structured JSON: `{tool: "getEmployee", args: {id: "E001"}}`
3. Bedrock runtime calls Gateway: `tools/call {name: "getEmployee", arguments: {id: "E001"}}`
4. Gateway invokes Lambda; Lambda returns result
5. Bedrock runtime sends result back to LLM as tool output
6. LLM reasons again — may call more tools or emit final response
7. Loop ends when LLM emits text without a tool call

Key distinction: the LLM signals intent; the Bedrock runtime executes. The LLM
never holds credentials or calls Lambda directly.

---

### Section 3 — Bedrock Model Selection

Table covering models available for Bedrock Agents with tool use:

| Model | Bedrock Model ID | Tool Support | Cost Tier | Latency | Best For |
|-------|-----------------|--------------|-----------|---------|---------|
| Claude 3 Haiku | `anthropic.claude-3-haiku-20240307-v1:0` | Full | Low | Fast | Simple routing, high-volume |
| Claude 3 Sonnet | `anthropic.claude-3-sonnet-20240229-v1:0` | Full | Medium | Medium | General production |
| Claude 3.5 Sonnet | `anthropic.claude-3-5-sonnet-20241022-v2:0` | Full (best) | Medium-High | Medium | Complex multi-step reasoning |
| Claude 3 Opus | `anthropic.claude-3-opus-20240229-v1:0` | Full | High | Slow | Highest accuracy, low-volume |
| Amazon Titan Text Premier | `amazon.titan-text-premier-v1:0` | Partial | Low | Fast | Cost-sensitive, AWS-native workloads |
| Llama 3.1 8B | `meta.llama3-1-8b-instruct-v1:0` | Partial | Low | Fast | Open-source requirement, simple tools |
| Llama 3.1 70B | `meta.llama3-1-70b-instruct-v1:0` | Good | Medium | Medium | Open-source with quality requirement |

**Cross-region inference profiles** (recommended for production):
- Prefix `us.` routes the request across multiple AWS regions for capacity and availability
- Standard IDs fail if the chosen region is overloaded; cross-region profiles do not

Cheatsheet:
```
Dev/test:    anthropic.claude-3-haiku-20240307-v1:0
Prod:        us.anthropic.claude-3-5-sonnet-20241022-v2:0
Cost-opt:    us.anthropic.claude-3-haiku-20240307-v1:0
High-stakes: us.anthropic.claude-3-opus-20240229-v1:0
```

---

### Section 4 — Path B: External LLM as MCP Client

Core concept: AgentCore Gateway exposes a standard MCP HTTP endpoint. Any
MCP-compatible client can call it — Bedrock Agents runtime is NOT required.

Sequence:
1. External app discovers tools: HTTP POST to Gateway MCP endpoint → `tools/list` → returns tool schemas
2. External app passes tool schemas to external LLM (GPT-4, Claude via Anthropic API) as function definitions
3. LLM reasons and returns: "call tool X with args Y"
4. External app calls Gateway: `tools/call {name: X, arguments: Y}` — SigV4-signed HTTP request
5. Gateway routes to Lambda, Lambda executes, returns result
6. External app feeds result to LLM, loop continues

**Authentication for external callers:**
- Caller must have IAM credentials with `bedrock-agentcore:InvokeGateway` permission
- All HTTP requests to the Gateway endpoint must be SigV4-signed
- External LLMs themselves never authenticate — only the calling application does

**Enterprise use case:** Your integration team's existing Python/Go services using
GPT-4 today can call your AWS Lambda tools through the same Gateway, without
migrating to Bedrock Agents. Same tools, different driver.

---

### Section 5 — AgentCore Gateway as Central Integration Point

**Architecture role:**

```
┌─────────────────────────────────────────────────────────┐
│              Any LLM (Bedrock or External)               │
│  Claude Haiku  │  Claude Sonnet  │  GPT-4  │  Llama 3   │
└────────────────┬────────────────────────────────────────┘
                 │ MCP protocol (tools/list, tools/call)
                 ▼
┌─────────────────────────────────────────────────────────┐
│              AgentCore Gateway                           │
│  Tool Registry  │  Auth Mediation  │  Observability      │
└────────────────┬────────────────────────────────────────┘
                 │
    ┌────────────┴──────────────┐
    │                           │
Lambda tools           HTTP / REST APIs
```

**Pros:**

| Benefit | Detail |
|---------|--------|
| LLM portability | Swap model (Haiku → Sonnet → GPT-4) without touching any tool code or Lambda |
| Credential centralization | No LLM ever holds API keys; all auth stays in Gateway + Secrets Manager |
| Single observability layer | All tool calls, all models, one CloudWatch + X-Ray view |
| Immediate propagation | Add a tool today; all LLMs and agents see it without redeployment |
| Consistent governance | Guardrails, PII redaction, topic denial applied once at the Gateway — not per-LLM |
| Reuse | One Lambda function serves 10 agents and 3 external LLM integrations simultaneously |

**Cons:**

| Risk | Mitigation |
|------|-----------|
| Single point of failure — Gateway unavailable means all LLMs lose tools | Use cross-region inference profiles; implement circuit-breaker in external callers |
| Latency overhead — extra hop on every tool call (~20–50 ms) | Accept for most workloads; pre-warm Lambda to reduce cold start contribution |
| AWS vendor lock-in — Gateway is AWS-managed; not portable to GCP/Azure equivalent | MCP is an open standard; tools can be re-registered if migrating; mitigates lock-in somewhat |
| External LLM authentication complexity — callers need SigV4 signing | Use IAM roles on EC2/ECS; avoid long-lived access keys |
| Model compatibility gaps — tool descriptions written for Claude may not route correctly on GPT-4 | Test every new tool with the least-capable model you plan to support |

**Best Practices:**

1. **Design for the weakest model you plan to support.** If a tool description works on Claude 3 Haiku, it will work on every model above it. Reverse is not guaranteed.
2. **One Gateway per domain, not per LLM.** Create separate Gateways for HR tools and Finance tools, not separate Gateways for "the Claude agent" and "the GPT-4 app".
3. **Store the Gateway endpoint URL in Parameter Store, not in code.** The endpoint is a deployment artifact; clients should retrieve it at startup.
4. **Use cross-region inference profiles in production.** Suffix your model IDs with `us.` prefix. No downside; significant availability upside.
5. **Version-control OpenAPI specs.** A tool description change is a breaking change for any LLM that has cached or hardcoded the old schema. Treat it like an API contract.
6. **Never create or update tools in the console.** Console changes create state drift; all tool registration must go through Terraform or SDK.
7. **Test each new tool with at least two model families before production.** Claude and GPT-4 parse tool descriptions differently; a description that works perfectly for one may produce wrong parameter extraction with the other.
8. **Tag CloudWatch metrics by model.** When a tool failure spike occurs, you need to know which LLM triggered it. Add `foundation_model` as a custom dimension to your CloudWatch dashboard.

---

### Section 6 — Console: Model Verification and Testing

**After `terraform apply`:** Verify the assigned model matches your tfvars.

Steps:
1. Bedrock console → left nav "Agents" → click agent name (e.g. `bgw-hr-agent`)
2. "Overview" tab → scroll to "Agent details" → confirm "Model" field matches your `foundation_model` variable
3. If mismatch: do NOT change it in console. Fix in `terraform.tfvars` and run `terraform apply` again.

**Bedrock Playground for model testing (testing only, not production):**

1. Open agent in console → "Test" tab → click "Playground"
2. Change the model dropdown to a different model (e.g. from Haiku to Sonnet)
3. Send the same test query — compare tool-routing accuracy and response quality
4. Changes made in Playground are session-only; they do NOT persist to the agent configuration

Use Playground to validate a model change before updating `terraform.tfvars`.

---

### Section 7 — Terraform: Model Management

**The `foundation_model` variable** is the only change needed to swap LLMs.
Bedrock Agents performs an in-place update — it does NOT destroy and recreate
the agent on a model change. Alias and version history are preserved. However,
after the model change the agent returns to `UNPREPARED` status. You must run
`prepare-agent` (or re-run the CI/CD alias promotion pipeline from Day 5)
before the agent can serve requests again.

```hcl
# terraform.tfvars — dev environment
foundation_model = "anthropic.claude-3-haiku-20240307-v1:0"

# terraform.tfvars — prod environment
foundation_model = "us.anthropic.claude-3-5-sonnet-20241022-v2:0"
```

**Model-per-environment pattern using workspace-specific tfvars:**

```
terraform/environments/day05-lab/
  terraform.tfvars              # dev: haiku, cheaper
  terraform.tfvars.prod         # prod: claude-3-5-sonnet, cross-region
```

Apply prod config:
```bash
terraform apply -var-file=terraform.tfvars.prod
```

**Full cross-region profile ID reference:**

```hcl
# Standard (single-region, use for dev only)
"anthropic.claude-3-haiku-20240307-v1:0"
"anthropic.claude-3-sonnet-20240229-v1:0"
"anthropic.claude-3-5-sonnet-20241022-v2:0"
"anthropic.claude-3-opus-20240229-v1:0"

# Cross-region US (recommended for production)
"us.anthropic.claude-3-haiku-20240307-v1:0"
"us.anthropic.claude-3-sonnet-20240229-v1:0"
"us.anthropic.claude-3-5-sonnet-20241022-v2:0"
"us.anthropic.claude-3-opus-20240229-v1:0"
```

The current module has no validation rule on `foundation_model` — any string
is accepted at `terraform apply` time. Invalid model IDs fail at agent
invocation time (Bedrock returns a `ResourceNotFoundException`). A future
improvement would add a validation block to catch this earlier.

---

### Section 8 — Exercise Questions

5 questions covering both paths, model selection, and the central integration
point tradeoffs:

1. **Reasoning loop:** An agent calls a Lambda tool incorrectly — it passes `employeeId: "Alice Smith"` instead of `employeeId: "E001"`. At which layer in the Path A reasoning loop did the failure occur? What is the fix, and in which file?

2. **Model selection:** You are building a high-volume support agent that routes simple HR questions (100,000 requests/month). Your team also needs a quarterly compliance report agent (50 requests/month) that must never hallucinate. Which Bedrock model ID do you assign to each, and why?

3. **Central integration point:** Your organization adds a new ticketing tool to the Gateway. Three existing agents (HR, Finance, IT) and one external Python app using GPT-4 use the same Gateway. What is the earliest all four callers will see the new tool, and what action (if any) must be taken per caller?

4. **External MCP client:** A developer says "we can't use this Gateway from our GPT-4 integration because GPT-4 doesn't have IAM credentials." Explain why this statement reflects a misunderstanding of Path B architecture, and describe what actually needs IAM credentials.

5. **Best practice — single point of failure:** Your production Gateway returns 503 errors for 10 minutes due to a regional AWS incident. Describe two changes — one Terraform, one application design — that would reduce the blast radius of this failure.

---

## Out of Scope

- New Go lab (no compilable program)
- Changes to existing day files (Days 1–5 unchanged)
- Terraform module changes (module already has `foundation_model` variable)
- Coverage of Bedrock Knowledge Bases, RAG patterns, or embeddings

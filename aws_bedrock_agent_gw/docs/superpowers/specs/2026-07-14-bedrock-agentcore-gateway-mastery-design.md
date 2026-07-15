# AWS Bedrock AgentCore Gateway — 4-Day Mastery Plan

**Date:** 2026-07-14 (updated 2026-07-14 — extended to 4 days)
**Owner:** hunghan
**Goal:** Master the AWS Bedrock AgentCore full stack — with Gateway as the primary deep-dive focus — to production-grade proficiency ready for enterprise project use. Covers Gateway, Evaluations, Identity/Policy, Memory, Runtime, and Registry.

---

## Purpose & Success Criteria

"Mastered" means three things simultaneously:
1. **Build** — can design and ship a production-grade Go service that uses AgentCore Gateway to expose enterprise APIs as agent-callable tools, with auth mediation, guardrails, tracing, and rate limiting
2. **Operate** — can architect multi-agent Gateway systems, diagnose failures from traces, make confident design decisions under enterprise constraints (security, compliance, cost)
3. **Validate + govern** — can set up an evaluation pipeline to measure agent quality, enforce fine-grained Policy controls, and integrate Memory and Identity into a full enterprise-grade agentic system

By end of Day 3, the user can rebuild a complete production Gateway + agent integration from scratch, closed-book, in under 2 hours.
By end of Day 4, the user can architect a full AgentCore stack (Gateway + Evaluations + Policy + Memory) and explain how each component fits into an enterprise production system.

---

## What Is AgentCore Gateway

AWS Bedrock AgentCore Gateway is a managed MCP (Model Context Protocol) server. It turns any API — Lambda, HTTP, AWS service — into a centralized registry of agent-callable tools. Agents discover and invoke tools through a single Gateway endpoint without holding downstream credentials.

Key differentiator from raw Bedrock action groups: Gateway is **centralized and API-agnostic**. Multiple agents share the same tool registry. The Gateway mediates authentication to downstream APIs. Tool definitions (OpenAPI schemas) are versioned and independently managed.

### Core components

| Component | Role |
|-----------|------|
| Gateway | Managed MCP server endpoint; hosts the tool registry |
| Tool | A callable unit backed by Lambda, HTTP endpoint, or AWS service |
| OpenAPI schema | Defines the tool interface; description quality directly drives agent reasoning quality |
| Execution role | IAM role the Gateway assumes to call downstream APIs |
| Auth config | Credentials/OAuth the Gateway holds on behalf of agents |
| Guardrails | Content filtering and PII redaction applied to tool inputs/outputs |
| X-Ray tracing | End-to-end trace: agent call → Gateway → downstream API |

### IAM trust chain (3 parties)

```
Caller identity (agent / Lambda / user)
    ↓  (must have bedrock:InvokeAgent + gateway:Invoke permission)
Gateway execution role
    ↓  (trust policy: bedrock.amazonaws.com; permissions: downstream API calls)
Downstream API / Lambda / service
```

Getting any layer wrong produces opaque errors. Understanding all 3 before writing agent code is the highest-leverage day 1 investment.

---

## Enterprise Use Cases

1. **Enterprise API registry** — centralize all internal REST APIs (HR, ticketing, ERP) as agent-callable tools without rewriting them
2. **Secure credential mediation** — agents never hold API keys or OAuth tokens; Gateway holds them and proxies calls
3. **Multi-agent tool sharing** — 10 specialized agents share one Gateway; tool updates propagate automatically
4. **Legacy API wrapping** — expose SOAP/REST legacy systems via OpenAPI spec → Gateway → agent, zero migration
5. **Compliance tool gating** — guardrails on tool outputs enforce PII redaction and content policy before results reach agent reasoning
6. **Audit trail** — X-Ray + CloudTrail gives full traceability of which agent called which tool with what parameters

---

## Approach

SDK-first, IAM-upfront. Zero console creation. Every Gateway, tool, and agent is provisioned via the Go SDK (`aws-sdk-go-v2`). This is the only approach that produces version-controllable, reproducible, production-grade skills.

**What this is not:**
- Console-first (can't reproduce, can't version-control, teaches wrong mental model)
- LangChain/wrapper-first (Python-first ecosystem; wrappers hide the IAM and MCP layer that breaks in production)

---

## Day-by-Day Design

### Day 1 — Gateway Foundations (6–8 hrs)

**Theme:** Understand what Gateway is, set up the IAM trust chain correctly, get one working Gateway-backed tool in Go.

**Daily rhythm:**
1. Primer from SDK docs (30 min)
2. Core build (2.5 hrs)
3. Deliberate failure lab (1 hr)
4. Break (15 min)
5. Extend + integrate (1.5 hrs)
6. Teach-it-back writing (30 min)
7. Journal + save point (20 min)

**Core build:**
- IAM setup: Gateway execution role, resource policy, caller identity — all 3 layers
- Create a Gateway with one Lambda-backed tool via Go SDK
- Call the tool through an agent, end-to-end

**Failure lab:**
- Break IAM at each of the 3 layers deliberately
- Read the exact CloudWatch error for each breakage
- Fix each one

**Extend:**
- Add a second tool backed by an HTTP endpoint (not Lambda)
- Expose both tools via the same Gateway
- Demonstrates Gateway's API-agnostic nature

**Teach-it-back prompt:** "What problem does Gateway solve that raw Lambda action groups don't?"

---

### Day 2 — Gateway Intelligence (6–8 hrs)

**Theme:** OpenAPI-driven tool registration, multi-agent sharing, enterprise auth patterns.

**Core build:**
- Register an existing OpenAPI spec into Gateway (simulate an enterprise REST API)
- Wire an agent to dynamically discover and call tools via the Gateway registry
- This is the real enterprise pattern: you already have APIs, Gateway wraps them without rewriting

**Failure lab:**
- Write a deliberately vague tool description → observe agent misuse → compare X-Ray traces
- Write a precise description → observe improved agent reasoning
- This is the most underestimated variable in production agent reliability

**Extend:**
- Add OAuth/API-key auth to the downstream API
- Configure Gateway to hold the credential — agent never touches it
- Wire a second, different agent to the same Gateway
- Demonstrates the enterprise security model: agents as credential-free callers

**Teach-it-back prompt:** "How to onboard a new enterprise API to the Gateway in under 30 minutes" — a runbook your team could follow.

---

### Day 3 — Production Gateway (6–8 hrs)

**Theme:** Guardrails, observability, rate limiting, versioning — then a closed-book rebuild.

**Core build:**
- Add guardrails: PII redaction on Gateway tool outputs
- Set up X-Ray tracing end-to-end: agent call → Gateway → downstream API
- Add rate limiting / throttling to the Gateway

**Failure lab:**
- Intentionally exceed rate limits → trace the throttle error
- Trigger a PII guardrail → observe redacted output
- Simulate downstream API timeout → observe Gateway error propagation

**Final test (2 hrs, closed-book):**
Design and wire a complete new Gateway + agent from scratch for a realistic enterprise DevOps scenario:
> Agent that checks deployment health via a deployment-pipeline API + creates/queries incident tickets via a ticketing system, all via Gateway, with credentials never in the agent, PII-safe responses, and X-Ray traces.

No notes. If you can do this, you've internalized it.

**Teach-it-back prompt:** "3 Gateway design decisions every enterprise architect needs to make before day 1."

---

### Day 4 — Full AgentCore Stack (6–8 hrs)

**Theme:** Evaluations, Identity/Policy, Memory, Runtime/Registry — close the gap from "Gateway expert" to "full AgentCore stack architect".

**Morning — Evaluations (2.5 hrs)**

AgentCore Evaluations is the quality-gate layer. Without it you can ship but you cannot validate, regression-test, or improve agents systematically. Every enterprise deployment needs this.

- Core build: create an evaluation dataset from real agent interactions; run an evaluation job; interpret scores (response quality, tool-call accuracy, latency)
- Failure lab: deliberately degrade agent quality (weaken tool description), run evaluation, observe the regression signal
- Key insight: evaluations catch the class of errors that neither unit tests nor X-Ray traces catch — *wrong answers that look right*

**Afternoon — Identity + Policy (2.5 hrs)**

AgentCore Identity and Policy operate above the IAM layer. IAM controls who can invoke a resource; Policy controls what an agent is *allowed to decide* at runtime — which tools it may call, under what conditions, with what constraints.

- Core build: set up an AgentCore Policy that restricts a specific agent to a subset of Gateway tools; verify a second agent with broader permissions can call the full tool set
- Extend: agent-to-agent calling with verified identity — one agent delegates a sub-task to another; the callee verifies the caller's identity before accepting
- Key enterprise use case: compliance agents that are policy-restricted from calling any tool that touches PII directly — the policy enforces this regardless of what the LLM decides

**Evening — Memory (1 hr)**

Session memory keeps context within a single conversation turn. Long-term memory persists across sessions — user preferences, prior decisions, workflow state.

- Core build: enable long-term memory on an agent; invoke it twice across two sessions; verify it recalls context from the first session in the second
- Pattern: Memory + Gateway = stateful agent with dynamic tool access — the enterprise pattern for conversational automation
- When to use each: session memory for multi-step reasoning within one task; long-term memory for user-specific agents that personalise over time

**Orientation — Runtime + Registry (30 min, conceptual only)**

- **Runtime:** managed execution environment for agent code — lifecycle management, resource limits, cold start behaviour, cost model. Knowing this affects debugging (why is my agent slow?) and architecture (when to use Runtime vs Lambda).
- **Registry:** centralised catalogue of agents — discovery, versioning, sharing across teams. Enterprise pattern: one team publishes a specialist agent to the Registry; other teams invoke it without maintaining it.
- No hands-on for these two — orientation and architectural placement only.

**Full-stack teach-it-back prompt:** "Draw the full AgentCore architecture for a production enterprise system. Label where Gateway, Evaluations, Policy, Memory, Runtime, and Registry each sit, and explain the data flow through them for one end-to-end agent invocation."

---

## The 7 Mistakes That Waste 80% of Beginners' Time

| # | Mistake | Why it's expensive |
|---|---------|-------------------|
| 1 | Skipping the MCP protocol | Gateway speaks MCP; fighting the abstraction instead of understanding it costs hours |
| 2 | Getting IAM wrong on day 1 | The 3-party trust chain is non-obvious; errors surface late and are hard to diagnose |
| 3 | Writing vague tool descriptions | Agent reasoning quality degrades badly; invisible until production failures |
| 4 | Holding credentials in the agent | Bypasses Gateway's core enterprise value; a security antipattern |
| 5 | Console-created Gateways | Can't version-control, can't reproduce in CI/CD, teaches wrong mental model |
| 6 | Treating Gateway like old action groups | Gateway is a centralized registry; the architecture pattern is fundamentally different |
| 7 | No X-Ray traces from day 1 | Debugging agent tool misuse without traces is nearly impossible |

---

## Tool Schema Best Practices (Gateway-specific)

These are the highest-leverage, least-documented Gateway practices:

- **Description quality is agent reasoning quality.** The OpenAPI `description` field is what the agent reads to decide whether and how to call a tool. Vague descriptions = misuse. Precise descriptions = reliable agents.
- **Atomic tools.** Tools that do one thing are predictably callable. Tools that do multiple things force the agent to guess which behavior to trigger.
- **Explicit error contracts.** Define what the tool returns on failure in the schema. Agents that receive undocumented error shapes hallucinate recovery strategies.
- **Parameter naming matters.** `userId` is unambiguous. `id` forces the agent to infer context. Name parameters for the agent's reading level, not the developer's.

---

## Profile Context

- **Background:** Agent/LLM experience (LangChain, OpenAI API patterns), AWS is fuzzy
- **Language:** Go primary (`aws-sdk-go-v2`), Python secondary
- **Time:** 6–8 hrs/day × 4 days
- **Approach:** SDK-first, IAM-upfront, zero console creation

---

## What's Out of Scope

- Bedrock Knowledge Bases (RAG) — valuable but not part of this plan; add post-plan
- Certification prep — not the goal; production capability is
- Python SDK — Go SDK only; Python examples are not a translation target

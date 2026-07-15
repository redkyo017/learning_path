# Day 3 — Production Gateway

Read this before the Day 3 labs. Budget: 30 minutes.

---

## 1. Bedrock Guardrails

Guardrails are content filters applied to model inputs and outputs (and tool
outputs). They enforce compliance requirements before results reach the agent's
reasoning layer.

**Guardrail types:**

| Type | What it blocks/redacts | When to use |
|------|------------------------|-------------|
| Content filter | Violence, hate, sexual, self-harm content | All production deployments |
| PII redaction | Names, emails, phone numbers, SSN, addresses | Any tool that returns user data |
| Topic denial | Custom topics (e.g. "competitor products") | Brand/legal compliance |
| Word filter | Specific prohibited words | Compliance, profanity filtering |
| Grounding check | Hallucinations in tool-grounded responses | High-stakes outputs |

**Guardrails on tool outputs:**
When a tool returns data containing PII, guardrails redact it BEFORE the agent
reasons over it. This means the agent's reasoning trace is also PII-free —
important for audit logs.

```
Tool returns: {"name":"Alice Smith","email":"alice@example.com","salary":95000}
After PII guardrail: {"name":"[REDACTED]","email":"[REDACTED]","salary":95000}
Agent reasons over redacted version.
```

**IAM for guardrails:**
The entity applying the guardrail (agent or Gateway) must have `bedrock:ApplyGuardrail`
permission. This is already in the `bgw-gateway-execution-permissions.json` from Day 1.

---

## 2. X-Ray Tracing for Agent + Gateway Flows

X-Ray traces an agent invocation as a tree of spans:

```
Agent Invocation [root span]
├── Model invocation (reasoning step 1)
├── Tool call: getEmployee [child span]
│   ├── Gateway processing
│   ├── Lambda invocation [child span]
│   │   └── Lambda execution
│   └── Guardrail application [child span]
├── Model invocation (reasoning step 2)
└── Final response generation
```

**What to look for in traces:**
- **Latency hotspots:** which span takes longest? Lambda cold start? Model reasoning?
- **Tool call frequency:** is the agent calling the same tool multiple times? (Possible
  prompt engineering issue)
- **Guardrail hits:** what percentage of tool responses trigger PII redaction?
- **Error spans:** red spans indicate failures — click through to see the error message

**Enabling tracing:**
- On Bedrock Agents: set `enableTrace: true` in InvokeAgent request
- On Gateway: enabled by default when X-Ray is enabled for the account
- Requires IAM permission: `xray:PutTraceSegments`, `xray:PutTelemetryRecords`

**Key insight:** You cannot debug agent reasoning failures without traces. The agent's
reasoning steps are only visible in the trace — they don't appear in CloudWatch logs.

---

## 3. Rate Limiting and Throttling

**Two throttling layers:**

1. **Bedrock service limits:** requests-per-minute and tokens-per-minute per model,
   per region, per account. These are hard limits. Check current limits:
   `aws bedrock list-foundation-models` (limits shown separately in Service Quotas).

2. **Gateway-level throttling:** you set per-gateway and per-tool limits to protect
   downstream APIs from agent-driven traffic spikes.

**What happens when throttled:**
- Agent receives a `ThrottlingException` from Bedrock
- Agent reasoning loop retries (if retry is configured)
- If retries exhausted: agent returns "I was unable to complete this request due
  to service limits"

**Throttle error diagnosis in traces:**
Look for spans with `ThrottlingException`. The parent span tells you which layer
throttled: Bedrock model? Gateway? Downstream Lambda?

**Circuit breaker pattern:**
For production, configure Gateway to stop calling a downstream API if error rate
exceeds threshold (e.g. >50% failures in 60s). Protects downstream APIs from
cascading agent retry storms.

---

## 4. Production Deployment Checklist

Before going live with a Gateway-backed agent system:

- [ ] All IAM roles use least-privilege (specific ARNs, not `*` resources)
- [ ] Guardrails enabled for PII at minimum on all tools returning user data
- [ ] X-Ray tracing enabled on agents and Gateway
- [ ] CloudWatch alarms on: tool error rate, agent invocation latency P99, throttle rate
- [ ] Gateway throttling configured per-tool to protect downstream APIs
- [ ] All AWS resources tagged with `project`, `environment`, `team`
- [ ] Secrets in Secrets Manager (no credentials in environment variables or code)
- [ ] Bedrock model access requested and approved for the region
- [ ] Cost alert configured (Bedrock costs spike quickly under load)

---

## 5. Exercise Questions

1. An audit team asks: "Show me every employee record that was accessed by AI agents
   this month, with PII removed." What AWS services give you this, and what do you
   query?
2. Your agent is calling the HR tool 6 times per session instead of once. How do
   you diagnose this and what likely caused it?
3. A downstream API is returning errors 80% of the time due to a bug in a new
   deployment. Your agents are retrying aggressively, making the situation worse.
   What Gateway feature prevents this?
4. Why does enabling guardrails on tool OUTPUT matter more than enabling it on
   model OUTPUT for PII compliance?
5. You want to set a CloudWatch alarm that fires when the agent P99 latency exceeds
   5 seconds. Which X-Ray metric do you use?

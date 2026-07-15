# Day 1 — Gateway Fundamentals

Read this before touching any lab code. Budget: 30 minutes.

---

## 1. What is MCP (Model Context Protocol)?

MCP is a protocol that standardises how AI agents discover and call tools.
Think of it as HTTP for agent-tool communication: it defines a request/response
format so any MCP-compatible agent can call any MCP-compatible tool server,
regardless of language or cloud.

**Client/server model:**
- **MCP client** — the agent (calls tools)
- **MCP server** — exposes tools (responds to tool calls)

**Two-phase interaction:**
1. **Discovery** — client calls `tools/list` → server returns a list of tool
   descriptions and their input schemas
2. **Invocation** — client calls `tools/call` with tool name + arguments →
   server executes and returns the result

The discovery phase is what makes Gateway powerful: agents dynamically learn
what tools are available rather than having them hardcoded.

---

## 2. What is AgentCore Gateway?

AgentCore Gateway is a **managed MCP server** hosted by AWS. You:
1. Define tools (backed by Lambda, HTTP endpoints, or AWS services)
2. Register them in a Gateway
3. Point your Bedrock agents at the Gateway endpoint

The Gateway handles:
- **Tool registry** — stores all tool definitions; agents query it at runtime
- **Auth mediation** — holds credentials for downstream APIs; agents never
  see secrets
- **MCP protocol** — translates agent tool calls into actual API invocations
- **Observability** — logs all tool invocations; integrates with X-Ray

**Why Gateway instead of action groups?**

| | Action Groups (old) | AgentCore Gateway (new) |
|---|---|---|
| Scope | Per-agent | Centralized registry |
| Tool updates | Redeploy agent | Update Gateway; all agents see it |
| Auth | Agent holds secrets | Gateway holds secrets |
| Multi-agent | Copy config to each agent | Share one Gateway |
| Protocol | Bedrock-proprietary | MCP (open standard) |

If you have 5 agents that all need to call your HR API, with action groups you
configure that 5 times. With Gateway you configure it once.

---

## 3. The IAM Trust Chain — 3 Parties

This is the most important concept to internalise before writing any code.
Getting any one of these wrong causes opaque errors that waste hours.

```
┌─────────────────────────────────────────────────┐
│  Party 1: Caller Identity                        │
│  (the IAM entity calling the Gateway — could be  │
│   your IAM user, a Lambda role, or an agent)     │
│                                                   │
│  Required permission:                             │
│    bedrock-agentcore:InvokeGateway (verify name) │
└────────────────────┬────────────────────────────┘
                     │ calls Gateway endpoint
                     ▼
┌─────────────────────────────────────────────────┐
│  Party 2: Gateway Execution Role                 │
│  (IAM role the Gateway ASSUMES to call           │
│   downstream APIs on behalf of the agent)        │
│                                                   │
│  Trust policy principal: bedrock.amazonaws.com   │
│  Required permission: lambda:InvokeFunction,     │
│    execute-api:Invoke (for HTTP tools), etc.     │
└────────────────────┬────────────────────────────┘
                     │ invokes
                     ▼
┌─────────────────────────────────────────────────┐
│  Party 3: Downstream API / Lambda                │
│  (the actual tool — Lambda function, REST API)   │
│                                                   │
│  Lambda: resource policy must allow              │
│    lambda:InvokeFunction from the execution role │
└─────────────────────────────────────────────────┘
```

**The failure pattern:** If Party 1 can't call the Gateway → 403 on Gateway
invocation. If Party 2 can't call Lambda → the Gateway gets a 403 calling
Lambda, which surfaces as a tool execution error in the agent response. If
Party 3's Lambda resource policy is wrong → same symptom as Party 2 failure.
They look identical from the agent's perspective. You must inspect CloudWatch
logs at each layer to pinpoint which party failed.

---

## 4. Key Terms

| Term | Definition |
|------|-----------|
| Gateway | The managed MCP server instance |
| Gateway Target | A single tool registered in the Gateway (backed by Lambda or HTTP) |
| Execution Role | IAM role Party 2 — the Gateway assumes this to call tools |
| Inline Agent | A Bedrock agent defined entirely in code, not in the console |
| MCP endpoint | The URL your agent points to for tool discovery and calls |
| Foundation Model (FM) | The LLM powering the agent reasoning (e.g. Claude 3 Sonnet) |

---

## 5. Exercise Questions

Answer these after the day's labs. If you can't answer them without notes,
re-read the relevant section.

1. In the IAM trust chain, which party holds the downstream API credentials?
2. An agent gets a tool execution error but the Lambda function logs show no
   invocation at all. Which IAM layer failed?
3. What is the difference between `tools/list` and `tools/call` in MCP?
4. Why does Gateway make tool updates easier than action groups for a
   10-agent system?
5. What does the trust policy principal `bedrock.amazonaws.com` mean, and
   why does Party 2's role need it?

# Day 2 — Gateway Intelligence

Read this before the Day 2 labs. Budget: 30 minutes.

---

## 1. OpenAPI Schema Quality = Agent Reasoning Quality

The `description` field in your OpenAPI schema is the only information the
agent uses to decide whether and how to call a tool. The agent never reads
your Lambda code. It reads descriptions.

**Bad description (causes misuse):**
```yaml
/employee:
  get:
    summary: Get employee
    description: Returns employee data.
    parameters:
      - name: id
        description: The ID.
```

**Good description (reliable agent behaviour):**
```yaml
/employee/{employeeId}:
  get:
    summary: Look up a single employee by their unique employee ID
    description: >
      Returns the full employee record including name, department, title,
      and email for the employee matching the given ID. Use this when the
      user asks about a specific person and you have their employee ID.
      Do NOT use this for department-level queries — use /department instead.
    parameters:
      - name: employeeId
        in: path
        description: >
          The unique employee identifier, always in format E followed by
          3 digits (e.g. E001, E042). Never a name — only an ID.
        required: true
```

**Rules:**
1. **Describe the tool's purpose and when to use it** — and when NOT to use it
2. **Describe every parameter precisely** — type, format, valid values, what it represents
3. **Describe what the tool returns** — the agent uses this to parse the response
4. **One tool, one job** — a tool that does multiple things forces the agent to guess

---

## 2. Multi-Agent Tool Sharing Patterns

Gateway is a shared resource. Multiple agents can point at the same Gateway.
This is the key enterprise pattern: centralise tool management, not agent management.

**Supervisor + specialist pattern:**
```
Supervisor Agent
├── calls Gateway → HR tool (get employee, list department)
├── calls Gateway → Ticketing tool (create ticket, get ticket status)
└── delegates sub-tasks to:
    ├── HR Specialist Agent (also uses Gateway)
    └── Ticketing Specialist Agent (also uses Gateway)
```

All agents point at the same Gateway endpoint. Tool updates in the Gateway
propagate to all agents immediately — no agent redeployment needed.

**When to use separate Gateways:**
- Different teams own different tool sets with separate SLAs
- Compliance requires strict tool-set isolation between agent classes
- Otherwise: one Gateway per domain (HR tools, Finance tools, etc.)

---

## 3. Auth Mediation Patterns

The agent should NEVER hold credentials. The Gateway holds them and proxies
all authenticated requests. Three patterns, by credential type:

**Pattern A — IAM (for AWS Lambda tools):**
No explicit credential needed. The Gateway's execution role (`bedrock.amazonaws.com`
trust) invokes Lambda via IAM. This is what Day 1 used.

**Pattern B — API Key (for external REST APIs):**
```
Gateway Target Config:
  credentialProvider:
    type: apiKey
    secretArn: arn:aws:secretsmanager:...:bgw-external-api-key
    headerName: X-API-Key
```
The Gateway reads the API key from Secrets Manager and injects it as a header.
The agent sends the request; the key is added transparently.

**Pattern C — OAuth2 Client Credentials (for enterprise SSO-protected APIs):**
```
Gateway Target Config:
  credentialProvider:
    type: oauth2ClientCredentials
    clientId: ...
    clientSecretArn: arn:aws:secretsmanager:...:bgw-oauth-secret
    tokenUrl: https://sso.corp.example.com/oauth/token
    scopes: [hr:read, hr:list]
```
Gateway obtains a token from the OAuth server before each tool call (or uses
a cached token if still valid). Agent never sees the token.

**The invariant:** agents are credential-free callers. If you find yourself
passing API keys or tokens through the agent's prompt or context, that is a
design error.

---

## 4. Dynamic Tool Discovery

Agents can discover what tools are available at runtime rather than having
them statically defined. Gateway supports this via the MCP `tools/list`
protocol call.

Static wiring: you tell the agent "these are your tools" at creation time.
Dynamic discovery: the agent calls `tools/list` on the Gateway at the start
of each session and builds its tool inventory on the fly.

Dynamic discovery means you can add a new tool to the Gateway today and
existing agents start using it tomorrow — without any agent config change.
This is the preferred enterprise pattern.

---

## 5. Exercise Questions

1. An agent is supposed to use the HR tool but keeps using the ticketing
   tool to look up employees. What is the most likely root cause?
2. Your company adds a new PTO balance API. You want all 8 existing agents
   to be able to call it by end of day, without redeploying any agent. What
   do you do?
3. What is the difference between Pattern B and Pattern C auth mediation?
   When would you choose C over B?
4. Why is dynamic tool discovery the preferred enterprise pattern over
   static tool wiring?
5. A tool description says "Returns employee data." An agent calls it with
   `employeeId: "Alice Smith"` instead of `employeeId: "E001"`. What do
   you fix and where?

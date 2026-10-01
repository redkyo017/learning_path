# Day 24 Lab — Diagrams

## 1. AgentCore Credential Vending Cycle

```mermaid
sequenceDiagram
    participant Agent as AI Agent
    participant AC as AgentCore
    participant STS as AWS STS
    participant BackendAPI as Backend API<br/>(DynamoDB, Payment API)
    participant CloudTrail as CloudTrail

    Agent->>AC: Request session + roleARN
    AC->>STS: sts:AssumeRole(roleARN, sessionTags={agentId,userId,sessionId})
    STS->>AC: Return {AccessKeyId, SecretAccessKey, SessionToken}
    AC->>Agent: Vend credentials (TTL: 15min)

    Agent->>BackendAPI: API call (SigV4 signed with credentials)
    Note over BackendAPI: Verify SigV4 signature using public key
    BackendAPI->>CloudTrail: Log API call with session tags
    CloudTrail->>CloudTrail: Entry includes: {agentId, userId, sessionId}
    BackendAPI->>Agent: Response (X-AgentCore-Caller-Identity header included)

    Note over Agent: Credentials expire after 15 minutes
    Agent->>AC: Request new credentials
    AC->>STS: sts:AssumeRole(roleARN, sessionTags={...})
    STS->>AC: Return new credentials
```

**Key points:**
- Each cycle generates new temporary credentials
- Session tags are metadata on every CloudTrail entry
- SigV4 signature prevents replay after credential expiry
- X-AgentCore-Caller-Identity header allows backend to trust agent identity

## 2. IAM Policy Conditions with Session Tags

```mermaid
flowchart TD
    A["Agent makes API call<br/>(SigV4 signed)"] -->|"CloudTrail records"| B["Entry includes<br/>aws:PrincipalTag/agentId=payment-orchestrator"]
    B --> C{"IAM policy<br/>condition check:<br/>aws:PrincipalTag/agentId<br/>== payment-orchestrator?"}
    C -->|"Yes"| D["Permission ALLOW<br/>dynamodb:GetItem on customer-accounts"]
    C -->|"No"| E["Permission DENY<br/>Resource is inaccessible"]

    F["Agent with agentId=fraud-checker<br/>tries same API call"] -->|"Different tag value"| C
    C -->|"No"| E

    style D fill:#90EE90
    style E fill:#FFB6C6
```

**Key points:**
- Session tags in IAM conditions enable fine-grained RBAC
- Different agents have different `agentId` tags
- Same role can be used with different tags for different agents
- Conditions prevent agent A from impersonating agent B

## 3. Credential Blast Radius: TTL Comparison

```mermaid
timeline
    title Credential Leak Blast Radius: AgentCore vs Static Key
    
    section Static IAM Key
        T0: Key created (no expiry)
        T0-T90d: Key valid for ~90 days in many deployments
        T90d: Key manually rotated (if discovered)
        T0-T90d: ⚠️ Large window for attacker to use leaked key

    section AgentCore Temp Credentials
        T0: Credentials issued (TTL: 15min)
        T0-T15min: Credentials valid
        T15min: Credentials auto-expire
        T15min+1s: ❌ Credentials useless; auto-revocation
        T0-T15min: ✅ Narrow window for attacker to use leaked credentials

```

**Key points:**
- Static keys are valid for weeks/months (large blast radius)
- Temporary credentials expire automatically (small blast radius)
- No manual rotation needed with automatic re-vending
- Breach impact is time-limited to credential TTL

## 4. Trust Policy: AgentCore vs Static User

```mermaid
graph TD
    A["Identity Model"] --> B["Static IAM User"]
    A --> C["AgentCore + STS + Session Tags"]

    B --> B1["Problem: Long-lived credentials"]
    B --> B2["Problem: No session isolation"]
    B --> B3["Problem: Shared principal across calls"]

    C --> C1["✅ Short-lived credentials<br/>15-min TTL"]
    C --> C2["✅ Per-session isolation<br/>Different sessionId each time"]
    C --> C3["✅ Auditable tags<br/>agentId, userId, sessionId"]

    B1 --> E["Risk: Leak window weeks/months"]
    B2 --> E
    B3 --> E

    C1 --> F["Safe: Leak window 15 minutes"]
    C2 --> F
    C3 --> F

    style E fill:#FFB6C6
    style F fill:#90EE90
```

**Key points:**
- Static users have long-lived keys (insecure for agents)
- AgentCore vends temporary credentials per-session (secure)
- Session tags enable full audit trail
- Blast radius is limited by credential TTL

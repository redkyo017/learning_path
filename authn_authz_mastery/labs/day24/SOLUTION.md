# Day 24 Lab — Solution

## Overview

This solution demonstrates a complete IAM role design for an orchestrator agent deployed via AWS AgentCore. Key features:

1. **Trust Policy:** Restricts assumption to AgentCore only
2. **Permission Policy:** Grants role-specific permissions with session tag conditions
3. **Session Tags:** Enable per-agent, per-user, per-session audit trail
4. **Credential Vending:** Temporary credentials with 15-minute TTL auto-expire

## Key Design Decisions

### 1. Trust Policy: Why External ID?

```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::<account>:root"
  },
  "Action": "sts:AssumeRole",
  "Condition": {
    "StringEquals": {
      "sts:ExternalId": "<external-id>"
    }
  }
}
```

The **external ID** prevents confused deputy attacks. Without it:
- Attacker in a different AWS account can assume this role (if they somehow know the role ARN)

With it:
- Attacker must also know the external ID (kept secret, not in logs or code)
- Only AgentCore deployment with the correct external ID can assume the role

This is a standard AWS security practice for cross-account role assumption.

### 2. Permission Policy: Session Tag Conditions

```json
{
  "Sid": "DynamoDBReadCustomerAccounts",
  "Effect": "Allow",
  "Action": ["dynamodb:GetItem", "dynamodb:Query"],
  "Resource": "arn:aws:dynamodb:...:table/CustomerAccounts",
  "Condition": {
    "StringEquals": {
      "aws:PrincipalTag/agentId": "payment-orchestrator"
    }
  }
}
```

Why session tag conditions?

- **Without:** Any agent using this role can access CustomerAccounts
- **With:** Only the `payment-orchestrator` agent can access CustomerAccounts

Benefits:
- Multiple agent types can reuse the same role (cost savings)
- Each agent type is confined to its intended permissions
- Fine-grained audit trail (agentId is recorded in CloudTrail)
- Per-agent revocation (disable one agent without affecting others)

### 3. Credential Vending Lifecycle

```
Time T0:
  Agent requests credentials from AgentCore
  AgentCore: sts:AssumeRole(roleARN, sessionTags={agentId, userId, sessionId})
  STS validates trust policy → OK
  STS validates session tags (required by SCP) → OK
  STS vends: {AccessKeyId, SecretAccessKey, SessionToken, Expiration: T0+900s}
  Agent receives credentials

Time T0 to T0+900s (15 minutes):
  Agent uses credentials to sign SigV4 requests
  Every request goes to backend via AgentCore gateway
  AgentCore validates signature
  AgentCore adds X-AgentCore-Caller-Identity header
  CloudTrail records: tags={agentId, userId, sessionId}
  Signature includes timestamp, preventing replay after expiration

Time T0+900s:
  Credentials auto-expire
  Further requests fail authentication

Time T0+901s onwards:
  Agent requests new credentials
  Cycle repeats
```

### 4. Why NOT Static IAM User?

**Static User Model:**
```json
{
  "UserName": "payment-orchestrator-user",
  "AccessKey": "AKIA...",
  "SecretKey": "..."
}
```

Problems:
1. **Long-lived credentials** — access key never expires (unless manually rotated)
2. **No session isolation** — every call appears as the same principal
3. **Manual rotation burden** — requires key rotation processes
4. **Leak blast radius** — leaked key is valid until manually revoked (days/weeks)
5. **No user context** — audit log shows only the user, not which end-user session triggered the call

**AgentCore Model:**
```json
{
  "RoleARN": "arn:aws:iam::...:role/PaymentOrchestratorAgentRole",
  "SessionTags": {"agentId": "...", "userId": "...", "sessionId": "..."},
  "CredentialTTL": 900
}
```

Benefits:
1. **Automatic credential rotation** — new credentials every 15 minutes
2. **Per-session isolation** — each session is tagged and auditable
3. **No rotation burden** — AgentCore handles re-vending
4. **Leak blast radius** — 15 minutes, then auto-expiration
5. **Full user context** — agentId, userId, sessionId in CloudTrail

### 5. Audit Compliance Checklist

**Can you answer these questions?**

- ✅ "Which user authorized this payment?" → Check CloudTrail `tags.userId`
- ✅ "Which agent made the call?" → Check CloudTrail `tags.agentId`
- ✅ "When was this call made?" → Check CloudTrail `eventTime`
- ✅ "Which session originated this call?" → Check CloudTrail `tags.sessionId` (link to agent session logs)
- ✅ "How long were these credentials valid?" → 15 minutes (credential TTL)
- ✅ "Can I revoke this specific agent's access?" → Yes (remove AgentCore's permission to assume role)
- ✅ "Can I revoke this specific user's authorization?" → Yes (revoke user's IS 7.3 session, which stops AgentCore from re-vending credentials for that userId)

This design satisfies banking audit compliance requirements.

### 6. Session Tag Enforcement (SCP Level)

While the role policy includes defensive denies for missing tags, the real enforcement happens at the Organization level via Service Control Policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "RequireAgentSessionTags",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::*:role/*AgentRole*",
      "Condition": {
        "StringNotLike": {
          "sts:TransitiveTagKeys": ["agentId", "userId", "sessionId"]
        }
      }
    }
  ]
}
```

**Why SCP?**
- Enforced at the organization boundary
- Cannot be overridden by individual role policies
- Applies to all role assumptions organization-wide
- Prevents bypassing by editing individual role policies

## Common Implementation Mistakes

### Mistake 1: Reusing same role without session tags

```json
// ❌ WRONG
{
  "Effect": "Allow",
  "Action": "dynamodb:*",
  "Resource": "*"
  // NO condition on agentId
}
```

Problem: Any agent using this role can access any DynamoDB table.

**Fix:**
```json
// ✅ CORRECT
{
  "Effect": "Allow",
  "Action": "dynamodb:GetItem",
  "Resource": "arn:aws:dynamodb:...:table/CustomerAccounts",
  "Condition": {
    "StringEquals": {
      "aws:PrincipalTag/agentId": "payment-orchestrator"
    }
  }
}
```

### Mistake 2: Forgetting userId tag requirement

```json
// ❌ WRONG
// Session tags only: {agentId, sessionId}
// Missing: userId
```

Problem: Audit log cannot trace which user's session triggered the call.

**Fix:**
```json
// ✅ CORRECT
// Session tags: {agentId, userId, sessionId}
// Enforce in SCP that userId is always present
```

### Mistake 3: Long credential TTL

```bash
# ❌ WRONG
export AWS_ROLE_TTL=3600  # 1 hour
```

Problem: Leaked credential is usable for 1 hour.

**Fix:**
```bash
# ✅ CORRECT
# AgentCore defaults to 900 seconds (15 minutes)
# Shorter TTL = smaller blast radius
# Re-vending is automatic, so no operational burden
```

## Assessment: Verify Your Understanding

**Q1: Why does AgentCore use session tags?**

A: Session tags (`agentId`, `userId`, `sessionId`) are metadata attached to temporary credentials. They appear in every CloudTrail entry and enable:
- Per-agent audit trail (which agent made the call?)
- Per-user audit trail (which user's session authorized it?)
- Per-session correlation (link CloudTrail to agent logs via sessionId)
- Fine-grained RBAC (IAM conditions restrict based on tag values)

**Q2: What happens if an agent is compromised?**

A: 
- Short-term: Attacker has 15 minutes to use the stolen credentials
- Medium-term: AgentCore can revoke its permission to assume the role (deny sts:AssumeRole for this role)
- Long-term: User revokes their IS 7.3 session, which stops AgentCore from obtaining credentials for that userId

**Q3: How does X-AgentCore-Caller-Identity help backend APIs?**

A: Instead of re-validating IAM, backend APIs trust the caller_identity header (added by AgentCore after SigV4 validation). They use it for:
- Authz decisions (scope data to userId)
- Agent-specific policy enforcement (agent-specific rate limits, audit rules)
- Audit log enrichment (correlate with AgentCore sessionId)

**Q4: How is this design compliant with banking audit requirements?**

A:
- Every API call is linked to a specific user (sub-claim)
- Every API call is linked to a specific agent (act claim analog in CloudTrail tags)
- Revocation propagates when user session ends
- Audit trail is immutable (CloudTrail)
- Per-session isolation enables compliance for per-user consent and revocation

## Files to Review

- `config/agentcore_iam_role.json` — Complete annotated IAM role with trust + permission policies
- `diagram.md` — Visual representation of credential vending cycle and session tag conditions
- Day 24 content: `content/day24.md` — Full technical deep-dive on AgentCore architecture

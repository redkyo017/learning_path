# Day 24 — AWS AgentCore Gateway Architecture

## Why this matters

A bank deploys an AI agent using Amazon Bedrock. Without AgentCore, the team gives the agent a static IAM access key stored in the deployment environment. The key is leaked via a misconfigured S3 bucket policy. With full IAM access, the attacker can read customer data from DynamoDB. AgentCore fixes this by vending per-request short-lived credentials tied to a scoped IAM role with session tags — a leaked credential is useless after seconds.

## Core concepts

### AgentCore Gateway identity model

Each agent type (orchestrator, tool) gets a dedicated IAM role; no shared service accounts. This follows the principle of least privilege at the identity layer — an orchestrator agent never has access to tool-scoped permissions, and vice versa.

### `sts:AssumeRole` with session tags

When an agent starts, AgentCore calls `sts:AssumeRole` to vend temporary credentials. The role assumption includes session tags:
- `agentId`: identifies the agent type or instance (e.g., `payment-orchestrator`, `fraud-checker-tool`)
- `userId`: the user on whose behalf the agent is acting (from the session context)
- `sessionId`: unique identifier for this agent session

These tags become metadata on every AWS API call made by the agent (visible in CloudTrail). A backend API can enforce access control based on these tags via IAM conditions like `"aws:PrincipalTag/agentId": "payment-orchestrator"`.

### SigV4 signing

Every request to an AgentCore-protected API is signed with temporary IAM credentials using AWS Signature Version 4. The SigV4 signature includes:
- Request body hash (prevents body tampering)
- Timestamp (prevents replay beyond credential TTL, typically 15 minutes)
- Service scope (e.g., `sts`, `s3`)

Replay attacks are prevented by the credential TTL — a stolen request cannot be replayed after the credentials expire.

### Credential vending lifecycle

1. Agent starts → AgentCore receives request
2. AgentCore calls `sts:AssumeRole` with the agent's target IAM role ARN + session tags
3. AWS STS vends temporary credentials: `AccessKeyId`, `SecretAccessKey`, `SessionToken`
4. AgentCore returns credentials to the agent
5. Agent uses these credentials to sign all subsequent requests (SigV4)
6. Credentials expire (typically 15 minutes)
7. Agent requests new credentials → cycle repeats

### AgentCore's trust model

AgentCore acts as an identity-aware proxy. Only requests from registered agents (identified by `agentId`) with valid SigV4 signatures are forwarded to backend APIs. Requests with missing, invalid, or expired signatures are rejected at the gateway. This ensures:
- Unauthenticated requests never reach the backend
- Backend APIs can trust the SigV4 signature (no need to re-verify AWS IAM)
- The gateway is the single point of control for agent identity

### `caller_identity` header

After validating an agent's SigV4 signature, AgentCore adds a `X-AgentCore-Caller-Identity` HTTP header to the forwarded request:

```json
{
  "agentId": "<agent-type>",
  "userId": "<session-user>",
  "sessionId": "<session-id>"
}
```

Backend APIs use this header for authorization decisions (e.g., "scope data access to userId") and audit logging. The API trusts this header because it's added by AgentCore (not by the agent itself) and the request already passed SigV4 validation.

## WSO2 IS 7.3 / AgentCore mapping

### IAM trust policy

Restricts assumption of the agent role to AgentCore's service principal. Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<PLACEHOLDER: agentcore-account-id>:root"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "<PLACEHOLDER: agentcore-external-id>"
        }
      }
    }
  ]
}
```

The `ExternalId` prevents confused deputy attacks — AgentCore must know the correct external ID to assume the role.

### IAM permission policy

Grants only the permissions needed by that agent type. Example for a payment orchestrator:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "dynamodb:GetItem",
        "dynamodb:Query"
      ],
      "Resource": [
        "arn:aws:s3:::payment-data-bucket/customer-records/*",
        "arn:aws:dynamodb:*:*:table/CustomerAccounts"
      ],
      "Condition": {
        "StringEquals": {
          "aws:PrincipalTag/agentId": "payment-orchestrator"
        }
      }
    }
  ]
}
```

Note the condition: even if the orchestrator role is assumed by a different agent type with a different `agentId` tag, this permission is denied.

### Session tag conditions

Service Control Policies (SCPs) can enforce that all role assumptions include required tags. Example:

```json
{
  "Effect": "Deny",
  "Action": "sts:AssumeRole",
  "Resource": "arn:aws:iam::*:role/AgentRole*",
  "Condition": {
    "StringNotLike": {
      "sts:TransitiveTagKeys": ["userId", "agentId", "sessionId"]
    }
  }
}
```

This denies any `sts:AssumeRole` for agent roles that does not include these three tags.

### AgentCore config

AgentCore is configured with:
- IAM role ARN per agent type (e.g., `arn:aws:iam::<account>:role/PaymentOrchestratorRole`)
- Mapping of session tag values: `userId` from the user's IS 7.3 subject claim, `agentId` from the agent's registration, `sessionId` generated per session

Day 25 covers how AgentCore bridges `userId` from IS 7.3 to the session tag.

## Anti-patterns

### 1. Shared IAM role for all agent instances

**Problem:** If one agent instance is compromised, all instances of the same type are compromised. No per-instance revocation.

**Example:**
```json
{
  "Role": "arn:aws:iam::123456789012:role/SharedAgentRole",
  "PermissionPolicy": {
    "Effect": "Allow",
    "Action": "dynamodb:*",
    "Resource": "*"
  }
}
```

An attacker who compromises any payment orchestrator instance can now read and modify all DynamoDB tables — they inherited the role's full permissions.

**Fix:** Create a separate IAM role per agent instance or per agent deployment, with tightly scoped permissions. Use session tags to enable fine-grained RBAC on top of IAM policies.

### 2. Not including `userId` as a session tag

**Problem:** The audit log shows only `agentId`. Impossible to trace which user's session triggered a specific API call.

**Scenario:** A fraud detection agent makes a payment API call. The CloudTrail entry shows `agentId=fraud-detector`, but the compliance officer needs to know: "Which user was this call made on behalf of?" Without `userId` in the session tag, the answer is not in the audit trail.

**Fix:** Include `userId` as a mandatory session tag in every `sts:AssumeRole` call.

### 3. Long-lived IAM credentials for agents

**Problem:** Credential TTL > 15 minutes increases the blast radius of a leak. A stolen static IAM access key or a credential that hasn't been refreshed can be used for extended periods.

**Anti-pattern:**
```bash
# DO NOT DO THIS
export AWS_ACCESS_KEY_ID="AKIA..."  # Static key in the agent image
export AWS_SECRET_ACCESS_KEY="..."  # Never rotated
```

**Fix:** AgentCore vends short-lived temporary credentials (15 minutes) via `sts:AssumeRole`. When credentials expire, the agent requests new ones. If a credential is leaked, it's useless after 15 minutes.

## Exercises

### Exercise 1: Why AgentCore uses `sts:AssumeRole` with session tags

**Hint:** Think about credential rotation, per-session isolation, and audit trail.

**Question:** Why does AgentCore use `sts:AssumeRole` with session tags rather than a fixed IAM user for each agent?

**Solution sketch:**

`sts:AssumeRole` vends temporary credentials (15-minute TTL) — a leaked credential expires automatically with no manual rotation. Session tags (`agentId`, `userId`, `sessionId`) make every CloudTrail entry traceable to the specific agent instance and user session.

A fixed IAM user has long-lived credentials (risk of leak) and no per-session isolation (can't revoke one session without revoking the user). The compromise window is measured in hours or days, not minutes.

### Exercise 2: IAM condition for agent-specific API access

**Hint:** Session tags are available as `aws:PrincipalTag/<tagKey>` in IAM conditions.

**Question:** An engineer wants to allow only the `payment-orchestrator` AgentCore agent to call the `PaymentService` API. Write the IAM condition that enforces this.

**Solution sketch:**

In the permission policy for PaymentService:

```json
{
  "Effect": "Allow",
  "Action": "execute-api:Invoke",
  "Resource": "arn:aws:execute-api:*:*:*/Prod/POST/payments/initiate",
  "Condition": {
    "StringEquals": {
      "aws:PrincipalTag/agentId": "payment-orchestrator"
    }
  }
}
```

This ensures that only STS sessions tagged with `agentId=payment-orchestrator` can call the API. Other agents using the same role but a different `agentId` tag are blocked.

### Exercise 3: Using the `X-AgentCore-Caller-Identity` header

**Hint:** The API doesn't need to re-validate IAM — AgentCore did that. The API uses the header for authz and audit.

**Question:** A backend API receives an AgentCore-forwarded request with the `X-AgentCore-Caller-Identity` header. What information does this header contain, and how should the API use it?

**Solution sketch:**

The header contains (as JSON):
```json
{
  "agentId": "payment-orchestrator",
  "userId": "user-123",
  "sessionId": "sess-abc-def"
}
```

The API uses:
- `userId` to scope data access to that user's records (e.g., "fetch only transactions for user-123")
- `agentId` to enforce agent-specific authorization policies (e.g., "payment-orchestrator can only initiate payments, not cancel them")
- `sessionId` for audit log correlation (link this payment API transaction to the AgentCore session and CloudTrail)

The API trusts this header because it's added by the AgentCore gateway — not by the agent itself — and the request already passed SigV4 validation at the gateway.

## Lab

See `labs/day24/README.md` — design a scoped IAM role for an orchestrator agent with session tag conditions and permission policies. Success signal: understand why AgentCore uses temporary credentials instead of static keys, and how session tags enable auditability.

# Day 21 Lab — Agent Identity Comparison Table

Complete this table by analyzing the three approaches: `client_credentials`, Impersonation (raw token pass-through), and OBO (RFC 8693 token exchange).

| Dimension | `client_credentials` | Impersonation (Raw Token) | OBO (RFC 8693) |
|-----------|----------------------|---------------------------|----------------|
| **Audit Trail — What does `sub` record?** | `sub`=client_id (service account). No user context. Cannot answer "which user authorized?" | `sub`=user (from passed token). But `azp` (authorized party) still shows user, not agent. Agent is invisible in audit log. | `sub`=user (preserved). `act`=agent_id (nested per hop). Full chain visible: user → agent1 → agent2. |
| **Scope Control — min/max** | MAX: agent inherits full service account scope. No narrowing possible. If the client is compromised, full scope is exposed. | MAX: agent receives user's full scope. Tool that only needs `read` gets `read+write`. | MIN: per-exchange scope narrowing. Tool requests only `payments:initiate`. IS 7.3 enforces scope ⊆ subject_token scope. |
| **Revocation Granularity** | Revoke service account → revoke all agent instances. Cannot revoke one session without affecting all. | Revoke user token → affects all agents. But revocation is not recorded in audit log (agent was invisible). | Revoke user token → all derived agent tokens revoked via introspection. Granular: different users' tokens independent. |
| **Confused Deputy Risk** | LOW risk but for wrong reason: agent has no user context, so no deputy confusion. But also no user authorization recorded. | HIGH: agent inherited full user scope. Prompt-injected agent can act on behalf of any user it has a token for, with their full authority. | LOW: `act.sub` identifies agent, `sub` identifies user. IS 7.3 can enforce actor trust policy: only pre-authorized agents allowed. Scope narrowing limits blast radius. |
| **Regulatory Compliance (Banking)** | FAIL: cannot prove user authorized the transaction. Service account tokens excluded from consent/revocation framework. | FAIL: agent is not an auditable principal. Audit log shows only user actions, not agent decomposition. Cannot distinguish agent-initiated vs. user-initiated. | PASS: every call traces to user + full agent chain. Fits into consent + revocation framework. Agents are first-class principals. Token `jti` enables transaction-level audit correlation. |
| **Token Lifetime Strategy** | N/A: service accounts typically use long-lived credentials or refresh tokens. High compromise window. | N/A: user token lifetime (1h+). Agent inherits this. If compromised, attacker has user-level access for up to 1h. | SHORT at each hop: human=1h, orchestrator=15min, tool=5min. Compromise window reduces at each hop. |

## Analysis Prompts

1. **Why does `client_credentials` fail for agent identity in a banking context?**
   
   _Answer space:_ The audit log cannot answer "which user authorized this payment?" because the token has no user context — only the service account. Banking regulators (PSD2, open banking) require proof that the human user consented. A service account token is not proof of human authorization.

2. **Why is impersonation (raw token pass-through) dangerous even though it preserves the user's identity in the token?**

   _Answer space:_ The agent is invisible in the audit log. All API calls appear as direct user actions, erasing the agent's involvement. If a compromised agent leaks data or makes unauthorized calls, the audit trail shows only the user — the bank cannot determine if the user or the agent was at fault. Also, the agent inherits the user's full scope — a prompt-injected agent can do anything the user can.

3. **How does OBO (RFC 8693) solve both the audit trail and scope control problems?**

   _Answer space:_ OBO creates a verifiable delegation chain by exchanging the user's token for a new token with the same `sub` (user) but a new `act` claim (agent). Each exchange produces a new token with narrowed scope. The `act` claim records which agent made the call; the `sub` claim records which user authorized it. IS 7.3's actor trust policy prevents unauthorized agents from exchanging. Scope narrowing ensures each agent gets only the permissions it needs.

## Self-Check

- [ ] I can explain why `client_credentials` is not suitable for agent identity
- [ ] I can explain the audit trail difference between impersonation and OBO
- [ ] I can design a scope narrowing strategy for a multi-hop agent chain
- [ ] I understand the actor trust policy requirement in IS 7.3
- [ ] I can justify token lifetime choices for each hop

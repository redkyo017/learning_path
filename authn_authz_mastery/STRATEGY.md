# AuthN/AuthZ Mastery — Strategy

## The Unconventional Approach

Most engineers learn identity protocols by reading RFCs in isolation, accumulating a list of
features. This course flips the order: every protocol is introduced through the failure mode
or attack it was designed to prevent.

You learn PAR because you first understand front-channel authorization request leakage.
You learn DPoP because you understand bearer token theft at the TLS termination proxy.
You learn CIBA because you understand why redirect-based flows break headless banking servers.

This anchors the "why" before the "how" — the config details become obvious once the threat is clear.

## The Master Key for AI Agents

RFC 8693 (Token Exchange / OBO) is the single pattern that unlocks every AI agent auth problem.
Every agent identity challenge — AgentCore delegation, MCP tool auth, cross-service agent calls —
is a specialization of the token exchange primitive. Phase 3 of this course radiates outward from
Day 23 (OBO) rather than introducing each pattern independently.

## The Six Mistakes That Waste 80% of Your Time

1. **Treating FAPI 2.0 as a checklist** — it's a coherent threat model. Understand the threat first.
2. **Configuring CIBA without understanding poll vs. push** — silent failures in mobile banking flows.
3. **Using `client_credentials` for agent identity** — agents need OBO (delegated user context), not service account tokens.
4. **Building MCP tool auth with API keys** — breaks auditability and revocation.
5. **Skipping `actor` and `may_act` claims in OBO** — breaks downstream trust chain verification.
6. **Treating IS 7.3 B2B org management as multi-tenancy** — misses the federated IdP-per-org model banking partners require.

## Phase Strategy

- **Phase 1 (Days 1–10):** Master the protocols as threat-model → mechanics → composition.
  By Day 10 you can draw the full FAPI 2.0 composite banking auth flow without notes.
- **Phase 2 (Days 11–20):** Map every Phase 1 protocol to its IS 7.3 config. Zero new theory —
  only implementation depth.
- **Phase 3 (Days 21–30):** AI agent identity, built on OBO as the master primitive.
  The capstone (Days 29–30) forces you to make real architectural decisions.

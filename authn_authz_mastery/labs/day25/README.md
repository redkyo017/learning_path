# Day 25 Lab — AgentCore + OBO Patterns

## Overview

In this lab, you will trace a complete AgentCore → IS 7.3 → Payment API flow. You'll learn how AWS OIDC federation bridges IAM identity with OAuth2 token exchange, enabling agents to call OAuth2-protected APIs with full user context and agent identity.

## Success Signal

You can:
- Explain the 8-step flow from user authentication to payment API call
- Understand how IS 7.3 validates AWS OIDC tokens (actor_token) via external IdP configuration
- Design an actor trust policy to restrict which agents can exchange tokens
- Trace how `sub` (user) and `act` (agent) claims are preserved and nested through the chain

## Task

You are architecting identity for a banking system. An orchestrator agent deployed via AgentCore needs to call a payment API protected by IS 7.3 OAuth2. Design:

1. IS 7.3 external IdP configuration for AWS OIDC registration
2. A token exchange request from the agent (with user token + OIDC token)
3. The IS 7.3 exchange result showing `sub` and `act` claims
4. An actor trust policy that restricts which agents can exchange tokens
5. Payment API introspection to validate the exchange token

## Key Concepts

- **Trust Federation:** IS 7.3 registers AWS OIDC as an external IdP to validate OIDC tokens from agents
- **Actor Token:** AgentCore's OIDC identity token, signed by AWS, proves the agent's identity
- **Subject Token:** The user's IS 7.3 access token being delegated
- **Exchange Result:** New token with `sub=user`, `act.sub=agent`, narrowed scope
- **Actor Trust Policy:** Configures which agents can exchange tokens for which users

## Steps

1. **Read** `config/agentcore_obo_token_exchange.http` — the complete 8-step flow
2. **Understand** each step: external IdP registration, token exchange request, exchange result
3. **Identify** the trust validation points: `aud` claim check, signature verification, actor trust policy
4. **Trace** how `sub` and `act` claims flow through the chain
5. **Verify** that the exchange result has narrowed scope compared to the subject_token
6. **Review** the SOLUTION.md to check your understanding

## Expected Deliverable

A completed `agentcore_obo_token_exchange.http` file with:
- IS 7.3 external IdP registration request (AWS OIDC setup)
- Token exchange request showing all required parameters
- Exchange result JWT decoded (showing `sub`, `act`, `scope`)
- Payment API call with the exchange token
- IS 7.3 introspection response showing the token is active

## Assessment Questions

1. Why must IS 7.3 validate the `aud` claim in the actor_token?
2. What happens if an actor trust policy is not configured in IS 7.3?
3. How does the 15-minute orchestrator token lifetime differ from the subject (user) token lifetime, and why?
4. How does payment API introspection validate that the chain of delegation is correct?
5. Design a scenario where revoking the user's IS 7.3 session invalidates active agent tokens via introspection.

## References

- Day 23: RFC 8693 token exchange (master pattern — do not re-explain)
- Day 24: AgentCore STS AssumeRole + session tags
- Day 25 content: Full AgentCore + IS 7.3 trust federation model

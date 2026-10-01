# Day 24 Lab — AWS AgentCore Gateway Architecture

## Overview

In this lab, you will design a scoped IAM role for an orchestrator agent deployed via AWS AgentCore. You'll learn how session tags enable fine-grained access control and audit trail correlation.

## Success Signal

You can:
- Explain why AgentCore uses temporary credentials instead of static IAM access keys
- Design an IAM trust policy that restricts role assumption to AgentCore only
- Write an IAM permission policy with session tag conditions to enforce agent-specific access
- Understand how `X-AgentCore-Caller-Identity` header bridges IAM and application-level authz

## Task

You are architecting identity for a banking system. An AI orchestrator agent needs to:
1. Read customer account data from DynamoDB
2. Call a payment initiation API via AgentCore
3. Write audit logs to CloudWatch

Design:
1. An IAM role for the orchestrator agent with trust policy (restricts assumption to AgentCore)
2. A permission policy that grants only the required permissions
3. Session tag conditions that prevent the agent from accessing resources outside its scope
4. An explanation of how AgentCore's credential vending cycle ensures short-lived credentials

## Key Concepts

- **IAM Trust Policy:** Who can assume this role? Answer: only AgentCore's service principal with a valid external ID.
- **IAM Permission Policy:** What can this role do? Answer: read DynamoDB, call payment API, write logs — with conditions based on session tags.
- **Session Tags:** Metadata (`agentId`, `userId`, `sessionId`) attached to temporary credentials; visible in CloudTrail.
- **Credential Vending:** AgentCore issues short-lived credentials (15-minute TTL) on-demand; no static keys stored.

## Steps

1. **Read** `config/agentcore_iam_role.json` — the template for an orchestrator role.
2. **Understand** each policy section: trust policy (who), permission policy (what), conditions (when).
3. **Compare** the trust policy against a static IAM user model — note the differences.
4. **Complete** the `<PLACEHOLDER>` values with realistic examples.
5. **Verify** that session tag conditions are present in all permission statements.
6. **Review** the SOLUTION.md to check your work.

## Expected Deliverable

A completed `agentcore_iam_role.json` with:
- Trust policy restricting assumption to AgentCore service principal + external ID
- Permission policy granting `dynamodb:GetItem`, `dynamodb:Query`, `logs:PutLogEvents`
- Conditions enforcing `aws:PrincipalTag/agentId == "payment-orchestrator"`
- Comments explaining each policy component

## Assessment Questions

1. Why is a static IAM access key unsuitable for an AI agent, and how does AgentCore's approach fix this?
2. How do session tags enable audit compliance (tracing which user's session triggered each API call)?
3. What happens if an agent is compromised? How do short-lived credentials limit the blast radius?
4. How does the `X-AgentCore-Caller-Identity` header allow a backend API to trust the agent's identity without re-validating IAM?

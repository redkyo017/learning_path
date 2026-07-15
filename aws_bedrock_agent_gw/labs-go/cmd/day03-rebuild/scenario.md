# Closed-Book Rebuild Scenario

**Time limit:** 2 hours. No notes, no prior code, no spec.

## What you are building

An enterprise HR + ticketing agent powered by AgentCore Gateway.

**Requirements:**
1. A Gateway with 2 tools:
   - HR tool: employee lookup (Lambda-backed, by employee ID)
   - Ticketing tool: create and query support tickets (HTTP-backed)
2. Agents never hold credentials — Gateway mediates all auth
3. HR tool responses must have PII redacted (name, email) via guardrail
4. X-Ray tracing enabled — every invocation must be traceable
5. Both tools have rate limiting: max 5 req/s each
6. At least 2 Bedrock agents share the same Gateway
7. All resources tagged `project=bgw-rebuild`, `environment=lab`
8. All provisioning via Go SDK — no console

**Success criteria:**
- Ask agent 1: "What is the department of employee E001?" → correct answer, PII redacted in trace
- Ask agent 2: "Create a ticket for employee E002's laptop issue" → ticket created, no credentials in agent context
- Update the HR tool's rate limit to 10 req/s → both agents see the change immediately
- Tear down all resources in one pass

## Start

Open `main.go`, start the timer, build from memory.

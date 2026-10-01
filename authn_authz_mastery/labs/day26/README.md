# Day 26 Lab — MCP Service Authentication

## Overview

In this lab, you will configure IS 7.3 as an OAuth2 authorization server for MCP (Model Context Protocol) tools. You'll learn how scoped OAuth2 tokens replace API keys, enabling per-user revocation and audit trails.

## Success Signal

You can:
- Explain why OAuth2 is superior to static API keys for MCP tool authentication
- Design scope hierarchy for MCP operations (read, write, specific operations)
- Configure IS 7.3 to register MCP scopes and tools
- Understand how agents discover and register as MCP clients
- Trace how user revocation invalidates active MCP tool tokens

## Task

You are architecting MCP tool authentication for a banking system. Design:

1. A scope hierarchy for a payments MCP tool with read and write operations
2. IS 7.3 deployment.toml configuration for MCP tool scope registration
3. DCR registration for an MCP agent client
4. MCP tool server resource server registration
5. Token exchange request for a specific MCP scope (not all scopes)

Key principle: **Least privilege at the scope level** — agents request only the scope needed for the specific operation.

## Key Concepts

- **MCP Scope:** OAuth2 scope mapped to a specific tool operation (e.g., `mcp:payments:read`, `mcp:payments:write:send`)
- **Tool Discovery:** MCP server publishes `/.well-known/oauth-authorization-server` to advertise scopes and authorization endpoints
- **DCR for MCP Clients:** Agents self-register as OAuth2 clients with scopes they support
- **Resource Server Registration:** MCP tool servers register with IS 7.3 as resource servers with specific scopes
- **Scoped Tokens:** Short-lived tokens (5min) tied to specific operations, tied to user context (via RFC 8693 exchange)

## Steps

1. **Read** `config/mcp_oauth2_server.toml` — the IS 7.3 configuration for MCP tools
2. **Understand** each deployment.toml section: scope registration, resource server config, token lifetime
3. **Design** a scope hierarchy: `mcp:payments:read`, `mcp:payments:write`, `mcp:payments:write:send`
4. **Complete** the `<PLACEHOLDER>` values with realistic examples
5. **Trace** a token exchange request for `scope=mcp:payments:read` only (not all scopes)
6. **Review** SOLUTION.md to check your work

## Expected Deliverable

A completed `mcp_oauth2_server.toml` with:
- Scope definitions for MCP operations
- Resource server registration for the payments MCP tool
- DCR configuration for MCP clients
- Token lifetime settings (short-lived for MCP)
- Security considerations (scopes, audience restrictions, consent requirements)

## Assessment Questions

1. Why is `scope=mcp:*` (wildcard) a security anti-pattern?
2. How does MCP token revocation via IS 7.3 consent withdrawal differ from static API key revocation?
3. Design a scope hierarchy for a tool with three operations: `GetBalance`, `InitiatePayment`, `ApprovePayment`. How many scopes?
4. An agent obtains a token with `scope=mcp:payments:read`. Can it call an operation with `scope=mcp:payments:write`? Why or why not?
5. How does user consent in IS 7.3 enable compliance-friendly MCP tool authentication?

## References

- Day 24: AgentCore credential vending
- Day 25: RFC 8693 token exchange with AWS OIDC federation
- Day 26 content: MCP OAuth2 architecture and scoped token design

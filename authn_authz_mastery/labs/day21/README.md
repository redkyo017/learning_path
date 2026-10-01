# Day 21 Lab — Agent Identity Fundamentals

## Objective

Design a principal hierarchy for a banking AI agent. Success signal: you can draw the 3-tier delegation chain with correct token claims (`sub`, `act`, scope) at each hop.

## Scenario

You're designing identity architecture for a payment processing AI system:

- **User**: Jane Smith (subject_id: `jane_user_001`)
- **Orchestrator Agent**: Bedrock-based "PaymentOrchestrator" (client_id: `payment_orchestrator`)
- **Tool Agent**: Specialized "RiskScorer" (client_id: `risk_scorer`)
- **Backend API**: `/v1/payments/initiate` (requires `payments:initiate` scope)

Jane initiates a payment request. The orchestrator decomposes it into: (1) risk assessment, (2) payment initiation. The risk scorer tool must call the backend — but with narrowed scope and clear audit trail.

## What you'll produce

1. A **Mermaid sequence diagram** showing all three principals and three token states:
   - User authenticates to IS 7.3 → receives `human_token`
   - Orchestrator exchanges `human_token` → receives `orchestrator_token` with `act` claim
   - Risk scorer exchanges `orchestrator_token` → receives `risk_scorer_token` with nested `act`

2. Complete **token payloads** at each step:
   - Decode what claims each token has
   - Show how `sub` is preserved
   - Show how `act` grows
   - Annotate each scope

3. A **comparison table** (template in `config/agent_identity_comparison.md`):
   - Compare three approaches: `client_credentials`, Impersonation, OBO (RFC 8693)
   - On each row, evaluate: audit trail, scope control, revocation, confused deputy risk, compliance

## Steps

### Step 1: Review the scenario

The bank's compliance requirement: every API call must be traceable to the user + all agents in the chain. They also need to revoke at the user level and see revocation propagate within 5 minutes.

### Step 2: Study the diagram template

Open `diagram.md` and sketch the sequence using Mermaid. Each actor (User, IS 7.3, Orchestrator, RiskScorer, Backend) appears as a participant. Show the full token lifecycle.

### Step 3: Analyze token payloads

For each token state, decode (in pseudocode) what claims it carries:

- `human_token`: What is `sub`? What `scope`? What `exp`? What `jti`?
- `orchestrator_token`: What is `sub`? What is `act`? What `scope`? Why shorter `exp`?
- `risk_scorer_token`: What is `sub`? What is `act` (nested)? What `scope`? What `exp`?

### Step 4: Fill the comparison table

In `config/agent_identity_comparison.md`, complete the three columns with your analysis. Reference Day 21 content for guidance.

### Step 5: Check your work

- Does `sub` remain `jane_user_001` at every hop? ✓
- Does `act` grow (not replace) at each exchange? ✓
- Are scopes narrowed appropriately? ✓
- Can you trace the audit trail: "jane → orchestrator → risk_scorer"? ✓

## Success Criteria

- Mermaid sequence diagram is complete and shows token evolution
- Token payloads are decoded with all 5 key claims visible
- Comparison table is filled with substantive analysis (not placeholder text)
- You can explain why each claim matters for banking compliance

## Time estimate

40–50 minutes

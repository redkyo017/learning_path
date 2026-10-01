# Day 11 Lab — App-Native Auth API Trace

**Goal:** Trace the IS 7.3 App-Native Auth API HTTP exchange for a two-step authentication flow
(username/password → TOTP).

**Success signal:** You can identify `flowId`, each step's `nextStep` object, and the final
`authCode` in the exchange, and explain what IS 7.3 does server-side at each step.

**Steps:**
1. Open `config/authn_api_flow.http` — annotated HTTP exchange for a two-step flow.
2. For each request/response pair, identify: (a) what the app sends, (b) what IS 7.3 validates,
   (c) what the response carries for the next step.
3. Trace the `flowId` through all steps — note it never changes.
4. Check your understanding against `SOLUTION.md`.

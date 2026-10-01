# Day 04 Lab — CIBA Poll-Mode Flow Trace

**Goal:** Trace a CIBA poll-mode HTTP exchange from the backchannel authorization request to token delivery.

**Success signal:** You can identify `auth_req_id`, the polling interval, the `binding_message` purpose, and the token grant type — without referring to the spec.

**Steps:**

1. Open `config/ciba_request.http`.
2. Read the `POST /bc-authorize` request. Identify:
   - Which parameter identifies the user to authenticate
   - Which parameter links the consumption device and authentication device
   - What format `authorization_details` takes
3. Read the `200` response from `/bc-authorize`. Answer:
   - What is `auth_req_id` used for in subsequent requests?
   - What does `interval` tell the client?
   - What does `expires_in` mean for the user experience?
4. Read the first `POST /token` poll. Identify:
   - What grant type is used for CIBA token requests?
   - What does `authorization_pending` tell the client?
5. Read the second `POST /token` poll (after user approves). Identify:
   - What changes in the response compared to the pending poll?
   - What is the `token_type` in a CIBA token response?
6. Check your answers against `SOLUTION.md`.

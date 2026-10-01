# Day 01 Lab — FAPI 2.0 Client Registration Annotation

**Goal:** Annotate a FAPI 2.0 client registration JSON to identify which fields enforce which FAPI 2.0 requirements.

**Success signal:** You can explain the purpose of every field in `config/fapi_client_registration.json` and identify which FAPI 2.0 mandate each field satisfies — without referring to the spec.

**Steps:**
1. Open `config/fapi_client_registration.json`.
2. For each field, write a one-line comment explaining: (a) what it configures, (b) which FAPI 2.0 requirement it satisfies.
3. Identify which fields would be present in a plain OAuth2 client registration but are absent here.
4. Check your annotations against `SOLUTION.md`.

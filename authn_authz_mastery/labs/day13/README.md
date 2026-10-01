# Day 13 Lab — FAPI 2.0 Config in IS 7.3

**Goal:** Enable FAPI compliance mode in IS 7.3 and register a FAPI-compliant client via DCR.

**Success signal:** You can identify every FAPI-required field in the config stubs and explain
what IS 7.3 would reject without each one.

**Steps:**
1. Review `config/fapi_deployment.toml` — IS 7.3 server FAPI settings.
2. Trace which requests IS 7.3 would accept vs. reject with these settings active.
3. Identify the three fields in the TOML that enforce PAR, JARM, and `private_key_jwt` respectively.
4. Check your answers against `SOLUTION.md`.

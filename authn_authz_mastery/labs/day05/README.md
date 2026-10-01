# Day 05 Lab — DPoP Proof JWT Annotation

**Goal:** Annotate a DPoP proof JWT to understand how each claim binds the proof to the access token and the HTTP request.

**Success signal:** You can explain the purpose of every claim in `config/dpop_proof.json` and explain what the resource server checks in order — without referring to the spec.

**Steps:**

1. Open `config/dpop_proof.json`.
2. Read the `dpop_proof_header` section. Answer:
   - Why is the DPoP key (JWK) embedded in the proof header rather than referenced by key ID?
   - What does `typ: "dpop+jwt"` tell the recipient?
3. Read the `dpop_proof_claims` section. For each claim, write one sentence explaining what it binds or prevents.
4. Read the `access_token_decoded` section. Answer:
   - How is `cnf.jkt` derived from the `jwk` in the proof header?
   - What does `token_type: DPoP` tell the resource server?
5. Trace the full validation sequence the resource server performs on a request carrying both `Authorization: DPoP <token>` and `DPoP: <proof>`. List the checks in order.
6. Check your answers against `SOLUTION.md`.

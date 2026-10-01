# Day 06 Lab — mTLS Certificate Thumbprint Trace

**Goal:** Trace the certificate thumbprint from TLS handshake through access token `cnf` claim to resource server validation.

**Success signal:** You can explain what `cnf.x5t#S256` means, how it is computed, and how the RS validates it — without referring to the spec.

**Steps:**

1. Open `config/mtls_client_config.yaml`.
2. Read the `client_registration` section. Answer:
   - What is the difference between `tls_client_auth` and `self_signed_tls_client_auth`?
   - What is `x5c` and how does the AS use it for `self_signed_tls_client_auth`?
3. Read the `token_response` section. Answer:
   - Where does the `cnf.x5t#S256` value come from?
   - What does it mean for the token to be "certificate-bound"?
4. Read the `resource_server_config` section. Answer:
   - What header does the API gateway forward from the TLS session to the backend?
   - Why is it a thumbprint rather than the full PEM certificate?
5. Trace the full validation path: client cert → TLS handshake → gateway → token `cnf` → backend validation.
6. Check your answers against `SOLUTION.md`.

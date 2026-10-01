# Day 15 Lab — DPoP + mTLS Token Binding in IS 7.3

**Goal:** Trace the DPoP token flow through IS 7.3, identifying where `cnf.jkt` is set
and where it must be validated. Identify the two gateway configurations required for DPoP
binding to work end-to-end.

**Success signal:** You can explain what the `cnf` object in an IS 7.3 introspection response
obligates the resource server to do, identify the two places a reverse proxy must be configured
to pass DPoP headers, and describe what IS 7.3 reads when extracting an mTLS client certificate
from behind a reverse proxy.

---

## Files in this lab

| File | Purpose |
|------|---------|
| `config/token_binding_deployment.toml` | Annotated `deployment.toml` stanzas + sample introspection response |
| `diagram.md` | DPoP + mTLS token flow sequence diagram through IS 7.3 and gateway |
| `SOLUTION.md` | Explanation of `cnf` validation, gateway requirements, and DPoP/mTLS interaction |

---

## Steps

### 1. Read the annotated config

Open `config/token_binding_deployment.toml`. Study:

- The `[oauth]` DPoP and mTLS enable flags and what each controls.
- The `[transport.https.ssl]` proxy header configuration for mTLS.
- The annotated introspection response JSON showing both `cnf.jkt` and `cnf.x5t#S256`.

### 2. Identify the two gateway configuration requirements

Without looking at `SOLUTION.md`, answer:

1. Which HTTP header must the API gateway forward from client to IS 7.3 at the token endpoint?
2. Which HTTP header must the API gateway forward from client to the resource server?

Write your answers. Then check whether these are the same header or different headers and why.

### 3. Trace the cnf.jkt embedding path

Using `diagram.md`, trace:

- When does IS 7.3 compute `jkt`? What inputs does it use?
- Where is `cnf.jkt` stored — in the token itself (JWT claims), or only in IS 7.3's introspection database?
- What does the resource server need to do when it sees `cnf.jkt` in the introspection response?

### 4. Understand DPoP vs. mTLS precedence

Using the config file, answer:

- If a client sends BOTH a `DPoP:` header AND a client certificate, what does IS 7.3 embed in the token?
- What happens if the gateway strips the `DPoP:` header after the token is issued — can IS 7.3 fall back to mTLS?

### 5. Check your answers

Compare to `SOLUTION.md`.

---

## Environment notes

No live IS 7.3 instance is required. All exercises work with annotated config stubs and
sequence diagrams. If using a local IS 7.3 Docker instance, changes to `deployment.toml`
require a server restart:

```bash
sh <IS_HOME>/bin/wso2server.sh restart
```

For mTLS testing, configure NGINX to forward the client cert header:

```nginx
# nginx.conf snippet — forward client cert to IS 7.3
proxy_set_header ssl-client-cert $ssl_client_escaped_cert;
```

Replace `ssl-client-cert` with whatever value you set for `ssl_client_cert_header_name` in
`deployment.toml`.

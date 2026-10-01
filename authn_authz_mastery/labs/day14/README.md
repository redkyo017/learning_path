# Day 14 Lab — CIBA Poll vs. Push Mode Configuration in IS 7.3

**Goal:** Configure IS 7.3 CIBA in both poll and push mode using the annotated TOML and HTTP
examples. Identify the three configuration changes needed to switch a running poll-mode setup
to push mode without breaking the `auth_req_id` lifecycle.

**Success signal:** You can list the three changes (one global, two application-level) required
for push mode, explain what happens in IS 7.3 when each change is missing, and describe what
IS 7.3 sends to the `client_notification_endpoint` on user approval.

---

## Files in this lab

| File | Purpose |
|------|---------|
| `config/ciba_is73_config.toml` | Annotated `deployment.toml` stanzas + HTTP request examples |
| `diagram.md` | IS 7.3 CIBA poll-mode and push-mode sequence diagrams |
| `SOLUTION.md` | Step-by-step explanation of the three configuration changes |

---

## Steps

### 1. Read the annotated config

Open `config/ciba_is73_config.toml`. This file contains:

- The `[oauth.ciba]` deployment.toml stanza enabling CIBA globally.
- A poll-mode `POST /oauth2/ciba` request with `client_assertion` in the form body.
- A poll-mode `POST /oauth2/token` poll request.
- A push-mode `POST /oauth2/ciba` request (identical to poll — mode is set in IS 7.3, not the request).
- The IS 7.3 Management API call to configure push mode at the application level.
- The push notification payload IS 7.3 sends to `client_notification_endpoint` on user approval.

### 2. Identify the three configuration changes

Without looking at `SOLUTION.md`, answer:

1. What is the **global** `deployment.toml` change needed to enable CIBA at all?
2. What **application-level** field must be set to activate push mode (instead of poll)?
3. What **application-level** field specifies where IS 7.3 delivers the token on push?

Write your answers before checking the solution.

### 3. Trace the auth_req_id lifecycle

Using `diagram.md`, trace what happens to the `auth_req_id` in each mode:

- In poll mode: where does IS 7.3 store it, what responses does it return on each poll, and when is it consumed?
- In push mode: does the client ever call `POST /oauth2/token`? What triggers IS 7.3 to deliver the token?

### 4. Check your answers

Compare your answers to `SOLUTION.md`.

---

## Environment notes

No live IS 7.3 instance is required. All exercises work with the annotated config stubs and
sequence diagrams. If you have a local IS 7.3 Docker container, the config path is:

```
<IS_HOME>/repository/conf/deployment.toml
```

Restart IS 7.3 after changing `deployment.toml`:

```bash
# Local Docker only — skip if not using a live instance
sh <IS_HOME>/bin/wso2server.sh restart
```

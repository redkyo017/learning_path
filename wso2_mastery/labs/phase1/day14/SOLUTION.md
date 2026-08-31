# Day 14 Lab — SOLUTION

## Question 1 — Which client successfully issued a token?

**Client:** `api-consumer-1`

**Scope granted:** `read:orders write:orders`

**Proof — the key log line:**

```
[2026-08-31 14:22:58,031] [http-nio-9443-exec-1] INFO {org.wso2.carbon.identity.oauth2.OAuth2Service} - Access token issued to [api-consumer-1] for scope [read:orders write:orders]
```

**Explanation:**
This is the canonical "token issued" INFO line from `OAuth2Service`.  The client
`api-consumer-1` successfully authenticated (see the preceding DEBUG lines on
`exec-1`) and received a token with a 3600-second TTL.

---

## Question 2 — Which client failed authentication, and why?

**Client:** `bad-client`

**Reason:** Invalid client credentials (provided secret does not match registered secret)

**The two WARN lines:**

```
[2026-08-31 14:23:01,106] [http-nio-9443-exec-3] WARN {org.wso2.carbon.identity.oauth2.token.handlers.clientauth.BasicAuthClientAuthHandler} - Client Authentication failed for client_id: bad-client. Provided secret does not match registered secret.
```

```
[2026-08-31 14:23:01,108] [http-nio-9443-exec-3] WARN {org.wso2.carbon.identity.oauth.OAuthClientAuthn} - Client Authentication failed for client_id: bad-client. Reason: Invalid client credentials
```

**Explanation:**
The first WARN comes from the lower-level `BasicAuthClientAuthHandler` — it
knows the secret comparison failed.  The second WARN is from `OAuthClientAuthn`,
the orchestration layer that routes the failure up as `invalid_client`.

Two log lines for one failure is a WSO2 IS pattern: the handler logs the
specific reason; the outer service logs the summary reason.  Both lines share
thread `exec-3`, confirming they are from the same request.

**What to do next:**
Verify that `bad-client` is registered in the IS admin console (Service Providers →
OAuth/OpenID Connect Configuration) and that the correct secret is being sent.
Check for Base64-encoding issues if using HTTP Basic Auth.

---

## Question 3 — What happened during introspection?

**Caller:** `api-consumer-1` (the same client that successfully issued a token)

**Token status:** `active=false` — expired

**The exact line with the reason:**

```
[2026-08-31 14:23:05,210] [http-nio-9443-exec-5] WARN {org.wso2.carbon.identity.oauth2.validators.DefaultOAuth2TokenValidator} - Invalid JWT token. failed: JWT has expired. Expiry time: 2026-08-31 14:22:58, Current time: 2026-08-31 14:23:05 — token is past its TTL
```

**Explanation:**
The token was issued at 14:22:58 with a 3600-second TTL — but the log shows
the current time as 14:23:05, only 7 seconds later.  In the synthetic scenario,
the token TTL was effectively zero (or negative due to a very short
`expires_in`).  In a real scenario, `JWT has expired` means the token's `exp`
claim is in the past relative to the IS server's clock.

Common causes:
- Clock skew between the issuer and IS.
- A token that was cached by the client and is now stale.
- An intentionally short `token_ttl` set on the OAuth app in IS.

**What to do next:**
Check `exp` claim in the JWT (decode with `jwt.io`).  Compare to IS server
clock.  Re-issue a fresh token.

---

## Bonus — grep WARN + INFO only

```bash
grep -E "^\[.*\] \[.*\] (WARN|INFO)" log_samples/token_failure.log
```

Output:
```
[2026-08-31 14:22:58,031] [http-nio-9443-exec-1] INFO  ... Access token issued to [api-consumer-1] ...
[2026-08-31 14:23:01,106] [http-nio-9443-exec-3] WARN  ... Client Authentication failed for client_id: bad-client ...
[2026-08-31 14:23:01,108] [http-nio-9443-exec-3] WARN  ... Client Authentication failed for client_id: bad-client ...
[2026-08-31 14:23:01,110] [http-nio-9443-exec-3] INFO  ... Token request rejected for client_id: bad-client ...
[2026-08-31 14:23:05,210] [http-nio-9443-exec-5] WARN  ... Invalid JWT token. failed: JWT has expired ...
[2026-08-31 14:23:05,212] [http-nio-9443-exec-5] INFO  ... Token introspection result: active=false ...
```

At a glance: one successful issue (INFO), one client auth failure (two WARNs),
one expired token on introspection (WARN + INFO).  The full story in 6 lines —
this is why filtering to WARN+INFO is the first step in any log review.

# Drill 11 — Solution: SNI mismatch causing an unexpected certificate

## Hint ladder

1. **Nudge:** exit code `60` is not a TLS alert at all — re-read Day 3's
   "Check 3 is worth calling out specifically" note. Which layer produced
   this error, TLS or the thing calling TLS?
2. **Tool to run:** capture what certificate actually came back, ignoring
   for a moment whether curl accepted it:
   ```
   docker compose run --rm toolbox bash -c \
     "curl -k -v --connect-to wrong.local:8443:nginx:443 https://wrong.local:8443/ 2>&1 | grep -i subject"
   ```
   (`-k` disables verification just for this diagnostic step, so you can
   see what the server sent before deciding whether to trust it.)
3. **Partial diagnosis:** the certificate that came back is for
   `example.local`, not `wrong.local`. Ask: how many `server_name`s does
   nginx actually know about in this lab?

## Full walkthrough

```
docker compose run --rm toolbox bash -c \
  "curl -k -v --connect-to wrong.local:8443:nginx:443 https://wrong.local:8443/ 2>&1 | grep -i subject"
# expected — not captured:
# * Server certificate:
# *  subject: CN=example.local
```

The certificate nginx sent back is for `example.local` — the only
hostname it has ever been configured to serve, and the only certificate
it has ever been issued. Day 2's nginx config defines exactly one server
block. **A single server block with no explicit `default_server` marking
still behaves as the default for its listen socket** — when the incoming
SNI (`wrong.local`, here) doesn't match any known `server_name`, nginx
doesn't refuse the connection; it just serves whichever block it has,
because there's nothing else to choose between.

So the TLS handshake itself completes normally: `ClientHello` carries
SNI `wrong.local`; nginx replies with `ServerHello` and its one available
certificate; the signature chains correctly to the root your `--cacert`
trusts (check 1 and check 4 both pass); the dates are current (check 2
passes). **Check 3 — name match — is the only one that fails**, and it
fails on the *client* side, after the handshake, when curl compares the
hostname it actually asked for (`wrong.local`) against the certificate's
SAN list (`example.local` only). That comparison isn't part of the TLS
protocol at all — it's curl's own post-handshake decision, which is
exactly why the error (`SSL: no alternative certificate subject name
matches target host name 'wrong.local'`, exit `60`,
`CURLE_PEER_FAILED_VERIFICATION`) looks nothing like a TLS alert: there
never was one.

**Fix:** there is no cipher, version, or config flag to "fix" here — the
premise itself was wrong. Either connect to the hostname the certificate
actually covers:

```
docker compose run --rm toolbox curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
    --connect-to example.local:8443:nginx:443 \
    https://example.local:8443/
# expected — not captured: SUCCESS, nginx's default response body.
```

or, if `wrong.local` is genuinely meant to be served by this nginx, issue
it its own certificate with the right SAN (`ca/issue-server-cert.sh
wrong.local wrong.local`) and add a matching `server_name wrong.local;`
block — that's Day 2 territory, not something to bolt onto Day 3.

## Lesson

A wrong or unexpected certificate isn't always a server misconfiguration —
it's frequently a client asking for a name the server was never told
about, on a server that has no better option than to answer with
whatever certificate it does have. Check 3 (name match) is evaluated
entirely on the client side, entirely after the handshake completes at
the protocol level, which is why its failure mode looks nothing like a
version or cipher mismatch.

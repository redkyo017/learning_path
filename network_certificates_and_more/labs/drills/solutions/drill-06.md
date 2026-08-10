# Drill 06 — Solution: the wrong certificate is being served

## Hint ladder

1. **Nudge:** `openssl verify` already told you the chain is fine
   (`OK`, exit `0`). If check 1, check 2, and check 4 all pass, which of
   Day 1's four checks is left to fail — and does `openssl verify` even
   test that one?
2. **Tool to run:** pull the SAN out of the cert actually being served, and
   compare it against the hostname you're connecting to:
   ```
   docker compose run --rm toolbox bash -c \
     "openssl x509 -in /work/drills/drill-06/other.local.cert.pem -noout -text | grep -A1 'Subject Alternative Name'"
   ```
3. **Partial diagnosis:** the SAN says `DNS:other.local`. You're connecting
   to `example.local`. `openssl verify` never checked that — hostname
   matching against SAN is a separate step that `curl` and browsers
   perform *after* chain verification succeeds, not something baked into
   `openssl verify`'s own chain-building logic.

## Full walkthrough

```
docker compose run --rm toolbox openssl verify -CAfile /work/drills/drill-06/chain.cert.pem \
    /work/drills/drill-06/other.local.cert.pem
# other.local.cert.pem: OK
```

The chain is completely sound: correctly signed by the intermediate,
intermediate correctly signed by the root, dates fine, root trusted. This
is real, confirmed output — and it is exactly why this drill is
instructive: `openssl verify` on its own **does not perform hostname
matching at all**. It only builds and validates the signature chain
(checks 1, 2, and 4). Check 3 — does the name you're actually trying to
reach appear in this cert's SAN — is a separate step that `curl` and every
browser run on top of chain verification, using the connection target
(here, `example.local`, supplied via `--connect-to`'s left-hand side and
still used as the URL's hostname/SNI/Host header) against the SAN list you
pulled out above:

```
docker compose run --rm toolbox bash -c \
  "openssl x509 -in /work/drills/drill-06/other.local.cert.pem -noout -text | grep -A1 'Subject Alternative Name'"
# X509v3 Subject Alternative Name:
#     DNS:other.local
```

`other.local` is the only name in this cert's SAN. `example.local` isn't
in it. Reasoning from Day 1's canonical wording (`curl`'s message text for
this exact class of failure is well-established and stable across
versions), the live `curl` command against nginx would report something in
the shape of:

```
curl: (60) SSL: no alternative certificate subject name matches target host name 'example.local'
```

**Fix:** serve the *correct* certificate for `example.local` — i.e. undo
the mix-up and point nginx's `ssl_certificate` back at
`example.local`'s own fullchain (leaf issued with `SAN=DNS:example.local`,
from this day's guided lab), not `other.local`'s. There is no way to
"patch" a SAN mismatch by adjusting anything on the client side — the
certificate is completely valid, just valid *for a different name*, and
the only real fix is serving the cert that was actually issued for the
name being requested.

## Lesson

A perfectly valid, correctly-chained, correctly-trusted certificate can
still be the wrong certificate for the connection you're making — chain
verification (checks 1/2/4) and hostname matching (check 3) are
independent steps, and `openssl verify`'s "OK" only ever speaks to the
former.

# Capstone 02 — Solution: right cert, wrong name

## Hint ladder

1. **Nudge:** "it's the same server" is a statement about infrastructure,
   not about what a certificate's SAN list actually says. Those are
   independent facts.
2. **Tool to run:**
   ```
   docker compose run --rm toolbox openssl x509 -in /work/ca/intermediate/certs/example.local.cert.pem \
       -noout -text | grep -A1 "Subject Alternative Name"
   ```
3. **Partial diagnosis:** the SAN list has exactly one entry, and it isn't
   `portal.example.local`. Nothing about the signature, the dates, or the
   trust anchor is in question here.

## Full walkthrough

```
docker compose run --rm toolbox openssl x509 -in /work/ca/intermediate/certs/example.local.cert.pem \
    -noout -text | grep -A1 "Subject Alternative Name"
# X509v3 Subject Alternative Name:
#     DNS:example.local
```

The certificate is completely unmodified, correctly signed by your real
intermediate CA, and nowhere near expired — checks 1, 2, and 4 all pass
cleanly, exactly as they do every other time you connect to
`example.local`. **Check 3: name match** is the only one that fails, and
it fails specifically because you connected to a *different name* than
the one the certificate was ever issued for. "It's the same server" is a
true statement about the underlying infrastructure and a completely
irrelevant one to check 3 — hostname verification asks whether the name
you're reaching is in the SAN list, not whether the physical machine
behind it happens to be shared with some other name that is.

This maps directly to Day 1 Exercise 3 and Day 3 Exercise 4's point about
where this check actually lives: it never produces a TLS protocol alert
at all (there's no "wrong name" alert defined in TLS), it's an
application-layer decision curl makes *after* the handshake has already
succeeded — which is exactly why the error text reads as a curl-specific
message (`SSL: no alternative certificate subject name matches target
host name '...'`) rather than anything resembling a handshake failure.

**Fix:** either connect using a name the certificate actually covers
(`example.local`, not `portal.example.local`), or — if `portal.example.local`
genuinely needs to be a supported name for this service — re-issue the
certificate with both names in its SAN list:
`ca/issue-server-cert.sh example.local example.local portal.example.local`.

## Lesson

A certificate binds a name (or a short list of names) to a key, full stop —
it says nothing about which physical server, IP, or infrastructure that
key happens to be deployed on. Two different hostnames sharing the same
backend does not make them the same name for verification purposes, and
"but it's the same server" is never an argument that overrides check 3.

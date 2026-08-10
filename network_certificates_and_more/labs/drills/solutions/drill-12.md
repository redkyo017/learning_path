# Drill 12 — Solution: ALPN mismatch

## Hint ladder

1. **Nudge:** "no application protocol" is a specific, named TLS alert —
   not a generic handshake failure. Which extension negotiates
   "application protocol" during a TLS handshake?
2. **Tool to run:** check exactly what each side offered/required:
   ```
   grep alpn /work/drills/drill-12/repro.sh
   ```
3. **Partial diagnosis:** the server was started with `-alpn h2` (it will
   only ever select `h2`). The client was started with `-alpn http/1.1`
   (it only offered `http/1.1`). Is there any protocol name common to
   both lists?

## Full walkthrough

`repro.sh` starts `openssl s_server -alpn h2` — the server is configured
with exactly one acceptable ALPN protocol, `h2`. The client then runs
`openssl s_client -alpn http/1.1` — it offers exactly one protocol,
`http/1.1`. The intersection of `{h2}` and `{http/1.1}` is empty.

Per RFC 7301 §3.2:

> In the event that the server supports no protocols that the client
> advertises, then the server SHALL respond with a fatal
> "no_application_protocol" alert.

This is not optional graceful degradation — the RFC uses "SHALL." Because
the server has ALPN protocols configured at all (via `-alpn h2`) and none
of them match the client's offer, it is required to abort the connection
with a fatal alert (`no_application_protocol`, alert `120` in the TLS
AlertDescription registry) rather than completing the handshake without
having agreed on an application protocol. That's exactly what the client
observes: `error:0A000042:SSL routines::tlsv1 alert no application
protocol`, and the connection tears down before any certificate chain is
ever printed by `s_client` — the alert fires during the
`ClientHello`/`ServerHello`+`EncryptedExtensions` exchange, before the
`Certificate` message would otherwise appear.

Contrast this with a server that has **no** ALPN protocols configured at
all: in that case there's nothing to fail to match, ALPN negotiation is
simply skipped, and the handshake proceeds normally without an agreed
protocol. The failure here specifically requires the server to *want*
ALPN and have zero overlap — not merely "the client asked for ALPN and
the server ignored it."

**Fix:** make the two lists overlap — either widen the server's accepted
list to include what the client offers, or change what the client offers:

```
docker compose run --rm toolbox bash -c \
  "openssl s_server -accept 8445 \
     -cert /work/ca/intermediate/certs/example.local.cert.pem \
     -key  /work/ca/intermediate/private/example.local.key.pem \
     -alpn h2,http/1.1 -naccept 1 -quiet & \
   sleep 1; \
   openssl s_client -connect 127.0.0.1:8445 -servername example.local \
       -CAfile /work/ca/intermediate/certs/ca-chain.cert.pem \
       -alpn http/1.1 </dev/null; \
   wait"
# expected — not captured: successful handshake, s_client reports
# "ALPN protocol: http/1.1" and prints the certificate chain.
```

**Note on the exact OpenSSL error text above:** the hex reason code
(`0A000042`) is representative of OpenSSL 3.x's rendering of the
`no_application_protocol` alert; treat the alert name and number (`120`,
per RFC 7301) as the authoritative fact, and the exact printed string as
indicative rather than guaranteed byte-for-byte on every build.

## Lesson

Unlike a plain protocol-version or cipher mismatch, an ALPN mismatch is
only fatal when the server has actually opted into requiring ALPN
agreement (i.e., it has a configured protocol list) and that list shares
nothing with what the client offered — RFC 7301 makes this specific case
a mandatory fatal alert, not a fallback. If a server has no ALPN
configuration at all, mismatched or absent ALPN is silently a non-event.

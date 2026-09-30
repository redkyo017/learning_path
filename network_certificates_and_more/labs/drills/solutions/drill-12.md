# Drill 12 — Solution: ALPN mismatch

## Hint ladder

1. **Nudge:** the client's line ends `SSL alert number 120`, and the
   server's line says "no application protocol". Alert 120 is a specific,
   named TLS alert — not a generic handshake failure. Which extension negotiates
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
observes: `error:0A000460:SSL routines:ssl3_read_bytes:reason(1120)...SSL
alert number 120`, and the connection tears down before any certificate chain is
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
# Successful handshake: s_client prints the certificate chain, then
# (excerpt):
#   New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
#   ALPN protocol: http/1.1
#   Verify return code: 0 (ok)
```

**Reading the error text:** OpenSSL encodes a received alert as reason
code `1000 + alert number`, so `reason(1120)` means "received alert 120".
The toolbox's OpenSSL 3.0 has no human-readable string for that reason, so
it prints the bare number — the trailing `SSL alert number 120` is the
reliable part. The server's own line (`0A0000EB ... tls_handle_alpn:no
application protocol`) names the cause directly. Also ignore
`Verify return code: 0 (ok)`: no certificate ever arrived, so there was
nothing for verification to reject.

## Lesson

Unlike a plain protocol-version or cipher mismatch, an ALPN mismatch is
only fatal when the server has actually opted into requiring ALPN
agreement (i.e., it has a configured protocol list) and that list shares
nothing with what the client offered — RFC 7301 makes this specific case
a mandatory fatal alert, not a fallback. If a server has no ALPN
configuration at all, mismatched or absent ALPN is silently a non-event.

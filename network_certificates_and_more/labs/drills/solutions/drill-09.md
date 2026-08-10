# Drill 09 — Solution: protocol-version mismatch

## Hint ladder

1. **Nudge:** `error:0A000102` mentions "unsupported protocol" and nothing
   about certificates, ciphers, or hostnames. Where in the handshake could
   a failure happen before *any* of those even come into play?
2. **Tool to run:** check what versions each side was actually configured
   to speak. Re-read the two `openssl` flags in `repro.sh`:
   ```
   grep -E 'tls1_1|tls1_2|tlsv1|tls-max|no_ssl3|no_tls1' /work/drills/drill-09/repro.sh
   ```
3. **Partial diagnosis:** the server explicitly disabled everything below
   TLS 1.2 (`-no_ssl3 -no_tls1 -no_tls1_1`). The client explicitly capped
   itself at TLS 1.1 (`--tlsv1.0 --tls-max 1.1`). Compare those two ranges.

## Full walkthrough

The server's allowed range is **TLS 1.2 and up** (everything below 1.2 was
explicitly disabled). The client's allowed range is **TLS 1.0 through 1.1**
(explicitly capped with `--tls-max 1.1`). Those two ranges do not overlap
anywhere:

```
server:  [-------- 1.2 --------- 1.3 ---]
client:  [-- 1.0 -- 1.1 --]
overlap: (none)
```

This failure happens during the very first exchange — `ClientHello` and
whatever the server can manage in response — **before any `Certificate`
message is ever sent**. None of the four verification checks from Day 1
even get a chance to run, because there's no certificate yet to check
against. This is a pure protocol-negotiation failure: the client's
`ClientHello` (built with a legacy version field capped at 1.1, since
`--tls-max 1.1` means the client never even advertises a `supported_versions`
extension reaching 1.2+) offers a version the server has explicitly refused
to speak, and the server has no lower version to fall back to that it's
still willing to negotiate. The result is a fatal alert conceptually
corresponding to `protocol_version` (alert 70 in the TLS AlertDescription
registry) — curl surfaces this to you as exit code `35`
(`CURLE_SSL_CONNECT_ERROR`) with an OpenSSL error queue message referencing
"unsupported protocol."

**Fix:** raise the client's ceiling to overlap with the server's floor —
either drop `--tls-max 1.1` entirely (curl will then negotiate the highest
mutually supported version automatically) or explicitly set
`--tlsv1.2 --tls-max 1.3`:

```
docker compose run --rm toolbox bash -c \
  "openssl s_server -accept 8444 \
     -cert /work/ca/intermediate/certs/example.local.cert.pem \
     -key  /work/ca/intermediate/private/example.local.key.pem \
     -no_ssl3 -no_tls1 -no_tls1_1 -naccept 1 -quiet & \
   sleep 1; \
   curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
        --resolve example.local:8444:127.0.0.1 \
        https://example.local:8444/; \
   wait"
# expected — not captured: a successful TLS 1.2 or 1.3 handshake and a
# response body from openssl s_server's default responder.
```

**Note on the exact OpenSSL error text above:** the hex reason code
(`0A000102`) and the general shape of the message are consistent with how
OpenSSL 3.x renders this failure, but the precise string can shift slightly
between point releases. Treat the *mechanism* (no overlapping version, so
the handshake dies before any certificate is exchanged) and the *exit code*
(`35`) as the reliable signal — the exact error text is secondary evidence,
not the diagnosis itself.

## Lesson

A version-mismatch failure happens strictly *before* the certificate
exchange — it's not one of the four checks failing, it's the handshake
never reaching the point where a certificate could even be sent. If you
see a version/protocol alert, look at what versions *each side* is
configured to allow, not at anything about the certificate.

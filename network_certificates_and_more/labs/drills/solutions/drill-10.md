# Drill 10 — Solution: no shared cipher

## Hint ladder

1. **Nudge:** the error says "handshake failure," not "unsupported
   protocol" (that was drill 9) and not a hostname/certificate-verify
   error. The protocol version negotiated fine — TLS 1.2 was explicitly
   requested and the server supports it. Something *inside* the TLS 1.2
   suite-selection process is the problem.
2. **Tool to run:** look at exactly which suites the client offered, and
   what the server's certificate actually is:
   ```
   grep ciphers /work/drills/drill-10/repro.sh
   docker compose run --rm toolbox openssl x509 \
       -in /work/ca/intermediate/certs/example.local.cert.pem -noout -text \
       | grep -A1 'Public Key Algorithm'
   ```
3. **Partial diagnosis:** the client only offered `ECDHE-ECDSA-*` suites.
   Check what kind of public key the server's certificate actually holds.

## Full walkthrough

```
docker compose run --rm toolbox openssl x509 \
    -in /work/ca/intermediate/certs/example.local.cert.pem -noout -text \
    | grep -A1 'Public Key Algorithm'
# expected — not captured:
# Public Key Algorithm: rsaEncryption
```

The server's only certificate holds an **RSA** key (Day 2's
`issue-server-cert.sh` always generates RSA 2048 leaf keys — confirmed
directly in that script's comments). The client, per `repro.sh`, restricted
itself to exactly two cipher suites:

```
ECDHE-ECDSA-AES256-GCM-SHA384
ECDHE-ECDSA-AES128-GCM-SHA256
```

Both are `ECDHE-ECDSA-*` suites. As Day 3's theory section spells out, the
second field in a TLS 1.2 suite name (`ECDSA` here) names the
**authentication algorithm** — it requires the server's certificate to
hold an ECDSA key, because the signature over `ServerKeyExchange`'s
ephemeral parameters has to be computed with that certificate's private
key, using that key's own algorithm. An RSA certificate cannot produce an
ECDSA signature. There is no certificate the server could substitute in
this specific setup that would make these two suites usable — the server
has exactly one certificate, and it's the wrong key type for what the
client is insisting on.

Because zero suites overlap between "what the client offered" and "what
the server can actually authenticate with," the server sends a fatal
`handshake_failure` alert (alert `40` in the TLS AlertDescription
registry) — curl surfaces this as exit code `35` with an OpenSSL error
referencing "handshake failure."

**Fix:** offer suites that match the certificate's actual key type — drop
the `--ciphers` restriction entirely (let curl/OpenSSL negotiate normally)
or explicitly request `ECDHE-RSA-*` suites instead:

```
docker compose run --rm toolbox curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
    --connect-to example.local:8443:nginx:443 \
    --tlsv1.2 --tls-max 1.2 \
    --ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256 \
    https://example.local:8443/
# expected — not captured: a successful TLS 1.2 handshake and nginx's
# default response body.
```

**Note on the exact OpenSSL error text above:** as with drill 09, the hex
reason code is representative of OpenSSL 3.x's rendering of a
`handshake_failure` alert, not a byte-for-byte guarantee across every
patch version. The reliable signal is the alert name/number and curl's
exit code `35`.

## Lesson

"No shared cipher" is rarely about the server's preferences — it's most
often about a mismatch between the *authentication algorithm* a cipher
suite demands and the *actual key type* of the certificate the server has
to offer. Read the suite name's authentication field (the part right
after the key-exchange algorithm) and cross-check it against
`openssl x509 -noout -text | grep 'Public Key Algorithm'` before assuming
the server's cipher list itself is misconfigured.

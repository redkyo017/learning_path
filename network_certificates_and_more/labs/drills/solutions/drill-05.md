# Drill 05 — Solution: server sends the leaf only, no intermediate

## Hint ladder

1. **Nudge:** error `20` is a different failure mode than "wrong key" or
   "tampered content" — the signature on the leaf itself is never even
   questioned here. Ask what `openssl verify` needs *besides* a trust
   anchor to walk a multi-link chain.
2. **Tool to run:** list exactly what's in this directory versus what a
   full chain actually requires:
   ```
   docker compose run --rm toolbox bash -c "openssl x509 -in /work/drills/drill-05/example.local.cert.pem -noout -issuer"
   ```
   Compare that `Issuer` line against what's actually sitting in
   `root.cert.pem`.
3. **Partial diagnosis:** the leaf's issuer is the *intermediate*, not the
   root. `root.cert.pem` alone cannot verify a signature made by the
   intermediate's key — no certificate for that intermediate exists
   anywhere you handed `openssl verify` (not in `-CAfile`, not in the
   file being checked, nowhere).

## Full walkthrough

```
docker compose run --rm toolbox bash -c "openssl x509 -in /work/drills/drill-05/example.local.cert.pem -noout -issuer"
# issuer=/C=US/ST=CA/O=Drill Fixture Lab/OU=Intermediate CA/CN=Drill Mini Intermediate CA
```

The leaf claims to be signed by "Drill Mini Intermediate CA." You were only
given `root.cert.pem` ("Drill Mini Root CA") as a trust anchor — the
intermediate cert itself is nowhere in the picture. `openssl verify` cannot
complete check 1 for this link: it has a signature to check, but no
certificate containing the intermediate's public key to check it against.
That's exactly what error `20` (`X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT_LOCALLY`)
means: "I don't have a local certificate for whoever issued this."

**Fix:** supply the missing intermediate. In a live handshake this means
nginx's `ssl_certificate` directive must point at the **fullchain**
(leaf + intermediate concatenated, not the leaf alone) so the server
actually *sends* the intermediate to the client during the TLS handshake —
this lab's real Part D does exactly that with
`cat example.local.cert.pem ca-chain.cert.pem > example.local.fullchain.pem`.
Offline, the equivalent fix is supplying the intermediate as `-untrusted`
(mirroring what a peer sends over the wire, as opposed to `-CAfile`, which
is what *you* already trust):

```
docker compose run --rm toolbox openssl verify -CAfile /work/drills/drill-05/root.cert.pem \
    -untrusted /work/drills/drill-05/intermediate.cert.pem \
    /work/drills/drill-05/example.local.cert.pem
```

(`intermediate.cert.pem` is also in this directory — it just wasn't part of
the original broken command, mirroring the original symptom: the *server*
never sent it, so the original check never had it either. In your own
`ca/` workspace, the equivalent file is
`ca/intermediate/certs/intermediate.cert.pem`, or just use
`ca-chain.cert.pem` as `-CAfile` directly, which is what Part D's
guided-lab curl does.) Confirmed real output once the intermediate is
supplied: `example.local.cert.pem: OK`, exit `0`.

Most real browsers only ship **root** certificates in their trust store —
they rely on the server to send every intermediate. This is precisely why
"include the full chain, not just the leaf, in your server config" is one
of the single most common TLS deployment checklist items in the industry.

## Lesson

A verifier can only walk a chain as far as it has certificates for — a
server that sends only its leaf forces every client to already possess the
intermediate independently (which almost none do), so the fix always lives
on the server side: send the leaf *and* every intermediate, every time.

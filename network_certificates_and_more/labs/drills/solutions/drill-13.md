# Drill 13 — Solution: client cert from the wrong CA

## Hint ladder

1. **Nudge:** don't look at the network error first — look at *who signed*
   the certificate you were handed, and compare that against who nginx's
   `ssl_client_certificate` file actually trusts.
2. **Tool to run:** pull the issuer straight off the cert and compare it to
   the CA nginx trusts:
   ```
   docker compose run --rm toolbox openssl x509 -in /work/drills/drill-13/client01-wrongca.cert.pem -noout -issuer
   docker compose run --rm toolbox openssl x509 -in /work/drills/drill-13/reference-ca.cert.pem -noout -subject
   ```
3. **Partial diagnosis:** the two names don't match, and there's no other CA
   in the trust file that could bridge them. This is a chain that simply
   doesn't terminate anywhere the verifier trusts.

## Full walkthrough

```
docker compose run --rm toolbox openssl x509 -in /work/drills/drill-13/client01-wrongca.cert.pem -noout -issuer
# issuer=C = US, ST = CA, O = Definitely Not TLS Mastery Lab, CN = Rogue Testing CA

docker compose run --rm toolbox openssl x509 -in /work/drills/drill-13/reference-ca.cert.pem -noout -subject
# subject=C = US, ST = CA, O = TLS Mastery Lab, CN = TLS Mastery Reference CA (drill fixture)
```

The cert's issuer is `Rogue Testing CA` — a completely different CA
(`rogue-ca.cert.pem`, also shipped in this directory) than the one your trust
file (`reference-ca.cert.pem` here; your real `ca-chain.cert.pem` in the
actual lab) recognizes. Running the same math nginx runs internally confirms
it:

```
docker compose run --rm toolbox openssl verify -CAfile /work/drills/drill-13/reference-ca.cert.pem \
    /work/drills/drill-13/client01-wrongca.cert.pem
# error 20 at 0 depth lookup: unable to get local issuer certificate
# client01-wrongca.cert.pem: verification failed: 20 (unable to get local issuer certificate)
```

This is exactly **check 4: trust anchor**, failing on the *client* side of
the handshake. Nothing is wrong with the certificate's own math — its
signature from `rogue-ca.cert.pem` verifies perfectly against that CA's key
(checks 1–3 could all pass on their own terms). It fails purely because
*nginx* never decided to trust `Rogue Testing CA` — its
`ssl_client_certificate ca-chain.cert.pem` directive is nginx's equivalent of
a `--cacert`/`-CAfile`, scoped specifically to verifying *client* certs, and
it names a completely different set of trusted issuers than whatever public
root store a browser might carry. Over the wire, this surfaces as a TLS
handshake failure (curl error `35`, an "unknown ca" or "bad certificate"
alert from nginx) rather than an HTTP-level response, because — unlike a
*missing* client cert (which some nginx builds let slip past the TLS layer
under TLS 1.3, only to reject at the HTTP layer — see today's guided lab) —
here nginx *does* receive a certificate and rejects it during the handshake
itself, before any HTTP request is ever processed.

**Fix:** issue `client01` from the CA nginx actually trusts:

```
docker compose run --rm toolbox bash ca/issue-server-cert.sh client01 client01
```

and use `ca/intermediate/certs/client01.cert.pem` /
`ca/intermediate/private/client01.key.pem` — not any cert someone hands you
from an unrelated CA, no matter how legitimate-looking its `CN` is.

## Lesson

mTLS makes the trust-anchor check symmetric, and each side's trust anchor is
its own file, not a shared global notion of "valid CA." A perfectly
legitimate certificate from a real, publicly trusted CA would fail this
*exact same way* against this nginx config, because `ssl_client_certificate`
only trusts what's explicitly listed in that one file — never confuse "this
CA is trustworthy in general" with "this CA is the one *this specific
verifier* was configured to trust."

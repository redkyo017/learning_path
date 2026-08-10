# Capstone 06 — Solution: the name on the cert was never the identity

## Hint ladder

1. **Nudge:** a contractor handing you a cert/key pair is not the same
   thing as that cert/key pair having come from *your* CA. Check the
   issuer before trusting the CN.
2. **Tool to run:**
   ```
   docker compose run --rm toolbox openssl x509 -in /work/drills/capstone/capstone-06/tmp/client01-imposter.cert.pem \
       -noout -subject -issuer
   docker compose run --rm toolbox openssl x509 -in /work/ca/intermediate/certs/intermediate.cert.pem \
       -noout -subject
   ```
3. **Partial diagnosis:** the contractor's cert's issuer and your real
   intermediate CA's subject are two completely different names. This
   cert was never signed by anything the server trusts.

## Full walkthrough

```
docker compose run --rm toolbox openssl x509 -in /work/drills/capstone/capstone-06/tmp/client01-imposter.cert.pem \
    -noout -subject -issuer
# subject=O = Definitely Not TLS Mastery Lab, CN = client01
# issuer=O = Definitely Not TLS Mastery Lab, CN = Imposter Testing CA

docker compose run --rm toolbox openssl x509 -in /work/ca/intermediate/certs/intermediate.cert.pem -noout -subject
# subject=O = TLS Mastery Lab, OU = Intermediate CA, CN = TLS Mastery Intermediate CA
```

The CN reads `client01` — identical, character for character, to what
your real Day 4 client identity is called. That similarity is worth
exactly nothing: a name is not an identity, a **key**, vouched for by
someone the verifier actually trusts, is. Anyone can generate a keypair
and self-sign (or stand up their own throwaway CA and sign) a certificate
claiming to be `CN=client01` today — this is Day 1 Exercise 2 and Day 4
Exercise 1's check-1-vs-check-4 distinction, demonstrated live instead of
on paper. The `s_server`'s `-CAfile ca-chain.cert.pem -Verify 1` (standing
in for Day 4's `ssl_client_certificate ca-chain.cert.pem`) only recognizes
certificates chaining to *your* intermediate and root. The imposter cert's
signature verifies perfectly against *its own* CA's key — check 1 passes
on its own terms — but that CA, `Imposter Testing CA`, is nowhere in the
file the server was told to trust. **Check 4: trust anchor** fails, on the
*client* side of the handshake, exactly as Day 4 Exercise 1 predicted this
would.

Over the wire this is a handshake-layer failure (curl exit `35`, an
`unknown ca` alert), not an HTTP-level response — the server rejects the
client certificate before ever processing a request, the same distinction
Day 4's guided lab drew between a *missing* client cert (which some
builds let slip past the TLS layer under TLS 1.3) and a *present but
untrusted* one (rejected during the handshake itself, every time).

**Fix:** never accept a certificate/key pair for an identity you didn't
issue yourself, no matter how correct the CN looks. Issue the real
`client01` identity from your own CA:
`ca/issue-server-cert.sh client01 client01`.

## Lesson

mTLS makes check 4 symmetric, and each side's trust anchor is a specific
file naming specific trusted issuers — never a general notion of "does
this look like a legitimate cert." A perfectly well-formed certificate
from a real, otherwise-trustworthy CA would fail this identical way
against this server, because `-CAfile`/`ssl_client_certificate` only ever
trusts what's explicitly listed in it. Verify who *signed* an identity
before you verify what it *claims to be called*.

# Drill 07 — Solution: a CA file that isn't *your* CA file

## Hint ladder

1. **Nudge:** error `19` is a different failure than error `20` (drill 05).
   Look at the depth in the error: `at 2 depth lookup` means the chain
   walked all the way up — leaf, then intermediate, then root — before
   failing. Something completed that didn't complete in drill 05.
2. **Tool to run:** look at exactly which certificate the error is
   complaining about:
   ```
   docker compose run --rm toolbox openssl x509 -in /work/drills/drill-07/chain.cert.pem -noout -subject -issuer
   ```
   (Note: `chain.cert.pem` contains two certs concatenated — this prints
   only the first, the intermediate. Split it if you want to see the
   root separately: `csplit` or just open the file and eyeball the two
   `BEGIN CERTIFICATE` blocks.)
3. **Partial diagnosis:** the certificate the error names is "Drill Mini
   Root CA" — a **self-signed** cert. It was supplied as part of the chain
   (via `-untrusted`), so `openssl` was able to walk the whole path
   successfully — it just discovered, at the very top, a self-signed cert
   that isn't present in whatever `-CAfile` was actually handed to it.

## Full walkthrough

```
docker compose run --rm toolbox openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt \
    -untrusted /work/drills/drill-07/chain.cert.pem \
    /work/drills/drill-07/example.local.cert.pem
# error 19 at 2 depth lookup:self signed certificate in certificate chain
# example.local.cert.pem: verification failed: 19 (self signed certificate in certificate chain)
```

Error `19` (`X509_V_ERR_SELF_SIGNED_CERT_IN_CHAIN`) means something
structurally different from drill 05's error `20`: the chain **did**
build successfully all the way to the top using the certificates you
supplied as `-untrusted` (exactly what a server sends over the wire) — leaf
→ intermediate → root, every signature checking out. The failure happens
only at the very last step: the root at the top of that otherwise-perfect
chain is self-signed, and it is **not** present in the `-CAfile` you
handed to `openssl` (`/etc/ssl/certs/ca-certificates.crt` — the toolbox's
real, standard system trust bundle, full of legitimate public CAs, none of
which is "Drill Mini Root CA" or, in the live scenario, "TLS Mastery Root
CA").

This is Day 1's check-1-vs-check-4 distinction happening for real: check 1
(is every signature in this chain actually valid, link by link?) passed
completely. Check 4 (is the thing at the top of the chain something *you*
specifically decided to trust?) failed, because "a real, legitimate CA
bundle" and "the CA bundle containing your CA" are not the same file, and
no amount of *other* trustworthy roots in `-CAfile` substitutes for the one
you actually need.

**Fix:** point `-cacert`/`-CAfile` at a bundle that actually contains your
root (or the full `ca-chain.cert.pem`, which contains both intermediate and
root):

```
docker compose run --rm toolbox openssl verify -CAfile /work/drills/drill-07/chain.cert.pem \
    /work/drills/drill-07/example.local.cert.pem
# example.local.cert.pem: OK
```

Confirmed real output: `OK`, exit `0`, once the actual root (bundled
inside `chain.cert.pem` here, or `ca/intermediate/certs/ca-chain.cert.pem`
in your own workspace) is what's supplied as the trust anchor.

## Lesson

A chain building successfully through every signature (check 1) tells you
nothing about whether you've actually decided to trust whoever is at the
top of it (check 4) — pointing `--cacert` at *some* valid CA bundle isn't
the same as pointing it at *the* bundle containing the specific root your
certificate chains to.

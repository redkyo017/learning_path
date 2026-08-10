# Drill 08 — Solution: expired leaf, otherwise-perfect chain

## Hint ladder

1. **Nudge:** error `10` is the same numeric code you saw in Day 1's
   drill-04 — but re-read the depth this time (`at 0 depth lookup`, not a
   self-signed single-cert case). What does depth `0` refer to when there's
   an actual multi-link chain involved?
2. **Tool to run:** pull just the validity window, ignoring the rest of the
   dump:
   ```
   docker compose run --rm toolbox openssl x509 -in /work/drills/drill-08/example.local.expired.cert.pem -noout -dates
   ```
3. **Partial diagnosis:** compare `notAfter` against today's date. Then
   separately confirm the *chain* itself (signature, trust anchor) is
   completely fine — is the problem here structural (a broken signature)
   or purely a clock/date problem?

## Full walkthrough

```
docker compose run --rm toolbox openssl x509 -in /work/drills/drill-08/example.local.expired.cert.pem -noout -dates
# notBefore=Jan  1 00:00:00 2025 GMT
# notAfter=Jul  1 00:00:00 2025 GMT
```

`notAfter` is well in the past relative to any date this course runs on.
Confirm programmatically with `-checkend` (checks whether the cert will
have expired within the given number of seconds from now; `0` means "as of
right now"):

```
docker compose run --rm toolbox openssl x509 -in /work/drills/drill-08/example.local.expired.cert.pem -noout -checkend 0
echo $?
# 1  (already expired)
```

Depth `0` in the original error means the **leaf itself** — depth 0 is
always the certificate you're checking; depth 1, 2, ... are its issuers
going up the chain. Confirm the rest of the chain has nothing wrong with
it by checking the intermediate and root independently — this exact chain,
with a *non-expired* leaf, verifies cleanly (see the guided lab's
`example.local.cert.pem`, built from the same mini-CA, which passes
`openssl verify -CAfile chain.cert.pem` with `OK`). The signature linking
this leaf to the intermediate is completely valid; the intermediate's
signature from the root is completely valid; the root is a legitimate
trust anchor once supplied via `-CAfile`. Every structural link is
intact — this matches Day 1 drill-04's core lesson (**check 2, validity
dates, is evaluated completely independently of check 1, signature
chain**), but now demonstrated on a *real multi-certificate chain* instead
of a lone self-signed cert: dates are checked **per certificate in the
chain**, and a single expired link — even at the very bottom — fails
verification for the whole chain, regardless of how sound every signature
above it is.

**Fix:** you cannot edit a certificate's dates in place — any change to the
document invalidates its signature (the signature covers the whole
document, dates included, exactly like Day 1 Exercise 1). The only real
fix is having the CA **issue a fresh certificate** for the same name with a
current `notBefore`/`notAfter` window:

```
docker compose run --rm toolbox bash ca/issue-server-cert.sh example.local example.local
```

## Lesson

Validity dates are checked independently, per certificate, for every link
in a chain — a leaf that's otherwise perfectly and correctly chained still
fails outright the moment its own `notAfter` passes, and the only fix is a
fresh certificate, never an edited one.

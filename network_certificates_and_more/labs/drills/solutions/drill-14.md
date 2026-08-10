# Drill 14 — Solution: expired client cert

## Hint ladder

1. **Nudge:** this is Day 1's drill-04 all over again, just on the *other*
   side of the handshake this time — check the dates before you go anywhere
   near CA trust questions.
2. **Tool to run:**
   ```
   docker compose run --rm toolbox openssl x509 -in /work/drills/drill-14/client01-expired.cert.pem -noout -dates
   ```
3. **Partial diagnosis:** if `notAfter` is in the past relative to today,
   the certificate's validity window has already closed — completely
   independent of whether its issuer is trusted or its signature is sound.

## Full walkthrough

```
docker compose run --rm toolbox openssl x509 -in /work/drills/drill-14/client01-expired.cert.pem -noout -dates
# notBefore=Jul  6 11:49:51 2025 GMT
# notAfter=Jul  6 11:49:51 2026 GMT
```

`notAfter` is in the past. Confirm programmatically:

```
docker compose run --rm toolbox openssl x509 -in /work/drills/drill-14/client01-expired.cert.pem -noout -checkend 0
echo $?
# 1  (already expired)
```

And the verify call against the CA that actually issued it
(`reference-ca.cert.pem`, a standalone CA shipped only for this drill) fails
exactly as shown in the symptom:

```
docker compose run --rm toolbox openssl verify -CAfile /work/drills/drill-14/reference-ca.cert.pem \
    /work/drills/drill-14/client01-expired.cert.pem
# error 10 at 0 depth lookup: certificate has expired
```

This is **check 2: validity dates**, and it's the same check, the same
failure mode, and the same error code (`10`,
`X509_V_ERR_CERT_HAS_EXPIRED`) as Day 1's drill-04 — the only thing that's
different is *which side of the mTLS handshake* is running it. That's
today's whole point: in mutual TLS, the server doesn't get a pass on
verifying the client just because it's the one demanding the handshake, and
the client's cert doesn't get a pass on expiry just because it's not the
"main" certificate anyone thinks about. Every one of the four checks runs
against the client cert too, in the exact same order, by the exact same
logic — nginx's `ssl_verify_client on` triggers this same date check
internally on whatever cert the client presents, and an expired one fails
here just as surely as an expired server cert fails a browser's check.

**Fix:** you cannot edit a certificate's dates in place — doing so would
invalidate the signature that covers the whole document (Day 1, Exercise 1).
The only real fix is re-issuing:

```
docker compose run --rm toolbox bash ca/issue-server-cert.sh client01 client01
```

which gives you a fresh `notBefore`/`notAfter` window for the same identity.

## Lesson

Both sides of an mTLS handshake run the full four-check verification, and
expiry is enforced exactly as strictly on a client cert as on a server
cert — there is no "it's just for identifying myself, dates don't really
matter" exception anywhere in the protocol.

# Drill 04 — Solution: spotting an expired `notAfter`

## Hint ladder

1. **Nudge:** error code `10` is not cryptic once you know where OpenSSL
   documents its verify error codes — this is one of the most common ones
   you'll see in production.
2. **Tool to run:** pull just the validity window out of the cert, without
   the noise of the full dump:
   ```
   docker compose run --rm toolbox openssl x509 -in /work/drills/drill-04/expired.cert.pem -noout -dates
   ```
3. **Partial diagnosis:** compare `notAfter` against today's date. If
   `notAfter` is in the past, the certificate's validity window has already
   closed — independent of whether its signature is otherwise perfectly
   valid.

## Full walkthrough

```
docker compose run --rm toolbox openssl x509 -in /work/drills/drill-04/expired.cert.pem -noout -dates
# notBefore=Jan  1 00:00:00 2025 GMT
# notAfter=Jul  1 00:00:00 2025 GMT
```

`notAfter` is well in the past relative to any current date this course
runs on. Confirm programmatically with `-checkend` (checks whether the cert
will have expired within the given number of seconds from now; `0` means
"as of right now"):

```
docker compose run --rm toolbox openssl x509 -in /work/drills/drill-04/expired.cert.pem -noout -checkend 0
echo $?
# 1  (already expired)
```

This matches the original symptom's `openssl verify` error code exactly:
`error 10 ... certificate has expired` — `10` is OpenSSL's stable numeric
code for `X509_V_ERR_CERT_HAS_EXPIRED`, documented in the `verify(1)` man
page. The signature on this certificate could be flawless (and here, it
is — it's self-signed and internally consistent), which is precisely the
point: **check 2 (validity dates) is evaluated independently of check 1
(signature chain)**. Passing one says nothing about the other.

**Fix:** you cannot edit a certificate's dates in place — any change
invalidates its signature (Day 1's Exercise 1: the signature covers the
whole document, dates included). The only real fix is to have the issuing
CA **issue a new certificate** with a fresh `notBefore`/`notAfter` window
for the same subject and key (or a fresh key). Day 2's `issue-server-cert.sh`
is exactly the tool for that once you've built a CA.

## Lesson

An expired certificate fails verification outright regardless of how
cryptographically sound its signature is — dates and signatures are two
independent checks, and expiry is fixed only by issuing a new certificate,
never by editing the old one.

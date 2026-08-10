# Drill 03 — Solution: digest-algorithm mismatch

## Hint ladder

1. **Nudge:** the key is right, the message is untouched — so before you
   suspect the files at all, re-read your own command line, flag by flag.
2. **Tool to run:** nothing new to run yet — just compare the digest flag
   you used (`-sha512`) against whatever information you have about how
   `report.txt.sig` was actually produced. If you don't know, that's the
   gap to close: ask, or check for a note/README next to the signature.
3. **Partial diagnosis:** the signature was produced with `-sha256`, but you
   verified with `-sha512`. The digest algorithm you're verifying with does
   not match the one used to sign.

## Full walkthrough

Re-run with the matching digest algorithm:

```
docker compose run --rm toolbox openssl dgst -sha256 -verify /work/drills/drill-03/pubkey.pem \
    -signature /work/drills/drill-03/report.txt.sig /work/drills/drill-03/report.txt
# Verified OK
```

**Why the mismatch fails outright, not just "sometimes":** an RSA PKCS#1 v1.5
signature (what `openssl dgst -sign`/`-verify` produce and check by default)
doesn't just encrypt a raw digest — it encrypts a `DigestInfo` structure that
itself names which digest algorithm was used. When you verify with
`-sha512`, OpenSSL computes a fresh SHA-512 digest of `report.txt` and
expects the decrypted signature to contain a `DigestInfo` tagged SHA-512.
But the signature's `DigestInfo` is tagged SHA-256 (from the original
signing step) — a structural mismatch, not a "close but off" numeric one.
The verification fails immediately; the tool doesn't guess or fall back to
trying other algorithms.

## Lesson

The digest algorithm used to verify must exactly match the one used to
sign — `openssl dgst` never auto-detects it from the signature bytes, so a
flag typo or an undocumented signing convention is enough to produce the
same generic `Verification Failure` as a tampered file or a wrong key.

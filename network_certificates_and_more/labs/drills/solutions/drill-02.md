# Drill 02 — Solution: verifying a tampered message

## Hint ladder

1. **Nudge:** you're confident the public key is correct this time — so if
   the key isn't the problem, what's the other variable in the equation
   besides the signature itself?
2. **Tool to run:** hash the message you actually have, and get the sender
   to confirm — out of band — the hash of the exact content they originally
   signed:
   ```
   docker compose run --rm toolbox openssl dgst -sha256 /work/drills/drill-02/message.txt
   ```
3. **Partial diagnosis:** the digest you compute doesn't match the digest
   the sender confirms for the file they actually signed. The content of
   `message.txt` has changed since it was signed.

## Full walkthrough

Hash the message you have:

```
docker compose run --rm toolbox openssl dgst -sha256 /work/drills/drill-02/message.txt
# SHA256(/work/drills/drill-02/message.txt)= 873b4158cbf20b981756e7800341bc7bbdd2d98ad14312a4aa2281d204f340bd
```

The sender confirms, out of band, that the digest of what they actually
signed was `cb066b018f6c660910a5feff44357fd324c4edf7cb378b9f1807e080d98f0f4e`
— a different digest entirely. One byte was enough: the original said "pay
vendor 4,200.00 USD"; the file you have now says "pay vendor 9,200.00 USD."
Because of the avalanche effect (Day 1 theory), that single-character change
produces a completely unrelated SHA-256 digest.

**Fix:** you cannot repair a tampered file and re-verify it — the signature
was computed over specific bytes that no longer exist in your copy. You must
obtain a fresh, untampered copy of the message from the sender (or a
channel you trust) and verify *that* copy against the original signature:

```
docker compose run --rm toolbox openssl dgst -sha256 -verify /work/drills/drill-02/pubkey.pem \
    -signature /work/drills/drill-02/message.txt.sig /work/drills/drill-02/message.txt
# Verified OK  (once message.txt is restored to its original, signed content)
```

## Lesson

A signature protects the exact bytes it was computed over; any later edit
to the message — however small — breaks verification deterministically,
and the fix is always to restore the original content, never to "adjust"
the key or the signature.

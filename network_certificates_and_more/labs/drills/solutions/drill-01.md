# Drill 01 — Solution: verifying with the wrong public key

## Hint ladder

1. **Nudge:** `Verification Failure` doesn't automatically mean the message
   was tampered with. The verify operation has two inputs besides the
   signature — the message *and* the public key. Which one are you less
   sure about?
2. **Tool to run:** fingerprint the public key you were actually given, and
   get the signer to confirm their real key's fingerprint out of band (a
   call, a chat channel you already trust — anything other than the same
   channel that handed you the files):
   ```
   docker compose run --rm toolbox bash -c \
     "openssl rsa -pubin -in /work/drills/drill-01/pubkey.pem -noout -modulus | openssl sha256"
   ```
3. **Partial diagnosis:** the fingerprint you compute does not match what
   the signer confirms is their real key's fingerprint. `pubkey.pem` in this
   directory is not the manifest signer's actual public key.

## Full walkthrough

Fingerprint the key you were handed:

```
docker compose run --rm toolbox bash -c \
  "openssl rsa -pubin -in /work/drills/drill-01/pubkey.pem -noout -modulus | openssl sha256"
# edc36092760860e591e8bdf17bd690780e9b296c1f8d71ba9869aaa6158733d3
```

You contact the signer out of band and they confirm their real public key's
fingerprint is `458f00c688bd69b67b184088295054b32b3f4fe4b382e00f1c6a5dade44ca34a`
— a completely different key than the one you were handed as `pubkey.pem`.

**Fix:** obtain the correct public key from the signer (matching the
confirmed fingerprint above) and re-run verify against it:

```
docker compose run --rm toolbox openssl dgst -sha256 -verify /work/drills/drill-01/pubkey.pem \
    -signature /work/drills/drill-01/manifest.txt.sig /work/drills/drill-01/manifest.txt
# Verified OK  (once pubkey.pem is replaced with the correct key)
```

Nothing about `manifest.txt` or `manifest.txt.sig` was ever wrong — the
problem was entirely on the verifying side: the wrong key was substituted
for the real one.

## Lesson

A failed verification is not proof the message was tampered with — it can
just as easily mean you're checking against the wrong public key; always
confirm a public key's fingerprint out of band before concluding the content
itself was compromised.

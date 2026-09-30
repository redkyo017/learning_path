# Drill 02 — Symptom

You were handed `message.txt`, its signature `message.txt.sig`, and the
signer's public key `pubkey.pem` (all in this directory). You ran, from
`labs/`:

```
docker compose run --rm toolbox openssl dgst -sha256 -verify /work/drills/drill-02/pubkey.pem \
    -signature /work/drills/drill-02/message.txt.sig /work/drills/drill-02/message.txt
```

Observed output (the hex prefix on each error line is a thread id and varies
run to run):

```
20303FAFFFFF0000:error:02000068:rsa routines:ossl_rsa_verify:bad signature:../crypto/rsa/rsa_sign.c:430:
20303FAFFFFF0000:error:1C880004:Provider routines:rsa_verify:RSA lib:../providers/implementations/signature/rsa_sig.c:774:
Verification failure
```

Exit code: `1`

You are confident `pubkey.pem` is the correct public key for the signer —
you obtained it directly from them over a channel you trust.

# Drill 03 — Symptom

You were handed `report.txt`, its signature `report.txt.sig`, and the
signer's public key `pubkey.pem` (all in this directory). You ran, from
`labs/`:

```
docker compose run --rm toolbox openssl dgst -sha512 -verify /work/drills/drill-03/pubkey.pem \
    -signature /work/drills/drill-03/report.txt.sig /work/drills/drill-03/report.txt
```

Observed output (the hex prefix on each error line is a thread id and varies
run to run):

```
20201B97FFFF0000:error:02000068:rsa routines:ossl_rsa_verify:bad signature:../crypto/rsa/rsa_sign.c:430:
20201B97FFFF0000:error:1C880004:Provider routines:rsa_verify:RSA lib:../providers/implementations/signature/rsa_sig.c:774:
Verification failure
```

Exit code: `1`

You have not modified `report.txt` or `report.txt.sig` in any way, and you
are confident `pubkey.pem` is the correct public key for the signer.

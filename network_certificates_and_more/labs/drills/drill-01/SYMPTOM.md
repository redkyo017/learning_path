# Drill 01 — Symptom

You were handed `manifest.txt`, its signature `manifest.txt.sig`, and the
signer's supposed public key `pubkey.pem` (all in this directory). You ran,
from `labs/`:

```
docker compose run --rm toolbox openssl dgst -sha256 -verify /work/drills/drill-01/pubkey.pem \
    -signature /work/drills/drill-01/manifest.txt.sig /work/drills/drill-01/manifest.txt
```

Observed output (the hex prefix on each error line is a thread id and varies
run to run):

```
20D0399DFFFF0000:error:0200008A:rsa routines:RSA_padding_check_PKCS1_type_1:invalid padding:../crypto/rsa/rsa_pk1.c:79:
20D0399DFFFF0000:error:02000072:rsa routines:rsa_ossl_public_decrypt:padding check failed:../crypto/rsa/rsa_ossl.c:697:
20D0399DFFFF0000:error:1C880004:Provider routines:rsa_verify:RSA lib:../providers/implementations/signature/rsa_sig.c:774:
Verification failure
```

Exit code: `1`

You have not modified `manifest.txt` or `manifest.txt.sig` in any way.

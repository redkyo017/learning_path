# Drill 01 — Symptom

You were handed `manifest.txt`, its signature `manifest.txt.sig`, and the
signer's supposed public key `pubkey.pem` (all in this directory). You ran,
from `labs/`:

```
docker compose run --rm toolbox openssl dgst -sha256 -verify /work/drills/drill-01/pubkey.pem \
    -signature /work/drills/drill-01/manifest.txt.sig /work/drills/drill-01/manifest.txt
```

Observed output:

```
Verification Failure
```

Exit code: `1`

You have not modified `manifest.txt` or `manifest.txt.sig` in any way.

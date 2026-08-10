# Drill 03 — Symptom

You were handed `report.txt`, its signature `report.txt.sig`, and the
signer's public key `pubkey.pem` (all in this directory). You ran, from
`labs/`:

```
docker compose run --rm toolbox openssl dgst -sha512 -verify /work/drills/drill-03/pubkey.pem \
    -signature /work/drills/drill-03/report.txt.sig /work/drills/drill-03/report.txt
```

Observed output:

```
Verification Failure
```

Exit code: `1`

You have not modified `report.txt` or `report.txt.sig` in any way, and you
are confident `pubkey.pem` is the correct public key for the signer.

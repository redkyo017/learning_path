# Drill 02 — Symptom

You were handed `message.txt`, its signature `message.txt.sig`, and the
signer's public key `pubkey.pem` (all in this directory). You ran, from
`labs/`:

```
docker compose run --rm toolbox openssl dgst -sha256 -verify /work/drills/drill-02/pubkey.pem \
    -signature /work/drills/drill-02/message.txt.sig /work/drills/drill-02/message.txt
```

Observed output:

```
Verification Failure
```

Exit code: `1`

You are confident `pubkey.pem` is the correct public key for the signer —
you obtained it directly from them over a channel you trust.

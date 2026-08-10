# Drill 16 — Symptom

You copied `client01.cert.pem` (in this directory) from a teammate's machine
so you could try the mTLS lab without re-issuing your own client cert. You
run the same mTLS curl command from today's guided lab, swapping in this
cert and what you assume is its matching key:

```
docker compose run --rm toolbox curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
    --cert /work/drills/drill-16/client01.cert.pem \
    --key /work/drills/drill-16/client01.key.pem \
    --connect-to example.local:8443:nginx:443 \
    https://example.local:8443/
```

Observed output:

```
curl: (58) unable to set private key file: '/work/drills/drill-16/client01.key.pem' type PEM
```

Exit code: `58`

Nothing else in this directory besides `client01.cert.pem` and this
`SYMPTOM.md`.

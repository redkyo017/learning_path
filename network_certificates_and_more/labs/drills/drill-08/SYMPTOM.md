# Drill 08 — Symptom

You're troubleshooting a TLS error against `example.local`. You ran, from
`labs/`:

```
docker compose run --rm toolbox curl --cacert /work/drills/drill-08/chain.cert.pem \
    --connect-to example.local:8443:nginx:443 https://example.local:8443/
```

...and got a certificate error. You checked the chain itself offline
against the two files in this directory — `chain.cert.pem` (intermediate +
root, the trust anchor) and `example.local.expired.cert.pem` (the leaf
currently being served):

```
docker compose run --rm toolbox openssl verify -CAfile /work/drills/drill-08/chain.cert.pem \
    /work/drills/drill-08/example.local.expired.cert.pem
```

Observed output:

```
C = US, ST = CA, O = Drill Fixture Lab, OU = Servers, CN = example.local
error 10 at 0 depth lookup:certificate has expired
example.local.expired.cert.pem: verification failed: 10 (certificate has expired)
```

Exit code: `2`

You have not been told what today's date is inside the container.
`chain.cert.pem` and `example.local.expired.cert.pem` are a standalone
drill fixture, independent of the `ca/` workspace and the real
`example.local` cert you issue in this day's guided lab.

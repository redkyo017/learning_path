# Drill 05 — Symptom

You're troubleshooting a TLS error against `example.local`. You were
handed `root.cert.pem` (in this directory) as "the CA cert, use this to
verify." You tried:

```
docker compose run --rm toolbox curl --cacert /work/drills/drill-05/root.cert.pem \
    --connect-to example.local:8443:nginx:443 https://example.local:8443/
```

...and got a TLS handshake failure. Before touching the live server again,
you reproduced the exact same check offline, against the two files
actually sitting in this directory — `root.cert.pem` (the trust anchor you
were handed) and `example.local.cert.pem` (exactly what nginx is currently
sending). You ran, from `labs/`:

```
docker compose run --rm toolbox openssl verify -CAfile /work/drills/drill-05/root.cert.pem \
    /work/drills/drill-05/example.local.cert.pem
```

Observed output:

```
C = US, ST = CA, O = Drill Fixture Lab, OU = Servers, CN = example.local
error 20 at 0 depth lookup:unable to get local issuer certificate
example.local.cert.pem: verification failed: 20 (unable to get local issuer certificate)
```

Exit code: `2`

Note: `root.cert.pem` and `example.local.cert.pem` here are a standalone
drill fixture — their own throwaway mini-CA, independent of the `ca/`
workspace you're building in this day's guided lab. Nothing in this
directory has been altered after being issued.

# Drill 07 — Symptom

You're troubleshooting a TLS error against `example.local` and a colleague
tells you "just pass `--cacert`, that fixes it" — so you pointed `--cacert`
at the toolbox container's own system CA bundle (a real file that ships
with every Debian/Ubuntu image, installed by the `ca-certificates` package
already in this lab's toolbox):

```
docker compose run --rm toolbox curl --cacert /etc/ssl/certs/ca-certificates.crt \
    --connect-to example.local:8443:nginx:443 https://example.local:8443/
```

...and it still failed. nginx is, in fact, sending the complete, correct
chain (leaf + intermediate + root — nothing is missing on the server
side). To isolate the problem offline, you ran the equivalent check against
this directory's two files — `example.local.cert.pem` (the leaf, correctly
issued) and `chain.cert.pem` (intermediate + root, exactly what the server
sends, passed here as `-untrusted` to mirror what a peer supplies during a
handshake) — using a real, unrelated system CA bundle in place of
`--cacert`:

```
docker compose run --rm toolbox openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt \
    -untrusted /work/drills/drill-07/chain.cert.pem \
    /work/drills/drill-07/example.local.cert.pem
```

Observed output:

```
C = US, ST = CA, O = Drill Fixture Lab, OU = Root CA, CN = Drill Mini Root CA
error 19 at 2 depth lookup:self signed certificate in certificate chain
example.local.cert.pem: verification failed: 19 (self signed certificate in certificate chain)
```

Exit code: `2`

Nothing in `chain.cert.pem` or `example.local.cert.pem` has been altered —
both are a standalone drill fixture (their own throwaway mini-CA),
independent of the `ca/` workspace from this day's guided lab.

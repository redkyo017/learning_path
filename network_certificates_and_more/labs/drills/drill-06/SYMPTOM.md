# Drill 06 — Symptom

You're troubleshooting a TLS error against `example.local`. You ran, from
`labs/`:

```
docker compose run --rm toolbox curl --cacert /work/drills/drill-06/chain.cert.pem \
    --connect-to example.local:8443:nginx:443 https://example.local:8443/
```

...and got a certificate error, even though you're confident the CA chain
itself is sound (you built it yourself, and the trust anchor is right
there in `--cacert`). To isolate exactly what's wrong, you ran the
CA-chain check offline against the two files in this directory —
`chain.cert.pem` (intermediate + root, the same trust anchor) and
`other.local.cert.pem` (the cert currently being served):

```
docker compose run --rm toolbox openssl verify -CAfile /work/drills/drill-06/chain.cert.pem \
    /work/drills/drill-06/other.local.cert.pem
```

Observed output:

```
other.local.cert.pem: OK
```

Exit code: `0`

The chain check passes cleanly. And yet the live `curl` against
`example.local` still fails with a certificate error.

`chain.cert.pem` and `other.local.cert.pem` are a standalone drill
fixture, independent of the `ca/` workspace and the real `example.local`
cert you issue in this day's guided lab.

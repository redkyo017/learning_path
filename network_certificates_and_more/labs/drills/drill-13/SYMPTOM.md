# Drill 13 — Symptom

A teammate hands you `client01-wrongca.cert.pem` and `client01-wrongca.key.pem`
(both in this directory) and says "this is your client identity for the mTLS
service, go ahead and connect." You point your mTLS curl command at
`nginx-mtls.conf`'s server (the same one from today's guided lab) using this
cert/key pair instead of the `client01` cert you issued yourself from the
lab's real CA:

```
docker compose run --rm toolbox curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
    --cert /work/drills/drill-13/client01-wrongca.cert.pem \
    --key /work/drills/drill-13/client01-wrongca.key.pem \
    --connect-to example.local:8443:nginx:443 \
    https://example.local:8443/
```

Observed output:

```
curl: (35) OpenSSL SSL_connect: SSL_ERROR_SSL in connection to example.local:8443
```

nginx's own error log (`docker compose logs nginx`) shows a line resembling:

```
[info] ... SSL_do_handshake() failed (SSL: error:...:SSL alert number 48) while SSL handshaking, client: ...
```

The curl command against the server's *own* certificate (no `--cert`/`--key`
at all) still works fine with the same `--cacert`, so the server side of the
handshake is not in question here. This drill is entirely about the client
side.

Also present in this directory: `rogue-ca.cert.pem` and
`reference-ca.cert.pem`. You have not been told what either of those is for.

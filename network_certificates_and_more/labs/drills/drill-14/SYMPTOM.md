# Drill 14 — Symptom

You dig up an old client identity you issued for yourself a while back —
`client01-expired.cert.pem` and `client01-expired.key.pem`, both in this
directory — and try to use it against the mTLS service from today's guided
lab. The connection fails. Before touching nginx or the network at all, you
decide to sanity-check the certificate itself the same way `openssl verify`
does internally, using a CA that's known to have issued it
(`reference-ca.cert.pem`, also in this directory — this is a small
standalone CA built just for this drill, unrelated to your real lab CA
under `ca/`, so this check works fully offline without touching your real
setup):

```
docker compose run --rm toolbox openssl verify -CAfile /work/drills/drill-14/reference-ca.cert.pem \
    /work/drills/drill-14/client01-expired.cert.pem
```

Observed output:

```
C = US, ST = CA, O = TLS Mastery Lab, OU = Clients, CN = client01
error 10 at 0 depth lookup: certificate has expired
client01-expired.cert.pem: verification failed: 10 (certificate has expired)
```

Exit code: `2`

You have not been told what today's date is inside the container.

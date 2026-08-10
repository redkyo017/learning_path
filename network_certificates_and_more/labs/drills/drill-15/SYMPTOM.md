# Drill 15 — Symptom

`client01-skew.cert.pem` (in this directory, with its matching
`client01-skew.key.pem`) is a client identity you issued recently. Nothing
about the certificate itself has changed since you issued it. You verify it
against `reference-ca.cert.pem` (a small standalone CA shipped only for this
drill — unrelated to your real lab CA under `ca/`) twice, back to back, with
no other change in between:

```
docker compose run --rm toolbox openssl verify -CAfile /work/drills/drill-15/reference-ca.cert.pem \
    /work/drills/drill-15/client01-skew.cert.pem
```

Observed output (first run):

```
client01-skew.cert.pem: OK
```

Then, still inside the same running container, someone else on your team —
debugging an unrelated NTP issue on the host — jumps the container's clock
forward and asks you to re-check the same file. You add nothing to the
command except `-attime`, passing the epoch timestamp the container now
reports as "current time" (`1829562708`, roughly 500 days from when the cert
was issued):

```
docker compose run --rm toolbox openssl verify -attime 1829562708 \
    -CAfile /work/drills/drill-15/reference-ca.cert.pem \
    /work/drills/drill-15/client01-skew.cert.pem
```

Observed output (second run):

```
C = US, ST = CA, O = TLS Mastery Lab, OU = Clients, CN = client01-skew
error 10 at 0 depth lookup: certificate has expired
client01-skew.cert.pem: verification failed: 10 (certificate has expired)
```

You did not touch the certificate file between the two runs — you checked
its checksum to be sure.

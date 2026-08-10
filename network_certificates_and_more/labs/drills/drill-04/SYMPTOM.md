# Drill 04 — Symptom

You were handed `expired.cert.pem` (in this directory) and told a service is
about to start using it. You ran, from `labs/`:

```
docker compose run --rm toolbox openssl verify -CAfile /work/drills/drill-04/expired.cert.pem \
    /work/drills/drill-04/expired.cert.pem
```

Observed output:

```
C = US, ST = CA, O = TLS Mastery Lab, CN = expired.local
error 10 at 1 depth lookup: certificate has expired
C = US, ST = CA, O = TLS Mastery Lab, CN = expired.local
error 10 at 0 depth lookup: certificate has expired
/work/drills/drill-04/expired.cert.pem: verification failed: 10 (certificate has expired)
```

Exit code: `2`

You have not been told what today's date is inside the container.

# Capstone 03 — Symptom

An old internal reporting cert turns up in a config a teammate is about to
reuse for a new service. Before plugging it in, you check it. You ran,
from `labs/`:

```
docker compose run --rm toolbox bash /work/drills/capstone/capstone-03/repro.sh
```

That script issues `old-report.local` from your real intermediate CA with
a validity window entirely in the past, then runs:

```
openssl verify -CAfile /work/ca/intermediate/certs/ca-chain.cert.pem \
    /work/ca/intermediate/certs/old-report.local.cert.pem
```

Observed output:

```
C = US, ST = CA, O = TLS Mastery Lab, OU = Servers, CN = old-report.local
error 10 at 0 depth lookup: certificate has expired
old-report.local.cert.pem: verification failed: 10 (certificate has expired)
```

Exit code: `2`

`openssl x509 -in /work/ca/intermediate/certs/old-report.local.cert.pem -noout -dates`
prints a `notAfter` date nearly two years before today.

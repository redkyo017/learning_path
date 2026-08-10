# Capstone 06 — Symptom

A contractor sends you "your client01 identity" as a zip of a `.cert.pem`
and `.key.pem` ahead of an mTLS integration test. The CN in the cert really
does say `client01`. You ran, from `labs/`:

```
docker compose run --rm toolbox bash /work/drills/capstone/capstone-06/repro.sh
```

That script stands up a throwaway `openssl s_server` (playing the role of
Day 4's mTLS-enabled nginx: it requires and verifies a client certificate
against your real `ca-chain.cert.pem`), then presents the contractor's
`client01` cert/key pair to it via `curl --cert/--key`.

Observed output:

```
curl: (35) OpenSSL/3.x: error:0A000418:SSL routines::tlsv1 alert unknown ca
```

`openssl x509 -in /work/drills/capstone/capstone-06/tmp/client01-imposter.cert.pem
-noout -subject -issuer` prints:

```
subject=O = Definitely Not TLS Mastery Lab, CN = client01
issuer=O = Definitely Not TLS Mastery Lab, CN = Imposter Testing CA
```

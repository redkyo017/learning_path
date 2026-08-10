# Capstone 09 — Symptom

Security asks you to prove that a compromised-key incident on
`example.local` would actually be caught before `notAfter`. You go looking
for where that would show up in the handshake itself. You ran, from
`labs/`:

```
docker compose run --rm toolbox bash /work/drills/capstone/capstone-09/repro.sh
```

That script serves your real `example.local` certificate from a plain
`openssl s_server` (no extra flags for revocation of any kind), then
runs:

```
openssl s_client -connect 127.0.0.1:8600 -servername example.local \
    -CAfile /work/ca/intermediate/certs/ca-chain.cert.pem \
    -status </dev/null
```

Observed output (filtered to the relevant lines):

```
OCSP response: no response sent
Verify return code: 0 (ok)
```

The handshake completed. `Verify return code: 0` is the same value every
prior successful connection in this course has reported.

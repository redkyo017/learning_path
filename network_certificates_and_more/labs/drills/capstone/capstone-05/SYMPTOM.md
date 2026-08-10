# Capstone 05 — Symptom

A hardening guide you're following says to force ECDSA cipher suites
"because they're faster than RSA." You add `--ciphers
ECDHE-ECDSA-AES128-GCM-SHA256` to your client's TLS 1.2 connection call
and it stops connecting entirely — to a server that worked fine a minute
ago. You ran, from `labs/`:

```
docker compose run --rm toolbox bash /work/drills/capstone/capstone-05/repro.sh
```

That script starts a throwaway `openssl s_server` pinned to TLS 1.2,
presenting your real (RSA-keyed) `example.local` certificate, then runs:

```
curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --connect-to example.local:8600:127.0.0.1:8600 \
     --tlsv1.2 --tls-max 1.2 \
     --ciphers ECDHE-ECDSA-AES128-GCM-SHA256 \
     https://example.local:8600/
```

Observed output:

```
curl: (35) OpenSSL/3.x: error:0A000410:SSL routines::sslv3 alert handshake failure
```

`openssl x509 -in /work/ca/intermediate/certs/example.local.cert.pem -noout -text
| grep "Public Key Algorithm"` prints `rsaEncryption`.

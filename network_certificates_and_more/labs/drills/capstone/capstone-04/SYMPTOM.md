# Capstone 04 — Symptom

Ops just hardened a server to require TLS 1.3 only, per a new security
policy. An older integration that's never been touched since it was written
starts failing against it immediately. You ran, from `labs/`:

```
docker compose run --rm toolbox bash /work/drills/capstone/capstone-04/repro.sh
```

That script starts a throwaway `openssl s_server` presenting your real
`example.local` certificate, configured to speak TLS 1.3 only, then runs
the older integration's exact client call:

```
curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --connect-to example.local:8600:127.0.0.1:8600 \
     --tls-max 1.2 \
     https://example.local:8600/
```

Observed output:

```
curl: (35) OpenSSL/3.x: error:0A000102:SSL routines::unsupported protocol
```

No certificate was ever printed, and the server process exited immediately
after the one connection attempt.

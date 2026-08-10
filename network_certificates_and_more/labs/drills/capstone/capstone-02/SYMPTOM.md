# Capstone 02 — Symptom

A colleague says the new customer portal is reachable at
`https://portal.example.local/` and should use the same certificate
`example.local` has always used ("it's the same server, just a new
vhost name"). You ran, from `labs/`:

```
docker compose run --rm toolbox bash /work/drills/capstone/capstone-02/repro.sh
```

That script serves your real, unmodified `example.local` certificate from
a throwaway `openssl s_server`, then runs:

```
curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --connect-to portal.example.local:8600:127.0.0.1:8600 \
     https://portal.example.local:8600/
```

Observed output:

```
curl: (60) SSL: no alternative certificate subject name matches target
host name 'portal.example.local'
```

`openssl x509 -in /work/ca/intermediate/certs/example.local.cert.pem -noout -text
| grep -A1 'Subject Alternative Name'` shows exactly one entry:
`DNS:example.local`.

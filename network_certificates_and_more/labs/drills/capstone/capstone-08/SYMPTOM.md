# Capstone 08 — Symptom

Someone left a note that "the security team was testing something on the
shared toolbox image, connect to `vault.internal.local` and tell me if
anything looks off." You ran, from `labs/`:

```
docker compose run --rm toolbox bash /work/drills/capstone/capstone-08/repro.sh
```

That script's final command is a plain `curl -v` against
`https://vault.internal.local:8600/` — no `--cacert` flag at all.

Observed output:

```
* subject: O=SecureVault Trust Services; CN=vault.internal.local
* issuer: O=SecureVault Trust Services; CN=SecureVault Trust Root G2
* SSL certificate verify ok.
> GET / HTTP/1.1
< HTTP/1.1 200 ok
```

The connection succeeded, with no certificate warning of any kind.

`grep -c "TLS Mastery" /etc/ssl/certs/ca-certificates.crt` inside the same
container returns `0` — this container was never told to trust anything
from your real `ca/`. `openssl x509 -in /work/ca/root/certs/ca.cert.pem
-noout -subject` (your real root) prints `CN = TLS Mastery Root CA`.

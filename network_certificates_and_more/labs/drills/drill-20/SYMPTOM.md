# Drill 20 — Symptom

You're in a hurry and skip straight to the guided lab's Part B step 3,
without doing step 2 (extracting `pebble.minica.pem`) or adding the
`-e REQUESTS_CA_BUNDLE=...` flag — you figure certbot will just work
against `https://pebble:14000/dir` the same way it works against the
real, publicly trusted Let's Encrypt endpoint:

```
docker compose run --rm --entrypoint certbot \
    toolbox certonly --standalone --http-01-port 5002 \
    --preferred-challenges http -n \
    --server https://pebble:14000/dir \
    -d test.local --agree-tos -m a@b.c --no-eff-email \
    --config-dir /work/acme/certbot/config \
    --work-dir /work/acme/certbot/work \
    --logs-dir /work/acme/certbot/logs
```

Observed output:

```
An unexpected error occurred:
requests.exceptions.SSLError: HTTPSConnectionPool(host='pebble', port=14000): Max retries exceeded with url: /dir (Caused by SSLError(SSLCertVerificationError(1, '[SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: unable to get local issuer certificate (_ssl.c:1007)')))
Ask for help or search for solutions at https://community.letsencrypt.org. Please include the logs from
/work/acme/certbot/logs.
```

`env-snapshot.txt` in this directory shows the environment the command
above actually ran with.

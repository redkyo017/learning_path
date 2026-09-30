# Capstone 07 — Symptom

You're issuing a certificate for a brand-new test domain against this
lab's Pebble server, reusing Day 5's exact workflow, but for a domain you
haven't registered with anything yet. You ran, from `labs/` (with `pebble`
and `challtestsrv` already up):

```
docker compose run --rm --entrypoint certbot \
    -e REQUESTS_CA_BUNDLE=/work/acme/pebble.minica.pem \
    toolbox certonly --standalone --http-01-port 5002 \
    --preferred-challenges http -n \
    --server https://pebble:14000/dir \
    -d billing.local --agree-tos -m a@b.c --no-eff-email \
    --config-dir /work/tmp/capstone-07/config \
    --work-dir /work/tmp/capstone-07/work \
    --logs-dir /work/tmp/capstone-07/logs
```

Observed output (token shortened):

```
Saving debug log to /work/tmp/capstone-07/logs/letsencrypt.log
Account registered.
Requesting a certificate for billing.local

Certbot failed to authenticate some domains (authenticator: standalone). The Certificate Authority reported these problems:
  Domain: billing.local
  Type:   connection
  Detail: Get "http://billing.local:5002/.well-known/acme-challenge/3_8VtPci...": could not resolve URL "http://billing.local:5002/.well-known/acme-challenge/3_8VtPci..."

Hint: The Certificate Authority failed to download the challenge files from the temporary standalone webserver started by Certbot on port 5002. Ensure that the listed domains point to this machine and that it can accept inbound connections from the internet.

Some challenges have failed.
Ask for help or search for solutions at https://community.letsencrypt.org. See the logfile /work/tmp/capstone-07/logs/letsencrypt.log or re-run Certbot with -v for more details.
```

Exit code: `1`.

Certbot's own standalone server started and bound port `5002` without any
complaint, and its `Hint:` blames that server. `test.local` (Day 5's
domain) still issues successfully against this exact same
Pebble/challtestsrv setup, using this exact same command shape with only
the `-d` value changed. `Type: connection` is also what drill-17 showed.

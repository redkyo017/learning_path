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
    --config-dir /work/acme/certbot/config \
    --work-dir /work/acme/certbot/work \
    --logs-dir /work/acme/certbot/logs
```

Observed output:

```
Simulating a certificate request for billing.local
Requesting a certificate for billing.local

Certbot failed to authenticate some domains (authenticator: standalone). The Certificate Authority reported these problems:
  Domain: billing.local
  Type:   dns
  Detail: DNS problem: NXDOMAIN looking up A for billing.local - check that a DNS record exists for this domain

Hint: The Certificate Authority failed to download the challenge files from
the temporary standalone webserver started by Certbot on port 80. Ensure
that the listed domains point to this machine and that it can accept
inbound connections from the internet.

Some challenges have failed.
Ask for help or search for solutions at https://community.letsencrypt.org.
```

Certbot's own standalone server started and bound port `5002` without any
complaint — the failure happened before Pebble ever tried to reach it.
`test.local` (Day 5's domain) still issues successfully against this exact
same Pebble/challtestsrv setup, using this exact same command shape with
only the `-d` value changed.

*(This capstone's output is reasoned from Pebble's and certbot's own
documented DNS-problem error format, not from a live run — see the task
report. Confirm the exact wording live before trusting it verbatim.)*

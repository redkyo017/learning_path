# Drill 17 — Symptom

You're running today's guided lab from memory instead of copy-pasting it,
and you're pretty sure `--http-01-port` was just a "nice to have" flag in
the example, so you leave it out:

```
docker compose run --rm --entrypoint certbot \
    -e REQUESTS_CA_BUNDLE=/work/acme/pebble.minica.pem \
    toolbox certonly --standalone \
    --preferred-challenges http -n \
    --server https://pebble:14000/dir \
    -d test.local --agree-tos -m a@b.c --no-eff-email \
    --config-dir /work/acme/certbot/config \
    --work-dir /work/acme/certbot/work \
    --logs-dir /work/acme/certbot/logs
```

Observed output:

```
Simulating a certificate request for test.local
Requesting a certificate for test.local

Certbot failed to authenticate some domains (authenticator: standalone). The Certificate Authority reported these problems:
  Domain: test.local
  Type:   connection
  Detail: Fetching http://test.local:5002/.well-known/acme-challenge/_-example-token-_:
  Connection refused

Hint: The Certificate Authority failed to download the challenge files from
the temporary standalone webserver started by Certbot on port 80. Ensure
that the listed domains point to this machine and that it can accept
inbound connections from the internet.

Some challenges have failed.
Ask for help or search for solutions at https://community.letsencrypt.org.
```

certbot itself never reported a bind error — whatever it bound to, it
bound successfully. The relevant config excerpt this lab actually ships,
`pebble-config-excerpt.json` in this directory, is included for reference.

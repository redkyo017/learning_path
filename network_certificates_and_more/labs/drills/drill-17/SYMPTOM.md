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
    --config-dir /work/tmp/drill-17/config \
    --work-dir /work/tmp/drill-17/work \
    --logs-dir /work/tmp/drill-17/logs
```

(This drill keeps its own certbot state under `tmp/drill-17/`. Reusing
the guided lab's `acme/certbot/` would just find the existing `test.local`
certificate and print `Certificate not yet due for renewal`. To reproduce
the symptom again after fixing it, `rm -rf tmp/drill-17` first.)

Observed output (token shortened):

```
Saving debug log to /work/tmp/drill-17/logs/letsencrypt.log
Account registered.
Requesting a certificate for test.local

Certbot failed to authenticate some domains (authenticator: standalone). The Certificate Authority reported these problems:
  Domain: test.local
  Type:   connection
  Detail: Get "http://test.local:5002/.well-known/acme-challenge/lNzrIyE0...": dial tcp 10.77.30.10:5002: connect: connection refused

Hint: The Certificate Authority failed to download the challenge files from the temporary standalone webserver started by Certbot on port 80. Ensure that the listed domains point to this machine and that it can accept inbound connections from the internet.

Some challenges have failed.
Ask for help or search for solutions at https://community.letsencrypt.org. See the logfile /work/tmp/drill-17/logs/letsencrypt.log or re-run Certbot with -v for more details.
```

Exit code: `1`.

certbot itself never reported a bind error — whatever it bound to, it
bound successfully. The relevant config excerpt this lab actually ships,
`pebble-config-excerpt.json` in this directory, is included for reference.

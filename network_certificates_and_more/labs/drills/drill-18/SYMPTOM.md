# Drill 18 — Symptom

You read Exercise 4's DNS-01 discussion in today's `day05.md` and decided
you'd rather test DNS-01 than HTTP-01 for today's guided-lab issuance, so
you add `--preferred-challenges dns` to the same certbot invocation the
guided lab otherwise uses, without changing anything else:

```
docker compose run --rm --entrypoint certbot \
    -e REQUESTS_CA_BUNDLE=/work/acme/pebble.minica.pem \
    toolbox certonly --standalone --http-01-port 5002 \
    --preferred-challenges dns -n \
    --server https://pebble:14000/dir \
    -d test.local --agree-tos -m a@b.c --no-eff-email \
    --config-dir /work/tmp/drill-18/config \
    --work-dir /work/tmp/drill-18/work \
    --logs-dir /work/tmp/drill-18/logs
```

(This drill keeps its own certbot state under `tmp/drill-18/`. Reusing
the guided lab's `acme/certbot/` would just find the existing `test.local`
certificate and print `Certificate not yet due for renewal`.)

Observed output:

```
Saving debug log to /work/tmp/drill-18/logs/letsencrypt.log
Account registered.
Requesting a certificate for test.local
None of the preferred challenges are supported by the selected plugin
Ask for help or search for solutions at https://community.letsencrypt.org. See the logfile /work/tmp/drill-18/logs/letsencrypt.log or re-run Certbot with -v for more details.
```

Exit code: `1`. Pebble never reported a validation failure; certbot
stopped on its own side.

Also present in this directory: `authz-challenges-excerpt.json`, a
trimmed copy of the `challenges` array Pebble includes on the
authorization object it hands back for `test.local` during order
creation — you have not been told what to do with it.

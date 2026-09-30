# Drill 19 — Symptom

Right after finishing the guided lab's Part B (you have a freshly issued
`test.local` certificate), you want to prove your renewal automation
actually works before you rely on it, so you set up a deploy hook and run
the same `renew` subcommand a real cron job would run:

```
docker compose run --rm --entrypoint certbot \
    -e REQUESTS_CA_BUNDLE=/work/acme/pebble.minica.pem \
    toolbox renew --deploy-hook "echo renewed >> /work/acme/renewed.log" \
    --config-dir /work/acme/certbot/config \
    --work-dir /work/acme/certbot/work \
    --logs-dir /work/acme/certbot/logs
```

Observed output:

```
Saving debug log to /work/acme/certbot/logs/letsencrypt.log

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Processing /work/acme/certbot/config/renewal/test.local.conf
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Certificate not yet due for renewal

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
The following certificates are not due for renewal yet:
  /work/acme/certbot/config/live/test.local/fullchain.pem expires on 2026-12-29 (skipped)
No renewals were attempted.
No hooks were run.
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```

Exit code: `0`.

```
docker compose run --rm toolbox cat /work/acme/renewed.log
cat: /work/acme/renewed.log: No such file or directory
```

`renewal-conf-excerpt.conf` in this directory is a trimmed copy of the
`[renewalparams]` section certbot itself wrote into
`config/renewal/test.local.conf` when Part B first issued the cert.

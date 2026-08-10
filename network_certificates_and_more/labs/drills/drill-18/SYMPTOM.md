# Drill 18 — Symptom

You read Exercise 4's DNS-01 discussion in today's `day05.md` and decided
you'd rather test DNS-01 than HTTP-01 for today's guided-lab issuance, so
you add `--preferred-challenges dns` to the same certbot invocation the
guided lab otherwise uses, without changing anything else:

```
docker compose run --rm --entrypoint certbot \
    -e REQUESTS_CA_BUNDLE=/work/acme/pebble.minica.pem \
    toolbox certonly --standalone --preferred-challenges dns -n \
    --server https://pebble:14000/dir \
    -d test.local --agree-tos -m a@b.c --no-eff-email \
    --config-dir /work/acme/certbot/config \
    --work-dir /work/acme/certbot/work \
    --logs-dir /work/acme/certbot/logs
```

Observed output:

```
Requesting a certificate for test.local

Certbot failed to authenticate some domains (authenticator: standalone). The Certificate Authority reported these problems:
  Domain: test.local
  Type:   ...
  Detail: ...

Some challenges have failed.
```

along with, earlier in the same run, a line resembling:

```
Client with the currently selected authenticator does not support any
combination of challenges that will satisfy the CA.
```

Also present in this directory: `authz-challenges-excerpt.json`, a
trimmed copy of the `challenges` array Pebble includes on the
authorization object it hands back for `test.local` during order
creation — you have not been told what to do with it.

# Drill 10 — Symptom

With Day 2's nginx already running (`docker compose up -d nginx`), you ran
the reproduction script in this directory, from `labs/`:

```
docker compose run --rm toolbox bash /work/drills/drill-10/repro.sh
```

That script runs one `curl` command against `example.local:8443`, capped
to TLS 1.2 (`--tlsv1.2 --tls-max 1.2`) and restricted to two cipher
suites: `ECDHE-ECDSA-AES256-GCM-SHA384` and `ECDHE-ECDSA-AES128-GCM-SHA256`.

Observed output:

```
curl: (35) OpenSSL/3.x: error:0A000410:SSL routines::sslv3 alert handshake failure
```

Exit code: `35`

You have not changed anything about nginx's configuration or the
certificate it serves. The same `curl` command, without the `--ciphers`
restriction, works fine against the same server.

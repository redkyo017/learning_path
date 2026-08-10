# Drill 09 — Symptom

You stood up a throwaway test server and a test client, using the
reproduction script in this directory. You ran, from `labs/`:

```
docker compose run --rm toolbox bash /work/drills/drill-09/repro.sh
```

That script, in order:
1. Starts `openssl s_server` on port `8444`, serving the `example.local`
   certificate, with `-no_ssl3 -no_tls1 -no_tls1_1` — i.e. a floor of
   TLS 1.2 and up.
2. One second later, runs `curl --tlsv1.0 --tls-max 1.1` against it — i.e.
   a client capped at TLS 1.1 maximum.

Observed output (curl's half):

```
curl: (35) OpenSSL/3.x: error:0A000102:SSL routines::unsupported protocol
```

Exit code: `35`

No certificate was ever printed, no HTTP response body appeared, and the
server process exited immediately after the one connection attempt.

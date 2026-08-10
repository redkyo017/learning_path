# Drill 12 — Symptom

You stood up a throwaway test server and a test client, using the
reproduction script in this directory. You ran, from `labs/`:

```
docker compose run --rm toolbox bash /work/drills/drill-12/repro.sh
```

That script, in order:
1. Starts `openssl s_server` on port `8445`, serving the `example.local`
   certificate, with `-alpn h2` — i.e. it will only ever select the ALPN
   protocol `h2`.
2. One second later, runs `openssl s_client -alpn http/1.1` against it —
   i.e. a client offering only `http/1.1`.

Observed output (relevant excerpt from the client's side):

```
error:0A000042:SSL routines::tlsv1 alert no application protocol
```

The connection closed before any certificate chain was printed. The
server process exited immediately after the one connection attempt.

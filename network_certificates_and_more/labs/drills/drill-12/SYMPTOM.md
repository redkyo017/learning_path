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

Observed output (relevant excerpt — the server's error line, then the
client's):

```
no peer certificate available
...
...:error:0A0000EB:SSL routines:tls_handle_alpn:no application protocol:...
...:error:0A000460:SSL routines:ssl3_read_bytes:reason(1120):../ssl/record/rec_layer_s3.c:1599:SSL alert number 120
```

`s_client` also printed `Verification: OK` and `Verify return code: 0 (ok)`
— with no certificate received, there was nothing to fail. The connection
closed before any certificate chain was printed. The server process exited
immediately after the one connection attempt, and the script exited `0`
(it ends with `|| true`).

# Drill 11 — Symptom

With Day 2's nginx already running (`docker compose up -d nginx`), you ran
the reproduction script in this directory, from `labs/`:

```
docker compose run --rm toolbox bash /work/drills/drill-11/repro.sh
```

That script runs one `curl` command against a hostname, `wrong.local`,
that has never been mentioned anywhere in this lab before now — no
certificate has ever been issued for it, and nginx has no server block
naming it.

Observed output:

```
curl: (60) SSL: no alternative certificate subject name matches target host name 'wrong.local'
```

Exit code: `60`

The TLS handshake itself did not report any error — no alert, no
"unsupported protocol," no "handshake failure." A certificate genuinely
came back from the server, chained to a root your `--cacert` trusts. The
failure surfaced only after that.

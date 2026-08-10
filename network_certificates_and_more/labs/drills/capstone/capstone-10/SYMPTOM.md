# Capstone 10 — Symptom

A monitoring dashboard that pins `secure-api.local`'s public key (set up
months ago, "for extra security") suddenly starts reporting the service as
untrusted, right after ops did a routine certificate renewal — same CA,
same name, nothing anyone would call an incident. You ran, from `labs/`:

```
docker compose run --rm toolbox bash /work/drills/capstone/capstone-10/repro.sh
```

That script records the pin from the *first* issuance of
`secure-api.local`, re-issues `secure-api.local` again (a normal renewal),
serves the *new* cert, then runs the dashboard's exact check — the *old*
pin against the *new* certificate:

```
curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --pinnedpubkey "sha256//<the OLD pin>" \
     --connect-to secure-api.local:8600:127.0.0.1:8600 \
     https://secure-api.local:8600/
```

Observed output:

```
curl: (90) SSL: public key does not match pinned public key!
```

`curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem --connect-to
secure-api.local:8600:127.0.0.1:8600 https://secure-api.local:8600/` (same
connection, `--pinnedpubkey` simply omitted) succeeds without any
complaint.

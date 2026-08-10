# Drill 20 — Solution: certbot doesn't trust Pebble's ACME endpoint

## Hint ladder

1. **Nudge:** this looks like a network failure but read the exception
   class name closely — `SSLError` /
   `CERTIFICATE_VERIFY_FAILED` / `unable to get local issuer certificate`.
   Which of Day 1's four checks talks about "local issuer certificate,"
   and on whose behalf is it running here?
2. **Tool to run:** check what certbot's underlying `requests` library
   was actually told to trust:
   ```
   docker compose run --rm toolbox cat /work/drills/drill-20/env-snapshot.txt
   ```
3. **Partial diagnosis:** certbot never got far enough to even ask Pebble
   about `test.local` — it failed while trying to establish the HTTPS
   connection to Pebble's own directory endpoint itself, before any ACME
   protocol exchange happened at all.

## Full walkthrough

`unable to get local issuer certificate` is Python's `ssl`/OpenSSL
reporting exactly the same failure Day 1 and Day 4 have both already
named directly: **check 4, trust anchor.** Pebble's `:14000` endpoint
presents an HTTPS certificate signed by Pebble's own bundled test CA
(`pebble.minica.pem`) — a CA that has never been added to any store
certbot's process actually consults. certbot's `acme`/`requests` stack
keeps its **own** bundle (via `certifi`, per Day 4's theory section on
per-process trust stores), completely independent of the `toolbox`
container's OS-level `/etc/ssl/certs/ca-certificates.crt` — and Pebble's
test root was never added to that bundle either, by design (per the
`pebble` project's own warning: never add it to any real trust store,
system-wide or otherwise).

`env-snapshot.txt` confirms exactly what's missing: no `REQUESTS_CA_BUNDLE`
anywhere in the environment this command ran with, which is the specific
override the `requests` library checks before falling back to its
`certifi` default. Without it, `requests` verifies Pebble's certificate
against a bundle that was never going to contain a private lab CA's test
root, check 4 fails, and the TLS connection to Pebble's own directory
endpoint is refused before certbot can even begin the ACME exchange for
`test.local` — this failure has nothing to do with `test.local`'s own
certificate at all; it's entirely about whether certbot trusts **Pebble
itself**.

**Fix:** run the extraction and pass the bundle, exactly as the guided
lab's Part B steps 2–3 do:

```
docker compose cp pebble:/test/certs/pebble.minica.pem acme/pebble.minica.pem
docker compose run --rm --entrypoint certbot \
    -e REQUESTS_CA_BUNDLE=/work/acme/pebble.minica.pem \
    toolbox certonly --standalone --http-01-port 5002 ...
```

**What NOT to do:** reach for `--no-verify-ssl` or any other
"just skip verification" flag. That would disable check 4 for the *entire*
HTTPS connection to Pebble, not just its self-signed-in-context root —
exactly the anti-pattern the guided lab's Part B and `labs/acme/README.md`
both explicitly warn against, and the same lesson Day 4 taught about never
confusing "I don't know how to configure trust properly" with "trust
doesn't matter here."

## Lesson

An ACME client talks to **two** different certificates during any
issuance: the CA's own TLS certificate on its API endpoint (which you, the
client, must trust to talk to the CA at all) and the certificate the CA is
about to *issue* you (which is a completely separate trust decision, made
by whoever later connects to your service). Getting the first one wrong
fails before the ACME protocol itself even starts — and it's exactly the
same check-4 mechanic as every other trust-anchor failure this course has
walked through, just applied to the automation tool's own outbound
connection instead of a browser's or curl's.

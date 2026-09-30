# Capstone 07 — Solution: the challenge never got far enough to hit the port at all

## Hint ladder

1. **Nudge:** the `Type` field is `connection`, same as drill-17. Don't
   stop there. Read the `Detail:` line word by word: is it complaining
   about a port, or about something that has to happen before any port
   is dialed?
2. **Tool to run:** compare against a domain that's known to work. Run
   the same command with `-d test.local` (same `tmp/capstone-07/` dirs)
   and put the two `Detail:` lines side by side. (Don't reach for
   `getent hosts` inside `toolbox`: toolbox resolves through Docker's DNS,
   which knows neither name. Only Pebble asks challtestsrv.)
3. **Partial diagnosis:** one `Detail:` contains `dial tcp <IP>:5002`, the
   other `could not resolve URL "http://billing.local:5002/..."` — no IP
   anywhere in it. Pebble has to turn a name into an address before it
   can connect to anything.

## Full walkthrough

`could not resolve URL "http://billing.local:5002/..."` is a
**name resolution** failure. Pebble asked its DNS server (challtestsrv at
`10.77.30.30:8053`, per the `-dnsserver` wiring in `labs/acme/README.md`)
for `billing.local` and got no address back, so it never dialed anything —
there is no IP in the `Detail` at all. Contrast drill-17: `dial tcp 10.77.30.10:5002: connect: connection
refused` — the name resolved fine, and the failure was *reaching* that
address on the port.

Pebble files both under `Type: connection`, because both happened while
fetching the challenge URL. (Let's Encrypt's production CA would report
this one as `Type: dns` with a `DNS problem: ...` detail; Pebble is
simpler.) So the `Type` alone doesn't separate the two steps. The
`Detail` does. And certbot's `Hint:` is generic: it always blames its
standalone server, even when the CA never got as far as dialing it.

The root cause is Day 5's Part B, step 1 — the one-time
`challtestsrv` registration call:

```
docker compose run --rm toolbox curl -s -X POST http://challtestsrv:8055/add-a \
    -d '{"host":"test.local","addresses":["10.77.30.10"]}'
```

That call was made for `test.local`, which is why `test.local` still
issues. `billing.local` was never registered. challtestsrv runs with
`-defaultIPv4 ""` and `-defaultIPv6 ""`, so it gives unregistered names
no answer at all — exactly what a real domain with no DNS records looks
like.

**Fix:** register the new domain with `challtestsrv` before requesting a
certificate for it, exactly like Day 5's Part B step 1 did for
`test.local`:

```
docker compose run --rm toolbox curl -s -X POST http://challtestsrv:8055/add-a \
    -d '{"host":"billing.local","addresses":["10.77.30.10"]}'
```

then re-run the same `certonly` command — it should proceed to the
HTTP-01 fetch and succeed exactly as `test.local` does.

## Lesson

An ACME challenge has to resolve a name to an address before it can prove
anything about what's served there. Resolution failures and connection
failures are two different steps, and here they share one error `Type`.
Read the whole `Detail:` line — `could not resolve URL ...` vs.
`dial tcp <IP>:<port>: connection refused` — before assuming two certbot
failures are the same failure, and don't trust a client's generic `Hint:`
to know which step broke. This lab's `challtestsrv` registration is the
stand-in for "make sure your real DNS actually points this domain
somewhere" in production.

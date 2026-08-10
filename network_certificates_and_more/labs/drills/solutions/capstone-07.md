# Capstone 07 — Solution: the challenge never got far enough to hit the port at all

## Hint ladder

1. **Nudge:** the error `Type` field is not the same value drill-17 showed
   you for a port problem. Read it before assuming this is the same
   failure with a different domain.
2. **Tool to run:** compare against a domain that's already known to work.
   ```
   docker compose run --rm toolbox getent hosts test.local
   docker compose run --rm toolbox getent hosts billing.local
   ```
3. **Partial diagnosis:** one of these resolves and one doesn't. Pebble's
   `-dnsserver` override has to resolve a name before it can ever reach it
   to challenge it — resolution is a step that happens *before*
   connecting to any port.

## Full walkthrough

Pebble's ACME error carries `Type: dns` and `NXDOMAIN looking up A for
billing.local` — this is a **name resolution** failure, not a connection
failure. Contrast this precisely against drill-17's symptom, which
reported `Type: connection` / `Connection refused` on port `5002` — that
was a case where `billing.local`-equivalent (there, `test.local`) resolved
just fine, and the failure was purely about *reaching* the resolved
address on the expected port. Here, Pebble's DNS override (pointed at
`challtestsrv`, per this lab's `-dnsserver` wiring — see
`labs/acme/README.md`) never got an address for `billing.local` to
connect to *at all*.

The root cause is Day 5's Part B, step 1 — the one-time
`challtestsrv`-registration call:

```
docker compose run --rm toolbox curl -s -X POST http://challtestsrv:8055/add-a \
    -d '{"host":"test.local","addresses":["10.77.30.10"]}'
```

That call was made for `test.local` (Day 5's domain), which is exactly why
`test.local` still issues successfully against this same Pebble instance.
`billing.local` was never registered with `challtestsrv` at all, so
Pebble's DNS override has no A record to hand back, and its own answer is
`NXDOMAIN` — the ACME server never even attempts an HTTP-01 fetch, because
it doesn't know what address to fetch from.

**Fix:** register the new domain with `challtestsrv` before requesting a
certificate for it, exactly like Day 5's Part B step 1 did for
`test.local`:

```
docker compose run --rm toolbox curl -s -X POST http://challtestsrv:8055/add-a \
    -d '{"host":"billing.local","addresses":["10.77.30.10"]}'
```

then re-run the same `certonly` command — it should proceed to the
HTTP-01 fetch exactly as `test.local` does.

## Lesson

An ACME challenge has to resolve a name to an address before it can prove
anything about what's served at that address — DNS-level failures and
connection-level failures are two different steps that fail with two
different, specifically distinguishable error `Type` values (`dns` vs.
`connection`), and this lab's own `challtestsrv` registration step is a
stand-in for "make sure your real DNS actually points this domain
somewhere" in production. Read the `Type` field before assuming any two
certbot failures are the same failure.

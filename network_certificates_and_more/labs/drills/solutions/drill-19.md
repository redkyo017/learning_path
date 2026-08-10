# Drill 19 — Solution: renewal that skips itself, and a hook that never runs

## Hint ladder

1. **Nudge:** exit code `0` almost never means "nothing happened is
   wrong" — it means certbot considers what it did to be a success.
   Reread the output for what it actually claims happened.
2. **Tool to run:** look at the `[renewalparams]` in
   `renewal-conf-excerpt.conf` and compare against `certbot renew --help`
   or the docs for what triggers an actual renewal attempt versus a
   skip — specifically, `renew`'s default renewal window.
3. **Partial diagnosis:** the deploy hook only ever runs when a
   certificate actually gets renewed. Nothing in this run's output claims
   a renewal happened at all.

## Full walkthrough

The output is explicit, if you read past the first line: **"The following
certs are not due for renewal yet... No renewals were attempted."** — this
is certbot behaving exactly as documented, not failing. `certbot renew`
only attempts to renew a certificate once it's within its renewal window
(by default, roughly the last 30 days before `notAfter`) — and the
certificate from Part B was issued minutes ago, with a full **90-day**
validity window ahead of it (`labs/acme/pebble-config.json` pins Pebble's
`default` profile to exactly that, deliberately matching real-world Let's
Encrypt's own default lifetime — see `labs/acme/README.md`). Ninety days
out is nowhere close to a 30-day renewal window; this isn't a borderline
case that happens to fall the wrong way, it's not remotely due yet, by a
wide margin.

Because nothing was renewed, certbot never ran the `--deploy-hook` at
all — deploy hooks fire **only** after a certificate is actually
renewed, never as a no-op courtesy call — which is exactly why
`/work/acme/renewed.log` doesn't exist. This is the trap: it's easy to
read "exit code 0, no errors" and conclude your renewal automation
(including the hook that's supposed to reload your server) is working,
when in fact it has never actually been exercised at all.

**Fix:** to genuinely test the renewal + hook path without waiting for
the real window, force it:

```
docker compose run --rm --entrypoint certbot \
    -e REQUESTS_CA_BUNDLE=/work/acme/pebble.minica.pem \
    toolbox renew --force-renewal \
    --deploy-hook "echo renewed >> /work/acme/renewed.log" \
    --config-dir /work/acme/certbot/config \
    --work-dir /work/acme/certbot/work \
    --logs-dir /work/acme/certbot/logs
```

`--force-renewal` bypasses the due-date check specifically so you *can*
validate the end-to-end pipeline — including whatever hook reloads your
real server — without waiting. After this, `/work/acme/renewed.log`
should exist and contain `renewed`.

## Lesson

`certbot renew`'s entire design point is to be safe to run on a schedule
(hourly/daily cron) without re-issuing certificates that don't need it
yet — but that same safety mechanism means "I ran renew and it exited 0"
is not evidence your renewal *pipeline* — including any deploy hook that
reloads a real service — has ever actually been exercised. Test hook
behavior with `--force-renewal` (or `--dry-run`, which simulates the ACME
exchange without touching your live cert at all) deliberately, rather
than trusting an early, premature production run to have proven anything.

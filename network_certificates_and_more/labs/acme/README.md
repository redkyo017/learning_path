# labs/acme — Day 5 ACME lab wiring (Pebble + challtestsrv + certbot)

This directory holds the config for the local ACME server used by Day 5
(`content/day05.md`). Everything here runs entirely offline — no real domain,
no public CA, no AWS account. Verified end to end against Pebble 2.10.1
on 2026-09-30.

## Services and ports

| Service | Image | Purpose | Ports (container) | Static IP (`certlab` = `10.77.30.0/24`) |
|---|---|---|---|---|
| `pebble` | `ghcr.io/letsencrypt/pebble:2.10.1` | ACME server (directory + issuance) | `14000` ACME directory (HTTPS), `15000` management API (HTTPS) | `10.77.30.20` |
| `challtestsrv` | `ghcr.io/letsencrypt/pebble-challtestsrv:2.10.1` | DNS backend for pebble's challenge validation | `8053` DNS (used by pebble only), `8055` management API (plain HTTP) | `10.77.30.30` |
| `toolbox` | (this lab's own image) | runs `certbot`, presents the HTTP-01 response itself | `5002` (certbot's own standalone HTTP-01 responder, bound only while `certonly` is running) | `10.77.30.10` |

`docker-compose.yml`'s `certlab` network was given a fixed subnet
(`10.77.30.0/24`, added in this task) specifically so `toolbox`, `pebble`,
and `challtestsrv` get **static** IPs — `docker compose run --rm toolbox
...` creates a brand-new, ephemeral container each time, and Pebble needs a
stable answer for "where is the domain I'm about to validate," which a
dynamic IP can't reliably give it across separate `run` invocations. `nginx`
is untouched and still gets whatever free address Docker assigns it in that
subnet — nothing anywhere depends on nginx's IP; it's still always reached
by service name, exactly as Days 1–4 do.

## Images and flags

Pebble's images moved off Docker Hub; the lab pins the GHCR builds at
`2.10.1`. Both images are built `FROM scratch` with `ENTRYPOINT ["/app"]`,
which has two consequences:

- `command:` in `docker-compose.yml` holds **only the flags**, with no
  leading `pebble` / `pebble-challtestsrv` program name.
- There is no shell or any other binary inside. `docker compose exec
  pebble ...` fails; use `docker compose cp` to get files out.

Two environment variables on `pebble` make it lab-friendly:

- `PEBBLE_WFE_NONCEREJECT=0` — by default Pebble rejects 5% of valid
  nonces, to test that ACME clients recover. In a learning lab that just
  makes certbot fail at random with `JWS has an invalid anti-replay
  nonce`.
- `PEBBLE_VA_NOSLEEP=1` — skips Pebble's artificial random delay before
  validating a challenge.

## Why pebble needs `-dnsserver`, and why challtestsrv's own challenge responders are disabled

Pebble validates challenges by actually connecting out to whatever domain
you're requesting a cert for. By default it uses real DNS — which has never
heard of `test.local` and never will. `-dnsserver 10.77.30.30:8053` tells
pebble to send **all** of its own validation-time DNS lookups (A/AAAA/TXT)
to `challtestsrv` instead of the real internet. This is the standard
Let's-Encrypt-recommended pairing for testing against Pebble (`pebble` +
`pebble-challtestsrv`), used exactly this way in the pebble project's own
`docker-compose.yml`.

challtestsrv can *also* act as the actual HTTP-01/HTTPS-01/TLS-ALPN-01
challenge responder (it has built-in listeners for all three, driven by its
management API) — but this lab's guided flow uses certbot's own
`--standalone` plugin instead, which binds a listener directly on the
`toolbox` container and answers the HTTP-01 request itself. Running both
would just be two things that could theoretically answer the same kind of
request, which is confusing to reason about, so challtestsrv's own
`-http01`, `-https01`, `-tlsalpn01`, and `-doh` listeners are explicitly
disabled (empty string) in `docker-compose.yml`. challtestsrv here is
**DNS-only**: it answers pebble's lookups for `test.local` (registered as a
static A record, see below) and can answer `_acme-challenge.test.local` TXT
lookups too if you ever drive a DNS-01 flow against it (Exercise 4 in
`day05.md` points at this without requiring you to run it).

challtestsrv also runs with `-defaultIPv4 ""` and `-defaultIPv6 ""`. By
default it answers every A/AAAA query it has no record for with
`127.0.0.1` / `::1`. That bites even registered names: `add-a` sets only
the A record, so Pebble got `::1` for `test.local`'s AAAA, preferred it,
and dialed `[::1]:5002` — itself — with a confusing `connection refused`. With both blanked, only names registered through `add-a`
resolve; anything else gets no answer, like a real unregistered domain.

## One-time step: register `test.local` with challtestsrv

Because `toolbox` now has a static IP (`10.77.30.10`), this registration only
needs to happen once per `docker compose up` of the lab (challtestsrv holds
it in memory; it's lost if the `challtestsrv` container itself restarts):

```
docker compose run --rm toolbox curl -s -X POST http://challtestsrv:8055/add-a \
    -d '{"host":"test.local","addresses":["10.77.30.10"]}'
```

A successful call prints nothing (HTTP 200, empty body).

Reached by service name (`challtestsrv:8055`) — that request itself goes
through **Docker's own embedded DNS**, not through pebble's overridden
resolver; the `-dnsserver` override on the `pebble` service only changes
what *pebble* asks, never what `toolbox` asks.

## certbot trusting Pebble's HTTPS endpoint (`REQUESTS_CA_BUNDLE`)

Pebble serves its ACME directory (`:14000`) and management API (`:15000`)
over HTTPS, signed by Pebble's **own** bundled test CA — a fixed, static
fixture the pebble project ships at `test/certs/pebble.minica.pem` in its
repo and at `/test/certs/pebble.minica.pem` inside the image.
This is a *different* CA from the one that signs certificates Pebble
*issues* to you (see below) — `pebble.minica.pem` only vouches for Pebble's
own listening certificate on `:14000`/`:15000`.

Nothing in `toolbox`'s OS trust store (or certbot's Python `requests`
library, which keeps its own bundle via `certifi` — see Day 4's theory
section on per-process trust stores) has ever heard of this CA. Rather than
disabling TLS verification (never do this — it silently defeats check 4 for
*everything* the process talks to, not just Pebble), point `requests`
specifically at Pebble's test root via the `REQUESTS_CA_BUNDLE` environment
variable, which certbot's underlying `acme`/`requests` stack respects:

```
docker compose cp pebble:/test/certs/pebble.minica.pem acme/pebble.minica.pem
```

Once extracted, every certbot invocation passes it via `-e`:

```
docker compose run --rm --entrypoint certbot \
    -e REQUESTS_CA_BUNDLE=/work/acme/pebble.minica.pem \
    toolbox certonly ...
```

(`/work/acme/pebble.minica.pem` — the container-internal path, since
`labs/` is bind-mounted to `/work` for every service built from
`toolbox/Dockerfile`, exactly as every prior day's commands do.)

## The issued cert's chain changes every Pebble restart

Pebble regenerates its ACME **root and intermediate** (the CAs behind the
leaf certificates it issues to you via ACME) from scratch every time the
`pebble` container starts. This is deliberate — it stops anyone building a
lab that quietly starts depending on a specific pebble-issued chain by
serial number or fingerprint. It does **not** affect `pebble.minica.pem`
above, which is a separate, static fixture used only for Pebble's own
listening certificate. Concretely: if you restart `pebble` and re-run the
guided lab's `certonly` command, you'll get a new certificate signed by a
*different* (freshly generated) intermediate than last time — this is
expected, not a bug, and `day05.md` calls it out again at the point in the
guided lab where it matters.

To verify an issued cert you need that root as a trust anchor. `chain.pem`
holds only the intermediate. Pebble serves the current root on its
management API:

```
docker compose run --rm toolbox curl -s \
    --cacert /work/acme/pebble.minica.pem \
    https://pebble:15000/roots/0 -o /work/acme/pebble-root.pem
```

(`/intermediates/0` serves the intermediate.) Re-fetch after every Pebble
restart. `acme/pebble-root.pem` is gitignored.

## Issued certificate validity: 90 days, on purpose, not "short-lived"

Issued certs have an **empty Subject**; the name lives only in the SAN
(`openssl x509 -noout -ext subjectAltName`).

`pebble-config.json`'s `profiles.default.validityPeriod` is pinned to
`7776000` seconds (90 days) explicitly — matching real-world Let's
Encrypt's own default certificate lifetime, rather than leaving it to
whatever Pebble's built-in default happens to be. This matters
operationally: it's what makes drill-19 (running `certbot renew`
immediately after issuance) a genuine, realistic "not yet due for
renewal" skip — certbot 2.9's fixed ~30-day-before-`notAfter` renewal
window (no ARI support until certbot 4.1) is nowhere close to tripping on
a cert that's 90 days from expiry.

`default` is deliberately the **only** profile defined. When an order
doesn't name a profile, Pebble picks one of its configured profiles **at
random** (verified live on 2.10.1: with a second, 6-day `shortlived`
profile defined, identical certbot runs came back 90 days or 6 days
roughly half the time each). certbot 2.9.0 has no way to request a
profile, so any extra profile would make Day 5's 90-day expectation and
drill-19's "not yet due" skip a coin toss. To experiment with a 6-day
`shortlived` profile (`"validityPeriod": 518400`), add it to
`pebble-config.json`, restart `pebble`, and expect random lifetimes from
this certbot.

## certbot's own state, kept under `labs/`

The guided lab points certbot's `--config-dir`/`--work-dir`/`--logs-dir` at
`/work/acme/certbot/...` (inside the container; `labs/acme/certbot/...` on
the host) instead of the defaults (`/etc/letsencrypt`, etc.), which would
otherwise be lost the moment the `--rm` container exits. Nothing under
`acme/certbot/` needs to be created by hand — certbot creates it on first
run.

## Cross-reference

Full guided lab, theory (HTTP-01/DNS-01/TLS-ALPN-01, revocation, OCSP
stapling, CT logs), the AWS ACM/ALB bridge, exercises, and drill pointers:
`content/day05.md`.

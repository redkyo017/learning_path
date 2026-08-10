# labs/acme — Day 5 ACME lab wiring (Pebble + challtestsrv + certbot)

This directory holds the config for the local ACME server used by Day 5
(`content/day05.md`). Everything here runs entirely offline — no real domain,
no public CA, no AWS account. See `docs/superpowers/sdd/2026-08-10-tls-certificates-mastery-plan/task-7-report.md`
for what in this write-up is verified by reasoning against Pebble's own
documented config schema/flags vs. what still needs a live Docker run to
confirm (this whole task was authored without Docker available).

## Services and ports

| Service | Image | Purpose | Ports (container) | Static IP (`certlab` = `10.77.30.0/24`) |
|---|---|---|---|---|
| `pebble` | `letsencrypt/pebble` | ACME server (directory + issuance) | `14000` ACME directory (HTTPS), `15000` management API (HTTPS) | `10.77.30.20` |
| `challtestsrv` | `letsencrypt/pebble-challtestsrv` | DNS backend for pebble's challenge validation | `8053` DNS (used by pebble only), `8055` management API (plain HTTP) | `10.77.30.30` |
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

## One-time step: register `test.local` with challtestsrv

Because `toolbox` now has a static IP (`10.77.30.10`), this registration only
needs to happen once per `docker compose up` of the lab (challtestsrv holds
it in memory; it's lost if the `challtestsrv` container itself restarts):

```
docker compose run --rm toolbox curl -s -X POST http://challtestsrv:8055/add-a \
    -d '{"host":"test.local","addresses":["10.77.30.10"]}'
```

Reached by service name (`challtestsrv:8055`) — that request itself goes
through **Docker's own embedded DNS**, not through pebble's overridden
resolver; the `-dnsserver` override on the `pebble` service only changes
what *pebble* asks, never what `toolbox` asks.

## certbot trusting Pebble's HTTPS endpoint (`REQUESTS_CA_BUNDLE`)

Pebble serves its ACME directory (`:14000`) and management API (`:15000`)
over HTTPS, signed by Pebble's **own** bundled test CA — a fixed, static
fixture the pebble project ships at `test/certs/pebble.minica.pem` in its
repo (and, per the project's docs, at the same path inside the built image).
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

**DEFERRED — needs live confirmation.** This exact in-container path
(`/test/certs/pebble.minica.pem`) is stated directly in the pebble project's
own documentation and mirrors its repo layout, but it was not possible to
confirm by actually running the container in this task (Docker was not
available while authoring this lab). If the path doesn't exist in whatever
image tag you pull, run `docker compose exec pebble find / -maxdepth 4 -iname
'pebble.minica.pem'` first to locate it, then adjust the `cp` source path.

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

Pebble regenerates its ACME **intermediate** (the CA that signs the leaf
certificates it issues to you via ACME) from scratch every time the
`pebble` container starts. This is deliberate — it stops anyone building a
lab that quietly starts depending on a specific pebble-issued chain by
serial number or fingerprint. It does **not** affect `pebble.minica.pem`
above, which is a separate, static fixture used only for Pebble's own
listening certificate. Concretely: if you restart `pebble` and re-run the
guided lab's `certonly` command, you'll get a new certificate signed by a
*different* (freshly generated) intermediate than last time — this is
expected, not a bug, and `day05.md` calls it out again at the point in the
guided lab where it matters.

## Issued certificate validity: 90 days, on purpose, not "short-lived"

`pebble-config.json`'s `profiles.default.validityPeriod` is pinned to
`7776000` seconds (90 days) explicitly — matching real-world Let's
Encrypt's own default certificate lifetime, rather than leaving it to
whatever Pebble's built-in default happens to be. This matters
operationally: it's what makes drill-19 (running `certbot renew`
immediately after issuance) a genuine, realistic "not yet due for
renewal" skip — certbot's own ~30-day-before-`notAfter` renewal window is
nowhere close to tripping on a cert that's 90 days from expiry. A
`shortlived` profile (`518400` seconds, 6 days) is also defined in the
config for anyone who wants to deliberately exercise a
near-expiry/actually-due renewal instead — Pebble supports selecting a
profile per-order via the ACME `profile` field, though this lab's guided
flow doesn't do so and just takes the `default` profile.

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

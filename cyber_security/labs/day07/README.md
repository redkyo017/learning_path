# Day 7 Lab — Intercept, Tamper, and Inspect HTTP Against OWASP Juice Shop

## Authorized use only

`juiceshop` is OWASP's own official, intentionally vulnerable training app — it exists
specifically to be attacked, but only on infrastructure you or your organization
control. Everything below runs against `juiceshop`, `proxy`, and `hardened`, the three
containers this lab starts on the shared `cyberlab` docker network. Never point a
proxy, a header-tampering script, or a CORS probe at a login page, API, or app you
don't own or don't have explicit written authorization to test — the exact same
techniques against a real site are unauthorized access, full stop.

## What this lab is

`labs/day07/docker-compose.yml` adds **three** services to the shared `cyberlab`
network created by [`labs/base`](../base/README.md). It does **not** redefine the
`attacker` service — that container is shared infrastructure, already running from
Day 0.

- **`juiceshop`** — [OWASP Juice Shop](https://owasp.org/www-project-juice-shop/)
  (`bkimminich/juice-shop`), run stock and unmodified, listening on its default port
  `3000`. This is today's target for mapping, header inspection, and CORS probing.
- **`proxy`** — a headless [mitmproxy](https://mitmproxy.org/) instance (`mitmdump`,
  mitmproxy's scriptable CLI — the same interception engine as the interactive
  `mitmproxy` TUI, chosen here specifically because it's **headless-friendly**: no
  terminal UI, no X11, works the same over a plain `docker compose exec`). It listens
  on `8080` and loads [`mitm/tamper_addon.py`](mitm/tamper_addon.py), which rewrites
  one query parameter on every request that passes through it, on its way to
  `juiceshop` — a live demonstration that a client can never be certain a request
  arrives server-side unmodified from what it sent, once anything sits on the network
  path.
- **`hardened`** — an `nginx:alpine` reverse proxy in **front** of `juiceshop`,
  configured (see [`hardened/nginx.conf`](hardened/nginx.conf)) to add the security
  headers and the explicit, non-wildcard CORS policy that `juiceshop` itself doesn't
  ship. This is the Defense Lab's before/after target: the exact same underlying app,
  reached two ways — `juiceshop:3000` directly (missing headers) vs. `hardened:8080`
  (headers present) — and the realistic pattern for hardening a third-party app whose
  source you don't own.

**Burp Suite** is an equally valid alternative to mitmproxy for the interception
sections below if you prefer a GUI — the concepts (a proxy sitting between client and
server, intercepting and rewriting requests in flight) are identical. This lab uses
mitmproxy as the primary tool specifically because it's scriptable and headless, which
fits running everything from inside a container over `docker compose exec` with no
display. If you do have a GUI available, Burp's Proxy tab + "Intercept" + a manual
edit-and-forward covers the same ground as `tamper_addon.py` below.

No ports are published to the host anywhere in this lab — every service is reached by
name (`juiceshop`, `proxy`, `hardened`) from the `attacker` container over the shared
`cyberlab` network.

## Setup

**Prerequisite:** the shared toolbox must already be up (Day 0):

```sh
cd cyber_security/labs/base
./up.sh
```

Then bring up today's target/proxy/hardened stack:

```sh
cd cyber_security/labs/day07
docker compose up -d
```

Juice Shop's first boot can take a few seconds to finish seeding its database — give it
a moment before the first request if you see a connection refused.

## Running `docker compose exec` for this lab

Exactly like every earlier day: `attacker` is defined in `labs/base/docker-compose.yml`,
not in this lab's compose file. Run every `docker compose exec attacker ...` command
**from `labs/base`**, not from `labs/day07`:

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -sI juiceshop:3000/"
```

Commands that target `juiceshop`, `proxy`, or `hardened` directly (not through
`attacker` — e.g. reading the proxy's own logs, or restarting a service) run from
**`labs/day07`** instead, since those three services live in *this* lab's compose
project:

```sh
cd cyber_security/labs/day07
docker compose logs proxy
```

## Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -sI juiceshop:3000 | head -1 | grep -q 200 && echo TARGET_OK"
```

**Expected output:** `TARGET_OK`.

## Walkthrough

1. Bring up `labs/base` and `labs/day07` as above.
2. From `labs/base`, work through Section 2 of
   [`content/day07-http.md`](../../content/day07-http.md) in order:
   - Step 1 — fingerprint `juiceshop` with `whatweb` and map its routes manually with
     `curl`.
   - Step 2 — route a normal request through `proxy` (`curl -x proxy:8080 ...`) and
     confirm it's captured.
   - Step 3 — repeat against the search endpoint and observe `tamper_addon.py`
     rewriting the `q` parameter in flight, before `juiceshop` ever sees the original
     value.
   - Step 4 — inspect `juiceshop`'s response headers directly and check them against
     the security-header checklist.
   - Step 5 — probe CORS behavior with a spoofed `Origin` header.
3. Run the verify command above and confirm `TARGET_OK`.
4. Read Section 3 (Defense Lab) and compare `juiceshop:3000` against `hardened:8080`
   for both the header and CORS fixes, before checking `SOLUTION.md`.

Full expected output for every command above — the tamper addon's effect, the header
checklist result, and the before/after through `hardened` — is in
[`labs/day07/SOLUTION.md`](SOLUTION.md).

**Note on this lab's verification:** this task's build was validated **statically
only** (`docker compose config -q`) — the containers below were not brought up live as
part of authoring this lab. `SOLUTION.md` documents *expected* output based on each
tool's and each app's known, documented behavior, not output captured from a live run.
Run it yourself and treat your own terminal's actual output as the ground truth over
anything written there.

## Optional supplement: PortSwigger Web Security Academy

[PortSwigger's Web Security Academy](https://portswigger.net/web-security) is a free,
self-paced set of labs covering HTTP fundamentals, CORS, and most of the OWASP Top 10
in much greater depth than a single day here can, using Burp Suite Community Edition
(also free) as its intercepting proxy. It's an optional, non-required supplement if you
want more reps on today's concepts — nothing in this path depends on it, and nothing
here assumes you've done it.

## Teardown

```sh
cd cyber_security/labs/day07
docker compose down
```

This removes only `juiceshop`, `proxy`, and `hardened` — `labs/base`'s `attacker`
container, the `cyberlab` network, and any other day's target are untouched, since
they're shared infrastructure other days depend on too. Tear down `labs/base`
separately (`cd ../base && ./down.sh`) only once you're done with the whole session.

# Day 7 Lab — Solution / Walkthrough

## Authorized use only

Same notice as [`README.md`](README.md): only run these commands against the
`juiceshop`, `proxy`, and `hardened` containers this lab starts, on `cyberlab`.

## A note on how this file was produced

This task's build was validated **statically only** — `cd labs/day07 && docker compose
config -q` (confirmed passing) — not by bringing the stack up and running every command
live. Everything below is **expected output**, reasoned from OWASP Juice Shop's
documented behavior, mitmproxy's documented addon/CLI behavior, and the exact nginx
config shipped in [`hardened/nginx.conf`](hardened/nginx.conf) — not output copy-pasted
from a real terminal. This is stated plainly rather than glossed over, matching this
path's own honesty standard elsewhere (e.g. Day 4's scope notes): if your actual output
differs in a specific status code, header capitalization, or JSON shape, trust your
terminal over this file, and treat any difference as worth understanding rather than a
"broken lab."

## 0. Bring the stack up

```sh
cd cyber_security/labs/base
./up.sh
cd ../day07
docker compose up -d
```

Give Juice Shop a few seconds to finish its first-boot database seed before the first
request.

## 1. Fingerprint and map the target

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "whatweb juiceshop:3000"
```

**Expected:** `whatweb` reports an `Express` backend, an `X-Powered-By` (or its
absence — Juice Shop, like many hardened-by-default frameworks, may already suppress
this one specific header) and a page title identifying Juice Shop. This is the same
tool Day 1's recon lab used against `target` — same technique, new target.

```sh
docker compose exec attacker sh -c "curl -s juiceshop:3000/ | grep -o '<title>[^<]*'"
```

**Expected:** `<title>OWASP Juice Shop` (or similar) — confirms the app identity from
the HTML itself, not just the fingerprinting tool's guess.

## 2. Route a request through the proxy and confirm it's intercepted

```sh
docker compose exec attacker sh -c "curl -s -x proxy:8080 http://juiceshop:3000/rest/products/search?q=orange"
```

**Expected:** the request succeeds (same JSON Juice Shop would return without the
proxy) — proving `proxy` is transparently forwarding traffic, not just blocking it.

Then, from `labs/day07` (not `labs/base` — `proxy` is a service in *this* lab's compose
project):

```sh
cd cyber_security/labs/day07
docker compose logs proxy
```

**Expected:** a line showing the intercepted `GET /rest/products/search?q=orange`
request and its response status, at `flow_detail=3`'s summary level.

## 3. Tamper — watch the search parameter get rewritten in flight

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -s -x proxy:8080 'http://juiceshop:3000/rest/products/search?q=orange' | jq -r '.data[].name'"
```

**Expected:** despite asking for `q=orange`, the returned product names are Juice
Shop's actual matches for `q=juice` — because
[`mitm/tamper_addon.py`](mitm/tamper_addon.py) rewrote the query parameter to
`"juice"` before the request ever reached `juiceshop`. `juiceshop` itself never sees
`orange` at all; from its perspective, the client asked for `juice`.

Confirm the tamper is visible in the proxy's own log (from `labs/day07`):

```sh
cd cyber_security/labs/day07
docker compose logs proxy
```

**Expected:** a line whose comment field reads
`tampered: q='orange' -> q='juice'` — the addon's `flow.comment`, set exactly when it
rewrites a query.

**What this proves:** the request that left `curl` and the request `juiceshop` actually
received were different, and neither `curl` nor `juiceshop` had any way to detect that
on their own — only inspecting the proxy's own log surfaces it. This is the concrete
version of Section 1's abstract point: HTTP gives a server nothing but "here is a
request," with no built-in guarantee it matches what the client thinks it sent.

## 4. Inspect response headers directly against `juiceshop`

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -sI juiceshop:3000/"
```

**Expected, checked against the Section 1 / Drill 1 checklist** (Content-Security-
Policy, Strict-Transport-Security, X-Frame-Options, X-Content-Type-Options,
Referrer-Policy, Permissions-Policy): Juice Shop is a deliberately vulnerable training
app, and its stock configuration does **not** ship the full set — expect at least
`Content-Security-Policy`, `Strict-Transport-Security`, and `Permissions-Policy` to be
absent from the raw response. It may already set a small number of baseline headers via
its Express middleware (e.g. `X-Content-Type-Options` or a `Server`/`X-Powered-By`
banner) — **run the command yourself and check the actual list against the checklist
line by line**, rather than trusting a fixed list here: this is exactly Drill 1's
exercise, applied live instead of to a supplied example.

## 5. Probe CORS with a spoofed Origin

```sh
docker compose exec attacker sh -c "curl -s -H 'Origin: https://evil.example' -I juiceshop:3000/rest/user/whoami"
```

**What to look for in the `Access-Control-Allow-Origin` response header (if present):**

- **Absent entirely** — the browser's Same-Origin Policy applies with no relaxation;
  a page on `evil.example` cannot read this response via `fetch`/`XHR`. Not a
  misconfiguration.
- **A literal, specific origin your own frontend actually needs** — a correctly scoped
  CORS relaxation. Not a misconfiguration.
- **The literal string `*`** — any site can read the response, but browsers refuse to
  combine a wildcard with `Access-Control-Allow-Credentials: true`, so this is only
  dangerous if the endpoint doesn't need cookies/auth to answer.
- **The exact value of the `Origin` header you just sent, reflected back** (i.e.
  `https://evil.example` appears in the response) **combined with
  `Access-Control-Allow-Credentials: true`** — this is the dangerous misconfiguration
  (Drill 3): it means literally any origin, including one an attacker controls, can
  make a credentialed cross-origin request and read the response.

Run this yourself and record which case you actually observe — that observed value,
not a guess, is the correct answer for your own run.

## 6. Defense — before/after through `hardened`

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "echo '--- direct (juiceshop:3000) ---'; curl -sI juiceshop:3000/; echo '--- via hardened (hardened:8080) ---'; curl -sI hardened:8080/"
```

**Expected:** the `juiceshop:3000` block is missing some subset of the header
checklist (Step 4 above); the `hardened:8080` block — the exact same underlying app,
reached through [`hardened/nginx.conf`](hardened/nginx.conf)'s reverse proxy — shows
all six headers present: `X-Content-Type-Options: nosniff`,
`X-Frame-Options: DENY`, `Content-Security-Policy: default-src 'self'; ...`,
`Strict-Transport-Security: max-age=63072000; ...`, `Referrer-Policy: no-referrer`,
`Permissions-Policy: geolocation=(), ...`. Nothing about `juiceshop`'s own code
changed — the fix is entirely at the reverse-proxy edge, which is the realistic pattern
when you don't own the upstream app's source.

```sh
docker compose exec attacker sh -c "curl -s -H 'Origin: https://evil.example' -I hardened:8080/rest/user/whoami"
```

**Expected:** `Access-Control-Allow-Origin: https://trusted-partner.example` — a fixed,
explicit value, **not** a reflection of the `evil.example` Origin just sent. This is
the fix for Step 5's misconfiguration case: the allowed origin is a hardcoded
allowlist entry the reverse proxy always returns, never an echo of whatever `Origin`
header a caller happens to send.

**Honest caveat on `Strict-Transport-Security` in this lab:** `hardened` is plain
HTTP-only here (port `8080`, no TLS), kept simple for a single day's lab. HSTS is
genuinely only meaningful once TLS actually terminates somewhere in front of a
deployment; showing the header here demonstrates the *mechanics* (the directive, the
`max-age`, `includeSubDomains`) without claiming this lab is a complete TLS-enforcing
deployment — that gap is intentional and named, not silently glossed over.

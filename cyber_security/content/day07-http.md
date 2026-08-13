# Day 7 — HTTP & the Web as Attack Surface

## Objectives

By the end of today you should be able to:

- Name the parts of an HTTP request and response precisely enough to say what a proxy
  can and can't change, and why HTTP being **stateless** is exactly what makes cookies
  and sessions (Day 4) necessary in the first place.
- Classify any HTTP method as **safe** and/or **idempotent** or neither, and say
  concretely why an app that lets a `GET` request delete something is a design bug, not
  a browser bug.
- State the **Same-Origin Policy** precisely (what counts as the same origin, what SOP
  blocks vs. what it lets through) and explain **CORS** as the sanctioned, explicit
  mechanism for relaxing it — then name the one specific header combination that turns
  CORS from a scoped relaxation into "any site can read this."
- Route traffic through `mitmproxy` and watch a request get rewritten in flight, then
  explain in one sentence why that possibility means a server can never trust that a
  request arrived unmodified from whatever the client actually sent.
- Given a raw set of response headers, name which standard security headers (CSP, HSTS,
  X-Frame-Options, and others) are missing and the specific risk each one's absence
  reintroduces.
- Harden a third-party app you don't control the source of, by adding the missing
  headers and a correct CORS policy at a reverse-proxy edge instead of in code you don't
  own.

## 1. Concept — HTTP, Statelessness, SOP, and CORS

### The request/response lifecycle, and why HTTP is stateless

Every HTTP exchange is one **request** answered by one **response**, and nothing more —
that's the entire protocol contract. A request has a **method** (what to do), a
**path** (what resource), a set of **headers** (metadata about the request), and
optionally a **body** (data). A response has a **status line** (a numeric code plus a
short reason phrase — `200 OK`, `404 Not Found`, `500 Internal Server Error`), its own
**headers**, and optionally a **body**. That's it — HTTP itself keeps no memory between
one request and the next. **Statelessness** means the server treats every incoming
request as if it had never seen that client before, unless something *in* the request
tells it otherwise.

This is precisely why Day 4's whole topic — sessions, cookies, JWTs — has to exist at
all: since HTTP itself remembers nothing, an application that needs to recognize "this
request and that earlier one came from the same logged-in user" has to smuggle an
identifier into *every single request* via a header (a `Cookie` header carrying a
session ID, or an `Authorization` header carrying a JWT) so the server can look up or
verify who's asking. Statelessness isn't a flaw being patched over — it's a deliberate
protocol design that pushed the entire concept of "who is this" up a layer, into
whatever the application chooses to build on top.

### HTTP methods — safe, idempotent, and what that actually buys you

A method is **safe** if it isn't supposed to change anything server-side — `GET` and
`HEAD` are the standard safe methods; a safe request should be repeatable, cacheable,
and pre-fetchable by a browser or a crawler with zero side effects. A method is
**idempotent** if making the identical request N times produces the same server state
as making it once — `GET`, `HEAD`, `PUT`, and `DELETE` are idempotent (deleting the same
resource twice leaves it deleted either way; `PUT`ting the identical representation
twice leaves the identical representation either way); `POST` and `PATCH` are **not**
guaranteed idempotent (`POST`ing "create an order" twice creates two orders).

| Method | Safe | Idempotent | Typical use |
|---|---|---|---|
| `GET` | Yes | Yes | Retrieve a resource |
| `HEAD` | Yes | Yes | Retrieve headers only, no body |
| `PUT` | No | Yes | Replace a resource entirely |
| `DELETE` | No | Yes | Remove a resource |
| `POST` | No | No | Create a resource / non-idempotent action |
| `PATCH` | No | No (usually) | Partially modify a resource |
| `OPTIONS` | Yes | Yes | Ask what methods/headers are allowed (CORS preflight, below) |

**Why this matters for security, concretely:** browsers, proxies, and crawlers are
built assuming safe methods have no side effects — a browser will happily pre-fetch a
`GET` link, and any cache is allowed to serve a stored `GET` response to a second
requester without re-asking the server. An app that wires a `GET /delete-account?id=5`
link up to actually delete an account isn't exploiting a browser flaw when a crawler or
a pre-fetch triggers it unintentionally — it's violating the method's own contract, and
every layer built on top of HTTP (caches, browsers, link-preview bots) is entitled to
assume that contract holds. Drill 4 below gives you concrete scenarios to classify.

### Headers and cookies

**Headers** are `Name: Value` metadata lines on both requests and responses — some are
standard (`Content-Type`, `Content-Length`, `Host`), some are conventionally used for
security (this section's second half), and applications can define arbitrary custom
ones (`X-Api-Key`, `X-Request-Id`). A request's `Host` header is what tells a single
server process which of potentially many sites it's serving which response for; a
response's `Content-Type` tells the client how to interpret the body (`text/html`,
`application/json`, ...) — and mismatches between what `Content-Type` *claims* and what
a browser decides to *do* with a body anyway is exactly what `X-Content-Type-Options:
nosniff` (below) exists to lock down.

A **cookie** is a specific, standardized use of headers to give HTTP a thin layer of
state: a server response header `Set-Cookie: name=value; <attributes>` tells the
browser to store that value and send it back automatically, as a `Cookie: name=value`
request header, on every subsequent request to a matching origin — this is the exact
mechanism Day 4's session-ID transport relies on. Three attributes on `Set-Cookie`
matter most for security, all three already named in Day 4 and worth having land fully
here too: **`Secure`** (only ever sent over HTTPS, never plain HTTP), **`HttpOnly`**
(invisible to JavaScript — `document.cookie` can't read it, which is the specific
defense against session-cookie theft via XSS), and **`SameSite`** (restricts whether
the cookie is attached to cross-site requests at all — `Strict`/`Lax`/`None`, the core
defense Day 9 builds on against CSRF).

### Same-Origin Policy — what actually gets restricted

An **origin** is the exact triple **scheme + host + port** — `https://shop.example:443`
and `http://shop.example:443` are *different* origins (different scheme); so are
`https://shop.example` and `https://api.shop.example` (different host, even as a
subdomain); so are `https://shop.example:443` and `https://shop.example:8443`
(different port). The **Same-Origin Policy (SOP)** is the browser's default rule: a
script running on one origin cannot **read the response** of a request to a different
origin.

The precise, easy-to-get-wrong part: SOP does **not** stop the cross-origin *request*
from being sent at all — a `<form>` on `evil.example` can still `POST` to
`bank.example`, and an `<img src="https://bank.example/logo.png">` tag still fetches
that image. What SOP blocks is **JavaScript on `evil.example` reading the response
body** of a cross-origin `fetch`/`XMLHttpRequest` call. This precise distinction is why
CSRF (a forged *request*, Day 9) and a SOP violation (unauthorized *reading* of a
response) are genuinely different bug classes that happen to both involve
cross-origin browser behavior — SOP already stops the second one by default; nothing
stops the first one except the `SameSite` cookie attribute and explicit anti-CSRF
tokens, precisely because SOP was never designed to block requests, only responses.

### CORS — the sanctioned relaxation, and its one dangerous combination

**CORS** (Cross-Origin Resource Sharing) is the mechanism a server uses to explicitly
tell browsers "it's fine for scripts on *this specific other origin* to read my
response" — an opt-in relaxation of SOP, not a bypass of it. The server states this via
response headers, most importantly `Access-Control-Allow-Origin: <origin>`. For
requests beyond a simple `GET`/`POST` with plain headers, the browser first sends an
automatic **preflight** — an `OPTIONS` request asking "would you allow this exact
method and these headers, from this origin?" — before sending the real request at all;
this is exactly why `OPTIONS` is in the methods table above as safe and idempotent, and
why you'll see it appear in intercepted traffic even for requests you never explicitly
made yourself.

**The one combination that turns CORS dangerous:** `Access-Control-Allow-Origin` set to
a literal `*` (any origin) is relatively safe *by itself* for non-credentialed,
non-sensitive public data — but browsers refuse to honor a wildcard together with
`Access-Control-Allow-Credentials: true`, specifically because that pairing would mean
any site on the internet can make an authenticated (cookie-carrying) request and read
the response. The real-world misconfiguration this protection doesn't fully prevent is
a server that **dynamically reflects whatever `Origin` header the request happened to
carry** back as the value of `Access-Control-Allow-Origin`, instead of checking it
against a real allowlist — that passes the "not a literal wildcard" technicality while
producing the exact same effective result: literally any origin, including one an
attacker controls, gets treated as allowed. Drill 3 and today's Attack Lab Step 5 walk
through spotting this exact pattern.

### Security headers — what each one specifically stops

None of these are enforced by HTTP itself — they're response headers that *tell the
browser* to apply an extra restriction, so they only help against clients (browsers)
that respect them, and they help not at all against a non-browser client like `curl` or
a server-to-server call.

- **`Content-Security-Policy` (CSP)** — restricts which origins scripts, styles,
  frames, and other resources may load from, expressed as directives like
  `default-src 'self'`. This is the modern, much stronger mitigation for XSS
  (Day 8): even if an attacker manages to inject a `<script>` tag into a page, a tight
  CSP can stop that script from executing or from exfiltrating data to an
  attacker-controlled origin.
- **`Strict-Transport-Security` (HSTS)** — tells the browser "once you've loaded this
  site over HTTPS, never downgrade to plain HTTP again, for `max-age` seconds." Closes
  the specific window an SSL-stripping man-in-the-middle would otherwise exploit on a
  user's very first visit or after a cache expiry. Only meaningful once TLS is actually
  terminating somewhere in front of the app — a header promising HTTPS enforcement on a
  site that doesn't serve HTTPS at all is a contradiction, not a fix.
- **`X-Frame-Options`** — restricts whether this page can be rendered inside a
  `<frame>`/`<iframe>` on another origin at all. The original, narrower defense against
  **clickjacking** (an attacker overlays your page invisibly under their own UI,
  tricking a user into clicking something on your page they never saw); CSP's
  `frame-ancestors` directive is the modern superset of this same protection.
- **`X-Content-Type-Options: nosniff`** — stops the browser from re-guessing a
  response's content type based on its bytes instead of trusting the declared
  `Content-Type` header. Without it, a file an app treats as a harmless image upload
  could be MIME-sniffed and rendered as HTML/JS by the browser anyway if its bytes look
  enough like a script.
- **`Referrer-Policy`** — controls how much of the current page's own URL leaks into
  the `Referer` header of requests it triggers to other origins (images, outbound
  links). `no-referrer` leaks none of it; looser policies leak progressively more.
- **`Permissions-Policy`** — explicitly disables browser features (camera, geolocation,
  microphone, etc.) a page has no legitimate reason to use, so that even a successful
  script injection can't invoke them.

### Proxies — forward, and the intercepting kind this lab uses

A **proxy** is any intermediary that sits between a client and a server and relays
requests/responses on the client's behalf. A plain **forward proxy** just relays
traffic, usually for caching or access control, without altering it. An
**intercepting proxy** (what `mitmproxy` and Burp both are) goes further: it terminates
the client's connection, can read every request and response in full plaintext, and can
**rewrite either one before passing it on** — the exact tool a legitimate security
tester or a malicious man-in-the-middle would both use, the difference being
authorization, not capability. This lab's Attack Section routes the attacker
container's own traffic through such a proxy on purpose, which is the honest,
in-scope way to demonstrate what an *unauthorized* intercepting position (achievable
via ARP spoofing on a shared network — Day 2 — or a compromised Wi-Fi access point in
the real world) would let a real attacker do to traffic that isn't theirs.

## 2. Attack Lab — Map, Intercept, Tamper, Inspect

**Authorized use only:** everything below runs against `juiceshop`, `proxy`, and
`hardened`, three containers this lab starts on the shared `cyberlab` network — never
against a real site, login page, or API you don't own or don't have explicit written
authorization to test.

Bring up both labs (after `labs/base/up.sh` if you haven't already):

```sh
cd cyber_security/labs/base
./up.sh
cd ../day07
docker compose up -d
```

`labs/day07/docker-compose.yml` adds **three** services — `juiceshop`, `proxy`, and
`hardened` — and does **not** redefine `attacker`. Every `docker compose exec attacker`
command below runs from `labs/base`, where `attacker` is actually defined; commands
targeting `proxy`/`juiceshop`/`hardened` directly (their own logs, restarts) run from
`labs/day07`. Full detail: [`labs/day07/README.md`](../labs/day07/README.md).

### Step 1 — Fingerprint and map the target

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "whatweb juiceshop:3000"
```

**What you should see:** the same fingerprinting tool Day 1's recon lab used, now
against a real (if intentionally vulnerable) Node/Express application — identifying the
backend framework and the page title from the response itself, the manual-mapping
counterpart to Day 8/9's later automated endpoint discovery.

### Step 2 — Route a request through the proxy

```sh
docker compose exec attacker sh -c "curl -s -x proxy:8080 'http://juiceshop:3000/rest/products/search?q=orange'"
```

**What you should see:** the same JSON `juiceshop` would return without the proxy at
all — `proxy` forwards traffic transparently by default; nothing changes yet until
Step 3's addon-specific path matches. Confirm the request was actually seen by the
proxy (from `labs/day07`, since `proxy` is defined there, not in `labs/base`):

```sh
cd cyber_security/labs/day07
docker compose logs proxy
```

### Step 3 — Tamper: watch a query parameter get rewritten in flight

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -s -x proxy:8080 'http://juiceshop:3000/rest/products/search?q=orange' | jq -r '.data[].name'"
```

**What you should see:** results for `q=juice`, not `q=orange` —
[`mitm/tamper_addon.py`](../labs/day07/mitm/tamper_addon.py) rewrites the `q` query
parameter to `"juice"` on every request matching `/rest/products/search`, before the
request ever reaches `juiceshop`. `juiceshop` never sees `orange` at all; from its
point of view, the client asked for `juice`. This is the concrete version of Section
1's proxy point: the request that left `curl` and the request the server actually
received were different, and neither end had any way to notice on its own.

### Step 4 — Inspect response headers for missing security headers

```sh
docker compose exec attacker sh -c "curl -sI juiceshop:3000/"
```

**What you should see:** check the response against Section 1's security-header list
(CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy,
Permissions-Policy) — Juice Shop, deliberately vulnerable, is missing at least the
strongest of these (CSP, HSTS, Permissions-Policy) in its stock configuration. Section
3's Defense Lab fixes this without touching `juiceshop` at all.

### Step 5 — Probe CORS with a spoofed `Origin`

```sh
docker compose exec attacker sh -c "curl -s -H 'Origin: https://evil.example' -I juiceshop:3000/rest/user/whoami"
```

**What you should see:** check whether `Access-Control-Allow-Origin` is absent, a fixed
specific value, a literal `*`, or — the dangerous case (Section 1, Drill 3) — an exact
reflection of the `evil.example` Origin you just sent, especially if paired with
`Access-Control-Allow-Credentials: true`. Record what you actually observe; full
walkthrough and both cases explained: [`labs/day07/SOLUTION.md`](../labs/day07/SOLUTION.md).

### Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -sI juiceshop:3000 | head -1 | grep -q 200 && echo TARGET_OK"
```

Expected: `TARGET_OK`. Full detail: `labs/day07/SOLUTION.md`.

## 3. Defense Lab — Security Headers and Correct CORS at the Edge

`juiceshop` is a third-party image — you don't own its source, so today's defenses
don't patch its code; they add a reverse proxy in front of it that layers the missing
protections on top. This is the realistic pattern for hardening any app you consume
rather than author.

### Defense 1 — Security headers via a reverse proxy (before/after)

`labs/day07/hardened/nginx.conf` puts `nginx:alpine` in front of `juiceshop`, adding
`add_header` directives for every header named in Section 1. Compare the exact same
underlying app two ways:

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "echo '--- direct ---'; curl -sI juiceshop:3000/; echo '--- hardened ---'; curl -sI hardened:8080/"
```

**What you should see:** the `juiceshop:3000` block missing some subset of the
checklist (Step 4); the `hardened:8080` block showing all six headers present, with
nothing about `juiceshop`'s own code changed. Full expected output:
[`labs/day07/SOLUTION.md`](../labs/day07/SOLUTION.md).

### Defense 2 — Correct CORS (before/after)

```sh
docker compose exec attacker sh -c "curl -s -H 'Origin: https://evil.example' -I hardened:8080/rest/user/whoami"
```

**What you should see:** `Access-Control-Allow-Origin: https://trusted-partner.example`
— a fixed allowlist entry the reverse proxy always returns, never a reflection of
whatever `Origin` header a caller happens to send. This is the direct fix for Step 5's
misconfiguration case and Drill 3's exercise: the allowed origin is a value the server
decides on its own, not an echo of client-controlled input.

### Defense 3 — Named but not re-demonstrated here

- **`SameSite` cookies** — the exact Day 4/Day 9 defense against cross-site request
  forgery; named precisely here because it's a cookie *attribute*, not a response
  header, and today's Defense Lab focuses on headers and CORS specifically. Day 9
  re-attacks and re-verifies this one directly.
- **CSP nonces/hashes for inline scripts** — a strict `default-src 'self'` (what
  `hardened/nginx.conf` ships) blocks *all* inline `<script>` tags, which is the right
  default but breaks apps that rely on them; a production CSP for such an app would add
  a per-request nonce or a script hash instead of loosening `default-src` back open —
  named as the next refinement step, not built here, since `juiceshop`'s own frontend
  isn't being modified today.
- **Terminating real TLS in front of HSTS** — Section 1 already named this: HSTS is
  only meaningful with TLS actually present. This lab's `hardened` proxy is
  intentionally plain-HTTP-only to stay a single day's scope; a real deployment would
  terminate TLS at this same edge (or one hop further out) before HSTS does anything.
- **Rate limiting / WAF rules** — out of today's specific scope (headers + CORS); Day
  11's detection lab is where request-volume-based defenses get built and verified.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Name the missing security headers and their risk

You capture this raw response from an app under review:

```
HTTP/1.1 200 OK
Content-Type: text/html; charset=utf-8
Content-Length: 4213
Server: nginx
Set-Cookie: session=abc123; Path=/
```

Name every header from Section 1's list that's missing, and for each one, name the
*specific* risk its absence reintroduces (not a generic "less secure").

**Hint:** go down the Section 1 list one at a time — CSP, HSTS, X-Frame-Options,
X-Content-Type-Options, Referrer-Policy, Permissions-Policy — and ask "what attack does
this one specifically stop?" Also look closely at the `Set-Cookie` line against Day 4's
cookie attributes — is anything missing there too?

**Solution sketch:**

- **`Content-Security-Policy`** missing — no restriction on which origins scripts can
  load from or execute from; a successful XSS injection (Day 8) runs with no
  header-level mitigation at all.
- **`Strict-Transport-Security`** missing — no protection against a downgrade
  (SSL-stripping) attack forcing this site back to plain HTTP on a repeat visit.
- **`X-Frame-Options`** missing — this page can be framed by any other origin,
  reopening the clickjacking risk CSP's `frame-ancestors` or this header would close.
- **`X-Content-Type-Options`** missing — the browser may MIME-sniff the response body
  instead of trusting `Content-Type`, reopening sniffing-based content confusion.
- **`Referrer-Policy`** missing — this page's full URL may leak via the `Referer`
  header on any outbound request it triggers, at the browser's own default policy
  rather than an explicit, deliberate choice.
- **`Permissions-Policy`** missing — no explicit denial of camera/geolocation/
  microphone access, so a successful script injection could invoke them if the browser
  would otherwise allow it.
- **Bonus, the cookie itself:** `Set-Cookie: session=abc123; Path=/` has **no `Secure`,
  no `HttpOnly`, no `SameSite`** — the exact Day 4/Day 9 cookie hardening is entirely
  absent, meaning this session cookie could be sent over plain HTTP, read by any script
  via `document.cookie` (worse if XSS is also present, per the CSP point above), and
  attached to cross-site requests with no restriction.

### Drill 2 — Predict the tamper addon's effect on a different request

Using [`mitm/tamper_addon.py`](../labs/day07/mitm/tamper_addon.py) exactly as shipped,
predict the output of each of these two requests routed through `proxy`, and say why:

1. `curl -x proxy:8080 'http://juiceshop:3000/rest/products/search?q=banana'`
2. `curl -x proxy:8080 'http://juiceshop:3000/rest/user/whoami'`

**Hint:** re-read the addon's `request()` function — what two conditions does it check
before rewriting anything, and does each URL above satisfy both?

**Solution sketch:**

1. **Rewritten.** The path starts with `/rest/products/search` and the query string
   has a `q` parameter — both conditions match, so `q=banana` is silently rewritten to
   `q=juice` before `juiceshop` ever sees it; the response reflects results for
   `"juice"`, not `"banana"`.
2. **Not rewritten, passed through unchanged.** The path is `/rest/user/whoami`, which
   doesn't start with `/rest/products/search` — the addon's `if` condition is false, so
   `request()` does nothing and the request reaches `juiceshop` exactly as `curl` sent
   it. This is the same behavior as Step 2's plain pass-through request, before Step 3
   ever hits the matching path.

### Drill 3 — Explain a CORS misconfiguration

You send this request:

```
GET /rest/user/whoami HTTP/1.1
Host: shop.example
Origin: https://attacker-controlled.example
Cookie: session=abc123
```

and get back:

```
HTTP/1.1 200 OK
Access-Control-Allow-Origin: https://attacker-controlled.example
Access-Control-Allow-Credentials: true
Content-Type: application/json

{"username":"victim","role":"user"}
```

Explain specifically why this is a dangerous misconfiguration, and name the one-line
fix.

**Hint:** the response's `Access-Control-Allow-Origin` value is *identical* to the
`Origin` header the request just sent — is that a coincidence, or is the server doing
something specific with whatever `Origin` it receives? Then ask what a script running
on `attacker-controlled.example` itself could now do with this response.

**Solution sketch:** the server isn't checking the requesting origin against an
allowlist at all — it's **reflecting back whatever `Origin` header the request
happened to carry**, verbatim, as the value of `Access-Control-Allow-Origin`. Combined
with `Access-Control-Allow-Credentials: true`, this means a page hosted on literally
any origin — including one an attacker fully controls — can make this exact
*credentialed* request (the victim's browser attaches `session=abc123` automatically,
since the request is same-browser, just cross-origin) and then **read the JSON
response via JavaScript**, something SOP would otherwise block. In effect: any site on
the internet can silently exfiltrate this victim's authenticated data just by getting
them to load a page with a background `fetch` on it. The fix: replace the reflection
logic with a real allowlist check — only ever set `Access-Control-Allow-Origin` to a
value the server itself decides is trusted (a fixed literal, or an origin checked
against a hardcoded list), never an echo of client-supplied input — exactly what
[`hardened/nginx.conf`](../labs/day07/hardened/nginx.conf)'s Defense 2 does.

### Drill 4 — Classify these methods as safe and/or idempotent

For each scenario, say whether the method used is (a) safe, (b) idempotent, neither, or
both — and flag which scenario is a real design bug because of a mismatch between the
method used and what it actually does.

1. `GET /api/reports/2024-annual` — retrieves a report.
2. `DELETE /api/users/42` — removes user 42; a repeat call on an already-deleted user
   returns `404` but leaves the same end state (user 42 absent).
3. `POST /api/orders` — creates a new order from the request body.
4. `GET /api/users/42/delete` — deletes user 42, implemented this way so a plain HTML
   link (`<a href="...">`) can trigger it without a form.

**Hint:** re-check Section 1's table for the definitions, then ask specifically what a
browser, crawler, or cache is *entitled to assume* about each method, and whether
scenario 4's actual behavior honors that assumption.

**Solution sketch:**

1. **Safe and idempotent** — a plain read, matches `GET`'s contract exactly.
2. **Not safe, but idempotent** — it changes state (not safe), but repeating it leaves
   the system in the same end state either time (idempotent) — exactly `DELETE`'s
   textbook profile.
3. **Not safe, not idempotent** — creates a new resource each time; two identical
   `POST`s produce two orders, not one order re-affirmed. Also `POST`'s textbook
   profile.
4. **The bug.** This is a `GET` request that has a **destructive, non-idempotent-in-
   effect side effect** (a first deletion changes state; hitting the same link again
   after account 42 no longer exists is a no-op only because the resource is already
   gone, not because the endpoint was designed to be idempotent) — violating `GET`'s
   contract that it be safe. Concretely dangerous because every layer above the app
   assumes `GET` is side-effect-free: a browser can pre-fetch this link speculatively, a
   link-preview bot (Slack, an email client) can fetch it just to render a preview, and
   a shared cache is entitled to serve or re-request it without asking — any of which
   could delete the account with no user ever clicking anything. The fix: destructive
   actions belong behind `POST`/`DELETE`, never a bare `GET`, precisely so that nothing
   upstream of the app treats the request as harmless to send automatically.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name the specific parameter you watched get tampered
  (`q=orange` → `q=juice`), and which CORS response you actually observed in Step 5 —
  absent, fixed, wildcard, or the dangerous reflected-origin case — versus which parts
  (the abstract SOP/CORS distinction, the clickjacking mechanics behind
  `X-Frame-Options`) you only reasoned through conceptually via Section 1 and the
  Drills, not against a live capture.
- **How:** walk through routing `curl` through `proxy` with `-x proxy:8080` — was
  seeing the tamper addon's rewrite in the response, versus in `docker compose logs
  proxy`'s comment field, the more convincing proof to you that the request was
  actually altered in flight?
- **What defended it:** compare `juiceshop:3000` against `hardened:8080` for both the
  header check and the CORS probe — which specific header's absence, or which CORS
  response, surprised you most once you saw the actual difference?
- **What confused me:** anything about why SOP blocks *reading* a cross-origin response
  but not *sending* the cross-origin request in the first place, or about why a
  wildcard `Access-Control-Allow-Origin` and `Access-Control-Allow-Credentials: true`
  can't be combined, that didn't click on first pass.
- **One thing to revisit:** pick one term from today (origin, SOP, CORS, preflight,
  CSP, HSTS, idempotent, intercepting proxy) to re-explain from memory before Day 8,
  without looking back at this file.

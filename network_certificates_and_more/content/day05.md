# Day 5 — Automation with ACME (Pebble)

> Unfamiliar term? Look it up in [GLOSSARY.md](GLOSSARY.md).

Read this before starting the lab. Budget: ~3.5 hours (75–90 min
theory/reading, ~105 min guided lab, ~30–45 min exercises + drills).

---

## Learning objectives

By the end of today you should be able to:
- State precisely what ACME automates: not certificate issuance itself
  (a CA could always issue programmatically), but the **"prove you control
  the name" step** — domain control validation — that a public CA
  requires before it will vouch for a name-to-key binding at all.
- Name the three ACME challenge types (HTTP-01, DNS-01, TLS-ALPN-01), what
  each one proves, and pick the right one for a given network constraint
  (e.g., port 80 blocked, or no way to touch DNS).
- Explain why classic certificate **revocation** broke down in practice
  (CRLs don't scale, OCSP leaks and stalls), what **OCSP stapling** tried
  to do about it, and what the industry actually relies on in 2026
  (browser-pushed revocation data plus short certificate lifetimes).
- Explain what a **Certificate Transparency log** is and what problem it
  solves that revocation and the four checks don't.
- Run the real certbot → ACME issuance workflow end to end against a local
  Pebble server, and explain every trust decision it makes along the way
  (which CA certbot has to be told to trust, and why — this is check 4
  again, just automated).
- Map today's local Pebble flow onto AWS ACM + ALB/NLB TLS termination —
  read-only, no AWS account touched — and say precisely which parts are
  "the same idea, at scale" and which parts genuinely differ.

---

## The mental model: ACME automates proving you control the name

Day 1 gave you the sentence every day of this course is a variation on:

> **A certificate is a signed statement binding a name to a public key.**

And the four checks, always in this order: **signature chain → validity
dates → name match → trust anchor.**

Every day so far, you've been the CA. You typed the CN and SAN yourself
(`ca/issue-server-cert.sh example.local example.local`) and your own script
signed whatever you asked it to sign, no questions asked. That's fine for a
private lab CA — you already know who you are — but it's precisely the
thing a **public** CA cannot do. If Let's Encrypt or DigiCert let anyone
type in any domain name and get a signed certificate for it with no
verification, the entire trust model collapses: a certificate would no
longer mean "someone vetted that this key belongs to this name," it would
just mean "someone typed a name into a form."

So before a public CA will sign anything, it needs a way to check: **does
whoever is asking for `example.com`'s certificate actually control
`example.com`?** That check — domain control validation — used to be a
manual, human process (upload a file, click a confirmation email, wait a
day). **ACME (Automatic Certificate Management Environment)** is the
protocol that automates it. Nothing about the *certificate* changes — it's
still a signed statement binding a name to a key, still verified with the
same four checks by everyone downstream. What ACME automates is
**everything upstream of issuance**: proving control, requesting the
signature, receiving the cert, and — the part manual issuance made everyone
skip in practice — renewing it constantly, automatically, before it ever
gets close to expiring.

Today you run that exact real-world workflow — the same protocol Let's
Encrypt, and every ACME-speaking public CA, actually implements — entirely
offline, against **Pebble**, Let's Encrypt's own test ACME server, built
specifically so nobody has to touch a real domain or a real CA to learn
this.

---

## Theory: challenge types, revocation, and Certificate Transparency

### The three ACME challenge types

An ACME **challenge** is the specific mechanic by which you prove control
of a name. The CA's ACME server picks a random token, and you have to
demonstrate — via some channel only the real controller of the name could
plausibly control — that you received it and can present it back tied to a
key you hold. There are three challenge types in wide use, and which one
you can use depends entirely on which network path you actually control:

| Challenge | What you prove | How | Needs |
|---|---|---|---|
| **HTTP-01** | You control what's served over HTTP at this domain | CA fetches `http://<domain>/.well-known/acme-challenge/<token>` and checks the response body against an expected value derived from your account key | Inbound port 80 reachable from the CA, for that one request |
| **DNS-01** | You control this domain's DNS records | CA queries a `TXT` record at `_acme-challenge.<domain>` and checks its value | Ability to create/update a DNS TXT record (via your DNS provider's API, or manually) — **no inbound port needed at all** |
| **TLS-ALPN-01** | You control what's served over TLS at this domain | CA opens a TLS connection to the domain on port 443, negotiates a special ALPN protocol (`acme-tls/1`), and checks a self-signed certificate you serve containing the expected token | Inbound port 443 reachable from the CA, for that one handshake |

**When to use which** — this is the operational judgment call, not just
trivia:
- **HTTP-01** is the default almost everyone reaches for first: simplest to
  automate if you already run a web server on port 80, no DNS API
  integration needed. Fails immediately if port 80 is firewalled, or if
  you're issuing for a **wildcard** name (`*.example.com`) — ACME CAs (per
  the CA/Browser Forum Baseline Requirements) don't allow HTTP-01 or
  TLS-ALPN-01 for wildcards, only DNS-01.
- **DNS-01** is the only option when port 80/443 genuinely can't be reached
  from the internet (internal services, strict egress-only firewalls) —
  because it never needs an inbound connection to your infrastructure at
  all, only a DNS record change. It's also the *only* challenge that
  supports wildcard issuance. The tradeoff: it needs your DNS provider to
  have a scriptable API (or a lot of manual TTL-waiting patience), and
  whoever holds that DNS API credential can issue certificates for
  anything in the zone — a real, if narrow, security consideration.
- **TLS-ALPN-01** exists for a specific niche: you can serve on 443 but
  genuinely cannot serve arbitrary HTTP paths there (e.g., a load balancer
  in TCP-passthrough mode where you don't control the HTTP layer at all,
  or you don't want to touch port 80 config for the validation). It's the
  least commonly used of the three in practice but solves a real gap.

Today's guided lab uses HTTP-01 (it's what the toolbox/nginx setup naturally
supports); Exercise 4 below and the lab's optional DNS-01 note walk you
through when you'd reach for DNS-01 instead.

### Revocation: why it broke, and what replaced it

The four-check model has a hole none of the four checks fill: what if a
certificate is completely valid by every check — good signature, unexpired
dates, correct name, trusted root — but the CA (or the certificate holder)
has decided it should no longer be trusted, *before* its `notAfter` date?
Maybe the private key leaked. Maybe the domain changed ownership. That's
**revocation**, and it's a genuinely separate concept from the four checks:
those four ask "was this ever validly issued and is it still within its
stated window," revocation asks "has someone since decided to take that
back early."

Two classic mechanisms exist, and both have serious practical problems.
That history is why the rules changed, so it's worth knowing:

- **CRLs (Certificate Revocation Lists)** — the CA publishes a signed list
  of every serial number it has revoked. A verifier is supposed to
  download this list and check the cert's serial against it. The problem
  is scale: a large public CA's CRL can be enormous, it has to be
  re-fetched periodically, and fetching it for every single connection
  would be crushingly slow — so in practice, almost nothing actually does
  this reliably for ordinary TLS connections.
- **OCSP (Online Certificate Status Protocol)** — instead of downloading
  the whole list, the verifier asks the CA directly, in real time, "is
  *this one* serial number still good?" This sounds better, but creates
  two new problems: (1) **latency** — every connection now has an extra
  round trip to a CA server before the handshake can even be trusted, and
  if that OCSP responder is slow or down, browsers historically chose to
  **soft-fail** (proceed anyway) rather than block the internet on a CA's
  uptime — which quietly defeats the entire point for anyone who wanted a
  genuinely revoked cert rejected; and (2) **privacy** — the CA now learns,
  in real time, exactly which sites you're visiting, since your browser is
  asking it directly, live, per-connection.

**OCSP stapling** was the attempted fix. The **server**, not the client,
fetches its own OCSP response from the CA ahead of time, caches it, and
"staples" that CA-signed response onto every handshake. The client checks
the attached statement instead of calling the CA itself: no extra round
trip, no browsing history leaked. But stapling never closed the hole. A
client can't tell "this server doesn't staple" from "an attacker stripped
the staple," so a missing staple was still soft-fail. The only hard-fail
option, the **OCSP Must-Staple** certificate extension, saw almost no
adoption.

**What the industry actually does now (2026):**

- **CRLs are back, and OCSP is on its way out.** The CA/Browser Forum made
  OCSP optional and CRLs mandatory in 2024. Let's Encrypt removed OCSP URLs
  from its certificates in May 2025 and shut its OCSP responders down in
  August 2025. It is CRL-only now.
- **Browsers push revocation data to themselves.** Instead of asking the
  CA per connection, the browser vendor collects every CA's CRLs and ships
  a compact summary with regular updates: **CRLite** in Firefox (on for
  all desktop users since Firefox 137, 2025) and **CRLSets** in Chrome
  (Chrome hasn't done live OCSP for ordinary certificates in years). No
  per-site lookup and no privacy leak. The catch: CRLite aims to cover
  every revocation, while CRLSets are a curated selection.
- **Short lifetimes are the real answer.** If a certificate can only live
  a few weeks, a missed revocation can only hurt for a few weeks. The
  CA/Browser Forum's ballot SC-081 (2025) caps publicly trusted TLS
  certificates at 200 days from March 2026, 100 days from March 2027, and
  47 days from March 2029. That only works because ACME makes renewal
  automatic. That's today's topic.

Stapling still exists. nginx still has `ssl_stapling on;`, and it still
does something for CAs that run OCSP. With a Let's Encrypt certificate
today it does nothing: the certificate has no OCSP URL to fetch from.

### Certificate Transparency: a different problem than revocation

Certificate Transparency (CT) logs solve a problem revocation doesn't even
attempt to address: **how would anyone even find out** that a CA
mis-issued a certificate for their domain in the first place — to someone
else, without their knowledge? Revocation only works if someone *notices*
a bad cert exists and asks the CA to revoke it; if nobody ever notices,
revocation never triggers.

CT logs are public, append-only, cryptographically verifiable (Merkle-tree)
records that every publicly trusted certificate must be submitted to
before major browsers will accept it (this is enforced today, not
optional — Chrome, for instance, requires CT proof for any cert it trusts).
Anyone — including the actual domain owner — can monitor a CT log for
certificates issued for their own domain and immediately notice if a CA
they never asked issued one. This is a **detection** mechanism, not a
prevention one: CT doesn't stop a compromised or careless CA from
mis-issuing, it makes mis-issuance impossible to hide, which turns out to
be a far stronger deterrent and far more scalable than any manual audit
could ever be. It's also the mechanism that has caught and led to the
distrust of multiple real CAs over the years (Day 6 covers specific named
incidents).

---

## Guided lab

All commands run through `toolbox`, from `labs/`, exactly as every prior
day — this day just adds two new services (`pebble`, `challtestsrv`) on the
same `certlab` network. Read `labs/acme/README.md` alongside this section;
it documents the exact wiring (static IPs, ports, why each flag is set)
in more depth than repeated here.

### Part A — Bring the ACME stack up, and watch it fail first

Before `pebble` exists, certbot has nothing to talk to. Confirm that,
deliberately, so the working version later actually means something:

```bash
docker compose run --rm --entrypoint certbot toolbox \
  certonly --standalone --server https://pebble:14000/dir \
  -d test.local --agree-tos -m a@b.c --no-eff-email
```

**Expected (before Part A's `up` below has run):** a connection error —
something like `Connection refused` or DNS resolution failure against
`pebble:14000` — because nothing named `pebble` is listening on the
`certlab` network yet. Certbot will not get far enough to even discuss
challenges.

Now actually bring the ACME stack up:

```bash
docker compose up -d pebble challtestsrv
```

Confirm pebble's directory endpoint is reachable at all (this alone tells
you nothing about trust yet — `curl -k` here is *only* to prove pebble is
up; never use `-k` once you're doing anything that matters):

```bash
docker compose run --rm toolbox curl -sk https://pebble:14000/dir
# Expected: a JSON body listing ACME endpoint URLs (newAccount, newOrder, etc.)
```

### Part B — Wire up trust and domain resolution, then issue a real cert

Three one-time setup steps, each explained in full in
`labs/acme/README.md` — do them in order.

**1. Register `test.local` with challtestsrv**, so pebble's `-dnsserver`
override (pointed at challtestsrv) has an answer when it resolves the
domain you're about to request a cert for:

```bash
docker compose run --rm toolbox curl -s -X POST http://challtestsrv:8055/add-a \
    -d '{"host":"test.local","addresses":["10.77.30.10"]}'
# Expected: no output at all (challtestsrv replies 200 with an empty body)
```

Only registered names resolve. `docker-compose.yml` starts challtestsrv
with `-defaultIPv4 ""` and `-defaultIPv6 ""`, so any name you haven't
added gets no answer, just like a real unregistered domain.

**2. Extract Pebble's own test root**, so certbot can trust Pebble's HTTPS
endpoint without disabling verification entirely (see the "certbot
trusting Pebble" section of `labs/acme/README.md` for exactly why this is
a *different* CA from the one that will sign your issued certificate):

```bash
docker compose cp pebble:/test/certs/pebble.minica.pem acme/pebble.minica.pem
```

`docker compose cp`, not `exec`: the Pebble image has no shell or
utilities inside, only the Pebble binary.

**3. Issue the certificate.** This is the brief's acceptance command, with
the two additions Part B's setup above makes necessary — `-e
REQUESTS_CA_BUNDLE=...` (so certbot trusts Pebble's HTTPS endpoint) and
`--http-01-port 5002` (Pebble's own config, `labs/acme/pebble-config.json`,
tells it to validate HTTP-01 on port `5002`, not the privileged port `80` —
deliberately, so nothing in this lab needs root/`CAP_NET_BIND_SERVICE`) —
plus redirected `--config-dir`/`--work-dir`/`--logs-dir` so certbot's state
lands under the bind-mounted `/work` tree instead of being lost when the
`--rm` container exits:

```bash
docker compose run --rm --entrypoint certbot \
    -e REQUESTS_CA_BUNDLE=/work/acme/pebble.minica.pem \
    toolbox certonly --standalone --http-01-port 5002 \
    --preferred-challenges http -n \
    --server https://pebble:14000/dir \
    -d test.local --agree-tos -m a@b.c --no-eff-email \
    --config-dir /work/acme/certbot/config \
    --work-dir /work/acme/certbot/work \
    --logs-dir /work/acme/certbot/logs
```

**Expected:** certbot prints something ending in
`Successfully received certificate.`, followed by the paths to the issued
`fullchain.pem` and `privkey.pem` under
`/work/acme/certbot/config/live/test.local/`.

Narrate what just happened, mapping it back onto every day so far: certbot
proved control of `test.local` (via HTTP-01 — Pebble connected to
`toolbox:5002` and checked the token, resolving `test.local` through
challtestsrv exactly as Part B step 1 set up); Pebble then **signed** a
brand-new leaf certificate binding `test.local` to the key certbot
generated — the exact same "issuer's private key signs the document"
mechanic from Day 1, just triggered automatically instead of by you typing
a script command. **This chain will be signed by an intermediate Pebble
generated fresh when its container last started** — restart the `pebble`
container and re-run this command, and you'll get a certificate chaining
to a *different* intermediate (and root). That's deliberate on Pebble's part (see
`labs/acme/README.md`), not a lab bug.

Confirm the issued cert directly:

```bash
docker compose run --rm toolbox openssl x509 \
    -in /work/acme/certbot/config/live/test.local/cert.pem -noout -issuer -subject -dates
```

**Expected:**

```
issuer=CN = Pebble Intermediate CA 2c49c5
subject=
notBefore=Sep 30 16:22:22 2026 GMT
notAfter=Dec 29 16:22:21 2026 GMT
```

(the hex suffix and dates will differ). Yes, `subject=` is **empty**.
That's not a bug. Pebble leaves the Subject empty and puts the name only
in the Subject Alternative Name. Print it:

```bash
docker compose run --rm toolbox openssl x509 \
    -in /work/acme/certbot/config/live/test.local/cert.pem -noout -ext subjectAltName
# Expected:
# X509v3 Subject Alternative Name: critical
#     DNS:test.local
```

This is Day 2's rule made visible: check 3 matches the name against the
SAN and ignores the CN. A certificate with no CN at all is completely
valid. (The SAN is marked `critical` because the Subject is empty; a client that
can't read the SAN must reject the cert rather than find no name.)

Note the **90-day validity window** — `labs/acme/pebble-config.json` pins
Pebble's `default` profile to `validityPeriod: 7776000` (seconds; 90 days)
explicitly, matching real-world Let's Encrypt's own default certificate
lifetime, specifically so `certbot renew`'s real ~30-day-before-`notAfter`
threshold behaves the same way here as it would in production. `default`
is the *only* profile the lab defines, on purpose: when an order doesn't
name a profile (and certbot 2.9.0 can't), Pebble picks one of its
configured profiles at random — so a second, 6-day `shortlived` profile
would make this 90-day window, and drill-19's "run `renew` right after
issuing" not-yet-due skip, a coin toss. See `labs/acme/README.md`.

**90 days won't last.** It's Let's Encrypt's default today, but it's
shrinking: an opt-in 45-day profile exists since May 2026, the default
drops to 64 days in February 2027 and 45 days in February 2028, and a
6-day `shortlived` profile is already generally available. A fixed "renew
30 days before expiry" rule doesn't fit every lifetime. So certbot 4.1+
supports **ARI** (ACME Renewal Information, RFC 9773): the CA tells the
client when to renew. This lab's toolbox ships certbot 2.9.0, which has no
ARI and still uses the fixed 30-day rule. Drill-19 runs straight into it.

Confirm check 4 directly. The obvious attempt is to verify the leaf
against `chain.pem`, the file certbot downloaded next to it:

```bash
docker compose run --rm toolbox openssl verify \
    -CAfile /work/acme/certbot/config/live/test.local/chain.pem \
    /work/acme/certbot/config/live/test.local/cert.pem
```

**Expected: it fails.**

```
CN = Pebble Intermediate CA 2c49c5
error 2 at 1 depth lookup: unable to get issuer certificate
error /work/acme/certbot/config/live/test.local/cert.pem: verification failed
```

Read the depth: `1` is the intermediate. OpenSSL built leaf →
intermediate, then looked for whoever signed the intermediate and found
nothing. `chain.pem` holds only the intermediate, never the root. A root
is a trust anchor: the client must already have it, so the server never
sends it (Day 2).

So fetch Pebble's issuing root. Pebble serves it on its management API
(`:15000`), which uses the same minica-signed HTTPS certificate as the
directory, so `pebble.minica.pem` from step 2 verifies it:

```bash
docker compose run --rm toolbox curl -s \
    --cacert /work/acme/pebble.minica.pem \
    https://pebble:15000/roots/0 -o /work/acme/pebble-root.pem
```

Now verify properly, giving OpenSSL the root as the anchor and the
intermediate as a helper:

```bash
docker compose run --rm toolbox openssl verify \
    -CAfile /work/acme/pebble-root.pem \
    -untrusted /work/acme/certbot/config/live/test.local/chain.pem \
    /work/acme/certbot/config/live/test.local/cert.pem
# Expected: /work/acme/certbot/config/live/test.local/cert.pem: OK
```

The two flags are two different roles:
- `-CAfile` holds **trust anchors**. Anything here is trusted outright.
- `-untrusted` holds **intermediates** that OpenSSL may use to build the
  chain. They're used for path building, but trusted only if the chain
  they form ends at an anchor in `-CAfile`.

That's exactly what a browser does with the chain a server sends.
OpenSSL also has `-partial_chain`, which lets the first run succeed: it
accepts any certificate in `-CAfile` as an anchor, even an intermediate.
That is the "trust an intermediate as the anchor" shortcut. Know it
exists; don't use it to paper over a missing root.

Like the Pebble intermediate, this root is generated fresh on every
Pebble start. Restart `pebble` and the two drift apart: your saved
`pebble-root.pem` still verifies certificates issued *before* the restart,
but anything issued *after* chains to a new root — re-fetch `/roots/0`
(and re-issue anything you want to verify against it). Pebble keeps no
state across restarts, so the old root is gone from `/roots/0` for good.

### Part C — Serve the ACME-issued cert with nginx, and confirm the trust anchor changed

Every prior day's `nginx` certificate came from `ca/intermediate/` — the
private CA you built and have been trusting all course long. Today's
certificate did not: it's signed by an ACME intermediate Pebble generated
on its own. Part C exists to make that concrete, the same way Day 1
taught you to reason about trust anchors — by watching the *wrong* one
fail before the right one succeeds.

Stage the issued cert/key where nginx can reach them, same pattern as
every prior day:

```bash
docker compose run --rm toolbox bash -c "
  cp acme/certbot/config/live/test.local/fullchain.pem certs/test.local.fullchain.pem &&
  cp acme/certbot/config/live/test.local/privkey.pem   certs/test.local.key.pem
"
```

Activate today's config (`services/nginx-day05.conf`, shipped alongside
this file) and restart nginx to pick it up:

```bash
cp services/nginx-day05.conf services/active.conf
docker compose restart nginx
```

First, try verifying with the CA you'd reach for out of habit — your
*own* private CA from Days 2–4. Watch it fail:

```bash
docker compose run --rm toolbox curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
    --connect-to test.local:8443:nginx:443 \
    https://test.local:8443/
```

**Expected:** a TLS handshake failure — curl reporting a certificate
verification problem along the lines of "unable to get local issuer
certificate" (the specific curl exit code varies by curl/OpenSSL build;
the message text, not the numeric code, is what to read). This is
**check 4: trust anchor**, failing for a completely unsurprising
reason once you say it out loud: `ca-chain.cert.pem` is *your* CA's chain.
It has never signed anything Pebble issued, and never will — these are
two entirely unrelated CAs that happen to have both been used in this lab
on different days.

Now verify with the trust anchor that actually issued this chain —
Pebble's root, fetched from `/roots/0` in Part B. nginx serves
`fullchain.pem`, so the intermediate arrives in the handshake; curl only
needs the anchor:

```bash
docker compose run --rm toolbox curl --cacert /work/acme/pebble-root.pem \
    --connect-to test.local:8443:nginx:443 \
    https://test.local:8443/
# Expected: test.local is up -- issued by ACME (Pebble), Day 5
```

(Passing `chain.pem` here would also work, unlike `openssl verify` in
Part B: curl turns on OpenSSL's partial-chain mode by default, so it
accepts an intermediate as an anchor. Same shortcut, different default.)

Narrate the contrast: nothing about checks 1–3 changed between the two
attempts — same signature, same dates, same SAN (`test.local`, matching
the `--connect-to` target both times). The **only** thing that changed is
which trust anchor you handed `--cacert`, and that alone was the entire
difference between failure and success — the exact check-1-vs-check-4
distinction Day 1 built this whole course around, now demonstrated against
a certificate that arrived via automation instead of your own hand-run CA
scripts.

---

## AWS bridge — how this maps onto ACM and ALB/NLB (read-only, no account)

Everything above is the *real* production ACME workflow, just pointed at a
test CA instead of the real Let's Encrypt. This section is a conceptual
map from what you just ran onto AWS's managed equivalent — you are not
expected to touch an AWS account for this, and nothing here requires one.

**AWS Certificate Manager (ACM) is a public CA wired into AWS's own
services, but standard ACM does not speak ACME.** You request a
certificate through the console/API, and AWS does domain-control
validation its own way:

- **DNS validation** (the default and recommended option) is the *same
  idea* as DNS-01 but not DNS-01. ACM gives you one CNAME record to create
  and leave in place **permanently**. DNS-01 uses a fresh
  `_acme-challenge` TXT value per order. Because ACM's record persists, ACM
  can re-validate on every renewal without you doing anything.
- **Email validation** is the pre-ACME manual mechanism: someone clicks a
  link in an email. Renewal needs a human again. Prefer DNS.
- **HTTP validation** exists only for certificates used with CloudFront,
  and can't issue wildcards.

Since February 2026, public ACM certificates are valid for 198 days and
renew about 45 days before expiry. Separately, in June 2026 AWS launched
an **ACME endpoint for ACM**: real ACME clients like certbot can get ACM
certificates, authenticated with External Account Binding (EAB) for
domains an admin has pre-validated. That's the one place today's certbot
workflow maps onto AWS almost unchanged.

**The renewal automation you just watched certbot need to be told to do
(re-running `certonly`/`renew` before `notAfter`) is exactly what ACM does
for you, silently, forever, for any certificate it manages** — as long as
the DNS validation record ACM originally used is still in place. This is
the single biggest practical difference from today's lab: your Pebble
certs will sit there and expire because nothing re-runs certbot for you
automatically (a real deployment would put `certbot renew` on a cron/timer
— Day 5's drill-19 covers exactly what happens when that automation
itself fails); ACM's renewal is fully managed by AWS with no cron job for
you to maintain or forget, **provided** the certificate is actually
**attached to** an ACM-integrated resource and the validation record
hasn't been deleted.

**ALB and NLB terminate TLS the same way nginx did in this lab, just as a
managed service instead of a config file you wrote yourself:**

- An **Application Load Balancer (ALB)** terminates TLS at the load
  balancer using a certificate you attach from ACM (or one you imported)
  — this is directly analogous to `ssl_certificate`/`ssl_certificate_key`
  in every nginx config this course has written; ACM is just where the
  cert/key material lives and how it's kept current, instead of files in
  `labs/certs/`.
- A **Network Load Balancer (NLB)** can either pass TLS straight through
  to the target (in which case *your* backend does exactly what nginx has
  done all course long) or terminate TLS at the NLB itself using an
  ACM certificate, functionally the same termination point as an ALB, just
  at a lower network layer.
- Either way, the four checks a *client's browser* runs against whatever
  certificate the load balancer presents are **unchanged** from Day 1 —
  signature chain, dates, name match, trust anchor. What ACM changes is
  entirely upstream of that: how the cert was issued, and whether it stays
  current without a human remembering to renew it.

If you've worked through `aws_network_components/` or
`aws_computing_loadbalancing_communication_components/` already, this is
the same ALB/NLB you saw there — today just fills in *where the
certificate they present actually comes from* and *why it never seems to
expire in a well-run AWS account*.

---

## Exercises

Answer these before moving to the drills. Each has a hint ladder — try
without looking, then peel back one hint at a time.

### Exercise 1

**A colleague's server sits behind a corporate firewall that blocks all
inbound traffic on port 80, but allows inbound 443, and separately they
have full API access to their DNS provider. Which ACME challenge type(s)
would actually work for them, and which would fail outright? Be specific
about why each one does or doesn't.**

<details>
<summary>Hints</summary>

- Nudge: go back to the challenge-type table's "Needs" column and check
  each one against exactly what's described — inbound 80 blocked, inbound
  443 open, DNS API available.
- Tool to run: nothing to run — this is a direct table lookup, but explain
  *why*, not just which row.
- Partial diagnosis: two of the three challenge types have a real path to
  success here; only one is flatly ruled out by the firewall rule as
  stated.

</details>

<details>
<summary>Solution</summary>

**HTTP-01 fails outright** — it requires the CA to reach port 80 inbound,
and that's exactly what's blocked. No amount of DNS access or open 443
helps HTTP-01 specifically; it only ever validates over port 80.

**TLS-ALPN-01 would work** — it needs inbound 443, which is open, and
nothing about it depends on port 80 or DNS at all; the CA opens a TLS
connection to port 443 and checks the special `acme-tls/1` ALPN
handshake.

**DNS-01 would also work**, and for an entirely independent reason — it
needs *no* inbound port at all, only the ability to publish a TXT record,
which they have via their DNS provider's API.

This colleague has two viable options (TLS-ALPN-01 or DNS-01) and one that
is simply off the table (HTTP-01) — the firewall rule as described doesn't
create a single forced answer, it eliminates exactly one of the three.

</details>

### Exercise 2

**You need a wildcard certificate for `*.example.com`. Which challenge
type(s) can issue it, and which can't — and why does the restriction
exist specifically for wildcards rather than for ordinary single-name
certs?**

<details>
<summary>Hints</summary>

- Nudge: re-read the HTTP-01 row's last sentence in the theory table above
  — it names this restriction directly.
- Tool to run: nothing to run — reasoning exercise.
- Partial diagnosis: think about *where* the proof of control actually
  happens for each challenge type, and whether that location is even
  well-defined for a name like `*.example.com` (which isn't a single
  reachable host at all).

</details>

<details>
<summary>Solution</summary>

**Only DNS-01 can issue a wildcard certificate.** ACME CAs don't allow
HTTP-01 or TLS-ALPN-01 for wildcard names. That rule comes from CA policy
(the CA/Browser Forum Baseline Requirements), not from the ACME protocol
itself.

The reason ties directly back to what each challenge actually proves.
HTTP-01 and TLS-ALPN-01 prove control by reaching a **specific host** —
`example.com` resolves to one (or a few) actual IP addresses you can
connect to and challenge. But `*.example.com` isn't a single host at all —
it's every possible subdomain, most of which don't exist yet and have no
server to challenge. DNS-01, by contrast, proves control of the **zone**
itself (you can write a TXT record at `_acme-challenge.example.com`), and
control of the zone is exactly the thing that legitimately implies control
over every subdomain under it — which is precisely what a wildcard
certificate claims to vouch for. So the policy isn't arbitrary: it follows
directly from what each challenge mechanically proves versus what a
wildcard certificate claims.

</details>

### Exercise 3

**A certificate was revoked yesterday after a key compromise. Its
`notAfter` is still months away, and the attacker holding the stolen key
is impersonating the site. Using the four-check model from Day 1, explain
why the four checks alone can't stop this. Then explain what, in 2026,
actually protects a visitor — and why "turn on OCSP stapling" was never a
complete answer.**

<details>
<summary>Hints</summary>

- Nudge: revocation is not one of the four checks — go back to the theory
  section above and reread the sentence that says this explicitly.
- Tool to run: nothing to run — this is about where revocation sits
  relative to the four-check model, not about running a command.
- Partial diagnosis: checks 1–4 all pass. So the answer has to be
  something outside them. Ask where the browser gets revocation data
  today, and who controls the server that would staple.

</details>

<details>
<summary>Solution</summary>

All four checks pass: the signature is fine (revocation changes no bytes
of the cert), the dates are fine, the name matches, the root is trusted.
**None of the four checks asks "has the CA taken this back?"** Revocation
is a separate layer on top of them.

What actually protects the visitor in 2026:
- **Browser-pushed revocation data.** The CA publishes the serial in its
  CRL. Firefox's CRLite picks it up in its next update and rejects the
  cert. Chrome rejects it only if the revocation makes it into a CRLSet,
  which covers a selection, not everything.
- **Short lifetime.** Whatever the browser misses, the certificate itself
  still dies at `notAfter`. That's why lifetimes are shrinking (SC-081):
  a 47-day cert bounds this exposure far tighter than a one-year cert.

Why stapling wasn't the answer: the attacker runs the impersonating
server, so they simply don't staple. A client can't tell that apart from
an honest server that never enabled stapling, so it soft-fails and
connects. Only a certificate carrying **OCSP Must-Staple** made a missing
staple fatal, and almost nobody used it. Let's Encrypt has since dropped
OCSP entirely.

</details>

### Exercise 4

**Your team runs a batch of internal services that must never accept
inbound connections from the public internet at all — not on port 80, not
on 443, nothing. You still want each of them to have a properly issued,
automatically renewing public certificate. Which ACME challenge type
makes this possible, and sketch — in terms of this lab's own
`challtestsrv` wiring — what the automation would actually need to do on
every renewal.**

<details>
<summary>Hints</summary>

- Nudge: this is Exercise 1's logic taken to its extreme — no inbound port
  at all, not even 443.
- Tool to run: nothing required to run, but if you want to see the
  mechanism directly: `curl -s -X POST http://challtestsrv:8055/set-txt -d
  '{"host":"_acme-challenge.test.local","value":"<any-string>"}'` against
  this lab's own `challtestsrv` shows you exactly the API call a DNS-01
  automation hook would make in production, just aimed at a real DNS
  provider's API instead.
- Partial diagnosis: the automation's job is entirely about *writing a
  DNS record*, at the right moment, with the right value — it never
  touches the service's own network path at all.

</details>

<details>
<summary>Solution</summary>

**DNS-01** is the only challenge type that fits — it's the only one that
requires zero inbound connectivity to the service being issued a
certificate for, which is exactly this constraint.

In terms of this lab's own wiring: today's guided lab used certbot's
`--standalone` plugin, which only knows how to *serve* HTTP-01
responses — it has no DNS-01 support on its own (drill-18 shows the
error). A DNS-01 flow instead
uses certbot's `--manual` mode (or a DNS-provider-specific certbot
plugin) with an **auth hook** — a script certbot runs at exactly the
moment it needs a challenge published, and again to clean it up. Against
this lab's own `challtestsrv`, that hook would be two API calls:

```
# auth hook (before certbot asks pebble to validate):
curl -s -X POST http://challtestsrv:8055/set-txt \
    -d '{"host":"_acme-challenge.test.local","value":"<token-derived value certbot gives the hook>"}'

# cleanup hook (after validation, success or failure):
curl -s -X POST http://challtestsrv:8055/clear-txt \
    -d '{"host":"_acme-challenge.test.local"}'
```

Pebble (already configured with `-dnsserver` pointed at `challtestsrv` in
this lab — see `labs/acme/README.md`) would query
`_acme-challenge.test.local` for a TXT record as part of validating a
DNS-01 challenge, get back whatever value the auth hook just set, and
issue the cert — no inbound connection to `toolbox` or any target service
ever required. In production, the *only* thing that changes is that the
hook script calls a real DNS provider's API (Route 53, Cloudflare, etc.)
instead of `challtestsrv`'s test API — the mechanism is identical; only
the DNS backend being written to is real. This exercise is left
un-run in the required guided lab (Part B above uses HTTP-01 only) — the
API calls above are safe to try against this lab's own `challtestsrv` if
you want to see the write/query cycle directly.

</details>

---

## Drills

Four drills are waiting for you in `labs/drills/drill-17/` through
`drill-20/`, each targeting a different way the ACME automation you just
ran can fail:

- **drill-17** — HTTP-01 challenge validation with the challenge port
  unreachable
- **drill-18** — the wrong challenge type requested for the plugin/setup
  in use
- **drill-19** — a certbot renewal that doesn't actually renew anything,
  so the deploy hook it was meant to exercise never runs
- **drill-20** — certbot doesn't trust Pebble's ACME endpoint at all
  (the `REQUESTS_CA_BUNDLE` step from Part B skipped)

Each drill directory has a `SYMPTOM.md` stating only the observed output
and the command that produced it — no diagnosis. Work the drill yourself
first. Full graduated-hint walkthroughs live in
`labs/drills/solutions/drill-NN.md` if you get stuck; resist opening them
until you've actually tried something.

## Journal template

```
### Day 5 — Automation with ACME (Pebble)
Key concept in my own words: ...
Which challenge type would I reach for, and why, for [a service I actually run]: ...
What confused me and how I resolved it: ...
Drill I found hardest and what finally gave it away: ...
```

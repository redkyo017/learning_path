# Day 5 — Automation with ACME (Pebble)

Read this before starting the lab. Budget: ~3.5 hours (75–90 min
theory/reading, ~105 min guided lab, ~30–45 min exercises + drills).

A note before you start: this day's guided lab was authored without a live
Docker environment to test against — every command below is
correct-by-construction against Pebble's and certbot's own documented
config schema and flags, but the first time you actually run it, treat
yourself as doing the final verification pass the author couldn't. Where
something is genuinely uncertain rather than just "unverified," it's called
out explicitly as **DEFERRED**. Full detail on what's reasoned vs. what
still needs a live run lives in
`labs/acme/README.md` and the task report it points to.

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
- Explain why certificate **revocation** is effectively broken in practice
  (CRLs don't scale, OCSP leaks and stalls) and what **OCSP stapling**
  does about it.
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
  you're issuing for a **wildcard** name (`*.example.com`) — the ACME spec
  doesn't permit HTTP-01 for wildcards at all, only DNS-01.
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

### Revocation: why it's effectively broken, and what OCSP stapling does

The four-check model has a hole none of the four checks fill: what if a
certificate is completely valid by every check — good signature, unexpired
dates, correct name, trusted root — but the CA (or the certificate holder)
has decided it should no longer be trusted, *before* its `notAfter` date?
Maybe the private key leaked. Maybe the domain changed ownership. That's
**revocation**, and it's a genuinely separate concept from the four checks:
those four ask "was this ever validly issued and is it still within its
stated window," revocation asks "has someone since decided to take that
back early."

Two mechanisms exist, and both have serious practical problems:

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

**OCSP stapling** is the fix for the latency/reliability half of that
problem (not the privacy half, though it happens to help there too): the
**server** — not the client — periodically fetches its own OCSP response
from the CA ahead of time, caches it, and "staples" that pre-fetched,
CA-signed response onto the TLS handshake it sends to every client. The
client then checks a locally-attached, cryptographically signed "still
good" statement instead of making its own live network call to the CA at
all. This moves the OCSP round trip from "every client, every connection,
live" to "the server, in the background, periodically" — which is both
faster and doesn't leak per-visitor browsing history to the CA. It doesn't
fix everything (a stapled response can itself be a few hours or days
stale, and a server that's *compromised* has no incentive to staple an
honest "revoked" answer about its own cert), but it's the mechanism that
made OCSP actually workable at internet scale, and it's why you'll see
`ssl_stapling on;` in real nginx configs.

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
# Expected: {}
```

**2. Extract Pebble's own test root**, so certbot can trust Pebble's HTTPS
endpoint without disabling verification entirely (see the "certbot
trusting Pebble" section of `labs/acme/README.md` for exactly why this is
a *different* CA from the one that will sign your issued certificate):

```bash
docker compose cp pebble:/test/certs/pebble.minica.pem acme/pebble.minica.pem
```

**DEFERRED — needs live confirmation.** This path comes straight from
Pebble's own documentation; it was not possible to confirm by actually
running the container while authoring this lab. If it 404s, run
`docker compose exec pebble find / -maxdepth 4 -iname 'pebble.minica.pem'`
to locate the real path and use that instead.

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
to a *different* intermediate. That's deliberate on Pebble's part (see
`labs/acme/README.md`), not a lab bug.

Confirm the issued cert directly:

```bash
docker compose run --rm toolbox openssl x509 \
    -in /work/acme/certbot/config/live/test.local/cert.pem -noout -issuer -subject -dates
```

**Expected:** `subject=CN = test.local`, an `issuer=` naming a Pebble
intermediate (something like `CN = Pebble Intermediate CA ...`), and a
**90-day validity window** — `labs/acme/pebble-config.json` pins Pebble's
`default` profile to `validityPeriod: 7776000` (seconds; 90 days)
explicitly, matching real-world Let's Encrypt's own default certificate
lifetime, specifically so `certbot renew`'s real ~30-day-before-`notAfter`
threshold behaves the same way here as it would in production. (Pebble
also ships a `shortlived` profile, ~6 days, for testing renewal-adjacent
edge cases — this lab doesn't select it, precisely so drill-19's "run
`renew` right after issuing" scenario is a genuine, not-yet-due skip
rather than an artifact of an unrealistically short-lived test cert.)

Confirm check 4 directly, the same way Day 1 taught you to reason about
trust anchors: verify the issued leaf against Pebble's ACME intermediate
that certbot also downloaded alongside it:

```bash
docker compose run --rm toolbox openssl verify \
    -CAfile /work/acme/certbot/config/live/test.local/chain.pem \
    /work/acme/certbot/config/live/test.local/cert.pem
# Expected final line: cert.pem: OK
```

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

Now verify with the chain that actually signed this certificate — the one
certbot downloaded alongside it in Part B:

```bash
docker compose run --rm toolbox curl --cacert /work/acme/certbot/config/live/test.local/chain.pem \
    --connect-to test.local:8443:nginx:443 \
    https://test.local:8443/
# Expected: test.local is up -- issued by ACME (Pebble), Day 5
```

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

**AWS Certificate Manager (ACM) *is* an ACME-issuing CA, operated by
Amazon, wired directly into AWS's own services.** When you request a
public certificate through ACM, AWS runs the exact same domain-control
validation your Pebble lab just ran manually:

- **DNS validation** (ACM's default and recommended option) is, at the
  protocol level, the same idea as this lab's DNS-01: ACM gives you a
  specific CNAME record to create, and once it can resolve that record, it
  issues the cert — control proven via DNS, no inbound port needed,
  exactly the DNS-01 tradeoff table above.
- **Email validation** (ACM's older option) is *not* one of the three
  ACME challenge types above at all — it's the pre-ACME manual mechanism
  ACME was built to replace, kept in ACM mostly for legacy compatibility.
  If you ever see it offered, prefer DNS validation; it's the one that
  actually automates renewal cleanly.

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

**Only DNS-01 can issue a wildcard certificate.** HTTP-01 and TLS-ALPN-01
are both explicitly disallowed by the ACME spec for wildcard names.

The reason ties directly back to what each challenge actually proves.
HTTP-01 and TLS-ALPN-01 prove control by reaching a **specific host** —
`example.com` resolves to one (or a few) actual IP addresses you can
connect to and challenge. But `*.example.com` isn't a single host at all —
it's every possible subdomain, most of which don't exist yet and have no
server to challenge. DNS-01, by contrast, proves control of the **zone**
itself (you can write a TXT record at `_acme-challenge.example.com`), and
control of the zone is exactly the thing that legitimately implies control
over every subdomain under it — which is precisely what a wildcard
certificate claims to vouch for. The restriction isn't arbitrary
CA policy; it's a direct consequence of what each challenge mechanically
proves versus what a wildcard certificate actually claims.

</details>

### Exercise 3

**A browser visits a site whose certificate was revoked yesterday due to a
key compromise, but the certificate's own `notAfter` date is still eight
months away, and the server has **not** configured OCSP stapling. Using
only the four-check model from Day 1, explain why the browser might still
accept this connection — and then explain what OCSP stapling being
enabled would have had to do differently for the browser to actually
reject it.**

<details>
<summary>Hints</summary>

- Nudge: revocation is not one of the four checks — go back to the theory
  section above and reread the sentence that says this explicitly.
- Tool to run: nothing to run — this is about where revocation sits
  relative to the four-check model, not about running a command.
- Partial diagnosis: checks 1–4 could all pass perfectly here. The
  question is what *fifth* thing has to happen, and where that fifth thing
  actually gets its information from.

</details>

<details>
<summary>Solution</summary>

All four of Day 1's checks can pass cleanly on this certificate: the
signature chain is fine (revocation doesn't change any bytes of the
cert or invalidate the math), the dates are fine (`notAfter` is eight
months out, well within the validity window), the name matches, and the
root is trusted. **None of the four checks was ever designed to catch
"the CA changed its mind about this cert after issuing it"** — that's
exactly the gap the theory section called out: revocation is a genuinely
separate concept layered on top of the four checks, not one of them.

Without OCSP stapling, the browser's *only* way to learn about the
revocation is either a CRL fetch or a live OCSP query to the CA — and as
the theory section covered, browsers have historically **soft-failed**
(proceeded anyway) if that CRL/OCSP check is slow, unavailable, or simply
skipped for performance reasons. If nothing forces that live check to
happen and succeed, the browser has no way to find out the key was
compromised, and connects anyway.

With OCSP stapling **enabled**, the *server itself* would have needed to
fetch a fresh signed "this cert's status" statement from the CA
periodically. Once the CA's own OCSP responder reflects yesterday's
revocation, the server's next staple attempt would come back `revoked`
(or the server would simply stop being able to present a valid staple at
all) — and a correctly implemented client checks that stapled response as
part of the handshake and would reject the connection outright,
**without needing to make its own live network call to the CA**. The
missing piece in this scenario isn't a broken check — it's that nothing
in this specific setup was actually feeding revocation information to
the browser at all.

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
`--standalone` plugin, which only knows how to *serve* HTTP-01/TLS-ALPN-01
responses — it has no DNS-01 support on its own. A DNS-01 flow instead
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

# Day 6 — Attack, Defend & Capstone

Read this before starting the lab. Budget: ~4 hours (60–75 min
theory/reading, ~45 min guided attack lab, ~90–120 min capstone gauntlet,
~30 min teach-back writeup). This is the last day of the course — every
prior day's material gets used today, on purpose.

---

## Learning objectives

By the end of today you should be able to:
- Build a rogue CA, issue a fraudulent certificate from it for a name you
  don't control, and explain precisely *why* that certificate can pass
  checks 1 through 3 perfectly while only check 4 stands between it and
  being accepted.
- Explain SSL stripping and HTTPS downgrade attacks, and explain exactly
  how HSTS closes the specific gap they exploit — and where HSTS's own
  gap (first-visit trust-on-first-use) still is.
- Explain certificate pinning: what it checks instead of check 4, why
  mobile apps reach for it more than browsers do, and why it trades
  MITM-resistance for a real, self-inflicted brittleness risk on your own
  legitimate key rotations.
- Recount three real CA/PKI failures — DigiNotar, Heartbleed's certificate
  angle, and the Symantec distrust — each with the specific mechanism and
  the specific lesson it teaches, not just "a bad thing happened."
- Diagnose a broken TLS setup from a symptom alone, with no hints, drawing
  on every failure class from Days 1–5 plus today's rogue-CA and pinning
  additions.
- State, unprompted and in your own words, the full trust model this
  course was built around: what a certificate is, and the four-check
  verification order.

---

## The mental model, one more time — and today's punchline

Every day of this course has been a variation on one sentence:

> **A certificate is a signed statement binding a name to a public key.**

verified by four checks, always in this order:

> **signature chain → validity dates → name match → trust anchor.**

Day 1 already told you where this course was headed: check 1 asks whether
a chain is *internally consistent* — every signature really was produced
by the key it claims. Check 4 asks whether the *top* of that chain is
someone you actually decided to trust. A chain can pass check 1 (and 2,
and 3) perfectly and still fail check 4, because anyone can generate a
keypair, self-sign a root, and build a perfectly self-consistent chain
underneath it. **Internal consistency is not the same as
trustworthiness.**

Today you stop reading that sentence and build it. You will construct a
rogue CA, issue it a certificate for `example.local` that is
*indistinguishable*, field by field, from a legitimate one — correct
name, current dates, mathematically flawless signature — and watch a
client trust it anyway, the instant its root sits in the client's trust
store. Today's punchline, stated as plainly as this course can state it:

> **The rogue-CA attack shows that check 4 — trust anchor — is the ONLY
> thing standing between you and an attacker who can otherwise satisfy
> checks 1–3 perfectly.** And certificate pinning defends against exactly
> this by bypassing the trust-anchor question entirely: instead of asking
> "do I trust whoever signed this," it asks "is this the *specific key* I
> already know about" — a question a rogue CA, no matter how convincingly
> it forges the rest of the document, cannot answer correctly, because it
> doesn't hold the real key.

Hold that framing through everything below — the historical incidents,
the guided lab, and the capstone gauntlet are all this same idea, from
different angles.

---

## Theory: rogue CAs, downgrade attacks, and pinning

### The rogue-CA MITM, mechanically

A man-in-the-middle needs two things to intercept TLS traffic
undetected: a position on the network path (DNS poisoning, a rogue Wi-Fi
access point, a compromised router, an ARP-spoofed LAN segment — the
specific mechanism doesn't matter to what follows) and *something to
present as a certificate* that the victim's client will accept. Every
earlier day of this course has assumed the second half is hard — that's
the entire reason `--cacert` has been explicit on every command,
naming a CA the client has decided, out of band, to trust.

The rogue-CA attack removes that assumption in exactly one way: get the
attacker's own self-signed root installed into the victim's trust store.
Once that root is there, the attacker can self-sign a leaf for *any* name
at all — `example.local`, `yourbank.com`, anything — and every check
downstream of that installation passes honestly. This is not a
cryptographic weakness in TLS; TLS is doing exactly what it's designed to
do, correctly, against a trust store that itself has been compromised.
The entire attack surface is: **how does a root get into a trust store
that shouldn't have accepted it?** In the real world, this has happened
via a compromised CA's own signing infrastructure (today's guided lab
builds a rogue CA from scratch, but DigiNotar, below, shows the same
outcome reached by compromising a *real*, previously-trusted CA instead
of standing up a fake one), a coerced enterprise MDM policy pushing a
corporate inspection root onto managed devices, or a user tricked into
manually installing a "certificate" to access some service. However it
gets there, the mechanism downstream — checks 1 through 3 passing
perfectly against a root nobody should have trusted — is identical.

### Downgrade and stripping attacks, and what HSTS actually fixes

**SSL stripping** (the attack, and the tool that popularized it, are both
generally associated with the name "sslstrip," first demonstrated
publicly around 2009) exploits a completely different gap: it doesn't
attack the certificate at all. It attacks the moment *before* HTTPS ever
starts. Most users don't type `https://` — they type a bare hostname, or
follow a plain `http://` link, and expect either their browser or the
server to upgrade them to HTTPS. An on-path attacker sitting between the
victim and the real site intercepts that initial *plaintext* HTTP
request, proxies the rest of the session to the real site over genuine
HTTPS (so the attacker sees everything in the clear), and serves the
victim a plain-HTTP copy back — rewriting any `https://` links in the
response to `http://` so the victim's browser never even attempts a TLS
handshake for them. Because no TLS handshake happens on the victim's side
of this attack, **none of the four checks ever run** — there's no
certificate for the victim's browser to accept or reject, rogue or
otherwise. This is a fundamentally different failure surface than the
rogue-CA attack: that one defeats check 4 by feeding a bad trust anchor;
this one defeats the *entire verification model* by making sure it never
gets invoked at all.

**HSTS (HTTP Strict Transport Security)** is the specific defense: a
response header,
`Strict-Transport-Security: max-age=<seconds>; includeSubDomains`, that
tells the browser "for the next `max-age` seconds, never send a plain-HTTP
request to this host again — silently upgrade every request to HTTPS
*before it ever leaves the browser*." Because that upgrade decision is
made entirely client-side, from a rule the browser already has cached,
before any network request is sent, there is no plaintext bootstrap
request left for an attacker to intercept — sslstrip's whole mechanism
depends on that plaintext request existing, and HSTS removes it. This is
the same principle behind Day 1's four checks running *before* trusting
anything, just applied one layer up the stack: don't give an attacker a
step to exploit in the first place, rather than trying to detect the
exploit after the fact.

HSTS has one structural gap worth naming precisely: it only protects a
browser that has **already seen** the header at least once (or is
consulting a browser-shipped **HSTS preload list** — Chromium's and
Firefox's own hardcoded list of domains that get the upgrade rule applied
even on a genuinely first-ever visit, populated by site operators
submitting their domain in advance). A user's *very first* visit to a
domain that has never set HSTS before and isn't preloaded is still exposed
to stripping on that one visit, because the browser has no rule yet to
apply. This "trust on first use" gap — protecting every visit *after* the
first, but not the first one itself — is conceptually the same bootstrap
problem certificate pinning has, below.

### Certificate pinning

**Public-key pinning** adds a check that sits *alongside*, not instead
of, Day 1's four — but it answers a different question than any of
them: instead of "does this chain terminate at a root I trust," it asks
"does this leaf certificate's public key match one specific key I
already know about, regardless of who signed it or whether that signer
is otherwise trusted." A client hardcodes (pins) the expected key — or,
more precisely, a SHA-256 hash of the key's SubjectPublicKeyInfo — for a
given host, and refuses the connection outright if the presented key
doesn't match, even if every one of the four checks would otherwise pass
cleanly.

This is *exactly* why pinning defeats the rogue-CA attack even after a
rogue root has somehow been installed: check 4 asks "do I trust the
issuer," and a rogue CA can make that answer "yes" by getting its root
installed. Pinning never asks that question at all — it asks "is this the
exact key," and no amount of trust-store manipulation changes what key an
attacker actually holds. The attacker would need to have compromised the
*real* server's private key itself, a categorically different and much
harder attack than getting a rogue root trusted.

**Why mobile apps reach for pinning more than browsers do:** a mobile app
ships as a single binary, built and controlled entirely by one developer,
talking to a small, well-known, fixed set of the developer's own backend
hosts. Hardcoding a handful of pins for those specific hosts is
completely tractable. A general-purpose browser has none of those
properties — it has to work correctly against millions of unrelated
sites run by unrelated operators, none of which the browser vendor can
pre-coordinate pins with, which is exactly why a *browser-wide* pinning
mechanism (HPKP, HTTP Public Key Pinning, defined in RFC 7469) was
deprecated and removed from Chrome — the operational failure mode below
turned out to be too easy to trigger at web scale, for a benefit narrower
than it first appeared. Mobile apps pin via code or configuration baked
directly into the app binary instead, which sidesteps HPKP's specific
header-based mechanism, but not the underlying brittleness tradeoff.

**Brittleness and rotation risk** is that tradeoff, stated precisely:
because a pin is tied to one specific keypair, *any* legitimate key
rotation — a routine certificate renewal onto a fresh key, a CA or
hosting-provider migration, an infrastructure change — invalidates every
client that already has the old pin baked in, unless the *new* key was
pinned in advance. Get this wrong and you've bricked every already-deployed
copy of your own client against your own legitimate infrastructure — an
outage that, from the client's point of view, looks *identical* to a real
attack (that symmetry is the whole point of today's capstone-10). Real
deployments that pin manage this by pinning **multiple** keys at once
(the currently active key plus one or more "backup" pins for a planned
future rotation, shipped well ahead of actually rotating), and by pinning
at a level above the leaf where practical (an intermediate certificate
you control the lifecycle of, rather than a leaf that rotates on every
renewal) — treating a pin change as a slow, staged rollout, never a
same-day, all-at-once cutover.

### Three real failures, and the specific lesson each one teaches

**DigiNotar (2011).** DigiNotar was a Dutch commercial CA, trusted by
every major browser, that was breached in mid-2011. The attacker —
widely reported as linked to Iranian state interests, though full
attribution was never conclusively public — used DigiNotar's own
compromised issuance systems to mint fraudulent certificates for a large
number of high-value domains, including Google properties, reportedly
used afterward for real, live interception of Iranian users' Gmail
traffic. Part of how this was caught is directly relevant to today's
theory: Google's Chrome shipped an early, built-in pin for its own
domains at the time (a direct ancestor of the public-key pinning
mechanism this day's theory covers), and a fraudulent `*.google.com`
certificate tripped that pin, surfacing the compromise. Once confirmed,
every major browser vendor moved to fully distrust DigiNotar's root —
not just revoke the fraudulent certificates, but remove trust in
DigiNotar *entirely*, which also broke the Dutch government's own
`PKIoverheid` services (which depended on DigiNotar) and led to
DigiNotar's bankruptcy within weeks. **Lesson:** trusting a CA is
trusting its *operational security*, not just its cryptography — a CA's
root sitting in your trust store is a standing liability the moment that
CA's own signing infrastructure is compromised, and "distrust the CA
entirely" is the only response strong enough once that compromise is
confirmed, because there is no way to know how many fraudulent certs
exist that haven't surfaced yet. It's also a direct, real-world
demonstration of today's pinning theory: pinning is what actually caught
this, not the four checks, because the fraudulent certs passed all four
checks perfectly.

**Heartbleed (2014).** CVE-2014-0160 was a buffer over-read bug in
OpenSSL's implementation of the TLS heartbeat extension, publicly
disclosed in April 2014. It let a remote attacker repeatedly read up to
64KB of a server's process memory per request, with no unusual footprint
in ordinary logs — memory that could contain anything currently resident,
including a server's **private key**. The certificate angle, specific to
this course's material: Day 5's theory drew a hard line between the four
checks (does this cert's own document check out) and revocation (has
someone since decided to take back a validly-issued cert early) — and a
leaked private key is exactly the scenario revocation exists for. A
certificate whose private key may have been exposed is not "probably
still fine because `notAfter` is still months away" — every affected
service's *correct* response was to treat the key as compromised, revoke
the existing certificate, and reissue on a brand-new keypair, not merely
patch OpenSSL and move on. This triggered a mass revocation-and-reissuance
event across a huge fraction of the TLS-serving internet, and it exposed,
in practice, exactly how weak Day 5's revocation theory said revocation
already was: CRLs didn't scale to the volume, OCSP responders were hit
with load spikes, and plenty of affected services simply never rotated
their keys promptly at all. **Lesson:** a certificate that passes every
one of the four checks cleanly is worthless the instant its private key
is exposed, and the only lever that matters at that point — revocation —
is exactly the lever Day 5 already told you is the weakest part of the
whole trust model.

**Symantec distrust (2017–2018).** Unlike DigiNotar, nothing here was a
single breach — it was a sustained pattern of mis-issuance found through
ordinary monitoring. Google's investigation into Symantec's CA business
(covering both Symantec's own issuance and several partner/reseller
sub-CAs operating under Symantec's roots) turned up a long history of
improperly validated certificates, including test certificates issued for
domains like `google.com` without authorization years earlier. Much of
this was only discoverable at all because of Certificate Transparency —
Day 5's theory named CT logs as a *detection*, not prevention, mechanism,
and this is the real-world case that shows exactly why that distinction
matters: CT logs made a years-long pattern of mis-issuance provable and
public, in a way no individual revocation ever would have surfaced.
Chrome (and, following, Mozilla) announced a phased distrust plan for
Symantec-issued roots; Symantec's CA business was acquired by DigiCert in
2017, which took over issuance on entirely new, separately audited
infrastructure, and Chrome completed distrust of the legacy Symantec
roots through its 2018 release cycle. **Lesson:** losing trust as a CA
doesn't require an attacker or a breach at all — a long enough pattern of
process failures, made visible through CT, is treated by the browser
ecosystem as disqualifying on its own. Being a large, longstanding CA
that "everyone already trusts" grants no immunity once that trust is
shown to be unearned; the browser vendors acting on CT evidence here are,
functionally, the same governance mechanism as check 4 itself, just
exercised collectively instead of by one verifier at a time.

---

## Guided attack lab

All commands run through `toolbox`, from `labs/`, same as every prior
day. This lab makes **no changes to `docker-compose.yml`** — see
`labs/attack/README.md` for exactly why none are needed and how the
"attacker" is presented without one.

**Before you start:** this entire script must run as ONE container
invocation — `labs/attack/README.md` explains why (the rogue root
installation only survives for the lifetime of the container that
installed it). Do not try to copy-paste its steps into separate
`docker compose run --rm` calls.

```bash
docker compose run --rm toolbox bash /work/attack/rogue-mitm-demo.sh
```

Requires Day 2's CA and `example.local` certificate to already exist. In
order, the script:

1. **Builds a rogue root CA** — an entirely separate self-signed root,
   nothing to do with `ca/`.
2. **Issues a rogue leaf for `example.local`** from that rogue root —
   correct SAN, correct name. Checks 1 through 3 will pass perfectly
   against this rogue root's own signature.
3. **Presents it** via `openssl s_server`, standing in for an attacker's
   endpoint. `curl --connect-to example.local:8443:127.0.0.1:<port>`
   redirects the connection there while SNI and `Host` still say
   `example.local` — exactly what a real DNS-hijack MITM would look
   like from the client's side.
4. **Connects BEFORE trusting the rogue root** — expect failure, same as
   any unknown-CA rejection from every earlier day.
5. **Installs the rogue root** into this one container's trust store
   (`update-ca-certificates`), then reconnects with the *identical*
   command. **This is the aha:** curl now trusts the attacker's
   `example.local` certificate. Nothing about the certificate changed
   between steps 4 and 5 — only what the *trust store* was told to
   accept changed, and that alone was the entire difference.
6. **Defends with pinning** — extracts the REAL `example.local` leaf's
   public-key hash and retries the same connection with
   `--pinnedpubkey sha256//<hash>`. Expect **failure**, even though check
   4 still says this connection is "trusted" — pinning bypassed that
   question entirely and checked the actual key instead.

The pubkey-hash extraction pipeline, worth understanding line by line
rather than just running:

```bash
openssl x509 -in <cert> -pubkey -noout \
  | openssl pkey -pubin -outform der \
  | openssl dgst -sha256 -binary \
  | base64
```

- `openssl x509 -pubkey -noout` pulls just the certificate's embedded
  public key, in PEM form.
- `openssl pkey -pubin -outform der` re-encodes that key from PEM into
  raw DER bytes — the exact binary encoding curl's `--pinnedpubkey`
  hashes against, not the base64-wrapped PEM text.
- `openssl dgst -sha256 -binary` hashes those DER bytes with SHA-256,
  emitting raw binary digest bytes (not a hex string — `-binary` matters
  here).
- `base64` encodes that raw digest into the text form
  `curl --pinnedpubkey sha256//<this>` expects.

**On the specific hash value:** this course was authored without a live
Docker session to actually run this pipeline against a real cert (see the
task report). Nowhere in this material is any specific base64 string
presented as if it were a real, verified pin — every example above uses
`<hash>`/`REAL_PIN` as a computed-at-runtime placeholder, produced fresh
by the script from whatever `example.local` certificate is actually
sitting in your own `ca/intermediate/`. Run the extraction yourself and
read the real value it produces; don't take any digest string on faith
from a document, including this one — that's the entire point of
`-binary | base64` being something *you* run against a cert *you* hold,
not something handed to you.

---

## The capstone gauntlet

Ten setups are waiting for you in `labs/drills/capstone/capstone-01/`
through `capstone-10/`. Every failure class from Days 1 through 5 makes
at least one appearance, plus today's two additions:

| # | Failure class |
|---|---|
| capstone-01 | Missing intermediate — chain incomplete on both ends |
| capstone-02 | Wrong SAN — right cert, wrong name |
| capstone-03 | Expired leaf, reused instead of reissued |
| capstone-04 | Protocol-version mismatch — hardened floor above a legacy ceiling |
| capstone-05 | No shared cipher — suite family the certificate's key type can't satisfy |
| capstone-06 | mTLS — client cert from the wrong CA |
| capstone-07 | ACME challenge failure — DNS resolution, not the port |
| capstone-08 | Rogue CA / trust anchor — today's new failure class |
| capstone-09 | OCSP soft-fail blind spot — revocation that was never even asked about |
| capstone-10 | Pinning brittleness — a legitimate rotation breaks a stale pin |

Each `capstone-NN/SYMPTOM.md` gives you **only** the symptom: the setup,
the exact command, and the observed output — no diagnosis, no hint
ladder, nothing pointing you toward which of Day 1's four checks (or
today's pinning/OCSP additions) is actually responsible. That is
deliberate. **Do not open `labs/drills/solutions/capstone-NN.md` until
you have actually run the setup and formed your own diagnosis** — even a
wrong one. The value of this gauntlet is entirely in the struggle of
figuring out *which* of everything you now know actually applies to a
given symptom, with nothing narrowing the search for you; reading the
solution first skips the one exercise this whole course has been
building toward.

Work through all ten, in any order. For each one, before checking the
solution, write down: which of the four checks (or which non-four-check
mechanism — revocation, pinning) you believe is responsible, and what
single command you'd run next to confirm it. Then open the solution and
compare.

---

## Teach-back — the retention lock-in

This is the last exercise of the course, and it has no hint ladder and no
partial credit for "close enough." Close this document, open a blank
page, and write out, entirely from memory, in your own words:

1. **The definition.** What a certificate actually is, in one sentence.
2. **The four checks, in order**, and for each one, one sentence on what
   it actually tests (not just its name).
3. **Why the order matters** — specifically, why check 1 passing tells
   you nothing about check 4, and why that distinction is the entire
   reason a rogue-CA attack is possible at all.
4. **What each of the following breaks, specifically** — pick the *one*
   check (or the *one* non-four-check mechanism, if it's not one of the
   four) each of these actually violates, from memory, no looking back:
   a missing intermediate; an expired leaf; a name mismatch; an untrusted
   root; a rogue CA installed into a trust store; a revoked-but-not-yet-
   expired certificate with no OCSP stapling; a stale certificate pin
   after a legitimate rotation.
5. **What pinning changes about the trust model**, and why that makes it
   simultaneously stronger against a rogue CA and weaker against your own
   routine operations.

Do not consult `day01.md` through `day06.md` while writing this. Once
you're done, go back and check every claim against the actual course
material — the gaps between what you wrote and what's actually true are
exactly what to review before calling this course finished. If you can
produce all five points cleanly, unaided, you have retained the thing
this entire course was built to teach.

---

## Journal template

```
### Day 6 — Attack, defend & capstone
The four-check order, from memory, one more time: ...
Rogue-CA attack in my own words -- why checks 1-3 aren't enough: ...
What pinning actually checks instead of check 4: ...
Which capstone I misdiagnosed first, and what the real answer turned out to be: ...
One thing from Days 1-5 that only really clicked once I hit this capstone gauntlet: ...
```

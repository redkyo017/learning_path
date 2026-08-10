# Day 4 — Mutual TLS + Trust-Store Operations

Read this before starting the lab. Budget: ~3 hours (45–60 min
theory/reading, ~90 min guided lab, ~30–45 min exercises + drills).

---

## Learning objectives

By the end of today you should be able to:
- State precisely what mutual TLS (mTLS) adds to ordinary TLS: **both**
  peers run the full four-check verification — signature chain, validity
  dates, name match, trust anchor — each against its **own** trust anchor,
  not a shared one.
- Configure nginx to require and verify a client certificate
  (`ssl_verify_client on` + `ssl_client_certificate`) and explain what each
  directive actually checks.
- Name where a Linux system's trust store lives on disk, and explain why a
  private CA (like the one you built) is deliberately absent from it.
- Explain why a config *reload* avoids the downtime a *restart* causes, and
  apply that distinction to certificate rotation.
- Predict, without running anything, what happens when a client presents a
  certificate signed by the wrong CA, an expired certificate, or no private
  key at all — and say exactly which of the four checks each failure maps
  to.

---

## The mental model: both sides verify, each against its own anchor

Day 1 gave you the sentence you're not allowed to forget:

> **A certificate is a signed statement binding a name to a public key.**

And the four checks, always in this order: **signature chain → validity
dates → name match → trust anchor.**

Every day so far has applied that sentence and those four checks in exactly
one direction: a client (curl, a browser) verifies a *server's*
certificate. The server just... serves. It never checks who's asking.

Mutual TLS removes that asymmetry. In mTLS, the handshake runs the
verification **twice, in mirror image**:

1. The **client verifies the server's certificate** — exactly what you've
   done every day so far. Signature chain, dates, name match, trust anchor,
   checked by curl (or a browser) against whatever CA file it was told to
   trust (`--cacert ca-chain.cert.pem` in this lab).
2. The **server verifies the client's certificate** — the new half, as of
   today. Signature chain, dates, name match, trust anchor, checked by
   nginx against whatever CA file *it* was configured to trust
   (`ssl_client_certificate ca-chain.cert.pem`).

Hold the mirror-image framing precisely: these are **two separate
verifications**, run by **two separate parties**, each against its **own**
trust-anchor file. In today's lab both files happen to be the exact same
`ca-chain.cert.pem`, because you built one CA and used it to issue
everything — but that's a lab simplification, not a protocol requirement.
Nothing stops a real deployment from trusting a public CA (Let's Encrypt,
DigiCert) for the server's own identity while trusting a completely
separate, private CA — issued only to a known set of internal services —
for `ssl_client_certificate`. The two checks don't know or care about each
other's trust anchor. That independence is the single idea this whole day
is built around; everything below — the guided lab, the theory, every
exercise, every drill — is a variation on it.

One consequence worth internalizing now, before the lab: if check 4
(trust anchor) can fail independently on *either* side, then "the
connection failed" is no longer enough diagnostic information by itself —
you now have to ask "**which side's check failed, against which anchor**?"
before you can even start debugging. Today's drills are built to force
exactly that question.

---

## Theory: trust stores, and rotating certs without downtime

### Where trust stores actually live

A "trust store" is nothing magical — it's a set of certificates (usually
just self-signed roots) that some piece of software has been told, out of
band, to treat as check-4 anchors. Different layers of a system each keep
their **own**, and they don't automatically share:

- **The OS-level bundle.** On Debian/Ubuntu (what the `toolbox` image is
  built on), this is `/etc/ssl/certs/ca-certificates.crt` — a single file
  concatenating every root the `ca-certificates` package ships, plus
  individual `.pem`/`.crt` files symlinked into `/etc/ssl/certs/`. It's
  populated and refreshed by running `update-ca-certificates`, which reads
  source certs from `/usr/local/share/ca-certificates/` (for anything you
  add yourself) and `/usr/share/ca-certificates/` (the distro-shipped set),
  then rebuilds the bundle. RHEL/Fedora use a different path
  (`/etc/pki/tls/certs/ca-bundle.crt`) and a different tool
  (`update-ca-trust`), but the shape of the pattern — a rebuilt bundle file,
  fed by a directory of individual source certs — is the same idea.
- **Language runtimes often keep a separate copy.** Python's `requests`
  library ships and uses its own bundle via the `certifi` package by
  default — it does **not** read `/etc/ssl/certs` unless you explicitly
  point it there (`REQUESTS_CA_BUNDLE`, or Day 5's `certbot`/ACME client
  configuration will show you exactly this kind of override). Java keeps
  its own store entirely, a keystore file (traditionally `cacerts`,
  format `JKS` or, in modern JDKs, `PKCS12`) managed with `keytool` — a
  cert trusted by the OS is invisible to a JVM until it's imported into
  that keystore too. Node.js bundles a snapshot of Mozilla's root list
  compiled into the binary itself, overridable per-process with
  `NODE_EXTRA_CA_CERTS` pointing at an extra PEM file. The operational
  lesson underneath all of these: "the OS trusts it" and "this specific
  process trusts it" are two different facts, and debugging a
  trust-anchor failure means finding out **which** store the failing
  process is actually consulting.
- **Browsers mostly keep their own too.** Firefox has always shipped and
  maintained its own root store, entirely independent of the OS. Chrome's
  behavior has shifted over time and varies by platform (recent versions on
  several platforms use their own Chrome Root Store rather than deferring
  to the OS) — treat the exact current behavior on any given browser
  version as something to verify against that browser's own documentation
  rather than something to assume; the point that matters operationally is
  just that **"installed in the OS trust store" does not guarantee "trusted
  by this particular browser."**

None of these stores — OS, language runtime, or browser — contain your
lab's CA. You built it yourself, entirely offline, and never ran anything
resembling `update-ca-certificates` for it. That's *why* every single
command in this course has explicitly passed `--cacert ca-chain.cert.pem`
(or, for the server-verifying-client direction, `ssl_client_certificate`)
instead of relying on any default store — without that explicit flag, check
4 fails every time, for the entirely correct reason that nothing has ever
told any of these stores to trust `TLS Mastery Root CA`. You'll inspect the
`toolbox` container's own OS-level store directly in Part B of today's lab
to see this for yourself.

### Rotating certificates without downtime

A certificate's `notAfter` date is a deadline, and production systems renew
before hitting it — but renewing is only half the job; *deploying* the
renewed cert without dropping traffic is the other half, and it's where
most real incidents happen.

The mechanism that matters here is **reload vs. restart**:

- **`docker compose restart nginx`** stops the container's process
  entirely, then starts a fresh one. Every in-flight connection is dropped
  the instant the old process dies, and nothing serves traffic again until
  the new process finishes booting. This is a real, if brief, outage.
- **`nginx -s reload`** (run inside the running container, e.g.
  `docker compose exec nginx nginx -s reload`) tells the nginx **master**
  process to re-read its configuration and re-open its certificate/key
  files, then spawn **new worker processes** using that fresh config. The
  **old** worker processes are not killed — they're told to stop accepting
  *new* connections but finish serving every connection they already had
  in flight, then exit cleanly once those finish. New connections land on
  the new workers, immediately using the rotated certificate. No
  connection, old or new, is ever dropped mid-flight, and there is no
  window where nothing is listening.

The general pattern for zero-downtime certificate rotation, independent of
which web server you're using: **generate/receive the new cert+key,
place them on disk (or wherever the process reads certs from) without
touching the running process, then reload — never restart.** Renewing with
enough lead time before `notAfter` (a common convention, mirrored by tools
like `certbot`, is to renew once ~30 days remain) buys you slack to notice
and fix a reload that silently failed, before the old cert actually
expires.

Rotating the **CA itself** — the root or intermediate, not just a leaf —
is a much bigger operation, because every trust anchor referencing the old
CA has to start trusting the new one *before* you can safely issue new
leaves under it, or every client still pointed at the old trust anchor
breaks the moment you switch. Public CAs solve this with **cross-signing**:
for a real-world example, Let's Encrypt's own root (ISRG Root X1) was, for
years, cross-signed by an older, separately-trusted root (DST Root CA X3)
specifically so that older clients whose trust stores hadn't yet picked up
ISRG Root X1 directly could still validate the chain through the older,
already-trusted root, while newer clients validated it directly. In this
lab, you have no public trust-store distribution problem at all — there's
no browser or OS anywhere that trusts your CA to begin with — so a CA
rotation here would just mean: build a new intermediate, re-issue every
leaf under it, and update every `--cacert` / `ssl_client_certificate`
reference in every config in one coordinated cutover. The complexity public
CAs deal with is entirely about the *scale* of getting a new root
distributed everywhere it needs to be trusted before depending on it — a
problem Day 5's ACME lab and its "AWS bridge" subsection will return to.

---

## Guided lab

All commands run through `toolbox`, from `labs/`, exactly as every prior
day. Nothing here runs on the host.

### Part A — Issue a client certificate

```bash
docker compose run --rm toolbox bash ca/issue-server-cert.sh client01 client01
```

This reuses Day 2's `issue-server-cert.sh` — there's no separate
"client-cert" script, because nothing about the *shape* of a client
certificate differs from a server certificate at the X.509 level; the only
real difference is how it's *used*. One caveat worth knowing: the script
signs with the `server_cert` extension block in
`ca/openssl-intermediate.cnf`, which sets `extendedKeyUsage = serverAuth`
— it does **not** set `clientAuth`. Strictly, a maximally strict verifier
could reject a cert lacking `clientAuth` when used as a client identity.
nginx's `ssl_verify_client`, however, does **not** check `extendedKeyUsage`
on the client certificate it receives by default — it verifies the chain
(checks 1, 2, 4) and stops there, so `client01` works for today's lab
exactly as issued. Flag this as a known gap if you ever harden this setup
beyond lab purposes: a production mTLS deployment that wants to enforce
"this cert may only be used as a client identity" would need either a
dedicated client-cert extension block or explicit application-level
checking of the EKU field.

Confirm what you got:

```bash
docker compose run --rm toolbox openssl x509 -in ca/intermediate/certs/client01.cert.pem -noout -subject -issuer -dates
```

### Part B — Stage the certs for nginx and enable mTLS

nginx's container only mounts `./services/active.conf` and `./certs` (see
`docker-compose.yml`) — it never sees `./ca` directly. If you haven't
already staged Day 2's server certificate as a fullchain, do that now, and
copy the chain too (nginx's `ssl_client_certificate` needs its own copy,
same file):

```bash
docker compose run --rm toolbox bash -c "
  cat ca/intermediate/certs/example.local.cert.pem ca/intermediate/certs/ca-chain.cert.pem \
      > certs/example.local.fullchain.pem &&
  cp ca/intermediate/private/example.local.key.pem certs/example.local.key.pem &&
  cp ca/intermediate/certs/ca-chain.cert.pem certs/ca-chain.cert.pem
"
```

nginx only ever loads `services/active.conf` (see `docker-compose.yml`'s
bind mount), so activate today's config there, then have nginx pick it up:

```bash
cp services/nginx-mtls.conf services/active.conf
docker compose restart nginx      # pick up the new active.conf
```

### Part C — Watch the handshake fail, then succeed

Both commands below run **inside `toolbox`**, not on the host. `toolbox`
and `nginx` are separate containers on the shared `certlab` network — from
inside `toolbox`, `127.0.0.1` means the `toolbox` container itself, not the
host, and not `nginx`. The published `8443:443` port mapping on
`docker-compose.yml` only helps something reaching in *from the host*;
sibling containers reach `nginx` by its service name and its
container-internal port, `443`. `curl --connect-to` lets you keep
`example.local:8443` as the URL (so SNI and the `Host` header still say
`example.local`, matching the certificate's SAN — check 3 still applies
normally) while actually connecting to `nginx:443`:

```bash
# No client certificate presented — expect a rejection.
docker compose run --rm toolbox curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
    --connect-to example.local:8443:nginx:443 \
    https://example.local:8443/
```

Expected body (HTTP status `400`; curl's own exit code is `0` here — you
didn't pass `-f`, so curl prints the response body regardless of the HTTP
status code, and the *body itself* is the failure signal):

```
<html>
<head><title>400 No required SSL certificate was sent</title></head>
<body>
<center><h1>400 Bad Request</h1></center>
<center>No required SSL certificate was sent</center>
<hr><center>nginx</center>
</body>
</html>
```

This exact wording — an *HTTP*-level 400, not a TLS handshake failure — is
specific to TLS 1.3: under TLS 1.3, nginx's OpenSSL stack completes the
handshake even when the client sends no certificate, and only rejects the
request afterward, at the HTTP layer. (Under TLS 1.2, the missing-cert
case fails during the handshake itself, before any HTTP request is
possible — you'd see a curl-level connection error instead. You are not
expected to have memorized this distinction yet; it's flagged here so it
doesn't look like an inconsistency later, e.g. against drill-13, where the
client *does* send a certificate and the failure genuinely does happen at
the handshake layer.)

Now present the client certificate you issued in Part A:

```bash
docker compose run --rm toolbox curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
    --cert /work/ca/intermediate/certs/client01.cert.pem \
    --key  /work/ca/intermediate/private/client01.key.pem \
    --connect-to example.local:8443:nginx:443 \
    https://example.local:8443/
```

Expected output:

```
mTLS OK — client cert verified.
```

Walk back through what just happened using the mental-model framing: curl
verified nginx's server certificate against `ca-chain.cert.pem` (the same
check every prior day has done), **and, independently**, nginx verified
`client01.cert.pem` against its own `ca-chain.cert.pem` reference before it
would let the request through to the `location /` block at all. Two
separate four-check runs, two separate trust anchors (that happen, in this
lab, to be copies of the same file), one handshake.

### Part D — Inspect a trust store in the client container

```bash
# How many roots does the toolbox container trust by default, and where do they live?
docker compose run --rm toolbox bash -c "wc -l /etc/ssl/certs/ca-certificates.crt; ls /etc/ssl/certs | wc -l"
docker compose run --rm toolbox openssl version -d
```

`openssl version -d` reports the compiled-in `OPENSSLDIR` — the default
location OpenSSL falls back to for CA material if you don't pass `-CAfile`
explicitly. Confirm your lab's own CA is nowhere in that bundle:

```bash
docker compose run --rm toolbox bash -c "grep -c 'TLS Mastery' /etc/ssl/certs/ca-certificates.crt || true"
```

Expect `0` (or the command to simply find nothing) — confirming, directly,
the theory section's claim: your private CA was never installed into this
container's OS trust store, which is exactly why every command all
course-long has needed an explicit `--cacert`/`ssl_client_certificate`
pointing at it.

---

## Exercises

Answer these before moving to the drills. Each has a hint ladder — try
without looking, then peel back one hint at a time.

### Exercise 1

**You take `client01`'s certificate workflow from today and, instead of
using `client01.cert.pem`/`client01.key.pem` from your own CA, you build a
completely separate, second CA from scratch (self-signed root, its own
key) and issue a lookalike `client01` certificate from *that* CA instead —
same CN, same SAN, different issuer entirely. You present this second
cert/key pair to the mTLS nginx from today's lab. Predict what happens,
and say exactly which of the four checks is responsible.**

<details>
<summary>Hints</summary>

- Nudge: the CN and SAN are identical to the real `client01` cert. Does
  that help this cert pass?
- Tool to run: nothing to run — sketch nginx's decision on paper.
  `ssl_client_certificate` names one specific file. Is your second CA's
  root anywhere in it?
- Partial diagnosis: this is drill-13's exact scenario, just described in
  the abstract instead of with a shipped fixture.

</details>

<details>
<summary>Solution</summary>

The connection is rejected. **Check 4: trust anchor** fails, on the
*server's* side of the handshake, evaluating the *client's* certificate.

Nothing about checks 1–3 is necessarily wrong: the signature on this
second cert verifies perfectly against its own (different) CA's public
key — check 1 passes on its own terms. Its dates could be entirely valid —
check 2 passes. Its SAN says `client01`, matching whatever name you'd be
checking it against — check 3 passes (mTLS client-cert verification
doesn't typically hostname-match the way server certs do, but nothing here
would trip a name mismatch either way). The chain is internally perfectly
consistent, right up to a self-signed root that is simply **not** the CA
named in `ssl_client_certificate ca-chain.cert.pem`.

The CN and SAN being identical to the real `client01` cert changes
*nothing* — a name is not an identity, a **key** is, and a name-to-key
binding is only as good as whoever vouched for it. Anyone can self-sign a
root and issue a certificate claiming to be `CN=client01` today; that's
precisely the check-1-vs-check-4 distinction from Day 1's mental model,
now demonstrated on the client side of an mTLS handshake instead of the
server side. Over the wire this shows up as a TLS handshake failure (curl
error `35`, an "unknown ca"-class alert from nginx), because — unlike a
*missing* certificate under TLS 1.3, which today's Part C showed slips
past the handshake and fails at the HTTP layer instead — a client that
*does* present a certificate, just an untrusted one, is rejected during
the handshake itself.

</details>

### Exercise 2

**In today's lab, curl's `--cacert` and nginx's `ssl_client_certificate`
happen to point at the exact same file, `ca-chain.cert.pem`. Are these
logically the same trust decision, made once and shared? If your
organization wanted its public-facing services to present certificates
from a real public CA (Let's Encrypt, DigiCert) for ordinary browser
traffic, while *still* using a private, internal-only CA to authenticate
service-to-service mTLS calls between its own backends, would anything
about nginx's configuration model prevent that?**

<details>
<summary>Hints</summary>

- Nudge: re-read the mental-model section's "two separate verifications,
  two separate trust anchors" framing. This lab's file-sharing is a
  simplification, not a rule.
- Tool to run: nothing to run — compare directive names.
  `ssl_certificate`/`ssl_certificate_key` (the server's own identity) vs.
  `ssl_client_certificate` (the trust anchor for verifying *incoming*
  client certs) are two independent nginx directives with no required
  relationship to each other.
- Partial diagnosis: nothing forces these two directives to reference the
  same CA at all — that's purely a choice this lab made for simplicity.

</details>

<details>
<summary>Solution</summary>

No — they are two independent trust decisions that merely happen to
resolve to the same bytes on disk in this lab, because you built one CA
and used it for everything.

`ssl_certificate`/`ssl_certificate_key` control what nginx *presents* as
its own identity (verified by whoever connects, against whatever CA file
*they* trust — none of nginx's business). `ssl_client_certificate` controls
what nginx *itself* trusts when verifying an incoming client cert — a
completely separate directive, read at a completely separate point in the
handshake, serving a completely separate role. Nothing in nginx's
configuration model requires these to reference the same CA, and in the
scenario described — public certs for ordinary traffic, a private CA for
internal mTLS — a real deployment would set `ssl_certificate` to a
Let's-Encrypt-issued cert/key pair (publicly trusted, so ordinary browsers
verify it against their own OS/browser store, no `--cacert` override
needed) and `ssl_client_certificate` to a private CA's chain that only
internal services are ever issued certificates from. Both directives sit
in the same `server` block, unbothered by each other's choice of CA — the
architecture is built for exactly this split.

</details>

### Exercise 3

**You need to rotate the nginx server certificate before it expires.
Explain, step by step, why `docker compose exec nginx nginx -s reload`
avoids downtime while `docker compose restart nginx` does not — referring
specifically to what happens to (a) connections already in progress and
(b) new connections arriving, during each.**

<details>
<summary>Hints</summary>

- Nudge: "the process" and "the workers serving traffic right now" are not
  the same thing once you separate master from worker processes.
- Tool to run: nothing to run — this is about process lifecycle, not
  cryptography.
- Partial diagnosis: one command tells the existing process to load new
  files without dying; the other kills the process outright.

</details>

<details>
<summary>Solution</summary>

`nginx -s reload` sends a signal to the running **master** process telling
it to re-read its configuration (which includes re-opening whatever files
`ssl_certificate`/`ssl_certificate_key` currently point at) and spawn
**new worker processes** using that fresh configuration. The **existing**
worker processes are not killed — they're instructed to stop *accepting
new* connections but keep serving every connection they already have open
until each one finishes naturally, then exit. So: (a) already-in-progress
connections finish on the old workers, using the certificate that was
active when they started, completely undisturbed; (b) new connections are
routed to the new workers, which present the newly rotated certificate
immediately. At no point does anything stop listening.

`docker compose restart nginx` stops the container — which kills the
nginx master **and every worker** — then starts a brand-new container from
scratch. Every connection open at that instant, in-progress or not, is
severed immediately, and nothing is listening at all until the new
container finishes starting up. That gap, however brief, is a real outage,
and it happens on every restart regardless of whether a certificate
rotation was even the reason for restarting.

</details>

### Exercise 4

**A colleague runs `curl https://example.local:8443/` from a machine whose
OS trust store has hundreds of legitimate, well-known public root CAs
installed (DigiCert, Let's Encrypt, etc.) — and it still fails, the same
way it would without `--cacert` on any machine in this lab. Explain why,
in terms of the four checks, and explain specifically why "the OS store
has plenty of trusted CAs in it" doesn't help here.**

<details>
<summary>Hints</summary>

- Nudge: how many of those hundreds of public CAs did you personally
  bootstrap when you built `ca/root/` on Day 2?
- Tool to run: nothing to run — this is a direct application of the
  theory section's "your lab CA is nowhere in any OS bundle" point.
- Partial diagnosis: check 4 doesn't ask "is *some* CA in my store
  trustworthy?" — it asks "is *this specific chain's root* in my store?"

</details>

<details>
<summary>Solution</summary>

**Check 4: trust anchor** fails, exactly as it would on any machine
without `--cacert`. `example.local`'s certificate chains up to `TLS
Mastery Root CA` — a root you generated yourself, offline, on Day 2, that
has never been submitted to, audited by, or included in any public root
program. Having hundreds of *other* legitimate CAs installed is
irrelevant: check 4 verifies that the **specific root at the top of this
particular chain** is present in the verifier's trust store, not that the
store contains *some* trustworthy CA somewhere. `TLS Mastery Root CA`
isn't DigiCert, isn't Let's Encrypt, and isn't cross-signed by anything
that is — it's an entirely separate, private root, so no amount of public
CA material sitting in the same store makes it any more trusted. This is
also exactly why every command in this course has passed `--cacert`
explicitly: it's not working around a broken setup, it's supplying the one
piece of information — "trust *this* root, specifically" — that no public
trust store could ever have contained in the first place.

</details>

---

## Drills

Four drills are waiting for you in `labs/drills/drill-13/` through
`drill-16/`, each targeting a different way mTLS's *two-sided*
verification can fail:

- **drill-13** — a client certificate signed by the wrong CA entirely
- **drill-14** — an expired client certificate
- **drill-15** — a valid client certificate that looks expired because the
  *verifier's clock*, not the certificate, is wrong
- **drill-16** — a client certificate presented without its matching
  private key

Each drill directory has a `SYMPTOM.md` stating only the observed output
and the command that produced it — no diagnosis. Work the drill yourself
first. Full graduated-hint walkthroughs live in
`labs/drills/solutions/drill-NN.md` if you get stuck; resist opening them
until you've actually run something.

## Journal template

```
### Day 4 — Mutual TLS + trust-store operations
Key concept in my own words: ...
Which two trust anchors were involved in today's mTLS handshake, and were they the same file or different ones: ...
What confused me and how I resolved it: ...
Drill I found hardest and what finally gave it away: ...
```

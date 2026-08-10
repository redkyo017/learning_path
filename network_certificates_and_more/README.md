# TLS/Certificates Mastery — Offline Study Guide

Keep this file open as your daily navigator. Everything you need is in this
folder.

This course makes you able to: recite and apply the four-check verification
order (signature chain → validity dates → name match → trust anchor) to any
certificate you encounter; build your own root + intermediate CA and issue,
serve, and rotate real certificates with `openssl`; capture and read a live
TLS handshake on the wire with `tshark`, including the concrete differences
between TLS 1.2 and 1.3; configure and debug mutual TLS (both sides
verifying, each against its own trust anchor); run the real ACME/certbot
issuance workflow against a local Pebble server and map it onto AWS ACM +
ALB/NLB; and build, then defend against, a rogue-CA MITM attack — diagnosing
any of the ~30 deliberately broken TLS setups (20 drills + a 10-setup
capstone gauntlet) from the symptom alone, in minutes, with no hints.

---

## File Map

```
network_certificates_and_more/
├── README.md                          ← You are here (open every day)
├── journal.md                         ← Write one entry per day after you finish
├── content/
│   ├── day01.md … day06.md            ← Theory + guided lab + exercises — read FIRST each day
│   └── GLOSSARY.md                    ← Plain-English glossary of every term used in this course
├── labs/
│   ├── README.md                      ← Lab infrastructure reference (services, ports, why toolbox exists)
│   ├── docker-compose.yml             ← toolbox + nginx + pebble + challtestsrv, all on the certlab network
│   ├── toolbox/
│   │   └── Dockerfile                 ← Ubuntu 24.04 + real OpenSSL 3.x, curl, tshark, certbot
│   ├── ca/                            ← persistent root + intermediate CA (built Day 2, reused every day after)
│   │   ├── openssl-root.cnf, openssl-intermediate.cnf   ← extension policy (basicConstraints, keyUsage, SAN)
│   │   ├── make-root.sh, make-intermediate.sh, issue-server-cert.sh
│   │   ├── root/                      ← generated: root CA db (certs/private/newcerts/index.txt/serial)
│   │   └── intermediate/              ← generated: intermediate CA db + every issued leaf cert
│   ├── services/                      ← per-day nginx conf.d fragments + active.conf (the file nginx actually loads)
│   ├── acme/                          ← Day 5 — Pebble config + certbot/ACME wiring (see acme/README.md)
│   ├── attack/                        ← Day 6 — rogue-CA MITM demo script (see attack/README.md)
│   ├── samples/                       ← offline sample cert for Day 1, before you've built your own CA
│   ├── certs/                         ← generated certs/keys staged for nginx
│   └── drills/
│       ├── drill-01 … drill-20        ← one per Day 1–5 failure class, symptom-only, no diagnosis given
│       ├── capstone/capstone-01 … 10  ← Day 6 gauntlet: 7 revisit Days 1–5, 3 are new (rogue CA, OCSP, pinning)
│       └── solutions/                 ← graduated-hint walkthrough for every drill and capstone
└── docs/superpowers/                  ← specs, plans, reviews (design history / reference, not day-to-day reading)
```

---

## One-Time Setup (before Day 1)

**Requires Docker Desktop (or another Docker engine) running.** Every lab
command in this course runs *inside* the `toolbox` container, never on the
host — macOS ships LibreSSL behind its `openssl` command, not real OpenSSL,
and LibreSSL's CLI output and flag support diverge from OpenSSL 3.x in ways
that would silently misinform several later labs (certificate extensions,
some `-provider` options, TLS 1.3 details). All commands below run from
`network_certificates_and_more/labs/`.

### 1. Build the toolbox image

```bash
cd network_certificates_and_more/labs
docker compose build toolbox
```

(You can also skip this — the first `docker compose run --rm toolbox ...`
below builds it automatically.)

### 2. Verify setup

```bash
docker compose run --rm toolbox openssl version
# Expected: OpenSSL 3.x   (NOT LibreSSL — if you see LibreSSL, the command
# ran on the host instead of in the container)

docker compose run --rm toolbox tshark --version
# Expected: TShark (Wireshark) 4.x
```

### 3. Build the CA and issue the first server certificate

This runs the three scripts in `labs/ca/` in order — root, then
intermediate signed by the root, then a leaf for `example.local` signed by
the intermediate. Each script is idempotent: re-running `make-root.sh` or
`make-intermediate.sh` leaves an existing CA in place rather than
regenerating it (which would invalidate every cert already issued under
it); `issue-server-cert.sh <cn> [san...]` can be called repeatedly for
different names.

```bash
docker compose run --rm toolbox bash ca/make-root.sh
docker compose run --rm toolbox bash ca/make-intermediate.sh
docker compose run --rm toolbox bash ca/issue-server-cert.sh example.local example.local
```

### 4. Verify the CA

```bash
docker compose run --rm toolbox openssl verify -CAfile ca/intermediate/certs/ca-chain.cert.pem \
    ca/intermediate/certs/example.local.cert.pem
# Expected final line: example.local.cert.pem: OK
```

You can also confirm the issued cert's SAN landed correctly:

```bash
docker compose run --rm toolbox bash -c \
    "openssl x509 -in ca/intermediate/certs/example.local.cert.pem -noout -text | grep -A1 'Subject Alternative Name'"
# Expected: DNS:example.local
```

Full detail on the CA layout, the extension configs each script relies on,
and why `copy_extensions = none` matters lives in `labs/README.md` and is
walked hands-on in `content/day02.md`.

### Services at a glance

All four services sit on one bridge network, `certlab` (`10.77.30.0/24`),
so containers reach each other by service name (e.g. `toolbox` can `curl
https://nginx:443`). Only what's published to the host matters if you want
to reach something from outside Docker entirely:

| Service | Purpose | Host-published ports |
|---|---|---|
| `toolbox` | runs every `openssl`/`curl`/`tshark`/`certbot` command; static IP `10.77.30.10` | none (reached via `docker compose run`) |
| `nginx` | the TLS/mTLS server every day's lab curls against | `8443` → container's `443` |
| `pebble` (Day 5) | local ACME test CA; static IP `10.77.30.20` | `14000` ACME directory (HTTPS), `15000` management API (HTTPS) |
| `challtestsrv` (Day 5) | Pebble's DNS backend for challenge validation; static IP `10.77.30.30` | `8055` management API (HTTP) |

`nginx` only ever loads `services/active.conf` — each day's guided lab
copies that day's `services/nginx-dayNN.conf` (or `nginx-mtls.conf`) onto
`active.conf` before starting or reloading nginx, so `active.conf` is always
"whichever day's config is currently live." Full service detail: `labs/README.md`.

**Do not run Day 1's lab yet without this setup done** — Day 1's guided lab
uses an offline sample certificate precisely because the real CA doesn't
exist until Day 2, but the "Verify setup" step above (OpenSSL/tshark
versions) is a prerequisite for every day, including Day 1.

---

## Day-by-Day Navigator

Each day is ~3–4 hours: theory/reading, a guided lab (every command runs
through `docker compose run --rm toolbox <command>` from `labs/`), then
exercises and drills. Open `content/dayNN.md` first each day — it has the
full theory, every command, and the exercises with hint ladders. This
README only summarizes.

### Day 1 — How Trust Actually Works: The Verification Mental Model

**Theory:** `content/day01.md` — a certificate is a signed statement
binding a name to a public key; the four-check verification order
(signature chain → validity dates → name match → trust anchor); hashing,
keypairs, signing vs. verifying.

**What you build:** hand-sign a file with `openssl dgst -sign` and verify it
with `openssl dgst -verify`; dissect a real certificate
(`labs/samples/sample.local.cert.pem` — your own CA doesn't exist yet) and
map every field onto one of the four checks.

**Drills:** `labs/drills/drill-01` … `drill-04` — wrong public key, tampered
message, digest-algorithm mismatch, expired `notAfter`.

### Day 2 — Become a CA: Building the Chain of Trust

**Theory:** `content/day02.md` — why real PKI never lets the root sign
leaves directly (blast-radius containment), SAN vs. the deprecated CN,
basicConstraints, keyUsage/EKU.

**What you build:** a root CA, an intermediate CA signed by that root, and a
leaf cert for `example.local` signed by the intermediate — typed by hand
first, then checked against `labs/ca/`'s scripts (your answer key). Wire the
cert into nginx and watch `curl` fail against no CA, then succeed once
handed `ca-chain.cert.pem`.

**Drills:** `labs/drills/drill-05` … `drill-08` — leaf served with no
intermediate, wrong cert served for the name, chain fine but root never
trusted, expired-but-otherwise-valid chain.

### Day 3 — The Handshake on the Wire

**Theory:** `content/day03.md` — the TLS 1.3 handshake message by message,
what TLS 1.2 did differently (extra round trip, cleartext `Certificate`),
SNI (always cleartext) vs. ALPN (answer hidden only in 1.3), reading cipher
suite names.

**What you build:** a live `tshark` capture of a Day 2 handshake; extract
the SNI from the `ClientHello`; confirm the `Certificate` message is
readable on TLS 1.2 but opaque `application_data` on TLS 1.3.

**Drills:** `labs/drills/drill-09` … `drill-12` — protocol-version
mismatch, no shared cipher (auth-algorithm/cert-key-type mismatch), SNI
mismatch, ALPN mismatch.

### Day 4 — Mutual TLS + Trust-Store Operations

**Theory:** `content/day04.md` — mTLS runs the four checks twice, in
mirror image, each side against its own trust anchor; where OS/language/
browser trust stores actually live on disk; reload vs. restart for
zero-downtime cert rotation.

**What you build:** issue a client certificate, configure nginx's
`ssl_verify_client on` + `ssl_client_certificate`, watch the request fail
with no client cert presented, then succeed once one is; inspect the
`toolbox` container's own OS trust store and confirm your lab CA is nowhere
in it.

**Drills:** `labs/drills/drill-13` … `drill-16` — client cert from the
wrong CA, expired client cert, valid cert that looks expired because the
verifier's clock is wrong, client cert presented without its private key.

### Day 5 — Automation with ACME (Pebble)

**Theory:** `content/day05.md` — what ACME actually automates (domain
control validation, not issuance itself); the three challenge types
(HTTP-01, DNS-01, TLS-ALPN-01) and when to use each; why revocation is
effectively broken (CRLs don't scale, OCSP soft-fails) and what OCSP
stapling does about it; Certificate Transparency as detection, not
prevention; an AWS bridge mapping this local flow onto ACM + ALB/NLB
(read-only, no AWS account touched).

**What you build:** bring up `pebble` + `challtestsrv`, register
`test.local`, extract Pebble's own test root so certbot trusts its HTTPS
endpoint, then run the real certbot → ACME issuance workflow end to end and
serve the issued cert from nginx — watching your own private CA fail to
verify it, then the correct Pebble chain succeed.

**Drills:** `labs/drills/drill-17` … `drill-20` — HTTP-01 challenge port
unreachable, wrong challenge type for the plugin in use, a renewal that
doesn't actually renew, certbot not trusting Pebble's ACME endpoint.

### Day 6 — Attack, Defend & Capstone

**Theory:** `content/day06.md` — building and exploiting a rogue CA (checks
1–3 can pass perfectly; only check 4 stands in the way); SSL stripping and
what HSTS actually fixes; certificate pinning and its rotation-brittleness
tradeoff; three real incidents (DigiNotar, Heartbleed, the Symantec
distrust) each with its specific mechanism and lesson.

**What you build:** a rogue root CA and a fraudulent `example.local` leaf,
presented to a client that accepts it the instant the rogue root lands in
its trust store — then defended against with `curl --pinnedpubkey`, which
rejects the same "trusted" rogue cert outright. Then the capstone gauntlet.

**Drills:** `labs/drills/capstone/capstone-01` … `capstone-10` — the first
seven revisit failure classes from Days 1–5 (missing intermediate, wrong
SAN, expired leaf, protocol mismatch, no shared cipher, mTLS wrong CA, an
ACME DNS failure), and the last three are new: rogue CA / trust anchor,
OCSP soft-fail, and pinning brittleness. No hint ladder on the capstones —
diagnose from the symptom alone, then check the solution. The day closes
with an unaided teach-back writeup (no partial credit for "close enough").

---

## About the Drills

20 numbered drills (`drill-01` … `drill-20`, four per Day 1–5) plus a
10-setup Day 6 capstone gauntlet — ~30 pre-broken lab setups in total, each
presenting only a `SYMPTOM.md` (the command that was run and what came out,
no diagnosis) so you have to actually reason about which of the four checks
(or which non-four-check mechanism — revocation, pinning) is responsible.
Every one ships a full graduated-hint solution walkthrough in
`labs/drills/solutions/`. Work each drill yourself — reproduce the symptom,
form your own diagnosis, even a wrong one — before opening its solution;
that struggle is most of the point. On top of the drills, Days 1–5 each
carry 4 in-content exercises (20 total) that also ship with a hint ladder
and a full worked solution, inline in `content/dayNN.md`. Day 6 replaces
that exercise section with the capstone gauntlet itself plus an unaided
teach-back writeup — see below.

---

## Terminology

`content/GLOSSARY.md` has a plain-English definition for every term used
across this course (SAN, EKU, OCSP stapling, ALPN, pinning, etc.) — check
there first if a term in a day file or a drill's `SYMPTOM.md` is unfamiliar.

---

## Where This Goes Next

This course is **Phase 1** of a larger TLS/network-security track. Two
future phases are already scoped as separate specs, and both are designed
to be **additive** — they reuse this course's infrastructure rather than
rebuilding it:

- **Phase 2 — Applied crypto (same primitives, new surfaces).** SSH keys
  and host-key verification, JWT signing/verification, code signing, and
  encryption at rest. Each of these reuses Day 1's "a certificate/signature
  is a signed statement binding a name/claim to a key" model directly, and
  Phase 2's labs are expected to issue their certificates from this course's
  own `labs/ca/` root + intermediate rather than standing up a new CA.

- **Phase 3 — Network-security breadth.** VPN/IPsec, DNS security
  (DNSSEC, DNS-over-HTTPS), zero-trust and service-mesh mTLS at scale, TLS
  inspection/WAF, and Kubernetes `cert-manager`. Phase 3's zero-trust/
  service-mesh work is expected to extend Day 4's mutual-TLS lab (two-sided
  verification, each side against its own trust anchor) up to
  many-service scale, rather than reintroducing mTLS from scratch.

If you're picking this course back up to plan either phase: the CA under
`labs/ca/` and the mTLS pattern in `content/day04.md` /
`labs/services/nginx-mtls.conf` are the two concrete extension points to
build on.

---

## Journal

After each day, open `journal.md` and add an entry using the template at
the top. Writing it forces retrieval practice — the single most effective
way to lock in what you learned. Each day file also ends with its own
journal-template snippet tailored to that day's content; use whichever
prompts fit, or both.

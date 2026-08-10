# TLS / Certificate Mastery — Phase 1 Design

**Date:** 2026-08-10
**Status:** Design approved, pending spec review
**Path directory:** `network_certificates_and_more/`

## Goal

Take a learner from "I know certs make HTTPS work and I've seen browser cert
errors" to genuine operational and diagnostic mastery of TLS certificates, in
roughly 6 days at ~3 focused hours/day (~18 hours). The learner's specific
starting confusion is *how network components verify each other using
certificates* — the design is organized to dissolve that confusion by having the
learner personally build every party that does the verifying.

The learner selected all four end-goals: operate certs in production, debug any
TLS failure fast, understand the security/attack surface, and explain PKI/TLS
crisply. The path is built so all four fall out of one physically-constructed
mental model rather than four separate topic tracks.

## Strategy (the "unconventional" spine)

**Become the Certificate Authority.** Rather than studying certificates other
people issued, the learner builds the entire trust ecosystem locally: hand-craft
signatures with raw openssl, stand up a root + intermediate CA, issue certs,
configure servers and clients to verify them, watch the handshake on the wire,
automate issuance with a local ACME server, then attack the setup with a rogue
CA. Practitioners who are genuinely fast at TLS almost all built a CA at some
point; beginners waste most of their time memorizing openssl flags and error
strings without ever seeing the trust graph those errors belong to.

Two mechanisms carry the strategy:

- **One persistent CA workspace**, built on Day 2 and reused by every later day
  (mTLS, ACME comparison, rogue-CA attack) and by future phases. This is the
  extensibility anchor.
- **Breakage drills** every day: the learner is handed deliberately broken
  setups presenting only a symptom and must diagnose them. ~40 diagnostic reps
  across the path build the fast-debugging instinct. This is the core of the
  top-1% debugging skill and the antidote to the beginner error-string trap.

## Non-goals (YAGNI / scope boundaries)

- **No real domain or public issuance.** Local Pebble (Let's Encrypt test
  server) delivers the real ACME workflow fully offline.
- **No hands-on AWS or Kubernetes in Phase 1.** AWS (ACM + ALB termination) is a
  read-only conceptual bridge on Day 5, tying into the learner's existing AWS
  paths. Kubernetes/cert-manager is deferred to Phase 3.
- **No crypto-math derivations.** Depth target is *operational understanding*
  (read a cipher suite name and know what each part does), not "implement RSA."

## Architecture & lab infrastructure

Directory layout follows the repo's established learning-path pattern:

```
network_certificates_and_more/
├── README.md                    # path overview, how to use, phase roadmap
├── content/
│   ├── day01.md … day06.md      # theory + guided labs + exercises
│   └── GLOSSARY.md              # plain-English glossary (like LA/quantum paths)
├── labs/
│   ├── docker-compose.yml       # one command brings up the whole lab
│   ├── ca/                      # persistent root + intermediate CA workspace
│   ├── services/                # nginx + client containers for TLS/mTLS labs
│   ├── acme/                    # Pebble (Let's Encrypt test server) + certbot
│   └── drills/                  # pre-broken setups for breakage drills
│       ├── drill-01/ …          # each: broken config + symptom description
│       └── solutions/           # diagnosis walkthrough per drill
└── docs/superpowers/            # specs, plans (this design lives here)
```

Infrastructure principles:

- **Single `docker-compose.yml`, everything local.** No domain, no cloud
  account, works offline. Services: an `openssl` toolbox container (avoids the
  Mac's LibreSSL quirks), `nginx` as TLS server, a `curl`-based client, Pebble
  for ACME, and `tshark` for packet capture (Wireshark GUI on the Mac optionally
  reads the capture files).
- **One persistent CA workspace.** The Day 2 root + intermediate CA is reused by
  every later day and is documented as the shared foundation for future phases.
- **Breakage drills are pre-built, not improvised.** Each drill is a directory
  the learner brings up with docker compose that presents only a symptom; the
  learner diagnoses with that day's tools, and a solution file shows the full
  diagnostic path.

## Day-by-day content design

Each day ≈ 3h: ~60–75 min theory/reading, ~90 min guided lab, ~30 min breakage
drills + exercises. Every exercise ships with hints + solution sketches.

### Day 1 — How trust actually works (the verification mental model)
Directly answers the learner's stated confusion. Theory: hashing → keypairs →
digital signatures → "a certificate is just a signed statement binding a name to
a public key." Lab: sign a file with a private key and verify with the public key
using raw `openssl dgst`; then dissect a real certificate (`openssl x509 -text`
against a live site) identifying each field's role in verification. End-state:
the learner can narrate unaided what a verifier checks and in what order
(signature chain → validity dates → name match → trust anchor).

### Day 2 — Become a CA
Theory: chains of trust, root vs intermediate and why intermediates exist, the
fields that actually matter (SAN, basicConstraints, keyUsage/EKU) vs. ones that
don't (CN, deprecated for hostname matching). Lab: build root CA → intermediate
CA → issue a server cert; serve from nginx; watch `curl` fail, then succeed once
handed the root. First drills: missing-intermediate, wrong-SAN.

### Day 3 — The handshake on the wire
Theory: TLS 1.3 handshake step by step (and what 1.2 did differently), where
certificate verification sits inside it, SNI, ALPN, session resumption, cipher
suites at "read a suite name and know what each part means" depth. Lab: `tshark`
capture of the Day 2 setup, walk each packet; compare 1.2 vs 1.3; observe SNI in
the clear. Drill gauntlet #1 (3–4 handshake failures).

### Day 4 — Mutual TLS + trust-store operations
Theory: how *both* sides verify (extends the core confusion to the two-way case),
where OS/browser/language trust stores live, cert rotation without downtime. Lab:
two Docker services that mutually authenticate with client certs from the
learner's CA; present a cert from a different CA and watch rejection; inspect
trust stores across client containers. Drills: expired cert, clock-skew,
untrusted-client-CA.

### Day 5 — Automation with ACME (real Let's Encrypt workflow, no domain)
Theory: why manual issuance doesn't scale, the ACME protocol (HTTP-01, DNS-01,
TLS-ALPN-01 challenges), revocation and why it is effectively broken (CRL/OCSP →
OCSP stapling), Certificate Transparency logs. Lab: `certbot` against local
Pebble issuing real ACME certs to nginx — the exact production workflow, offline.
AWS bridge: read-only walkthrough of how ACM + ALB termination map onto what was
just built (no account needed). Drills: renewal failure, wrong challenge type.

### Day 6 — Attack, defend & capstone
Theory: rogue-CA MITM, downgrade/stripping attacks, certificate pinning (and why
mobile uses it), famous real-world failures (DigiNotar, Heartbleed's cert angle,
Symantec distrust) and each one's lesson. Lab: install a rogue CA into the
client's trust store and MITM the learner's own HTTPS traffic — the visceral
"aha" for what a trust store is — then defend with pinning. Capstone: a gauntlet
of 8–10 broken setups diagnosed against the clock, plus a short teach-back
writeup explaining the trust model in the learner's own words.

## Exercises & drills

Two tiers per day, following the hints + solutions convention:

- **Breakage drills** — a running container presents only a symptom; the learner
  diagnoses with that day's tools. Each ships a graduated hint ladder (nudge →
  tool to run → partial diagnosis) and a full solution walkthrough in
  `drills/solutions/`.
- **Concept exercises** — short written/practical questions (e.g., "given this
  `openssl verify` output, which of the four checks failed and why?") with answer
  sketches.

Target ~4 drills + ~4 exercises per day, ~40 diagnostic reps total. The Day 6
capstone gauntlet reuses drill infrastructure but withholds hints until the
learner has attempted each one.

## Extensibility — phase roadmap

This path is **Phase 1**. The README carries a "Where this goes next" section,
and `labs/ca/` is documented as the shared foundation. Two future phases are
named as separate specs that reuse this CA lab and trust-store infrastructure so
they are additive, not rewrites:

- **Phase 2 — Applied crypto (same primitives, new surfaces):** SSH keys & host
  verification, JWT signing/verification, code signing, encryption at rest. Each
  reuses the CA and the Day 1 "signed statement" model.
- **Phase 3 — Network-security breadth:** VPN/IPsec, DNS security (DNSSEC/DoH),
  zero-trust & service-mesh mTLS at scale, TLS inspection/WAF. Reuses the Day 4
  mTLS lab. Kubernetes/cert-manager lives here.

## Success criteria

By end of Day 6 the learner can:

1. Explain the full verification sequence unaided.
2. Build a working CA and issue/deploy a valid cert from scratch.
3. Diagnose any of the ~40 drill failure classes in minutes.
4. Run the real ACME issuance/renewal workflow.
5. Execute and then defend against a rogue-CA MITM.

Each criterion maps back to one of the four selected end-goals (operate, debug,
security-depth, explain).

## Deliverables

- `README.md` — overview, how to run the lab, phase roadmap.
- `content/day01.md … day06.md` — theory + guided labs + exercises with hints
  and solutions.
- `content/GLOSSARY.md` — plain-English glossary.
- `labs/` — docker-compose, CA workspace, services, ACME (Pebble), drills +
  solutions.

## Notes for implementation

- Day-content and lab files are written on a cheaper model; the spec and the
  implementation plan are written on the current model. Prompt the user to switch
  models before writing any day-content or lab files.
- Do not run git commits in this repo; the user handles version control.

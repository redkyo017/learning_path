# TLS / Certificate Mastery — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 6-day, offline, Docker-based learning path that takes a learner from "I've seen browser cert errors" to operational and diagnostic TLS/certificate mastery, organized around personally building a Certificate Authority.

**Architecture:** A single local `docker-compose.yml` brings up an openssl toolbox, nginx TLS server, curl client, Pebble ACME server, and tshark capture. A persistent CA workspace (built Day 2) is reused by every later day. Each day pairs a theory/lab content file with runnable lab assets and pre-built "breakage drills" — deliberately broken setups the learner diagnoses, each shipping graduated hints and a full solution walkthrough.

**Tech Stack:** Docker + docker-compose, OpenSSL (via an Alpine/Ubuntu toolbox image to avoid macOS LibreSSL quirks), nginx, curl, Pebble (Let's Encrypt test ACME server), certbot, tshark/Wireshark. Content is Markdown following the repo's existing learning-path conventions.

## Global Constraints

- **Fully offline / no real domain.** No public CA, no real DNS, no cloud account. Pebble provides the ACME workflow locally.
- **One persistent CA workspace** at `labs/ca/`, built in Task 4 (Day 2) and reused by all later tasks. Never regenerate it per-day.
- **Every exercise and drill ships hints + a full solution.** Graduated hint ladder (nudge → tool to run → partial diagnosis) then complete walkthrough. No exercise without a solution.
- **openssl runs inside the toolbox container**, never against the host's LibreSSL. All lab commands are container commands.
- **Do NOT run git commits.** The user handles version control. Where this plan says "Checkpoint," stop for review — do not commit.
- **Model switch before content:** Tasks 1–2 (scaffold + infra) may proceed on the current model. Before Task 3 and every content/lab task after it, prompt the user to switch to the cheaper content-writing model.
- **Content conventions** (match existing paths like `aws_network_components/`): each `dayNN.md` opens with a time budget and "Learning objectives" list, teaches one mental model early, then guided lab, then exercises + drills with hints and solutions.
- **Depth target:** operational understanding, not crypto-math. Read a cipher suite name and explain each part; do not derive RSA.

---

## File Structure

```
network_certificates_and_more/
├── README.md                      # daily navigator + phase roadmap (Task 12)
├── journal.md                     # one entry per day (Task 12)
├── content/
│   ├── day01.md … day06.md        # Tasks 3,4,5,6,7,8
│   └── GLOSSARY.md                # Task 11
├── labs/
│   ├── docker-compose.yml         # Task 1
│   ├── README.md                  # lab quickstart (Task 1)
│   ├── toolbox/Dockerfile         # openssl+curl+tshark image (Task 1)
│   ├── ca/                        # persistent CA workspace + scripts (Task 2)
│   │   ├── openssl-root.cnf
│   │   ├── openssl-intermediate.cnf
│   │   ├── make-root.sh
│   │   ├── make-intermediate.sh
│   │   └── issue-server-cert.sh
│   ├── services/                  # nginx + client configs (Task 4+)
│   ├── acme/                      # Pebble + certbot (Task 7)
│   └── drills/
│       ├── drill-NN/              # each: broken setup + SYMPTOM.md
│       └── solutions/             # drill-NN.md walkthroughs
└── docs/superpowers/
    ├── specs/2026-08-10-tls-certificates-mastery-design.md
    └── plans/2026-08-10-tls-certificates-mastery-plan.md   (this file)
```

Each day task is self-contained: content file + that day's lab assets + that day's drills with solutions. A reviewer can accept or reject one day without touching another. Tasks 1–2 are shared infrastructure every later task consumes.

---

### Task 1: Lab infrastructure scaffold (compose + toolbox image)

**Files:**
- Create: `labs/docker-compose.yml`
- Create: `labs/toolbox/Dockerfile`
- Create: `labs/README.md`

**Interfaces:**
- Produces: a `toolbox` service/image with `openssl`, `curl`, `tshark`, `bash` on PATH; an `nginx` service; a shared bind-mount so containers see `labs/` at `/work`. Later tasks run commands via `docker compose run --rm toolbox <cmd>`.

- [ ] **Step 1: Write the verification check (the "failing test")**

Define the acceptance command that must eventually succeed. Create `labs/README.md` with a "Verify setup" section stating:

```
docker compose -f labs/docker-compose.yml run --rm toolbox openssl version
# Expected: OpenSSL 3.x  (NOT LibreSSL)
docker compose -f labs/docker-compose.yml run --rm toolbox tshark --version
# Expected: TShark (Wireshark) 4.x
```

- [ ] **Step 2: Run it to confirm it fails**

Run the first command above. Expected: FAIL (`no configuration file provided` / service not found) because compose does not exist yet.

- [ ] **Step 3: Write the toolbox Dockerfile**

```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl curl tshark ca-certificates bash coreutils \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /work
```

- [ ] **Step 4: Write docker-compose.yml**

Define services: `toolbox` (builds `./toolbox`, mounts `.:/work`, `working_dir: /work`, `entrypoint: []`), `nginx` (image `nginx:stable`, mounts `./services:/etc/nginx/conf.d` and cert dirs, ports `8443:443`), on a shared user-defined bridge network `certlab`. Keep `pebble` commented with a `# added in Day 5 (Task 7)` marker.

- [ ] **Step 5: Run the verification check to confirm it passes**

Run both commands from Step 1. Expected: OpenSSL 3.x and TShark 4.x print. If macOS LibreSSL appears, the command ran on the host — fix the invocation.

- [ ] **Step 6: Checkpoint** (do not commit; stop for review)

---

### Task 2: Persistent CA workspace scripts

**Files:**
- Create: `labs/ca/openssl-root.cnf`
- Create: `labs/ca/openssl-intermediate.cnf`
- Create: `labs/ca/make-root.sh`
- Create: `labs/ca/make-intermediate.sh`
- Create: `labs/ca/issue-server-cert.sh`

**Interfaces:**
- Produces: `make-root.sh` → `ca/root/certs/ca.cert.pem` (self-signed root). `make-intermediate.sh` → `ca/intermediate/certs/intermediate.cert.pem` signed by root, plus `ca/intermediate/certs/ca-chain.cert.pem`. `issue-server-cert.sh <cn> <san...>` → `ca/intermediate/certs/<cn>.cert.pem` + key, with SANs set. These artifacts are consumed by Tasks 4–10.
- Note: scripts are runnable now, but they are the *answer key*. The learner types the equivalent commands themselves in Day 2 (Task 4).

- [ ] **Step 1: Write the verification check**

Add to `labs/README.md` a "Verify CA" section:

```
docker compose run --rm toolbox bash ca/make-root.sh
docker compose run --rm toolbox bash ca/make-intermediate.sh
docker compose run --rm toolbox bash ca/issue-server-cert.sh example.local example.local
docker compose run --rm toolbox openssl verify -CAfile ca/intermediate/certs/ca-chain.cert.pem \
    ca/intermediate/certs/example.local.cert.pem
# Expected final line: example.local.cert.pem: OK
```

- [ ] **Step 2: Run it to confirm it fails**

Run the `verify` command. Expected: FAIL (files do not exist).

- [ ] **Step 3: Write the two openssl config files**

`openssl-root.cnf` and `openssl-intermediate.cnf` with `[ v3_ca ]` (basicConstraints CA:TRUE, keyUsage keyCertSign,cRLSign), a `[ server_cert ]` extension block (basicConstraints CA:FALSE, keyUsage digitalSignature,keyEncipherment, extendedKeyUsage serverAuth, `subjectAltName = @alt_names`), and a `[ alt_names ]` placeholder the issue script rewrites. Include directory layout dirs (`certs`, `private`, `newcerts`, `index.txt`, `serial`).

- [ ] **Step 4: Write make-root.sh**

Bash script: create dirs, `openssl genrsa` (or `ecparam`) for the root key, `openssl req -x509 -new -config openssl-root.cnf -extensions v3_ca` to self-sign the root cert. Set `set -euo pipefail`.

- [ ] **Step 5: Write make-intermediate.sh**

Generate intermediate key + CSR, sign with the root via `openssl ca -config openssl-root.cnf -extensions v3_intermediate_ca`, then `cat` intermediate + root into `ca-chain.cert.pem`.

- [ ] **Step 6: Write issue-server-cert.sh**

Args `<cn> [san...]`; write SANs into `[ alt_names ]`, generate key + CSR, sign with intermediate via `openssl ca -extensions server_cert`. Output cert + key paths.

- [ ] **Step 7: Run the full verification chain from Step 1**

Expected: `example.local.cert.pem: OK`. Also run `openssl x509 -in example.local.cert.pem -noout -text | grep -A1 "Subject Alternative Name"` and confirm `DNS:example.local` appears.

- [ ] **Step 8: Checkpoint** (do not commit; stop for review)

---

> **MODEL SWITCH GATE:** Everything below writes learner-facing content and lab
> exercises. Prompt the user to switch to the content-writing model before
> starting Task 3. Do not begin Task 3 until confirmed.

---

### Task 3: Day 1 content — the verification mental model

**Files:**
- Create: `content/day01.md`
- Create: `labs/drills/drill-01/` … `drill-04/` (with `SYMPTOM.md` each)
- Create: `labs/drills/solutions/drill-01.md` … `drill-04.md`

**Interfaces:**
- Consumes: toolbox from Task 1.
- Produces: the "four-check verification order" framing (signature chain → validity dates → name match → trust anchor) reused verbatim by every later day.

- [ ] **Step 1: Write day01.md content**

Sections in order: (1) time budget + Learning objectives list; (2) mental model — "a certificate is a signed statement binding a name to a public key," and the four-check verification order; (3) theory — hashing, keypairs, digital signatures, what "signing" means; (4) guided lab; (5) exercises; (6) drills. Lab commands, all via `docker compose run --rm toolbox`:

```
# Sign and verify a file by hand
openssl genrsa -out /work/tmp/priv.pem 2048
openssl rsa -in /work/tmp/priv.pem -pubout -out /work/tmp/pub.pem
echo "hello trust" > /work/tmp/msg.txt
openssl dgst -sha256 -sign /work/tmp/priv.pem -out /work/tmp/msg.sig /work/tmp/msg.txt
openssl dgst -sha256 -verify /work/tmp/pub.pem -signature /work/tmp/msg.sig /work/tmp/msg.txt
# Expected: Verified OK
# Dissect a real cert (offline copy shipped in labs/samples/, or a cert from Task 2)
openssl x509 -in /work/ca/intermediate/certs/example.local.cert.pem -noout -text
```

- [ ] **Step 2: Write 4 concept exercises with hints + solution sketches**

Example exercise: "You changed one byte of `msg.txt` after signing. Predict the `-verify` output and explain which of the four checks this maps to." Ship a hint ladder and a full answer.

- [ ] **Step 3: Build the 4 drills (each a broken setup + SYMPTOM.md)**

Day 1 drills target the signing model: (a) verifying with the wrong public key; (b) verifying a tampered message; (c) wrong digest algorithm mismatch; (d) reading a cert and identifying an expired `notAfter`. Each `drill-NN/SYMPTOM.md` states only the symptom + the command the learner ran.

- [ ] **Step 4: Write the 4 drill solution walkthroughs**

Each `solutions/drill-NN.md`: graduated hints, then the exact diagnostic commands and the fix, then the one-line lesson.

- [ ] **Step 5: Verify each drill reproduces its symptom**

For each drill, run its setup and confirm the stated symptom actually appears (e.g., `Verification Failure`). Expected: symptom matches SYMPTOM.md exactly.

- [ ] **Step 6: Checkpoint** (do not commit; stop for review)

---

### Task 4: Day 2 content — become a CA

**Files:**
- Create: `content/day02.md`
- Create: `labs/services/nginx-day02.conf`
- Create: `labs/drills/drill-05/` … `drill-08/` + matching `solutions/`

**Interfaces:**
- Consumes: CA scripts (Task 2) as the answer key; toolbox + nginx (Task 1).
- Produces: a running nginx serving `example.local` on `:8443` with a CA-issued cert; consumed by Tasks 5–10.

- [ ] **Step 1: Write day02.md content**

Sections: objectives; mental model — chain of trust (root → intermediate → leaf) and why intermediates exist (keep root offline); theory — SAN/basicConstraints/keyUsage/EKU matter, CN deprecated for hostname matching; guided lab where the learner *types* the CA-build commands (Task 2 scripts are the answer key they check against). Lab climax:

```
# Serve the cert
docker compose up -d nginx
curl --resolve example.local:8443:127.0.0.1 https://example.local:8443/
# Expected: FAIL — self-signed/unknown issuer
curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
     --resolve example.local:8443:127.0.0.1 https://example.local:8443/
# Expected: SUCCESS
```

- [ ] **Step 2: Write nginx-day02.conf** referencing the leaf cert + chain from Task 2 artifacts.

- [ ] **Step 3: Write 4 concept exercises** (e.g., "why does the first curl fail but a browser might show a different error?") with hints + solutions.

- [ ] **Step 4: Build drills 05–08:** missing-intermediate (server sends leaf only), wrong-SAN (cert for `other.local`), root-not-trusted, expired-leaf. Each with SYMPTOM.md.

- [ ] **Step 5: Write drill solutions 05–08** with hint ladders + fixes.

- [ ] **Step 6: Verify** the success/fail curl commands behave as documented, and each drill reproduces its symptom.

- [ ] **Step 7: Checkpoint** (do not commit; stop for review)

---

### Task 5: Day 3 content — the handshake on the wire

**Files:**
- Create: `content/day03.md`
- Create: `labs/drills/drill-09/` … `drill-12/` + matching `solutions/`

**Interfaces:**
- Consumes: running nginx from Task 4; toolbox tshark from Task 1.
- Produces: capture-reading skill; no new persistent artifacts.

- [ ] **Step 1: Write day03.md content**

Sections: objectives; mental model — the handshake as "prove identity, then agree on keys," and where the four-check verification sits inside it; theory — TLS 1.3 handshake steps, 1.2 differences, SNI, ALPN, session resumption, reading a cipher-suite name. Guided lab:

```
# Capture a handshake
docker compose run --rm toolbox bash -c \
  "tshark -i any -w /work/tmp/hs.pcap -a duration:5 & sleep 1; \
   curl --cacert /work/ca/intermediate/certs/ca-chain.cert.pem \
        --resolve example.local:8443:127.0.0.1 https://example.local:8443/ ; wait"
# Inspect ClientHello SNI in the clear
tshark -r /work/tmp/hs.pcap -Y 'tls.handshake.type==1' -V | grep -i server_name
```
Note: Wireshark GUI on the host may open `hs.pcap` for a visual walk.

- [ ] **Step 2: Write 4 concept exercises** (e.g., "identify each field in `TLS_AES_128_GCM_SHA256`") with hints + solutions.

- [ ] **Step 3: Build drills 09–12** (gauntlet #1): protocol-version mismatch (client max TLS1.1 vs server min TLS1.2), cipher/no-shared-cipher, SNI mismatch causing wrong cert, ALPN mismatch. Each with SYMPTOM.md.

- [ ] **Step 4: Write drill solutions 09–12.**

- [ ] **Step 5: Verify** capture commands produce a pcap with a visible SNI, and each drill reproduces its symptom.

- [ ] **Step 6: Checkpoint** (do not commit; stop for review)

---

### Task 6: Day 4 content — mutual TLS + trust stores

**Files:**
- Create: `content/day04.md`
- Create: `labs/services/nginx-mtls.conf`
- Create: `labs/drills/drill-13/` … `drill-16/` + matching `solutions/`

**Interfaces:**
- Consumes: CA (Task 2) to issue a client cert; nginx (Task 1).
- Produces: an mTLS-configured nginx + client-cert workflow reused by Phase 3 later.

- [ ] **Step 1: Write day04.md content**

Sections: objectives; mental model — *both* sides run the four-check verification, each against its own trust anchor; theory — trust store locations (OS bundle, `/etc/ssl/certs`, language runtimes), rotation without downtime. Guided lab:

```
# Issue a client cert from the same CA
docker compose run --rm toolbox bash ca/issue-server-cert.sh client01 client01
# Enable mTLS (ssl_verify_client on; ssl_client_certificate ca-chain)
docker compose up -d nginx   # using nginx-mtls.conf
curl --cacert .../ca-chain.cert.pem --resolve example.local:8443:127.0.0.1 \
     https://example.local:8443/
# Expected: FAIL — 400 No required SSL certificate was sent
curl --cacert .../ca-chain.cert.pem \
     --cert .../client01.cert.pem --key .../client01.key.pem \
     --resolve example.local:8443:127.0.0.1 https://example.local:8443/
# Expected: SUCCESS
```

- [ ] **Step 2: Write nginx-mtls.conf** with `ssl_verify_client on`.

- [ ] **Step 3: Write 4 concept exercises** (e.g., "present a client cert from a different CA — predict and explain the rejection").

- [ ] **Step 4: Build drills 13–16:** client cert from wrong CA, expired client cert, clock-skew (container date ahead of validity), missing client key. Each with SYMPTOM.md.

- [ ] **Step 5: Write drill solutions 13–16.**

- [ ] **Step 6: Verify** both mTLS curls behave as documented and drills reproduce symptoms.

- [ ] **Step 7: Checkpoint** (do not commit; stop for review)

---

### Task 7: Day 5 content — automation with ACME (Pebble)

**Files:**
- Create: `content/day05.md`
- Modify: `labs/docker-compose.yml` (uncomment/add `pebble` service)
- Create: `labs/acme/` (pebble config, certbot invocation notes)
- Create: `labs/drills/drill-17/` … `drill-20/` + matching `solutions/`

**Interfaces:**
- Consumes: toolbox, nginx, compose network from Task 1.
- Produces: a working local ACME issuance flow.

- [ ] **Step 1: Add the pebble service to docker-compose.yml**

Add `pebble` (image `letsencrypt/pebble`), on the `certlab` network, with its config in `labs/acme/pebble-config.json`. Document that certbot must trust Pebble's test root via `REQUESTS_CA_BUNDLE`/`--server https://pebble:14000/dir`.

- [ ] **Step 2: Write the ACME verification check**

```
docker compose up -d pebble
docker compose run --rm --entrypoint certbot toolbox \
  certonly --standalone --server https://pebble:14000/dir \
  -d test.local --agree-tos -m a@b.c --no-eff-email
# Expected: "Successfully received certificate" issued by Pebble intermediate
```
(If the toolbox image lacks certbot, add `certbot` to its apt install list in Task 1's Dockerfile and note the dependency here.)

- [ ] **Step 3: Run it to confirm it fails** before pebble/config exist. Expected: connection refused / unknown server.

- [ ] **Step 4: Write day05.md content**

Sections: objectives; mental model — ACME automates the "prove you control the name" step; theory — HTTP-01 vs DNS-01 vs TLS-ALPN-01 challenges, revocation (CRL/OCSP) and why it's effectively broken → OCSP stapling, Certificate Transparency logs. Guided lab = the certbot-against-Pebble flow. **AWS bridge subsection** (read-only, no account): how ACM issues/renews and how ALB/NLB terminate TLS, mapped onto the Pebble flow just run; cross-link the learner's AWS paths.

- [ ] **Step 5: Write 4 concept exercises** (e.g., "which challenge type works when port 80 is firewalled but you control DNS?").

- [ ] **Step 6: Build drills 17–20:** HTTP-01 with port 80 unreachable, wrong challenge type for the setup, renewal failure (cert not yet due / hook fails), untrusted-ACME-root (certbot doesn't trust Pebble). Each with SYMPTOM.md.

- [ ] **Step 7: Write drill solutions 17–20.**

- [ ] **Step 8: Verify** the certbot flow issues a cert and each drill reproduces its symptom.

- [ ] **Step 9: Checkpoint** (do not commit; stop for review)

---

### Task 8: Day 6 content — attack, defend & capstone

**Files:**
- Create: `content/day06.md`
- Create: `labs/drills/capstone/` (8–10 broken setups, hints withheld)
- Create: `labs/drills/solutions/capstone-NN.md`

**Interfaces:**
- Consumes: everything from Tasks 2–7.
- Produces: the capstone gauntlet + teach-back prompt.

- [ ] **Step 1: Write day06.md content**

Sections: objectives; theory — rogue-CA MITM, downgrade/stripping, certificate pinning (why mobile uses it), real failures (DigiNotar, Heartbleed's cert angle, Symantec distrust) each with its lesson. Guided attack lab:

```
# Make a rogue CA and a cert for example.local from it
docker compose run --rm toolbox bash -c "mk rogue CA + issue example.local"
# Install rogue root into the CLIENT trust store, then MITM
# Show curl now TRUSTS the attacker cert -> the 'aha'
# Defend: pin the real leaf's public-key hash and show the MITM now fails
```

- [ ] **Step 2: Build the capstone gauntlet (8–10 setups)**

Reuse drill infrastructure but **withhold hints**. Mix failure classes from Days 1–5 (missing intermediate, wrong SAN, expired, protocol mismatch, mTLS wrong CA, ACME challenge failure, rogue CA, OCSP/pinning). Each `capstone/capstone-NN/SYMPTOM.md` gives only the symptom.

- [ ] **Step 3: Write capstone solutions** in `solutions/capstone-NN.md` (full diagnosis, revealed only after attempt).

- [ ] **Step 4: Write the teach-back prompt** at the end of day06.md: the learner writes, in their own words, the full trust model and the four-check verification order — the retention lock-in.

- [ ] **Step 5: Verify** the rogue-CA MITM lab demonstrably succeeds then fails-after-pinning, and every capstone setup reproduces its symptom.

- [ ] **Step 6: Checkpoint** (do not commit; stop for review)

---

### Task 9: GLOSSARY.md

**Files:**
- Create: `content/GLOSSARY.md`

- [ ] **Step 1: Write plain-English glossary** covering every term introduced across Days 1–6 (certificate, CA, root/intermediate/leaf, CSR, SAN, chain of trust, trust store, handshake, SNI, ALPN, cipher suite, mTLS, ACME, challenge types, CRL/OCSP/stapling, CT log, pinning, MITM, downgrade). One-to-three sentence plain-English definition each, matching the style of the LA/quantum GLOSSARY files.

- [ ] **Step 2: Reconcile against corpus.** Grep the day files for capitalized/acronym terms and confirm each appears in the glossary (lesson carried from the prior glossary project). Fix gaps.

- [ ] **Step 3: Checkpoint** (do not commit; stop for review)

---

### Task 10: README.md + journal.md

**Files:**
- Create: `README.md`
- Create: `journal.md`

- [ ] **Step 1: Write README.md** as the daily navigator (match `aws_network_components/README.md` style): file map, one-time setup (build the toolbox image, run the CA scripts), a "Verify setup" block, per-day pointers, and a **"Where this goes next"** section naming Phase 2 (applied crypto: SSH/JWT/code signing/encryption-at-rest) and Phase 3 (VPN/IPsec, DNS security, zero-trust mTLS, TLS inspection, Kubernetes cert-manager) as future specs that reuse `labs/ca/`.

- [ ] **Step 2: Write journal.md** with a one-entry-per-day template (what I built, what broke, what I learned).

- [ ] **Step 3: Full path smoke test.** From a clean state: build toolbox → run CA scripts → walk Day 2 curl success → Day 4 mTLS success → Day 5 certbot issuance. Confirm each documented "Expected" line matches reality. Fix any drift.

- [ ] **Step 4: Checkpoint** (do not commit; stop for review)

---

## Self-Review (completed against the spec)

**Spec coverage:**
- Verification mental model → Task 3 (Day 1). ✓
- Become a CA → Tasks 2 (scripts) + 4 (Day 2). ✓
- Handshake on the wire / tshark → Task 5 (Day 3). ✓
- mTLS + trust stores → Task 6 (Day 4). ✓
- ACME/Pebble + AWS bridge → Task 7 (Day 5). ✓
- Attack/defend + capstone + teach-back → Task 8 (Day 6). ✓
- ~40 drills with hints + solutions → 20 numbered drills (Tasks 3–7) + 8–10 capstone (Task 8) + 24 concept exercises = ~50 diagnostic reps. ✓ (exceeds target; acceptable)
- Persistent CA reused everywhere → Task 2 artifacts consumed by Tasks 4–10. ✓
- GLOSSARY → Task 9. ✓
- README phase roadmap (Phase 2/3 extensibility) → Task 10 Step 1. ✓
- Offline / Pebble / no domain → Global Constraints + Task 7. ✓
- Model-switch gate + no-commit → Global Constraints + gate before Task 3 + every Checkpoint. ✓

**Placeholder scan:** No "TBD"/"handle edge cases" placeholders; each content task lists concrete sections and real commands. Full markdown prose is intentionally deferred to execution (content-writing model) — the plan specifies exact sections, commands, drill classes, and verification, which is the appropriate altitude for a content deliverable.

**Type/name consistency:** `ca-chain.cert.pem`, `issue-server-cert.sh`, `certlab` network, `:8443` port, and the "four-check verification order" phrase are used consistently across all tasks.

---

## Execution Handoff

Choose an execution approach when ready. Note the model-switch gate before Task 3 and the no-commit constraint at every checkpoint.

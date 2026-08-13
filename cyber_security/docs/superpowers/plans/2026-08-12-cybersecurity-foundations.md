# Cybersecurity Foundations Fast-Track — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 22-module (Day 0–21) purple-team cybersecurity foundations learning path in `cyber_security/`, with runnable Docker/AWS labs, strategy docs, and an extension roadmap.

**Architecture:** A purple-team spiral — each day teaches an attack, then instruments the defense/detection for that same attack. Four phases (Fundamentals → Web/App → Cloud/AWS → Integration) plus a Day 0 ignition. Content files live in `content/`, hands-on labs in `labs/dayNN/`. Labs are Docker-first and self-contained; AWS is used only in Phase 3 with teardown scripts. Knowledge compounds — earlier attacks reappear as later detection targets.

**Tech Stack:** Markdown content; Docker + docker-compose labs; a Kali-style attacker toolbox container; standard offensive tooling (nmap, hashcat/john, sqlmap, hydra, burp/mitmproxy, gitleaks/trivy) and defensive tooling (iptables, suricata, fail2ban, auditd, ELK-lite); AWS CLI + IAM/CloudTrail/GuardDuty/Config for Phase 3.

## Global Constraints

- **Never commit.** The learner handles all version control. This plan contains **no `git commit` steps** — each task ends with a **Verify checkpoint** instead. Do not run `git add`/`git commit`/`git push`.
- **Model split:** Reasoning/design on the current model; **switch to Sonnet for all file-writing** (content, labs, code, drills). Spec/plan/review docs may stay on the current model.
- **Think step by step** before writing each content file or lab — outline structure first.
- **Drills always ship with hints + solution sketches** (offline self-check). No drill without answers.
- **Per-day content anatomy** (every Day file follows this): (1) Concept / mental model, (2) Attack lab, (3) Defense lab, (4) Drill (3–5 items, each with hint + solution sketch), (5) Journal prompt.
- **Docker-first labs.** AWS only in Phase 3; every AWS lab includes a `teardown.sh` and stays free-tier-friendly. Warn on any cost (e.g. GuardDuty) in the lab README.
- **Authorized-lab only.** All offensive tooling targets the provided local containers or the learner's own AWS sandbox. Every lab README states this explicitly.
- **Naming:** content files `content/dayNN-<slug>.md` (zero-padded NN); labs `labs/dayNN/`. Strategy docs and roadmap at the paths named in their tasks.
- **Grow shared docs incrementally:** each Day task appends its new terms to `content/GLOSSARY.md` and marks its covered nodes in `ROADMAP.md`.

## Per-Day Task Procedure (applies to every Day task, Tasks 6–27)

Each Day task's steps follow this identical procedure. The **concrete substance** (objectives, attack, defense, tools, target, drills, terms, roadmap nodes) is spelled out per-task below — this is only the mechanical loop, factored out to avoid repetition:

- **Step A — Outline (think step by step):** draft the section outline for the day from the task's objectives before writing prose.
- **Step B — Write content file** `content/dayNN-<slug>.md` following the 5-part anatomy, on Sonnet.
- **Step C — Build the lab** under `labs/dayNN/` (compose file / scripts / target as specified), plus `labs/dayNN/README.md` (authorized-use notice, setup, walkthrough) and `labs/dayNN/SOLUTION.md`.
- **Step D — Verify the lab runs** (the task lists the exact command + expected result: attack reproduces, defense blocks/detects).
- **Step E — Write drills with hints + solution sketches** into the content file's Drill section.
- **Step F — Update shared docs:** append new terms to `content/GLOSSARY.md`; mark covered nodes in `ROADMAP.md`; add a journal prompt.
- **Step G — Verify checkpoint** (no commit): the day has all 5 anatomy parts; every drill has a hint + solution; the lab's verify command passed; GLOSSARY + ROADMAP updated.

---

## Phase A — Scaffolding & Strategy

### Task 1: Project scaffold + README + journal + glossary seed

**Files:**
- Create: `cyber_security/README.md`
- Create: `cyber_security/journal.md`
- Create: `cyber_security/content/GLOSSARY.md`
- Create: `cyber_security/.gitignore`

**Interfaces:**
- Produces: the directory layout (`content/`, `labs/`, `docs/`) and the day index every later task links into.

- [ ] **Step 1: Create directory structure** — `content/`, `labs/`, `docs/superpowers/{specs,plans,reviews}` (specs/plans already exist).
- [ ] **Step 2: Write `README.md`** — what the path is, learner profile, the purple-spiral method (1 paragraph), prerequisites (Docker, AWS CLI + sandbox account for Phase 3), how to bootstrap the lab (points to Day 0), the full Day 0–21 index as a table with links, and the standing rules (authorized-use, teardown for AWS).
- [ ] **Step 3: Write `journal.md`** — a template header explaining the writeup habit, with a per-day entry template (date, what I attacked, how, what defended it, what confused me, one thing to revisit).
- [ ] **Step 4: Seed `content/GLOSSARY.md`** — title + intro + alphabetized section headers; seed with foundational terms already known (CIA triad, threat model, attack surface, trust boundary).
- [ ] **Step 5: Write `.gitignore`** — ignore AWS credential dumps, `*.pem`, lab loot/output dirs, `__pycache__`, `.env`.
- [ ] **Step 6: Verify checkpoint** — all files exist, README day index lists 22 modules, no broken relative links to planned paths. (No commit.)

### Task 2: Lab bootstrap infrastructure (Docker + Kali toolbox)

**Files:**
- Create: `cyber_security/labs/README.md`
- Create: `cyber_security/labs/base/docker-compose.yml`
- Create: `cyber_security/labs/base/attacker/Dockerfile`
- Create: `cyber_security/labs/base/README.md`
- Create: `cyber_security/labs/base/up.sh`, `cyber_security/labs/base/down.sh`

**Interfaces:**
- Produces: an `attacker` container (Kali-style toolbox) and an isolated docker network that later day-labs attach targets to. Later labs reference the network name and the attacker image.

- [ ] **Step 1: Write attacker `Dockerfile`** — base on `kalilinux/kali-rolling` (or a Debian slim + tools fallback documented in README); install the toolset used across the path: `nmap tcpdump tshark netcat-traditional curl dnsutils john hashcat hydra sqlmap gobuster whatweb jq git openssl iproute2 iputils-ping vim`. Pin with `apt-get install -y --no-install-recommends` and document that image size is large.
- [ ] **Step 2: Write `base/docker-compose.yml`** — define the attacker service on a dedicated bridge network `cyberlab`, with a shared `./loot` volume for output. No target yet (targets come per-day).
- [ ] **Step 3: Write `up.sh` / `down.sh`** — `up.sh`: build + `docker compose up -d` + print the exec command; `down.sh`: `docker compose down -v`.
- [ ] **Step 4: Write `labs/base/README.md`** — authorized-use notice, how to build (`./up.sh`), how to shell in (`docker compose exec attacker bash`), how the `cyberlab` network is reused, teardown.
- [ ] **Step 5: Write `labs/README.md`** — index of all day-labs, the shared conventions (each lab attaches to `cyberlab`, each has README + SOLUTION + teardown), and the safety notice.
- [ ] **Step 6: Verify the attacker container builds and tools work**

Run: `cd cyber_security/labs/base && ./up.sh && docker compose exec attacker sh -c "nmap --version && sqlmap --version && hashcat --version && hydra -h >/dev/null 2>&1 && echo TOOLS_OK"`
Expected: prints tool versions and `TOOLS_OK`.

- [ ] **Step 7: Verify checkpoint** — container builds, `TOOLS_OK` printed, `down.sh` cleans up. (No commit.)

### Task 3: `content/STRATEGY.md` — the top-1% playbook

**Files:**
- Create: `cyber_security/content/STRATEGY.md`

- [ ] **Step 1: Outline (think step by step)** the playbook principles.
- [ ] **Step 2: Write `STRATEGY.md`** (on Sonnet) covering, each as a short section with a concrete "do this" action: attacker-mindset-before-tools; learn-by-breaking (build → break → fix → detect); fundamentals compound / tools are transient; spaced retrieval via writeups; read real CVEs & advisories early (with one worked example of reading an advisory); threat modeling (STRIDE) as a daily habit; reverse-the-kill-chain for defense. End with "how to run a day of this path."
- [ ] **Step 3: Verify checkpoint** — every principle has a concrete action; ties to the journal habit; no filler. (No commit.)

### Task 4: `content/ANTIPATTERNS.md` — the 80% time-wasters

**Files:**
- Create: `cyber_security/content/ANTIPATTERNS.md`

- [ ] **Step 1: Outline** the antipatterns.
- [ ] **Step 2: Write `ANTIPATTERNS.md`** (on Sonnet) — each antipattern as **Symptom → Why it wastes time → The fix**: cert-chasing before hands-on; tutorial/passive-video hell; tool-collecting & Kali distro-hopping; skipping fundamentals to jump to "hacking"; going too wide too fast; no writeups; `msfconsole` autopwn without understanding; ignoring defense entirely; only-CTF-never-real-systems; not reading source/advisories.
- [ ] **Step 3: Verify checkpoint** — each antipattern has all three parts and a fix that maps to something in this path. (No commit.)

### Task 5: `ROADMAP.md` — coverage & extension map

**Files:**
- Create: `cyber_security/ROADMAP.md`

**Interfaces:**
- Produces: the coverage table every Day task updates (Step F marks nodes Covered/Partial/Deferred).

- [ ] **Step 1: Outline** the roadmap.sh cybersecurity tree top-level nodes (fundamentals, networking, OS, crypto, identity/IAM, web security, cloud security, tooling, blue team/SOC, offensive, IR/forensics, governance).
- [ ] **Step 2: Write `ROADMAP.md`** (on Sonnet) — a table mapping each roadmap.sh node to **Covered / Partial / Deferred** (all "Deferred" initially, filled in as days ship), a "how this path maps to roadmap.sh" intro, and an **Extension Modules** section listing concrete future phases: Web Exploitation Deep-Dive; Binary Exploitation/Reversing intro; SIEM & Threat Hunting (blue-team track); Malware Analysis intro; OSCP-style privesc track; Cloud IR & detection engineering at scale; Governance/Compliance literacy. Each extension names its prerequisite day(s).
- [ ] **Step 3: Verify checkpoint** — every roadmap.sh top-level node appears; extension modules each have a prerequisite pointer. (No commit.)

---

## Phase B — Day 0 Ignition

### Task 6: Day 0 — Ignition, threat modeling, lab bootstrap

**Files:**
- Create: `cyber_security/content/day00-ignition.md`
- Create: `cyber_security/labs/day00/README.md`, `labs/day00/SOLUTION.md`
- Modify: `content/GLOSSARY.md`, `ROADMAP.md`

**Substance:**
- **Objectives:** run the build→break→fix→detect loop mentally; perform a STRIDE threat model; get the lab environment running.
- **Concept:** how to use this path; the loop; STRIDE walkthrough on a sample architecture (browser → web app → DB → S3 bucket), identifying trust boundaries and one threat per STRIDE category.
- **Attack lab:** none (setup day) — instead, bring up `labs/base` and confirm the attacker toolbox works (reuse Task 2's verify).
- **Defense lab:** identify the trust boundaries in the sample architecture and list one mitigation per boundary.
- **Drills (with solutions):** (1) STRIDE-classify 5 given threats; (2) draw trust boundaries for a login+DB+S3 app; (3) pick the highest-risk threat and justify.
- **Terms:** STRIDE, trust boundary, attack surface, threat actor, mitigation.
- **Roadmap nodes:** mark "Fundamentals → threat modeling" Covered.

- [ ] Follow the **Per-Day Task Procedure** (Steps A–G). Lab verify command: `cd cyber_security/labs/base && ./up.sh && docker compose exec attacker sh -c "echo LAB_READY"` → expects `LAB_READY`.

---

## Phase C — Fundamentals (Days 1–6)

### Task 7: Day 1 — Attacker mindset, threat modeling, recon

**Files:** `content/day01-recon.md`; `labs/day01/{docker-compose.yml,README.md,SOLUTION.md}`; modify `GLOSSARY.md`, `ROADMAP.md`.

**Substance:**
- **Objectives:** distinguish passive vs active recon; enumerate a target's exposed surface.
- **Concept:** CIA triad through an attacker's eyes; the recon phase of the kill chain; information disclosure as attack surface.
- **Attack:** against a target container running a small web + DNS setup — banner grabbing (`nc`, `curl -I`), tech fingerprinting (`whatweb`), DNS lookups (`dig`/`host`), initial port sweep (`nmap -sV` top ports).
- **Defense:** attack-surface reduction — remove version banners, close unneeded ports, minimize headers.
- **Target:** compose adds a `target` service (simple nginx + a service with a leaky banner) on `cyberlab`.
- **Drills:** (1) given nmap output, list the attack surface; (2) which headers leak info and how to suppress; (3) passive vs active — classify 5 actions. All with solution sketches.
- **Terms:** recon, banner grabbing, fingerprinting, enumeration, attack surface reduction.
- **Roadmap:** "Fundamentals → reconnaissance" Covered.
- **Lab verify:** `docker compose exec attacker sh -c "nmap -sV target | tee /loot/day01.txt | grep -q open && echo ATTACK_OK"` → `ATTACK_OK`.

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 8: Day 2 — Networking as an attacker

**Files:** `content/day02-networking.md`; `labs/day02/{docker-compose.yml,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** understand how scanning and MITM work at the packet level; detect a scan.
- **Concept:** OSI/TCP through a security lens; SYN vs connect scans; ARP spoofing/MITM; sniffing.
- **Attack:** full `nmap` enumeration (`-sS`, `-sV`, `-sC`); capture traffic with `tcpdump`/`tshark`; ARP-spoof between two target containers on an isolated network and sniff cleartext creds.
- **Defense:** segmentation, host firewall (`iptables`) rules, scan detection (intro `suricata` or a simple rule), detecting ARP anomalies.
- **Target:** compose adds `victim` + `server` containers exchanging cleartext on `cyberlab`; attacker performs MITM.
- **Drills:** (1) interpret a given pcap snippet; (2) write an iptables rule to drop a scan pattern; (3) explain why ARP spoofing works and one detection. With solutions.
- **Terms:** SYN scan, ARP spoofing, MITM, packet capture, IDS, network segmentation.
- **Roadmap:** "Networking security" Covered; "Blue team → IDS" Partial.
- **Lab verify:** `docker compose exec attacker sh -c "nmap -sS server >/loot/day02.txt && grep -q open /loot/day02.txt && echo ATTACK_OK"` → `ATTACK_OK`; plus a documented manual MITM check in SOLUTION.md.

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 9: Day 3 — Cryptography for security

**Files:** `content/day03-crypto.md`; `labs/day03/{docker-compose.yml,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** identify and crack weak crypto; choose strong primitives.
- **Concept:** hashing vs encryption; symmetric vs asymmetric (bridge to the learner's TLS knowledge); where crypto breaks — weak/unsalted hashes, ECB pattern leakage, bad randomness, key reuse.
- **Attack:** identify hash types; crack weak MD5/SHA1 hashes with `hashcat`/`john` + wordlist; demonstrate ECB penguin-style pattern leakage with `openssl`; conceptual padding-oracle demo (script provided).
- **Defense:** bcrypt/argon2, salting, proper key management, authenticated encryption (AEAD/GCM), TLS config hardening checklist.
- **Target:** a provided `hashes.txt` + a small wordlist in the lab; a script producing ECB vs CBC ciphertext images.
- **Drills:** (1) match algorithms to use-cases; (2) crack 3 provided hashes; (3) explain why ECB leaks. With solutions (including the cracked plaintexts).
- **Terms:** hash, salt, symmetric/asymmetric, ECB/CBC/GCM, KDF, padding oracle, AEAD.
- **Roadmap:** "Cryptography" Covered.
- **Lab verify:** `docker compose exec attacker sh -c "john --wordlist=/loot/wordlist.txt /loot/hashes.txt >/dev/null 2>&1; john --show /loot/hashes.txt | grep -q ':' && echo ATTACK_OK"` → `ATTACK_OK`.

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 10: Day 4 — Authentication & identity

**Files:** `content/day04-auth.md`; `labs/day04/{docker-compose.yml,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** attack weak auth; forge tokens; design secure auth.
- **Concept:** password storage, sessions/cookies, tokens, JWT structure & claims, OAuth/OIDC basics.
- **Attack:** brute force a login with `hydra`; crack captured password hashes; forge/tamper a JWT (`alg:none`, weak-secret signing) with `jwt_tool` or a provided script; demonstrate session fixation/hijack.
- **Defense:** MFA, secure session management, JWT best practices (verify alg, strong secret, short expiry), rate limiting + account lockout.
- **Target:** a small Flask/Node auth app container with a weak login + a JWT endpoint signed with a guessable secret.
- **Drills:** (1) decode & tamper a given JWT to elevate role; (2) list 4 login-hardening controls and the attack each stops; (3) why `alg:none` is dangerous. With solutions.
- **Terms:** session, cookie, JWT, claim, MFA, brute force, rate limiting, OIDC.
- **Roadmap:** "Identity & authentication" Covered.
- **Lab verify:** `docker compose exec attacker sh -c "hydra -l admin -P /loot/pw.txt target http-post-form '<form>' 2>/dev/null | grep -qi 'login:' && echo ATTACK_OK"` (exact form string in SOLUTION.md) → `ATTACK_OK`.

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 11: Day 5 — Linux/OS security & privilege escalation

**Files:** `content/day05-privesc.md`; `labs/day05/{docker-compose.yml,Dockerfile,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** enumerate a Linux host and escalate to root via a misconfig.
- **Concept:** users/groups/permissions, SUID/SGID, `sudo`, capabilities, cron, PATH abuse.
- **Attack:** run `linpeas` (vendored in lab) to enumerate; exploit a planted vector — a SUID binary via GTFOBins, a `sudo` misconfig, and a writable cron script (pick one as primary, list others).
- **Defense:** least privilege, remove needless SUID, `sudo` hygiene, `auditd` monitoring of privileged actions.
- **Target:** a deliberately-vulnerable Debian container (custom Dockerfile) with a SUID `find`/`vim` and a world-writable cron.
- **Drills:** (1) given `find / -perm -4000` output, pick the exploitable binary and the GTFOBins path; (2) fix the misconfig; (3) what would `auditd` log for this escalation. With solutions.
- **Terms:** SUID/SGID, capability, GTFOBins, privilege escalation, least privilege, auditd.
- **Roadmap:** "OS security" Covered; "privilege escalation" Covered.
- **Lab verify:** documented in SOLUTION.md — after exploitation, `id` inside target shows `uid=0`; a scripted check `docker compose exec target sh -c "test -u /usr/bin/find && echo VULN_PRESENT"` → `VULN_PRESENT` confirms the vector is planted.

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 12: Day 6 — Consolidation mini-CTF (fundamentals)

**Files:** `content/day06-ctf-fundamentals.md`; `labs/day06/{docker-compose.yml,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** chain recon → network enum → hash crack → privesc unaided.
- **Concept:** short — how to approach an unknown box; note-taking during a CTF.
- **Lab (CTF):** a single box with staged flags: `flag1` from recon/enum, `flag2` from cracking a discovered hash, `flag3` from privesc to root. Flags are `CTF{...}` strings placed at each stage.
- **Defense reflection:** for each flag, name the control that would have stopped it.
- **Drills:** the CTF itself is the drill; `SOLUTION.md` is the full staged walkthrough. Content file includes a hints ladder (nudge → bigger nudge → answer) per stage.
- **Terms:** none new required; reinforce.
- **Roadmap:** mark Phase 1 nodes "reinforced."
- **Lab verify:** `docker compose config -q && echo COMPOSE_OK`; SOLUTION.md walkthrough reproduces all 3 flags (documented commands).

- [ ] Follow the Per-Day Task Procedure (A–G). This task also includes: **update `journal.md`** with a Phase 1 retro prompt, and **update `ROADMAP.md`** end-of-phase status.

---

## Phase D — Web / Application (Days 7–12)

### Task 13: Day 7 — HTTP & the web as attack surface

**Files:** `content/day07-http.md`; `labs/day07/{docker-compose.yml,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** intercept and modify HTTP; understand browser trust (SOP/CORS).
- **Concept:** HTTP methods/headers/cookies/status, statelessness, the request/response lifecycle, Same-Origin Policy, CORS.
- **Attack:** intercept & tamper requests with `mitmproxy` (headless-friendly) or Burp; modify params; map an app manually.
- **Defense:** security headers (CSP, HSTS, X-Frame-Options, etc.), correct CORS config.
- **Target:** OWASP Juice Shop container on `cyberlab`.
- **Drills:** (1) given a response, name the missing security headers and their risk; (2) tamper a request to change a param and observe; (3) explain a CORS misconfig. With solutions.
- **Terms:** HTTP method, header, cookie, SOP, CORS, CSP, HSTS, proxy.
- **Roadmap:** "Web security → HTTP fundamentals" Covered.
- **Lab verify:** `docker compose exec attacker sh -c "curl -sI juiceshop:3000 | head -1 | grep -q 200 && echo TARGET_OK"` → `TARGET_OK`.

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 14: Day 8 — Web attacks I: injection & XSS

**Files:** `content/day08-injection-xss.md`; `labs/day08/{docker-compose.yml,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** exploit injection and XSS; defend with parameterization + encoding.
- **Concept:** injection = mixing data and code; SQLi (in-band/blind), command injection; XSS (reflected/stored/DOM).
- **Attack:** manual SQLi then `sqlmap`; command injection; stored + reflected XSS.
- **Defense:** parameterized queries/prepared statements, input validation, output encoding, CSP as XSS mitigation.
- **Target:** DVWA container (adjustable security level) on `cyberlab`.
- **Drills:** (1) turn a given query into a UNION-based SQLi; (2) write the parameterized fix; (3) classify 3 XSS snippets by type and give the encoding that stops each. With solutions.
- **Terms:** SQL injection, UNION-based/blind, command injection, XSS types, output encoding, prepared statement.
- **Roadmap:** "Web security → injection/XSS" Covered; "OWASP Top 10" Partial.
- **Lab verify:** `docker compose exec attacker sh -c "sqlmap -u '<dvwa-url>' --batch --dbs 2>/dev/null | grep -qi 'available databases' && echo ATTACK_OK"` (exact URL + cookie in SOLUTION.md) → `ATTACK_OK`.

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 15: Day 9 — Web attacks II: access control, SSRF, CSRF

**Files:** `content/day09-access-ssrf-csrf.md`; `labs/day09/{docker-compose.yml,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** exploit broken access control, SSRF, CSRF; map to OWASP Top 10.
- **Concept:** authn vs authz; IDOR/broken access control; SSRF; CSRF; the OWASP Top 10 as a map.
- **Attack:** IDOR to read another user's object; SSRF to reach an internal-only service; a CSRF PoC page.
- **Defense:** server-side authz checks on every object, SSRF allowlist + block link-local (169.254.169.254), anti-CSRF tokens + `SameSite` cookies.
- **Target:** Juice Shop (IDOR/SSRF) + a small internal service container reachable only from the app network.
- **Drills:** (1) given two user IDs, craft the IDOR request; (2) why blocking `169.254.169.254` matters (ties forward to Day 15); (3) build a minimal CSRF form. With solutions.
- **Terms:** authz, IDOR, broken access control, SSRF, CSRF, SameSite, link-local metadata.
- **Roadmap:** "OWASP Top 10" Covered; "access control/SSRF" Covered.
- **Lab verify:** `docker compose config -q && docker compose exec attacker sh -c "curl -s juiceshop:3000/rest/user/whoami >/dev/null && echo TARGET_OK"` → `TARGET_OK`; exploit steps in SOLUTION.md.

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 16: Day 10 — Secrets & supply chain

**Files:** `content/day10-secrets-supplychain.md`; `labs/day10/{docker-compose.yml,sample-repo/,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** find leaked secrets and vulnerable dependencies; remediate.
- **Concept:** secrets sprawl, hardcoded creds, dependency/transitive vulns, SBOM, typosquatting.
- **Attack:** scan a provided repo + image for secrets (`gitleaks`/`trufflehog`); scan an image for vuln deps (`trivy`/`grype`); identify a planted vulnerable dependency.
- **Defense:** secrets management (AWS SSM/Secrets Manager, env injection), dependency scanning in CI, SBOM generation (`syft`), pre-commit secret hooks.
- **Target:** a `sample-repo/` with planted secrets in git history + a Dockerfile pulling a known-vulnerable package.
- **Drills:** (1) run gitleaks and list the leaked secret + the fix; (2) read a trivy report and pick the highest-severity CVE to fix; (3) where should each secret actually live. With solutions.
- **Terms:** secrets sprawl, SBOM, CVE, CVSS, transitive dependency, typosquatting, secrets manager.
- **Roadmap:** "Supply chain security" Covered; "secrets management" Covered.
- **Lab verify:** `docker compose exec attacker sh -c "gitleaks detect --source /work/sample-repo --no-git 2>/dev/null; gitleaks detect --source /work/sample-repo -v 2>&1 | grep -qi 'secret' && echo ATTACK_OK"` → `ATTACK_OK`.

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 17: Day 11 — Logging & the blue-team loop

**Files:** `content/day11-detection.md`; `labs/day11/{docker-compose.yml,rules/,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** instrument detection for the attacks learned so far; close the purple loop.
- **Concept:** telemetry & log sources, detection engineering, what a good detection looks like (fidelity vs noise), the purple loop.
- **Attack (replay):** re-run a port scan (Day 2), a brute force (Day 4), and a web injection (Day 8) against instrumented targets.
- **Defense/detection:** stand up a lightweight log stack (rsyslog/`filebeat`+ELK-lite, or structured JSON logs + `jq`), `fail2ban` for brute force, a `suricata` rule for the scan, and a log query for the injection; alert on each.
- **Target:** reuse earlier targets with logging enabled + a small detection container.
- **Drills:** (1) write a detection query for the brute force; (2) tune out a false positive; (3) map each replayed attack to its log source. With solutions.
- **Terms:** telemetry, detection engineering, true/false positive, SIEM, fail2ban, signature vs anomaly.
- **Roadmap:** "Blue team → logging/detection" Covered; IDS node upgraded to Covered.
- **Lab verify:** `docker compose exec attacker sh -c "for i in $(seq 1 6); do curl -s target/login -d 'u=a&p=b' >/dev/null; done"; docker compose exec detection sh -c "grep -qi 'ban\\|alert\\|fail' /var/log/detect.log && echo DETECT_OK"` → `DETECT_OK`.

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 18: Day 12 — Web consolidation mini-CTF

**Files:** `content/day12-ctf-web.md`; `labs/day12/{docker-compose.yml,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** chain a web attack end-to-end and detect it.
- **Lab (CTF):** a web box combining injection (foothold) → broken access control (escalate) → a detection challenge (find the attack in provided logs). Staged `CTF{...}` flags.
- **Drills:** the CTF; hints ladder per stage in content; full walkthrough in SOLUTION.md including the detection answer.
- **Roadmap:** Phase 2 nodes "reinforced"; end-of-phase status update.
- **Lab verify:** `docker compose config -q && echo COMPOSE_OK`; SOLUTION.md reproduces all flags.

- [ ] Follow the Per-Day Task Procedure (A–G). Also update `journal.md` with a Phase 2 retro prompt and `ROADMAP.md` end-of-phase status.

---

## Phase E — Cloud / AWS (Days 13–18)

> **All Phase E labs:** require the learner's own AWS sandbox account; every lab has `setup.sh` + `teardown.sh`, stays free-tier-friendly, and the README states estimated cost + a teardown reminder. Labs use the AWS CLI from the attacker container or the host. **Never** hardcode credentials; use a named profile.

### Task 19: Day 13 — Cloud security model & IAM foundations

**Files:** `content/day13-cloud-iam.md`; `labs/day13/{setup.sh,teardown.sh,policies/,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** read/write IAM policies; apply least privilege; understand policy evaluation.
- **Concept:** shared responsibility model; IAM principals/policies/roles; identity as the new perimeter; policy evaluation logic (explicit deny > allow > implicit deny).
- **Lab (AWS):** `setup.sh` creates a sandbox IAM user + role + an over-permissive policy; learner rewrites it to least privilege; `teardown.sh` deletes all created resources.
- **Defense:** permission boundaries, SCP intro, `iam:PassRole` awareness (sets up Day 14).
- **Drills:** (1) given a policy, identify the over-broad statement and tighten it; (2) predict the outcome of an allow+deny combo; (3) explain shared responsibility for S3 vs EC2. With solutions.
- **Terms:** IAM principal/policy/role, least privilege, permission boundary, SCP, shared responsibility, policy evaluation.
- **Roadmap:** "Cloud security → IAM foundations" Covered.
- **Lab verify:** `bash labs/day13/setup.sh --dry-run || aws iam simulate-principal-policy ...` documented; teardown verified by `aws iam get-user --user-name <lab-user>` returning NoSuchEntity after `teardown.sh`.

- [ ] Follow the Per-Day Task Procedure (A–G), with setup/teardown in place of Docker up/down.

### Task 20: Day 14 — IAM abuse & privilege escalation in AWS

**Files:** `content/day14-iam-privesc.md`; `labs/day14/{setup.sh,teardown.sh,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** enumerate IAM and escalate via a misconfig; detect the path.
- **Concept:** common IAM privesc paths (`iam:PassRole`+`ec2:RunInstances`, `iam:CreatePolicyVersion`, `iam:AttachUserPolicy`), enumeration.
- **Attack (AWS, authorized sandbox):** enumerate as a low-priv user (`enumerate-iam`-style CLI calls / documented `pmapper`), then escalate via a planted `CreatePolicyVersion` misconfig.
- **Defense:** deny dangerous permissions, analyze with `pmapper`, IAM Access Analyzer, boundary policies.
- **Drills:** (1) given a low-priv policy, find the escalation path; (2) which single deny statement breaks the path; (3) what Access Analyzer would flag. With solutions.
- **Terms:** IAM privesc, `PassRole`, policy version, Access Analyzer, pmapper.
- **Roadmap:** "Cloud security → IAM abuse" Covered.
- **Lab verify:** SOLUTION.md documents the escalation; `teardown.sh` verified to remove the user/policy/role (get-* returns NoSuchEntity).

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 21: Day 15 — Metadata/SSRF-to-cloud, S3, exposed services

**Files:** `content/day15-metadata-s3.md`; `labs/day15/{setup.sh,teardown.sh,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** steal role creds via IMDS and exploit S3 misconfig; harden both.
- **Concept:** instance metadata service (IMDSv1 vs IMDSv2), SSRF→temporary creds (callback to Day 9), S3 misconfig, public exposure.
- **Attack (AWS):** stand up an EC2 with a small SSRF-able app; exploit SSRF → `169.254.169.254` → steal role creds → use them; enumerate + read a misconfigured public S3 bucket.
- **Defense:** enforce IMDSv2 (hop limit, token required), S3 Block Public Access, tight bucket policies, least-privilege instance roles.
- **Drills:** (1) the exact SSRF URL to reach IMDS and why IMDSv2 stops it; (2) fix the bucket policy; (3) what the stolen creds can/can't do. With solutions.
- **Terms:** IMDS/IMDSv2, instance role, SSRF-to-cloud, S3 Block Public Access, bucket policy, temporary credentials.
- **Roadmap:** "Cloud security → metadata/S3" Covered; links to Day 9 SSRF.
- **Lab verify:** SOLUTION.md documents cred theft in the sandbox; `teardown.sh` removes EC2 + bucket (verified with `aws ec2 describe-instances`/`s3 ls` empty).

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 22: Day 16 — Cloud detection & response

**Files:** `content/day16-cloud-detection.md`; `labs/day16/{setup.sh,teardown.sh,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** detect the Day 14–15 attacks in AWS-native telemetry; build an alert.
- **Concept:** CloudTrail, GuardDuty, Config, EventBridge; detecting IAM privesc and credential exfil.
- **Lab (AWS):** enable CloudTrail + GuardDuty (note free-trial/cost) or use provided sample findings; replay the Day 14–15 attacks; find them in CloudTrail (Athena/CLI queries) and GuardDuty findings; wire an EventBridge → SNS alert.
- **Defense:** detection & automated response patterns.
- **Drills:** (1) write the CloudTrail/Athena query that catches `CreatePolicyVersion` abuse; (2) which GuardDuty finding maps to IMDS cred theft; (3) design an auto-response. With solutions.
- **Terms:** CloudTrail, GuardDuty, AWS Config, EventBridge, detective control, auto-remediation.
- **Roadmap:** "Cloud security → detection/response" Covered.
- **Lab verify:** documented CLI query returns the replayed event; **cost warning + teardown** (disable GuardDuty, delete trail/bucket) verified.

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 23: Day 17 — Cloud network security

**Files:** `content/day17-cloud-network.md`; `labs/day17/{setup.sh,teardown.sh,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** find and fix over-exposed cloud network config (builds on the learner's AWS networking background).
- **Concept:** VPC, subnets, security groups vs NACLs, public exposure, VPC Flow Logs.
- **Attack/assess:** identify over-permissive security groups (0.0.0.0/0 on sensitive ports), scan an exposed instance from outside with `nmap`, confirm reachability.
- **Defense:** SG least privilege, private subnets + NAT, NACL layering, Flow Logs for visibility, segmentation.
- **Drills:** (1) given SG rules, list the risky ones and the fix; (2) SG vs NACL — when each applies; (3) what Flow Logs would show for the scan. With solutions.
- **Terms:** VPC, subnet, security group, NACL, Flow Logs, public/private subnet, egress control.
- **Roadmap:** "Cloud security → network" Covered; links to prior AWS network learning path.
- **Lab verify:** `setup.sh` creates a VPC + exposed instance; documented external `nmap` finds the open port; `teardown.sh` removes the VPC stack (verified empty).

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 24: Day 18 — Cloud consolidation lab

**Files:** `content/day18-cloud-lab.md`; `labs/day18/{setup.sh,teardown.sh,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** run a combined cloud scenario: enumerate → IAM/SSRF exploit → detect.
- **Lab (AWS):** a scenario chaining Day 14 enumeration + Day 15 SSRF-to-creds, then detecting it via Day 16 telemetry. Staged objectives (not necessarily `CTF{}` — cloud "flags" are proof-of-access artifacts).
- **Drills:** the scenario; SOLUTION.md is the full walkthrough incl. detection; hints ladder in content.
- **Roadmap:** Phase 3 nodes "reinforced"; end-of-phase update.
- **Lab verify:** `teardown.sh` leaves the account clean (documented checks for IAM users, EC2, S3, trails, GuardDuty all empty/disabled).

- [ ] Follow the Per-Day Task Procedure (A–G). Also update `journal.md` (Phase 3 retro) and `ROADMAP.md` end-of-phase status.

---

## Phase F — Integration & Capstone (Days 19–21)

### Task 25: Day 19 — Incident response & forensics basics

**Files:** `content/day19-ir-forensics.md`; `labs/day19/{docker-compose.yml,artifacts/,README.md,SOLUTION.md}`; modify shared docs.

**Substance:**
- **Objectives:** triage a compromised host, build a timeline, write an incident report.
- **Concept:** IR lifecycle (prepare/detect/contain/eradicate/recover/lessons), triage, evidence handling & chain of custody, basic host forensics (logs, processes, persistence, file timelines).
- **Lab:** a pre-compromised container image with planted IOCs (suspicious cron, modified binary, attacker log lines); learner finds IOCs, builds a timeline, fills an incident report template.
- **Drills:** (1) from provided logs, identify the initial access; (2) list the persistence mechanism and how to eradicate; (3) what to preserve for evidence. With solutions.
- **Terms:** IR lifecycle, IOC, triage, chain of custody, persistence, timeline, containment.
- **Roadmap:** "Incident response/forensics" Covered.
- **Lab verify:** `docker compose config -q`; SOLUTION.md lists all planted IOCs and a scripted `grep` check confirms each artifact is present in the image.

- [ ] Follow the Per-Day Task Procedure (A–G).

### Task 26: Day 20 — Capstone I: attack end-to-end

**Files:** `content/day20-capstone-attack.md`; `labs/capstone/{docker-compose.yml,setup.sh,teardown.sh,README.md}`; `labs/capstone/SOLUTION-attack.md`; modify shared docs.

**Substance:**
- **Objectives:** execute a full attack chain against a realistic environment and document findings.
- **Environment:** a combined lab — a web app (Docker) fronting a Linux host (Docker) plus an AWS component (an S3 bucket / IAM role reachable via SSRF-to-creds). Chain: recon → web foothold (injection/access-control) → host privesc → cloud credential access.
- **Deliverable:** the learner produces an attacker's findings report (template provided) capturing each stage, evidence, and impact.
- **Drills:** the capstone attack itself; `SOLUTION-attack.md` is the full chain walkthrough with a hints ladder in the content file.
- **Terms:** kill chain, lateral movement, pivot, findings report.
- **Roadmap:** mark capstone attack Covered.
- **Lab verify:** `docker compose config -q && bash labs/capstone/setup.sh --check` (dry validation); SOLUTION-attack.md reproduces the full chain.

- [ ] Follow the Per-Day Task Procedure (A–G). (Capstone spans Tasks 26–27 and shares the `labs/capstone/` environment.)

### Task 27: Day 21 — Capstone II: harden, detect, report + roadmap update

**Files:** `content/day21-capstone-defend.md`; `labs/capstone/SOLUTION-defend.md`; `labs/capstone/report-template.md`; modify `journal.md`, `ROADMAP.md`, `README.md`.

**Substance:**
- **Objectives:** harden the capstone environment against the Day 20 attack, stand up detection, and write the full attack-and-defense report; choose the next specialization.
- **Concept:** turning findings into fixes; defense-in-depth; measuring whether a control actually blocks the attack.
- **Defense lab:** for each Day 20 stage, apply a control (parameterize the injection, fix access control, remove the SUID/privesc, enforce IMDSv2 + least-privilege role, add detection) and re-run the attack to prove it's blocked/detected.
- **Deliverable:** completed attack-and-defense report from the template; a retrospective; **`ROADMAP.md` updated** to mark the whole foundations block Covered and to pick the next extension module.
- **Drills:** (1) map each Day 20 stage to the control that stops it; (2) prove one control works (before/after); (3) what detection fires for the residual risk. With solutions.
- **Terms:** defense-in-depth, compensating control, residual risk, remediation.
- **Roadmap:** foundations block marked complete; next specialization selected; success-criteria checklist ticked.
- **Lab verify:** re-running the Day 20 chain against the hardened env fails at each stage (documented in `SOLUTION-defend.md`); `teardown.sh` leaves Docker + AWS clean.

- [ ] Follow the Per-Day Task Procedure (A–G). Final step: verify the **success criteria** from the spec are met (learner can threat-model, attack, harden, detect end-to-end) and the completed report exists.

---

## Self-Review (completed during authoring)

**Spec coverage:** STRATEGY.md (Task 3) ✓, ANTIPATTERNS.md (Task 4) ✓, ROADMAP.md (Task 5, updated per-phase) ✓, scaffolding/README/journal/GLOSSARY (Task 1) ✓, lab bootstrap + Kali toolbox (Task 2) ✓, Day 0–21 all mapped (Tasks 6–27) ✓, per-day anatomy enforced via Per-Day Procedure ✓, Docker-first + AWS-only-Phase-3 + teardown ✓, drills-with-solutions constraint ✓, success criteria checked in Task 27 ✓.

**Placeholder scan:** No "TBD/TODO"; each day task carries concrete objectives, attack, defense, target, drills, terms, roadmap nodes, and a verify command. Exact form strings / URLs / cookies that depend on the built target are deferred to each lab's `SOLUTION.md` by design (they can't be known until the target image is chosen), with the verify command shape given.

**Type/name consistency:** shared network `cyberlab`, shared `attacker` service, `content/dayNN-<slug>.md` + `labs/dayNN/` naming, `up.sh`/`down.sh` (Docker) vs `setup.sh`/`teardown.sh` (AWS) used consistently; SSRF/IMDS thread runs Day 9 → Day 15 consistently; detection thread runs Day 2/4/8 → Day 11 → Day 16 consistently.

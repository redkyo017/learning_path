# Cybersecurity Foundations Fast-Track — Design Spec

**Date:** 2026-08-12
**Location:** `cyber_security/`
**Status:** Approved design, ready for implementation planning

---

## 1. Goal & Framing

A **cybersecurity foundations fast-track** for an infra-strong / security-new engineer who wants
to master foundations "as fast as humanly possible" — deliberately skipping the traditional
theory-first path in favor of the unconventional, hands-on strategy that high performers actually use.

- **Learner profile:** Strong in networking, TLS, AWS, Linux, and system architecture. No formal
  security study. Therefore infra basics are *compressed*; the security layer on top gets the depth.
- **Time budget:** 3-4 hrs/day → ~70-80 hr foundations block.
- **Cadence:** ~21 day-modules. "21 days" is a reference, not a contract — modules are self-contained
  and calendar time may extend reasonably.
- **End goal:** Applied security for the learner's own infrastructure. By the end, the learner can
  **threat-model, attack, harden, and detect** end-to-end against a realistic environment.

## 2. Structure — Purple Spiral, Phased (Approach A)

The path is a **purple-team spiral**: every day teaches an **attack first, then immediately
instruments the defense** against that same attack. Topics build in a spiral — earlier attacks
reappear later as detection targets — so knowledge compounds rather than sits in silos.

Four phases:

1. **Fundamentals** — the trust-breaking core (mental models, networking, crypto, auth, OS/privesc)
2. **Application** — HTTP and the most common real-world web attacks + their defenses
3. **Cloud / AWS** — cloud security model, IAM abuse, cloud attacks, cloud detection & response
4. **Integration** — incident response + a two-part attack-and-defend capstone

**Why this structure:** It matches the "applied security for my own infra" end goal, lets us compress
the infra the learner already knows, keeps hands-on work from Day 1, and makes every phase boundary
a clean **extension seam** for deeper/advanced content later.

**Design principle — isolation & clarity:** Each day-module is a self-contained unit with one clear
purpose (one concept + its attack + its defense). A learner can pick up any single day without
reading the internals of others; phases can be extended or reordered without breaking foundations.

## 3. Deliverables

### 3.1 Strategy documents (first-class, not sprinkled)

- **`content/STRATEGY.md`** — the unconventional "top 1%" playbook:
  - Attacker mindset *before* tools (tools are interchangeable; trust models are forever)
  - Learn by breaking: build → break → fix → detect loop
  - Fundamentals compound, tools are transient
  - Spaced retrieval via writeups; read real CVEs/advisories early
  - Threat modeling (STRIDE) as a daily habit
  - Reverse the kill chain: understand the attack, then instrument detection for exactly it

- **`content/ANTIPATTERNS.md`** — the "80% time-wasters" each paired with its fix:
  - Cert-chasing before hands-on
  - Tutorial / passive-video hell
  - Tool-collecting & Kali distro-hopping
  - Skipping fundamentals to jump straight to "hacking"
  - Going too wide too fast (red + blue + cloud + malware simultaneously)
  - Not writing anything down (no writeups)
  - `msf` autopwn without understanding the exploit
  - Ignoring defense entirely

### 3.2 Extension / progress roadmap

- **`ROADMAP.md`** — the pick-up-later map:
  - Maps the full **roadmap.sh cybersecurity** tree
  - Marks each node **Covered / Partial / Deferred** by the 21-day core
  - Lists concrete **extension modules** for later depth, e.g.:
    - Web Exploitation Deep-Dive (advanced injection, deserialization, SSTI)
    - Binary exploitation / reversing intro
    - SIEM & Threat Hunting (blue-team track)
    - Malware analysis intro
    - OSCP-style privilege-escalation track
    - Cloud IR & detection engineering at scale
  - **Updated as the final step of each phase** so progress stays current.

### 3.3 Standard project scaffolding (mirrors existing learning_path projects)

- `README.md` — how to use the path, prerequisites, lab bootstrap, day index
- `journal.md` — running lab journal / writeup log (retention via writing)
- `content/GLOSSARY.md` — plain-English security glossary, grown as terms appear
- `content/` — one theory file per day
- `labs/dayNN/` — one lab per day (attack + defense), with teardown where cloud is involved
- `docs/superpowers/` — specs, plans, reviews

## 4. The 21 Day-Modules

### Phase 0 — Ignition (Day 0)
Strategy + antipatterns + threat modeling (STRIDE) primer + **lab bootstrap**: Docker
attacker/target setup and a Kali-style toolbox container. Learner leaves Day 0 with a working lab.

### Phase 1 — Fundamentals: the trust-breaking core (Days 1-6)
1. Attacker mindset, threat modeling, recon fundamentals
2. Networking as an attacker — scanning/enumeration (nmap), MITM, packet analysis; **defense:** segmentation, firewalls, IDS basics
3. Cryptography for security (builds on TLS knowledge) — hashing, symmetric/asymmetric, real attacks (hash cracking, oracle concepts), key management
4. Authentication & identity — password cracking (hashcat/john), sessions, tokens/JWT; **defense:** secure auth design
5. Linux/OS security & privilege escalation — permissions, SUID, sudo misconfig, capabilities; **defense:** hardening, least privilege
6. Consolidation mini-CTF + writeup

### Phase 2 — Application & the real common attacks (Days 7-12)
7. HTTP & the web as an attack surface — how the web trusts
8. Web attacks I — injection (SQLi, command injection), XSS; + defenses
9. Web attacks II — broken access control (IDOR), SSRF, CSRF; OWASP Top 10 framing
10. Secrets & supply chain — secrets in code/env, dependency vulns, SBOM basics; **defense:** scanning, secrets management
11. Logging & the blue-team loop — instrument detection for everything learned so far; log analysis
12. Web consolidation mini-CTF + writeup

### Phase 3 — Cloud / AWS security (Days 13-18)
13. Cloud security model & IAM foundations — shared responsibility, identity as the new perimeter
14. IAM abuse & privilege-escalation paths in AWS
15. Instance metadata / SSRF-to-cloud, S3 misconfiguration, exposed services
16. Cloud detection & response — CloudTrail, GuardDuty, Config detecting days 14-15 attacks
17. Cloud network security — VPC security, security groups, exposure (builds on AWS networking knowledge)
18. Cloud consolidation lab

### Phase 4 — Integration & capstone (Days 19-21)
19. Incident response & forensics basics — process, triage, evidence handling
20. Capstone I — attack a realistic environment end-to-end
21. Capstone II — harden + detect + write the report; retrospective + update `ROADMAP.md`

## 5. Per-Day File Anatomy

Each day = one theory file in `content/dayNN-*.md` + one lab in `labs/dayNN/`:

1. **Concept** — the mental model (~30-40 min read)
2. **Attack lab** — hands-on (Docker; AWS in Phase 3)
3. **Defense lab** — detect/harden against what was just done
4. **Drill** — 3-5 practice questions/challenges, **always shipped with hints + solution sketches**
   (standing learner rule: offline self-check)
5. **Journal prompt** — a writeup task for retention

## 6. Labs & Tooling

- **Docker-first:** attacker container + vulnerable targets (e.g. DVWA, OWASP Juice Shop, custom
  containers). Self-contained, repeatable, offline-capable. Fits the `docker-tools` repo home.
- **Kali-style toolbox container** as the standard attacker box rather than ad-hoc tool installs.
- **AWS only for Phase 3**, free-tier-friendly, with **every lab teardown-scripted** so cost ≈ $0.
- **PortSwigger Web Security Academy** referenced as optional free supplements on web days; the path
  is fully functional without any external account.

## 7. Success Criteria

By Day 21 the learner can **threat-model, attack, harden, and detect end-to-end** against a
realistic environment — demonstrated by the two-part capstone (Days 20-21) producing a written
attack-and-defense report.

## 8. Extensibility

Phase boundaries are extension seams. `ROADMAP.md` tracks Covered/Partial/Deferred against the full
roadmap.sh tree, so a later "Phase 5: Web Exploitation Deep-Dive" or a dedicated "Blue-Team/SIEM
track" can drop in without disturbing the foundations.

## 9. Build Process Constraints

- **Reasoning/design** on the current (reasoning) model; **switch to Sonnet at the file-writing step**
  to save tokens (content, primers, labs, code). Spec/plan/review docs may be written on the
  current model.
- **Never commit.** The learner handles all version control themselves.
- **Think step by step** before writing each day file / lab / spec.
- **Drills always ship with hints + solution sketches.**

## 10. Out of Scope (for the foundations block)

- Advanced/deep specialization (web exploitation deep-dive, binary exploitation, malware analysis,
  full SIEM engineering) — captured in `ROADMAP.md` as deferred extension modules.
- Certification exam prep as a primary objective (path is applied-security-first, not blueprint-first).
- Physical security, social engineering campaigns, and non-technical governance/compliance depth
  beyond foundational literacy.

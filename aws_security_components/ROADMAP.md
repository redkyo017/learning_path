# AWS Security Mastery — 12-Day Roadmap

This is the map. `README.md` is the daily navigator (prereqs, billing
guardrail, the five-beat loop); this file is where you check "what's next"
and "why this day, in this order."

## The 12 days

| Day | Title | Door (evaluation order) | Service focus | Break → Harden | Est. hours |
|-----|-------|--------------------------|----------------|-----------------|-----------:|
| 0 | [Setup](content/day00-setup.md) | — (no door yet — pre-flight) | Billing guardrail, `labs/base` deploy, daily apply/teardown rhythm | — | 0.5 |
| 1 | [The engine + target deploy](content/day01-iam-engine.md) | Identity policy + resource policy — the whole order, end to end | IAM/STS, policy simulator, Access Analyzer | Over-broad task role reaches a bucket it shouldn't → tightened to least privilege, `AccessDenied` proven | 3.5 |
| 2 | [Advanced identity](content/day02-advanced-identity.md) | Trust policy + permission boundary + session policy | Cross-account roles, STS, confused deputy, boundaries | Privilege escalation via mis-scoped `iam:PassRole`/policy-attach → permission boundary caps it, re-proven blocked | 3.0 |
| 3 | [KMS foundations](content/day03-kms-foundations.md) | Key policy — the root of trust, itself a resource policy | KMS keys, grants, envelope encryption, rotation | Key policy lets the wrong principal decrypt → key policy fixed, decrypt denied for that principal | 3.0 |
| 4 | [KMS advanced + data at rest](content/day04-kms-advanced-data-at-rest.md) | Resource policy + condition keys (`kms:ViaService`, cross-account) | Cross-account KMS, S3/EBS/RDS encryption, grants | Mis-scoped key policy lets a simulated exfil succeed → re-locked, decrypt now denied | 3.0 |
| 5 | [Secrets & certificates](content/day05-secrets-and-certs.md) | Resource policy (secret policy) + service integration | Secrets Manager, Parameter Store, ACM | Secret found leaked into a task-def env var (placeholder) → moved to Secrets Manager + rotation; ALB fronted with ACM HTTPS | 2.5 |
| 6 | [Edge protection I — WAF](content/day06-waf-edge.md) | Request-layer control sitting in front of the engine | WAF Web ACLs, managed + custom rules, rate limiting | SQLi/XSS payload lands (HTTP 200) → Web ACL blocks it (HTTP 403), one false positive tuned | 3.0 |
| 7 | [Edge protection II + network layering](content/day07-shield-network-layering.md) | Condition keys (`aws:SourceVpce`, `aws:SourceIp`) + network controls | Shield, CloudFront security, SG vs NACL vs WAF, VPC endpoint policies | A VPC-only resource is reachable from outside → VPC endpoint + policy + SG/NACL layering locks it to in-VPC only | 3.0 |
| 8 | [Detection](content/day08-detection.md) | Logging/observation layer — reads the engine's decisions | CloudTrail, GuardDuty, Security Hub, Macie, Detective | Trigger ≥2 real findings against your own workload (SSRF task-role theft + a GuardDuty finding) — **free-trial window opens** | 3.5 |
| 9 | [Response automation](content/day09-response-automation.md) | Corrective controls wired to detective signals | EventBridge, Lambda/SSM, Config | Day 8's finding → EventBridge → Lambda auto-quarantines the compromised role; Config flags + remediates a public bucket — **free-trial window closes** | 3.5 |
| 10 | [Governance & multi-account](content/day10-governance-multiaccount.md) | SCP — the deny that beats every identity policy, top of the order | Organizations SCPs, IAM Identity Center, ABAC, Control Tower concept | Prove (simulated/traced) an SCP deny wins over an identity-policy allow; ABAC tag scheme applied | 3.0 |
| 11 | [IR capstone: attack](content/day11-ir-capstone-attack.md) | Integrative — every door from Days 1–10 | Full incident: leaked key → recon → task-role theft via SSRF → attempted exfil/crypto-mining | Scripted attack run against your own workload — **detection re-enabled for the capstone** — every control's artifact captured | 3.5 |
| 12 | [IR capstone: defend + gap-fill](content/day12-ir-capstone-defend.md) | Integrative — contain/eradicate/recover across every door | IR runbook + SCS-C02 self-assessment + full teardown | Re-run a Day-11 attack step → now blocked end-to-end — **final sweep**: base + every day module destroyed, detection confirmed off, CMKs scheduled for deletion | 4.0 |

**Total: ~38.5 hours** across 12 days (~3.2 hrs/day average — some days run
shorter, the capstone days run longer). Budget target for the whole sprint:
**under $15** (see README.md § Cost & Teardown).

## The six phases

| Phase | Days | Theme |
|-------|------|-------|
| 1 — The engine | 1–2 | IAM core evaluation order, then advanced identity (trust, boundaries, sessions) |
| 2 — Data protection | 3–5 | KMS foundations → KMS advanced/cross-account → secrets & certificates |
| 3 — Edge & network | 6–7 | WAF, then Shield + the SG/NACL/WAF/endpoint layering map |
| 4 — Detection & response | 8–9 | Turn on the detection stack, generate real findings, wire auto-remediation, turn it back off |
| 5 — Governance | 10 | SCPs (the top door), multi-account concepts, ABAC at scale |
| 6 — IR capstone | 11–12 | Run a full incident against your own workload, then contain/eradicate/recover it and self-grade against the exam blueprint |

## Dependency graph

```
labs/base (persistent 3-tier workload — ALB, ECS Fargate, CloudFront,
           S3, Secrets Manager, a starter task role)
   │
   ├─▶ Day 1  (IAM engine)              ─┐
   ├─▶ Day 2  (advanced identity)        │  every day layers a Terraform
   ├─▶ Day 3  (KMS foundations)          │  module on top of labs/base;
   ├─▶ Day 4  (KMS advanced)             │  none of them depend on each
   ├─▶ Day 5  (secrets & certs)          │  other except where noted below
   ├─▶ Day 6  (WAF)                      │
   ├─▶ Day 7  (Shield/network layering) ─┘
   │
   ├─▶ Day 8  (detection) ──────enables the free-trial window──────┐
   │                                                                 ▼
   ├─▶ Day 9  (response automation) ◀── consumes Day 8's findings, then
   │                                     disables the detection stack
   │                                     (end of the trial window)
   │
   ├─▶ Day 10 (governance / SCP)
   │
   └─▶ Days 11–12 (IR capstone) ── re-enables detection for the capstone
                                    only, reuses every control built on
                                    Days 1–10, sweeps everything on Day 12
```

Read: `labs/base` is the one dependency every day shares. Days 1–7 and
Day 10 are otherwise independent of each other — attack and harden the
workload from a different angle each day. Day 9 is the only day with a
hard content dependency on the day before it (it closes the break Day 8
opened). Days 11–12 are the only days that reuse *every* prior day's
control at once, which is the point of a capstone.

## SCS-C02 domain map (summary — full detail + self-scored checklist in [`content/CERT-MAP.md`](content/CERT-MAP.md))

| Day | Primary SCS-C02 domain(s) |
|-----|----------------------------|
| 1 | Identity and Access Management |
| 2 | Identity and Access Management |
| 3 | Data Protection |
| 4 | Data Protection |
| 5 | Data Protection; Infrastructure Security |
| 6 | Infrastructure Security |
| 7 | Infrastructure Security |
| 8 | Threat Detection and Incident Response; Security Logging and Monitoring |
| 9 | Threat Detection and Incident Response; Management and Governance |
| 10 | Management and Governance; Identity and Access Management |
| 11 | Threat Detection and Incident Response |
| 12 | All six domains — final self-assessment |

## Detection free-trial window (repeated here because it costs real money if you miss it)

GuardDuty, Security Hub, Macie, and Detective run inside **one** 30-day
free-trial window across this entire sprint:

- **Enabled:** Day 8
- **Disabled:** end of Day 9 (this is a checklist item on Day 9, not
  optional)
- **Re-enabled:** Days 11–12, for the capstone only
- **Swept:** Day 12's final teardown confirms every detection service is
  off and every CMK is scheduled for deletion

See `README.md` § Cost & Teardown for the full guardrail.

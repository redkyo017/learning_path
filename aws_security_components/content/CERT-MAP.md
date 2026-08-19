# CERT-MAP.md — SCS-C02 Domain Map & Day-12 Gap-Fill Checklist

This path is not exam prep — it's a hands-on sprint that happens to
cover every domain of the AWS Certified Security – Specialty (SCS-C02)
exam blueprint along the way. This file is the cross-reference: which
days build which domain, and a self-scored checklist to run on Day 12
so gaps get named before you decide whether to sit the exam.

Domain names and weights below are the public SCS-C02 exam guide
weightings (no exam content, no proprietary material — just the
blueprint's own domain labels, used to organize what this path already
teaches).

## Domain → day map

| # | SCS-C02 domain | Approx. exam weight | Days that cover it | Primary content |
|---|---|---:|---|---|
| 1 | Threat Detection and Incident Response | 14% | 8, 9, 11, 12 | GuardDuty/Macie findings (Day 8), EventBridge→Lambda auto-remediation (Day 9), full attack scenario (Day 11), contain/eradicate/recover (Day 12) |
| 2 | Security Logging and Monitoring | 18% | 8, 10, 11, 12 | CloudTrail management vs. data events, Security Hub standards, Detective (Day 8); an org-wide SCP that structurally prevents CloudTrail tampering, and delegated administration for GuardDuty/Security Hub/Config (Day 10); the CloudTrail-reconstruction and Config resource-history exercises against the capstone incident (Day 11); Day 12 final-sweep audit of what logged what |
| 3 | Infrastructure Security | 20% | 5, 6, 7, 12 | ACM/TLS at the ALB (Day 5), WAF Web ACLs (Day 6), Shield + SG/NACL/VPC-endpoint layering (Day 7); all reused in the Day 12 capstone |
| 4 | Identity and Access Management | 16% | 1, 2, 10, 12 | The evaluation order + policy simulator (Day 1), trust policies/boundaries/confused deputy (Day 2), SCPs/ABAC/permission sets (Day 10); all reused Day 12 |
| 5 | Data Protection | 18% | 3, 4, 5, 12 | KMS key policies + envelope encryption (Day 3), cross-account KMS + condition keys (Day 4), Secrets Manager/Parameter Store (Day 5); reused Day 12 |
| 6 | Management and Governance | 14% | 9, 10, 12 | Config rules + conformance packs (Day 9), SCPs/Organizations/Control-Tower concepts (Day 10); Day 12's final governance sweep |

Day 12 is listed against every domain deliberately — it's the
integrative capstone day and the day this checklist is meant to be run
on, precisely because by then every domain has been touched at least
once.

## Self-scored gap-fill checklist (run this on Day 12)

For each domain, score yourself honestly before checking the answer key
in that domain's day file(s). This isn't graded by anyone but you — the
point is finding out *now*, with 12 days of labs to point back to,
rather than in an exam room.

Score key: **1** = can't explain it without notes · **2** = can explain
the concept but not defend a design choice · **3** = can explain it and
justify a design choice · **4** = can explain it, justify it, *and*
point to the specific lab where I broke and hardened it.

| Domain | Self score (1–4) | Where to re-drill if < 3 |
|---|---|---|
| 1. Threat Detection and Incident Response | ☐ 1 ☐ 2 ☐ 3 ☐ 4 | Day 8 (findings), Day 9 (auto-response), Day 11 (attack) |
| 2. Security Logging and Monitoring | ☐ 1 ☐ 2 ☐ 3 ☐ 4 | Day 8 (CloudTrail tiers, Security Hub standards) |
| 3. Infrastructure Security | ☐ 1 ☐ 2 ☐ 3 ☐ 4 | Day 6 (WAF), Day 7 (SG/NACL/VPC-endpoint layering) |
| 4. Identity and Access Management | ☐ 1 ☐ 2 ☐ 3 ☐ 4 | Day 1 (evaluation order), Day 2 (trust/boundary/session) |
| 5. Data Protection | ☐ 1 ☐ 2 ☐ 3 ☐ 4 | Day 3 (KMS foundations), Day 4 (cross-account KMS) |
| 6. Management and Governance | ☐ 1 ☐ 2 ☐ 3 ☐ 4 | Day 9 (Config), Day 10 (SCPs/ABAC) |

**If any domain scores below 3:** don't move on to scheduling an exam
yet — reopen the day file(s) listed, re-run that day's lab from
`labs/dayNN/`, and re-score. The break→harden signal you captured that
day is the fastest way back to a "3" or "4" on this checklist, faster
than re-reading theory.

See [`ROADMAP.md`](../ROADMAP.md) for the full 12-day dependency graph
and phase grouping this map is drawn from.

# AWS Security Mastery — Design Spec

**Date:** 2026-08-19
**Path directory:** `aws_security_components/`
**Duration:** 12 days, ~5–6 h/day (~60–70h total)
**Author:** Hung Han

---

## 1. Purpose & Goals

Master the working set of AWS security services fast enough to **do the job at
work** — designing and operating security on real AWS workloads — with three
secondary payoffs: readiness for the **AWS Certified Security – Specialty
(SCS-C02)** exam, fluency for **interviews / design reviews**, and **attacker-
and-defender break/fix intuition**.

The learner is **comfortable but self-taught**: makes IAM/S3/KMS work when
needed, but has known gaps and has cargo-culted policies. So the path does not
re-teach "what is a role" — it starts at the *evaluation engine* and the seams.

This is explicitly an **unconventional, compressed** path. It skips the
service-by-service survey most courses use and instead organizes by security
**domain** around two spine principles (§3).

### Success criteria

By the end the learner can, without notes:

1. Trace an access request through the full IAM policy evaluation chain and say
   exactly why it was allowed or denied.
2. Explain and configure "who can actually decrypt this" for a KMS-encrypted
   resource, including cross-account.
3. Stand up WAF/Shield/edge protection and prove it stops a real attack they
   launched.
4. Turn on the detection stack (CloudTrail → GuardDuty → Security Hub → Macie),
   trigger a real finding, and route it to an automated response.
5. Author SCPs, permission boundaries, and an Identity Center / ABAC model for
   multi-account governance.
6. Run a full incident-response cycle (detect → contain → eradicate → recover)
   against a real workload.
7. Map each of the above to the SCS-C02 exam domains.

---

## 2. Constraints & Environment

- **Lab environment:** learner's **personal AWS account**.
- **Cost discipline (hard requirement):** every lab is `terraform apply` at the
  start of a session and `terraform destroy` at the end. Each lab README ends
  with a **teardown checklist**. Step 0 of the path is a **billing alarm +
  budget** guardrail. Target total spend for the whole sprint: **< ~$15**.
- **Detection-service trials:** GuardDuty, Macie, Security Hub, and Detective
  are sequenced into a single **30-day free-trial window** (enabled once around
  D8, disabled at end of D9/D12) so the learner never pays for them.
- **Compute tier for the persistent workload:** **ECS Fargate** (no host
  patching, clean task-role IAM story, fast teardown). The EC2-only
  IMDS-metadata-exfil lab is adapted to **task-role credential theft via app
  SSRF** — same lesson, Fargate-appropriate primitive.
- **Infrastructure as code:** all labs are **Terraform** (matches repo
  convention in `aws_network_components/`, `aws_computing_*`). Console is used
  only for read-only inspection tours, never as the primary path.
- **No git commits by the assistant** — the learner handles all VCS.
- **No credentials in any file (hard requirement):** never write a real
  credential, secret, key, token, or account ID into any `.env`, `.tfvars`,
  `.yaml`/`.yml`, compose, or config file. All such values ship **empty or as
  placeholders** with a comment on how to fill them locally; use
  `*.tfvars.example` / `*.env.example` patterns and note the real file should be
  gitignored. This keeps the repo commit-safe (learner commits these paths).
- **Practice rule (repo standing preference):** every exercise ships with
  **hints + solution sketches**; every lab ships with **README + SOLUTION +
  teardown**.
- **Authorized-testing framing (hard requirement):** all offensive labs target
  **only the learner's own account and own deployed workload**. Every offensive
  lab README and `ANTIPATTERNS.md` states this explicitly.

---

## 3. Architecture: Two Organizing Principles

The entire path is built on two ideas that are the "top 1%" shortcut.

### Principle 1 — One engine, many doors

AWS access control is *one* policy evaluation engine with a fixed decision
order:

```
explicit Deny  →  Organizations SCP / RCP  →  resource-based policy
   →  identity-based policy  →  permission boundary  →  session policy
```

Beginners waste ~80% of their time learning each service's policy language as
if it were a separate skill (S3 bucket policy, KMS key policy, VPC endpoint
policy, Secrets resource policy…). It is **one engine attached at different
doors**. Day 1 teaches the engine deeply, and every later service is introduced
as "the same engine, new door." This is the single biggest time-saver and the
organizing thread of the whole path.

### Principle 2 — One persistent workload, attacked daily

Day 1 deploys a small but realistic **3-tier target workload**:

```
CloudFront  →  WAF  →  ALB  →  ECS Fargate app  →  S3 (data) + DB + Secrets Manager
```

Its Terraform lives in `labs/base/`. Every subsequent day **layers a module**
onto this same workload and follows a **break → harden** loop: the learner
attacks their own workload (bypass the WAF, exfiltrate past KMS, steal the task
role via SSRF, trigger a GuardDuty finding) and then writes the control that
stops it. Learning a service by *defeating it and then defending it* against
yourself produces durable intuition that reading docs cannot.

The final two days convert the workload into a full **incident-response
scenario** (attack day + defend day), forcing every service to work together.

---

## 4. Repository Layout

Mirrors the `cyber_security/` convention.

```
aws_security_components/
├── README.md                 # quickstart, account setup, billing guardrail (step 0), nav
├── ROADMAP.md                # 12-day overview + dependency graph + cert map summary
├── journal.md                # learner's running war-story / findings log
├── content/
│   ├── STRATEGY.md           # the "top 1%" strategy (engine-first, one-workload, break-to-learn)
│   ├── ANTIPATTERNS.md       # the mistakes that waste 80% of beginners' time
│   ├── GLOSSARY.md           # plain-English terms (matches LA/quantum/cyber style)
│   ├── CERT-MAP.md           # each day → SCS-C02 domain mapping (secondary goal)
│   ├── day01-iam-engine.md
│   ├── day02-advanced-identity.md
│   ├── day03-kms-foundations.md
│   ├── day04-kms-advanced-data-at-rest.md
│   ├── day05-secrets-and-certs.md
│   ├── day06-waf-edge.md
│   ├── day07-shield-network-layering.md
│   ├── day08-detection.md
│   ├── day09-response-automation.md
│   ├── day10-governance-multiaccount.md
│   ├── day11-ir-capstone-attack.md
│   └── day12-ir-capstone-defend.md
├── labs/
│   ├── base/                 # the persistent 3-tier workload (Terraform)
│   ├── day01/ … day12/       # each: README.md, SOLUTION.md, *.tf, teardown checklist
│   └── capstone/             # IR scenario scripts + runbook
└── docs/
    └── superpowers/
        ├── specs/2026-08-19-aws-security-mastery-design.md   # this file
        └── plans/                                            # writing-plans output
```

---

## 5. Day-by-Day Design

Each content day file follows the same skeleton:

- **Why this matters at work** (1 short para, concrete)
- **The engine lens** — which "door" of Principle 1 today attaches to
- **Core concepts** — taught with the persistent workload as the running example
- **Break → Harden lab** — pointer to `labs/dayNN/`
- **Exercises** — with hints + solution sketches
- **Anti-patterns for today** — cross-linked to `ANTIPATTERNS.md`
- **Cert corner** — SCS-C02 tie-in
- **Teardown reminder**

### D1 — The Engine + Target Deploy
IAM policy evaluation logic end-to-end (all six layers, with worked "why
allowed/denied" traces). Identity vs resource policies, principals, conditions.
Deploy `labs/base/` workload. First break: an over-broad policy the learner
tightens using Access Analyzer / policy simulator reasoning.
**Lab:** deploy workload; run 3 access-decision traces; fix one over-broad grant.

### D2 — Advanced Identity
Cross-account roles, `sts:AssumeRole`, the **confused-deputy** problem and
`ExternalId`, **permission boundaries**, **session policies**, IAM Access
Analyzer, ABAC preview. Break: privilege escalation via a mis-scoped
`iam:PassRole` / policy-attach path; harden with a boundary.
**Lab:** build a second "trusting" role, exploit a passrole escalation, block it.

### D3 — KMS Foundations
Key policies vs grants (and why the key policy is the root of trust), **envelope
encryption** hands-on (generate data key, encrypt/decrypt locally), AWS-managed
vs customer-managed keys, rotation, `kms:ViaService`. The central question:
"who can actually decrypt this?" traced through the engine.
**Lab:** create a CMK, encrypt S3 objects, prove/deny decrypt for two principals.

### D4 — KMS Advanced + Data at Rest
Cross-account KMS access, S3 / EBS / RDS encryption wiring, grant tokens,
condition keys for scoping decrypt. Break: an exfiltration attempt from the
workload that KMS + key policy should stop.
**Lab:** attempt cross-account/exfil decrypt; watch it fail; then mis-configure
the key policy so it *succeeds*, understand why, and re-lock it.

### D5 — Secrets & Certificates
Secrets Manager (rotation, resource policies, VPC endpoint access), Parameter
Store SecureString, when to use which, **secret sprawl** anti-pattern. ACM:
public cert issuance + DNS validation, attaching to ALB/CloudFront, Private CA
concept. Break: find a secret leaked into an env var / task definition.
**Lab:** move a hardcoded secret into Secrets Manager with rotation; issue + wire
an ACM cert to the ALB.

### D6 — Edge Protection I (WAF)
Web ACLs, managed rule groups, custom rules, rate-based rules, rule priority,
count vs block, logging. Break: launch SQLi/XSS at the workload, confirm it
lands, then write the rule that stops it and re-test.
**Lab:** attack app → observe hit → deploy WAF rule → confirm block → tune false positives.

### D7 — Edge Protection II + Network Layering
Shield (Standard vs Advanced), CloudFront security (OAC, signed URLs, geo),
**security groups vs NACLs vs WAF** — which layer does what, VPC endpoint
policies, `aws:SourceVpce`, `aws:SourceIp`. Break: reach a resource that should
be VPC-only; lock it with an endpoint policy.
**Lab:** layer SG/NACL/endpoint-policy controls; prove least-exposure with a
reachability test.

### D8 — Detection
CloudTrail as the foundation (management vs data events, log-file validation),
**GuardDuty** (enable, trigger a real finding — e.g. the SSRF task-role theft or
a mining sim), **Security Hub** aggregation + standards, **Macie** on the S3
bucket, **Detective** concept. Enter the single free-trial window here.
**Lab:** enable stack; trigger ≥2 real findings against own workload; read the
detection trail end-to-end in CloudTrail.

### D9 — Response Automation
EventBridge → Lambda / SSM Automation **auto-remediation**, AWS **Config** rules
+ conformance packs, the **detective → corrective control** pattern, quarantine
patterns (isolate a compromised task/role). Break: leave a finding; let the
automation remediate it.
**Lab:** wire GuardDuty finding → EventBridge → Lambda that auto-quarantines;
verify it fires. Tear down detection trial resources after.

### D10 — Governance & Multi-Account
Organizations **SCPs** (the deny that beats every identity policy), **IAM
Identity Center** (SSO, permission sets), Control Tower / landing-zone concepts,
tagging strategy + **ABAC** at scale, delegated admin. Mostly design + Terraform
`plan`-level for org features (single-account learner), with the engine lens
showing exactly where an SCP sits in the decision order.
**Lab:** author an SCP + permission boundary set; simulate the deny precedence;
design an ABAC tag scheme for the workload.

### D11 — IR Capstone: Attack
A scripted, realistic incident run against the learner's own workload: leaked
access key → reconnaissance → task-role theft via SSRF → attempted data exfil /
crypto-mining. The learner executes it and **captures the full detection trail**
(CloudTrail, GuardDuty, Security Hub, Config).
**Lab:** run the attack script; document every artifact each detection control
produced; build a timeline.

### D12 — IR Capstone: Defend + Gap-Fill
Using everything built, run **contain → eradicate → recover** on the D11
incident (revoke/rotate credentials, quarantine the task/role, close the
control gap that allowed it, restore). Then a **gap-fill + self-assessment**
against the SCS-C02 blueprint using `CERT-MAP.md`.
**Lab:** full IR runbook execution; final self-scored blueprint checklist;
complete teardown of all remaining resources.

---

## 6. Supporting Documents

- **STRATEGY.md** — the deliverable that answers the "unconventional strategy
  the top 1% use" ask: engine-first, one-persistent-workload, break-to-learn,
  Terraform-not-console, and *how to compress* (what to skip, what to over-index
  on). Written as durable guidance, not day-specific.
- **ANTIPATTERNS.md** — the explicit "mistakes that waste 80% of beginners'
  time," each with the corrective. Seed list:
  1. Learning each service's policy language as a separate skill (vs. one engine).
  2. Console-clicking instead of Terraform (nothing reproducible, nothing to diff).
  3. Never testing a **deny** — only ever confirming the happy path.
  4. Leaving detection off "until later" — you learn nothing about findings.
  5. Trusting default encryption without asking "who can decrypt?"
  6. `iam:PassRole` / wildcard actions as the silent escalation path.
  7. Treating WAF as a checkbox instead of tuning + testing it.
  8. Long-lived access keys instead of roles / short-lived creds.
  9. Ignoring the free-trial clock and getting surprise bills.
  10. Secret sprawl (env vars, task defs, code) instead of Secrets Manager.
  Includes the **authorized-testing** statement.
- **GLOSSARY.md** — plain-English, matches the LA/quantum/cyber glossary style.
- **CERT-MAP.md** — each day mapped to SCS-C02 domains for the secondary goal.
- **README.md** — quickstart, account prerequisites, **step-0 billing alarm +
  budget**, how to use the persistent workload, navigation.
- **ROADMAP.md** — 12-day overview, dependency graph, cert-map summary.
- **journal.md** — the learner's running war-story log (feeds the interview
  goal).

---

## 7. Testing & Verification

This is learning content, so "tests" are correctness + runnability checks:

- **Terraform validity:** every lab's `.tf` passes `terraform validate` and
  `terraform plan` against a real (learner) account; `apply`/`destroy` cycle is
  documented and clean.
- **Break-then-harden provability:** every offensive lab has a concrete,
  observable "it worked / it's now blocked" signal (an HTTP response, an
  AccessDenied, a GuardDuty finding ID). SOLUTION.md records expected output.
- **Cost teardown:** every lab README teardown checklist leaves zero billable
  resources; D12 includes a global sweep.
- **Exercise self-check:** every exercise has hints + a solution sketch so the
  learner can verify offline.
- **Engine-trace correctness:** D1/D2 decision traces are checked against the
  actual AWS policy simulator behavior.

---

## 8. Out of Scope

- Deep third-party / marketplace security tooling.
- Full Control Tower deployment (single-account learner) — concept + design only.
- Compliance-framework deep dives (PCI/HIPAA/FedRAMP) beyond how AWS controls map.
- Windows/AD-specific identity federation edge cases.
- Non-security AWS networking already covered in `aws_network_components/`.

---

## 9. Open Questions / Decisions Locked

- **Compute:** ECS Fargate — **locked**.
- **Duration:** 12 days — **locked** (learner accepted "no strict 5-day cap,
  pick reasonable duration").
- **Model for content writing:** to be decided after this spec (learner will be
  asked before the file-writing phase per standing preference).
- **Region:** default to a low-cost region the learner already uses; confirm at
  README step 0.

# AWS Security Mastery — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to author this path task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Each Day is an authoring task that produces one content file plus one break→harden lab (Terraform + README + SOLUTION). Do NOT run any `terraform apply`/`destroy` or touch a real AWS account during authoring — labs are *written* here; the learner runs them.
>
> **For the learner (once built):** Work the five beats in order every day — **apply the workload → learn through the engine lens → break→harden lab → exercises → journal + teardown.** Tear down at the end of every session (`terraform destroy`); it is a scheduled step, not an afterthought. Saving your work to git is entirely your own responsibility — nothing here commits on your behalf.

**Goal:** Build a 12-day, ~5–6 h/day AWS-security learning path in `aws_security_components/` that takes a comfortable-but-self-taught engineer to job-credible mastery of the AWS security service set — organized by domain, taught through one policy-evaluation engine and one persistent workload the learner breaks then hardens daily.

**Architecture:** Six cumulative domain phases — Identity (Days 1–2), Data Protection (Days 3–5), Edge & Network (Days 6–7), Detection & Response (Days 8–9), Governance (Day 10), IR Capstone (Days 11–12). Day 1 deploys one persistent 3-tier workload (CloudFront→WAF→ALB→ECS Fargate→S3+DB+Secrets) in `labs/base/`; every later day layers a Terraform module and runs a break→harden loop against that same workload. Days 11–12 convert it into a full incident-response attack/defend scenario.

**Tech Stack:** Terraform (all labs, IaC-first — console for read-only inspection only), AWS (IAM, STS, KMS, ACM, Secrets Manager, SSM Parameter Store, WAF, Shield, CloudFront, VPC endpoints, ECS Fargate, S3, CloudTrail, GuardDuty, Security Hub, Macie, Detective, EventBridge, Lambda, Config, Organizations SCPs, IAM Identity Center), AWS CLI + policy simulator, Markdown content (matches repo LA/quantum/cyber style).

**Spec:** `aws_security_components/docs/superpowers/specs/2026-08-19-aws-security-mastery-design.md`

## Global Constraints

- **No credentials in any file.** Never write a real credential, secret, key, token, or account ID into any `.env`, `.tfvars`, `.yaml`/`.yml`, compose, or config file. All such values ship **empty or as placeholders** with a fill-in comment. Ship `*.tfvars.example` / `*.env.example`; note the real file must be gitignored. Every lab includes a `.gitignore` covering `*.tfvars`, `.env`, `.terraform/`, `*.tfstate*`.
- **No commits by the author.** Nothing in this plan runs git on the learner's behalf; the learner handles all VCS.
- **Authorized testing only.** Every offensive lab targets the learner's own account and own deployed workload only. Each offensive lab README and `ANTIPATTERNS.md` state this explicitly.
- **Teardown every day.** Every lab README ends with a **teardown checklist** leaving zero billable resources; `terraform destroy` is the last beat. Target total sprint spend **< ~$15**.
- **Detection services in one trial window.** GuardDuty, Macie, Security Hub, Detective are enabled once around Day 8 and disabled by end of Day 9 (Day 12 sweeps any remainder) to stay inside a single 30-day free trial.
- **One engine, many doors.** Every service after Day 1 is framed through the IAM policy evaluation order: explicit Deny → SCP/RCP → resource-based policy → identity-based policy → permission boundary → session policy. Each day names which "door" it attaches to.
- **Break → Harden, provably.** Every lab has a concrete observable signal for both the break (attack lands) and the harden (attack now blocked) — an HTTP status, an `AccessDenied`, a finding ID. SOLUTION.md records expected output.
- **Exercises ship with hints + solution sketches.** Every content day ends with exercises the learner can self-check offline (repo standing rule).
- **Compute is ECS Fargate.** The metadata-exfil lesson is delivered as task-role credential theft via app SSRF, not EC2 IMDS.
- **Terraform, not console.** Console appears only as read-only inspection tours, never as the primary path.

## Project Layout

Built incrementally — this is the target end-state, not something to create all at once. Pre-flight creates the scaffold and supporting docs; each Day adds its `content/dayNN-*.md` and `labs/dayNN/`.

```
aws_security_components/
├── README.md                 # quickstart, account prereqs, STEP-0 billing alarm+budget, how to use the workload, nav
├── ROADMAP.md                # 12-day overview, phase/dependency graph, cert-map summary
├── journal.md                # learner's running war-story / findings log (seeded with a template entry)
├── .gitignore                # *.tfvars, .env, .terraform/, *.tfstate*
├── content/
│   ├── STRATEGY.md           # the "top 1%" strategy (engine-first, one-workload, break-to-learn, how to compress)
│   ├── ANTIPATTERNS.md       # the mistakes that waste 80% of beginners' time + authorized-testing statement
│   ├── GLOSSARY.md           # plain-English terms
│   ├── CERT-MAP.md           # each day → SCS-C02 domain mapping
│   └── dayNN-*.md            # 12 content files (skeleton below)
├── labs/
│   ├── base/                 # persistent 3-tier workload (Terraform): README + *.tf + variables + outputs + teardown
│   ├── dayNN/                # each: README.md, SOLUTION.md, *.tf (module layered on base), teardown checklist
│   └── capstone/             # IR scenario: attack script(s) + defend runbook
└── docs/superpowers/
    ├── specs/2026-08-19-aws-security-mastery-design.md
    └── plans/2026-08-19-aws-security-mastery-plan.md   # this file
```

## Content Day Skeleton (copy for every `content/dayNN-*.md`)

```markdown
# Day N — <Title>

## Why this matters at work
<1 short paragraph, concrete>

## The engine lens
<Which door of the evaluation order today attaches to, and why>

## Core concepts
<Taught with the labs/base workload as the running example; diagrams text/ASCII>

## Break → Harden lab
See `labs/dayNN/`. The break: <one line>. The harden: <one line>. Success signal: <one line>.

## Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>
2. ...

## Anti-patterns today
<2–3 bullets, each cross-linked to ANTIPATTERNS.md>

## Cert corner (SCS-C02)
<Which exam domain(s) this maps to, 2–3 bullets>

## Teardown
`cd labs/dayNN && terraform destroy` — confirm zero billable resources (checklist in the lab README).
```

## Lab Skeleton (copy for every `labs/dayNN/`)

```
labs/dayNN/
├── README.md        # objective, prereqs (base must be up), THE BREAK (steps+expected), THE HARDEN (steps+expected), teardown checklist, authorized-testing note (offensive labs)
├── SOLUTION.md      # expected outputs/finding IDs/AccessDenied text, and the fix rationale
├── main.tf          # module layered on labs/base (data sources reference base outputs)
├── variables.tf     # names only; no secrets; placeholder defaults
├── outputs.tf
└── terraform.tfvars.example   # placeholder values + fill-in comments (real .tfvars gitignored)
```

---

## Pre-flight: Scaffold, guardrails & supporting docs

### Pre-flight Task A: Scaffold, README, ROADMAP, journal, .gitignore

**Files:**
- Create: `aws_security_components/.gitignore`
- Create: `aws_security_components/README.md`
- Create: `aws_security_components/ROADMAP.md`
- Create: `aws_security_components/journal.md`
- Create: directory tree per Project Layout (empty `content/`, `labs/`)

- [ ] **Step 1: Create the directory scaffold.** `content/`, `labs/base/`, `labs/day01`…`labs/day12`, `labs/capstone/`, `docs/superpowers/{specs,plans}` (specs/plans already exist).
- [ ] **Step 2: Write `.gitignore`** covering `*.tfvars` (but NOT `*.tfvars.example`), `.env`, `.terraform/`, `*.tfstate`, `*.tfstate.*`, `.terraform.lock.hcl` optional, crash logs.
- [ ] **Step 3: Write `README.md`** with: one-paragraph pitch; the two spine principles (link STRATEGY.md); prerequisites (AWS account, AWS CLI configured, Terraform ≥1.6, a low-cost default region the learner chooses); **STEP 0 — billing guardrail**: create an AWS Budget + a CloudWatch billing alarm (give exact `aws budgets create-budget` CLI and a small Terraform snippet, values as placeholders); how the persistent workload works (`labs/base` up once per session, day modules layer on it); the daily five-beat loop; a **cost & teardown** section restating the <$15 target and the detection free-trial window; navigation table linking every day file and lab.
- [ ] **Step 4: Write `ROADMAP.md`** — the 12-day table (day, title, door, service focus, break→harden one-liner, est. hours), the six-phase grouping, a text dependency graph (base → all days; Day 8 enables trial → Day 9 uses it; Days 11–12 reuse everything), and a one-line-per-day SCS-C02 map summary (full detail in CERT-MAP.md).
- [ ] **Step 5: Seed `journal.md`** with the war-story template: date, day, "what I broke", "what stopped it", "the engine trace", "one thing for an interview". Include one filled example entry so the learner sees the bar.
- [ ] **Verify:** tree matches Project Layout; README STEP-0 gives runnable (placeholder-valued) budget commands; no real account ID or email anywhere.

### Pre-flight Task B: Supporting docs — STRATEGY, ANTIPATTERNS, GLOSSARY, CERT-MAP

**Files:**
- Create: `content/STRATEGY.md`, `content/ANTIPATTERNS.md`, `content/GLOSSARY.md`, `content/CERT-MAP.md`

- [ ] **Step 1: Write `STRATEGY.md`** — the deliverable answering "the unconventional strategy the top 1% use." Cover: (a) engine-first — learn the evaluation order once, then every service is a new door; (b) one persistent workload, attacked daily; (c) break-to-learn — defeat a control then defend it; (d) Terraform-not-console — reproducible, diffable, destroyable; (e) how to compress — what to over-index on (IAM evaluation, KMS "who can decrypt", detection→response wiring) and what to skip on a first pass (marketplace tooling, full Control Tower, compliance-framework minutiae); (f) how to keep it cheap. Durable guidance, not day-specific.
- [ ] **Step 2: Write `ANTIPATTERNS.md`** — the 10 seed anti-patterns from spec §6, each as: *the mistake → why it wastes time → the corrective*. Anti-patterns: (1) per-service policy language vs one engine; (2) console-clicking vs Terraform; (3) never testing a deny; (4) detection off "until later"; (5) trusting default encryption without "who can decrypt?"; (6) `iam:PassRole`/wildcards as silent escalation; (7) WAF as checkbox vs tuned+tested; (8) long-lived access keys vs roles/short-lived creds; (9) ignoring the free-trial clock → surprise bills; (10) secret sprawl. End with the **authorized-testing statement** (own account + own workload only) that offensive labs link to.
- [ ] **Step 3: Write `GLOSSARY.md`** — plain-English entries (match LA/quantum/cyber style) for at least: principal, resource vs identity policy, permission boundary, session policy, SCP, trust policy, assume-role, confused deputy, ExternalId, CMK vs AWS-managed key, key policy vs grant, envelope encryption, data key, `kms:ViaService`, Web ACL, managed rule group, rate-based rule, OAC, security group vs NACL, VPC endpoint policy, CloudTrail management vs data events, GuardDuty finding, Security Hub standard, Macie, Detective, EventBridge rule, Config rule, conformance pack, permission set, ABAC.
- [ ] **Step 4: Write `CERT-MAP.md`** — a table mapping each of the 6 SCS-C02 domains (Threat Detection & IR; Security Logging & Monitoring; Infrastructure Security; IAM; Data Protection; Management & Governance) to the days that cover it, with a self-scored checklist row per domain for the Day-12 gap-fill.
- [ ] **Verify:** STRATEGY explicitly names the two spine principles and the compression advice; ANTIPATTERNS has all 10 + authorized-testing note; every glossary term used in a day file exists here (cross-check at end of authoring).

### Pre-flight Task C: The persistent workload — `labs/base/`

**Files:**
- Create: `labs/base/README.md`, `labs/base/main.tf`, `labs/base/variables.tf`, `labs/base/outputs.tf`, `labs/base/terraform.tfvars.example`

**Produces (outputs later days consume):** `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `alb_arn`, `alb_dns_name`, `alb_listener_arn`, `cloudfront_distribution_id`, `ecs_cluster_arn`, `ecs_service_name`, `task_role_arn`, `task_execution_role_arn`, `app_bucket_name`, `app_bucket_arn`, `db_endpoint` (or a lightweight stand-in), `secret_arn`. Later day modules reference these via `terraform_remote_state` or documented data sources.

- [ ] **Step 1: Write `main.tf`** for a minimal but real 3-tier workload: a VPC (2 AZ, public+private subnets, one NAT or a NAT-free design noted for cost), an ALB in public subnets, an **ECS Fargate** service running a tiny public container image (e.g. an httpbin-like or a small app that exposes a URL-fetch endpoint so the Day-8/11 SSRF lab is possible — note the image choice), a CloudFront distribution in front of the ALB, an S3 bucket for "app data" (block public access ON by default), a Secrets Manager secret (value is a placeholder set outside Terraform — document the `aws secretsmanager put-secret-value` step; do NOT put a real value in tf), and a task role with **intentionally slightly-broad** starting permissions the learner tightens on Day 1. Keep the DB tier lightweight (a small RDS instance OR a documented stand-in table in S3/DynamoDB) — note the cost tradeoff and default to the cheapest that still teaches encryption-at-rest.
- [ ] **Step 2: Write `variables.tf`** — region, project name/prefix, image URI, instance sizes; placeholder defaults; NO secrets.
- [ ] **Step 3: Write `outputs.tf`** exposing the Produces list above.
- [ ] **Step 4: Write `terraform.tfvars.example`** with placeholder values and fill-in comments.
- [ ] **Step 5: Write `README.md`** — what the workload is (diagram), `terraform init/plan/apply`, how to set the secret value out-of-band, how to reach the app URL, the **teardown checklist**, and a cost note (what runs while up: ALB, Fargate, NAT/CloudFront). State the workload comes up once per session and day modules layer on it.
- [ ] **Verify:** `terraform validate` passes (author runs `terraform validate` only — no apply); outputs cover everything later days need; no secret value in any tf; `.tfvars.example` only.

---

## Phase 1 — Identity (Days 1–2)

### Day 1 — The engine + target deploy
**Door:** identity policy + resource policy (the whole order, taught end-to-end). **Focus:** IAM/STS, policy simulator, Access Analyzer.

- [ ] **Step 1: Write `content/day01-iam-engine.md`** covering: the full evaluation order with worked "why allowed / why denied" traces; identity vs resource-based policies; principals, actions, resources, conditions; the policy simulator and Access Analyzer as the tools that answer "will this be allowed?". Use the `labs/base` task role as the running example.
- [ ] **Step 2: Write `labs/day01/` lab.** Break: the base task role starts slightly over-broad — the learner demonstrates it can reach something it shouldn't (an `aws s3 ls` on an unintended bucket, or an `iam:` call). Harden: tighten to least privilege and re-prove the action is now `AccessDenied`. Include 3 policy-evaluation traces to run in the simulator. `main.tf` = a tightened policy the learner applies; SOLUTION.md records the exact `AccessDenied` messages and simulator verdicts.
- [ ] **Step 3: Write exercises** (≥3) with hints + solution sketches — e.g. "given policy X + SCP Y, is action Z allowed? explain the winning statement."
- [ ] **Step 4: Anti-patterns today** — #1 (one engine), #6 (PassRole/wildcards). Cross-link.
- [ ] **Step 5: Cert corner** — SCS-C02 IAM domain. **Teardown** reminder (base stays up across the sprint but day-module resources destroy).
- [ ] **Verify:** day file follows skeleton; lab has both break and harden signals; `terraform validate` on day01 module passes; exercises have solutions.

### Day 2 — Advanced identity
**Door:** trust policy + permission boundary + session policy. **Focus:** cross-account roles, STS, confused deputy, boundaries, Access Analyzer.

- [ ] **Step 1: Write `content/day02-advanced-identity.md`** — `sts:AssumeRole` and trust policies; the confused-deputy problem and `ExternalId`; permission boundaries (the ceiling) vs identity policies; session policies; ABAC preview (`aws:PrincipalTag`); Access Analyzer for external access.
- [ ] **Step 2: Write `labs/day02/` lab.** Break: a privilege-escalation path via mis-scoped `iam:PassRole` or a policy-attach permission (learner escalates their own low-priv role). Harden: apply a permission boundary that caps the escalation; re-prove blocked. `main.tf` builds a second "trusting" role + the boundary.
- [ ] **Step 3: Exercises** (≥3) w/ hints+solutions — include one "write the trust policy that prevents the confused deputy" with `ExternalId`.
- [ ] **Step 4: Anti-patterns** — #6, #8 (long-lived keys vs assume-role).
- [ ] **Step 5: Cert corner** — IAM domain (cross-account, federation edges noted as out-of-scope). **Teardown**.
- [ ] **Verify:** boundary demonstrably caps escalation in SOLUTION.md; `terraform validate` passes.

## Phase 2 — Data Protection (Days 3–5)

### Day 3 — KMS foundations
**Door:** key policy (the root of trust) as a resource policy. **Focus:** KMS keys, grants, envelope encryption, rotation.

- [ ] **Step 1: Write `content/day03-kms-foundations.md`** — key policy vs grant and why the key policy is the root of trust; AWS-managed vs customer-managed keys; **envelope encryption** walked through (generate data key → encrypt locally → store ciphertext + encrypted data key); rotation; the central question "who can actually decrypt this?" traced through the engine.
- [ ] **Step 2: Write `labs/day03/` lab.** Break/build: create a CMK, encrypt objects in the base S3 bucket; prove principal A can decrypt and principal B gets `AccessDenied`. Harden: fix the key policy so only intended principals decrypt. Include a CLI envelope-encryption demo (`generate-data-key`, `encrypt`, `decrypt`). SOLUTION.md records both outcomes.
- [ ] **Step 3: Exercises** (≥3) w/ hints+solutions — one "trace who can decrypt given this key policy + this identity policy."
- [ ] **Step 4: Anti-patterns** — #5 (trusting default encryption). 
- [ ] **Step 5: Cert corner** — Data Protection domain. **Teardown** (destroy the CMK-dependent module; schedule key deletion with a short window and note the cost/irreversibility).
- [ ] **Verify:** decrypt allowed/denied both shown; key deletion handled in teardown; `terraform validate` passes.

### Day 4 — KMS advanced + data at rest
**Door:** resource policy + condition keys (`kms:ViaService`, cross-account). **Focus:** cross-account KMS, S3/EBS/RDS encryption, grants.

- [ ] **Step 1: Write `content/day04-kms-advanced-data-at-rest.md`** — cross-account KMS access (key policy + grant + caller identity all three must line up); wiring KMS into S3/EBS/RDS; grant tokens; `kms:ViaService` and condition-key scoping of decrypt.
- [ ] **Step 2: Write `labs/day04/` lab.** Break: an exfiltration attempt from the workload that KMS + key policy *should* stop — then deliberately mis-configure the key policy so the exfil *succeeds*, understand exactly which statement opened it, and re-lock it. Success signal: decrypt succeeds under the broken policy, `AccessDenied` under the fixed one.
- [ ] **Step 3: Exercises** (≥3) w/ hints+solutions — one cross-account "make it work, then make it least-privilege."
- [ ] **Step 4: Anti-patterns** — #5, and a note on over-broad key policies.
- [ ] **Step 5: Cert corner** — Data Protection. **Teardown**.
- [ ] **Verify:** the "broken then fixed" contrast is explicit with both outputs; `terraform validate` passes.

### Day 5 — Secrets & certificates
**Door:** resource policy (secret policy) + service integration. **Focus:** Secrets Manager, Parameter Store, ACM.

- [ ] **Step 1: Write `content/day05-secrets-and-certs.md`** — Secrets Manager (rotation, resource policies, VPC-endpoint access), Parameter Store SecureString, when to use which, **secret sprawl** anti-pattern; ACM public cert issuance + DNS validation, attaching to ALB/CloudFront, Private CA concept.
- [ ] **Step 2: Write `labs/day05/` lab.** Break: find a secret leaked into a task-definition env var / plaintext (planted in a controlled way — placeholder, never a real secret). Harden: move it into Secrets Manager with rotation and reference it from the task; issue an ACM cert and wire it to the ALB listener (HTTP→HTTPS). Signal: app served over HTTPS with a valid cert; secret no longer in the task def.
- [ ] **Step 3: Exercises** (≥3) w/ hints+solutions.
- [ ] **Step 4: Anti-patterns** — #10 (secret sprawl), #2 (reproducibility).
- [ ] **Step 5: Cert corner** — Data Protection + Infrastructure Security. **Teardown** (note ACM public certs are free; delete the DNS validation records).
- [ ] **Verify:** no real secret anywhere; HTTPS wiring shown; `terraform validate` passes.

## Phase 3 — Edge & Network (Days 6–7)

### Day 6 — Edge protection I (WAF)
**Door:** request-layer control in front of the engine. **Focus:** WAF Web ACLs, managed + custom rules, rate limiting.

- [ ] **Step 1: Write `content/day06-waf-edge.md`** — Web ACLs, managed rule groups, custom rules, rate-based rules, rule priority, count vs block, WAF logging to CloudWatch/S3.
- [ ] **Step 2: Write `labs/day06/` lab (offensive — authorized-testing note).** Break: launch SQLi/XSS payloads at the base app, confirm they land (HTTP 200 / reflected). Harden: attach a Web ACL with the managed rule group + a rate-based rule; re-test → HTTP 403. Then tune one false positive. Signal: 200→403 on the attack, legit traffic still 200.
- [ ] **Step 3: Exercises** (≥3) w/ hints+solutions — one "write a rate-based rule for path /login."
- [ ] **Step 4: Anti-patterns** — #7 (WAF as checkbox), #3 (never testing a deny).
- [ ] **Step 5: Cert corner** — Infrastructure Security. **Teardown** (WAF has hourly + request cost — destroy same day).
- [ ] **Verify:** offensive note present; 200→403 contrast in SOLUTION.md; `terraform validate` passes.

### Day 7 — Edge protection II + network layering
**Door:** condition keys (`aws:SourceVpce`, `aws:SourceIp`) + network controls. **Focus:** Shield, CloudFront security, SG vs NACL vs WAF, VPC endpoint policies.

- [ ] **Step 1: Write `content/day07-shield-network-layering.md`** — Shield Standard vs Advanced; CloudFront security (OAC, signed URLs, geo restriction); the "which layer does what" map for security groups vs NACLs vs WAF; VPC endpoint policies and `aws:SourceVpce`.
- [ ] **Step 2: Write `labs/day07/` lab.** Break: reach an S3/Secrets resource that should be VPC-only from outside the VPC. Harden: add a VPC endpoint + endpoint policy + bucket-policy condition (`aws:SourceVpce`) so only in-VPC access works; layer SG/NACL for least exposure. Signal: access from outside → `AccessDenied`; from in-VPC → success; a reachability test proves least exposure.
- [ ] **Step 3: Exercises** (≥3) w/ hints+solutions — one "SG vs NACL: which blocks this and why."
- [ ] **Step 4: Anti-patterns** — #3, and confusing WAF/SG/NACL responsibilities.
- [ ] **Step 5: Cert corner** — Infrastructure Security. **Teardown**.
- [ ] **Verify:** in-VPC vs out contrast shown; `terraform validate` passes.

## Phase 4 — Detection & Response (Days 8–9)

### Day 8 — Detection
**Door:** logging/observation layer (reads the engine's decisions). **Focus:** CloudTrail, GuardDuty, Security Hub, Macie, Detective. **Enters the single free-trial window.**

- [ ] **Step 1: Write `content/day08-detection.md`** — CloudTrail as the foundation (management vs data events, log-file validation); GuardDuty (what it detects, how to trigger a real finding); Security Hub aggregation + standards; Macie on the S3 bucket; Detective concept. **Prominent free-trial-clock note** (enable now, plan to disable by end of Day 9).
- [ ] **Step 2: Write `labs/day08/` lab (offensive — authorized-testing note).** Enable CloudTrail + GuardDuty + Security Hub + Macie via Terraform. Break: trigger ≥2 real findings against the learner's own workload — e.g. task-role credential theft via the app's SSRF endpoint used from outside, plus a GuardDuty test/finding (document GuardDuty sample-findings as a fallback if a natural trigger is slow). Harden step is Day 9. Signal: ≥2 findings visible with IDs; the CloudTrail trail of the SSRF read end-to-end.
- [ ] **Step 3: Exercises** (≥3) w/ hints+solutions — one "given this CloudTrail event, what happened and who did it?"
- [ ] **Step 4: Anti-patterns** — #4 (detection off), #9 (free-trial clock).
- [ ] **Step 5: Cert corner** — Threat Detection & IR + Logging & Monitoring. **Teardown note:** leave detection ON overnight into Day 9 (only day the base+detection stay up); everything else destroys.
- [ ] **Verify:** free-trial note prominent; SSRF trigger tied to the base app's fetch endpoint; finding IDs captured in SOLUTION.md; `terraform validate` passes.

### Day 9 — Response automation
**Door:** corrective controls wired to detective signals. **Focus:** EventBridge, Lambda/SSM, Config.

- [ ] **Step 1: Write `content/day09-response-automation.md`** — EventBridge rules on GuardDuty/Config findings → Lambda/SSM Automation auto-remediation; AWS Config rules + conformance packs; the detective→corrective pattern; quarantine patterns (isolate a compromised task/role, revoke sessions).
- [ ] **Step 2: Write `labs/day09/` lab.** Harden (closes Day 8's break): wire GuardDuty finding → EventBridge → a Lambda that auto-quarantines (e.g. attaches a deny-all boundary to the compromised role or revokes its sessions); add a Config rule that flags a public bucket and a remediation. Signal: leave a finding/violation → automation fires → the offending principal/resource is demonstrably contained.
- [ ] **Step 3: Exercises** (≥3) w/ hints+solutions — one "write the EventBridge pattern that matches only high-severity GuardDuty findings."
- [ ] **Step 4: Anti-patterns** — #4, and alert-without-action.
- [ ] **Step 5: Cert corner** — Threat Detection & IR + Management & Governance. **Teardown — CRITICAL:** disable GuardDuty/Security Hub/Macie/Detective and destroy detection resources at end of day (end of the trial window); confirm in the checklist.
- [ ] **Verify:** automation fires with an observable containment result; detection-service disable is an explicit checklist item; `terraform validate` passes.

## Phase 5 — Governance (Day 10)

### Day 10 — Governance & multi-account
**Door:** SCP — the deny that beats every identity policy (top of the order). **Focus:** Organizations SCPs, IAM Identity Center, ABAC, Control Tower concept.

- [ ] **Step 1: Write `content/day10-governance-multiaccount.md`** — Organizations SCPs and exactly where they sit in the evaluation order; IAM Identity Center (SSO, permission sets); Control Tower / landing-zone concepts; tagging strategy + ABAC at scale; delegated admin. Note single-account learners do org features at `plan` level + design.
- [ ] **Step 2: Write `labs/day10/` lab.** Mostly design + `terraform plan`-level: author an SCP + a permission-boundary set; use the policy simulator / a written trace to show the SCP deny wins over an allow; design an ABAC tag scheme for the base workload and apply the tags. Signal: a written+simulated proof that the SCP-denied action is blocked regardless of identity policy; tags applied and an ABAC policy that keys on them.
- [ ] **Step 3: Exercises** (≥3) w/ hints+solutions — one "write an SCP that denies disabling CloudTrail org-wide."
- [ ] **Step 4: Anti-patterns** — #1 (SCP is the same engine, top door), governance-as-afterthought.
- [ ] **Step 5: Cert corner** — Management & Governance + IAM. **Teardown** (tags/roles cheap; destroy any created roles).
- [ ] **Verify:** SCP precedence proven (simulated or traced); ABAC tags + policy shown; `terraform validate`/`plan` passes.

## Phase 6 — IR Capstone (Days 11–12)

### Day 11 — IR capstone: attack
**Focus:** run a realistic incident end-to-end against own workload; capture the detection trail. **Note:** re-enable detection stack for the capstone (document the trial-window/cost implication; keep it to Days 11–12 and sweep on Day 12).

- [ ] **Step 1: Write `content/day11-ir-capstone-attack.md`** — the incident storyline: leaked access key → recon → task-role theft via SSRF → attempted data exfil / crypto-mining. Frame it as authorized self-testing.
- [ ] **Step 2: Write `labs/capstone/` attack assets + `labs/day11/README.md`.** A scripted attack (shell/CLI steps, placeholders for any identifiers) the learner runs against their own workload; instructions to capture every artifact each detection control produces (CloudTrail events, GuardDuty finding IDs, Security Hub, Config). Signal: a completed attack timeline with artifact references.
- [ ] **Step 3: Exercises** (≥2) w/ hints+solutions — "from these artifacts alone, reconstruct the attacker's path."
- [ ] **Step 4: Anti-patterns** — recap #3, #4; authorized-testing statement repeated.
- [ ] **Step 5: Cert corner** — Threat Detection & IR. **Teardown note:** detection stays up into Day 12; nothing else lingers.
- [ ] **Verify:** attack script uses only placeholders; every step maps to an expected detection artifact in SOLUTION.md; authorized-testing note present.

### Day 12 — IR capstone: defend + gap-fill
**Focus:** contain→eradicate→recover; final SCS-C02 self-assessment; full sweep.

- [ ] **Step 1: Write `content/day12-ir-capstone-defend.md`** — the IR runbook: contain (revoke/rotate creds, quarantine the task/role), eradicate (close the control gap that allowed it — tie back to the exact engine door), recover (restore), and the retro. Then the gap-fill against `CERT-MAP.md`.
- [ ] **Step 2: Write `labs/day12/` + `labs/capstone/` defend runbook.** The learner executes contain→eradicate→recover on the Day-11 incident using controls built across the path; then runs the CERT-MAP self-scored blueprint checklist. Signal: the attacker path from Day 11 is now blocked end-to-end (re-run a step → blocked); checklist completed.
- [ ] **Step 3: Exercises** (≥2) w/ hints+solutions — "which single control, added earlier, would have prevented the whole incident? justify via the engine order."
- [ ] **Step 4: Anti-patterns** — recap the highest-leverage ones.
- [ ] **Step 5: Cert corner** — all six domains (the self-assessment). **Teardown — FINAL SWEEP:** `terraform destroy` on base + every day module; disable/confirm-off all detection services; delete CMKs (scheduled); a global checklist confirming zero billable resources across regions.
- [ ] **Verify:** re-running a Day-11 attack step is now blocked; final sweep checklist is exhaustive and includes detection-service disable + CMK deletion + cross-region check.

---

## Self-Review

**Spec coverage:** Every spec §5 day (D1–D12) has a Day task; §6 supporting docs map to Pre-flight Tasks A/B; the persistent workload (§3) is Pre-flight Task C; testing/verification (§7) is folded into each task's Verify step and the Day-12 final sweep; constraints (§2) are the Global Constraints block. Out-of-scope (§8) items are excluded (no full Control Tower deploy, no compliance deep dives). No gaps.

**Placeholder scan:** No "TBD/TODO/implement later." Each Day names concrete files, the specific break, the specific harden, the success signal, the anti-patterns, and the cert domain. Where a value is genuinely environment-specific (region, account ID, image URI, secret value) the plan requires a *placeholder* — that is the no-credentials constraint, not a plan gap.

**Type consistency:** `labs/base` Produces list (vpc_id, subnet ids, alb_listener_arn, task_role_arn, app_bucket_name/arn, secret_arn, ecs_service_name, cloudfront_distribution_id, db_endpoint) is the single source later days consume; Day tasks reference only those names. Detection stack is enabled Day 8, disabled Day 9, re-enabled Days 11–12, swept Day 12 — consistent across all mentions. Evaluation order is stated identically everywhere (explicit Deny → SCP/RCP → resource → identity → boundary → session), per AWS's documented single-account evaluation logic.

---

## Execution Handoff

Plan complete. Because every Day authors content + labs (not docs-only), the content-writing phase should run on the model the learner chooses — per standing preference, **ask before switching to Sonnet** before executing any Day or Pre-flight Task that writes content/lab/Terraform files.

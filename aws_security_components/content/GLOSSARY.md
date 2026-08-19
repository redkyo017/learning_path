# Glossary — AWS Security Mastery

*Lookup for catch-up: scan for the term you forgot — this is not meant
to be read in order. Full treatments live in the day files named in
each entry.*

→ [Jump index](#jump-index)

## Acronyms at a glance

| Acronym | Stands for | One-line meaning |
|---|---|---|
| IAM | Identity and Access Management | AWS's identity-policy system — users, roles, groups, policies |
| STS | Security Token Service | issues the short-lived credentials behind `AssumeRole` |
| SCP | Service Control Policy | an Organizations-level guardrail that can only remove permissions, never grant them |
| CMK | Customer Managed Key | a KMS key you create and control the policy on, as opposed to an AWS-managed key |
| KMS | Key Management Service | AWS's managed service for creating and controlling encryption keys |
| ARN | Amazon Resource Name | the globally unique string identifying a specific AWS resource |
| WAF | Web Application Firewall | inspects and filters HTTP(S) requests before they reach your app |
| ABAC | Attribute-Based Access Control | grants access based on matching tags/attributes rather than naming resources individually |
| NACL | Network Access Control List | a stateless, subnet-level allow/deny list |
| OAC | Origin Access Control | the mechanism that lets CloudFront alone read a private S3 origin |
| IR | Incident Response | the contain → eradicate → recover discipline this path's capstone runs end to end |
| ASFF | AWS Security Finding Format | the normalized schema Security Hub converts every finding into, regardless of which service found it |
| SSRF | Server-Side Request Forgery | a bug that tricks a server into fetching an attacker-chosen URL on its own behalf |
| OU | Organizational Unit | a grouping of accounts inside an AWS Organization that guardrails like SCPs apply to as a whole |

## Jump index

[A](#a) · [B](#b) · [C](#c) · [D](#d) · [E](#e) · [F](#f) · [G](#g) · [I](#i) · [K](#k) · [L](#l) · [M](#m) · [N](#n) · [O](#o) · [P](#p) · [R](#r) · [S](#s) · [T](#t) · [V](#v) · [W](#w)

## A

**ABAC (Attribute-Based Access Control)** — An access model where a policy grants permissions based on matching *tags* between the principal and the resource (e.g. "allow if the caller's `project` tag equals the resource's `project` tag") instead of naming every resource explicitly. It scales far better than resource-by-resource IAM as an account grows, because adding a new resource with the right tag is enough — no policy edit required. (see Day 10)

**Account Factory** — A Control Tower feature that provisions new, pre-baked AWS accounts from a standard template (baseline SCP guardrails, logging, network setup already applied) instead of creating accounts by hand one at a time. It's the piece of Control Tower that makes "spin up a fresh, compliant account" a self-service, few-minutes operation rather than a manual checklist. (see Day 10)

**ACM DNS validation** — The standard way ACM proves you control a domain before issuing a public certificate: ACM hands you a CNAME record to create in your DNS zone, and once it can resolve that record it issues the certificate and keeps it auto-renewed for as long as the record stays in place. It requires an actual domain you control — there's no way to DNS-validate a domain you don't own. (see Day 5)

**ACM Private CA** — A paid AWS Certificate Manager feature that lets you run your own private certificate authority, issuing certificates trusted only within your own infrastructure (internal service-to-service TLS) without any public domain validation. It bills a flat rate (roughly $400/month) regardless of how many certificates you issue, which is why it's reserved for organizations with enough internal-PKI volume to justify the cost, not for a personal lab. (see Day 5)

**AssumeRole** — The STS API call that exchanges a principal's existing identity for a temporary set of credentials scoped to a different IAM role. It's the mechanism behind almost every cross-account and cross-service access pattern in AWS: the caller never gets the target role's long-lived secret, only a short-lived credential set tied to that role's permissions. (see Day 2)

## B

**break-glass access** — A deliberately narrow, temporary override — typically an explicit-Deny policy attached directly via the CLI during an active incident — used when a fix can't wait for a normal change-management cycle like a Terraform plan/apply. It's meant to be removed the moment the incident is contained and replaced by the same fix made permanent through your normal infrastructure-as-code path; leaving it in place indefinitely just turns an emergency measure into undocumented, untracked configuration. (see Day 12)

## C

**certificate import vs. issuance** — ACM can either *issue* a certificate itself (requesting one and proving domain control, typically via DNS validation) or *import* a certificate you generated elsewhere — a self-signed cert, or one from an external CA — by supplying its private key and certificate body directly. Importing skips domain validation entirely, which is useful for a lab or an internal cert, but an imported certificate doesn't get ACM's automatic renewal — you're responsible for tracking its expiry and re-importing it yourself. (see Day 5)

**CloudTrail management events vs. data events** — CloudTrail logs two tiers of activity. *Management events* record control-plane actions — creating a role, changing a bucket policy, launching an instance — and are logged by default at no extra cost. *Data events* record data-plane activity inside a resource — an individual S3 `GetObject`, a Lambda `Invoke` — and must be turned on explicitly, at a per-event cost, because the volume is far higher. Knowing which tier you need before an incident (not during one) is the difference between having the log and not. (see Day 8)

**CMK (Customer Managed Key) vs. AWS-managed key** — Both are KMS keys, but a **CMK** is one *you* create, and you fully control its key policy, rotation schedule, and (if you choose) its deletion. An **AWS-managed key** (named `aws/service` in the console) is created automatically by an integrating service, and you can view but not edit its policy or control its rotation — AWS manages both. Use a CMK whenever you need to answer "who specifically can decrypt this" yourself; an AWS-managed key answers that question with "whatever that service's fixed policy says." (see Day 3)

**Confused deputy** — A vulnerability pattern where a trusted, more-privileged service is tricked into performing an action on an attacker's behalf, because the service was granted access based on identity alone and not on *which specific request* it should be allowed to act for. The classic fix is the `sts:ExternalId` condition (see below) on a trust policy. (see Day 2)

**Config rule** — An AWS Config rule that continuously (or on a schedule) evaluates whether a resource's configuration complies with a condition you define — e.g. "flag any S3 bucket that isn't private." Rules can be paired with a remediation action, so a non-compliant finding doesn't just sit there, it triggers a fix. (see Day 9)

**Conformance pack** — A packaged, deployable collection of AWS Config rules (plus optional remediation actions) representing a common compliance posture, deployed as one unit instead of one rule at a time. It's the "many Config rules bundled together" answer to "how do I not hand-wire 40 individual rules." (see Day 9)

**Control Tower / landing zone** — Control Tower is an AWS service that automates the standard multi-account setup pattern: a **landing zone** consisting of a dedicated log-archive account, a dedicated audit/security account, baseline SCP guardrails pre-attached across every OU, and an **Account Factory** for provisioning new accounts on a template. It's the packaged, automated version of governance patterns (SCPs, centralized logging, delegated administration) you can also build by hand in a single-account setup. (see Day 10)

## D

**Data key** — The actual symmetric key that encrypts your data in an envelope-encryption scheme. KMS generates it, hands you both the plaintext and an encrypted copy, and you keep only the encrypted copy at rest — decrypting it later requires calling back to KMS. See **envelope encryption** for the full pattern. (see Day 3)

**delegated administration** — A mechanism that lets the AWS Organizations management account grant one specific member account administrative rights over a particular service (GuardDuty, Security Hub, Config, Macie) across the entire organization, without granting that account the management account's own root-level control over Organizations itself. It's how a security team can see and manage findings org-wide without also being able to dissolve or restructure the organization. (see Day 10)

**deny-list vs. allow-list SCP strategy** — Two ways to write an SCP guardrail. A **deny-list** keeps the AWS-managed `FullAWSAccess` Allow-everything SCP attached and adds targeted `Deny` statements for specific dangerous actions — low friction, easy to reason about one guardrail at a time, and the more common real-world choice. An **allow-list** removes `FullAWSAccess` and attaches an SCP that only `Allow`s an approved action set — a much stronger ceiling, but a much higher chance of an unexpected `AccessDenied` on something a team actually needed, so it's usually reserved for tightly scoped OUs like a locked-down sandbox. (see Day 10)

**Detective** — An AWS security service that ingests VPC Flow Logs, CloudTrail, and GuardDuty findings, then builds a visual, queryable graph of resource behavior over time, purpose-built for answering "how did this happen and what else did it touch" during an investigation, rather than for generating the original alert. (see Day 8)

## E

**ECS task credentials endpoint (`AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`)** — The mechanism an ECS/Fargate task uses to fetch its task role's temporary credentials: a fixed link-local address (`169.254.170.2`) plus a per-task, randomly generated path stored in the `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI` environment variable. Unlike EC2's older, guessable instance-metadata credential path, this endpoint's path isn't enumerable from outside the task — an attacker still needs some other leak (a debug endpoint, an error message, a second foothold) to learn it before an SSRF bug can be used to steal the credentials it returns. (see Day 11)

**Envelope encryption** — The standard pattern for encrypting data larger or more frequent than KMS's direct `Encrypt` API is meant for: KMS generates a one-time **data key**, you use that data key locally to encrypt the actual data (fast, no API call per byte), then you ask KMS to encrypt the data key itself and store only that encrypted copy alongside the data. Decrypting later means asking KMS to decrypt the small data key, then using it locally — KMS never sees or handles your bulk data directly. (see Day 3)

**EventBridge rule** — A rule that matches an incoming event against a pattern you define — e.g. "any GuardDuty finding of severity High" or "any Config non-compliance event for this resource type" — and routes matching events to one or more targets, such as a Lambda function or an SSM Automation document. It's the wiring between a detective signal and an automated corrective action: Day 9's auto-remediation (a compromised role getting quarantined the moment Day 8's finding fires) is one EventBridge rule doing exactly this. (see Day 9)

**explicit vs. implicit deny** — An **explicit deny** is a `Deny` statement that actually matches the principal/action/resource/condition of a request — it's checked first, in any policy, at any layer, and nothing downstream can override it. An **implicit deny** is simply the absence of any matching `Allow` anywhere in the evaluation — IAM's default-deny posture — and it carries no special priority; it just means nothing ever said yes. The distinction matters because a permission boundary or session policy that never mentions an action produces an implicit deny with zero `Deny` statements written anywhere, while retrofitting an explicit deny is the one technique guaranteed to win over any `Allow`, however it's structured. (see Day 1)

**ExternalId** — A caller-supplied string that a trust policy can require via a condition key (`sts:ExternalId`) on `AssumeRole`, specifically to close the confused-deputy gap in cross-account role assumption: without it, any customer of a third-party service using the same ARN could accidentally (or intentionally) trigger an assume into a role meant for a different customer entirely. It isn't a secret in the cryptographic sense — its job is to force a caller to prove they know a specific token tied to *this* relationship. (see Day 2)

## F

**five whys** — A root-cause-analysis technique used in an incident retro: starting from the immediate symptom, ask "why did that happen" and use the answer as the next question's starting point, repeating roughly five times until you reach a systemic cause rather than stopping at the first proximate one. It's what turns "stolen credentials did damage" into "the identity policy was broader than the app actually needed, and the fix that narrowed it once didn't survive because it wasn't made permanent." (see Day 12)

**FullAWSAccess** — The AWS-managed Service Control Policy attached to every account in an Organization by default, consisting of a single `Allow *` statement on every action. It's the starting ceiling every additional SCP narrows from; a deny-list strategy leaves it in place and adds `Deny` statements on top, while an allow-list strategy removes it entirely and replaces it with a narrower explicit `Allow` set. (see Day 10)

## G

**grant token** — A short-lived token returned by KMS's `CreateGrant` call that you can pass into an immediately following `Decrypt`/`Encrypt` call to prove a grant exists even before it has fully propagated. It exists purely to sidestep `CreateGrant`'s eventual-consistency window — without it, a workflow that creates a grant and immediately tries to use it can hit a flaky `AccessDenied` that "fixes itself" on retry a moment later. (see Day 4)

**GuardDuty finding** — A single detected-threat record GuardDuty emits when its threat-intelligence and anomaly-detection models flag activity — e.g. an EC2 instance querying a known-malicious IP, or API calls consistent with credential compromise. Each finding has a type, a severity, and enough detail to drive an automated response; it's the unit of signal that Day 9's EventBridge → Lambda pipeline reacts to. (see Day 8)

**GuardDuty sample findings** — Synthetic, clearly-labeled finding records that GuardDuty's `create-sample-findings` API generates on demand for every finding type the service supports, without needing the real anomalous activity to actually occur. They're the reliable fallback for testing a detection-response pipeline (a rule, a Lambda, a runbook) when triggering a genuine finding would require an anomaly to build up real baseline history first, which can take minutes to hours. (see Day 8)

## I

**IAM Access Analyzer** — A continuous auditor of your account's resource-based policies (bucket policies, key policies, role trust policies) that flags any of them granting access to a principal outside your trust zone — another account, the public internet, or an unintended part of your organization. It also has a policy-generation feature that can draft a least-privilege identity policy from a principal's observed CloudTrail activity. (see Day 1, Day 2)

**IAM Identity Center** — The centralized successor to AWS SSO for giving humans access across many accounts: a user signs in once, and an admin assigns them a **permission set** against specific accounts, which Identity Center provisions under the hood as an actual IAM role in each target account. It replaces "one IAM user per account per person" with one identity and one set of credentials per human, managed centrally. (see Day 10)

**IAM policy simulator** — A tool (`aws iam simulate-principal-policy` / `simulate-custom-policy`) that evaluates whether a given principal, action, and resource combination would be allowed, without making the real API call or needing live credentials for the principal being tested. Its important limitation: it only evaluates identity-based policies and permission boundaries — it does not evaluate Organizations SCPs/RCPs, and it doesn't check resource-based policies unless you explicitly supply one — so an `allowed` verdict from the simulator is necessary but not sufficient on its own. (see Day 1)

**iam:PassRole** — The IAM action that lets a principal hand a specific IAM role to an AWS service (for example, specifying which role an ECS task or a Lambda function should run as). Granted broadly — wildcarded on `Resource: "*"` — it's one of the most common real-world privilege-escalation paths, because it looks completely benign in a policy review until you notice which role it can be paired with; a principal that can pass a highly privileged role to a service it also controls can effectively borrow that role's permissions. (see Day 2)

**Identity policy** — A policy attached directly to a principal (a user, group, or role) that grants that principal permissions. It's checked after an explicit deny, SCP/RCP, and any resource policy have all had their say, but *before* the permission boundary and session policy — an identity policy is the door that actually grants permissions; the two doors that follow it can only cap what it already granted, never add to it. Contrast with **resource policy**. (see Day 1)

**InstanceCredentialExfiltration (GuardDuty finding family)** — A GuardDuty finding type (`UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`, and its InstanceCredentialExfiltration variants) that fires when a role's temporary credentials — normally used only from inside the AWS network, on an EC2 instance or ECS task — are suddenly used from an external IP address. It's the signature GuardDuty produces when stolen task/instance-role credentials get replayed from outside AWS, such as after an SSRF-driven credential theft. (see Day 11)

## K

**Key policy vs. grant** — A KMS **key policy** is the resource policy attached to the key itself — the root document that says who can administer or use the key at all; every other permission mechanism for that key (IAM identity policies, grants) operates *within* what the key policy allows. A **grant** is a narrower, often temporary and programmatically created delegation of specific key permissions to a specific principal — commonly used by AWS services that need to use your key on your behalf without you editing the key policy each time. Read the key policy first; grants are additive permissions layered on top of it, never a way around it. (see Day 3)

**kms:CallerAccount** — A KMS condition key that scopes a key-policy (or identity-policy) statement so it only matches requests from callers in one specific AWS account. It's useful in a key policy meant to serve several trusted accounts with different permissions each, without needing a separate statement keyed on individual principal ARNs. (see Day 4)

**kms:EncryptionContext** — A KMS condition key (`kms:EncryptionContext:<key>`) that scopes a statement so it only matches requests carrying a specific encryption-context key/value pair, binding an allow statement or grant to *which logical dataset* is being encrypted or decrypted, not just which principal is asking. It follows the same mental model as `kms:ViaService`: the identity side answers "who," this condition answers "for exactly which data," and both have to say yes. (see Day 4)

**kms:ViaService** — A condition key restricting a KMS permission so it only applies when the KMS request arrives *via* a specific AWS service (e.g. `s3.us-east-1.amazonaws.com`), rather than from a direct KMS API call. It's how you can safely allow "S3 may use this key to encrypt objects on my behalf" without also allowing "anyone with this permission may call KMS directly and decrypt the key material outside of S3's use case." (see Day 4)

## L

**log file validation** — A CloudTrail feature (`enable_log_file_validation = true`) that writes a cryptographic digest file alongside each batch of log files, letting you later prove a given log file wasn't altered or deleted after it was written. It costs nothing extra and turns "we have logs" into "we have logs an attacker or a bad actor with console access couldn't have quietly edited" — exactly the kind of control an auditor or an incident write-up will ask you to point to. (see Day 8)

## M

**Macie** — A managed data-security service that uses machine learning and pattern matching to discover sensitive data (PII, credentials, financial data) in S3 and flag buckets or objects that expose it inappropriately. It answers "do I even have sensitive data sitting somewhere I forgot about," which is a different question from GuardDuty's "is something actively attacking me." (see Day 8)

**Macie classification job** — A run of Macie's machine-learning and pattern-matching classifiers against a scoped set of S3 objects (a one-time job against a single bucket, or a recurring job across many), flagging PII, credentials, financial data, and bucket-level posture issues it finds. Scoping a job to one bucket and running it once is the cost-disciplined way to use it; a recurring job scanning every bucket in the account burns through cost and noise for little extra teaching or security benefit in a small environment. (see Day 8)

**Managed rule group** — A pre-built, AWS- or vendor-maintained bundle of WAF rules targeting a known threat class (SQL injection, known bad inputs, common CVEs) that you attach to a Web ACL as a unit instead of writing each rule yourself. Attaching one is a starting point, not a finish line — see [`ANTIPATTERNS.md`](ANTIPATTERNS.md) #7 on why it still needs tuning and testing. (see Day 6)

**management account** — The root account of an AWS Organization, where Organizations itself is administered (billing, member-account creation, SCPs) — deliberately never the account where actual workloads run. Keeping workloads out of the management account limits the blast radius if that account's own credentials are ever compromised, since it sits above every guardrail it can apply to everyone else. (see Day 10)

## N

**NACL — see "Security group vs. NACL."**

**NotResource** — The inverse of a policy statement's `Resource` element: instead of naming which resources the statement applies to, `NotResource` names which resources it applies to *everything except*. It's most useful for a `Deny` statement meant to block an action almost everywhere while carving out a small, explicitly-named exception. (see Day 1)

## O

**OAC (Origin Access Control)** — The current mechanism for restricting an S3 bucket (or other origin) so that only a specific CloudFront distribution can read it — CloudFront signs its requests to the origin, and the origin's bucket policy is scoped to trust only that signed identity. It supersedes the older OAI (Origin Access Identity) and additionally supports SSE-KMS-encrypted origins. (see Day 7)

**Organizational Unit (OU)** — A container within an AWS Organization that groups member accounts (and can nest other OUs) into a tree rather than a flat list, so a guardrail like an SCP attached at a parent OU automatically applies to every account and every child OU beneath it. It's the structural unit that lets you apply different security postures to different parts of an organization — a locked-down sandbox OU versus a production OU — without repeating the same policy on every account individually. (see Day 10)

## P

**Parameter Store SecureString** — An AWS Systems Manager Parameter Store parameter type that encrypts its value at rest with KMS, functioning as a lighter-weight alternative to Secrets Manager for sensitive values that don't need automatic rotation or a per-parameter resource policy. It fits app configuration that happens to be sensitive (an internal-only URL, a feature-flag default) rather than credentials that should rotate — access to it is identity-policy-only, with no resource-based policy of its own. (see Day 5)

**Permission boundary** — A managed policy attached to a user or role that sets the *maximum* permissions that principal's identity policies can ever grant — it never grants anything by itself, it only caps. It's the standard tool for letting a team create their own IAM roles without being able to accidentally (or deliberately) create a role more powerful than the boundary allows. Sits between identity policy and session policy in the evaluation order — checked after the identity policy has already granted something, right before the session policy gets its own chance to further cap it. (see Day 2)

**Permission set** — In IAM Identity Center (successor to AWS SSO), the reusable bundle of permissions assigned to a user or group for a specific AWS account — the Identity Center equivalent of "which IAM role do you get when you log into this account," managed centrally instead of per-account. (see Day 10)

**Principal** — Whoever or whatever is making a request: an IAM user, an IAM role (including one assumed via STS), another AWS service acting on your behalf, or a federated identity. Every policy evaluation starts by identifying the principal, because every other check (deny, SCP, resource policy, and so on) is a check *about* that principal. (see Day 1)

## R

**Rate-based rule** — A WAF rule that counts requests from an IP (or a custom aggregation key) over a rolling time window and blocks that source once it crosses a threshold — the mechanism for stopping a single abusive client or a slow, low-and-slow attack that a signature-based managed rule wouldn't necessarily catch. (see Day 6)

**Resource policy** — A policy attached directly to a resource (an S3 bucket, a KMS key, an SQS queue) rather than to a principal, granting or restricting who may access that specific resource. It's checked earlier in the evaluation order than identity policies and permission boundaries — a resource policy can grant access a principal's own identity policy never mentions (cross-account access, for instance), or it can silently withhold access an identity policy would otherwise allow. Contrast with **identity policy**. (see Day 1)

## S

**SCP (Service Control Policy)** — An AWS Organizations-level policy attached to an account, OU, or the whole organization that can only ever *remove* permissions, never grant them — it sets a ceiling every resource policy, identity policy, permission boundary, and session policy in that account must additionally fit under. It's checked second in the evaluation order, right after an explicit deny, which is why "the SCP blocks it" beats any identity policy's `Allow` every time. **RCP (Resource Control Policy)** is its newer, resource-side sibling — same ceiling idea, evaluated alongside SCPs, but written to cap what resource policies in the organization can grant rather than what identities can do. (see Day 10)

**secret resource policy** — A resource-based policy attached directly to a Secrets Manager secret (rather than to a principal), written in the same IAM-style JSON as any other policy. It's the tool for an explicit `Deny` on a secret specifically — "no principal may read this except these two roles" — which an identity policy alone can't express, since identity policies only ever describe what one principal can do, not who else is blocked. (see Day 5)

**Secrets Manager rotation (the 4-step Lambda contract)** — Secrets Manager rotation is implemented by a Lambda function you own that Secrets Manager calls through four steps: `createSecret` (stage a new value under the `AWSPENDING` label), `setSecret` (push it to whatever downstream system needs it, e.g. a database `ALTER USER`), `testSecret` (confirm the new value actually works), and `finishSecret` (promote it to `AWSCURRENT`, demoting the old value to `AWSPREVIOUS`). Application code never needs to change to support this — it always asks for whatever is currently `AWSCURRENT`. (see Day 5)

**Security group vs. NACL** — Both filter network traffic, but at different layers and with different statefulness. A **security group** is *stateful* and attached to individual resources (an ENI) — allow inbound HTTP and the matching outbound response is automatically allowed, no separate rule needed. A **NACL (Network Access Control List)** is *stateless* and attached to a whole subnet — you must explicitly allow both directions of a conversation, including ephemeral return ports, or it silently drops the reply. Security groups are the day-to-day tool; NACLs are a coarser, subnet-wide backstop. (see Day 7)

**ASFF (AWS Security Finding Format)** — The normalized JSON schema Security Hub converts every finding into, regardless of which service originated it (GuardDuty, Macie, Config, Inspector, and others), so findings from different sources can be searched, filtered, and scored consistently in one place instead of each service's own native format. (see Day 8)

**Security Hub standard** — A named collection of security best-practice checks (e.g. the AWS Foundational Security Best Practices standard, or a CIS benchmark) that Security Hub continuously evaluates your account against, rolling the results into one aggregated compliance score instead of forcing you to read every underlying Config rule individually. (see Day 8)

**Security Hub standard subscription** — The act (and the resulting resource) of opting your account into a named Security Hub standard via `BatchEnableStandards` — represented by a `StandardsSubscriptionArn` — after which Security Hub begins continuously evaluating your account against every control in that standard. Enabling GuardDuty findings to flow into Security Hub doesn't require one of these; a standards subscription is specifically about turning on a checklist's worth of Config-rule-backed controls. (see Day 8)

**Session policy** — A policy passed inline at the moment of `AssumeRole` (or a similar STS call) that further restricts what the resulting temporary credentials can do, on top of whatever the assumed role's identity policy already allows. It's scoped to just that one session and disappears when the credentials expire — useful for handing out temporary, narrowly-scoped access without creating a new role for every use case. It's the last door checked in the evaluation order, right after the permission boundary. (see Day 2)

**SSM Automation document** — A Systems Manager document that codifies a sequence of remediation or operational steps (stop an instance, revoke a security group rule, re-lock a public S3 bucket) so it can be executed programmatically instead of typed by hand. AWS ships a library of ready-made ones (`AWSConfigRemediation-*`) for common misconfigurations, and both an EventBridge rule and an AWS Config remediation configuration can target one as their "act" step. (see Day 9)

**SSRF (Server-Side Request Forgery)** — A vulnerability where an application accepts a URL from a caller and fetches it *server-side*, letting an attacker make the server issue requests on its behalf — including to internal-only addresses the attacker could never reach directly, such as a cloud credential endpoint. It isn't an IAM policy problem by itself; it's an application flaw that breaks the assumption that every request reaching a policy engine really is who it claims to be, which is why fixing it requires a control in front of the request (input validation, a WAF rule) rather than just tightening a policy. (see Day 11)

## T

**Trust policy** — The resource policy attached to an IAM role that specifies *who* is allowed to assume it — which principals (accounts, services, federated identities) `sts:AssumeRole` will accept for this role. It's a resource policy in every technical sense, just one whose "resource" happens to be a role and whose permission is "may assume," rather than "may read/write." (see Day 2)

## V

**VPC endpoint policy** — A resource policy attached to a VPC endpoint (interface or gateway) that restricts which API calls and which resources are reachable *through that endpoint specifically* — independent of, and layered on top of, whatever the target resource's own policy allows. It's how you can permit S3 access from inside a VPC while still denying that same access if it's attempted from outside the VPC entirely. (see Day 7)

## W

**Web ACL** — The top-level WAF resource: an ordered set of rules and rule groups (managed and/or custom) attached to a CloudFront distribution, ALB, or API Gateway, evaluated in priority order to produce an allow/block decision for each incoming request before it reaches your application. (see Day 6)

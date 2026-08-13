# ROADMAP — Coverage & Extension Map

This file tracks how the **Cybersecurity Foundations Fast-Track** (Day 0–21, see
[README.md](README.md)) maps onto the broader cybersecurity field, using the
[roadmap.sh cybersecurity roadmap](https://roadmap.sh/cyber-security) as the reference
tree. The 21-day core is intentionally narrow-and-deep on a purple-team attack/defense
loop — it does not attempt every branch of that tree. The table below shows, for each
top-level roadmap.sh node, the **target status this path reaches once all 22 days are
complete**, and exactly where in this path that coverage comes from. Anything not fully
reached becomes a named **Extension Module** below.

**Status key:**
- **Covered** — the path gives hands-on, lab-verified competence in this node's core skills.
- **Partial** — the path touches this node meaningfully but doesn't go deep; an extension
  module (or further study) is needed for competence.
- **Deferred** — this node is out of scope for the 21-day core; it's named as a future
  extension module or left to other resources.

**This file is a living document.** Status starts as the *target* state below; each Day
task updates its own row as that day's content ships (Per-Day Task Procedure, Step F).
End-of-phase checkpoints at **Day 6, Day 12, Day 18, and Day 21** additionally re-verify
and reconcile this whole table.

## Coverage Table

| roadmap.sh node | Target status | Where in this path |
|---|---|---|
| Fundamentals / security basics | Covered — threat modeling, reconnaissance, and Phase-1 consolidation all shipped (day00, day01, day06) | [day00-ignition](content/day00-ignition.md) (STRIDE threat modeling, trust boundaries — **shipped**), [day01-recon](content/day01-recon.md) (CIA triad through an attacker's eyes, passive/active recon, attack surface — **shipped**), [day06-ctf-fundamentals](content/day06-ctf-fundamentals.md) (consolidation mini-CTF, end-of-Phase-1 checkpoint — **shipped**) |
| Networking security | Covered — day02-networking and day17-cloud-network both shipped | [day02-networking](content/day02-networking.md) (OSI/TCP, scanning, ARP/MITM, segmentation, firewalling — **shipped**); reinforced in [day17-cloud-network](content/day17-cloud-network.md) (VPC/subnets, SG vs NACL, exposure mechanics, VPC Flow Logs — **shipped**) |
| Operating-system security | Covered | [day05-privesc](content/day05-privesc.md) (users/permissions, SUID/SGID, sudo, cron, privilege escalation, auditd) |
| Cryptography | Covered — day03-crypto shipped | [day03-crypto](content/day03-crypto.md) (hashing vs encryption, symmetric/asymmetric, ECB/CBC/GCM, KDFs, cracking weak hashes — **shipped**) |
| Identity & access management (IAM) | Covered — day04-auth, day13-cloud-iam, and day14-iam-privesc all shipped | [day04-auth](content/day04-auth.md) (sessions, cookies, JWT structure/claims, brute force, rate limiting/lockout, MFA, OIDC basics — **shipped**); [day13-cloud-iam](content/day13-cloud-iam.md) (IAM principals/policies/roles, least privilege, permission boundaries, SCP, policy evaluation — **shipped**); [day14-iam-privesc](content/day14-iam-privesc.md) (IAM abuse/escalation — PassRole, CreatePolicyVersion, AttachUserPolicy primitives; Access Analyzer/pmapper detection — **shipped**) |
| Application / web security | Covered — day07/day08/day09/day12 all shipped | [day07-http](content/day07-http.md) (HTTP methods/headers/cookies, SOP, CORS, security headers, intercepting-proxy mechanics — **shipped**), [day08-injection-xss](content/day08-injection-xss.md) (SQLi incl. UNION-based/blind, command injection, reflected/stored/DOM XSS, output encoding, prepared statements — **shipped**), [day09-access-ssrf-csrf](content/day09-access-ssrf-csrf.md) (IDOR/broken access control, SSRF incl. SSRF-to-cloud foreshadowing, CSRF, OWASP Top 10 mapping — **shipped**), [day12-ctf-web](content/day12-ctf-web.md) (consolidation mini-CTF, end-of-Phase-2 checkpoint — **shipped**) |
| Cloud security | Covered — day13 through day18 all shipped (Phase 3 complete) | [day13-cloud-iam](content/day13-cloud-iam.md) (IAM foundations — **shipped**), [day14-iam-privesc](content/day14-iam-privesc.md) (IAM abuse/escalation — **shipped**), [day15-metadata-s3](content/day15-metadata-s3.md) (IMDS/IMDSv2, SSRF-to-cloud, S3 exposure — **shipped**), [day16-cloud-detection](content/day16-cloud-detection.md) (CloudTrail/GuardDuty/AWS Config/EventBridge, auto-remediation — **shipped**), [day17-cloud-network](content/day17-cloud-network.md) (VPC/SG/NACL/Flow Logs — **shipped**), [day18-cloud-lab](content/day18-cloud-lab.md) (end-to-end cloud consolidation, end-of-Phase-3 checkpoint — **shipped**) — AWS only, own sandbox account |
| Security tooling | Partial | Toolbox in [labs/base](labs/base/README.md) (nmap, tcpdump/tshark, hashcat/john, hydra, sqlmap, gobuster) exercised throughout Days 1–10; [day10-secrets-supplychain](content/day10-secrets-supplychain.md) (gitleaks/trufflehog/trivy/grype/syft, secrets sprawl, SBOM, CVE/CVSS triage — **shipped**). Breadth is limited to tools this path uses directly — no dedicated tool-survey day |
| Blue team / SOC / detection | Covered — day02-networking (scan/ARP detection, Partial on its own) + day11-detection (telemetry, detection engineering, fail2ban/Suricata/jq log correlation, closes the purple loop) together bring the on-prem/network half to full coverage; day16-cloud-detection extends this to the cloud-native half | [day02-networking](content/day02-networking.md) (scan/ARP detection — **shipped, Partial on its own**), [day11-detection](content/day11-detection.md) (logging, detection engineering, fail2ban/suricata, closes the purple loop — upgrades Day 2's IDS coverage to Covered — **shipped**), [day16-cloud-detection](content/day16-cloud-detection.md) (CloudTrail/GuardDuty/AWS Config/EventBridge, auto-remediation — **shipped**) |
| Offensive security / red team | Covered | Primary thread of Days 1–5, 8–9, 14–15, and [day20-capstone-attack](content/day20-capstone-attack.md) (recon → network attacks → crypto attacks → auth attacks → OS privesc → web injection/access-control → cloud IAM/SSRF privesc → full chain — **shipped**) |
| Incident response & forensics | Covered | [day19-ir-forensics](content/day19-ir-forensics.md) (IR lifecycle, triage, chain of custody, host forensics/timeline — **shipped**); reinforced in [day21-capstone-defend](content/day21-capstone-defend.md) (attack-and-defense report, findings report, defense-in-depth, remediation vs. compensating controls — **shipped, foundations-complete**) |
| Governance, risk & compliance (GRC) | Partial | [day00-ignition](content/day00-ignition.md) covers risk-assessment methodology (STRIDE) as a habit; no day covers compliance frameworks (NIST CSF, ISO 27001, PCI-DSS, SOC 2) or audit practice — see **Governance/Compliance literacy** extension module below |

**Status as of the Day 21 capstone:** all 22 day-modules (Day 0–21) have shipped, and
every end-of-phase checkpoint (Day 6, 12, 18, and 21) has been reconciled into the
table above. The 21-day core is complete — the next step is picking a specialization
from the **Extension Modules** below (see
[day21-capstone-defend.md](content/day21-capstone-defend.md) Section 5).

## Extension Modules

Concrete future phases beyond the 21-day core, each with its scope and the day(s) it
builds on. These are not scheduled — pick one after Day 21 based on the specialization
chosen in [day21-capstone-defend](content/day21-capstone-defend.md).

| Module | Scope | Prerequisite day(s) |
|---|---|---|
| **Web Exploitation Deep-Dive** | Advanced web attack classes beyond injection/XSS/IDOR/SSRF/CSRF — SSTI, insecure deserialization, request smuggling, auth/business-logic bypass, advanced SQLi (blind/OOB) | [day09-access-ssrf-csrf](content/day09-access-ssrf-csrf.md), [day12-ctf-web](content/day12-ctf-web.md) |
| **Binary Exploitation / Reversing intro** | Reading disassembly, stack layout, basic buffer overflows, intro to exploit primitives (Docker-first, no OS zero-days) | [day05-privesc](content/day05-privesc.md) |
| **SIEM & Threat Hunting (blue-team track)** | Standing up a real SIEM (e.g. ELK/Wazuh), writing detection rules at scale, structured threat-hunting hypotheses over telemetry | [day11-detection](content/day11-detection.md), [day16-cloud-detection](content/day16-cloud-detection.md) |
| **Malware Analysis intro** | Safe static/dynamic analysis of sample malware in an isolated sandbox VM, IOC extraction, basic unpacking | [day19-ir-forensics](content/day19-ir-forensics.md) |
| **OSCP-style privilege-escalation track** | A larger rotation of vulnerable-machine CTFs chaining recon → foothold → privesc across varied misconfigurations (Linux + Windows) | [day05-privesc](content/day05-privesc.md), [day06-ctf-fundamentals](content/day06-ctf-fundamentals.md) |
| **Cloud IR & detection engineering at scale** | Multi-account detection-as-code, Security Hub/Config aggregation, automated response playbooks beyond the single-account Day 16 alert | [day16-cloud-detection](content/day16-cloud-detection.md), [day18-cloud-lab](content/day18-cloud-lab.md) |
| **Governance/Compliance literacy** | Risk-management frameworks (NIST CSF, ISO 27001), compliance mapping (PCI-DSS, SOC 2), control documentation and audit prep | [day00-ignition](content/day00-ignition.md), [day21-capstone-defend](content/day21-capstone-defend.md) |

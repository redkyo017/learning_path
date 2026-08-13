# Cybersecurity Foundations Fast-Track

A 22-module (Day 0–21) purple-team cybersecurity learning path: attack a system, then
instrument its defense and detection, day after day, until offense and defense are one
reflex instead of two subjects.

## Who this is for

You're comfortable with core networking, Linux basics, and (per prior learning paths in
this repo) TLS/certificates and AWS networking. You haven't yet built a systematic
offense-then-defense habit across the stack — this path builds that habit hands-on, in
runnable labs, rather than through slides or certification cram.

## The purple-spiral method

Every day follows the same loop: **build → break → fix → detect**. You start from a
concept, attack a deliberately vulnerable target to see the weakness firsthand, apply the
fix, then instrument logging/alerting so the *same* attack would be caught next time.
Earlier attacks don't disappear after their day — they resurface later as detection
targets (e.g., the Day 2 port scan and Day 8 injection get replayed and detected in
Day 11; the Day 9 SSRF pattern reappears as cloud credential theft in Day 15). Knowledge
compounds instead of being covered once and forgotten.

## Prerequisites

- **Docker** and Docker Compose, for every lab through Day 12 and most of Days 19–21.
- **AWS CLI** plus your own AWS **sandbox account** (a dedicated, low-stakes account),
  needed only for Phase 3 (Days 13–18) and parts of the capstone (Days 20–21). Every AWS
  lab ships a `teardown.sh` and stays free-tier-friendly; cost is called out wherever it
  applies (e.g., GuardDuty).
- Basic comfort with the Linux shell.

## How to start

1. Read `content/STRATEGY.md` and `content/ANTIPATTERNS.md` once, before Day 0 — they set
   the habits (and the traps to avoid) for the whole path.
2. Bring up the shared lab toolbox: see `labs/base/README.md` (build once, reuse every
   day).
3. Start at `content/day00-ignition.md`.
4. After each day, write a `journal.md` entry (template below) before moving on.
5. Track your progress against the wider field in `ROADMAP.md`.

## Standing rules

- **Authorized-lab only.** Every attack in this path targets containers or cloud
  resources you stood up yourself in your own sandbox. Never point any tool in this path
  at a system you don't own or don't have explicit written authorization to test.
- **Teardown every AWS lab.** Each Phase 3 (and capstone) lab includes `teardown.sh`.
  Run it when you're done with that day, even if you plan to return — AWS resources left
  running cost money and expand your exposure.
- **No commits from tooling.** Version control in this repo is handled by you, the
  learner — content-generation tooling does not run `git commit`.

## Day index

| Day | Title | Content |
|---|---|---|
| 00 | Ignition, threat modeling, lab bootstrap | [content/day00-ignition.md](content/day00-ignition.md) |
| 01 | Attacker mindset, threat modeling, recon | [content/day01-recon.md](content/day01-recon.md) |
| 02 | Networking as an attacker | [content/day02-networking.md](content/day02-networking.md) |
| 03 | Cryptography for security | [content/day03-crypto.md](content/day03-crypto.md) |
| 04 | Authentication & identity | [content/day04-auth.md](content/day04-auth.md) |
| 05 | Linux/OS security & privilege escalation | [content/day05-privesc.md](content/day05-privesc.md) |
| 06 | Consolidation mini-CTF (fundamentals) | [content/day06-ctf-fundamentals.md](content/day06-ctf-fundamentals.md) |
| 07 | HTTP & the web as attack surface | [content/day07-http.md](content/day07-http.md) |
| 08 | Web attacks I: injection & XSS | [content/day08-injection-xss.md](content/day08-injection-xss.md) |
| 09 | Web attacks II: access control, SSRF, CSRF | [content/day09-access-ssrf-csrf.md](content/day09-access-ssrf-csrf.md) |
| 10 | Secrets & supply chain | [content/day10-secrets-supplychain.md](content/day10-secrets-supplychain.md) |
| 11 | Logging & the blue-team loop | [content/day11-detection.md](content/day11-detection.md) |
| 12 | Web consolidation mini-CTF | [content/day12-ctf-web.md](content/day12-ctf-web.md) |
| 13 | Cloud security model & IAM foundations | [content/day13-cloud-iam.md](content/day13-cloud-iam.md) |
| 14 | IAM abuse & privilege escalation in AWS | [content/day14-iam-privesc.md](content/day14-iam-privesc.md) |
| 15 | Metadata/SSRF-to-cloud, S3, exposed services | [content/day15-metadata-s3.md](content/day15-metadata-s3.md) |
| 16 | Cloud detection & response | [content/day16-cloud-detection.md](content/day16-cloud-detection.md) |
| 17 | Cloud network security | [content/day17-cloud-network.md](content/day17-cloud-network.md) |
| 18 | Cloud consolidation lab | [content/day18-cloud-lab.md](content/day18-cloud-lab.md) |
| 19 | Incident response & forensics basics | [content/day19-ir-forensics.md](content/day19-ir-forensics.md) |
| 20 | Capstone I: attack end-to-end | [content/day20-capstone-attack.md](content/day20-capstone-attack.md) |
| 21 | Capstone II: harden, detect, report + roadmap update | [content/day21-capstone-defend.md](content/day21-capstone-defend.md) |

## Structure

- `content/` — the 22 day files above, plus shared reference docs:
  - `content/STRATEGY.md` — the top-1% playbook: concrete habits that separate people who
    actually get good at this from people who collect certifications.
  - `content/ANTIPATTERNS.md` — the 80% time-wasters to avoid, each as symptom → why it
    wastes time → the fix.
  - `content/GLOSSARY.md` — every term introduced, grown incrementally day by day.
- `labs/` — one directory per day (`labs/dayNN/`) with the runnable Docker (or, in Phase
  3, AWS `setup.sh`/`teardown.sh`) environment, a `README.md`, and a `SOLUTION.md`.
  `labs/base/` is the shared attacker toolbox reused by every day.
- `journal.md` — your running writeup log; one entry per day.
- `ROADMAP.md` — how this path maps onto the broader cybersecurity field (roadmap.sh-style
  tree), what's covered vs. deferred, and the extension modules for after Day 21.
- `docs/superpowers/` — the spec, plan, and reviews used to build this path (not learner
  content).

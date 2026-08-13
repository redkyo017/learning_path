# Capstone Attack-and-Defense Writeup Template

Copy this file to `writeup.md` (or paste it into your own notes) and fill in every
bracketed placeholder. Day 20 asks you to complete **Sections 1-6** as your attacker's
findings deliverable, right after you finish the attack chain, while it's fresh. Day 21
asks you to come back and complete **Sections 7-10** once you've applied and
re-verified each control -- the finished document is the full attack-and-defense
writeup, the capstone's main deliverable.

This is not busywork: writing this down precisely, with evidence, in the order a real
engagement would need it, is itself a skill -- see `content/STRATEGY.md`'s
spaced-retrieval principle and every earlier day's journal habit, scaled up to a real
deliverable shape.

---

## 1. Executive Summary

*Three to five sentences, written for someone who will never run a single command in
this lab. What was tested, what you got, why it matters, in plain language -- no jargon
that isn't defined elsewhere in this document.*

```
[Your summary here.]
```

## 2. Scope & Authorization

```
Target:        labs/capstone/ (webapp, host, fake-imds, fake-s3) -- this repo's own
                Docker sandbox [and, if you ran setup.sh --with-aws: your AWS sandbox
                account, profile <name>].
Authorization: self-authorized, authorized-sandbox-only lab exercise. Not a real
                engagement; no third party's systems were touched.
Dates:          [start] - [end]
Tester:         [you]
```

## 3. Environment / Architecture Map

*Sketch (ASCII is fine) or describe: which containers exist, which networks each one
sits on, and which boundaries an attacker actually has to cross. Compare your sketch
against `content/day20-capstone-attack.md`'s Concept section once you're done -- did you
get every boundary right before you started attacking, or only after?*

```
[Your architecture sketch here.]
```

## 4. Methodology -- Kill Chain Stages

*List the stages you actually walked, in the order you walked them, named with the kill
chain / lateral-movement vocabulary from Day 20's Concept section. There were two
independent sub-chains in this environment (Path A and Path B) -- note explicitly
whether you ran one or both, since that itself matters (see Section 5).*

```
Path A (broken access control -> command injection -> lateral movement -> host privesc):
  [ ] Recon
  [ ] Stage 2a - access control bypass
  [ ] Stage 2b - command injection foothold
  [ ] Stage 3  - lateral movement / pivot to `host`
  [ ] Stage 3  - host privilege escalation

Path B (SQL injection -> admin -> SSRF -> cloud credential access):
  [ ] Recon
  [ ] Stage 2c - SQL injection auth bypass
  [ ] Stage 4  - SSRF to instance metadata
  [ ] Stage 4  - cloud credential use
```

## 5. Vulnerability Log

*One block per distinct vulnerability. Use the IDs below (they're the ones
`SOLUTION-attack.md` uses) so Section 7's remediation table can reference them
directly.*

```
### CAP-1 - Broken access control on /admin/diagnostics

Description:  [what the bug is, in one sentence]
Evidence:     [exact request(s) and response excerpt(s) that prove it]
Impact:       [what an attacker gains]
Severity:     [your call - justify it in one sentence]
Component:    webapp

### CAP-2 - OS command injection on /admin/diagnostics

Description:  ...
Evidence:     ...
Impact:       ...
Severity:     ...
Component:    webapp

### CAP-3 - Hardcoded/leaked internal credential (ops-notes.txt)

Description:  ...
Evidence:     ...
Impact:       ...
Severity:     ...
Component:    webapp

### CAP-4 - Passwordless sudo on python3 (host privilege escalation)

Description:  ...
Evidence:     ...
Impact:       ...
Severity:     ...
Component:    host

### CAP-5 - SQL injection auth bypass on /login

Description:  ...
Evidence:     ...
Impact:       ...
Severity:     ...
Component:    webapp

### CAP-6 - Server-side request forgery on /admin/fetch

Description:  ...
Evidence:     ...
Impact:       ...
Severity:     ...
Component:    webapp

### CAP-7 - IMDSv1 permits unauthenticated metadata reads

Description:  ...
Evidence:     ...
Impact:       ...
Severity:     ...
Component:    fake-imds [or: real AWS EC2 instance metadata options]
```

## 6. Attack Narrative

*The full step-by-step story, in your own words, cross-referencing the vulnerability IDs
above. Don't just paste `SOLUTION-attack.md` -- write it as if a colleague who's never
seen this lab has to reproduce your work from this section alone.*

```
[Your narrative here.]
```

---

*Everything below this line is Day 21's job -- come back once you've applied and
re-verified each control.*

## 7. Remediation Plan

*One row per vulnerability. "Verified?" means you personally re-ran the Day 20 payload
against the hardened environment and watched it fail -- not that the fix merely looks
correct.*

| ID | Control applied | Verified? (re-attack result) |
|---|---|---|
| CAP-1 | | |
| CAP-2 | | |
| CAP-3 | | |
| CAP-4 | | |
| CAP-5 | | |
| CAP-6 | | |
| CAP-7 | | |

## 8. Residual Risk

*After every control above is applied, what's still true that you'd want a real
organization to know about? A control blocking today's exact payload is not the same
claim as "this class of bug can never recur here" -- name the gap honestly.*

```
[Your residual risk assessment here.]
```

## 9. Detection Coverage

*For each vulnerability, does `detection/detect.sh` (or your own detection) actually
fire on it? If not, say so -- a vulnerability with a control but no detection is a
different risk posture than one with both.*

```
[Your detection coverage table/notes here.]
```

## 10. Retrospective

*Use the Day 21 Journal Prompt (content/day21-capstone-defend.md, Section 5) for this --
paste your answer here too so this document is self-contained.*

```
[Your retrospective here.]
```

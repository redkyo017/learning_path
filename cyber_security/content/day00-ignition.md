# Day 0 — Ignition, Threat Modeling, Lab Bootstrap

## Objectives

By the end of today you should be able to:

- Explain the build → break → fix → detect loop this whole path runs on, and where
  today fits into it (setup, not an attack).
- Run a STRIDE threat model against a simple architecture from a diagram alone, with one
  threat per category.
- Identify trust boundaries in that architecture and name a mitigation for each.
- Have the shared attacker toolbox (`labs/base`) up and confirmed working.

There is no attack today. Day 0 is the only day in this path with no exploit — its job
is to give you the habit (STRIDE) and the tool (the lab toolbox) that every later day
assumes you already have.

## 1. Concept — How This Path Works, and Your First Threat Model

### The loop you'll repeat 21 more times

Every day after this one follows the same rhythm, spelled out in full in
[`content/STRATEGY.md`](STRATEGY.md): **build → break → fix → detect.** You read a
concept, attack a deliberately vulnerable target to see the weakness firsthand, apply
the fix, then re-attack the patched version to confirm the fix holds, and instrument
detection so the same attack wouldn't go unnoticed in production. Read `STRATEGY.md` and
[`content/ANTIPATTERNS.md`](ANTIPATTERNS.md) in full before Day 1 if you haven't
already — they're short, and they set the habits (and name the traps) for the next 21
days.

Today, instead of attacking a target, you're doing the thing that comes *before* every
attack in this path: deciding where to look. That's threat modeling.

### STRIDE: a checklist for "what could go wrong"

Before you can attack (or defend) a system well, you need a structured way to ask "what
could go wrong here, and who would make it go wrong?" Staring at an architecture diagram
and hoping inspiration strikes doesn't scale — you'll always notice the same one or two
failure modes you already know about and miss the rest. **STRIDE** is a checklist that
forces you through six categories of failure, one at a time:

| Letter | Category | The question it forces |
|---|---|---|
| **S** | Spoofing | Could someone convincingly pretend to be a user, service, or component they aren't? |
| **T** | Tampering | Could someone modify data, code, or configuration without authorization? |
| **R** | Repudiation | Could someone perform an action and later credibly deny having done it? |
| **I** | Information disclosure | Could someone read data they shouldn't have access to? |
| **D** | Denial of service | Could someone degrade or block the system's availability? |
| **E** | Elevation of privilege | Could someone gain capabilities beyond what they're authorized for? |

STRIDE isn't a research project — it's a five-minute pass, one sentence per category,
run against *any* system before you decide where to spend attack time. `STRATEGY.md`
Principle 6 makes this a standing daily habit for every day after this one. Today you
run it once, slowly, as a worked example.

### A threat actor is who, a mitigation is what you do about it

Two terms you'll use constantly while threat modeling:

- A **threat actor** is *who* might cause the problem — an external attacker scanning
  the internet, a malicious insider with legitimate credentials, an automated
  bot/worm, or even an unintentional actor (a misconfigured script, a careless
  employee). Naming the actor for a threat clarifies how likely it is and what it would
  take to pull off.
- A **mitigation** is *what you do about it* — a control that reduces the likelihood or
  blast radius of a threat: input validation, encryption in transit, network
  segmentation, least-privilege IAM, rate limiting, and so on. Every **trust boundary**
  (see `GLOSSARY.md` — you already met this term) should have at least one mitigation
  covering it.

### Worked example: browser → web app → DB → S3 bucket

Here's the sample architecture you'll reuse for the defense lab and drills below — a
typical small web app:

```
[ Browser ]  --HTTPS-->  [ Web app ]  --SQL-->  [ Database ]
                              |
                              +--API calls-->  [ S3 bucket ]
```

A user's browser talks to a web app over HTTPS. The web app queries a database for
application data, and separately calls an S3 bucket (via the AWS API) to store or fetch
uploaded files. Three components, three trust levels: the browser is fully untrusted
(anyone can point one at your app), the web app is your trusted logic tier, and the
database/S3 are backend stores the web app should be the only thing touching directly.

**One STRIDE threat per category, for this architecture:**

| Category | Example threat |
|---|---|
| Spoofing | An attacker steals or guesses a session cookie and impersonates a logged-in user to the web app. |
| Tampering | A user tampers with a hidden form field or API parameter to change a price or user ID the web app trusts blindly. |
| Repudiation | The web app has no audit log, so an admin who deletes a record can plausibly claim they never did it. |
| Information disclosure | The database is queried with unsanitized input (SQL injection), leaking rows the requester was never authorized to see. |
| Denial of service | An attacker sends a flood of expensive requests (e.g., large file uploads to S3) until the app or the account's request quota is exhausted. |
| Elevation of privilege | A regular user discovers an unauthenticated admin API endpoint and uses it to grant themselves admin rights. |

Notice each threat lives at a specific point in the diagram — that's the connection
between STRIDE and trust boundaries: STRIDE tells you *what kind* of thing can go wrong;
trust boundaries tell you *where* to look for it.

## 2. Attack Lab — None Today: Stand Up the Toolbox Instead

There's no vulnerable target to break yet — that starts Day 1. Today's hands-on step is
getting the shared **attacker toolbox** running, since every day-lab from Day 1 onward
assumes it's already up.

**What you're bringing up:** `labs/base` — a Kali-rolling-based `attacker` container
(nmap, tcpdump/tshark, john, hashcat, hydra, sqlmap, gobuster, whatweb, and more) plus
the `cyberlab` docker bridge network that every later day's target containers attach to.
Full detail: [`labs/base/README.md`](../labs/base/README.md).

**Do this now:**

```sh
cd cyber_security/labs/base
./up.sh
docker compose exec attacker sh -c "echo LAB_READY"
```

Expected: after the (one-time, multi-minute) image build, the container starts on the
`cyberlab` network, and the `exec` prints `LAB_READY`. That confirms two things at
once: the attacker container is running, and `docker compose exec` can reach it — the
exact mechanism every later day's lab verify command depends on.

Full walkthrough and troubleshooting: [`labs/day00/README.md`](../labs/day00/README.md).

When you're done for the session, you can tear down (`./down.sh`) or leave `labs/base`
running — it's shared, lightweight infrastructure meant to persist across days.

## 3. Defense Lab — Map the Trust Boundaries and Their Mitigations

Take the same browser → web app → DB → S3 architecture from Section 1. Before touching
any tool, do this on paper or in a scratch file:

1. **Draw the trust boundaries** — every place the diagram crosses from one trust level
   to another. In this architecture there are three: browser↔web app, web app↔database,
   and web app↔S3.
2. **For each boundary, name one mitigation** that belongs specifically at that
   crossing — not a generic "use good security practices," but a control that addresses
   what changes trust at that exact point.

Try it yourself first, then check your answer against the worked walkthrough below.

**Worked answer:**

| Trust boundary | Why it's a boundary | One mitigation |
|---|---|---|
| Browser ↔ Web app | The browser is fully untrusted — any input arriving here could be forged, scripted, or malicious. | Validate and authenticate every request server-side (auth checks, input validation) — never trust client-supplied data or client-side checks alone. |
| Web app ↔ Database | The web app is trusted logic, but the query it builds may embed untrusted data from the browser. | Use parameterized queries/prepared statements so untrusted input can never be interpreted as SQL. |
| Web app ↔ S3 | The web app's AWS credentials/role determine what the bucket will do — over-broad permissions here turn any web-app bug into a data breach. | Scope the web app's IAM role to least privilege (only the specific bucket/actions it needs) and keep the bucket itself private by default. |

The pattern to internalize: **a mitigation belongs at the boundary, not floating in the
middle of a component.** "Validate input" is meaningless until you say *where* the
untrusted input enters — that's exactly what mapping trust boundaries first gives you.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — STRIDE-classify 5 given threats

Classify each threat below into exactly one STRIDE category (Spoofing, Tampering,
Repudiation, Information disclosure, Denial of service, Elevation of privilege):

1. An attacker floods a login API with requests until the server runs out of memory.
2. A user edits a JWT's payload to change their `role` claim from `user` to `admin`,
   and the server accepts it without re-verifying the signature.
3. An attacker intercepts a password reset link and uses it to log in as the victim.
4. A support engineer deletes a customer's account and later claims they never touched
   it, because there's no log of the action.
5. A misconfigured API returns another customer's full order history when queried with
   a guessable ID.

**Hint:** ask "what specifically changed for the attacker" — did they *become* someone
(S), *alter* something (T), *deny* something (R), *see* something (I), *break*
availability (D), or *gain* capability (E)? Some threats look like they could fit two
categories — pick the one that describes the *mechanism*, not the eventual damage.

**Solution sketch:**

1. **Denial of service** — the mechanism is resource exhaustion, not any of the other
   five.
2. **Elevation of privilege** — the attacker gains admin capability they weren't
   authorized for; note this is *also* a tampering act (modifying the JWT), but the
   goal/mechanism to classify by is the privilege gain, since that's the actual damage
   done via a broken trust check (the missing signature re-verification).
3. **Spoofing** — the attacker is now impersonating the victim's identity/session.
4. **Repudiation** — the core failure is the *absence of an audit trail*, letting the
   actor deny the action.
5. **Information disclosure** — data crossed a boundary to a party not authorized to
   see it (this is also a broken access control, but the STRIDE mechanism is disclosure).

### Drill 2 — Draw trust boundaries for a login + DB + S3 app

Given an app with: a public login page, an application server, a user database, and an
S3 bucket for profile pictures — sketch (ASCII is fine) the components and mark every
trust boundary.

**Hint:** count components first, then check every *pair* that exchanges data — a
boundary exists wherever the trust level changes crossing that pair, not just between
adjacent boxes in your drawing.

**Solution sketch:**

```
[ Browser/login page ] --(1)--> [ App server ] --(2)--> [ User DB ]
                                       |
                                      (3)
                                       v
                                 [ S3 bucket ]
```

Three boundaries, same shape as the worked example in Section 1:

- **(1) Browser ↔ App server** — untrusted client to trusted logic tier.
- **(2) App server ↔ User DB** — trusted logic, but the query may embed
  browser-supplied data (e.g., the username being looked up).
- **(3) App server ↔ S3** — the app server's credentials/role determine what happens to
  the bucket; a compromised or over-permissioned app server becomes a compromised
  bucket.

A common mistake: forgetting that the login page *is* the browser boundary (it's not a
separate trusted component just because it's the "login" page) — the trust level only
changes once data leaves the browser and reaches server-side code.

### Drill 3 — Pick the highest-risk threat and justify it

From the five threats in Drill 1, pick the single highest-risk one and justify your
choice in 2-3 sentences.

**Hint:** "risk" is a function of both **likelihood** (how easy/common is this attack?)
and **impact** (how bad is it if it succeeds?) — a devastating but nearly-impossible
threat and a trivial but low-impact one can both lose to something that's merely
moderate on both axes. There's no single correct answer here; the justification is what
matters.

**Solution sketch:** A defensible answer is **#2 (JWT role-tampering to admin)**:
likelihood is high because tampering with a client-held token requires no special
access, just a text editor, and — critically — the flaw described (accepting the claim
without re-verifying the signature) means the "attack" is trivial to execute once
discovered. Impact is severe: full admin elevation, not just a data leak, meaning the
attacker can now do anything an admin can, including covering their tracks. Compare to
#1 (DoS): often high-likelihood but typically lower and more recoverable impact (service
degradation, not a compromise), and #4 (repudiation): real, but it's a governance/audit
gap rather than a way to directly cause harm. A defensible alternate answer is #5 if
you argue the guessable-ID pattern is likely to be automatable at scale across many
customers, which can make aggregate impact larger than a single admin-elevation
incident — the key grading criterion is that your likelihood/impact reasoning is
explicit, not which threat you picked.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file,
adapted for a day with no attack:

- **What I attacked:** *(none — write instead: "the architecture I threat-modeled and
  why I chose that framing")*
- **How:** the STRIDE pass — which category was hardest to find a threat for, and why?
- **What defended it:** the mitigation you're least confident about from Section 3 — the
  one where, if pushed, you couldn't fully explain *why* it stops the threat at that
  specific boundary.
- **What confused me:** anything about STRIDE, trust boundaries, or the loop itself that
  didn't click on first read.
- **One thing to revisit:** pick one term from today (STRIDE, trust boundary, threat
  actor, mitigation, attack surface) to re-explain from memory before Day 1, without
  looking back at this file.

Do this before starting Day 1 — Principle 4 in `STRATEGY.md` is the whole reason this
habit exists, and it starts today, not once you have an exploit to write up.

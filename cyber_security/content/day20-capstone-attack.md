# Day 20 — Capstone I: Attack End-to-End

## Objectives

By the end of today you should be able to:

- Name the **kill chain** stages you actually walked through against a multi-container
  environment you've never seen the source of before, in the correct order, using the
  vocabulary (recon, foothold, escalation, **lateral movement**/**pivot**, objective)
  rather than "then I did this, then I did that."
- Execute **lateral movement** for real — reach a host your attacking machine has *no
  network route to at all* by riding an already-compromised machine's own network
  position and tools, and say precisely why that's different from just "using another
  tool."
- Chain a broken-access-control bug, a command-injection bug, a leaked credential, and a
  GTFOBins privilege escalation into one continuous foothold-to-root path — and,
  independently, chain a SQL-injection auth bypass into an SSRF that steals cloud
  credentials — without either path depending on the other.
- Explain, from firsthand attack experience rather than from reading about it, why an
  environment can have **two independent ways in** to the same eventual objective, and
  why a findings report that only documents the path you happened to try first is an
  incomplete report.
- Produce a **findings report** (Sections 1–6 of `labs/capstone/report-template.md`)
  that a colleague who never touched this lab could use to reproduce every finding.

## 1. Concept — The Kill Chain, Lateral Movement, and Why This Environment Has Two Doors

### The kill chain, as a vocabulary rather than a rigid recipe

Every attack you've run in this path so far has quietly followed the same shape:
**recon** (find out what's there) → **foothold** (get some access at all) →
**escalation** (turn that access into more access) → **objective** (do the thing you
actually came for — read data, prove impact, move on). Security teams borrow the term
**kill chain** from Lockheed Martin's original model of this shape, and MITRE ATT&CK
gives each stage a much larger, real-world-attack-derived vocabulary of specific
*techniques* within each stage. You don't need ATT&CK's full taxonomy today, but you do
need the discipline the vocabulary forces: a findings report that says "I got in, then
found some stuff, then got admin" is not a kill-chain analysis — one that says "initial
access via broken access control on an internal diagnostic endpoint, execution via OS
command injection, lateral movement via a leaked SSH credential to an internal host,
privilege escalation via a passwordless sudo rule on `python3`" is.

Today's environment has a stage this path hasn't given you a clean, deliberate example
of yet: **lateral movement**. Every earlier day's target was one box, reachable
directly from `attacker`. Today, one of the two objectives lives on a box `attacker`
has **no network route to at all** (see the architecture map below) — the only way to
reach it is to compromise a box that *does* have a route, and use *that box's own
network position and tools* to take the next step. That specific technique — using an
already-compromised host as a stepping stone into a network segment you couldn't reach
directly — is called a **pivot**, and doing it is lateral movement in the most literal,
textbook sense: you are moving laterally, across a boundary, using someone else's
foothold as your vehicle, not opening a brand new connection of your own from
`attacker`.

### Architecture — draw this before you attack anything

```
                 cyberlab (shared, external)
   attacker ───────────────┬───────────────── fake-s3
                            │                  ("the S3 API" -- reachable
                            │                   directly, like real S3)
                            ▼
                         webapp
                    "Northwind Ops Portal"
                       /            \
                      /              \
        internal (lab-private)      imds (lab-private)
        [attacker has NO route]     [attacker has NO route]
                    │                          │
                    ▼                          ▼
                  host (ssh)              fake-imds (169.254.169.254)
        "the box nobody meant           "the metadata service" --
         to expose"                      only webapp can reach this
```

Two boundaries matter more than anything else in this diagram: `attacker` shares a
network with `webapp` and `fake-s3` only, never with `host` or `fake-imds`. Everything
you do today either respects those boundaries (recon, the SQL injection, the SSRF
itself) or specifically *crosses* one of them by riding `webapp`'s own position (the
pivot to `host`) or by tricking `webapp` into crossing it on your behalf (the SSRF to
`fake-imds`) — those are two *different* mechanisms for crossing a network boundary you
don't have direct access to, and naming which one you used, precisely, is itself part
of today's findings report.

### Why this environment has two independent doors, on purpose

Real environments are rarely one clean, single-file kill chain. A web app usually has
*several* bugs at once, and a competent attacker — or a competent pentest report —
doesn't stop enumerating after the first one works. This lab's `webapp` has two
genuinely separate bug pairs, and neither depends on the other at all:

- **Path A** — a normal, freely self-registered account reaches an endpoint that
  should require `admin` (broken access control), and that same endpoint has an
  independent OS command-injection bug. No SQL injection is needed anywhere in this
  path.
- **Path B** — a SQL injection on `/login` bypasses authentication entirely into an
  `admin` session, and that session unlocks a *correctly access-controlled* endpoint
  that is nonetheless a raw SSRF. No command injection, no host pivot, no privesc is
  needed anywhere in this path.

Walking only one of these and writing a report that implies the *other* doesn't exist
is the single most common gap in a rushed real-world assessment — not because the
tester was careless about the bug they found, but because they stopped looking once
something worked. Today asks you to walk **both**.

### An honest note on stage ordering

The plan for this lab describes the chain as "recon → web foothold → host privesc →
cloud credential access," and that's the order this content presents things in below.
But — named precisely rather than glossed over — Path B's cloud-credential-access stage
does **not** technically depend on Path A's host-privesc stage at all; it only depends
on Path B's own SQL injection. The two paths converge on "you've now fully compromised
this environment," not on a single shared sequence of prerequisites. Treat the ordering
below as a **reading order**, not a **dependency graph** — your own findings report
(Section 4) should reflect which is actually true for what you did.

### Findings report — today's real deliverable

A **findings report** is the artifact that makes an attack matter to anyone besides the
attacker: it's what a defender, a manager, or (in Day 21) *your own future self* uses to
fix what you found. `labs/capstone/report-template.md` gives you the shape; today you
fill in Sections 1–6 (summary, scope, architecture, methodology, findings, narrative).
Write it as you go, immediately after each stage — not from memory at the end. The
discipline of writing evidence down the moment you have it, rather than trusting you'll
remember it later, is the same spaced-retrieval habit `content/STRATEGY.md` and every
prior day's journal entry have been building.

## 2. Attack Lab — Compromise the Environment, Both Ways

**Authorized use only:** everything below targets the containers `labs/capstone/`
starts (plus, only if you explicitly opt in, your own AWS sandbox account — see "Real
AWS mode" below). Never point any of this at a system you don't own.

**Setup:**

```sh
cd cyber_security/labs/base && ./up.sh        # if not already running
cd ../capstone && ./setup.sh                  # Docker only, free
```

This is a genuine capstone: the objectives and a **hints ladder** are below, not a
worked walkthrough. Attempt each stage for real, with real tools, before opening a
hint. `labs/capstone/SOLUTION-attack.md` has the complete, captured-real chain — treat
it as a last resort, or as a way to check your own work afterward, not as step one.

### Stage 1 — Recon

**Objective:** find out what `webapp` actually exposes before touching anything else.

**Hint 1 (nudge):** you already know how to do this — it's Day 1's whole subject. What
does the target itself tell you if you just ask it politely?

**Hint 2 (bigger nudge):** `curl -s webapp:5000/` from `attacker`. Read what comes
back literally — it names its own routes.

**Hint 3 (answer):** `SOLUTION-attack.md`, "Setup."

### Stage 2a–2b — Web foothold, Path A: broken access control → command injection

**Objective (2a):** get a normal account, then reach an endpoint that should
require `admin` but doesn't check for it. **Objective (2b):** turn that same endpoint's
missing input sanitization into arbitrary command execution.

**Hint 1 (Stage 2a):** registration is open to anyone (`POST /register`). Once you have
*any* session, try the admin-sounding routes the landing page named — does the server
actually check *which* role your session has, or just *that* you have one at all?

**Hint 2 (Stage 2b):** `/admin/diagnostics?host=...` runs something that looks a lot
like a shell `ping` command with your `host` value spliced straight in. What happens if
your `host` value isn't a hostname at all, but a hostname *followed by* a shell
metacharacter and a second command?

**Hint 3 (answer):** `SOLUTION-attack.md`, "Path A, Stage 2a–2b."

### Stage 3 — Lateral movement and host privilege escalation

**Objective:** using only the shell you just landed on `webapp`, reach `host` — a box
`attacker` has no route to at all — and escalate to root there.

**Hint 1:** your command-injection primitive can run *any* command `webapp`'s own
container can run. What's sitting in `webapp`'s own filesystem, right next to the app
code, that a rushed deploy might have left behind? (You already have the tool to find
out — you just used it in Stage 2.)

**Hint 2:** once you have a credential for `host`, you don't need `attacker` to reach it
at all — `webapp`'s container already has an SSH client installed, and it already has a
network route to `host`. Chain the SSH call *inside* the same injection primitive you
used in Stage 2, rather than trying to reach `host` directly.

**Hint 3:** on `host`, check `sudo -l` as the account you land as. GTFOBins
(https://gtfobins.github.io/) documents exactly what a passwordless-sudo rule on a full
language interpreter lets you do — you've already used a version of this idea in
Day 5.

**Hint 4 (answer):** `SOLUTION-attack.md`, "Path A, Stage 3."

### Stage 2c & 4 — Web foothold + cloud credentials, Path B: SQL injection → SSRF → theft

**Objective (2c):** bypass `/login` with a SQL injection to obtain an `admin` session.
**Objective (4):** use that session's access to a *correctly* access-controlled fetch
feature to reach a network address `attacker` itself can never reach — and use what
that address hands back.

**Hint 1 (Stage 2c):** `/login`'s query is built by directly inserting your username
and password into a SQL string. What single SQL comment syntax, placed inside your
*username* field, makes everything after it — including the password check — simply
not exist to the database?

**Hint 2 (Stage 4):** once you're `admin`, `/admin/fetch?url=...` fetches *any* URL you
give it, server-side, with no restriction at all on what addresses count as "safe."
Real cloud compute has a well-known, specific address reserved for instance metadata —
you've already seen this exact number in this path's ROADMAP cross-references even
before reaching this day. What happens if you hand that address to `/admin/fetch`
instead of a normal website?

**Hint 3 (Stage 4):** the metadata response names a role, then hands back credentials
for that role at a follow-up path under the same address. Once you *hold* those
credentials, you don't need `/admin/fetch` — or `webapp` — at all anymore. Where else in
this environment would a real stolen AWS credential actually get used, and what does
that service expect you to prove you're holding it?

**Hint 4 (answer):** `SOLUTION-attack.md`, "Path B."

### Real AWS mode (optional)

Everything above runs entirely in Docker, for free, against `fake-imds`/`fake-s3`. If
you want the genuine experience of SSRF reaching *real* EC2 instance metadata instead
of a simulation: `./setup.sh --with-aws` provisions a real, scoped IAM role + instance
profile + S3 bucket in your own AWS sandbox account (never hardcodes a credential —
named profile only), and prints exactly how to attach that instance profile to a real
EC2 instance running this lab's `webapp`+`host`+`fake-s3` (skip `fake-imds` — the real
IMDS is already sitting at `169.254.169.254` on any real EC2 instance). This is
entirely optional; every stage above is fully exercisable, and fully counts, without
it. If you do use it: **run `./teardown.sh --with-aws --bucket <name>` before Day 21
grades anything left running**, and never leave a live EC2 instance up longer than the
lab needs.

## 3. Defense Lab — Reflection Pass (the fixes themselves are Day 21's job)

Today's Defense Lab is deliberately light: you just spent real effort finding these
bugs, and jumping straight to fixing them would skip the step that makes Day 21's fixes
actually land — writing down, precisely, what you'd change and why, **before** you're
told the answer.

For each finding in your `report-template.md` (Section 5), write one sentence naming
the *category* of fix you'd apply — not the exact code, just the shape of the fix:

- CAP-1 (broken access control): *"restore the missing ___ check."*
- CAP-2 (command injection): *"stop building a ___ string; use a ___ instead."*
- CAP-3 (leaked credential): *"___ the credential; stop storing it ___."*
- CAP-4 (host privesc): *"remove the ___ rule granting ___."*
- CAP-5 (SQL injection): *"use a ___ query instead of ___."*
- CAP-6/CAP-7 (SSRF / IMDSv1): *"require a ___ before metadata is served."*

Fill in the blanks yourself before Day 21 — you'll compare your answers against
`SOLUTION-defend.md`'s actual fixes and re-verified before/afters there.

## 4. Drills

Attempt each drill yourself before reading its solution sketch. These are separate,
short exercises — the capstone attack chain above is the main event; these check
specific concepts from it.

### Drill 1 — Name the kill-chain stage for each action

For each action below, name the kill-chain stage (recon / foothold / escalation /
lateral movement or pivot / objective) it belongs to:

1. Reading `webapp`'s landing page to see its route list.
2. Using `webapp`'s own SSH client to reach `host`.
3. Running `sudo python3 -c '...'` on `host`.
4. Reading the confidential object from `fake-s3` with stolen credentials.

**Hint:** ask what each action's *purpose* was at the moment you did it, not what tool
you happened to use.

**Solution sketch:** (1) recon — nothing was exploited, only observed. (2) lateral
movement / pivot — specifically, using an already-compromised host's own network
position to reach a segment the attacker couldn't reach directly. (3) escalation —
turning a low-privilege foothold (`opsuser`) into a higher-privilege one (`root`) on the
*same* host, not a move to a new host. (4) objective — this is the actual goal the
chain was working toward, not a step that gets you *closer* to access; it's the payoff
itself.

### Drill 2 — Why Path A and Path B are genuinely independent

In two or three sentences: explain why fixing only Path A's bugs (access control,
command injection) while leaving Path B's bugs (SQL injection, SSRF) unpatched still
leaves this environment fully compromisable, and vice versa.

**Hint:** trace each path's very first step back to what it actually depends on —
does either path's first move require anything the other path produced?

**Solution sketch:** Path A's first move is registering a free account and finding a
missing role check; it never touches `/login`'s query logic at all. Path B's first move
is the SQL injection on `/login`; it never touches `/admin/diagnostics` or `host` at
all. Neither path's starting point is gated by anything the other path produces, so
patching one path's bugs removes exactly that path and nothing else — an attacker who
tries the *other* set of bugs succeeds exactly as before. This is precisely why Day 21's
Defense Lab has to apply (and separately re-verify) fixes for **both** paths, not just
whichever one you happened to find first.

### Drill 3 — Pick the highest-impact finding and justify it

Of CAP-1 through CAP-7, pick the single finding you'd rank as highest-severity if you
were writing this up for a real organization, and justify it in two sentences.

**Hint:** severity isn't "which one felt hardest to exploit" — it's about *impact*
(what does an attacker actually get) combined with *likelihood* (how little skill or
access does it take).

**Solution sketch:** reasonable answers differ, but the strongest case is usually
**CAP-5 (SQL injection auth bypass)** or **CAP-1 (broken access control)** — both are
the *first* bug in their respective chains, require zero prior access, and each one
alone (even before any later stage) already grants a privilege boundary crossing
(anonymous → admin, or anonymous → an endpoint that should be admin-only) with no
special skill beyond knowing the technique. CAP-4 (host privesc) and CAP-7 (IMDSv1) are
serious, but both require an earlier bug to even become reachable — they compound
impact, they don't create the initial entry point.

### Drill 4 — Draw the boundary-crossing map from memory

Without looking back at Section 1's architecture diagram, draw (or list) which networks
`attacker`, `webapp`, `host`, `fake-imds`, and `fake-s3` are each on, and mark which
pairs can reach each other directly.

**Hint:** there are exactly two "cannot reach directly" pairs that matter for this
lab's whole story — name both, and name which mechanism (pivot vs. SSRF) crosses each
one.

**Solution sketch:** `attacker`–`webapp`: direct (`cyberlab`). `attacker`–`fake-s3`:
direct (`cyberlab`). `attacker`–`host`: **no direct route** — crossed only via pivoting
through `webapp`'s own shell over the `internal` network. `attacker`–`fake-imds`: **no
direct route** — crossed only via tricking `webapp` into fetching it (SSRF) over the
`imds` network. `webapp`–`host` and `webapp`–`fake-imds`: both direct (that's *why*
`webapp` can be used to cross either boundary on the attacker's behalf).

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file —
and also start filling in `labs/capstone/report-template.md` Sections 1–6 now, while
everything is fresh, rather than after Day 21.

- **What I attacked:** name both paths explicitly, and which specific findings (CAP-1
  through CAP-7) you personally reproduced yourself versus which (if any) you only
  confirmed by reading `SOLUTION-attack.md`.
- **How:** which hint level did each stage actually take — did any stage need the
  full answer, and if so, what specifically didn't click from the nudge alone?
- **What defended it:** you haven't applied any fixes yet — instead, name the one
  finding you're most confident you already know the right fix category for (Section 3
  above), and the one you're least sure about.
- **What confused me:** the multi-layer shell-quoting needed to chain the pivot through
  a single HTTP request is a real, common point of friction — did it trip you up, and
  if so, what finally made it click?
- **One thing to revisit:** pick one term from today (kill chain, lateral movement,
  pivot, findings report) to re-explain from memory before Day 21, without looking back
  at this file.

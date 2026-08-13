# Day 21 — Capstone II: Harden, Detect, Report + Roadmap Update

## Objectives

By the end of today you should be able to:

- Apply a **specific, correct-category** control to each Day 20 finding — not a vague
  "add validation," but the exact fix shape (parameterization, an access-control check,
  an argument list instead of a shell string, a token requirement, a scoped policy) —
  and then **prove** it works by re-running the *exact same* Day 20 payload and watching
  it fail.
- Explain **defense-in-depth** from firsthand evidence: point to at least one Day 20
  finding where you applied *two* independent controls to the same underlying chain,
  and say what each one specifically stops that the other doesn't.
- Distinguish a **compensating control** (bounds the damage a bug still allows) from an
  actual **fix** (removes the bug), using this lab's own IMDSv2-vs-least-privilege
  distinction as your worked example.
- State the **residual risk** that remains even after every Day 20 finding has a
  control applied — honestly, not as a formality.
- Write a complete attack-and-defense report (`labs/capstone/report-template.md`, all
  ten sections) and use it to decide your next specialization from `ROADMAP.md`'s
  Extension Modules.

## 1. Concept — Defense-in-Depth, Compensating Controls, and Residual Risk

### Defense-in-depth, demonstrated rather than defined

**Defense-in-depth** means a single failure shouldn't be the whole story — multiple,
independent layers each have to fail before an attacker reaches the objective. Day 20's
Path A gives you a real instance of this, not just the textbook phrase: `/admin/
diagnostics` had **two separate bugs** stacked on the same endpoint — broken access
control (who can call it) and command injection (what calling it can be tricked into
doing). Today's Fix 2 and Fix 3 are two *independent* layers over that same endpoint.
If you apply only Fix 2 (the role check) and something *else* in this app ever calls
that same vulnerable `ping` logic with attacker-influenced input, the command injection
is still live — Fix 3 exists precisely so that scenario is *also* covered. Conversely,
if you apply only Fix 3 and somehow miss Fix 2, at least a non-admin can no longer
reach the endpoint at all. Neither fix alone is "the fix" — together, they're
defense-in-depth on one small piece of code.

### Compensating control vs. remediation — the same bug, two different responses

A **remediation** removes the underlying bug: Fix 1 (parameterized queries) means the
SQL injection *cannot happen anymore*, structurally, regardless of what string an
attacker sends. A **compensating control** doesn't remove the bug — it bounds what the
bug is *worth* if it's still exploited. This lab's cloud-credential stage gives you the
cleanest possible contrast between the two, and today asks you to apply and re-verify
both, precisely because they answer different questions:

- **IMDSv2 (Fix 4a)** is close to a remediation for *this specific SSRF shape*: it
  makes the plain GET-relay SSRF `/admin/fetch` offers insufficient to reach
  credentials at all, full stop, for that attack shape.
- **The scoped `iam-policy-after.json` (Fix 4b)** is a pure compensating control: it
  does **nothing** to prevent the SSRF or the credential theft — a stolen credential is
  still stolen. What it changes is what that stolen credential is *worth*: scoped to one
  bucket instead of `s3:*` on every resource in the account.

A mature security posture applies both, for the same reason a bank has a vault *and*
insurance: one tries to stop the theft, the other bounds the loss when a control
somewhere still fails. Neither replaces the other.

### Residual risk — the honesty this whole day is really about

**Residual risk** is what's still true after every control you can reasonably apply has
been applied. It is not a confession of failure — every real system has some. What
*is* a failure is not naming it. `SOLUTION-defend.md`'s Fix 4 section names one
directly: IMDSv2 stops *this exact SSRF shape*, but an SSRF bug living inside code that
already legitimately talks to IMDS (and so already performs the token dance for its own
normal operation) could still relay a "logged in" request through that same
legitimate flow. Today's report (Section 8) asks you to write your own residual-risk
statement for this environment, honestly, the same way.

### Remediation is a verb, not a checkbox

The single biggest failure mode this day exists to prevent: marking a finding "fixed"
because the patch *looks* right, without re-running the attack that proved the bug
existed in the first place. Every fix below is re-verified in exactly that way — the
identical `curl` command from Day 20, run again, now expected to fail. Do that
yourself, for every finding, before you write "Verified" in your own report's Section 7.

## 2. Re-Attack Lab — Prove Yesterday's Chain Now Fails

**Authorized use only** — same scope as Day 20.

Today's "attack lab" is running Day 20's exact attack again, against the environment
you're about to harden, both **before** each fix (to reconfirm the baseline still
behaves as Day 20 found it) and **after** (to prove the fix actually changed the
outcome). Do not skip the "before" half — a fix that "works" against a payload you
never actually re-confirmed was still live first proves nothing.

**Hint 1:** you already have every payload you need — they're the exact commands in
your own Day 20 `report-template.md` Section 6, or `SOLUTION-attack.md` if you didn't
capture them precisely enough to reuse verbatim.

**Hint 2:** apply fixes one at a time, re-running *only that fix's* payload each time,
before moving to the next — mixing several fixes together and then testing once tells
you the combination works, not which fix did the work.

**Hint 3 (answer / full worked before-after for every fix):** `SOLUTION-defend.md`.

## 3. Defense Lab — Apply and Re-Verify Every Control

Work through these in the order below — it matches Day 20's Path A then Path B
ordering, and Fix 2/Fix 3 deliberately sit next to each other since they're the
defense-in-depth pair described in Section 1.

### Fix 1 — Parameterize the injection (closes CAP-5, SQL injection)

**Hint:** SQLite's Python driver accepts a query string with `?` placeholders and a
*separate* tuple of values — look at `webapp/app.py`'s `login()` and replace the
f-string with exactly that shape, then rebuild and re-run Day 20's `admin' -- ` payload.

### Fix 2 — Fix access control (closes CAP-1, broken access control)

**Hint:** `diagnostics()` checks `"user" in session`. What's the one-word change that
checks the *right* thing instead?

### Fix 3 — Stop building a shell string (closes CAP-2, command injection — independent of Fix 2)

**Hint:** `subprocess.getoutput(f"...")` always goes through a shell. Python's
`subprocess.run` accepts a **list** of arguments instead of one string — with a list,
there is no shell at all, so shell metacharacters in any single argument are just
literal characters to whatever program you're calling.

### Fix 4a — Enforce IMDSv2 (raises the bar on CAP-6/CAP-7 — no webapp code change needed)

**Hint:** this fix lives entirely in one environment variable, not in `webapp/app.py`
at all: `IMDS_MODE=v2 docker compose up -d --force-recreate fake-imds`. Re-run Day 20's
exact metadata-theft payload afterward with zero other changes.

### Fix 4b — Scope the role to least privilege (a compensating control, not a fix, for CAP-6/CAP-7)

**Hint:** only relevant if you ran `setup.sh --with-aws`. Diff `policies/iam-policy-
before.json` against `policies/iam-policy-after.json` — what specifically changed
about `Action` and `Resource`, and what could the "before" version reach that the
"after" version can't?

### Fix — Remove the host privilege-escalation path (closes CAP-4)

**Hint:** the vulnerability is a single file: `/etc/sudoers.d/opsuser` on `host`. What
does removing it (or rebuilding `host` without creating it) do to `sudo -l` for
`opsuser`, and to the exact `sudo python3 -c ...` command Day 20 used?

### Fix 5 — Add detection

**Hint:** run `./detection/detect.sh` against a log that has at least one full
Day 20 attempt (both paths) in it. Read its four `---` sections — does each one fire on
the payload it's supposed to catch, and can you find a variant of any payload that
*wouldn't* trip it? (Drill 3 below asks you this directly.)

**Full worked before/after for every fix above, captured for real:**
`labs/capstone/SOLUTION-defend.md`.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Map each Day 20 stage to the control that stops it

For each Day 20 stage (2a broken access control, 2b command injection, the leaked
credential, 3 lateral movement/privesc, 2c SQL injection, 4 SSRF/IMDSv1), name the one
fix from Section 3 that closes it.

**Hint:** go stage by stage — each Day 20 finding maps to exactly one primary fix
above, even though some fixes reinforce each other.

**Solution sketch:** 2a → Fix 2 (role check). 2b → Fix 3 (argument-list subprocess).
leaked credential → not separately re-demonstrated as a live fix in this lab (the real
remediation is rotating the credential and never placing one in a web root at all —
applying Day 10's secrets-sprawl lesson); Fixes 2 and 3 already block the path that
would discover it. 3 (lateral movement/privesc) → remove the `sudoers.d` rule on
`host`. 2c → Fix 1 (parameterized query). 4 (SSRF/IMDSv1) → Fix 4a (IMDSv2) as the
near-remediation, Fix 4b (scoped policy) as the compensating control alongside it.

### Drill 2 — Prove one control works (before/after)

Pick any one fix from Section 3, apply it yourself, and re-run its exact Day 20 payload
against both the unpatched and patched code. Write down the literal before/after output
you observed — not what you expect it to say.

**Hint:** the SQL injection fix (Fix 1) is the easiest to get a crisp before/after for,
and to double-check you didn't break the legitimate login path while you were at it.

**Solution sketch:** see `SOLUTION-defend.md`'s Fix 1 section for the exact captured
before (`{"role":"admin","status":"logged in","username":"admin"}`) and after
(`{"error":"invalid username or password"}`), plus the confirmation that a normal
registered account still logs in successfully on the same patched code — the point of
this drill is that *you* produce this pair yourself, not that you read someone else's.

### Drill 3 — What detection fires for the residual risk

Section 1 named a residual risk for the IMDSv2 fix: an SSRF bug in code that
*legitimately* needs to talk to IMDS (and so already performs the token dance for its
own normal operation) could still relay a "logged in" request through that legitimate
flow. Would `detection/detect.sh`'s `[SSRF]` rule catch that variant? Justify your
answer by naming exactly what the rule checks.

**Hint:** open `detection/detect.sh` and read the literal pattern the `[SSRF]` section
greps for — is it checking "this request is suspicious in general," or one specific
string?

**Solution sketch:** yes, actually — the rule matches on the literal string
`169.254.169.254` appearing in an `/admin/fetch` request, regardless of *how* the
request obtained a valid token, so a relayed-through-legitimate-flow variant would
still be flagged as long as it's still targeting that literal address through that
literal endpoint. What the rule would **not** catch is an SSRF reaching a *different*
internal-only address this lab doesn't define at all, or one arriving through a
completely different endpoint. This is Section 1's fidelity-vs-noise tradeoff again:
a literal-string rule has very few false positives but a narrow blast radius of what it
actually covers — Day 11's future content builds toward real IP-range-based rules that
trade a little more noise for a lot more coverage.

## 5. Report, Roadmap, and Choosing What's Next

### Finish the report

Complete `labs/capstone/report-template.md` Sections 7–10 (Remediation Plan, Residual
Risk, Detection Coverage, Retrospective) — you already have Sections 1–6 from Day 20.
The finished ten-section document is this path's main deliverable.

### Success-criteria checklist

Before you consider this path complete, confirm you can honestly check every box below
— each one maps to a specific piece of work you just did:

- [ ] **Threat-model** — Day 0's STRIDE walkthrough, and today's Section 3's-worth of
      naming *which* control category closes *which* bug, are the same skill applied
      twice, three weeks apart.
- [ ] **Attack** — Day 20's two independent, fully-reproduced chains (Path A and
      Path B), captured in your own `report-template.md` Sections 1–6.
- [ ] **Harden** — today's Section 3, with every fix re-verified against the exact
      Day 20 payload, not assumed correct from reading the code.
- [ ] **Detect** — `detection/detect.sh` run against a real attack log, plus Drill 3's
      honest accounting of what it does and doesn't catch.

### Update `ROADMAP.md`

The whole 21-day foundations block is complete once today's work is done. `ROADMAP.md`
gets marked accordingly (see this task's own completion report for the exact roadmap
row/coverage-table update, applied by whoever integrates this lab into the shared
docs) — and its **Extension Modules** section is where you pick what's next. Read that
section now and pick one module based on which parts of this path you found most
compelling versus most uncomfortable — discomfort is usually the better signal of where
you have the most room to grow.

## 6. Journal Prompt — The Final Retrospective

This is the last entry in this path. Open `journal.md` and write it using the entry
template at the top of the file, answering all five of its normal prompts for today's
work — **and then add this final retrospective**, verbatim, as its own entry
immediately after:

```
### Capstone Retrospective — the whole path (YYYY-MM-DD)

**The single most valuable thing I built:** <not "learned" -- built. A skill, a habit,
or an artifact from this path you'd actually reach for again.>

**The bug class I now recognize fastest:** <across all 21 days, which vulnerability
pattern do you now spot on sight, in code or in a report, without having to think
about it?>

**The stage I'm still least confident in:** <recon, foothold, escalation, lateral
movement, detection, or reporting -- name the one weakest link honestly, the same way
Section 1's residual-risk habit asks you to name a system's weakest link honestly.>

**What "attacker mindset before tools" (STRATEGY.md, Day 0) actually meant by the end:**
<in your own words now, not the definition you'd have given on Day 0.>

**My next specialization, and why:** <the Extension Module you picked from ROADMAP.md,
and the one sentence that made you pick it over the others.>
```

Fill this in before you consider the path finished — it's the one piece of this whole
22-module path that only you can write, and the only one nobody will ever check for
you.

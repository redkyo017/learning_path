# STRATEGY — The Top 1% Playbook

Most people who study security accumulate facts. The top 1% build a loop: they form a
hypothesis about how a system breaks, break it, fix it, and instrument it so the break
can't happen silently again — then they write down what changed in their own
understanding. Every principle below is a piece of that loop. None of them are optional
extras; skip one and the loop stops compounding.

This file is the "why" behind how the days in this path are structured. `journal.md` is
where you prove you're actually doing it.

## 1. Attacker Mindset Before Tools

A tool tells you *how* to do something you've already decided to do. It never tells you
*what's worth doing*. Before you touch `nmap` or `sqlmap`, you need to be able to look at
any system and ask: what does this trust, what does it assume, and what happens if that
assumption is false? That question is transferable across every tool you'll ever pick up
or retire.

**Do this:** before every attack lab in this path, spend two minutes writing one sentence
— on paper or in the lab's scratch notes — answering "what is this target *trusting*
that an attacker could violate?" *before* you run a single command. If you can't answer
it, you're not ready to attack the target yet; go read the concept section again. This
sentence is also your fastest way into that day's threat model (Principle 6).

## 2. Learn by Breaking — Build → Break → Fix → Detect

Reading about a SQL injection teaches you what a SQL injection is. Exploiting one, then
patching it, then re-running the exact same exploit against the patched version and
watching it fail, then wiring up a detection and watching it fire — that teaches you what
a SQL injection *does*, at every layer, permanently. This four-step loop is the anatomy
of every day in this path (attack lab → defense lab), and it's the single habit that
separates people who can recite OWASP Top 10 from people who can secure a real system.

**Do this:** never close a lab after the attack step. Every attack lab has a matching
defense lab in the same day's content file — always run both, in order, and always
re-attempt the attack after applying the fix to confirm it's actually blocked (not just
that you *believe* it's blocked). If a day's lab includes a detection step, don't skip
it because the attack "already worked" — the detection is what turns a one-time exploit
into something you'd catch in production.

## 3. Fundamentals Compound; Tools Are Transient

`sqlmap` will be replaced by something else. TCP, the HTTP request/response model, how
permissions and privilege boundaries work, how cryptographic primitives fail when
misused — those don't get replaced. They're the substrate every new tool and every new
CVE sits on top of. Someone who understands *why* a SYN scan works can pick up any new
scanner in ten minutes; someone who only knows scanner flags is stuck the day the flags
change.

**Do this:** whenever a lab introduces a tool, spend one extra sentence in your journal
entry on the underlying mechanism the tool is exploiting, not the tool's syntax — write
"why this works" instead of "what I typed." When you hit Day 6, 12, or 18's
consolidation CTF and a tool misbehaves or isn't installed, treat that as a test: can
you reconstruct the attack manually from the fundamental (a raw `curl`, a hand-crafted
packet, a manual hash comparison) instead of being blocked by a missing binary?

## 4. Spaced Retrieval via Writeups

Knowledge you don't retrieve decays. The fix isn't more reading — it's retrieval:
forcing your own brain to reconstruct what happened without looking at the lab's
`SOLUTION.md`. Writing a short summary from memory, a day or a week after the fact, is
one of the most effective ways to convert a lab into something you can still do cold in
three months.

**Do this:** fill in the `journal.md` entry for a day *the same day you finish it*,
before you move to the next day, and do it from memory — don't reopen the content file
or `SOLUTION.md` while writing it. Then, before starting each phase's consolidation CTF
(Day 6, 12, 18), reread your last week of journal entries without touching any lab
files. If you can't reconstruct "what I attacked" and "what defended it" from your own
one-paragraph entry, that's a signal to redo the lab, not to move on.

## 5. Read Real CVEs & Advisories Early

Labs teach you exploitation patterns in a controlled setting. Advisories teach you how
those patterns show up, get discovered, and get fixed in the wild — and reading them is
a skill in its own right that most self-taught people never practice because it feels
less hands-on than running an exploit. It isn't optional: the ability to read a CVE
description and CVSS vector and immediately know "is this exploitable in my environment,
and how bad is it" is a top-1% differentiator, and it only comes from repetition.

**Do this:** starting Day 1, read one real advisory per week using the checklist below,
and log the one-line takeaway in your journal entry for that day. Don't wait for a
"CVE day" in the curriculum — this is a standing habit layered on top of the daily
labs.

**Advisory reading checklist** (apply to any CVE):
1. **Description** — what class of bug is this (injection? deserialization? auth
   bypass?) and where does it live (which component, which input)?
2. **CVSS vector** — decode the string, don't just read the score. `AV` (attack vector:
   network vs local), `AC` (attack complexity), `PR` (privileges required), `UI` (user
   interaction), and the `C`/`I`/`A` impact triad tell you *how* it's exploited, not just
   how scary it sounds.
3. **Affected versions** — is the vulnerable code path actually reachable in the default
   configuration, or does it need a non-default feature enabled?
4. **Root cause** — read past the summary to the actual mechanism (often in the vendor
   advisory or the patch diff, not the CVE entry itself).
5. **Exploitability** — is there a public PoC? If so, that's the gap between "theoretical"
   and "mass-scanned within days."
6. **Fix** — what did the patch actually change, and would a compensating control (WAF
   rule, network restriction, config flag) have mitigated it before the patch existed?

**Worked example — CVE-2021-44228 ("Log4Shell")**

- *Description:* Apache Log4j2's JNDI message-lookup feature would resolve attacker-
  controlled strings (e.g. embedded in a `User-Agent` header) as JNDI lookups, allowing
  a remote server reference to be fetched and its class deserialized/executed. This is a
  logging library treating untrusted input as *code to resolve*, not data to record —
  the same injection root cause you'll see in Day 8, just in an unexpected sink.
- *CVSS vector:* `AV:N/AC:L/PR:N/UI:N/S:C/C:H/I:H/A:H` (CVSS 10.0). Read it in order:
  network-reachable, low complexity, no privileges needed, no user interaction, scope
  changed (it escapes the vulnerable component), and full loss of confidentiality,
  integrity, and availability. That vector alone tells you this is wormable before you
  read a single paragraph of prose.
- *Affected versions:* Log4j2 2.0-beta9 through 2.14.1 — meaning almost anything built
  in the prior seven years that logged untrusted input through a default Log4j2 config
  was in scope. The "is the vulnerable path reachable by default" question was
  answered: yes, that's why it was catastrophic.
- *Root cause:* the JNDI lookup feature (`${jndi:ldap://...}`) was enabled by default and
  interpolated into log messages before writing them — the fix disabled JNDI lookups by
  default and later removed the message-lookup substitution entirely.
- *Exploitability:* a PoC (a single crafted header value) was public within hours,
  confirmed by the near-immediate mass internet scanning that followed.
- *Fix / compensating control:* upgrade to a patched release; if you couldn't patch
  immediately, setting `log4j2.formatMsgNoLookups=true` or removing the `JndiLookup`
  class from the classpath mitigated it before patching — exactly the kind of "control
  that would have stopped it" reasoning you practice in every day's defense lab.

## 6. Threat Model (STRIDE) as a Daily Habit

Threat modeling isn't a one-time architecture-review exercise — it's a five-minute habit
you run on *any* system before deciding where to spend attack time. STRIDE
(Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation
of privilege) is a checklist, not a research project: it forces you to consider
categories of failure you'd otherwise skip because they're not the first thing that
comes to mind.

**Do this:** before each day's attack lab, spend five minutes STRIDE-classifying the
day's target using its docker-compose services and network diagram as the
"architecture": one sentence per category, even if some categories are "not applicable
to this target." Day 0 walks through a full example (browser → web app → DB → S3) so you
have a template to reuse every day after. This is the same five-minute habit as
Principle 1's trust-question — STRIDE is just the structured version of it once a system
has more than one component.

## 7. Reverse the Kill Chain for Defense

The kill chain (recon → weaponization → delivery → exploitation → installation →
command & control → actions on objectives) is usually taught as an attacker's model. Its
real value to a defender is running it backwards: for every stage, ask "what evidence
would this stage leave, and am I collecting it?" Defense that only reacts to the final
stage (data exfiltration, ransomware detonation) is defense that's already too late;
defense built stage-by-stage from recon onward catches the attacker while they're still
cheap to stop.

**Do this:** for every attack you run in this path, before moving to that day's defense
lab, write down which kill-chain stage it corresponds to and one telemetry source that
stage would touch (a log line, a network flow, a process spawn). Day 11 formalizes this
into an actual detection stack, but the habit of mapping attack-stage → telemetry starts
Day 1 with recon and banner-grabbing, and every later day adds one more stage to the
chain you're defending.

## How to Run a Day of This Path

Every day follows the same rhythm — this is the loop all seven principles above feed
into:

1. **Read the concept section.** Don't skip to the lab; the concept section is where the
   "why" lives that the lab won't teach you on its own.
2. **STRIDE the day's target** (Principle 6) — five minutes, before touching a command.
3. **Run the attack lab** (Principle 2) — with the trust-question from Principle 1
   already answered, and the kill-chain stage from Principle 7 noted as you go.
4. **Run the defense lab** — apply the fix, then re-run the attack to confirm it's
   actually blocked or detected. Never skip this re-run.
5. **Do the drills** — use the hints ladder if stuck, but check your answer against the
   solution sketch only after attempting it, not before.
6. **Write the journal entry** (Principle 4) — same day, from memory, before starting
   the next day.
7. **On your own cadence, spend part of one day a week reading a real advisory**
   (Principle 5) using the checklist above, and note the takeaway in that day's journal
   entry.

If you only have time for a partial day, do steps 2–4 and skip the drills before you'd
ever skip the journal entry — the loop only compounds if the writeup happens.

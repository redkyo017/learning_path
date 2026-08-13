# Antipatterns — the 80% time-wasters

Most people who "study cybersecurity" for a year and can't do anything hands-on didn't
fail because the field is too hard. They fell into one or more of the patterns below.
Each one *feels* productive while you're doing it — that's what makes it a trap. Read
this once before Day 0, then reread it whenever a day feels like a grind and some other
activity looks more appealing.

Each entry: **Symptom → Why it wastes time → The fix.**

---

## 1. Cert-chasing before hands-on

**Symptom:** You're planning your Security+/CEH/OSCP study schedule before you've run a
single attack against a target you built yourself. Certifications feel like the "real"
credential, so they jump to the top of the queue.

**Why it wastes time:** Certifications test recall of vocabulary and multiple-choice
scenarios, not the ability to actually compromise or defend a system. Studying for one
before you have hands-on reps means memorizing terms for concepts you've never touched —
the knowledge doesn't stick, and you'll relearn most of it (properly, this time) the
first time you try to use it. Worse, cert study has a defined syllabus and a test date,
which makes it *feel* like progress even when it produces no transferable skill.

**The fix:** Do this path first. Every day here is build → break → fix → detect against
a real (if small) target — that's the skill certs claim to test. If you want a cert
afterward, you'll study for it in a fraction of the time because the labs already gave
you the muscle memory. See `content/STRATEGY.md`'s "learn-by-breaking" principle, and
don't open a cert syllabus until you've finished at least Phase A (Days 0–6).

---

## 2. Tutorial / passive-video hell

**Symptom:** You've watched dozens of hours of "Hacking Tutorial" or "Day in the Life of
a Pentester" videos. You can narrate what the presenter did. You've never typed the
commands yourself on your own machine.

**Why it wastes time:** Watching someone else run `sqlmap` is not the same skill as
running it yourself, reading its output, and deciding what to do when it doesn't work
the way the video showed. Passive video gives you recognition memory ("I've seen this
before") without recall or troubleshooting ability — and troubleshooting *is* the job.
Hours of video compound into zero hours of debugging experience, which is the thing that
actually transfers to a real engagement.

**The fix:** Every day in this path is lab-first: you stand up `labs/dayNN` yourself,
run the attack yourself, and when something breaks (wrong container IP, a tool flag that
changed, a payload that gets filtered), you debug it yourself before checking
`labs/dayNN/SOLUTION.md`. If you catch yourself watching a video about a topic this path
covers, close it and go run the lab instead — the video's shortcuts will make more sense
*after* you've hit the problem it's shortcutting past.

---

## 3. Tool-collecting & Kali distro-hopping

**Symptom:** You've reinstalled Kali three times, tried Parrot OS and BlackArch "to
compare," and you have forty offensive tools installed but have used maybe five of them
past `--help`. Choosing a distro or curating a toolkit feels like real work.

**Why it wastes time:** The tool is not the skill. A new tool with default settings
against a target you don't understand produces noise, not compromise. Distro-hopping
resets your environment and your muscle memory every time, and evaluating tools you
haven't needed yet is speculative work with no target to validate against.

**The fix:** This path gives you one attacker toolbox — `labs/base` — built once in Task
2 and reused for all 22 days. It has a fixed, deliberately small tool list (`nmap`,
`tcpdump`/`tshark`, `netcat`, `john`, `hashcat`, `hydra`, `sqlmap`, `gobuster`, `whatweb`,
`openssl`, and a few more). You will use every tool in it more than once, against a real
target, before you're allowed to wonder if you need a different one. If a day's lab
genuinely needs a tool that isn't there, add it to `labs/base/attacker/Dockerfile` and
move on — don't rebuild the environment.

---

## 4. Skipping fundamentals to jump straight to "hacking"

**Symptom:** You want to run a web app exploit or a privilege-escalation chain today,
but you don't actually know what a TCP handshake is, how a Linux permission bit works,
or what a JWT contains. You skip the boring parts and go straight for the "cool" exploit
tutorials.

**Why it wastes time:** Nearly every real exploit is a fundamentals problem wearing a
costume — SSRF is fundamentally about trust boundaries and network requests, privesc is
fundamentally about permission models, and injection is fundamentally about the
data/code boundary. Without the fundamental, you can reproduce a specific PoC from a
walkthrough but can't adapt it when the target differs even slightly, and you can't
explain *why* the fix works — so you can't build the matching defense either.

**The fix:** This path's structure enforces the order: Phase A/B (Days 0–6) is
networking, crypto, auth, and Linux/OS security *before* Phase C (Days 7–12) touches web
exploitation, and cloud (Days 13–18) comes after both. Don't reorder the day index in
`README.md` to skip ahead to the "exciting" days — the later attacks are built to assume
the earlier fundamentals are already reflexes, and the defense half of each day (the
"fix/detect" steps) is unintelligible without them.

---

## 5. Going too wide too fast (red + blue + cloud + malware at once)

**Symptom:** You're simultaneously trying to learn offensive pentesting, SOC/blue-team
work, cloud security, and malware analysis, switching between four different resources
depending on your mood that day. Nothing gets more than a surface pass.

**Why it wastes time:** Each of those is a deep specialty with its own tool ecosystem,
vocabulary, and muscle memory. Splitting attention across all of them means you never
spend enough consecutive time in any one to get past the "everything is unfamiliar"
phase, which is the slowest and most frustrating part of learning anything. You end up
with four shallow starts instead of one real foundation.

**The fix:** This path sequences depth instead of running tracks in parallel: purple-team
fundamentals first (Days 0–6), then web (7–12), then cloud (13–18), then IR/capstone
(19–21) — and within every single day, offense and defense are paired (build → break →
fix → detect), so you're never doing "pure red" or "pure blue" in isolation either.
`ROADMAP.md`'s Extension Modules section is exactly where the tracks you're tempted to
chase now (malware analysis, SIEM/threat hunting, binary exploitation, OSCP-style
privesc) belong — *after* Day 21, one at a time, each with its listed prerequisite days
already done.

---

## 6. No writeups

**Symptom:** You do a lab, it works, you move to the next one. Nothing gets written
down. A month later you can't explain how the Day 8 SQL injection worked or what
detection rule caught it.

**Why it wastes time:** Doing something once without retrieval practice is one of the
weakest ways to retain it. Without a writeup, you have no spaced-retrieval trigger to
revisit the material, no artifact to show you actually understand it (vs. just clicked
through it), and no record to compare against when a later day's attack rhymes with an
earlier one (which happens deliberately in this path — e.g., the Day 2 port scan and Day
8 injection get replayed and detected in Day 11).

**The fix:** `journal.md` exists for exactly this — a per-day entry (what I attacked, how,
what defended it, what confused me, one thing to revisit) that you fill in *before*
moving to the next day, per `README.md`'s "How to start" step 4 and `content/STRATEGY.md`'s
spaced-retrieval principle. Treat an unfilled journal entry as a day that isn't actually
finished yet, even if the lab technically ran.

---

## 7. `msfconsole` autopwn without understanding the exploit

**Symptom:** You launch Metasploit, run `use exploit/...`, `set RHOSTS`, `exploit`, and
get a shell — and that's the entire mental model. You couldn't explain what the exploit
actually did to the target, what CVE it corresponds to, or what a detection engineer
would look for in the logs.

**Why it wastes time:** A framework that automates exploitation for you is only useful
once you already understand the vulnerability class it's automating — otherwise you've
learned "type these commands in this order" for one specific module, which doesn't
transfer to the next target, the next CVE, or (critically) to building the matching
defense. You also learn nothing about *why* the fix works, because you never saw the
mechanism, only the shell.

**The fix:** Every lab in this path requires you to explain the mechanism before you get
credit for the attack — `labs/dayNN/SOLUTION.md` walks through *why* the exploit works,
not just the commands, and the day's content file pairs every attack with the fix and
the detection signal it should trigger. If a day's target is vulnerable to something
Metasploit could automate, run it manually first (raw `curl`/`nc`/crafted payloads) so
you see the request/response or memory effect yourself; only reach for an automation
framework once you can already explain the vulnerability in your own words.

---

## 8. Ignoring defense entirely

**Symptom:** You find attacking more fun than defending, so you do the attack half of
every lab and skip or skim the "now fix and detect it" half. You can pop a shell but
you've never written a Suricata rule, a CloudTrail alert, or reasoned about what a SOC
analyst would see.

**Why it wastes time:** Purely offensive skill without defensive literacy caps your
ceiling — you can't red-team effectively without understanding what blue teams look for
(or you'll get caught by controls you didn't know existed), and you can't get hired into
most real security roles, which are majority defensive. It also means you never validate
that your attack understanding is *correct*: writing the detection rule for an attack is
a forcing function that proves you understood the mechanism, not just the PoC.

**The fix:** This path's per-day anatomy makes skipping defense structurally impossible
if you follow it as written — "fix" and "detect" are two of the four steps in build →
break → fix → detect, not optional extensions. Day 11 (logging & the blue-team loop) and
Day 16 (cloud detection & response) exist specifically to consolidate this half. If
you're tempted to stop after "attack works," that's the signal the day isn't done.

---

## 9. Only-CTF-never-real-systems

**Symptom:** You're good at capture-the-flag challenges — you can find the flag in a
deliberately-broken box built for a competition — but you've never set up a real service
(a web app, a database, an IAM policy) yourself and then had to secure it against
someone else's attack.

**Why it wastes time:** CTF boxes are built to *have* a solvable path to a flag; real
systems aren't built for you, and most of the difficulty in real security work is in the
ambiguity CTFs deliberately remove — noisy logs, systems that are broken in boring,
non-puzzle ways, defenses that partially work. Pure CTF practice trains puzzle-solving
under artificial constraints, which is a real but narrow skill that doesn't fully
transfer to operating or defending a system you're responsible for.

**The fix:** This path's mini-CTF days (Day 6, Day 12) are consolidation checkpoints,
not the main mode — they come *after* you've built and defended the underlying
components yourself in the preceding days. The other 19 days have you stand up the
target infrastructure yourself (`labs/dayNN/docker-compose.yml`, or in Phase 3 your own
AWS sandbox resources), which is closer to owning a real system than solving someone
else's puzzle box. Keep that ratio if you do outside CTFs for fun — treat them as
dessert, not the main course.

---

## 10. Not reading source / advisories

**Symptom:** You learn about vulnerabilities entirely secondhand — blog post summaries,
video explainers, one-line CVE descriptions — and have never actually read a CVE
advisory, a security bulletin, or the vulnerable source snippet it references.

**Why it wastes time:** Secondhand summaries are lossy and sometimes wrong, and they
train you to consume security news rather than to evaluate it. When a real advisory
lands on your desk during actual work, you need to be able to read it cold — the CVSS
vector, the affected versions, the root cause — and decide what it means for your
systems. That's a distinct reading skill, and skipping it means the first time you build
it is under real time pressure.

**The fix:** `content/STRATEGY.md`'s "read real CVEs & advisories early" principle
includes one worked example of reading an advisory end-to-end — start there. Days that
build a specific vulnerability class (e.g., injection on Day 8, SSRF on Day 9,
IAM privilege escalation on Day 14) are good moments to go find and read one real CVE
in that class before or after the lab, and note it in that day's `journal.md` entry.
Treat "I read the advisory, not just a summary of it" as part of finishing the day, not
extra credit.

---

## How to use this list

Reread this file if a day starts to feel like a chore and something else — a video, a
cert plan, a new tool, a shiny CTF — starts to look more appealing. That pull is usually
one of the ten patterns above wearing a disguise. The fix is almost always the same: go
run the lab, write the journal entry, and move to the next day.

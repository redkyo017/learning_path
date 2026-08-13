# Day 19 — Incident Response & Forensics Basics

## Objectives

By the end of today you should be able to:

- Name the six phases of the IR lifecycle (Preparation, Detection, Containment,
  Eradication, Recovery, Lessons Learned) and say, for any given action during an
  incident, which phase it belongs to.
- Explain **triage** precisely — what it decides, and why doing it badly (treating
  everything as maximum severity, or dismissing a real incident as noise) wastes the
  two things an incident actually needs: time and evidence.
- State the **order-of-volatility** principle for evidence collection and apply it to
  a real host: which artifacts to preserve first, and why preservation, not analysis,
  is the first move on any live system.
- Read raw logs (`access.log`, `auth.log`) and a recovered shell history to
  reconstruct, with evidence citations, exactly how an attacker got in and what they
  did next.
- Find a **persistence mechanism** on a compromised host (a cron entry plus the
  script it runs plus the account/key it maintains) and name why eradicating only
  part of it fails.
- Use a **hash comparison against a known-good baseline** to catch a tampered binary
  that shows no behavioral difference at all.
- Fill in a real incident report from evidence you collected yourself, distinguishing
  what you can prove from what you're inferring.

## 1. Concept — IR Lifecycle, Triage, Evidence, and Basic Host Forensics

### The IR lifecycle — six phases, in order, and why the order matters

**Incident response (IR)** is the structured process of handling a security incident
from first suspicion to closed report. It has six phases, and the order is not
arbitrary — each phase depends on the previous one having happened first:

1. **Preparation** — everything done *before* an incident: logging turned on and
   retained somewhere an attacker can't delete it, backups that actually restore, a
   contact list, and (today's whole lab, implicitly) knowing in advance what "normal"
   looks like on your systems, so you can recognize when something isn't. Preparation
   is the phase most real organizations skip, and it's the reason many real incidents
   take days instead of hours to even confirm.
2. **Detection** (and analysis) — noticing that something might be wrong and doing
   enough initial digging to say whether it's a real incident or noise. This is where
   **triage** lives (below) — detection produces a *hypothesis*, not a full picture.
3. **Containment** — stopping the incident from getting worse, *without* destroying
   the evidence you'll need for the next two phases. Isolating a host from the network
   is containment; wiping and reimaging it immediately is not — that's jumping straight
   to Recovery and throwing away Eradication's evidence in the process.
4. **Eradication** — actually removing every piece of the attacker's presence:
   malware, backdoor accounts, planted scripts, scheduled persistence, everything.
   Today's lab's central lesson (Section 3) is that eradication done *partially* — one
   piece of a multi-part persistence mechanism removed, the rest left standing — is
   functionally the same as not eradicating at all.
5. **Recovery** — safely returning the system to production: verifying it's actually
   clean (not just "the parts we found are gone"), rotating anything the attacker could
   have touched (credentials, keys), and monitoring closely for recurrence before
   trusting it fully again.
6. **Lessons learned** (post-incident activity) — the phase most often skipped under
   time pressure, and the one that turns one incident into prevention of the next
   ten: what let this happen, what would have caught it sooner, what changes with an
   owner and a deadline.

The **incident report template** this lab's lab section fills in
([`labs/day19/incident-report-template.md`](../labs/day19/incident-report-template.md))
has one section per phase from Detection onward — filling it in *is* walking the
lifecycle.

### Triage — deciding what an incident actually is, fast, with incomplete information

**Triage** is the first, time-pressured pass over an alert or a report: is this a real
incident, how bad, and what needs to happen *right now* versus what can wait for a
full investigation. It is explicitly not the full investigation — it's the decision
that determines whether a full investigation happens at all, and how urgently.
Getting triage wrong has two distinct failure modes, and they cost different things:

- **False negative** (treating a real incident as noise) — the cost is the incident
  continues unchecked while nobody's looking, exactly the situation today's lab
  starts you in: `prod-web01` has been compromised for over a day (see the Section 2
  timeline) before anyone (you) starts investigating.
- **False positive fatigue** (treating everything as maximum severity) — the cost is
  slower, but just as real: responders burn out, real signals get lost in noise, and
  the *next* real incident gets triaged slower because "another false alarm" has become
  the default assumption. Day 11's detection-engineering content is where reducing
  false-positive rate on the *detection* side gets covered directly; today's job
  starts one step later, once something has already been flagged for you.

Today's target skips the alert-triggered part of triage entirely — you're handed a box
already known to be compromised — so today's practice is really the second half of
triage: given a real incident, scope it (what's affected, how far did the attacker
get) before deciding what to contain and how.

### Evidence handling and chain of custody

**Chain of custody** is the documented, unbroken record of who collected a piece of
evidence, when, how, and who has had access to it since — the reason a chain of
custody matters in a legal/HR context is that evidence with a broken or undocumented
chain can be argued to have been tampered with, which can make it inadmissible or just
not credible. Even outside a legal context, the same discipline matters for a purely
technical reason: **if you investigate the live, still-compromised system directly,
you cannot prove your own investigation didn't change something** — and worse, if the
attacker still has active access (exactly today's scenario — the persistence mechanism
is still live), *anything* you do on the live box risks tipping them off or triggering
a self-healing response before you're ready to eradicate. The practical fix, applied in
today's lab (see `labs/day19/target/entrypoint.sh`), is: **acquire a copy first, then
investigate the copy, never the live system**. A real responder does this with a full
disk image or a volume snapshot; this lab's container does the equivalent with a plain
recursive file copy into `/loot/day19/evidence/` at boot — smaller in scope, identical
in principle.

**Order of volatility** governs the *order* evidence is collected in, when you can't
grab everything simultaneously: collect what will disappear soonest, first.

1. Running processes, open network connections, and anything only ever held in RAM —
   gone the instant a process exits or the box reboots.
2. Logs that actively rotate or truncate, or that an attacker's cleanup routine could
   still touch.
3. Command history — frequently deliberately deleted by an attacker (today's target's
   own `.bash_history` ends with a `history -c` attempt, left visible on purpose so you
   can see it happened and reason about why recovering it *before* that succeeds, or
   from a source that survives it, matters).
4. Stable on-disk artifacts (dropped files, persistence scripts, config changes) —
   least urgent to grab first only in a *relative* sense: they're still collected
   before Eradication necessarily destroys them.

Finally: **hash every piece of evidence at the moment you collect it.** A SHA-256
hash recorded then lets you prove later — to yourself, to a colleague, or in a formal
context — that the copy you're analyzing is byte-for-byte identical to what you
originally collected, and hasn't been altered since (accidentally or otherwise).

### Basic host forensics — what to actually look at, and one non-obvious technique

Given a host, "look for anything suspicious" is not an actionable instruction. Four
concrete, repeatable things to check, all exercised hands-on in Section 2:

- **Logs** — web/application access logs for the initial foothold, auth logs for
  who logged in as whom and when, cron/system logs for scheduled jobs actually firing.
  Cross-referencing two independent logs that agree on a timestamp (Section 2's
  `access.log` and `auth.log` both landing on the same afternoon) is stronger evidence
  than either alone.
- **Processes and scheduled jobs** — `ps aux`, `crontab -l`, and every file under
  `/etc/cron.d/`, `/etc/cron.daily/`, and systemd timer units on a real host — the
  standard places persistence hides. A disguised, innocuous-sounding name (today's
  `sysmon-check` — sounds like routine monitoring) is deliberately not a giveaway on
  its own; you have to actually read what the job *runs*, not just that a job exists.
- **Accounts and keys** — new entries in `/etc/passwd`, unexpected `sudo` grants
  under `/etc/sudoers.d/`, and unfamiliar public keys in any `authorized_keys` file —
  all three are classic persistence, and all three survive a reboot, unlike a
  live shell or process.
- **File timelines** — `stat` a file's `mtime` (last modified) and `ctime` (last
  metadata/inode change — includes permission changes, not just content) to ask "when
  did this actually change," and `find /some/path -newer /some/reference/file` to list
  everything touched after a known-good point in time. Today's lab doesn't require
  this technique directly (every planted IOC is identifiable by content/location
  alone), but it's the general tool for the case where a suspicious file's *content*
  looks fine and only its *timestamp* is out of place.

The one technique today's lab specifically requires and that's easy to miss if you
only ever look for "does this file behave badly": **hash comparison against a known
baseline**. A trojanized binary can be functionally identical to the original — same
behavior, same exit code, nothing observably wrong — and still not be the original
file. The only thing that catches this is comparing its current hash against a hash
recorded *before* any tampering could have happened (Section 2, Step 5). This is
exactly the principle a real file-integrity-monitoring tool (`auditd`'s file-watch
rules from Day 5, or a dedicated tool like AIDE/Tripwire) automates continuously,
instead of doing it once, by hand, after the fact.

## 2. Triage Lab — Investigate a Pre-Compromised Host

**Authorized use only:** everything below runs against `target`, "prod-web01", a
container this lab starts on the shared `cyberlab` network — never against a real host
you don't own or don't have explicit written authorization to investigate. Unlike
every earlier day, `target` here isn't something you attack — every IOC is already
planted at build time; your job is to find and document it, not exploit anything.

Bring up both labs (after `labs/base/up.sh` if you haven't already):

```sh
cd cyber_security/labs/base
./up.sh
cd ../day19
docker compose up -d --build
```

`labs/day19/docker-compose.yml` adds **only** the `target` service — it does not
redefine the `attacker` service. `target`'s entrypoint copies every planted IOC into
`/loot/day19/evidence/` at boot (a simulated forensic acquisition — Section 1's chain-
of-custody point, made concrete). Every command below runs from `labs/base`, exec'd
into `attacker` — reused today as your analyst workstation, not as an offensive
toolbox:

```sh
cd cyber_security/labs/base
docker compose exec attacker bash
```

Full detail: [`labs/day19/README.md`](../labs/day19/README.md).

### Step 1 — See what was acquired

```sh
ls -la /loot/day19/evidence
```

**What you should see:** `access.log`, `auth.log`, `sysmon-check.cron`,
`sysmon-check.sh`, `root_authorized_keys`, `root_bash_history`, `shell.php`, `passwd`,
`baseline-hashes.txt`, and `current-hashes.txt` — nine artifacts, one investigation
copy each, none of it the live `target` filesystem.

### Step 2 — Find initial access

```sh
grep -E "203\.0\.113\.77|uploads" /loot/day19/evidence/access.log
```

**What you should see:** a `POST /uploads.php` at `14:02:55` followed by several
`GET /uploads/shell.php?cmd=...` requests, all from `203.0.113.77` — the upload is the
actual foothold; everything after it is the attacker using the webshell it created.
Full captured output and the exact reasoning for calling `14:02:55` (not the first
`GET`) the initial-access timestamp: [`labs/day19/SOLUTION.md`](../labs/day19/SOLUTION.md).

### Step 3 — Corroborate with auth.log and recovered history

```sh
cat /loot/day19/evidence/auth.log
cat /loot/day19/evidence/root_bash_history
```

**What you should see:** `auth.log` shows a new account (`svc-monitor`) created at
`14:04:20` — seven minutes after the webshell upload — then an SSH login as that same
account from the **same IP** (`203.0.113.77`) roughly an hour later, and a cron entry
firing the next day. `root_bash_history` independently shows the exact commands that
created that account, fetched the persistence script, and installed the cron job —
two unrelated sources of evidence landing on the same story is what makes a timeline
trustworthy rather than speculative.

### Step 4 — Identify the persistence mechanism

```sh
cat /loot/day19/evidence/sysmon-check.cron
cat /loot/day19/evidence/sysmon-check.sh
```

**What you should see:** a cron entry disguised as a routine health check
(`/etc/cron.d/sysmon-check`, every 5 minutes) that runs a script whose real job is to
re-create the `svc-monitor` account and re-add the attacker's SSH key
*if either is ever missing*. This is the lab's central persistence lesson: it's not
one artifact, it's **four connected artifacts** (cron entry, script, account, key) —
naming only one of them as "the persistence mechanism" in your report would be
incomplete. See also `/loot/day19/evidence/root_authorized_keys`, which contains the
attacker's planted key (`mallory@c2`).

### Step 5 — Catch the tampered binary by hash, not behavior

```sh
diff /loot/day19/evidence/baseline-hashes.txt /loot/day19/evidence/current-hashes.txt
```

**What you should see:** a difference on the `/bin/true` line — `baseline-hashes.txt`
was recorded *before* any tampering; `current-hashes.txt` reflects the host as found.
The two other files hashed alongside it (`/bin/ls`, `/usr/bin/whoami`) match, which is
itself useful evidence — it tells you the tampering was narrow (one specific file),
not a wholesale reinstall of coreutils. Note this technique caught the file with *zero*
behavioral testing — `/bin/true` still exits `0` either way; only the hash differs.

### Step 6 — Build the timeline and fill in the incident report

Using Steps 2–5's evidence, fill in
[`labs/day19/incident-report-template.md`](../labs/day19/incident-report-template.md)
— the Timeline, Initial Access, Persistence Mechanisms, IOCs, and Evidence Preserved
sections. A worked example: [`labs/day19/SOLUTION.md`](../labs/day19/SOLUTION.md).

### Verify

```sh
cd cyber_security/labs/day19
docker compose config -q
```

**Expected output:** nothing, exit code `0` — confirms the compose file is
well-formed. This is a **static** check only; it doesn't build or start `target`. To
confirm every IOC is actually present in a built image, run the scripted `grep` check
in [`labs/day19/SOLUTION.md`](../labs/day19/SOLUTION.md) (requires
`docker compose up -d --build` first).

## 3. Defense — Containment, Eradication, and Recovery

### Containment — stop the bleeding without destroying evidence

For `prod-web01`, containment (once Section 2's evidence is preserved) means: isolate
the host from the network (remove it from load balancing, block it at a firewall, or
disconnect the docker network in a lab context) and block the attacker's known
indicator — `203.0.113.77` — at the perimeter. Notice what containment is *not*:
rebooting, wiping, or reimaging the host immediately. Any of those destroys exactly
the evidence Section 2 just spent five steps collecting, and — worse — a reboot can
also trigger some persistence mechanisms to re-verify or re-establish themselves
(today's cron-based one would simply fire again on the next tick regardless).

### Eradication — remove the whole mechanism, not one piece of it

Removing only the cron entry and calling it done is the single most common mistake
this lab is built to surface. The full removal, all as one unit:

1. Delete `/etc/cron.d/sysmon-check` (the trigger).
2. Delete `/usr/local/bin/sysmon-check` (the script the trigger ran — leaving this in
   place means *any* future trigger, not just this exact cron entry, restores the
   backdoor).
3. `userdel -r svc-monitor` and remove `/etc/sudoers.d/svc-monitor` (the account the
   script maintained).
4. Remove the specific `mallory@c2` line from `/root/.ssh/authorized_keys` (the key
   the script also maintained) — without deleting the whole file if legitimate keys
   share it.
5. Restore `/bin/true` from a trusted source (a package reinstall, not a hand
   edit) and re-hash it to confirm the restored file now matches a known-good
   baseline again.

Do all five together, then re-run Step 5's hash comparison and a fresh sweep of
cron/accounts/keys to confirm nothing was missed — eradication isn't complete until
you've actively looked for evidence that it worked, not just performed the removal
steps and assumed so.

### Recovery — trust the system again, deliberately

Before returning a system like this to production: rotate every credential the
attacker could plausibly have touched (not just the ones you found evidence of use
for — anything reachable from the compromised account), fix the root cause (Day 10's
supply-chain/secrets content and Day 8's injection content are exactly the earlier
material that covers hardening an upload endpoint against this), and monitor closely
for a period before trusting the system fully unattended again. "It's clean now" and
"we're confident it's clean" are different claims — Recovery is where you close that
gap, deliberately, not by default over time.

### Lessons learned — the phase this lab asks you to actually do

Section 4's Drill 2 and this lab's incident report template's final section both push
you to name a **root cause** (the unrestricted upload endpoint) and **one concrete
follow-up action with an owner and a deadline** — not "be more careful." A lessons-
learned entry that doesn't produce at least one such action is a lessons-learned entry
that changes nothing, which defeats the entire point of the sixth phase.

## 4. Drills

Attempt each drill yourself, from the evidence in `labs/day19/target/fixtures/`
(mirroring what you'd see under `/loot/day19/evidence/`), before reading its solution
sketch.

### Drill 1 — Identify the initial access from provided logs

You're handed this excerpt (a subset of `access.log`, reordered — your job includes
re-ordering it):

```
198.51.100.23 - - [10/Aug/2026:09:58:02 +0000] "GET / HTTP/1.1" 200 1024 "-" "Mozilla/5.0"
203.0.113.77 - - [10/Aug/2026:14:03:07 +0000] "GET /uploads/shell.php?cmd=id HTTP/1.1" 200 45 "-" "curl/7.88.1"
203.0.113.77 - - [10/Aug/2026:14:02:55 +0000] "POST /uploads.php HTTP/1.1" 200 512 "-" "curl/7.88.1"
```

Which line is the initial-access event, and why is it *that* line and not the earlier
or later ones?

**Hint:** "initial access" means the moment the attacker's foothold was created, not
the moment you first see them *use* it, and not unrelated normal traffic from a
different source.

**Solution sketch:** the `POST /uploads.php` at `14:02:55` from `203.0.113.77` is
initial access — it's the request that plants the webshell, creating the foothold.
The `GET /uploads/shell.php?cmd=id` at `14:03:07` is the first confirmed *use* of that
foothold, twelve seconds later — a real, useful timestamp for "when did they start
actively exploiting it," but not the same event as the upload itself. The
`198.51.100.23` line is unrelated ordinary traffic (different source IP, hours
earlier, hitting the homepage) and isn't part of the incident at all — including it in
a report as if it were related would be exactly the kind of unsupported inference
Section 1's "evidence you could point to if challenged" standard is meant to catch.

### Drill 2 — List the persistence mechanism and every step to eradicate it

Given only `/etc/cron.d/sysmon-check`'s content —

```
*/5 * * * * root /usr/local/bin/sysmon-check >> /var/log/sysmon-check.log 2>&1
```

— and knowing `/usr/local/bin/sysmon-check` re-creates a backdoor account and
re-adds an SSH key whenever either is missing, list every single artifact that must
be removed to actually eradicate this persistence mechanism, in an order that
wouldn't let any of it silently survive.

**Hint:** count the artifacts named across Section 1's "basic host forensics"
categories (accounts, keys) plus the two you're given directly (the cron entry, the
script) — there are more than two, and removing only the ones visible in the snippet
above (the cron line itself) leaves the rest standing.

**Solution sketch:** four artifacts, all required, order doesn't strictly matter as
long as all four happen before declaring eradication complete: (1) the cron entry
itself, (2) the script it invokes (`/usr/local/bin/sysmon-check` — leaving this
in place means any *other* trigger could still restore the backdoor), (3) the backdoor
account the script maintains, and (4) the specific attacker SSH key the script
re-adds. Removing only (1) — the visible cron line — while leaving (2)–(4) in place
means the account and key still exist and are still usable right now, even with the
cron trigger gone; removing (1)+(3)+(4) but leaving (2) means the next time anything
at all invokes that script, the account and key silently come back. This is exactly
Section 3's central eradication lesson, applied concretely to the snippet given here.

### Drill 3 — What to preserve for evidence, and in what order

You arrive at a live, still-compromised host. Name, in order, the first three
categories of evidence you should prioritize collecting, and say briefly why that
order (not a different one).

**Hint:** think about which categories of evidence disappear or degrade on their own,
with no attacker action required at all, the fastest — that's the ordering principle,
not "most important first."

**Solution sketch:** (1) running processes and open network connections — gone the
instant the process exits or the box reboots, with zero attacker effort required; (2)
logs that actively rotate, truncate, or that a cleanup routine could still reach; (3)
command history — frequently deliberately deleted by an attacker, so it's a race
against their own cleanup, not just against time. Stable on-disk artifacts (dropped
files, persistence scripts) come after these three precisely because they're the
*least* likely to disappear on their own before you get to them — the ordering is
about volatility, not about which evidence turns out to matter most for the final
report.

### Drill 4 — Reason about evidence reliability

Today's target's `root_bash_history` ends with a `history -c` command (clear
history) — and yet the file you're handed still contains everything before that line.
In two or three sentences: what does this tell you about how much you should trust a
recovered `bash_history` in a real investigation, and name one reason a real attacker's
`history -c` might *not* actually erase what you're relying on it to erase.

**Hint:** think about *when* `history -c` actually takes effect relative to when a
shell session's history gets written to disk, and about other places the same
commands might be logged independently of the shell's own history file.

**Solution sketch:** `history -c` clears the *in-memory* history of the current
interactive shell; it does not retroactively un-write lines that a shell had already
flushed to the history file on previous commands (behavior here varies by shell and
configuration, which is itself the point — you cannot assume it reliably erases
anything). Today's target ships this exact scenario: the file still contains every
command run before the clear attempt. More broadly, this is a reason to treat a
recovered `bash_history` as **corroborating** evidence, not sole evidence — Section
1's point about two independent logs agreeing (Step 3's `auth.log` + `bash_history`
landing on the same timeline) is exactly the mitigation: even if an attacker's history
clearing had fully succeeded here, `auth.log`'s independent record of the account
creation and SSH login would still exist, on a completely separate logging path the
shell's own history has no control over at all.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name precisely — today wasn't an attack, it was an
  investigation. Write instead which specific IOCs you found yourself versus which
  ones you only confirmed by reading `SOLUTION.md` — the same honesty-about-what-was-
  hands-on habit Day 4's journal prompt asked for.
- **How:** which single piece of evidence made the timeline click into place for
  you — the log correlation in Step 3, or the hash mismatch in Step 5 catching
  something with no behavioral difference at all?
- **What defended it:** which of Section 3's five eradication steps would you have
  missed on a first pass, before reading it spelled out as "all five, together"?
- **What confused me:** anything about why chain of custody matters even in a
  container you fully control, or about why a `history -c` attempt didn't actually
  erase the evidence you were handed, that didn't click on first pass.
- **One thing to revisit:** pick one term from today (triage, chain of custody,
  order of volatility, persistence, IOC, containment) to re-explain from memory
  before Day 20, without looking back at this file.

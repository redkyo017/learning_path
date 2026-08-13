# Day 11 — Logging & the Blue-Team Loop

## Objectives

By the end of today you should be able to:

- Name the difference between a **log** (one event, one system) and **telemetry**
  (everything you've deliberately instrumented, across systems, so a security question
  can actually be answered) — and say which one Days 1–10 mostly gave you and which one
  today builds.
- Explain **detection engineering** as writing a hypothesis with a real cost: every
  detection either fires when it shouldn't (a **false positive**, wasting an
  analyst's time) or stays silent when it shouldn't (a **false negative**, missing a
  real attack) — and say why "just alert on everything" is not a free win.
- Distinguish **signature-based** detection (matches a known-bad pattern, fast and
  precise, blind to anything novel) from **anomaly-based** detection (flags a deviation
  from a baseline, catches novelty, noisier) — and correctly classify each of today's
  three detectors.
- Stand up **fail2ban** against a real structured log and watch it actually ban a
  brute-force source's traffic — not just alert on it.
- Write and load a real **Suricata** rule that fires on the exact SYN-scan pattern Day 2
  taught, and read its alert.
- Write a `jq` query over structured JSON logs that finds a UNION-based SQLi payload,
  and name specifically why a plain `grep` for the word `UNION` would miss real
  attacks and flag some harmless ones.
- For each of Days 2, 4, and 8's replayed attacks, name its log source, its detection
  rule, and its expected alert — closing the loop this path has been building toward
  since Day 0's build → break → fix → **detect** cycle.

## 1. Concept — Telemetry, Detection Engineering, and Closing the Purple Loop

### A log is one event. Telemetry is the instrumented whole.

A **log** is a single system's record of what it did: an nginx access line, a login
attempt, a kernel audit entry. **Telemetry** is the deliberate, cross-system
instrumentation that makes those individual logs *answerable as a security question* —
not "what did `target` log at 10:04am" but "did anyone brute-force a login in the last
hour, and from where." Every earlier day already produced logs (the `access.log`
Day 4's target quietly wrote every login attempt to; Day 2's raw pcap). What none of
those days did — on purpose, so today would have something real to build — was turn
those logs into something a detector *watches continuously* and *alerts on*. That gap
is exactly what today closes.

Today's target ([`labs/day11/target/app.py`](../labs/day11/target/app.py)) produces
telemetry, not just logs: every `/login` and `/search` request is written as one JSON
line, in a *fixed field order*, to `/var/log/webapp/access.log` — a small, deliberate
step up from Day 4's target, which logged nothing machine-parseable at all. That fixed
shape is precisely what makes the rest of today possible: a detector can pattern-match
a JSON line reliably in a way it can't reliably pattern-match free-text prose.

### Detection engineering: a detection is a hypothesis, and every hypothesis has a cost

Writing a detection rule is making a falsifiable claim: "this specific pattern means
this specific bad thing happened." Every such claim can be wrong in two directions,
and knowing the name for each matters because they trade off against each other, not
independently:

- **True positive (TP)** — the detection fires, and an attack actually happened.
  What you want.
- **False positive (FP)** — the detection fires, but nothing bad happened (a legitimate
  user mistyped a password twice; a vulnerability scanner your own team runs looks
  identical to `nmap -sS`). Costs analyst time and, at scale, trains people to ignore
  alerts — the single most common reason real SOCs miss real incidents.
- **False negative (FN)** — the detection stays silent, but an attack happened anyway
  (a slow-and-low brute force that never crosses a 5-in-60-seconds threshold; a SQLi
  payload that doesn't contain the literal string `UNION`). The attack succeeds
  undetected.
- **True negative (TN)** — the detection stays silent, and nothing bad happened. The
  overwhelming majority of all traffic, always — which is exactly why FP rate matters
  so much: even a tiny false-positive *rate* generates a large *absolute number* of
  false alerts against a large true-negative background.

**Detection engineering** is the discipline of choosing thresholds, patterns, and
scope to push the TP/FP/FN trade-off toward "catches what matters, without drowning the
analyst" — and it is never a one-time act. Today's fail2ban jail
([`rules/fail2ban/target-bruteforce-jail.local`](../labs/day11/rules/fail2ban/target-bruteforce-jail.local))
picks `maxretry = 5` within `findtime = 60` seconds specifically *because* Day 4's own
`passwords.txt` run produces far more than 5 failures well inside 60 seconds — a
threshold tuned against a real known attack shape, not a guess. Drill 2 below asks you
to re-tune it against a false-positive scenario.

### Signature-based vs. anomaly-based — and which one is which today

- **Signature-based** detection matches a *specific, known pattern* — a packet shape,
  a byte string, a log line structure. Fast, precise, and cheap to write, but blind to
  any attack that doesn't match the exact signature, including trivial variants of a
  known one.
- **Anomaly-based** detection flags a *deviation from an established baseline* —
  "this source normally sends 2 requests/minute, it just sent 200." Catches genuinely
  novel attacks a signature was never written for, at the cost of needing a real
  baseline (which takes time and data to build) and generally producing more false
  positives, since "unusual" and "malicious" are not the same thing.

All three of today's detectors are **signature-based**, and naming that precisely
matters — it's the honest limitation, not a gap to gloss over:

1. Suricata's rule ([`rules/suricata/local.rules`](../labs/day11/rules/suricata/local.rules))
   matches a specific packet shape (bare SYN, 5+ in 10 seconds, one source) — a known
   scan signature, exactly like Day 2's own scan-detection framing.
2. fail2ban's filter matches a specific log-line structure (`"event": "login_attempt"`
   with `"outcome": "fail"`) — a known failure signature.
3. `sqli_watch.sh`'s jq query matches specific SQLi payload shapes (`UNION SELECT`, a
   trailing `--`, an `OR 1=1` tautology) — known injection signatures.

None of these would catch a genuinely novel technique that doesn't match their exact
pattern (a scan slow enough to stay under 5-in-10-seconds; a SQLi payload using a
comment style other than `--`; a brute force that guesses one password every 90
seconds, forever). That's not a bug in today's lab — it's the actual, permanent
trade-off signature-based detection makes, and Drill 4 asks you to reason about what
an anomaly-based version of each would need instead.

### SIEM: the place all of this is supposed to converge

A **SIEM** (Security Information and Event Management system) is the real-world tool
that ingests telemetry from many sources — network IDS alerts, host logs, cloud
audit trails — normalizes it, and gives an analyst one place to query and correlate
across all of it. Today's `/var/log/detect.log`
([`labs/day11/detection/entrypoint.sh`](../labs/day11/detection/entrypoint.sh) tails
Suricata's and fail2ban's native logs and writes normalized `ALERT [...]` lines into
it) is a deliberately tiny, one-file stand-in for that idea — genuinely the same
*shape* of problem (many sources, one place to look), at a scale you can read by eye
instead of query with Splunk/Elastic. The **Extension Modules** section of
[`ROADMAP.md`](../ROADMAP.md) names "SIEM & Threat Hunting" as exactly the track that
takes this idea to production scale.

### The purple loop, closed

Day 0 named the loop this whole path runs: build → break → fix → **detect**. Days 2,
4, and 8 (once shipped) each did "break" against a specific target. Today is the
"detect" step for all three at once, retroactively — the loop closing exactly as
promised. **Telemetry** is what those days should have been feeding into all along;
**detection engineering** is the discipline of turning it into a real alert; and the
signature/anomaly, TP/FP/FN vocabulary above is precisely what lets you reason about
*how good* that alert actually is, not just whether it fired once in a demo.

## 2. Attack Lab — Replay Three Earlier Attacks

**Authorized use only:** everything below runs against `target`, a container this lab
starts on the shared `cyberlab` network — never against a system you don't own or
don't have explicit written authorization to test.

Bring up both labs (after `labs/base/up.sh` if you haven't already):

```sh
cd cyber_security/labs/base
./up.sh
cd ../day11
docker compose up -d --build
```

`labs/day11/docker-compose.yml` adds **`target`** and **`detection`** — it does not
redefine `attacker`. Every attack command below runs from `labs/base`, where
`attacker` is actually defined. Full detail: [`labs/day11/README.md`](../labs/day11/README.md).

### Replay 1 — port scan (Day 2's technique)

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "for i in 1 2 3 4 5 6; do nmap -sS -p 5000 target > /dev/null; done"
```

**What you should see:** six quick SYN-scan passes against the same port, from the
same source, well inside 10 seconds — the exact burst shape Suricata's rule (Section
3, Defense 1) is written to catch. This is literally Day 2's `nmap -sS` technique,
against a fresh target.

### Replay 2 — brute force (Day 4's technique)

```sh
docker compose exec attacker sh -c "for i in 1 2 3 4 5 6; do curl -s -X POST target:5000/login -d 'username=admin&password=wrong'; echo; done"
```

**What you should see:** six `{"status": "invalid credentials"}` responses. Behind the
scenes, `target` appends six `login_attempt` / `"outcome": "fail"` JSON lines to its
access log — the exact signature fail2ban's filter (Section 3, Defense 2) matches.
This is Day 4's brute-force *technique* (repeated guesses, no rate limit) rather than
Day 4's exact `hydra` command — a real `hydra` run against `/login` works identically
if you'd rather reuse Day 4's actual tooling and wordlist; both are documented in
[`labs/day11/SOLUTION.md`](../labs/day11/SOLUTION.md).

### Replay 3 — web injection (Day 8's technique, self-contained stand-in)

```sh
docker compose exec attacker sh -c "curl -s 'target:5000/search?q=firewall'"
```

**What you should see (baseline):** `{"results": [[1, "firewall appliance", "199.99"]]}`
— the search working normally, proving the next step is a real injection and not just
a broken endpoint.

```sh
docker compose exec attacker sh -c "curl -s 'target:5000/search?q=nomatch%27%20UNION%20SELECT%20id%2C%20username%2C%20password%20FROM%20users--'"
```

**What you should see:**

```json
{"results": [[1, "admin", "S3cr3t-Admin-PW!"], [2, "svc_backup", "b4ckup-service-2024"]]}
```

The `users` table's contents, pulled out through the `products` search box — the same
UNION-based-SQLi shape Day 8 teaches in full, built here as a deliberate, self-contained
stand-in rather than reusing Day 8's own target directly (an honest scope note, matching
this path's pattern of naming what's borrowed versus what's a placeholder). **Why it
works:** `target`'s query template is
`SELECT id, name, price FROM products WHERE name LIKE '%{q}%'`; the payload closes the
quote, appends a `UNION SELECT` with exactly 3 columns (matching `products`' 3 columns),
and a trailing `--` comments out the template's leftover `%'` — the textbook
column-count-matching UNION technique.

### Verify — all three replayed, evidence check

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "for i in $(seq 1 6); do curl -s -X POST target:5000/login -d 'username=admin&password=wrong' >/dev/null; done"
cd ../day11
docker compose exec detection sh -c "grep -Eiq 'ban|alert|fail' /var/log/detect.log && echo DETECT_OK"
```

Expected: `DETECT_OK`. Full expected evidence for every replayed attack, per detector:
[`labs/day11/SOLUTION.md`](../labs/day11/SOLUTION.md).

## 3. Defense Lab — Stand Up Detection for Each

### Defense 1 — a Suricata rule for the scan

[`rules/suricata/local.rules`](../labs/day11/rules/suricata/local.rules):

```
alert tcp any any -> any 5000 (msg:"Possible port scan against target:5000 (SYN burst)"; flags:S; threshold:type both, track by_src, count 5, seconds 10; classtype:attempted-recon; sid:1000001; rev:1;)
```

Read left to right: match any bare-**SYN** packet (`flags:S`) toward port `5000`; only
actually **alert** once the same source (`track by_src`) has done this **5 times within
10 seconds** (`threshold:type both, count 5, seconds 10`) — `type both` means fire once
per source per window that crosses the threshold, not once per matching packet, which
would flood the alert log instead of naming the burst once. This is a direct,
practical instance of the signature-based detection defined in Section 1 — it matches
a *specific packet shape*, the same half-open SYN scan Day 2's Concept section walked
through byte-by-byte.

**Expected evidence** (after Replay 1's burst): a line in
`detection`'s `/var/log/suricata/fast.log` naming `sid:1000001` and the message text
above. Full command + expected exact format: [`SOLUTION.md`](../labs/day11/SOLUTION.md).

### Defense 2 — fail2ban for the brute force

Filter ([`rules/fail2ban/target-bruteforce-filter.conf`](../labs/day11/rules/fail2ban/target-bruteforce-filter.conf)):

```
failregex = ^\{"ts": "[^"]+", "event": "login_attempt", "src_ip": "<HOST>", "username": "[^"]*", "outcome": "fail"\}$
```

Jail ([`rules/fail2ban/target-bruteforce-jail.local`](../labs/day11/rules/fail2ban/target-bruteforce-jail.local)):

```
maxretry = 5
findtime = 60
bantime  = 300
action   = iptables-allports[name=TargetBruteForce, protocol=all]
```

The filter matches `target`'s JSON access log **structurally** (fail2ban's filter
engine is line-regex based, not JSON-aware — a real production pipeline would run
these logs through a JSON-aware shipper instead; named honestly here as a
simplification, not hidden). `<HOST>` is fail2ban's own placeholder — it's what gets
extracted as the address to ban. Five matches inside 60 seconds bans that source for
300 seconds, via `iptables-allports` — a real ban, not just a log line: `detection`
runs with `network_mode: service:target` (see the compose file's comment) precisely so
this ban lands in `target`'s own network namespace and actually blocks its traffic.

**Expected evidence** (after Replay 2's six failures): five `Found` lines and one
`Ban` line in `/var/log/fail2ban.log`, plus a `DROP` rule for the attacker's IP visible
in `iptables -L -n` inside the shared namespace. Full commands + expected exact
output: [`SOLUTION.md`](../labs/day11/SOLUTION.md).

### Defense 3 — a jq log query for the injection

[`detection/sqli_watch.sh`](../labs/day11/detection/sqli_watch.sh)'s core query:

```sh
jq -r '
  select(.event == "search_query") |
  select(
    (.query | test("(?i)union\\s+select")) or
    (.query | test("--")) or
    (.query | test("(?i)\\bor\\b\\s*1\\s*=\\s*1"))
  ) | .query
'
```

This is the "structured JSON logs + jq" half of the Global Constraints' lightweight-
stack requirement, and it's worth being precise about why it beats plain `grep -i
union`: `grep` matching the raw log line would (a) **false-positive** on a legitimate
search for a product literally named "union" (Day 1's Concept section on precision
already made this point about banner matching), and (b) still **miss** the `--`-comment
and `OR 1=1` payload shapes entirely, since those don't contain the word `UNION` at all.
Querying the *parsed* `.query` field against three distinct payload shapes, instead of
one substring, is a small but real step toward real detection engineering.

**Expected evidence** (after Replay 3's UNION payload): one line appended to
`/var/log/detect.log` reading `ALERT [injection] SQLi-shaped query on /search: ...`
with the injected payload echoed back. Full command + expected exact output:
[`SOLUTION.md`](../labs/day11/SOLUTION.md).

### Defense 4 — one consolidated log, three alert types

[`detection/entrypoint.sh`](../labs/day11/detection/entrypoint.sh) tails each
detector's own native log (`suricata/fast.log`, `fail2ban.log`) and `sqli_watch.sh`
writes its own alerts directly — all three converge into one file:
`/var/log/detect.log`. This is the smallest possible working model of what a real
**SIEM** does at scale (Section 1): many sources, normalized, in one place an analyst
actually reads. Confirming all three fired, in one command:

```sh
cd cyber_security/labs/day11
docker compose exec detection sh -c "cat /var/log/detect.log"
```

Expected: one `ALERT [scan] ...` line, one `ALERT [bruteforce] ...` line, one
`ALERT [injection] ...` line — the whole purple loop, closed, in one file.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Write the brute-force detection query yourself

You're handed these raw log lines (a fresh example, not Section 2's actual replay —
work it out yourself rather than reusing an answer):

```
{"ts": "2026-08-12T10:00:01+00:00", "event": "login_attempt", "src_ip": "172.20.0.7", "username": "admin", "outcome": "fail"}
{"ts": "2026-08-12T10:00:03+00:00", "event": "login_attempt", "src_ip": "172.20.0.7", "username": "admin", "outcome": "fail"}
{"ts": "2026-08-12T10:00:05+00:00", "event": "login_attempt", "src_ip": "172.20.0.9", "username": "bob", "outcome": "success"}
{"ts": "2026-08-12T10:00:07+00:00", "event": "login_attempt", "src_ip": "172.20.0.7", "username": "admin", "outcome": "fail"}
```

Write a `jq` query (not a fail2ban filter this time — same underlying data, different
tool) that prints only the source IPs with **2 or more failed logins** in this batch.

**Hint:** `jq` can group by a field with `group_by`, and count entries per group with
`length` — you don't need to hand-write a sliding time window for this drill, just a
count over the batch you're given.

**Solution sketch:**

```sh
jq -s '
  map(select(.event=="login_attempt" and .outcome=="fail")) |
  group_by(.src_ip) |
  map(select(length >= 2)) |
  map(.[0].src_ip)
' logs.json
```

(`-s` slurps all lines into one array first, since `group_by` needs the whole
collection at once.) Result: `["172.20.0.7"]` — `172.20.0.9`'s one entry is a
**success**, filtered out before grouping even happens, and never counted as a
failure in the first place.

### Drill 2 — Tune out a false positive

A real user on your network mistypes their password twice in a row (normal human
behavior), then gets it right on the third try, twice a day, every day. Today's jail
(`maxretry = 5`, `findtime = 60`) never bans them — good. Now suppose a stricter
teammate proposes tightening it to `maxretry = 2`, `findtime = 300` "to catch brute
force faster." Explain what breaks, and propose a fix that still catches Day 4's real
attack.

**Hint:** re-read Section 1's false-positive definition, then simulate the proposed
jail against the "two mistakes, then correct" pattern by hand.

**Solution sketch:** `maxretry = 2` inside a 5-minute window bans the *real user*
outright — two honest mistypes is a **false positive** under the stricter rule, exactly
the "makes the analyst distrust every alert" cost Section 1 named, except here it locks
out a real employee instead of just wasting an analyst's time. The fix is not "loosen
it back to today's numbers because it's what shipped" (that's begging the question) —
it's checking the fix against Day 4's *actual* attack shape: a `hydra` wordlist run
produces dozens of failures in seconds, not two. `maxretry = 5, findtime = 60` (today's
setting) comfortably survives two honest mistakes while still tripping in well under
a second against a real wordlist run — the tuning target is "above normal human error
rate, below real attack volume," and today's numbers were chosen with exactly that
margin, not picked arbitrarily.

### Drill 3 — Map each replayed attack to its log source

For each of today's three replayed attacks, name (a) which file/stream the evidence
actually lives in, and (b) which detector reads it.

**Hint:** one of the three sources is a raw network capture point (no file the attack
itself writes), and the other two are both the SAME log file, read by two different
tools looking for two different things in it.

**Solution sketch:**

1. **Port scan** — no application log at all; the evidence is the packets themselves,
   on the wire. Read by **Suricata**, sniffing `target`'s own interface (`eth0`,
   shared via `network_mode: service:target`).
2. **Brute force** — `target`'s `/var/log/webapp/access.log`, specifically the
   `login_attempt` / `"outcome": "fail"` lines. Read by **fail2ban**.
3. **Web injection** — the SAME file, `/var/log/webapp/access.log`, specifically the
   `search_query` lines. Read by **`sqli_watch.sh`**'s `jq` query. The lesson worth
   naming: one well-structured log file can serve multiple, entirely independent
   detectors, as long as every event type in it is unambiguously tagged (today's
   `"event"` field) — a real argument for structured logging over free-text.

### Drill 4 — Classify signature vs. anomaly, and say what the anomaly version would need

All three of today's detectors were named signature-based in Section 1. Pick any ONE
of them and describe, concretely, what an **anomaly-based** version would need instead
— specifically, what "normal" would have to be measured as, and one way today's exact
attack would still slip past a badly-built anomaly detector.

**Hint:** an anomaly detector needs a *baseline* before it can call anything abnormal —
ask what quantity you'd track over time, and over what population, to build one.

**Solution sketch** (using the brute-force detector as the example): today's fail2ban
filter is signature-based — it matches the exact string shape of a failed-login JSON
line, with no notion of what's "normal" for any given source. An anomaly-based version
would instead track, per source IP (or per account), a **baseline failed-login rate**
over some historical window (e.g., "this IP averages 0.1 failed logins/hour") and alert
when a source's rate deviates sharply from its own baseline — catching, for instance, a
*distributed* brute force where 50 different IPs each try only 2 guesses (never
crossing today's `maxretry = 5` per-source threshold, a real false negative in today's
design) but collectively hammer one account far outside its normal login-attempt
volume. The trade-off named in Section 1 shows up immediately: building that baseline
takes real historical data and tuning, and a *new* source with no baseline yet (a
first-time real user) looks anomalous by default — a fresh source of false positives
signature-based detection doesn't have.

### Drill 5 — True positive or false positive?

Your team runs a legitimate internal vulnerability scanner against `target` every night
at 2am, as part of routine hygiene scanning — fully authorized, known, expected.
Tonight, Suricata's rule fires at 2:00am with the exact alert from Section 3, Defense
1. Is this a true positive or a false positive, and — separately — does that answer
mean the rule is broken?

**Hint:** re-read Section 1's TP/FP definitions against what the rule actually claims
to detect, not against whether the underlying traffic was "bad" in some broader sense.

**Solution sketch:** it's a **true positive** — the rule's actual claim is "a SYN burst
matching a port-scan shape happened," and one genuinely did; the rule did its job
correctly. Whether that traffic was *malicious* is a completely separate question the
rule was never designed to answer, and this is exactly why detection engineering
doesn't stop at "the rule fired correctly" — the practical fix isn't touching the
rule at all, it's an **allowlist/suppression** for the known scanner's source IP during
its known schedule, documented as an accepted exception, so future 2am alerts don't
retrain the on-call analyst to reflexively dismiss anything from Suricata. Silently
disabling the rule, or shrugging off every future alert as "probably just the scanner,"
would both be the wrong fix — the first loses real detection coverage, the second
recreates the alert-fatigue problem Section 1 named as the actual cost of a bad
false-positive rate.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name specifically which port-scan, brute-force, and injection
  replay you ran against today's `target`, and which detector's log you personally
  read the evidence from for each.
- **How:** which of today's three detectors "clicked" fastest for you — Suricata's
  packet-level rule, fail2ban's log-line filter, or the jq query over structured
  JSON — and which one took the most re-reading to actually understand what it was
  matching and why?
- **What defended it:** walk through the consolidated `/var/log/detect.log` you
  produced — did all three alert types actually land in it, and if one didn't fire on
  the first try, what did you have to fix (timing, log format, a typo in a rule)?
- **What confused me:** anything about the true/false positive vocabulary, or about why
  `network_mode: service:target` matters for fail2ban's ban to actually work, that
  didn't click on first pass.
- **One thing to revisit:** pick one term from today (telemetry, detection engineering,
  true/false positive, SIEM, fail2ban, signature-based vs. anomaly-based) to
  re-explain from memory before Day 12, without looking back at this file.

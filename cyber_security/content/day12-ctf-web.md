# Day 12 — Web Consolidation Mini-CTF

## Objectives

By the end of today you should be able to:

- Chain an injection foothold into a broken-access-control escalation on a single,
  unguided web target — no step-by-step "Step 1, Step 2" this time, just three named
  stages and your own approach.
- Recognize, hands-on, that the textbook `' OR '1'='1'` SQLi payload is **not**
  universal — and explain precisely why it fails against a specific query shape while
  a `--`-comment payload succeeds against that exact same query.
- Explain why an IDOR/broken-access-control bug is completely independent of *which*
  account an injection foothold happened to land you as.
- Given a raw access log and a set of candidate automated alerts, distinguish a true
  positive from three distinct flavors of false positive — no evidence at all, a real
  signal with an overstated claim, and a real, correlating signal that's simply
  irrelevant to the incident — rather than trusting an alert's label at face value.
- Name, for each flag, the one specific control that would have stopped it.

## 1. Concept — Approaching an Unguided Web Box

Every earlier Phase 2 day handed you the vulnerability class up front (Day 8: "here's
the SQLi," Day 9: "here's the IDOR") and walked you through exploiting it step by step.
Today doesn't — you're given a box, told it chains three bugs, and left to find each
one yourself, the way a real unscoped engagement or a real CTF actually works. Two
habits carry over directly from Day 6's fundamentals CTF and matter again here:

- **Recon before you attack.** The index page names the two accounts that exist
  (`alice`, `admin`) but nothing about their passwords — spend a moment confirming what
  you *don't* know (Section 2, Step 0 below) before reaching for a specific technique.
- **Write down what worked and what didn't, as you go.** A failed textbook payload that
  you can explain the failure of (Stage 1's `OR '1'='1'` trap below) is worth more than
  a lucky success you can't explain — the same "articulate it or you don't really know
  it" habit `STRATEGY.md` and every journal entry so far has been pushing.

The other shift today: Stage 3 asks you to look at this exact attack chain from the
*defender's* side — the same purple-loop habit Day 11 introduced, now applied to an
attack you just ran yourself, not a replay of someone else's.

## 2. Attack Lab — The CTF

**Authorized use only:** everything below runs against `target`, a container this lab
starts on the shared `cyberlab` network — never against a web application you don't
own or don't have explicit written authorization to test.

Bring up both labs (after `labs/base/up.sh` if you haven't already), then stage this
lab's log files with a plain `cp` (no extra container — `/loot` is just a bind mount):

```sh
cd cyber_security/labs/base
./up.sh
cd ../day12
docker compose up -d --build
mkdir -p ../base/loot/day12
cp logs/access.log logs/alerts.log ../base/loot/day12/
```

`labs/day12/docker-compose.yml` adds **only** the `target` service — it does not
redefine `attacker`. Every command below runs from `labs/base`, where `attacker` is
actually defined. Full detail: [`labs/day12/README.md`](../labs/day12/README.md).

### Step 0 — Recon

```sh
docker compose exec attacker sh -c "curl -s target:5000/ ; echo"
```

**What you should see:** an HTML fragment naming the routes and the two accounts that
exist, `alice` (role: user) and `admin` (role: admin) — and an explicit statement that
neither account's real password is documented anywhere. Confirm that for yourself once
before moving on:

```sh
docker compose exec attacker sh -c "curl -s target:5000/login -d 'username=alice&password=letmein'; echo"
```

**What you should see:** `{"error":"invalid username or password"}` — every real
credential guess fails, because the target's password column is a random string
nobody, including this lab's author, actually knows. This isn't a hint you missed; it's
the setup for Stage 1.

### Stage 1 — Foothold (injection)

**Goal:** get a valid, logged-in session on `target` without knowing any real
password.

**Hints ladder:**

- **Nudge:** you confirmed above that guessing a real password is a dead end. `POST
  /login` builds a database query out of the `username` and `password` fields you
  send it. What happens to that query's own *syntax* if one of those fields isn't the
  plain text the app expects?
- **Bigger nudge:** you already know two real usernames. What single extra character
  sequence, appended right after one of those usernames, would make the rest of the
  query — including the entire `AND password = '...'` clause — never get evaluated at
  all?
- **Answer:** POST to `/login` with `username` set to `admin' -- ` (or `alice' -- `)
  and any value at all for `password`. This changes the server's query from checking
  both username *and* password to checking username alone, because `--` is a SQL
  comment — everything after it on that line is simply discarded. **A tempting
  shortcut that does *not* work here:** `' OR '1'='1'` alone (without a trailing `--`)
  fails against this specific query, because SQL's `AND` binds tighter than `OR` — it
  parses as `username='' OR ('1'='1' AND password='<your guess>')`, and no real row's
  password matches your guess either. Full captured proof of both the failure and the
  working payload: [`labs/day12/SOLUTION.md`](../labs/day12/SOLUTION.md).

**Flag 1** is returned directly in the JSON body of any successful login — on this box,
a successful login can *only* happen via this injection, so reaching it is the proof.

### Stage 2 — Escalate (broken access control)

**Goal:** using the session from Stage 1, reach data you don't own.

**Hints ladder:**

- **Nudge:** you're logged in now (as whichever account Stage 1's payload named). One
  more route exists beyond `/login` and `/api/whoami` — `/notes/<id>`. Try it with an
  id that's plausibly yours first.
- **Bigger nudge:** now try an id you were never given, or never told about. Does the
  app check who a note actually belongs to before handing it back to whoever asks?
- **Answer:** `GET /notes/2` — with any valid session cookie at all, including one that
  logged you in as `alice`, not `admin`. `admin`'s private note (id `2`) comes back
  regardless, because the route checks only that *some* session exists, never that its
  `owner_id` matches the session's own user. If Stage 1 happened to land you directly
  as `admin` (via `admin' -- `), this step is trivial — the more instructive path is to
  log in as `alice` specifically and still reach `admin`'s note through this
  *independent* bug. Full captured proof:
  [`labs/day12/SOLUTION.md`](../labs/day12/SOLUTION.md).

**Flag 2** is the content of `admin`'s note.

### Stage 3 — Detect (log analysis, entirely offline)

**Goal:** given `/loot/day12/access.log` (raw traffic) and `/loot/day12/alerts.log`
(five candidate automated alerts), identify the **one** true-positive alert that
actually corresponds to real evidence in `access.log`, and read off its flag. No live
detector runs anywhere in this lab — this is pure log reading with `jq`/`grep`, the
same tools Day 11 introduced.

**Hints ladder:**

- **Nudge:** don't trust `alerts.log` at face value. An alert firing is a *claim*, not
  proof — your job is to go verify each one against the raw evidence in `access.log`
  yourself, the same way Stage 1/2's "confirm it, don't just assume it" habit applied
  to your own attack.
- **Bigger nudge:** for each alert, check its `source_ip` against `access.log`. Some
  IPs won't appear at all. For the ones that do, check whether the alert's *specific
  claim* (a count, a time window, or plain relevance to what actually happened) matches
  what's really there — not just whether *something* from that IP exists.
- **Answer:** four of the five alerts are false positives, each for a different
  reason — one cites an IP with zero matching traffic at all; one cites a real IP but
  overstates its own claim (a "5 attempts in 10 seconds" alert against traffic that's
  actually 3 attempts over 25 seconds); one correlates exactly against a real log line
  but describes something the target app has no code path to actually be affected by.
  The two true positives share a source IP and sit one line apart in `access.log`: the
  first matches Stage 1's injection line exactly, the second matches Stage 2's
  cross-user note access — and the second one carries the flag. Full table, every
  correlation command, and the reasoning for all five verdicts:
  [`labs/day12/SOLUTION.md`](../labs/day12/SOLUTION.md).

**Flag 3** is the `flag` field on that one true-positive alert.

### Verify (static validation only — the CTF itself is what proves the flags)

```sh
cd cyber_security/labs/day12
docker compose config -q && echo COMPOSE_OK
```

Expected: `COMPOSE_OK`. This only validates the compose file; it does not reproduce the
three flags. All three flags reproduce by working Stages 1–3 above, or by following
[`labs/day12/SOLUTION.md`](../labs/day12/SOLUTION.md)'s full captured walkthrough.

## 3. Defense Lab — For Each Flag, the Control That Would Have Stopped It

Same reflection habit as Day 6's fundamentals CTF: for each flag, name the specific
control, not a vague "be more secure."

- **Flag 1 (SQLi auth bypass):** parameterized queries / prepared statements. The
  entire bug is that `target/app.py`'s `login()` builds SQL by string formatting —
  `f"... WHERE username = '{username}' AND ..."`. A parameterized query
  (`cursor.execute("... WHERE username = ? AND password = ?", (username, password))`)
  passes `username` and `password` as *data*, never as part of the query's own syntax —
  a `--` or a `'` inside either field would just be a literal character being compared
  against, with no ability to change what the query does. This is the exact fix Day
  8's Defense section names for injection generally.
- **Flag 2 (IDOR):** a server-side ownership check on every object access, unconditionally.
  `/notes/<id>` needs one additional line: after looking up the note, compare its
  `owner_id` against the *session's own* user id (not anything the client sends) and
  return 403/404 on a mismatch. This is Day 9's core lesson: broken access control is
  never fixed by hiding the id or making it harder to guess (`/notes/2` is a small
  integer specifically so guessing isn't the point) — only an explicit check, on every
  request, closes it.
- **Flag 3 (detection):** two things, and they're different controls. First, the true
  fix for Flags 1 and 2 (parameterized queries, an ownership check) would have
  prevented the *incident* Stage 3 investigates from ever happening — detection is
  always the second line of defense, not the first. Second, and specific to Stage 3
  itself: the false-positive alerts (A1, A2, A5) are exactly the "detection engineering
  is a tuning problem, not a fire-and-forget rule" lesson from Day 11 — a signature
  that's too loosely scoped (A2's overstated count/window) or checks for a pattern
  without confirming it's actually exploitable in *this* app (A5) produces noise that
  makes the two real alerts (A3, A4) easy to miss in a bigger, real alert queue. Tuning
  each rule against real traffic, the way you just did by hand, is the concrete fix.

## 4. Drills

The CTF in Section 2 **is** today's drill — each stage's hints ladder above is the
scaffolded version of "attempt it yourself before reading the answer" that every other
day's Drills section uses, and
[`labs/day12/SOLUTION.md`](../labs/day12/SOLUTION.md) is the full solution sketch,
including the Stage 3 detection answer. One additional synthesis drill, since it asks
something the three stages individually don't:

### Drill — One fix, applied earliest, that breaks the whole chain

Of the two live bugs (Stage 1's SQLi, Stage 2's IDOR), which one, if fixed *first* and
in isolation — leaving the other bug entirely unpatched — would have stopped this
specific chain from reaching Flag 2 at all? Say why, precisely.

**Hint:** ask which stage the chain depends on happening *before* the other one can be
reached at all, versus which stage would still be reachable on its own through some
other route into a session (a real stolen credential, a different bug entirely).

**Solution sketch:** fixing Stage 1's SQL injection (parameterized queries) first stops
this exact chain cold — with no way to forge a session without a real password, an
attacker never reaches Stage 2's IDOR *through this path*, because Stage 2 requires
"any valid session" as a precondition, and Stage 1 was the only way this scenario had
to get one. This is not the same as saying Stage 2 doesn't matter: the IDOR bug would
still be live and reachable by anyone with *any* legitimate account (a real user who
never touched injection at all) — fixing Stage 1 breaks *this specific attack chain*,
not the underlying access-control bug. That's exactly why real defense-in-depth fixes
both, not whichever one happens to be "upstream" in one particular incident's
narrative.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name the exact injection payload that worked, the exact note id
  the IDOR reached, and which of the five alerts you identified as the true positive —
  versus the four you ruled out and why each one specifically failed to hold up.
- **How:** which of the two "textbook trick doesn't quite work" moments (Stage 1's `OR
  '1'='1'` precedence trap, or an alert in Stage 3 whose claim didn't match the raw
  evidence) took longer to work through?
- **What defended it:** of Section 3's two concrete fixes (parameterized queries,
  ownership check), pick the one you'd implement first on a real system under time
  pressure, and say why.
- **What confused me:** anything about why an IDOR bug doesn't care which account
  Stage 1 landed you as, or about telling a real detection signal apart from a
  correlating-but-irrelevant one (A5), that didn't click on first pass.
- **One thing to revisit:** pick one term from Phase 2 (injection, prepared statement,
  IDOR, broken access control, SSRF, CSRF, true/false positive, detection engineering)
  to re-explain from memory before starting Phase 3, without looking back at any file.

This is also an **end-of-Phase-2 checkpoint**, same structure as Day 6's end-of-Phase-1
retro: before moving on, skim back over `content/day07-http.md` through today and
confirm you could still explain, from memory, what each day's core bug was and what
specifically fixed it. If any day's answer doesn't come immediately, that's the day to
revisit before Day 13.

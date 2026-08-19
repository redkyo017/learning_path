# `labs/day06` — Solution / expected outputs

**How to read this file:** no Terraform was applied and no AWS API calls
were made while authoring this lab — that's a hard constraint on how this
path is built (no credentials, no `terraform apply`, by the author; see
`content/day06-waf-edge.md`'s teardown note and `.superpowers` day
constraints). Every status code and log field below is what AWS's
documented behavior for `AWSManagedRulesCommonRuleSet`,
`AWSManagedRulesSQLiRuleSet`, and rate-based rules predicts for exactly
the requests in `README.md` — not a captured transcript. When you run
this lab for real, your job is to confirm your own output matches this
table; if it doesn't, that mismatch is itself worth a `journal.md` entry
(rule sets get updated by AWS over time, so a drift here is a legitimate
finding, not necessarily a mistake).

## THE BREAK — expected status codes (no Web ACL attached)

| # | Request | Expected | Why |
|---|---|---|---|
| 1 | `GET /?id=1' OR '1'='1' --` | `200` | `/` is the health-check route — it returns `"ok", 200` unconditionally and never even reads the query string. Nothing in front of it (no Web ACL yet) inspects the request either. |
| 2 | `GET /fetch?url=http://example.com&id=1' OR '1'='1' --` | `200` | The app reads only `url`, ignores `id` entirely, successfully fetches `http://example.com`, and returns its body + status verbatim. |
| 3 | `GET /whoami?comment=<script>alert(1)</script>` | `200` | `/whoami` returns the STS caller identity as JSON regardless of query string; the payload is present in the request but never read or reflected by this route. |
| 4 | `GET /fetch?url=<script>alert(document.domain)</script>` | non-`200` (`502`), body reflects payload | `requests.get("<script>alert(document.domain)</script>")` raises `requests.exceptions.MissingSchema: Invalid URL '<script>alert(document.domain)</script>': No scheme supplied. ...`, caught by `except requests.RequestException as exc: return jsonify(error=str(exc)), 502`. The exact payload string appears **verbatim, unescaped**, inside that JSON error body — the reflection signal for this request. |

Row 4 lands at `502`, not `200` — flagged here explicitly because the
brief's success signal is "`200` / reflected" (either signal, not both):
row 4 demonstrates *reflected*, rows 1–3 demonstrate *200*. All four
demonstrate the same underlying fact: nothing at the edge inspects any of
this content before it reaches the application.

## THE HARDEN — expected status codes (Web ACL attached, `tune_generic_rfi_false_positive = false`)

| # | Request | Expected | Matching rule |
|---|---|---|---|
| 1 | SQLi @ `/` | `403` | `AWSManagedRulesSQLiRuleSet` — the `id` query argument matches a SQLi signature |
| 2 | SQLi @ `/fetch` | `403` | `AWSManagedRulesSQLiRuleSet` on `id`, **and** `GenericRFI_QUERYARGUMENTS` (inside `AWSManagedRulesCommonRuleSet`) on the `http://` in `url=` — either alone would block this request; whichever the WAF engine reports first in the log is a query away, not something to guess |
| 3 | XSS @ `/whoami` | `403` | `CrossSiteScripting_QUERYARGUMENTS` inside `AWSManagedRulesCommonRuleSet` matches `<script>` in `comment=` |
| 4 | XSS @ `/fetch` (as target) | `403` | same `CrossSiteScripting_QUERYARGUMENTS` match on `url=` — the request never reaches the ECS task this time, so the app-level `MissingSchema` behavior from THE BREAK never happens; the Web ACL's decision replaces it entirely |

**The 200 → 403 contrast on all four rows is the lab's primary success
signal.**

Sample expected `aws_wafv2_web_acl_logging_configuration` log entry
(fields trimmed to what matters for this check; real entries are much
longer):

```json
{
  "timestamp": 1755650000000,
  "webaclId": "arn:aws:wafv2:us-east-1:<account>:regional/webacl/aws-sec-lab-day06-webacl/<id>",
  "action": "BLOCK",
  "terminatingRuleId": "aws-common-rules",
  "terminatingRuleType": "MANAGED_RULE_GROUP",
  "httpRequest": {
    "uri": "/whoami",
    "args": "comment=<script>alert(1)</script>"
  },
  "ruleGroupList": [
    {
      "ruleGroupId": "AWSManagedRulesCommonRuleSet",
      "terminatingRule": {
        "ruleId": "CrossSiteScripting_QUERYARGUMENTS",
        "action": "BLOCK"
      }
    }
  ]
}
```

## THE FALSE POSITIVE — before and after the tune

| Request | `tune_generic_rfi_false_positive = false` | `= true` |
|---|---|---|
| `GET /fetch?url=https://example.com` (no attack content) | `403` — false positive | `200` — fixed |
| `GET /?id=1' OR '1'='1' --` (the SQLi attack) | `403` | still `403` — unaffected |
| `GET /whoami?comment=<script>alert(1)</script>` (the XSS attack) | `403` | still `403` — unaffected |

**Root cause:** `GenericRFI_QUERYARGUMENTS` (a sub-rule inside
`AWSManagedRulesCommonRuleSet`) matches `scheme://` patterns — `http://`,
`https://`, `ftp://` — appearing anywhere in a query-string value. This
app's one designed feature is passing a target URL in exactly that shape
via `/fetch?url=<target>`, so *every* legitimate call to `/fetch`
contains the pattern the rule is looking for, attack or not.

**Fix, and why it's the right fix:** a `rule_action_override` on
`GenericRFI_QUERYARGUMENTS` specifically, set to `Count` instead of
`Block` (`main.tf`, gated by `var.tune_generic_rfi_false_positive`).
This is narrower than either of the two obviously-worse options:

- Disabling `AWSManagedRulesCommonRuleSet` entirely would also drop
  `CrossSiteScripting_QUERYARGUMENTS` (the rule blocking row 3/4's XSS
  attack) and the `EC2MetaDataSSRF_*` sub-rules (a compensating control
  against this same app's `/fetch` SSRF hole toward the ECS credential
  endpoint — see `content/day06-waf-edge.md` "The engine lens").
- Leaving it in `Block` mode "because the managed group knows best"
  (anti-pattern #7) would keep the app's core feature broken — a real
  production incident waiting to be filed as a bug against the app
  instead of recognized as a WAF tuning gap.

The override is intentionally scoped to only the one noisy sub-rule; the
rest of `AWSManagedRulesCommonRuleSet` — including the rule that
actually stopped today's XSS payload — keeps blocking.

## THE RATE LIMIT — expected split

Firing 130 requests in a tight loop against `alb_dns_name` directly
(default `limit = 100`, `evaluation_window_sec = 300`, `aggregate_key_type
= "IP"`, no `scope_down_statement` — every request to the ALB counts):

```
    ~100 200
     ~30 403
```

The exact boundary between the last `200` and the first `403` depends on
request timing and whatever else already counted toward your IP in the
current 5-minute window (including THE HARDEN's own SQLi/XSS test
requests above, which the rate-based rule counts too — every request
counts toward the limit regardless of which other rule also matched it).
Record your own observed split here once you run it:

```
Your run: ___ x 200, ___ x 403 (out of 130)
```

After waiting out the 5-minute window and re-sending a small burst
(`seq 1 5`), expect all `200` again — the rate-based rule has no manual
"unblock," it just re-evaluates the rolling window on every request.

## Anti-pattern tie-in (record this in `journal.md`)

- **#7 — WAF as a checkbox:** the false-positive section above IS the
  corrective in action — attach, observe a real block against legitimate
  traffic via the logs, fix the one sub-rule responsible, re-confirm both
  the attack is still blocked and the legitimate call isn't.
- **#3 — never actually testing a deny:** THE HARDEN section is the deny
  test (attack → `403`); THE TUNE section is the matching allow-path test
  (legit call → `200`) that anti-pattern #3 says not to skip.

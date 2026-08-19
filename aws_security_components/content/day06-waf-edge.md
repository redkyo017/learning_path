# Day 6 — Edge protection I (WAF)

## Why this matters at work

SQL injection and cross-site scripting have been in the OWASP Top 10 for
over a decade, and they still show up in production because fixing them
in application code is slow — it means a code review, a test, a
deploy, sometimes across a dozen endpoints written by people who left
the team years ago. A WAF Web ACL is the compensating control you can
put in front of a vulnerable app **today**, in minutes, while the real
code fix works its way through the backlog. It also does something app
code can't: it stops abusive request *volume* — a credential-stuffing
run, a scraper, a single IP hammering `/login` — before any of it
burns compute or database capacity. Today you attack the base app's
edge directly, watch obviously malicious traffic sail through
untouched, then put a Web ACL in the way and watch the exact same
traffic get rejected.

## The engine lens

Every day so far has attached to a door in the IAM evaluation order —
explicit deny, resource policy, identity policy, and so on. WAF is
different: it sits **in front of** that whole engine, not inside it. A
request has to clear the Web ACL before it ever reaches the ALB
listener or CloudFront's cache behavior — before any IAM policy, S3
bucket policy, or KMS key policy gets a chance to run at all. Blocked
at WAF means the request never becomes an AWS API call in the first
place, so there's nothing for the evaluation order to evaluate.

That said, a Web ACL's *own* rule evaluation rhymes with the engine you
already know: an ordered list of rules, evaluated by priority, where
the first rule with a **terminating action** (`Block` or `Allow`, not
`Count`) decides the outcome and nothing after it runs. Same shape —
ordered checks, first decisive match wins — wearing WAF's syntax
instead of a policy document's. Recognizing that shape is the payoff of
[`STRATEGY.md`](STRATEGY.md)'s spine principle 1.

One more connection worth holding onto: the base app's `/fetch?url=`
endpoint is the exact SSRF hole Day 8/11 uses to steal the ECS task
role's credentials from the container credential endpoint. AWS's
`AWSManagedRulesCommonRuleSet` ships a rule named `EC2MetaDataSSRF_*`
that specifically looks for metadata-endpoint IPs in requests — a
compensating control against that same attack path, sitting at the
edge, months before anyone gets around to fixing the SSRF in code.
WAF doesn't replace the Day 1/8 fixes (scoping the task role,
allow-listing `/fetch`'s target host) — it's a second, independent
layer that has to be defeated too.

## Core concepts

### Web ACL: the top-level resource

A **Web ACL** ([glossary](GLOSSARY.md#w)) is an ordered set of rules
and rule groups attached to one of three things: an ALB, a CloudFront
distribution, or an API Gateway/AppSync API. Every request to the
attached resource is evaluated against every rule (by priority) until
one produces a terminating decision; if nothing terminates, the Web
ACL's `default_action` (typically `Allow`) applies.

### Scope: REGIONAL vs CLOUDFRONT — this is not a detail, it changes where things live

This is the distinction the brief for today calls out explicitly,
and it trips people up because it looks like a minor flag:

| | `scope = "REGIONAL"` | `scope = "CLOUDFRONT"` |
|---|---|---|
| Protects | ALB, API Gateway, AppSync | CloudFront distributions |
| Web ACL must be created in | the same region as the protected resource | **always `us-east-1`**, regardless of where the distribution's origin lives |
| Attached via | a separate `aws_wafv2_web_acl_association` resource | the distribution's own `web_acl_id` field, set directly on the distribution config |
| Sees client IP as | the actual caller's IP hitting the ALB directly (or CloudFront's edge IP if CloudFront is the caller — see exercise 3) | the real end-viewer's IP at the CloudFront edge |

**Today's lab uses `REGIONAL`, attached to `labs/base`'s ALB.** That
choice is deliberate, not arbitrary: it lets us test with a plain
`curl` against `alb_dns_name` and see the block immediately, with no
CloudFront propagation delay (the base README already flags that
CloudFront distributions take several minutes to reach `Deployed`).
Protecting the CloudFront distribution instead is a legitimate,
common production pattern — it would require creating a *second*,
`CLOUDFRONT`-scoped Web ACL specifically in `us-east-1` (via an aliased
provider if your lab region is different) and setting it on the
distribution's `web_acl_id`. We call that out as the road not taken
rather than build both; know that the scope difference exists and
which one you'd reach for when the resource in front of your app is
CloudFront instead of (or in addition to) an ALB.

### Managed rule groups vs custom rules

- **Managed rule group** ([glossary](GLOSSARY.md#m)) — a pre-built
  bundle AWS (or a Marketplace vendor) maintains for a known threat
  class. `AWSManagedRulesCommonRuleSet` covers a broad mix (XSS,
  generic LFI/RFI, oversized bodies, the SSRF-to-metadata pattern
  mentioned above); `AWSManagedRulesSQLiRuleSet` is a dedicated,
  narrower SQL-injection detector. You attach a group as a unit; AWS
  updates its signatures over time without you touching Terraform.
- **Custom rule** — you write the match condition yourself: a
  byte-match against a URI path or header, a geo-match, an IP-set
  match, a size constraint, or a **rate-based rule** (below). Custom
  rules are where you encode things specific to *your* app that no
  managed group could know about.

### Rule priority and evaluation order

Rules run in ascending `priority` order. The first rule whose
statement matches **and** whose action is terminating (`Block` or
`Allow`) decides the request; every rule after it is skipped. A rule
whose action is `Count` never terminates — evaluation keeps moving to
the next rule even on a match. This is why rule *order* matters as much
as rule *content*: a broad rate-based `Block` at priority 1 will decide
a request before a more specific managed-rule-group check at priority
5 ever runs (see exercise 2).

### Count vs Block — WAF's "shadow mode"

Every rule (and every managed rule group as a whole, via
`override_action`) can run in `Count` mode instead of `Block`: the
request is logged and the metric increments, but nothing is stopped.
This is the standard way to safely stage a new rule against real
traffic before you trust it to reject anything — attach in `Count`,
watch the logs for a while, confirm nothing legitimate would have been
blocked, *then* flip to `Block`. Skipping this staging step and going
straight to `Block` on day one is exactly [anti-pattern
#7](ANTIPATTERNS.md#7-waf-as-a-checkbox-instead-of-tuned-and-tested).

Inside a managed rule group specifically, you don't have to accept the
group's default action for every sub-rule. A `rule_action_override`
lets you flip **one named sub-rule** (e.g.
`GenericRFI_QUERYARGUMENTS`) to `Count` while every other sub-rule in
that same group keeps blocking — surgical tuning instead of an
all-or-nothing choice between "whole group blocks" and "whole group
doesn't." Today's harden step uses exactly this.

### Rate-based rules

A [rate-based rule](GLOSSARY.md#r) counts requests from an aggregation
key — by default the source IP, but it can be a custom key such as a
header value — over a rolling evaluation window (60/120/300/600
seconds; 300s/5min is the common default), and applies its action
once a request from that key crosses the configured `limit` within the
window (AWS's minimum allowed `limit` is 100). It "unblocks"
automatically once the rate for that key falls back under the
threshold within the window — there's nothing to manually clear. A
`scope_down_statement` narrows what counts toward the limit at all
(e.g. only requests to a specific path) — see exercise 1.

One gotcha worth internalizing now, because it will bite in any real
architecture that puts CloudFront in front of an ALB (exactly
`labs/base`'s topology): a `REGIONAL` Web ACL on the ALB, by default,
counts by the IP address of whoever is *directly* calling the ALB.
When traffic arrives via CloudFront, that's CloudFront's edge IP, not
the original viewer's — every viewer's requests get lumped into the
same handful of CloudFront IPs, which defeats a per-client rate limit.
The fix, if you need rate limiting *and* CloudFront in the path, is a
`forwarded_ip_config` pointed at the `X-Forwarded-For` header (trusted
only because CloudFront reliably sets it). Today's lab avoids the
problem by testing directly against `alb_dns_name`, matching the base
README's own "fastest to use while iterating" guidance — but exercise
3 walks through diagnosing it, because production traffic won't have
that luxury.

### WAF logging

A Web ACL doesn't log anywhere by default — you opt in with an
`aws_wafv2_web_acl_logging_configuration`, pointed at either a
CloudWatch Logs log group (whose name **must** start with the literal
prefix `aws-waf-logs-`, an AWS-enforced naming rule) or a Kinesis Data
Firehose delivery stream feeding S3. Each log entry records the full
request context, which rule/rule-group matched, and the resulting
action — this is how you find out *which specific sub-rule* blocked a
false positive instead of guessing (see the harden step). Without this
logging turned on, `Count` mode is close to useless — you'd have no
way to see what would have been blocked. (Prereq note: tailing that log
group with `aws logs tail`, as `labs/day06/README.md` does, requires
AWS CLI v2 — the command doesn't exist in CLI v1.)

## Break → Harden lab

See `labs/day06/`. **The break:** fire SQLi/XSS-shaped payloads at the
base app's ALB with no Web ACL attached — they land uninspected; three
of the four requests come back `HTTP 200`, and the fourth (the XSS
payload against `/fetch`) comes back `502` with the payload reflected
verbatim in the error body instead of `200` — the app's own exception
handling for an invalid URL, not a block, so it still counts as "landed
untouched" (see `labs/day06/SOLUTION.md` for exactly why). **The
harden:** attach a `REGIONAL` Web ACL (AWS Managed Common Rule Set + AWS
Managed SQLi Rule Set + a rate-based rule) to the ALB, re-send the
identical payloads — `HTTP 403`. Then tune one real false positive the
Common Rule Set introduces against this app's own legitimate traffic
shape. **Success signal:** the exact same request goes `200`/`502` →
`403` after the Web ACL is attached, while a benign call to the app
keeps returning `200` after tuning.

## Exercises

1. **Write a rate-based rule scoped to the path `/login`** with a
   limit of 100 requests per 5-minute window, `Block` action, so it
   only counts requests to that one path instead of every request to
   the site. — **Hint:** a rate-based rule takes an optional
   `scope_down_statement`; use a `byte_match_statement` against
   `field_to_match { uri_path {} }` with `positional_constraint =
   "EXACTLY"` and `search_string = "/login"`. — **Solution sketch:**
   ```hcl
   rule {
     name     = "rate-limit-login"
     priority = 10
     action { block {} }
     statement {
       rate_based_statement {
         limit              = 100
         evaluation_window_sec = 300
         aggregate_key_type = "IP"
         scope_down_statement {
           byte_match_statement {
             search_string         = "/login"
             positional_constraint  = "EXACTLY"
             field_to_match { uri_path {} }
             text_transformation {
               priority = 0
               type     = "NONE"
             }
           }
         }
       }
     }
     visibility_config {
       cloudwatch_metrics_enabled = true
       sampled_requests_enabled   = true
       metric_name                = "rate-limit-login"
     }
   }
   ```
   Every request outside `/login` never touches the rate counter at
   all, so a spike anywhere else on the app doesn't accidentally
   throttle login traffic.

2. **A Web ACL has a rate-based rule at priority 1 with action
   `Block`, and `AWSManagedRulesCommonRuleSet` at priority 2 in
   `Count` mode (staged, not yet trusted). A client sends 150 requests
   in five minutes to `/fetch`, and every single one also carries a
   naive SQLi payload in the query string. What happens to request
   #101, and why doesn't the SQLi content matter for the answer?** —
   **Hint:** re-read "Rule priority and evaluation order" — think
   about which of the two rules can actually terminate the request. —
   **Solution:** request #101 gets `403`'d by the priority-1 rate rule
   before the priority-2 Common Rule Set is ever evaluated — the rate
   rule is a terminating `Block`, so evaluation stops there. The SQLi
   payload is irrelevant to *this particular* request's outcome
   because the Common Rule Set never gets a turn to look at it; it
   would only have mattered if the rate rule had let the request
   through (or if it were in `Count` mode too, or ordered after it).

3. **A learner attaches today's rate-based rule (limit 100/5min,
   default `aggregate_key_type = "IP"`) to the ALB and confirms it
   trips after ~100 rapid requests when testing directly against
   `alb_dns_name`. They then repeat the exact same burst through the
   CloudFront distribution's domain instead, and it never trips even
   after 500 requests. Why?** — **Hint:** what IP address does the
   `REGIONAL` Web ACL on the ALB actually see when the caller is
   CloudFront itself, not the original browser? — **Solution:**
   CloudFront terminates the viewer's connection and makes its *own*
   HTTP call to the ALB as the origin request — so the ALB (and the
   Web ACL attached to it) sees CloudFront's small set of shared edge
   IPs as the source, not the individual viewers' IPs. Every distinct
   viewer's requests get pooled onto the same few aggregation keys,
   diluting any one viewer's count well below the threshold. The fix
   is a `forwarded_ip_config` block on the rate-based statement reading
   the client IP from `X-Forwarded-For` (trustworthy specifically
   because CloudFront sets that header itself), or moving the rate
   limit to a second, `CLOUDFRONT`-scope Web ACL attached to the
   distribution directly, which sees the real viewer IP natively.

4. **After attaching `AWSManagedRulesCommonRuleSet` in `Block` mode,
   every legitimate call to `/fetch?url=https://example.com` starts
   returning `403`, even though nothing malicious is in the request.
   Which specific sub-rule is almost certainly responsible, and how do
   you fix it without disabling the whole managed group?** — **Hint:**
   think about what `/fetch`'s one design feature — a URL passed
   straight through as a query argument — looks like to a signature
   that scans for remote-file-inclusion patterns. — **Solution:**
   `GenericRFI_QUERYARGUMENTS` matches `scheme://` patterns
   (`http://`, `https://`, `ftp://`) appearing in query-string values —
   which is exactly what `/fetch?url=...` legitimately contains on
   every single call, malicious or not. Don't turn off the whole
   Common Rule Set to fix one noisy sub-rule: add a
   `rule_action_override` for `GenericRFI_QUERYARGUMENTS` with
   `action_to_use { count {} }`, leaving every other sub-rule in the
   group still blocking. This is exactly the false-positive tuning
   step `labs/day06/` walks through.

## Anti-patterns today

- [**#7 — WAF as a checkbox instead of tuned and
  tested**](ANTIPATTERNS.md#7-waf-as-a-checkbox-instead-of-tuned-and-tested):
  attaching `AWSManagedRulesCommonRuleSet` and calling WAF "done" is
  exactly the failure mode today's lab makes concrete — the harden step
  doesn't stop at "attached," it finds and fixes a real false positive
  (`GenericRFI_QUERYARGUMENTS` against `/fetch`'s own legitimate query
  string) using the logs, and re-confirms both the attack is still
  blocked *and* the legitimate call is not.
- [**#3 — Never actually testing a deny**](ANTIPATTERNS.md#3-never-actually-testing-a-deny):
  today's break→harden *is* a deny test — you don't get to claim the
  Web ACL works until you've re-run the identical payload and watched
  `200` become `403` yourself. But #3 cuts both ways: after tuning,
  also re-test the *allow* path (a benign request) — a Web ACL that
  blocks everything, attack or not, "passes" a deny test just as
  easily as a correctly tuned one, and only testing the deny side would
  miss that.

## Cert corner (SCS-C02)

Domain 3, **Infrastructure Security** (~20% of the exam, per
[`CERT-MAP.md`](CERT-MAP.md) — the heaviest single domain, and Days 5–7
are its primary build):

- Know the `REGIONAL` vs `CLOUDFRONT` Web ACL scope split cold — which
  resources each protects, and that `CLOUDFRONT`-scope Web ACLs must be
  created in `us-east-1` regardless of the distribution's footprint.
  This exact distinction shows up as an exam distractor.
- Know the difference between a managed rule group (signature-based,
  AWS-maintained) and a custom rule (rate-based, byte-match, geo-match,
  IP-set) — and that `Count` vs `Block` is how you safely stage either
  one before trusting it.
- Rate-based rules are WAF's answer to layer-7 volumetric abuse
  (credential stuffing, scraping, a brute-force `/login` loop) — the
  complement to Day 7's Shield/network-layer DDoS mitigation, not a
  substitute for it.

## Teardown

A `wafv2` Web ACL bills **hourly** (a flat per-Web-ACL charge plus a
per-rule/rule-group charge, plus a small per-million-requests fee and
whatever the CloudWatch Logs log group costs to retain) for as long as
it exists — unlike the base workload's KMS/S3/DynamoDB/Secrets Manager
resources, there is no "cheap to leave up" case for a Web ACL you're
not actively using. **Destroy the Day 6 Web ACL, its ALB association,
and its logging configuration the same day**, alongside the
association resource — never let it roll into tomorrow's session.

```bash
cd labs/day06
terraform destroy
```

Confirm zero billable resources per the checklist in `labs/day06/README.md`.
The base ALB is untouched by this — only today's Web ACL, association,
and log group are removed; `labs/base`'s own daily ALB/CloudFront
teardown (see `labs/base/README.md`) is a separate, independent step.

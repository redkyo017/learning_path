# `labs/day06` — Edge protection I (WAF)

Layers a `REGIONAL` WAFv2 Web ACL on top of `labs/base`'s ALB: AWS Managed
Common Rule Set + AWS Managed SQLi Rule Set + a rate-based rule, with
CloudWatch Logs turned on. See [`content/day06-waf-edge.md`](../../content/day06-waf-edge.md)
for the full write-up (scope choice, rule priority, count vs block).

> ## ⚠️ Authorized testing only
>
> Every attack in this lab is run **against your own AWS account and your
> own `labs/base` deployment only** — the SQLi/XSS payloads below, and the
> rate-limit burst test, must never be pointed at any resource you do not
> own and are not explicitly authorized to test. See
> [`content/ANTIPATTERNS.md`](../../content/ANTIPATTERNS.md)'s
> "Authorized-testing statement" (the canonical source every offensive lab
> in this path links back to).

## Objective

1. **Break:** confirm SQLi- and XSS-shaped payloads reach the base app
   completely uninspected — no Web ACL is attached yet.
2. **Harden:** attach a Web ACL to the ALB and re-run the identical
   payloads — they're now blocked before the app ever sees them.
3. **Tune:** find and fix the one real false positive the Common Rule Set
   introduces against this app's own `/fetch?url=` traffic, without
   disabling the whole managed group.
4. **Rate limit:** confirm the rate-based rule independently blocks a
   request burst, regardless of payload content.

## Prerequisites

- `labs/base` is applied and `terraform output -raw alb_dns_name` returns
  a real DNS name (see `labs/base/README.md`). The ECS service must be
  `RUNNING` — confirm with `curl "http://<alb_dns_name>/"` returning `ok`.
- Terraform >= 1.6, AWS provider >= 5.0 — same as `labs/base`.
- **This module is not applied by its author.** Terraform is not
  installed in the environment that wrote it; every `.tf` file here was
  validated by manual review against the `aws_wafv2_web_acl` /
  `aws_wafv2_web_acl_association` / `aws_wafv2_web_acl_logging_configuration`
  schema, not by running `terraform validate`/`plan`/`apply`. You run
  Terraform yourself.

## THE BREAK — attack the unprotected ALB

No Web ACL exists yet. Get the ALB's DNS name straight from base (day06
hasn't been applied, so there's nothing to read a day06 output from yet):

```bash
cd labs/base
ALB=$(terraform output -raw alb_dns_name)
cd ../day06
```

Fire the payloads:

```bash
# 1. SQLi-shaped query string at the health-check path.
curl -s -o /dev/null -w 'SQLi @ / -> %{http_code}\n' \
  "http://${ALB}/?id=1%27%20OR%20%271%27%3D%271%27%20--"

# 2. SQLi-shaped query string mixed into a real /fetch call.
curl -s -o /dev/null -w "SQLi @ /fetch -> %{http_code}\n" \
  "http://${ALB}/fetch?url=http://example.com&id=1' OR '1'='1' --"

# 3. XSS-shaped query string at /whoami (ignored by the app, but should
#    still reach it).
curl -s -o /dev/null -w 'XSS @ /whoami -> %{http_code}\n' \
  "http://${ALB}/whoami?comment=<script>alert(1)</script>"

# 4. XSS-shaped payload as the /fetch target itself — the app tries (and
#    fails) to fetch it as a URL, and reflects the exact string back in
#    its own JSON error body.
curl -s "http://${ALB}/fetch?url=<script>alert(document.domain)</script>"
```

**Expected (no Web ACL attached):**

| # | Request | Expected result |
|---|---|---|
| 1 | SQLi @ `/` | `200` |
| 2 | SQLi @ `/fetch` | `200` (the fetch to `example.com` succeeds; the SQLi-shaped `id` param is simply ignored by the app, and by everything in front of it) |
| 3 | XSS @ `/whoami` | `200` (payload ignored by the app, but nothing at the edge inspected or blocked it either) |
| 4 | XSS @ `/fetch` (as target) | non-`200` from the *app's own* exception handling (`requests.exceptions.MissingSchema`), body contains the literal `<script>alert(document.domain)</script>` string verbatim — reflected, completely unfiltered |

The point of all four: nothing between the internet and this Flask app is
looking at the content of these requests at all. Record the exact
status codes and bodies in your own run — `SOLUTION.md` has the reference
values.

## THE HARDEN — attach the Web ACL

```bash
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: region/project MUST match labs/base's values
terraform init
terraform plan
terraform apply
```

This first apply uses `tune_generic_rfi_false_positive = false` (the
variable's default in `variables.tf` — `terraform.tfvars.example` leaves
it commented out on purpose) — so you see the false positive below
before you fix it.

Re-run the exact same four `curl` commands from THE BREAK, unchanged.

**Expected (Web ACL attached, not yet tuned):**

| # | Request | Expected result | Why |
|---|---|---|---|
| 1 | SQLi @ `/` | `403` | `AWSManagedRulesSQLiRuleSet` matches the `id` query argument |
| 2 | SQLi @ `/fetch` | `403` | same SQLi rule set match, plus `GenericRFI_QUERYARGUMENTS` also matches the `http://` in `url=` |
| 3 | XSS @ `/whoami` | `403` | `CrossSiteScripting_QUERYARGUMENTS` in the Common Rule Set matches `comment=<script>...` |
| 4 | XSS @ `/fetch` (as target) | `403` | same `CrossSiteScripting_QUERYARGUMENTS` match — note the request never reaches the app at all now, so the app's own `MissingSchema` behavior from THE BREAK is irrelevant; WAF decided first |

**This 200 → 403 contrast on requests 1–4 is today's core success
signal.** Confirm it, then keep going — attaching rules and stopping here
is exactly [anti-pattern #7](../../content/ANTIPATTERNS.md#7-waf-as-a-checkbox-instead-of-tuned-and-tested).

### Now find the false positive

Try a request with **no attack payload at all** — the app's actual,
intended feature:

```bash
curl -s -o /dev/null -w 'legit /fetch -> %{http_code}\n' \
  "http://${ALB}/fetch?url=https://example.com"
```

**Expected right now: `403`.** This is a real false positive, not a
contrived one — `GenericRFI_QUERYARGUMENTS` matches any `scheme://` in a
query argument, and `/fetch?url=<target>` legitimately contains one on
every call. Confirm this in the WAF logs (log group name is the
`log_group_name` output):

```bash
aws logs tail "$(terraform output -raw log_group_name)" --since 10m --format short
```

Look for a log entry with `"action":"BLOCK"` and
`"terminatingRuleId":"AWSManagedRulesCommonRuleSet"` whose
`"nonTerminatingOrTerminatingMatchingRules"`/rule detail names
`GenericRFI_QUERYARGUMENTS` — the exact evidence that this specific
sub-rule, not the SQLi rule set, is the one blocking legitimate traffic.

### THE TUNE — fix it without disabling the whole group

Edit `terraform.tfvars`:

```hcl
tune_generic_rfi_false_positive = true
```

```bash
terraform apply
```

Re-run both checks:

```bash
# Legitimate traffic: back to 200.
curl -s -o /dev/null -w 'legit /fetch -> %{http_code}\n' \
  "http://${ALB}/fetch?url=https://example.com"

# The original attack payloads: still 403 — tuning one sub-rule to Count
# did not reopen the door.
curl -s -o /dev/null -w 'SQLi @ / -> %{http_code}\n' \
  "http://${ALB}/?id=1%27%20OR%20%271%27%3D%271%27%20--"
curl -s -o /dev/null -w 'XSS @ /whoami -> %{http_code}\n' \
  "http://${ALB}/whoami?comment=<script>alert(1)</script>"
```

**Expected:** legit `/fetch` call → `200` again; both attack payloads →
still `403`. Record all six status codes (before/after/tuned) in
`SOLUTION.md`.

## THE RATE LIMIT — an independent control, tested independently

The rate-based rule (priority 3, `limit = 100` requests / `300`s,
default in `variables.tf`) blocks by request *volume*, regardless of
payload content. Test it against `alb_dns_name` directly — **not** the
CloudFront domain (see `content/day06-waf-edge.md` "Rate-based rules" —
a `REGIONAL` Web ACL on the ALB counts by whoever calls the ALB directly,
and that's CloudFront's shared edge IPs if you go through CloudFront,
which won't trip on your single client's burst):

```bash
for i in $(seq 1 130); do
  curl -s -o /dev/null -w '%{http_code}\n' "http://${ALB}/"
done | sort | uniq -c
```

**Expected:** roughly the first ~100 lines read `200`, the rest read
`403` — the exact count depends on ambient traffic already counted in
the current 5-minute window. Record your actual split in `SOLUTION.md`.
Wait 5 minutes (the evaluation window) and repeat a small burst
(`seq 1 5`) to confirm it returns to all-`200` once the window rolls.

## Teardown checklist

A WAFv2 Web ACL bills **hourly** for as long as it exists (flat per-ACL
fee + per-rule/rule-group fee + per-million-request fee), with no "cheap
to leave up" exception — unlike `labs/base`'s KMS/S3/DynamoDB/Secrets
Manager resources. **Destroy this module the same day**, before the
base's own daily ALB/CloudFront teardown:

```bash
cd labs/day06
terraform destroy
```

Confirm:

- [ ] `terraform state list` for this module is empty (or the command
      errors because the state file is gone — either is fine).
- [ ] AWS Console (or
      `aws wafv2 list-web-acls --scope REGIONAL`) shows no Web ACL named
      `<project>-day06-webacl`.
- [ ] The CloudWatch Logs log group `aws-waf-logs-<project>-day06` is
      gone (or note it if you intentionally kept it briefly to review
      logs — delete it before ending the session; it costs pennies but
      isn't free).
- [ ] `labs/base`'s ALB (`aws_lb.app`) is **untouched** — this module
      only removes the association and the Web ACL, never the ALB
      itself. Base's own daily teardown (ALB/listener/target
      group/ECS/CloudFront) is a separate step — see
      `labs/base/README.md`.

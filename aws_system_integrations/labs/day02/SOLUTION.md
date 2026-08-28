# Day 2 Lab — Solution Notes

## ALB listener rule priority

ALB evaluates listener rules in ascending priority order: **lower number = higher priority = evaluated first**. The default action on the listener (the `default_action` block) is always last — it is the fallback when no rule matches.

In this lab:
- `header_v2` rule: priority `1` — evaluated before anything else
- Default action (weighted forward): evaluated only when the header rule does not match

Why this order matters: if the weighted default had priority 1 and the header rule had priority 2, requests with `x-api-version: v2` could still hit v1 when the weighted coin flip picks v1. By giving the header rule the lowest priority number, any request with that header is pinned to v2 before the weighted rule is ever consulted.

**Practical rule:** always assign header and path overrides lower priority numbers than catch-all defaults.

---

## Weighted target group mechanics

### What happens when one weighted target group has no healthy targets?

This is the Break it exercise answer.

ALB does **not** silently redistribute traffic from an unhealthy weighted group to a healthy one. When ALL targets in a weighted target group are unhealthy (either failed health checks or deregistered), ALB returns **502 Bad Gateway** or **503 Service Unavailable** for the proportion of requests routed to that group.

At 90/10 (v1/v2):
- ~90% of requests hit v1-tg → healthy → return 200
- ~10% of requests hit v2-tg → all targets unhealthy → return 502/503

The ALB does not detect that v2-tg is unhealthy and compensate by routing that 10% to v1-tg. The weight is honoured, the target group is selected, and the group returns an error.

**Why this design matters for canary deploy:**
- A 10% canary weight with an unhealthy v2 will cause 10% error rate for production users.
- Monitor v2-tg health checks and error rates *before* increasing canary weight.
- Use CloudWatch ALB metrics `HTTPCode_Target_5XX_Count` filtered by target group to catch this early.

### Healthy target group, unhealthy individual targets

If some (not all) targets in v2-tg are unhealthy, ALB distributes requests only among the healthy targets within that group. The weighted split between v1-tg and v2-tg is still honoured.

---

## Canary promotion sequence

To safely promote v2 from 10% to full:

1. **Validate at 10%:** Check CloudWatch `HTTPCode_Target_5XX_Count` for `v2-tg`. Check application-level error rates (CloudWatch Logs, X-Ray). Allow 24–48 hours of traffic at this weight.
2. **Increase to 50%:** Edit `terraform.tfvars`, set `v2_weight = 50`, run `terraform apply`. The ALB listener updates in-place — no service restart, no connection drops.
3. **Increase to 100%:** Set `v2_weight = 100`, run `terraform apply`. At this point v1-tg receives zero traffic.
4. **Decommission v1:** Remove `aws_lb_target_group_attachment.v1` and `aws_instance.api_v1` from `main.tf`, then `terraform apply`. The target group can also be removed.

The ALB listener rule itself (`header_v2`) continues to work at `v2_weight = 100` — it simply forwards to the same target group as the default action, which is harmless.

---

## Break it exercise — answer

**What does ALB do when v2-tg has no healthy targets (with 10% weight)?**

Answer: **(A) Returns 502/503 for approximately 10% of requests.**

ALB does not redistribute. The v2-tg weight is honoured, the group is selected for ~10% of requests, and because no healthy target exists, ALB returns a 5xx response. Legitimate v1 traffic (the 90%) is unaffected.

**To observe this:**
```bash
# Run 20 rapid requests:
for i in $(seq 1 20); do curl -s -o /dev/null -w "%{http_code}\n" http://<alb_dns_name>/; done
```

With v2 stopped, you will see approximately 2 out of 20 responses return 502 and the rest return 200.

**To observe the header-pinned path:**
```bash
curl -H "x-api-version: v2" http://<alb_dns_name>/
```

With v2 stopped, this returns 502 every time — because the header rule always routes to v2-tg, which has no healthy targets.

**Lesson:** During a canary deploy, monitor target group health checks continuously. Set a CloudWatch alarm on `UnHealthyHostCount` for v2-tg and page on any value greater than 0.

---

## Key Terraform patterns in this lab

| Pattern | Where | Why |
|---|---|---|
| `data "aws_ami"` instead of hardcoded ID | `main.tf` | AMI IDs are region-specific and change with AMI updates; data source always resolves the latest |
| `data "aws_subnets"` from default VPC | `main.tf` | Works in any account without knowing subnet IDs upfront |
| `forward` block with multiple `target_group` entries | `aws_lb_listener.http` | Enables weighted routing; weights do not need to sum to 100 — ALB normalises them |
| `priority = 1` on header rule | `aws_lb_listener_rule.header_v2` | Ensures header condition is checked before the weighted default |
| `stickiness { enabled = false }` | `aws_lb_listener.http` | Explicit; without this, ALB might use connection-based stickiness that breaks canary metrics |

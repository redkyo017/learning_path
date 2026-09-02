# Cost Safety Net

This path is designed to be cheap, but "designed to be cheap" only holds if
you do two things: set the budget alarm on Day 0, and actually run teardown
after every session. This file is the reference for both.

## Read this before Day 1

**Set the $10/month AWS Budget alarm in Day 0 before you touch anything
else.** It is non-negotiable, not because this path expects you to blow past
$10 — it doesn't, the target is ~$0.74 for the whole week if you tear down
after each session (up to ~$2.40 if you leave the Day 3 and Day 5 stacks up
overnight instead) — but because the
alarm is what makes the rest of the path *safe to experiment in*. Every lab
in this path asks you to break things on purpose: flip a poison switch,
widen a trust policy, kill a readiness probe. The budget alarm is the
backstop that means a mistake you don't notice for a day or two costs you an
email, not a surprise bill. If you haven't done Day 0 yet, stop and do it —
see [`labs/day00/README.md`](labs/day00/README.md).

## The three traps

Three resources are responsible for nearly every "why is my AWS bill higher
than expected" story in a CI/CD path like this one. Each has a binding
design rule this path adopts specifically to avoid it.

| Trap | Hourly cost | Design rule this path adopts |
|---|---|---|
| NAT gateway | ~$0.045/h (~$32/mo) plus per-GB processed | **Zero NAT gateways, path-wide.** Every Fargate task runs in a public subnet with `assign_public_ip = true`. No lab attaches CodeBuild to a VPC. If you ever see a NAT gateway in `terraform plan` output for this path, that's a bug — stop and re-read the lab. |
| Idle ALB | ~$0.0225/h plus LCU | **The ALB exists only in the Day 3 and Day 5 labs**, and only for the duration of those sessions. It is destroyed in Day 3's teardown and re-applied at the start of Day 5 (Day 5's alarms and canary need to observe a live stack) — it is never left running "just in case" between sessions. |
| EKS control plane | ~$0.10/h (~$73/mo) before nodes or networking | **No EKS control plane is ever applied.** Day 4 uses a free local `kind` cluster. The `labs/day04/eks/` Terraform is authored, for when a future dedicated EKS path needs it, but is explicitly marked never-applied. |

## Reference prices

Prices below are for **us-east-1** and are what this path's cost estimates
are built on. **Prices change — sanity-check current pricing at Day 0**
(AWS Pricing Calculator or the relevant service's pricing page) before you
assume these numbers still hold.

| Resource | Price | Notes for this path |
|---|---|---|
| CodeBuild `ARM_SMALL` | ~$0.0034/build-min | ~30% cheaper than x86 small; Go cross-compiles cleanly to arm64 |
| CodeBuild Lambda compute | cheaper still, faster cold start | Introduced on Day 1 as the default-beating choice |
| CodePipeline V2 | ~$0.002/action-min, 100 free action-min/month | The whole path likely lands inside the free allowance |
| ECR storage | ~$0.10/GB-month | `scratch`-based Go image ≈ 15 MB → effectively free |
| ECR basic scanning | free | Enhanced (Inspector) scanning is named but not enabled |
| Fargate 0.25 vCPU / 0.5 GB (arm64/Graviton) | ~$0.0099/h | One task; blue/green briefly doubles it. This path runs arm64 throughout — arm64 Fargate is ~20% cheaper than the x86 rate ($0.0123/h), which this file previously (and incorrectly) used |
| ALB | ~$0.0225/h + LCU | Days 3 and 5 only |
| CloudWatch alarms | 10 free, then ~$0.10/alarm-month | Path stays under 10 |
| CloudWatch Logs | ~$0.50/GB ingested | All log groups set to 1-day retention |
| CloudWatch Synthetics canary | ~$0.0012/run | Day 5, short window only |
| `kind` cluster | $0 | Day 4 |

## Cost per lab

"Cost while running" is what a normal ~3–4h session costs in metered usage.
"Cost if left overnight" only differs from that when the lab has a resource
billed by the hour (Fargate, ALB) that keeps accruing after you close your
laptop — CodeBuild and CodePipeline bill per build-minute / action-minute,
not per hour standing, so leaving Day 1 or Day 2 open overnight adds
essentially nothing. "Cost after teardown" excludes the foundation stack
(see below), which is meant to stay up all week at ~$0.

| Day | Billable resources | Cost while running | Cost if left overnight | Cost after teardown |
|---|---|---|---|---|
| 1 | CodeBuild (`ARM_SMALL`, ~15 build-min), ECR image storage | ~$0.20 | ~$0.20 (no hourly meter) | $0.00 |
| 2 | CodePipeline V2 (action-min), CodeBuild, GitHub Actions OIDC role (free) | ~$0.30 | ~$0.30 (no hourly meter) | $0.00 |
| 3 | Fargate tasks (blue/green briefly doubled), ALB, CodeDeploy (free), CloudWatch alarms | ~$0.13 | ~$0.78 (a full 24h of ALB + one Fargate task accruing hourly, not just the ~4h session) | $0.00 |
| 4 | `kind` cluster (local, $0) | $0.00 | $0.00 | $0.00 |
| 5 | Fargate + ALB (re-applied from Day 3), capstone CodeBuild/CodePipeline, Synthetics canary, composite alarm, CloudWatch alarms | ~$0.11 | ~$1.12 (same 24h ALB + Fargate as Day 3, plus a canary still firing every 5 min all night) | $0.00 |

**Worked math (Day 3, at this file's reference prices, arm64 Fargate):** a realistic ~4h session is ALB
`4h × $0.0225/h ≈ $0.09` plus Fargate `4h × $0.0099/h ≈ $0.04` ≈ **$0.13**.
Left running a full 24h instead (forgot teardown): ALB `24h × $0.0225 ≈ $0.54` plus Fargate
`24h × $0.0099 ≈ $0.24` ≈ **$0.78** — correctly *higher* than the while-running figure, since
"left overnight" means the meter kept running for hours nobody was watching, not fewer.

Day 5 adds the same Day-3-reapplied ALB/Fargate for a shorter, ~2h window (ALB `2h × $0.0225 ≈
$0.05` plus Fargate `2h × $0.0099 ≈ $0.02`, together ~$0.06), the capstone CodeBuild/CodePipeline
(~$0.02, mostly inside CodePipeline's 100 free action-min/month), and the Synthetics canary
(`$0.0012/run × 12 runs/h × 2h ≈ $0.03`) — **~$0.11** while running. Left overnight, the same 24h
ALB + Fargate math as Day 3 (~$0.78) plus a canary firing all night
(`24h × 12 runs/h × $0.0012 ≈ $0.35`) ≈ **~$1.12**.

Day 3 and Day 5 are the two days where forgetting teardown has a real
consequence — the ALB and its Fargate task don't stop billing just because
you stopped looking at them, and Day 5's canary keeps generating its own
traffic on schedule regardless of whether you're watching. Those overnight
figures are small in absolute terms, but they're also the exact numbers
that turn into "why is my bill ~$1.66 higher" — the sum of the two overnight
deltas above (Day 3's $0.78 − $0.13 = $0.65 plus Day 5's $1.12 − $0.11 =
$1.01) — if you forget teardown on both of those days during the week.

## What stays up all week

`labs/foundation/` — a VPC with an internet gateway and public subnets, plus
one ECR repository — is created once on Day 1 and left running until after
Day 5. It costs effectively **$0/month**: the VPC, IGW, subnets, and route
tables are free, and ECR storage for a ~15 MB image is around $0.002/month.

This is the one thing in the whole path that is explicitly safe to leave
running unattended. Everything else — every day lab's Fargate tasks, ALB,
CodePipeline resources, and CloudWatch alarms — is not, and should be torn
down at the end of each session per that day's `teardown.md`.

## Teardown discipline

The rule, every session, no exceptions:

1. Run `terraform destroy` in the lab directory.
2. Then run `labs/verify-teardown.sh` (see its `--help` for `--region` and
   `--prefix` flags).
3. **Never trust `terraform destroy`'s exit code alone.** A clean exit code
   only means Terraform successfully destroyed the resources *it knows
   about*. It says nothing about resources created outside Terraform's view
   — CodeDeploy-managed task sets and replacement target groups from a
   blue/green deployment, or a log group CodeBuild auto-creates on first
   run that was never imported into state. Those survive a "successful"
   destroy and keep billing. `verify-teardown.sh` is a read-only AWS API
   audit that catches exactly this class of leak.

## If you see an unexpected charge

1. Open **Cost Explorer**, group by **Service** for the last 7 days. This
   tells you which service is responsible.
2. Drill into that service and group by **Usage Type** — this distinguishes,
   for example, "ALB hours" from "ALB LCU-hours" from "data transfer."
3. Check the three usual culprits, in order, since they account for nearly
   every surprise in a path like this: **(1) a NAT gateway that shouldn't
   exist, (2) an ALB from Day 3 or Day 5 that didn't get destroyed, (3) a
   CloudWatch log group with no retention limit quietly accumulating GB-months.**
   All three are things `verify-teardown.sh` checks for directly.

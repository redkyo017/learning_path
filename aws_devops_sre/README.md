# AWS DevOps / SRE (CI/CD-First)

5-day CI/CD-first DevOps/SRE path. A pipeline is a chain of custody for an
artifact: every stage either preserves that custody or breaks it, and the
whole path is about learning to tell which. Scheduled work is ~3–4h/day,
~17h total across Days 1–5, plus a ~30 min Day 0 pre-flight.

## Prerequisites

- A personal AWS account (billing enabled, region us-east-1 recommended)
- A personal GitHub account
- Terraform >= 1.5
- AWS CLI v2
- Docker
- `kind` + `kubectl` (Day 4 only)
- Go 1.23

This path assumes VPC, IAM, and ALB fundamentals and does not re-teach them —
if any of those feel shaky, the sibling `aws_network_components/` and
`aws_security_components/` paths in this repo cover them from the ground up.

## Start here: Day 0

Before Day 1, work through [`labs/day00/README.md`](labs/day00/README.md).
It takes ~30 minutes and it is not optional: it sets the $10 AWS Budget
alarm that makes the rest of this path safe to experiment in, and it does
the one-time console handshake (CodeConnections → GitHub) that Day 2 needs.

## How to use this path

For each day, read `content/dayNN.md` first, then work `labs/dayNN/`. The
daily loop is the same every day:

**read → build → break → fix → tear down**

Read the concepts and decision rules, build the lab's Terraform, deliberately
break something to see the failure mode, fix it, then run that day's
teardown so nothing keeps billing after you log off.

## Day index

| Day | Chain link | Title | What you can do after | ~Cost |
|---|---|---|---|---|
| 1 | PRODUCE | What exactly is the artifact? | Answer "what code is in prod right now?" | ~$0.20 |
| 2 | PROMOTE | The pipeline is a promotion machine | Scope a GitHub OIDC trust policy correctly | ~$0.30 |
| 3 | REVERSE | Promotion is only safe if reversible | Ship a blue/green deploy with alarm rollback | ~$0.13 |
| 4 | (substrate) | Same chain, different substrate | Map the chain onto Kubernetes | $0.00 |
| 5 | MEASURE | Close the loop | Define SLOs and measure DORA from your pipeline | ~$0.11 |

PROVE has no day of its own — it is distributed across Days 1 and 2. See
`STRATEGY.md` for why.

## The foundation stack

`labs/foundation/` is a small shared stack — a public-subnet VPC and one ECR
repository — that you apply once, on Day 1, and leave running for the whole
week. It costs ~$0/month. Every day lab reads its outputs (`vpc_id`,
`public_subnet_ids`, `ecr_repository_url`) via `terraform_remote_state`
instead of re-creating a VPC and an image registry five times. You destroy
it only after Day 5, as the very last teardown step.

## Cost note

This path is designed so that following every teardown keeps the whole week
around **~$0.74** (tearing down after each session), rising to at most
**~$2.40** if you leave the Day 3 and Day 5 stacks up overnight instead —
see [`COST.md`](COST.md) for the full breakdown,
per-lab estimates, and the read-only `verify-teardown.sh` script that checks
whether you actually got to $0 between sessions. The three traps that blow
past that budget are a stray NAT gateway, an ALB left running overnight, and
an EKS control plane — none of which this path asks you to create by
accident, but all three are one wrong Terraform apply away.

## Scope boundary

Day 4 is deliberately capped at making you *conversant* in Kubernetes — able
to name the pod/deployment/service/ingress analogs of what you already
learned on ECS, and to explain why image immutability matters more there —
not *competent* to run it in production. Deep EKS, IRSA in anger, and GitOps
are their own future path.

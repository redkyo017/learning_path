# AWS CLI Mastery — Appendix Design Spec

**Date:** 2026-09-10
**Location:** `aws_devops_sre/` (appendix to the existing 5-day path)
**Duration:** 2 appendix days, ~3.5 h/day (~7h total), plus a standalone reference file
**Path type:** Applied / engineering → extends the existing `labs/` Terraform scaffold
**Depends on:** Days 1–3 of the main path (their stacks are the lab substrate)
**Learner:** Senior backend engineer (Golang), returning to hands-on IC work from management. Team stack: Terraform + AWS ECS Fargate. Company AWS access via IAM Identity Center (SSO); personal account via long-lived IAM user keys.

---

## Purpose & Goals

The main path uses the AWS CLI on every single day and teaches it on none of them. A count of the
existing content and labs turns up roughly **46 distinct command shapes** — `aws deploy
get-deployment` appears 18 times, `aws codebuild start-build` 11, plus `aws ecr describe-images`,
`aws iam simulate-principal-policy`, `aws logs describe-log-groups`, and the rest — every one of
them handed to the learner as a copy-paste incantation with the arguments already filled in.
Nothing anywhere in the path explains `--query`, `--output`, profiles, SSO login, assume-role,
pagination, waiters, `--dry-run`, or how to read the CLI's own error messages. A learner who
finishes Day 5 can run the path's commands and cannot yet write their own.

That gap is what this appendix closes, and the goal is deliberately narrower than "learn the AWS
CLI." The goal is **to be able to walk up to an AWS account — personal or the company's — and
answer a question about it, or safely change something in it, without a console tab and without
a tutorial**. Two competencies, in that order:

1. **Interrogate.** Given a question in English ("what image is that service actually running?",
   "is this thing really gone?", "why is this call denied?"), produce the command that answers it,
   read the answer correctly, and know when the answer is lying to you.
2. **Operate.** Given a change to make, predict its effect, know whether it is reversible before
   pressing enter, execute it, and verify convergence rather than trusting the API's acknowledgement.

Two things this appendix is explicitly *not*. It is not a service tour — `STRATEGY.md` already
names service-first learning as the single largest time sink in this field, and that verdict does
not change just because the interface changed from Terraform to a shell. And it is not a
scripting course; shell composition appears as a thread on Day A2, not as a pillar, because the
learner asked for interrogation and safe operation as the weighted priorities.

The appendix is **dependent**, not standalone. Its labs interrogate and mutate the stacks the
learner built on Days 1–3, which means every resource on screen is one they already understand
from the inside. Asking "what does this JSON mean?" about infrastructure you wrote yourself is a
fundamentally different exercise from asking it about a stranger's account, and it is the reason
this material belongs here rather than in a generic CLI course.

## Success Criteria

By the end of Day A2, without notes, the learner can:

1. **State the four things every `aws` invocation does** — resolve an identity, call one API
   operation, receive a full JSON response, display a chosen projection of it — and, given a
   failing command, name which of the four broke before attempting a fix.
2. **Explain the difference between `--filters` and `--query`** and state the three consequences
   of getting it wrong: no reduction in API calls or throttling, no reduction in transfer, and
   silently wrong answers when combined with pagination limits.
3. **Determine which identity a command will use before running it**, from `~/.aws/config`,
   `~/.aws/credentials`, environment variables, and the documented precedence order — and confirm
   it with `aws configure list` and `aws sts get-caller-identity`.
4. **Set up and refresh IAM Identity Center (SSO) access** — `aws configure sso`, `sso-session`
   blocks, `aws sso login` — and recognize an expired SSO token from its error alone, distinguishing
   it from a wrong key and from a missing permission.
5. **Write a JMESPath expression from memory** that filters a list, selects specific fields, and
   renames them into a flat table — and quote it correctly in `zsh`.
6. **Classify a CLI error into one of four families** (client-side validation, authorization,
   credential/expiry, resource-not-found-vs-empty) and state what each family rules out.
7. **Answer "what is actually deployed right now?"** for an ECS service by chaining CLI calls from
   service → task definition → image → ECR digest, with no console.
8. **Classify any mutating command into the reversibility taxonomy** — trivially reversible,
   reversible with effort, irreversible — and name at least three commands in the third bucket.
9. **Run a pre-flight before a mutation**: confirm identity, confirm target, capture current state
   for a revert, and use `--dry-run` where it exists (understanding that on EC2 it is an
   authorization probe, not a simulation).
10. **Use a waiter** instead of a hand-rolled polling loop, and check its exit status.
11. **Verify convergence after a mutation** by re-reading the resource, and explain why the
    mutation's own response is not evidence — including where eventual consistency bites.
12. **Explain what a CLI mutation does to Terraform state** and defend a rule for when reaching for
    the CLI against IaC-managed infrastructure is legitimate.
13. **Operate safely in an account they do not own**: default to read-only, use
    `simulate-principal-policy` to establish what they can do before trying, and distinguish what
    their IAM policy permits from what their team's change process permits.

## Constraints & Environment

**Inherits every standing constraint of the main path.** The three binding cost rules — zero NAT
gateways path-wide, no idle ALB, no EKS control plane — apply unchanged, and the appendix is
designed around them rather than asking for an exception.

| Constraint | How the appendix satisfies it |
|---|---|
| Zero NAT gateways | `labs/dayA2/` places its single Fargate task in a foundation public subnet with `assign_public_ip = true`, exactly as the main path's labs do. |
| No idle ALB | Day A2 needs an ECS service to mutate, but **not** an ALB. Re-standing `labs/day03/` would drag one in at ~$0.0225/h for drills that never route traffic. `labs/dayA2/` therefore authors a minimal ALB-less service. |
| No EKS | Untouched — the appendix never goes near Day 4's substrate. |
| Shell | `zsh` on macOS (darwin). JMESPath quoting guidance is written for `zsh` specifically, where an unquoted `[?Name=='x']` is a glob pattern and fails with `no matches found`. |
| CLI version | AWS CLI **v2** throughout. v2-only behavior (auto-pagination defaults, `--cli-auto-prompt`, the built-in pager, `aws configure sso`) is used freely and marked where a v1 habit would mislead. |
| Credentials in files | Unchanged and absolute: no real account IDs, ARNs, emails, or keys in any authored file. Placeholders plus fill-in comments; `*.tfvars.example` only. |
| Company account | Day A2's "operating in an account you don't own" material is **read-only by construction**. No drill in this appendix instructs the learner to mutate anything outside their personal account. |
| Authoring rule | Labs are written, never run. No `terraform apply`, no live AWS calls during authoring. |

**Cost.** Two new rows, both small, and neither introduces an hourly meter the learner isn't already
managing:

| Day | Billable resources | While running (~3.5h session) | Left overnight | After teardown |
|---|---|---|---|---|
| A1 | CodeBuild reruns (`ARM_SMALL`, ~6 build-min), existing ECR storage | ~$0.02 | ~$0.02 (no hourly meter) | $0.00 |
| A2 | One Fargate task (0.25 vCPU / 0.5 GB, arm64) for ~2h, CloudWatch alarms (under the 10 free), 1-day-retention logs | ~$0.03 | ~$0.24 (24h × $0.0099/h) | $0.00 |

Worked at `COST.md`'s own reference prices: A2 running is Fargate `2h × $0.0099/h ≈ $0.02` plus a
handful of build-minutes and effectively-free alarms and logs. The path total moves from **~$0.74 to
~$0.79** for a full week with teardown after every session. `labs/verify-teardown.sh` needs **no
change** to cover the appendix: its ECS check enumerates every cluster in the region and filters on
`*${PREFIX}*`, and its alarm check uses `--alarm-name-prefix ${PREFIX}`, so `awsdevops-cli-*`
resources are already in scope. This is verified, not assumed, as a step of the integration task.

## Strategy (the core design decision)

The main path earns its retention from one model — *a pipeline is a chain of custody for one
artifact* — which turns design questions into derivations instead of recalled rules. An appendix
that abandons that structure would be a tutorial stapled to a curriculum. So the appendix runs on
two spines, each a direct descendant of the existing model.

### Day A1's spine: every invocation is four things, in order

Not "the CLI has many commands." Every single `aws` invocation, without exception, is:

| | The question | Where it goes wrong |
|---|---|---|
| **WHO** | Which identity resolved, in which region? | credential provider chain, profile file syntax, env-var precedence, expired SSO token |
| **WHAT** | Which API operation, with which parameters? | service model, `list-` vs `describe-` vs `get-`, required-vs-optional shape |
| **WHAT CAME BACK** | What did the API actually return? | pagination, **server-side** filters, empty result vs thrown error |
| **WHAT DID I SEE** | What did I choose to display? | `--query` (**client-side**), `--output`, the pager |

The payoff is diagnostic, and it is the entire reason for the framing: nearly every CLI frustration
in the field is a *mislocation* of which of the four failed. "The command returned nothing" is two
completely different bugs depending on whether the API returned an empty list or a JMESPath
expression matched nothing in a full one. "Access denied" is two different bugs depending on
whether the wrong identity resolved or the right identity lacks the permission. A learner who
reaches for the four-way split first stops guessing.

The single highest-leverage fact the appendix teaches falls straight out of the table:
**`--filters` is the API; `--query` is your laptop.** `--query` is applied locally, after the
entire response has already crossed the network. It cannot reduce API calls, cannot help with
throttling, cannot reduce transfer — and when combined with `--max-items`, it filters *what was
already truncated*, which produces an answer that is confidently, silently wrong. Most people who
have used the CLI for years have this backwards.

### Day A2's spine: at the keyboard, you are a pipeline stage

The path has already trained one reflex about every stage in a delivery chain: *what does this stage
prove, and is it reversible?* Day A2 turns that reflex on the learner's own hands. A human typing a
mutating command into a terminal is a promotion stage with no code review, no artifact, no
approval gate, and no automatic rollback — which makes the three questions the path already asks of
CodeDeploy strictly *more* urgent here, not less:

- **Predict.** What state transition am I about to cause, and on which exact resource?
- **Observe.** What did the system actually converge to — as distinct from what the API said it
  accepted?
- **Reverse.** Which reversibility bucket is this command in, and did I capture what I need to get
  back?

This is why the appendix belongs to *this* path rather than being a generic CLI unit. The REVERSE
link is already load-bearing in the learner's head after Day 3; A2 spends its authority rather than
building it from scratch.

### Approaches considered and rejected

| Approach | Why rejected |
|---|---|
| **Service-by-service tour** (an ECS day, then an IAM/S3/EC2 day) | The exact trap `STRATEGY.md` names as the largest time sink in the field. Produces someone who recalls commands for four services and derives none. The interface changed; the pedagogy failure did not. |
| **One day plus a large cheatsheet** | Cheaper to author, but the safe-mutation half is a *motor* skill, not a reading one. It degrades into a list of warnings nobody has ever felt the force of. The learner weighted "operate & mutate safely" as a top priority; it needs a lab. |
| **A prerequisite Day 0.5 before Day 1** | Superficially attractive — own the tool before you need it. Fatal in practice: no resources exist yet, so every drill queries an empty account and turns artificial. Interrogation is only teachable against infrastructure worth interrogating. |
| **Drills against the learner's real company account** | Highest transfer, unusable as authored content: the contents are unknown and unpredictable, so every drill would have to be written generically enough to be worthless. The company account instead gets a *doctrine* section on Day A2 (read-only default, permission probing) rather than drills. |

### Why a reference file as well as two days

`CLI-MASTERY.md` exists because the two artifacts have different jobs and neither substitutes for
the other. The day files build the models; the reference file is what gets opened at 2pm on a
Tuesday with a Slack thread waiting. Teaching material optimized for lookup makes bad teaching
material, and reference material optimized for teaching makes an unusable reference. Keeping them
separate lets each be good at one thing — and lets the learner get work value out of the appendix
immediately, before the labs are done.

## Curriculum

Daily shape follows the main path's: **content → lab → break-it/fix-it → teardown**.

| Day | Spine | Content | Lab | Break/fix | Teardown | Total |
|---|---|---|---|---|---|---|
| A1 | INTERROGATE | 70m | 110m | 20m | 5m | ~3.4h |
| A2 | OPERATE | 65m | 115m | 20m | 10m | ~3.5h |

### Day A1 — INTERROGATE: what is actually there?

*Concepts.*

**WHO — identity resolution.** The credential provider chain in documented precedence order, and
`aws configure list` as the tool that shows *where each resolved value came from* rather than just
what it is. `~/.aws/config` versus `~/.aws/credentials`, including the `[profile foo]`-in-config
versus `[foo]`-in-credentials prefix rule (and that `[default]` takes no prefix in either), which is
responsible for a large share of "my profile isn't being picked up." Environment variables beating
profiles, and why that makes a shell that "worked yesterday" a suspect. **The SSO path**, since it
is how the learner reaches the company account: `aws configure sso`, the `sso-session` block and
what it shares across profiles, `aws sso login`, where the token is cached, and what expiry looks
like. **The long-lived-key path**, since it is how the learner reaches their personal account: how
it resolves, and what it costs you — a direct callback to the trap `STRATEGY.md` already names for
CI, now pointed at the learner's own laptop. Region resolution treated as a **separate chain** with
its own precedence, because "no region" and "wrong region" are different bugs and the second is
worse. `aws sts get-caller-identity` as ground truth that cannot be argued with.

**WHAT — the operation.** The CLI is generated from service models, which is why
`aws ecs describe-services help` is authoritative and a three-year-old blog post is not.
`--generate-cli-skeleton` as a shape-discovery tool rather than only an input-file generator. The
`list-` / `describe-` / `get-` naming heuristic — identifiers and summaries, full objects, single
objects — and how to chain them, since the argument for `describe-` almost always comes out of a
`list-`.

**WHAT CAME BACK — the response.** Server-side filtering (`--filters`, `--filter`, and the
service-specific named parameters) versus client-side `--query`, developed properly rather than
mentioned. Auto-pagination in v2, `--no-paginate`, and the distinction between `--page-size` (the
underlying API page size) and `--max-items` (a client-side cap that emits a continuation token).
The truncation trap: `--max-items` plus `--query` filters what was already cut off.

**WHAT DID I SEE — the projection.** JMESPath in real depth: projections, filter expressions
`[?Field=='value']`, multiselect lists `[a,b]` and hashes `{Name:name,Id:id}`, the functions worth
memorizing (`length`, `sort_by`, `join`, `contains`, `starts_with`), pipe expressions, and
flattening with `[]`. `--output json|text|table|yaml`, and precisely when `text` is a trap —
tab-separated with nested structures flattened and empty fields collapsing, which turns a
`cut -f3` into a time bomb. `zsh` quoting rules for bracket expressions. The v2 pager and
`--no-cli-pager`.

**Reading errors as a decision tree.** Four families, each ruling something out: client-side
validation (the request never left the machine — a syntax problem, not a permissions one);
authorization (`AccessDenied`, `UnauthorizedOperation` — the identity resolved fine, so stop
re-checking your profile); credential and expiry (`ExpiredToken` versus `InvalidClientTokenId` —
SSO refresh versus wrong key); and not-found versus empty, where `describe-` *throws* on a missing
resource while `list-` returns `[]` — meaning "no output" is a different diagnosis for each.
`--debug` and the three things worth grepping out of its noise.

*Lab.* Re-apply `labs/foundation/` and `labs/day01/` — stacks the learner wrote and understands —
then work a graded question set answered **by CLI only, console forbidden**. Progressive: single
calls, then projections, then chains where one command's output is another's input. Which digest is
behind that tag. Are those subnets genuinely public (and what makes them so). What exactly can the
CodeBuild role do to ECR, established with `simulate-principal-policy` rather than by reading the
policy hopefully. Reconstruct commit → build → image → digest in one composed command. Every drill
ships a hint and a solution one-liner, per the standing rule.

*Break it.* Deliberate identity failures, diagnosed by error family *before* reading the fix: unset
the region, point at a profile that doesn't exist, use a syntactically wrong profile header, let the
SSO token expire. Then the pagination lesson with teeth — use `--query` where a server-side filter
was required, on a list long enough to be truncated, and get a confident wrong answer.

*Anti-patterns.* Believing `--query` reduces API load. Parsing `--output text` with `cut` in a
script. `grep`-ing JSON instead of querying it. Reaching for the console the moment output looks
unfamiliar. Assuming empty output means the resource is gone.

### Day A2 — OPERATE: changing things you can undo

*Concepts.*

**The pre-flight triad**, before every mutating enter keypress: *who am I* (identity and account,
verified not assumed), *what will this touch* (the resolved target, read back), *what is the current
state* (captured to a file, because a revert you can't perform isn't a plan).

**The tooling of care.** `--dry-run` where it genuinely exists — largely EC2 — and the correction
that matters: on EC2 it is an **authorization probe**, not a simulation, returning
`DryRunOperation` when you would have been allowed and `UnauthorizedOperation` when you would not.
It tells you nothing about whether the change is a good idea. `--generate-cli-skeleton` plus
`--cli-input-json` as the way to make a change reviewable by a human before execution.
`--cli-auto-prompt` for guarded interactive work. `--no-cli-pager` in anything non-interactive.

**Idempotency.** Which operations are naturally safe to repeat and which are not, plus client
request tokens where the API offers them. The trap developed in detail because the learner will hit
it: **`put-` is a full replace, not a patch.** `put-metric-alarm` with a subset of the alarm's
settings does not update those fields — it rewrites the alarm and silently drops everything you
didn't restate. This is the single most common way a "small" CLI change causes an outage nobody
attributes to the CLI.

**The reversibility taxonomy** — the direct descendant of the path's REVERSE link, and the day's
central artifact:

| Bucket | Examples | What it demands of you |
|---|---|---|
| Trivially reversible | tags, `--desired-count`, alarm threshold, service scale | Just do it; capture state anyway out of habit |
| Reversible with effort | task-definition revisions (the old revision still exists), service updates, security-group rules | Know the *specific* revert command before you run the forward one |
| Irreversible | `delete-log-group`, `delete-repository --force`, `batch-delete-image` on the only copy, `terminate-instances` | Stop. Say it out loud. Confirm the account. |

The rule: **know your bucket before pressing enter**, and treat "which bucket is this?" as a
question with a checkable answer rather than a feeling.

**Waiters.** `aws ecs wait services-stable` and friends as the correct primitive, versus the
hand-rolled `while sleep 5; do describe; done` loop everyone writes once. Exit status on timeout,
and why that makes waiters the only sane thing to put in a script.

**"Did it actually happen?"** Never trust a mutation's own response — it reports that the API
accepted the request, not that the system converged, and those are different events separated by
anywhere from milliseconds to minutes. Re-read the resource. Eventual consistency, with IAM as the
canonical example of a service where the write succeeds and the next read disagrees with it.

**Operating in an account you don't own** — the company case, and doctrine rather than drills.
Read-only by default, with a profile named so that a mutating command in the wrong terminal is
obviously wrong. `simulate-principal-policy` to establish what you're able to do before discovering
it by accident. And the distinction that outranks all of the above: what your IAM policy *permits*
is not what your team's change process *allows*, and only one of those two will be checked by the
API.

**The CLI/IaC boundary** — high-transfer, given the learner's team runs Terraform. What a CLI
mutation does to Terraform state, why `terraform plan` is the detector, and a defensible rule for
when reaching past IaC is legitimate (incident response, investigation, genuinely out-of-band
resources) versus when it is the start of a drift problem nobody will find for a quarter.

**Scripting thread** (deliberately light — the learner weighted interrogation and operation above
automation). Composing the day's commands into something reusable in the shape of the repo's
existing `verify-teardown.sh`: `set -euo pipefail`, checking exit codes rather than output text,
and the choice of `--output json` piped to `jq` over `--output text` piped to `cut`.

*Lab.* Predicted → executed → verified → reverted mutations, each cycle run in full, against the
learner's own stacks plus a minimal new one:

1. **Retag an ECR image** — and watch tag immutability reject it. A callback to Day 1's entire
   thesis, now felt from the operator's side rather than the pipeline's.
2. **Scale the ECS service to 0 and back**, using a waiter rather than watching the console.
3. **Change an alarm threshold and revert it** — the `put-` full-replace trap, sprung deliberately
   and then diffed against the captured original.
4. **Register a task-definition revision and roll back to the previous one**, which is the
   CLI-side shape of the rollback Day 3 automated.
5. **The drift hunt.** Mutate a resource via CLI, run `terraform plan`, read the drift, then decide
   and justify the resolution — revert the CLI change, or codify it.

*Break it.* Delete a lab log group and try to get the logs back, so the third bucket of the
reversibility table stops being an abstraction. Then run a multi-step script whose SSO token expires
partway through, and inspect the half-applied state — the failure mode that makes "check exit codes"
a rule rather than a style preference.

*Anti-patterns.* Trusting a mutation's own response as proof of convergence. `put-`ing a partial
object. Hand-rolled polling instead of waiters. Running a mutation in a terminal whose identity you
haven't checked this session. Using the CLI to fix IaC-managed infrastructure and not telling anyone.
Assuming a permission you have in your personal account exists in the company one.

### `CLI-MASTERY.md` — the reference artifact

Path root, explicitly not a teaching file, ordered for lookup speed:

1. **Identity triage** — a flowchart from a symptom to the command that discriminates it.
2. **JMESPath recipe book** — the dozen expressions that cover most real questions, with `zsh`-safe
   quoting.
3. **"Answer this question in one line"** — per service, phrased as the English question rather than
   the command name: EC2, S3, IAM, ECS, ECR, CloudWatch Logs, CloudWatch, plus this path's
   CodeBuild / CodePipeline / CodeDeploy.
4. **The reversibility table**, in a form that can be scanned in five seconds.
5. **The error decoder** — message fragment → family → what it rules out → next command.

### Deliberately out of scope

Named where relevant, not built: `aws-vault` and other credential-hygiene tooling; CloudShell;
`boto3`/SDK equivalence; CLI plugins and aliases; `--endpoint-url` beyond a mention; LocalStack;
Session Manager and SSH-adjacent workflows; cross-account role chaining beyond the single hop the
learner's SSO setup implies; `jq` as a language (used, not taught).

## Directory Layout

Additions and edits only; the rest of the tree is unchanged.

```
aws_devops_sre/
├── README.md                          # EDIT: appendix section, day index rows, prerequisites
├── STRATEGY.md                        # EDIT: one row in the traps table (CLI as memorized incantations)
├── COST.md                            # EDIT: two per-lab rows, dayA2 stack, revised week total
├── CLI-MASTERY.md                     # NEW: lookup reference (triage, JMESPath, one-liners, tables)
├── content/
│   ├── GLOSSARY.md                    # EDIT: JMESPath, credential provider chain, waiter,
│   │                                  #       service model, paginator, SSO session, drift
│   ├── day01.md … day05.md            # unchanged
│   ├── dayA1.md                       # NEW: INTERROGATE
│   └── dayA2.md                       # NEW: OPERATE
├── labs/
│   ├── verify-teardown.sh             # UNCHANGED: existing prefix-scoped ECS and
│   │                                  #   alarm checks already cover awsdevops-cli-*
│   ├── dayA1/                         # NEW: README.md (drill set), SOLUTION.md, teardown.md
│   │                                  #      no Terraform — reuses foundation/ and day01/
│   └── dayA2/                         # NEW: README.md, SOLUTION.md, teardown.md,
│                                      #      main.tf, variables.tf, outputs.tf,
│                                      #      terraform.tfvars.example
└── docs/superpowers/
    ├── specs/2026-09-10-aws-cli-appendix-design.md
    └── plans/2026-09-10-aws-cli-appendix-plan.md
```

**`labs/dayA1/` ships no Terraform on purpose.** Its substrate is `labs/foundation/` and
`labs/day01/`, re-applied. Authoring a parallel stack for it would create a second version of
infrastructure the learner already understands, and interrogating unfamiliar resources is a weaker
exercise than interrogating your own.

**`labs/dayA2/` is the one new stack**, and it is minimal by cost necessity: an ECS cluster, one
Fargate service at desired-count 1 (0.25 vCPU / 0.5 GB, arm64) running the Day 1 image from the
foundation ECR repository in a foundation public subnet, plus one CloudWatch alarm to mutate. **No
ALB and no NAT** — the drills change desired counts, task definitions, tags, and alarm thresholds,
none of which need traffic to be routed anywhere. It reads `vpc_id`, `public_subnet_ids`, and
`ecr_repository_url` from the foundation stack via `terraform_remote_state`, exactly as every other
day lab does.

**`CLI-MASTERY.md` sits at the path root**, alongside `COST.md` and `STRATEGY.md`, rather than under
`content/`. Everything in `content/` is day-ordered teaching material read once in sequence; this
file is read out of order, repeatedly, forever. The location signals which kind of thing it is.

## Content Day Skeleton

Both appendix day files follow the main path's applied/engineering skeleton, with the chain-link
header adapted — the appendix days are not links in the five-link chain, so the header names the
appendix spine instead:

```markdown
# Day A<N> — <SPINE>: <title>

**Appendix:** AWS CLI mastery (depends on Days 1–3)
**Time:** ~3.5h (content ~Xm · lab ~Ym · break/fix ~Zm · teardown ~Wm)
**Cost if you follow teardown:** ~$0.0N

## Why this matters
<1 short paragraph, concrete and specific>

## The question of the day
**<the one question this day makes answerable>**

## Core concepts
<numbered sections>

## Decision rules
| When you see... | Choose... | Because |

## Lab
See `labs/dayA<N>/`. The goal: <one line>. Success signal: <one line>.

## Break it / Fix it
<the failure to induce on purpose, and what it teaches>

## Exercises
1. <task> — **Hint:** <hint> — **Solution sketch:** <sketch>

## Anti-patterns / Common mistakes
<bullets>

## Teardown
<checklist leaving zero billable resources>

## Self-check
<exactly three scenario questions, no answers, then a pointer paragraph>
```

**This is the path's actual house structure, not the authoring skill's generic
template.** `content/day01.md`, `day03.md`, and `day05.md` all carry ten sections
in exactly this order. An earlier draft of this spec listed only seven, omitting
`## Decision rules`, `## Break it / Fix it`, and `## Self-check` — a learner moving
from `day05.md` into the appendix would have noticed three familiar sections
missing. The appendix days match the path they extend.

Every exercise ships a hint and a solution sketch; every lab ships `README.md`, `SOLUTION.md`, and a
teardown checklist. Both are standing rules of the authoring skill and neither is relaxed here.

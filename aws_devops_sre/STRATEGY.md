# The Top 1% Strategy for AWS DevOps / SRE

## The core mental model: a pipeline is a chain of custody

A pipeline is not a sequence of stages that run scripts. It is a **chain of
custody for one artifact** — the same discipline a courtroom applies to
physical evidence, applied to a container image. Five links:

| Link | Question it answers | AWS service that owns it |
|---|---|---|
| **PRODUCE** | What exactly is the thing we ship, and is it identical every time? | CodeBuild → ECR |
| **PROVE** | What do we know about it, and who attested to that? | CodeBuild reports, ECR scanning |
| **PROMOTE** | How does it cross an environment boundary without changing? | CodePipeline / GitHub Actions |
| **REVERSE** | How do we undo a promotion, and how fast? | CodeDeploy, alarms, circuit breaker |
| **MEASURE** | How do we know the chain is healthy? | CloudWatch, SLOs, DORA metrics |

Once you hold this model, design questions stop being a matter of taste and
become **derivable**. Take "should we rebuild the image per environment, so
config gets baked in at build time?" — a question that sounds reasonable and
gets asked in almost every platform team. Run it through the chain: a
rebuild produces a *new* artifact, so the thing running in staging and the
thing running in prod are no longer the same object — custody is severed at
PRODUCE, which means every test result staging produced is now evidence
about an artifact that isn't the one in prod. The answer — "no, bake
environment config in at deploy time, not build time" — falls out in one
breath instead of being a rule you memorized from a style guide.

## Why PROVE has no day of its own

PROVE — what do we know about the artifact, and who attested to it — never
gets its own day because it isn't a phase, it's an activity that attaches to
the phases around it. Day 1 covers PROVE through build reports and ECR
scanning; Day 2 covers it through what each pipeline stage attests to before
letting an artifact pass. Giving it a standalone day would imply proving
things is something you do *between* producing and promoting, when in fact
it's something you do *while* producing and promoting.

## The daily loop

Every day, in order:

1. **Name the link** — which of the five (PRODUCE / PROVE / PROMOTE /
   REVERSE / MEASURE) is today's subject.
2. **State what this stage proves** — what fact about the artifact does this
   link establish, and what would be false without it?
3. **Map it to AWS** — which service implements the link, and what it trades
   off against the alternatives.
4. **Wire it** — build the minimal real Terraform for it.
5. **Break it** — remove a component or inject a failure on purpose.
6. **Measure the blast radius** — how long would this failure go unnoticed,
   and how far would it spread, if nobody was watching?

## What the 80% waste time on

| Trap | Why it fails |
|---|---|
| Service-first learning — CodeBuild docs, then CodePipeline docs, then CodeDeploy docs | Produces someone who can configure three services and design zero promotion strategies. This is the single largest time sink in the field. |
| Following CodeCommit tutorials | Closed to new accounts since July 2024. Hours lost before the first build ever runs. |
| Mutable `:latest` tags | Destroys custody. "What is in prod?" becomes unanswerable, and rollback becomes a guess. |
| Rebuilding the image per environment | The artifact you tested is not the artifact you shipped. All staging evidence is void. |
| Long-lived IAM access keys in CI | The credential outlives the engineer who created it. OIDC federation solves this and takes 20 minutes to learn. |
| Happy-path-only labs | Deployment skill *is* failure skill. Someone who has never watched a rollback fire cannot design one. |
| Treating rollback as an afterthought | Reversibility is a build-time property, not an incident-time one. If the artifact is not immutable and addressable, there is nothing to roll back *to*. |
| Learning EKS before learning delivery | Kubernetes is a substrate, not a delivery model. Learners who start there acquire `kubectl` muscle memory and no promotion strategy. |
| Ignoring cost until the bill arrives | NAT gateways and idle ALBs teach an expensive lesson that a $10 budget alarm teaches for free. |

## What the top 1% do differently

- They design the **artifact** first and the pipeline second.
- They can state, for any stage, **what it proves** — and delete stages that
  prove nothing.
- They rehearse rollback deliberately, because the first rollback should
  never be during an incident.
- They treat the **trust boundary of CI** as production infrastructure, not
  developer tooling.
- They measure the pipeline itself (lead time, change fail rate), not just
  the service.
- They can name one scenario where each pattern is the *wrong* choice.

## The one question that separates levels

Juniors answer "how do I configure X?" Seniors answer "what does this stage
prove, and what happens when it's unavailable?" Every day in this path is
built to move you from the first question to the second — for every stage
you touch, you should be able to say what fact it establishes about the
artifact, and what breaks if that stage is skipped or fails silently.

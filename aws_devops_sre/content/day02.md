# Day 2 — PROMOTE: the pipeline is a promotion machine

**Chain link:** PROMOTE
**Time:** ~3.4h (content ~60m · lab ~120m · break/fix ~20m · teardown ~5m)
**Cost if you follow teardown:** ~$0.30

## Why this matters

Day 1 gave you an artifact: an image, addressed by digest, that you can point
at and say "this exact thing, no other." An artifact nobody moves is just a
fact sitting in a registry. PROMOTE is the link that moves it — across a
staging/prod boundary, past a human who has to sign off, from "we built this"
to "this is now serving traffic." Every promotion mechanism makes a claim
about what it preserves and what it lets change. Get that claim wrong and you
get a pipeline that looks green while quietly shipping something nobody
tested: a deploy stage that resolves a mutable tag instead of the digest your
build recorded, a CI job holding a long-lived AWS access key that outlived
the engineer who created it, an "approval" gate that approves a stage name
instead of an artifact. None of those failures show up in the pipeline's own
success/failure status. You only find them when something's already wrong in
production.

This is also where your day job and this lab meet directly: your team
deploys WSO2 components to ECS Fargate, and whatever promotes those
components — CodePipeline, GitHub Actions, or some hybrid — is making exactly
the same custody claims this lab makes. If you can't state what a stage
proves, you can't tell a real promotion machine from a rebuild-and-hope
script with extra buttons.

## The question of the day

**How does an artifact cross an environment boundary without changing?**

By the end of today you should be able to answer that cold — not "we use a
pipeline," but the actual mechanism: what identifies the artifact, what
carries that identity between stages, and what would have to go wrong for
the thing that reaches prod to be different from the thing a human approved
in staging.

## Core concepts

### 1. A stage is a claim, not a script

It's tempting to think of a pipeline stage as "a place where a script runs."
That framing hides the thing that actually matters: **every stage makes a
claim about the artifact**, and the pipeline's job is to make sure that claim
is true before the artifact moves on. A `Build` stage claims "this source
produced this exact image." A `DeployStaging` stage claims "this image runs
correctly in an environment that looks like prod." A manual `Approval` stage
claims "a human looked at the evidence and accepted the risk." A stage that
runs a script but proves nothing — a `NoOp` stage, a stage that always
passes regardless of what happened inside it, a deploy stage with no health
check — is not cheap insurance, it's a false claim wearing a green checkmark.
For every stage in a pipeline you design, ask **"what does this prove?"**
If you can't answer in one sentence, delete the stage; it is adding latency
and false confidence, not safety.

### 2. CodePipeline V2 anatomy

A CodePipeline pipeline is a directed sequence of **stages**, each holding
one or more **actions**. Actions within a stage can run in parallel or in
sequence, controlled by `runOrder` — actions sharing a `runOrder` value run
in parallel; a higher `runOrder` waits for every lower one to finish. Every
action reads **input artifacts** and writes **output artifacts**, and those
artifacts physically live in one **S3 bucket**, the pipeline's artifact
store. This detail explains a lot of otherwise-confusing pipeline behavior:
what moves between a `Build` stage and a `Deploy` stage is **a zip file in
S3**, not a Docker image. The image itself never enters the pipeline's
artifact store — it lives in ECR, addressed by digest, and what CodePipeline
passes downstream is a small JSON manifest (`imageDetail.json`) pointing at
that digest. If you've ever wondered why a CodePipeline "artifact" browses
like a handful of tiny files instead of a multi-hundred-megabyte image, this
is why.

### 3. Source via CodeConnections

CodePipeline's `Source` stage for a GitHub repo uses the
`CodeStarSourceConnection` action provider, backed by a **CodeConnections**
connection you create once (Day 0, console-only OAuth handshake) and
reference by ARN. The action's configuration names a `FullRepositoryId`
(`owner/repo`), a `BranchName`, and `DetectChanges = true`. On top of that,
CodePipeline **V2** adds a `trigger` block that filters *which* pushes to
that branch actually start an execution — by branch name and by file path
glob (so a push that only touches `docs/` doesn't trigger a rebuild of an
app nobody changed).

**Why GitHub and not CodeCommit:** AWS closed CodeCommit to new customers in
**July 2024**. If you're starting an AWS account today, you cannot create a
CodeCommit repository — the service still runs for existing customers, but
there is no path in for anyone new. Every tutorial that opens with
`git push codecommit` predates that change and is not usable advice for this
learner, or for anyone reading this after 2024. That's the entire reason
this path's source of truth is GitHub via CodeConnections rather than
AWS-native source control.

### 4. V1 vs V2 pricing

CodePipeline has two pricing models tied to `pipeline_type`:

- **V1**: a flat **~$1/month per active pipeline**, regardless of how often
  it runs.
- **V2**: **~$0.002 per action-minute**, with **100 free action-minutes per
  month**, and no flat fee.

You can derive the crossover yourself: V2 costs more than V1's flat $1 once
the free tier is exhausted and you're paying for `(x - 100)` action-minutes
at $0.002 each. Setting that equal to $1: `(x - 100) × 0.002 = 1` → `x = 600`
action-minutes/month. **Below ~600 action-minutes/month, V2 is cheaper than
V1's flat fee; above it, V1 wins on cost alone.** For a lab pipeline you run
a handful of times in an afternoon, you're nowhere near that line — but for
a team's real production pipeline running dozens of times a day, that
crossover is a number worth actually computing rather than assuming. One
more fact that settles the choice regardless of cost: **the branch and
file-path trigger filters used in this lab exist only in V2.** If you need
them, V1 isn't on the table.

### 5. Promotion without rebuilding

This is the central mechanic of the whole day. Day 1's `Build` stage doesn't
just build an image — it emits `imageDetail.json`, a small JSON file
containing the image's **digest** (`ImageURI`, a `repo@sha256:...` string).
Every downstream stage — `DeployStaging`, the approval gate, `DeployProd` —
consumes *that exact file*. Nothing downstream of `Build` ever rebuilds the
image or re-resolves what "the latest version" means. The same bytes, the
same digest, travel from source to prod-approval unchanged. That's what
"promotion" means as distinct from "deployment": a deployment puts *some*
version of the app somewhere; a promotion carries *the specific, previously
built and tested* version somewhere new.

Say this part out loud, because it's the exercise-4-worthy trap: **if your
deploy stage names a mutable tag (`:latest`, `:staging`) rather than
consuming the digest recorded at build time, you no longer have a promotion
machine.** You have a machine that redeploys whatever happens to match that
tag *at the moment it runs* — which might be a completely different image
than the one that passed your staging tests an hour ago, if anyone pushed a
new `:latest` in between. A pipeline that "redeploys yesterday's execution"
and ships different code than it shipped yesterday is not a bug in
CodePipeline. It's this exact anti-pattern, and it's entirely a choice made
in how the deploy action is configured.

### 6. One buildspec, two CodeBuild projects — what "build once" actually binds

Here's a wrinkle worth understanding precisely, because it looks at first
like it contradicts everything Core concept 5 just said: this lab's `Build`
action does **not** point at Day 1's CodeBuild project. It declares a
**second** `aws_codebuild_project` resource. That is not the pipeline
rebuilding the app a second time — it's a real CodeBuild constraint you need
in your mental model regardless of which tool you're driving it with.

A CodeBuild project's `source { type = ... }` and `artifacts { type = ... }`
blocks commit it to exactly one **invocation mode**, and the two modes this
path needs are mutually exclusive on a single project:

- **`source { type = "GITHUB" }` / `artifacts { type = "NO_ARTIFACTS" }`**
  (Day 1's project) — started by `aws codebuild start-build`, so the project
  clones from GitHub itself and there's no pipeline stage waiting to collect
  an output artifact.
- **`source { type = "CODEPIPELINE" }` / `artifacts { type = "CODEPIPELINE" }`**
  (this lab's project) — started by a CodePipeline `Build` action, so the
  project's "source" is the zip CodePipeline's `Source` stage already
  produced, and its output is a zip the next stage picks up. It cannot also
  clone from GitHub — that would silently re-resolve the source a second
  time, independent of the exact commit CodePipeline already checked out,
  which is precisely the custody break this whole day exists to prevent.

Both `source.type` and `artifacts.type` are set once, at creation, and the
CodeBuild API doesn't offer a project that runs as either depending on who
calls it. So the honest options are: give Day 1's `GITHUB`/`NO_ARTIFACTS`
project a pipeline-shaped twin, or give up `aws codebuild start-build` as a
way to run a build standalone. This path keeps both working, on purpose —
Day 1's project stays exactly as it is, and this lab declares its own.

What actually gets reused, then, was never the `aws_codebuild_project`
resource — it's the **buildspec**. `labs/day02/main.tf` points this lab's
project at `buildspec = file("${path.module}/../day01/buildspec.yml")`, the
identical file Day 1 uses, completely unedited. Same `install` /
`pre_build` / `build` / `post_build` commands, same commit-derived
`IMAGE_TAG`, same `imageDetail.json` shape written at the end. The only
things that differ between the two projects are *what triggers a build* (a
CLI call vs. a pipeline action) and *where source and output live* (GitHub
directly vs. CodePipeline's S3 artifact store) — not what the build
actually does. "Build once" was never a claim about how many CodeBuild
project resources exist in an AWS account; it's a claim about how many
times one commit's source gets compiled and pushed to ECR. Two projects,
one buildspec, one build — that's what keeps the claim true.

### 7. Manual approval gates

A `Manual` approval action pauses the pipeline until a human approves or
rejects. What makes an approval **meaningful** rather than theater is
whether it names something specific: the action's `CustomData` field should
say *what* is being approved (which digest, which build, a link to the
evidence — test results, scan output, the staging URL) so the approver is
making an informed decision about a specific artifact, not rubber-stamping
"stage 4 of 5." An approval gate whose `CustomData` just says "Approve
deployment" approves nothing in particular — it's a speed bump, not a
control. You'll build one of each shape in the lab and feel the difference.

### 8. Where configuration lives

Every promoted artifact eventually needs environment-specific configuration
— a database endpoint, a feature flag, a log level — and where that
configuration lives is a real design decision with real consequences: baked
into the image (breaks the "one artifact, many environments" model
outright), in the task definition's environment block, in Parameter Store,
or in Secrets Manager for anything sensitive. Today you only need to know
this axis exists and that CodePipeline's job is emphatically *not* to carry
configuration — it carries an artifact reference. **Day 3 covers this in
full**, once you have a real ECS task definition to hang the answer on.

### 9. GitHub Actions + OIDC

CodePipeline isn't the only promotion mechanism in this ecosystem — GitHub
Actions, calling AWS directly, is the other one you'll meet constantly in
the wild. The trust chain, end to end:

1. A GitHub Actions job requests a short-lived **OIDC token** from GitHub's
   own token issuer (`token.actions.githubusercontent.com`).
2. The job presents that token to AWS **STS**, calling
   `AssumeRoleWithWebIdentity`.
3. STS validates the token's signature against the **IAM OIDC identity
   provider** you registered for that issuer, checks the role's trust
   policy conditions against the token's claims, and — if everything
   matches — returns **temporary credentials** (default 1 hour, capped by
   the role's max session duration).

The entire point: **no long-lived keys anywhere.** No `AWS_ACCESS_KEY_ID`
sitting in a GitHub secret that a departing contractor's laptop might still
have cached, no key rotation cron job, no key to leak in a `docker build`
layer by accident. The credential is minted fresh, per job run, and expires
on its own.

Everything about whether this is safe comes down to one claim in the token:
**`sub`** (subject). For a GitHub Actions token, `sub` takes the form
`repo:OWNER/REPO:ref:refs/heads/BRANCH` for a branch-triggered workflow (it
has other forms for pull requests, tags, and environments — the branch form
is what this lab uses). Compare three trust-policy conditions on that claim:

| `sub` condition | What it grants |
|---|---|
| `repo:OWNER/REPO:ref:refs/heads/main` | Exactly one repo, exactly one branch. Correct. |
| `repo:OWNER/REPO:*` | Every branch, every pull request, every tag in that repo — including a branch created by someone who just opened a PR. |
| `*` (or the condition omitted) | Every GitHub Actions workflow on Earth that can obtain a token for *any* audience matching your `aud` condition. Catastrophic. |

The corresponding trust-policy condition block, using the operator that
matters:

```json
"Condition": {
  "StringEquals": {
    "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
    "token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:ref:refs/heads/main"
  }
}
```

`StringEquals` requires an exact match. **`StringLike` combined with a `*`
wildcard is where people get burned** — it turns "this exact branch" into
"any branch matching this pattern," and because `sub` encodes *both* the
repo and the ref in one string, a careless wildcard doesn't just widen the
branch, it can widen it far enough to match pull-request refs from forks
too. Pin the ref. Use `StringEquals`, never `StringLike`, on this
condition, and treat any PR that changes it as a security review, not a
routine merge.

### 10. Choosing between them

Not a preference — a decision rule:

- Choose **CodePipeline** when you need manual approval gates as a first-
  class pipeline primitive, cross-account promotion (assuming a role in a
  different AWS account per stage), or AWS-native artifact custody (S3 +
  IAM, no third-party runner ever touches your build output).
- Choose **GitHub Actions** when build ergonomics matter — matrix builds
  across OS/arch, a huge marketplace of pre-built actions, and PR feedback
  wired directly into the GitHub UI (status checks, inline annotations)
  that CodePipeline has no native equivalent for.
- **The common real answer in production systems is both, split by
  concern:** GitHub Actions builds and pushes the artifact (it's simply
  better at build ergonomics and PR feedback), then CodePipeline or
  CodeDeploy owns the promotion — approvals, environment sequencing,
  rollback. You'll see this exact split argued for in the decision rules
  below and it's what the lab's OIDC role is scoped for: pushing an image
  to ECR, nothing else.

## Decision rules

| When you see... | Choose... | Because... |
|---|---|---|
| A promotion needs a human sign-off before prod, tied to a specific artifact | CodePipeline manual approval action | Native primitive with `CustomData`; no separate approval tool to bolt on |
| Promotion must assume a role in a *different* AWS account per stage | CodePipeline | Cross-account roles are a first-class action configuration; GitHub Actions can do it but you're wiring the account-hopping yourself |
| You need matrix builds (multiple OS/arch/language-version combinations) | GitHub Actions | Native `strategy.matrix`; CodePipeline has no equivalent concept |
| You want PR status checks and inline feedback in the GitHub UI | GitHub Actions | Runs natively against the PR event; CodePipeline requires extra plumbing (webhooks back to GitHub) to surface anything there |
| Trigger must fire only on specific branches *and* specific file paths | CodePipeline **V2** | V1 has no `trigger` block; this is a V2-only feature |
| Pipeline execution frequency is low (a lab, a low-traffic service) | CodePipeline V2 | Pay-per-action-minute with 100 free/month beats V1's flat $1/month below ~600 action-min/month (see pricing crossover above) |
| Pipeline execution frequency is high (many builds/day, established product) | CodePipeline V1 | Flat $1/pipeline-month wins once you're consistently over the ~600 action-min/month crossover |
| CI needs to call AWS with the least possible standing risk | GitHub Actions + OIDC | No stored credential exists between runs — nothing to leak from a compromised secret store |
| You need one artifact built once, then promoted unchanged through several environments | Either, but only if the deploy stage consumes a **digest**, never a mutable tag | The mechanism (CodePipeline vs Actions) matters less than this one property; get it wrong in either tool and you don't have a promotion machine |

## Lab

See `labs/day02/`. The lab provisions a CodePipeline V2 pipeline —
`Source → Build → DeployStaging → Approval → DeployProd` — with its own
CodePipeline-shaped CodeBuild project driving the `Build` stage, built from
Day 1's `buildspec.yml` reused verbatim (see Core concept 6 for why this is
a second *project* but not a second *build*: Day 1's project stays
`GITHUB`/`NO_ARTIFACTS` so `aws codebuild start-build` keeps working
standalone), plus an IAM OIDC provider and role scoped for GitHub Actions to
push to ECR with no long-lived keys.

**Goal:** stand up a pipeline where one image digest travels from source to
a prod-approval gate without ever being rebuilt, and a GitHub Actions
workflow that can push to ECR using nothing but a short-lived OIDC token.

**Success signal:** one digest travels from source to prod-approval without
a rebuild — you can point at the `imageDetail.json` output of the `Build`
stage and the input consumed by `DeployProd` and show they're the same
digest, and `aws codepipeline get-pipeline-state` shows the pipeline
progressed stage by stage to the approval gate without a second `Build`
action ever running.

## Break it / Fix it

Swap the OIDC role's trust policy for the commented-out wildcard version in
`oidc.tf` (`StringLike` + `repo:OWNER/REPO:*`), `terraform apply`, and then
**reason about — do not perform** — what a pull request opened from a fork
of that repo could now reach with the temporary credentials that trust
policy would hand it. Restore the correct `StringEquals` condition,
`terraform apply` again to close the hole, and write one sentence stating
exactly what the wildcard granted. Full walkthrough and the enumerated blast
radius are in `labs/day02/README.md` and `SOLUTION.md`.

## Exercises

1. Write the OIDC trust policy condition that allows exactly one repo's
   `main` branch — nothing wider.

   **Hint:** Two claims need to be pinned, not one, and the operator that
   pins them matters as much as the values.

   **Solution sketch:** `StringEquals` (never `StringLike`) with
   `"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"` and
   `"token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:ref:refs/heads/main"`.
   Both conditions must hold simultaneously — `aud` proves the token was
   minted for AWS STS specifically, `sub` proves it came from that exact
   repo and branch.

2. Given `"sub": "repo:OWNER/REPO:*"` matched with `StringLike`, name three
   things an attacker who can merely open a pull request against that repo
   could now do.

   **Hint:** `sub` doesn't only encode branches — think about what other
   ref shapes GitHub issues tokens for, and who is allowed to trigger those
   workflows.

   **Solution sketch:** (1) Any workflow triggered by a `pull_request`
   event from *any* branch — including one pushed by an outside
   contributor's fork, if the repo's Actions settings permit it — now
   matches the wildcard and can assume the role. (2) Any contributor who
   can create a branch in the repo (not just fork it) can push a workflow
   file on that branch that assumes the role and does anything the role's
   permissions policy allows, with no review required before the token is
   issued. (3) The attacker can exfiltrate or misuse whatever the role's
   permissions policy grants — in this lab, push arbitrary images to the
   foundation ECR repo, meaning the next deploy from that repo could pull a
   malicious image. The fix: pin the ref (`ref:refs/heads/main` exactly,
   `StringEquals`), and for anything touching prod, additionally require
   the `environment:` claim (GitHub Environments with required reviewers),
   which cannot be satisfied by a plain PR run at all.

3. A pipeline redeploys yesterday's execution and ships different code than
   it shipped yesterday. Explain how that's possible.

   **Hint:** Nothing about redeploying "yesterday's execution" forces the
   deploy stage to resolve the artifact the same way twice — look at what
   identifier the deploy action is actually configured to use.

   **Solution sketch:** The deploy stage names a mutable tag (`:latest`,
   `:staging`) rather than consuming the digest recorded in `Build`'s
   `imageDetail.json`. Re-running the same pipeline execution re-triggers
   the deploy action, which re-resolves that tag *at deploy time* — and if
   anyone pushed a new image under that tag since yesterday, the tag now
   points at different bytes. The pipeline's own logs show "execution
   re-run, succeeded" with no indication anything changed, because nothing
   about the pipeline's bookkeeping tracks the tag's target over time —
   only a digest reference would have prevented this.

4. Compute CodePipeline V2's cost for 3 executions/day, 4 actions each,
   ~2 action-minutes per action.

   **Hint:** Work out action-minutes per day first, then per month, then
   apply the free tier before the per-minute rate.

   **Solution sketch:** `3 executions/day × 4 actions × 2 action-min = 24
   action-min/day` → `24 × ~30 days ≈ 720 action-min/month`. Subtract the
   100 free action-minutes: `720 - 100 = 620` billable action-minutes.
   `620 × $0.002 ≈ $1.24/month`. Compare against V1's flat `~$1/pipeline-
   month`: at this execution rate V2 costs slightly *more* than V1's flat
   fee — the answer flips depending entirely on execution frequency, which
   is exactly why decision rule 6/7 above says "compute it," not "assume
   V2 is always cheaper."

## Anti-patterns / Common mistakes

- **Rebuilding per environment.** If `DeployStaging` and `DeployProd`
  trigger separate builds instead of consuming the same digest, the
  artifact you tested in staging is not the artifact you shipped to prod —
  every bit of staging evidence you collected is void.
- **Config baked into images.** An image that has to be rebuilt to change
  a database endpoint or a feature flag can no longer be promoted unchanged
  between environments — you've forced a rebuild-per-environment even if
  your pipeline stages are wired correctly.
- **Static access keys in CI.** A long-lived `AWS_ACCESS_KEY_ID`/
  `AWS_SECRET_ACCESS_KEY` pair in a GitHub secret is a credential with no
  expiry, held by a third-party runner, that nobody remembers to rotate
  until it leaks. OIDC federation replaces it with a credential that
  expires on its own and costs about twenty minutes to set up correctly.
- **Approval gates that approve nothing specific.** A `Manual` approval
  action with `CustomData` reading "Approve deployment" gives the approver
  nothing to evaluate — they're clicking a button on a timer, not reviewing
  evidence about a specific artifact. Name the digest and link the evidence
  or the gate is theater.

## Teardown

Full steps, commands, and the two things `terraform destroy` reliably
leaves behind (S3 objects in the artifact bucket, and the OIDC provider if
another role still references it) are in `labs/day02/teardown.md`. Short
version:

```bash
cd labs/day02
terraform destroy
# if destroy fails on a non-empty bucket, see teardown.md for the
# `aws s3 rm --recursive` command, then destroy again
bash ../verify-teardown.sh
```

Leave `labs/foundation/` running — it isn't torn down until after Day 5.

## Self-check

1. Without looking anything up: what physically moves through
   CodePipeline's S3 artifact store between the `Build` and `DeployStaging`
   stages, and what does *not* move through it?
2. You're handed an IAM trust policy for a GitHub Actions role. What two
   things do you check first, and what operator must the `sub` condition
   use for the check to mean anything?
3. A teammate says "we redeploy the pipeline and it always ships the same
   code it shipped last time — CodePipeline guarantees that." Is that true
   in general, or only true under a specific configuration choice? Name the
   choice.

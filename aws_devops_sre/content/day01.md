# Day 1 — Produce: what exactly is the artifact?

**Chain link:** PRODUCE
**Time:** ~3.3h (content ~55m · lab ~115m · break/fix ~20m · teardown ~5m)
**Cost if you follow teardown:** ~$0.20

## Why this matters

Every deployment story eventually collapses into one question: what,
precisely, is running in production right now? Not "the `main` branch" —
`main` is a moving pointer, not a thing you can run. Not "whatever the last
successful build was" — successful according to what check, built from what
source, verified how? The only honest answer is: a specific set of bytes,
produced once, that you can name and never mistake for a different set of
bytes.

This day is about making that answer trustworthy for the sample Go service
in `app/`. By the end, `terraform apply` in `labs/day01/` gives you a
CodeBuild project that turns one Git commit into one container image, pushes
it to the foundation stack's ECR repository under a tag immutability makes
impossible to overwrite, and hands you both the tag and the underlying
digest. Every later day in this path — the pipeline in Day 2, the blue/green
deploy in Day 3, the Kubernetes substrate in Day 4, the DORA metrics in Day
5 — depends on that image existing and being unambiguous. If Day 1 is sloppy
about identity, every day after it is building on a guess.

## The question of the day

**What exactly is the thing we ship, and is it byte-identical every time?**

## Core concepts

### 1. The artifact is the unit of custody

"We deploy the `main` branch" is a category error, not shorthand. A branch
is a pointer to a commit, and the pointer moves every time someone pushes.
Saying "we deploy `main`" describes a *process* (grab whatever `main` points
to right now, build it, ship it) — it does not describe a *thing*. A chain
of custody needs a thing: one specific set of bytes you can name, hash, scan,
sign, and hand from one stage to the next without it changing shape.

That thing is the **artifact** — here, a container image identified by its
digest. Every stage from this point forward (build, promote, deploy,
measure) either preserves that artifact's identity unchanged or it has
broken the chain. The rest of this day is building the first link: making
one artifact, once, identifiably.

### 2. buildspec anatomy

A CodeBuild `buildspec.yml` declares four phases, in order:
`install → pre_build → build → post_build`, plus an optional `finally` block
attached to any phase.

**What each phase is conventionally for:**

| Phase | Conventional use |
|---|---|
| `install` | Install runtime versions and system-level tools |
| `pre_build` | Authenticate to registries, resolve values needed later (like a commit-derived tag) |
| `build` | Run the actual build/compile/`docker build` |
| `post_build` | Push artifacts, run notifications, capture output metadata |

**What actually differs, mechanically:** only `install` supports the
`runtime-versions` block (a CodeBuild-managed way to select a language
runtime version from the build image's preinstalled set). Every other phase
is just a list of shell commands — CodeBuild does not enforce that
`pre_build` only authenticates or that `build` only compiles. Those are
conventions, useful for readability, not rules the tool checks.

What *is* enforced: a non-zero exit code from any command, in any phase,
fails the build — with two exceptions worth memorizing because they're both
places people get surprised:

- **`finally` commands run regardless of whether the phase's main commands
  succeeded.** They're meant for cleanup that should happen either way.
  Whether a non-zero exit from a `finally` command fails the phase is not
  something this guide asserts one way or the other — check CodeBuild's own
  docs if that distinction matters to you. Treat anything load-bearing you
  put in `finally` as worth an explicit check of its own exit status rather
  than relying on an assumption about how failures there are handled.
- **A `docker push` whose output is not checked can also let a build "pass"
  while nothing shipped.** This isn't a CodeBuild special case — it's the
  general shell rule (a command's own exit code is what matters) applied to
  the one command in this buildspec where getting it wrong is expensive:
  if `docker push` is piped through something that swallows its exit code,
  or its result is never referenced, a build can go green while the image
  never reached ECR. `buildspec.yml` in this lab pushes as a bare command
  specifically so its exit code is what CodeBuild checks directly.

### 3. Compute selection

CodeBuild offers three relevant compute choices for this build:

- **`ARM_CONTAINER` / `BUILD_GENERAL1_SMALL`** — ~$0.0034/build-minute.
- **x86 `LINUX_CONTAINER` / `BUILD_GENERAL1_SMALL`** — ~$0.005/build-minute.
- **Lambda compute** (`LINUX_LAMBDA_CONTAINER`) — cheaper still per minute,
  faster cold start, but with two hard constraints that decide when it does
  *not* apply: a **15-minute maximum build time**, and **no privileged
  mode**, which means **no Docker daemon, which means no `docker build`.**

Given those constraints, you can derive the choice without memorizing a
rule: any build that runs `docker build` needs privileged mode, which rules
out Lambda compute immediately, regardless of price. Between the two
container options, this app cross-compiles cleanly to arm64 (see
`app/Dockerfile` — `GOARCH=arm64`, `FROM scratch` final stage), so
`ARM_CONTAINER` wins on price with no downside. Lambda compute becomes the
right answer only for builds that never invoke Docker — a pure `go build`
and unit-test run, for instance.

### 4. Caching

CodeBuild offers two cache families:

- **Local caching** (`LOCAL_SOURCE_CACHE`, `LOCAL_DOCKER_LAYER_CACHE`,
  `LOCAL_CUSTOM_CACHE`) — free, and fast when it hits, because the cache
  lives on the build host's own disk. The honest tradeoff: it only hits
  when CodeBuild happens to reuse the same host for your next build, which
  it does not guarantee. Local caching is **best-effort**, not reliable.
- **S3 caching** — every build downloads the cache from S3 at the start and
  uploads it again at the end, which costs a download every single build
  (time, and a small amount of data transfer) whether or not the cache
  contents actually changed. What it buys in exchange is a guarantee: the
  cache is there every time, independent of which host runs the build.

**The rule:** use local caching for layer caching (Docker layers, source
checkouts) where a miss just means "this build was a little slower," and use
S3 caching only for dependency caches that must hit reliably (a large
dependency tree that would meaningfully slow every build if refetched from
scratch every time, and where "best effort" isn't good enough). This lab
uses `LOCAL_DOCKER_LAYER_CACHE` and `LOCAL_SOURCE_CACHE` — a Go build with
`app/`'s tiny dependency footprint (stdlib only) has nothing that needs the
reliability guarantee S3 caching would buy.

### 5. Privileged mode and Docker-in-CodeBuild

`docker build` needs a Docker daemon to talk to, and CodeBuild's build
containers don't run one by default. Setting `privileged_mode = true` on the
CodeBuild project is what starts a Docker daemon inside the build container,
granting it the elevated container privileges Docker-in-Docker requires.

This is required for any build that runs `docker build`, `docker push`, or
anything else that talks to a Docker daemon — and it is exactly the
capability Lambda compute cannot offer (see Core concept 3), which is why
"does this build need Docker" is the first fork in the compute-selection
decision tree.

### 6. Artifacts vs reports

These are two different `buildspec.yml` top-level sections with two
different jobs, and beginners routinely conflate them:

- **`artifacts:`** — files the build hands to whatever consumes its output
  next: a CodePipeline stage, an S3 location, or (in this lab's case,
  standalone) just the build's own record. This buildspec's `artifacts:`
  section lists `imageDetail.json`, the file that carries the pushed
  image's digest forward.
- **`reports:`** — structured test results (JUnit XML, Cucumber JSON, and a
  handful of other formats) that CodeBuild parses and renders in its own
  Reports UI — pass/fail counts, per-test detail, trends across builds. This
  lab has no `reports:` section because `app/` currently ships no automated
  tests; if it did, that's where their results would go, not into
  `artifacts:`.

The distinction that matters: `artifacts:` is *opaque* to CodeBuild (it just
moves files), `reports:` is *parsed* by CodeBuild (it understands the file
format well enough to build a UI from it).

### 7. Two roles, not one

Three distinct trust boundaries get flattened into "IAM for the pipeline" if
you're not careful. Keep them apart:

1. **The CodeBuild service role** (this lab, `aws_iam_role.codebuild` in
   `main.tf`) — what the *build itself* is allowed to do while it runs:
   write its own CloudWatch Logs, authenticate to ECR, push to one specific
   repository.
2. **The pipeline role** (Day 2) — what *CodePipeline* is allowed to do to
   orchestrate builds and deploys on your behalf: start this CodeBuild
   project, read/write the pipeline's S3 artifact bucket, use a
   CodeConnections connection. A completely different principal, a
   completely different job.
3. **The ECR resource policy** (not used in this path, but worth naming) —
   a policy attached to the *repository itself* that grants other AWS
   accounts or principals pull/push access, independent of any IAM role.
   This is how cross-account image sharing works; it's not needed here
   because everything in this path stays in one account.

The least-privilege shape for role #1, this lab's build role, is two kinds
of ECR permission with two different scoping rules:

- **`ecr:GetAuthorizationToken`, scoped to `"*"`.** This has to be
  account-wide — the API call authenticates you to the ECR registry as a
  whole, not to any one repository, so there is no repository ARN to scope
  it to. IAM's policy grammar simply doesn't offer a narrower option for
  this specific action.
- **The five push actions
  (`BatchCheckLayerAvailability`/`InitiateLayerUpload`/`UploadLayerPart`/
  `CompleteLayerUpload`/`PutImage`), scoped to the one repository ARN** this
  build actually needs to push to. This is where the real narrowing
  happens: a token that authenticates you to the registry is useless for
  pushing anywhere this role's policy doesn't explicitly allow.

### 8. ECR as the custody register

ECR is where "the artifact" becomes something you can query, not just
something you trust happened. Four features make that true:

- **Tag immutability** (`image_tag_mutability = "IMMUTABLE"`, set on the
  foundation stack's repository) — once a tag is pushed, pushing a
  *different* image under that same tag is rejected outright
  (`ImageTagAlreadyExistsException`). This is the mechanism, not a
  convention: nobody has to remember not to overwrite a tag, ECR refuses to
  let it happen.
- **Lifecycle policies** — the foundation stack keeps the 10 most recent
  images and expires the rest, which bounds storage cost without you
  manually pruning.
- **Scan-on-push, basic vs enhanced** — basic scanning (enabled here, free)
  checks pushed images against the Common Vulnerabilities and Exposures
  (CVE) database on every push. Enhanced scanning (AWS Inspector-backed,
  ~$0.09/image, **named here but not enabled** in this path) adds
  continuous rescanning as new CVEs are published and OS/language package
  vulnerability coverage beyond the basic scanner. Basic is the right
  default for a lab; enhanced is a real production consideration once image
  volume and blast radius justify the cost.
- **Digests as true identity.** A tag is a label you (or a script) chose. A
  digest — `sha256:<hash of the image manifest>` — is computed from the
  image's actual content. Two pushes can share a tag only if immutability is
  off (see the Break it exercise); two pushes can never share a digest
  unless the bytes are identical. The digest is the fact; the tag is a
  convenience name for looking the fact up.

### 9. Secrets

`buildspec.yml` supports pulling secret values in two safe ways —
`env.parameter-store` (SSM Parameter Store) and `env.secrets-manager`
(Secrets Manager) — versus the unsafe way, plaintext `env.variables`, which
puts the value directly in the buildspec file (and, if that file is
version-controlled, in your Git history forever).

The leak nobody expects, though, isn't about where a secret is *declared* —
it's about how it's *used* afterward. CodeBuild echoes every command it runs
to CloudWatch Logs, arguments included. A secret correctly pulled from
Secrets Manager into an environment variable, then passed as a CLI argument
(`some-tool --token "$MY_SECRET"`), lands in plaintext in the build log the
instant that command executes — the safe retrieval mechanism doesn't protect
you from an unsafe *use*. This lab's ECR login sidesteps exactly this
failure mode: `aws ecr get-login-password | docker login --password-stdin`
pipes the token through stdin rather than passing it as a `--password`
argument, specifically so it never appears as a logged command argument.

## Decision rules

| When you see... | Choose... | Because |
|---|---|---|
| A build that runs `docker build` | `ARM_CONTAINER` (or x86) with `privileged_mode = true`, not Lambda compute | Lambda compute has no privileged mode, so it cannot run a Docker daemon at all |
| A build with no Docker step, just compile/test | Lambda compute | Cheaper per minute, faster cold start, and the 15-minute cap and no-privileged-mode constraints don't bite a build that never needed them |
| An arm64-compatible build (like this Go service) | `ARM_CONTAINER` over x86 `LINUX_CONTAINER` | ~30% cheaper per build-minute with no compatibility cost here |
| A cache that only needs to speed up *most* builds, not guarantee a hit | `LOCAL_*` caching modes | Free, fast on a host hit, and a miss only costs time, never correctness |
| A cache that must hit every time regardless of build host | S3 caching | Local caching is best-effort by design; S3 caching costs a download every build but is reliable |
| Deciding what belongs in `artifacts:` vs `reports:` | `artifacts:` for anything the next stage consumes as a file; `reports:` for structured test results you want CodeBuild's own UI to render | CodeBuild treats the two sections completely differently — one is opaque file-passing, the other is parsed |
| Writing the build role's ECR permissions | `ecr:GetAuthorizationToken` on `"*"`, everything else scoped to one repository ARN | `GetAuthorizationToken` is not resource-scopable by the API itself; the push actions are, so they should be |
| A secret that must reach a shell command | Parameter Store or Secrets Manager reference, piped via stdin (never a `--flag value` CLI argument) | CodeBuild logs every command's arguments; stdin input isn't part of the logged command line |
| Deciding whether to tag `:latest` | Never — tag from `CODEBUILD_RESOLVED_SOURCE_VERSION` instead | A mutable, human-meaningful tag answers "what did we push most recently," not "what is running right now, verifiably" |

## Lab

See `labs/day01/`. The goal: produce one immutable, identifiable artifact.
Success signal: an image in ECR whose tag is a commit SHA and which cannot
be overwritten.

## Break it / Fix it

Attempt to push a second image under a tag that's already in ECR — the
first thing you'll hit is `ImageTagAlreadyExistsException`, immutability
doing its job. Then deliberately turn immutability off, push two different
commits under the same tag, and try to answer "which commit is running?"
using only the tag. You can't — the only fact left standing is the digest.
Full steps, including how to restore immutability afterward, are in
`labs/day01/README.md`.

## Exercises

1. Given a buildspec that tags an image `:latest`, rewrite the tagging logic
   so the tag is derived from immutable, digest-friendly identity instead,
   and explain what breaks in the deploy stage as a result.

   **Hint:** Look at where this lab's `buildspec.yml` derives `IMAGE_TAG` —
   what value does it use, and where does that value come from?

   **Solution sketch:** Replace `docker build -t "$REPO_URI:latest" ...` /
   `docker push "$REPO_URI:latest"` with
   `IMAGE_TAG="${CODEBUILD_RESOLVED_SOURCE_VERSION:0:12}"` and tag/push
   `"$REPO_URI:$IMAGE_TAG"` instead — exactly what this lab's buildspec
   already does. What breaks downstream: the deploy stage can no longer say
   "deploy `:latest`" as a fixed, reusable instruction, because there is no
   longer a stable name that always means "the newest thing." It must
   instead be *given* a specific tag (or digest) as an input for each
   deploy — which is the point: deploys become explicit about what they're
   shipping instead of implicitly trusting "whatever is newest right now."

2. Compute the monthly CodeBuild cost for 40 builds/day at 3 minutes each,
   on ARM small compute vs x86 small compute.

   **Hint:** ~$0.0034/build-minute for ARM, ~$0.005/build-minute for x86.
   Total build-minutes per month = builds/day × minutes/build × days/month.

   **Solution sketch:** 40 × 3 × 30 = 3,600 build-minutes/month.
   ARM: 3,600 × $0.0034 ≈ **$12.24/month**. x86: 3,600 × $0.005 =
   **$18.00/month**. Difference: ~$5.76/month saved by choosing ARM. The
   arithmetic itself matters less than noticing that compute-type selection
   is a *pricing* decision with a concrete monthly number attached to it,
   not just a technical preference.

3. A build succeeds and reports a pushed image, but the running container
   is missing the version string that should have come from `-X
   main.version=...`. Name the three most likely causes.

   **Hint:** Trace the value from the buildspec, through the `docker build`
   command, into the Dockerfile, and into the Go `ldflags`. Where could the
   value get silently dropped at each handoff?

   **Solution sketch:** (1) The ldflags value was never passed into the
   image build as a `--build-arg` — the buildspec ran `docker build` without
   `--build-arg VERSION=...`, so the Dockerfile's `ARG VERSION=dev` default
   silently won. (2) The Dockerfile's build stage never declares `ARG
   VERSION` (or `ARG GIT_COMMIT`) at all — a `--build-arg` passed for an
   undeclared `ARG` is simply ignored by Docker, no error. (3) The variable
   name in `-X main.version=${VERSION}` doesn't match the actual
   package-level variable name in `main.go` (for example, `-X
   main.Version=...` capitalized differently, or referencing a variable
   that isn't declared `var version string` at package scope) — `-X` fails
   silently on a name mismatch rather than erroring the build.

4. Write the least-privilege IAM policy statement(s) for the build role's
   ECR push permissions.

   **Hint:** Two different resource scopes are needed here — one action
   can't be scoped to a repository at all, and five others should be scoped
   to exactly one.

   **Solution sketch:** Two statements — one granting `ecr:GetAuthorizationToken`
   on `Resource: "*"` (not resource-scopable — the action authenticates to
   the whole registry, not one repository), and a second granting
   `ecr:BatchCheckLayerAvailability`, `ecr:InitiateLayerUpload`,
   `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, and `ecr:PutImage`
   scoped to `data.terraform_remote_state.foundation.outputs.ecr_repository_arn`
   — exactly the shape `labs/day01/main.tf`'s `aws_iam_role_policy.codebuild`
   implements.

## Anti-patterns / Common mistakes

- **Tagging every image `:latest`.** `:latest` is not a version, it's a
  moving pointer — the same failure mode as "we deploy `main`," one layer
  further into the pipeline. It makes "what's running right now"
  unanswerable and makes rollback mean "guess an older tag and hope."
- **Rebuilding the same commit separately for every environment.** If
  staging and production each trigger their own build from the same source,
  you are no longer promoting one tested artifact — you're building two
  different artifacts from the same source and hoping they turn out
  identical. Different build timestamps, different dependency resolution
  windows, and different transient environment state can all make that hope
  wrong. Build once; promote the digest.
- **Secrets as plaintext `env.variables`.** Beyond the obvious (anyone who
  can read the buildspec, or its Git history, reads the secret), plaintext
  buildspec variables have no rotation story and no audit trail — Secrets
  Manager and Parameter Store give you both, plus the stdin-not-argument
  discipline that keeps values out of build logs too.
- **`FROM ubuntu` (or any full OS base image) for a statically compiled Go
  binary.** `app/Dockerfile`'s final stage is `FROM scratch` for a reason:
  a `CGO_ENABLED=0` Go binary has no dependency on libc, a shell, or any
  package manager, so a full OS base image adds tens or hundreds of
  megabytes of attack surface, CVE-scan noise, and pull time that buys
  nothing the binary actually needs.

## Teardown

```bash
cd labs/day01
terraform destroy
bash ../verify-teardown.sh
```

Full checklist — including the CodeBuild-auto-created-log-group edge case —
is in `labs/day01/teardown.md`. **Leave `labs/foundation/` running**; it
stays up all week.

## Self-check

1. You have a running service and someone asks "what code is this?" What
   command, against what AWS resource, gives you a defensible answer — and
   why isn't "check which branch we deployed" good enough?
2. Your buildspec's `pre_build` phase computes `IMAGE_TAG` from
   `CODEBUILD_RESOLVED_SOURCE_VERSION`. Why not just use
   `CODEBUILD_SOURCE_VERSION` (the value CodeBuild was *given*, before
   resolution) instead — what could differ between the two?
3. Someone proposes running this project's build with 40 builds/day for a
   month on x86 compute instead of ARM. What's the monthly cost delta, and
   what single Terraform attribute would you change to capture the saving?

If any of these is unanswerable without looking back, re-read the matching
Core concept — 1 for the first, 2 for the second, 3 for the third — before
moving on to Day 2.

# Day 4 — Same chain, different substrate

**Chain link:** `(substrate)` · **Time:** ~3.2h (content ~55m · lab ~110m ·
break/fix ~20m · teardown ~5m) · **Cost:** $0.00

## The question of the day

**Does the chain of custody survive a change of substrate?**

## Why this matters

This day makes you **conversant** in Kubernetes, not competent. Deep EKS —
running it in production, tuning autoscalers, operating a control plane you
own — is a separate, future path. What you get here is enough vocabulary
and enough hands-on time to hold a real conversation with a platform team
that runs Kubernetes, and to know which of your ECS instincts still apply.

The reason this day exists at all, in a path otherwise organized around
ECS, is a test: if the chain-of-custody model from `STRATEGY.md` — PRODUCE,
PROVE, PROMOTE, REVERSE, MEASURE — only works because of something specific
to ECS, then it was never really an abstraction. It was an ECS story wearing
an abstraction's clothes. The only way to find out is to swap the substrate
underneath the same artifact and see what breaks. Today you take the exact
image you built on Day 1, with the exact `/readyz` and `POISON` contract you
tested against ECS on Day 3, and deploy it to Kubernetes instead. If the
same mental model still explains what you see — same artifact, same
custody, different machinery underneath — the model survives. If it
doesn't, that's worth knowing too, and it's worth knowing on a free local
cluster rather than on a $0.10/h EKS control plane the first time you find
out.

## Core concepts

### 1. Reconciliation vs events

This is the single most important conceptual difference between ECS and
Kubernetes. An ECS deployment is an **event**: you call `UpdateService`, ECS
starts a task set, waits for health checks, and either finishes or rolls
back — a bounded, one-shot operation with a beginning and an end. Kubernetes
has no equivalent single event. Instead, a set of controllers run a
**control loop**, forever, comparing declared state (what you told the API
server you want) against observed state (what's actually running) and
nudging the difference toward zero. `kubectl apply -f deployment.yaml` does
not deploy anything — it writes desired state into etcd. The Deployment
controller, watching that state, is the thing that actually decides when
and how reality should catch up. This is why `kubectl apply` returning
successfully tells you your *intent* was recorded, and nothing about
whether it was *achieved*. You check that separately with `kubectl rollout
status`.

### 2. The five objects that matter here

**Pod** — the smallest deployable unit: one or more containers that share a
network namespace and are always scheduled together. A Pod is disposable;
nothing in Kubernetes tries hard to keep a specific Pod alive, and you
almost never create one directly.

**Deployment** — a declarative wrapper that says "keep N replicas of this
Pod template running, and here is how to roll from one version of the
template to the next." You edit a Deployment; you don't edit Pods.

**ReplicaSet** — the object a Deployment actually creates and manages under
the hood, responsible for keeping exactly N Pods of one specific template
version alive. A rolling update works by a Deployment creating a *new*
ReplicaSet and scaling it up while scaling the old ReplicaSet down; you
rarely touch a ReplicaSet directly, but `kubectl get rs` is where you see a
rollout's arithmetic happening.

**Service** — a stable network identity (a virtual IP and DNS name) in front
of a changing set of Pods, selected by label. Pods come and go on every
rollout; the Service is what stays put so nothing else in the cluster needs
to track individual Pod IPs.

**Ingress** — a set of HTTP(S) routing rules (host/path → Service) that an
Ingress controller turns into real load-balancer or proxy configuration.
Ingress is optional for this lab — a NodePort Service is enough to reach the
app on `kind` — but it's the object that plays the ALB-listener-rule role in
a real cluster.

### 3. Rolling update vs blue/green

A Deployment's default strategy is `RollingUpdate`, governed by two knobs:
`maxSurge` (how many Pods above the desired count the rollout may create
temporarily) and `maxUnavailable` (how many of the desired count may be
missing at once). With the common defaults (`25%`/`25%`), a rollout creates
a few new Pods, waits for them to pass readiness, retires a few old ones,
and repeats — old and new versions coexist and share traffic through the
same Service for the whole rollout. This is a genuinely different shape
from Day 3's blue/green: blue/green keeps two *complete*, isolated
environments and cuts traffic from one to the other in one motion, so at any
given instant either the old version or the new version is serving, never a
mix. Kubernetes can do blue/green (two Deployments, a Service selector you
flip), but it isn't the default, and the reason it isn't the default is that
rolling updates need no second full-size environment — you pay for `maxSurge`
extra Pods, not a whole second fleet.

### 4. Readiness probes as the deploy gate

A `readinessProbe` is the direct analog of Day 3's ALB target group health
check: it's what tells the platform "this specific instance may receive
traffic," separately from "this process is alive." The behavior that
matters — and the one this lab is built to make you watch happen — is that
**a Deployment with a Pod failing its readiness probe stalls rather than
completing.** The rollout controller will not scale the old ReplicaSet down
past `maxUnavailable` while the new one isn't passing readiness, so a bad
image doesn't get shipped; it just sits there, half-rolled, until you notice
or until `progressDeadlineSeconds` expires. That stall — not a fast failure,
not an automatic rollback — is the lab's punchline, and it's worth sitting
with before you read the Break it section below.

### 5. Why immutability matters more here

On ECS, a task definition pins an exact image digest (or at least an exact
tag) at revision-creation time; every task launched from that revision runs
the same bits, by construction. Kubernetes has no equivalent structural
guarantee. If `imagePullPolicy: Always` is set and the image tag is mutable
(anyone can `docker push` a new image to the same tag), then two Pods that
both say `image: myapp:latest` in `kubectl describe` can be running
genuinely different code, because each Pod pulled whatever `:latest`
pointed to *at the moment it started*, not at the moment the Deployment was
last edited. Nothing enforces that they match. This is exactly the custody
break the whole path is organized around: if you can't say what's running,
you can't say what you tested. On Kubernetes, immutability is a discipline
you impose (immutable tags or digest pins, `imagePullPolicy: IfNotPresent`
with a versioned tag) rather than a property the platform hands you for
free the way ECS's task definition does.

### 6. The ECS ↔ Kubernetes mapping table

This is the highest-value artifact of the day. Memorize the left-right
pairs, not the K8s column in isolation — the value is in the mapping, not
the trivia.

| ECS concept | Kubernetes concept |
|---|---|
| Task definition | Pod spec |
| Service | Deployment |
| Task set | ReplicaSet |
| Target group | Service |
| ALB listener rule | Ingress |
| Task role | ServiceAccount + IRSA |
| Execution role | Node IAM role / image pull secret |
| Deployment health-check gate + auto-rollback (CodeDeploy) | `progressDeadlineSeconds` |
| `desired_count` | `replicas` |

A few of these deserve a sentence each. Task role ↔ ServiceAccount+IRSA is
two AWS concepts (task role, execution role) mapping onto a decomposition
K8s doesn't natively have — see IRSA below. The deployment row needs a
naming note: Day 3's service uses the CodeDeploy blue/green controller, so
what actually gates and rolls back a bad task set there is CodeDeploy's own
health-check gate plus its `DEPLOYMENT_FAILURE` auto-rollback — **not** the
ECS deployment circuit breaker. The circuit breaker
(`deploymentConfiguration.deploymentCircuitBreaker`) is real, but it only
exists for the plain **`ECS` rolling-update** deployment controller; if
Day 3's service ran that controller instead of CodeDeploy, the circuit
breaker — counting consecutive health-check failures and rolling back on
its own — would be the mechanism doing this job, and it would map onto
`progressDeadlineSeconds` even more directly. Either way the comparison
holds: it looks like a one-line swap but the failure modes differ. ECS's
mechanism (CodeDeploy's gate here, or the circuit breaker on a rolling
deployment) actively rolls back a bad deployment; a Deployment past its
`progressDeadlineSeconds` is marked `Progressing=False` and *stops*, but
does not roll back on its own — someone (or some GitOps tool) still has to
run `kubectl rollout undo`.

### 7. IRSA

IAM Roles for Service Accounts (IRSA) is how a Pod gets scoped AWS
permissions without long-lived credentials baked into a container image.
The pieces: an OIDC identity provider registered in IAM for the EKS
cluster's issuer URL, a Kubernetes ServiceAccount annotated with an IAM role
ARN, and the EKS control plane injecting a short-lived, auto-rotated OIDC
token into any Pod using that ServiceAccount. The AWS SDK inside the Pod
exchanges that token for temporary credentials via
`sts:AssumeRoleWithWebIdentity`.

Name the lineage plainly: **this is the exact same trust mechanism as Day
2's GitHub Actions OIDC federation** — the same `AssumeRoleWithWebIdentity`
call, the same "an external OIDC issuer vouches for an identity, IAM trusts
the issuer, and a role's trust policy conditions on a claim in the token" —
with a different issuer (the EKS cluster's OIDC endpoint instead of
`token.actions.githubusercontent.com`) and a different subject claim shape
(`system:serviceaccount:<namespace>:<name>` instead of
`repo:<owner>/<repo>:ref:refs/heads/<branch>`). If Day 2 taught you to read
an OIDC trust policy, IRSA costs you nothing new to understand — only a new
issuer to plug in. Recognizing that is worth more than any amount of EKS
configuration trivia, and it's exactly the kind of "same shape, different
label" pattern-matching this path is trying to build in you.

### 8. How a pipeline reaches a cluster

Two shapes, and they trade off differently than anything on ECS:

**Push** — CI runs `kubectl apply` (or `helm upgrade`) directly against the
cluster's API server. Simple to reason about and matches the ECS mental
model (CI calls an API, waits for the result) but it means your CI system
needs live, sufficiently-privileged credentials to your cluster, and CI must
be network-reachable to the API server — which is a meaningfully large
trust boundary to hand a CI runner.

**Pull (GitOps)** — an in-cluster controller (Argo CD, Flux) watches a Git
repo and reconciles the cluster to match what's committed there; CI's job
ends at "push a commit that changes a manifest," and it never touches the
cluster's credentials at all. This also gets you continuous drift detection
for free — the same controller that applies your intended state also
notices and can correct manual `kubectl edit` drift — at the cost of running
and operating one more component.

Argo CD and Flux are named here so you have the vocabulary; wiring either
one up is out of scope for this day and deferred to the future EKS path.
The one-line rule for when pull starts paying off: **once you have more
than a handful of clusters, or compliance requires an audit trail of every
change to running state, GitOps earns its extra moving part; below that, push
is simpler and that simplicity is not a compromise.**

### 9. What EKS costs and why we are not using it today

An EKS control plane costs **~$0.10/hour (~$73/month)** whether or not a
single Pod is running on it — that's before nodes (EC2 or Fargate profiles),
and usually before a NAT gateway, since most real EKS deployments run
worker nodes in private subnets. An idle "just to learn on" EKS cluster
commonly runs **$100+/month**. This path's cost target for the whole week is
$3–8 — see `COST.md` — so today runs entirely on a local `kind` (Kubernetes
IN Docker) cluster instead: same Kubernetes API, same manifests, $0. The
`eks/` Terraform in this lab is written and correct, but it exists for the
future EKS path to start from, not for you to apply today.

## Decision rules

- **Reach for the ECS↔K8s table before reaching for K8s documentation.**
  If you already know what a target group does, you already know 80% of
  what a Service does — look up the syntax, not the concept.
- **Treat `kubectl apply` succeeding as "intent recorded," never as
  "deployment done."** Always follow it with `kubectl rollout status`
  before you believe anything shipped.
- **A stalled rollout is not a bug to route around with `kubectl delete pod`
  — it's the platform doing its job.** Investigate the readiness probe
  first; forcing Pods to restart just resets the clock on the same failure.
- **Never let an IAM role's trust policy stay wide because "it's just a
  side project."** Scope IRSA (and Day 2's GitHub OIDC) `sub` conditions to
  the exact namespace/ServiceAccount or exact repo/branch — a broad
  `StringLike` on `sub` is the same mistake in either mechanism.
- **Default to push-based deploys until a concrete trigger (multi-cluster,
  audit requirement) justifies GitOps** — don't adopt Argo CD/Flux because
  it's the "correct" pattern; adopt it when the one-line rule above fires.
- **Never `terraform apply` in `eks/` during this path.** It's reference
  code for later, not a step in this lab.

## Lab

Work through [`labs/day04/README.md`](../labs/day04/README.md). You'll
stand up a free local `kind` cluster, deploy the same sample service you
built on Day 1 and shipped via blue/green on Day 3, watch a normal rolling
update succeed, then set `POISON=true` and watch the rollout stall instead
of shipping a broken version — the same class of failure Day 3's
CodeDeploy health-check gate catches, caught here by a different
mechanism.

## Break it / Fix it

The break: flip the Deployment's `POISON` env var to `"true"` and
`kubectl apply` it. Watch `kubectl get pods` — the new Pod reaches `Running`
but sits at `0/1 READY` indefinitely, while the old Pods keep serving
traffic through the Service the whole time. Nothing falls over; nothing
serves a 503 to a real client. The fix: `kubectl rollout undo`, which
reverts the Deployment's Pod template back to the last good ReplicaSet.

Compare this deliberately with Day 3: CodeDeploy's health-check gate
detects a failing task set and **actively rolls back** on your behalf
(`DEPLOYMENT_FAILURE` auto-rollback), finishing the story without a human
in the loop — that's the mechanism Day 3 actually used, not the ECS
deployment circuit breaker, which only applies to a plain rolling-update
ECS deployment (see Core concept 6). Kubernetes's `progressDeadlineSeconds`
only marks the Deployment's `Progressing` condition `False` after the
deadline and **stops** — it does not undo anything. Name which failure
each mechanism actually catches: both catch "the new version can't pass
its own health check," but only Day 3's ECS-side mechanism closes the loop
by itself; on K8s, closing the loop is on you (or on a GitOps controller
watching for exactly this condition).

## Exercises

1. **Fill in the ECS↔Kubernetes mapping table from memory** — all nine
   pairs — before checking it against Core concepts §6.

   **Hint:** Work top to bottom in the order things get created for a
   single deploy: what defines the Pod, what manages replicas of it, what
   routes traffic to it, what gates a rollout, what identity a Pod runs as.

   **Solution sketch:** Task definition↔Pod spec, service↔Deployment, task
   set↔ReplicaSet, target group↔Service, ALB listener rule↔Ingress, task
   role↔ServiceAccount+IRSA, execution role↔node role/pull secret,
   deployment health-check gate + auto-rollback↔`progressDeadlineSeconds`,
   `desired_count`↔`replicas`. Grade yourself hardest on task set↔ReplicaSet
   and task role↔IRSA — they're the two most commonly missed, because ECS
   bundles what K8s splits into two separate mechanisms (an object plus an
   auth pattern). On the deployment row, bonus points if you can also name
   where the ECS deployment circuit breaker fits: the rolling-update analog
   of that gate, not what Day 3 actually used.

2. **A Deployment update leaves 3 old Pods and 1 new Pod running for 20
   minutes.** What is happening, and is it broken?

   **Hint:** Check the new Pod's `READY` column, not just its `STATUS`
   column — `Running` and `Ready` are not the same claim.

   **Solution sketch:** The new Pod is `Running` but failing its readiness
   probe, so the rollout is blocked at `maxSurge`/`maxUnavailable` and can't
   retire more old Pods. This is correct behavior, not a bug — it's the
   cluster refusing to finish shipping a version that can't prove it's
   healthy. Left alone, it eventually flips `Progressing=False` once
   `progressDeadlineSeconds` elapses, but it will sit there stalled, not
   crash-loop, until then.

3. **Explain why IRSA and Day 2's GitHub Actions OIDC are the same
   mechanism.**

   **Hint:** Ask what each one calls, what vouches for the caller's
   identity, and what the trust policy conditions on.

   **Solution sketch:** Both are `sts:AssumeRoleWithWebIdentity` against an
   IAM OIDC identity provider — an external issuer signs a token, IAM
   verifies the issuer, and the role's trust policy checks a `sub` claim
   before granting temporary credentials. Only the issuer URL and the `sub`
   claim's format differ: `system:serviceaccount:<namespace>:<name>` for
   IRSA versus `repo:<owner>/<repo>:ref:refs/heads/<branch>` for GitHub
   Actions. Same mechanism, different vouching party.

4. **Your team runs 4 services on ECS Fargate and is considering EKS. Give
   the honest cost and complexity delta.**

   **Hint:** List what EKS adds that ECS doesn't have, not what EKS is
   generically good at.

   **Solution sketch:** EKS adds a ~$73/month control plane, either node
   management or Fargate profiles to configure per workload, usually a NAT
   gateway once nodes sit in private subnets, and a Kubernetes version
   upgrade cadence ECS simply doesn't impose on you. It pays off once you
   have many services, heavy per-service customization needs (custom
   schedulers, service mesh, operators), or a team that's already
   Kubernetes-fluent and would fight ECS's constraints instead of benefiting
   from them. At 4 services, on a small team, it almost certainly does not
   pay off yet — and being able to say that plainly, instead of defaulting
   to "Kubernetes is the industry standard," is a senior answer.

## Anti-patterns / Common mistakes

- **Treating `kubectl apply` as a deployment strategy.** It only writes
  desired state; `kubectl rollout status` is the step that tells you
  whether reality caught up, and skipping it is how "the deploy is done"
  turns out to mean "the stall started five minutes ago."
- **Shipping a Deployment with no readiness probe.** Without one, every Pod
  is considered ready the instant its container starts, so a broken new
  version gets full traffic immediately instead of being gated out — the
  exact failure mode this lab is built to show you avoiding.
- **Using the EKS node IAM role for application permissions instead of
  IRSA.** Every Pod on that node inherits the node role's permissions,
  which is the Kubernetes equivalent of giving every ECS task the execution
  role's permissions instead of a scoped task role — a blast-radius mistake,
  not a convenience.
- **Assuming `kubectl rollout undo` restores data.** It reverts the
  Deployment's Pod template to the previous ReplicaSet — code and config —
  and nothing else. Any database migration, external state change, or side
  effect the bad version caused is untouched by a rollback and needs its
  own recovery plan.

## Teardown

Work through [`labs/day04/teardown.md`](../labs/day04/teardown.md) —
`kind delete cluster`, and nothing else, because nothing else was ever
created. Cost impact: $0.00.

## Self-check

- [ ] I can state, without looking, the ECS↔Kubernetes mapping for all nine
      pairs in the table.
- [ ] I can explain why `kubectl apply` succeeding does not mean a
      deployment finished, in terms of reconciliation vs events.
- [ ] I watched a Deployment stall on a failing readiness probe and can
      describe exactly what `kubectl get pods` showed while it did.
- [ ] I can name what Day 3's CodeDeploy health-check gate + auto-rollback
      catches automatically that `progressDeadlineSeconds` does not, and I
      can say where the ECS deployment circuit breaker actually fits (the
      rolling-update analog, not what Day 3 used).
- [ ] I can explain IRSA as "Day 2's GitHub OIDC with a different issuer" in
      one breath, not as a separate EKS-specific concept.
- [ ] I can state the one-line rule for when GitOps (pull) starts paying
      off over a push-based pipeline.
- [ ] I can give the honest EKS cost/complexity delta for a small team
      without reflexively recommending EKS.
- [ ] I never ran `terraform apply` inside `labs/day04/eks/`.

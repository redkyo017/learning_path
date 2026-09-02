# Day 4 lab — Same chain, different substrate

Read [`content/day04.md`](../../content/day04.md) first — this lab assumes
you've read Core concepts 1–6 already.

## Goal

Deploy the same `awsdevops-sample` service you built on Day 1 and shipped
via blue/green on Day 3 — same image, same `/readyz` + `POISON` contract —
to a local Kubernetes cluster instead of ECS Fargate, and watch a poisoned
rollout stall instead of ship.

**Success signal:** you set `POISON=true`, apply it, and watch a broken
rollout **stall** rather than complete — `kubectl get pods` shows the new
Pod stuck at `Running` / `0/1 READY` while the old Pods keep serving traffic
the whole time. Nobody sees a 503. Nothing "fails" loudly. That quiet stall
*is* the correct behavior, and recognizing it as correct is the point of
this lab.

## Prerequisites

- `kind` and `kubectl` installed (checked in Day 0, step 8).
- Docker running locally.
- The `app/` sample service from this repo (`aws_devops_sre/app/`) — you
  already built this on Day 1.

Cost: **$0.00**. Everything in this lab is a set of Docker containers on
your machine. No AWS resource is created.

## Steps

### 1. Create the cluster

```bash
cd labs/day04
kind create cluster --config kind-cluster.yaml
kubectl cluster-info --context kind-awsdevops-day04
```

### 2. Build and load the image locally

This lab does not give the `kind` cluster ECR pull credentials, so build
the image locally and load it directly into the cluster's node — no
registry round-trip needed. (See the comment in `k8s/deployment.yaml` for
the ECR alternative if you've separately set up pull access.)

```bash
docker build -t awsdevops-sample:local \
  --build-arg VERSION=day04-lab \
  --build-arg GIT_COMMIT=local \
  ../../app

kind load docker-image awsdevops-sample:local --name awsdevops-day04
```

Edit `k8s/deployment.yaml` and set `image: awsdevops-sample:local` in place
of the `<YOUR_ECR_URL>:<TAG>` placeholder.

### 3. Apply the manifests and confirm the rollout

```bash
kubectl apply -f k8s/
kubectl rollout status deployment/awsdevops-sample
```

Remember: `kubectl apply` returning immediately only means your desired
state was recorded — `kubectl rollout status` is the command that actually
tells you whether the cluster caught up to it (Core concepts #1).

### 4. Confirm you can reach it

```bash
curl localhost:8080/
curl localhost:8080/readyz
```

You should see the same JSON shape (`service`, `version`, `commit`,
`hostname`) you saw hitting the ALB on Day 3 — same artifact, different
substrate.

### 5. Do a normal update

Rebuild with a different `VERSION` and re-load it, to see an ordinary
rolling update happen:

```bash
docker build -t awsdevops-sample:local \
  --build-arg VERSION=day04-lab-v2 \
  --build-arg GIT_COMMIT=local2 \
  ../../app

kind load docker-image awsdevops-sample:local --name awsdevops-day04
kubectl rollout restart deployment/awsdevops-sample
kubectl rollout status deployment/awsdevops-sample
curl localhost:8080/    # "version" should now read day04-lab-v2
```

Watch `kubectl get pods -w` in a second terminal during this step if you
want to see `maxSurge`/`maxUnavailable` in action — new Pods appearing
before old ones disappear, never a hard cutover.

## Break it

Edit `k8s/deployment.yaml`: change the `POISON` env value from `"false"` to
`"true"`. Apply it:

```bash
kubectl apply -f k8s/deployment.yaml
kubectl get pods -w
```

Watch closely. You will see a new Pod reach `STATUS: Running` — the
container started fine — but its `READY` column stays at `0/1`,
indefinitely. Meanwhile the old Pods are still `1/1 READY` and are still
the ones actually serving `curl localhost:8080/`. Confirm:

```bash
kubectl get pods
kubectl describe pod <new-pod-name> | grep -A5 Readiness
curl localhost:8080/readyz   # still 200 — old Pods are still fronting the Service
```

Nothing crashed. Nothing rolled back on its own. The Deployment is simply
**stuck**, refusing to retire the last old Pod because the new one can't
prove it's healthy. Leave it long enough (past `progressDeadlineSeconds:
120` in the manifest) and `kubectl rollout status` will report the rollout
as failed to progress — but note it still won't undo anything by itself.

**Stop and compare this with Day 3 before moving on.** Day 3's CodeDeploy
health-check gate detects the exact same class of failure — a new version
that can't pass its health check — and *actively rolls the service back*
on your behalf (`DEPLOYMENT_FAILURE` auto-rollback), with no `rollout undo`
required. (That's not the ECS deployment circuit breaker — Day 3's service
uses the CodeDeploy blue/green controller, which doesn't have one; the
circuit breaker is the rolling-update analog, see `content/day04.md` Core
concept 6.) Write down, in your own words, which failure each mechanism
actually catches, and which one closes the loop by itself. (The Exercises
section of `content/day04.md` and `SOLUTION.md` both have the answer if
you want to check yourself.)

## Fix it

```bash
kubectl rollout undo deployment/awsdevops-sample
kubectl rollout status deployment/awsdevops-sample
kubectl get pods
curl localhost:8080/readyz   # 200 again, from an unpoisoned Pod
```

## Next

When you're done, go straight to [`teardown.md`](teardown.md) — a `kind`
cluster left running costs nothing in AWS but is still worth cleaning up
before you move on.

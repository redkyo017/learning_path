# Day 4 lab — expected output and explanations

## After `kubectl apply -f k8s/` (step 3)

```
$ kubectl rollout status deployment/awsdevops-sample
Waiting for deployment "awsdevops-sample" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "awsdevops-sample" rollout to finish: 1 of 2 updated replicas are available...
deployment "awsdevops-sample" successfully rolled out

$ kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
awsdevops-sample-7d9f8c6b45-abcde   1/1     Running   0          20s
awsdevops-sample-7d9f8c6b45-fghij   1/1     Running   0          20s
```

Both Pods `1/1 READY` — the readiness probe against `/readyz` is passing on
both, so the Service has both in its endpoint list.

## After the normal update (step 5)

```
$ kubectl rollout status deployment/awsdevops-sample
Waiting for deployment "awsdevops-sample" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "awsdevops-sample" rollout to finish: 1 old replicas are pending termination...
deployment "awsdevops-sample" successfully rolled out

$ kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
awsdevops-sample-6c8b9d7f21-klmno   1/1     Running   0          15s
awsdevops-sample-6c8b9d7f21-pqrst   1/1     Running   0          10s
```

New ReplicaSet's Pods have replaced the old ReplicaSet's Pods one at a time
(`maxSurge`/`maxUnavailable` at their 25%/25% defaults on `replicas: 2`
round to "one at a time" in practice). `curl localhost:8080/` now reports
`"version":"day04-lab-v2"`.

## Break it — expected `kubectl get pods` during the stall

```
$ kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
awsdevops-sample-6c8b9d7f21-klmno   1/1     Running   0          4m
awsdevops-sample-6c8b9d7f21-pqrst   1/1     Running   0          4m
awsdevops-sample-9f4a2e8c67-uvwxy   0/1     Running   0          45s
```

Both old Pods (from the previous good ReplicaSet, `6c8b9d7f21`) still
`1/1 READY` and still receiving traffic through the Service — with
`maxUnavailable: 25%` rounding down to 0 for a count of 2, the Deployment
can't retire either of them yet. One new Pod (from the poisoned ReplicaSet,
`9f4a2e8c67`) is `Running` but stuck `0/1` — that's `maxSurge: 25%` rounding
up to 1, so exactly one new Pod is allowed to surge in ahead of any old Pod
being removed. So it just... waits, with three Pods up instead of two.
`kubectl describe pod <new-pod-name>` shows
`Warning  Unhealthy  ... Readiness probe failed: HTTP probe failed with
statuscode: 503` on repeat.

```
$ kubectl rollout status deployment/awsdevops-sample
Waiting for deployment "awsdevops-sample" rollout to finish: 1 out of 2 new replicas have been updated...
error: deployment "awsdevops-sample" exceeded its progress deadline
```

That last line only appears after `progressDeadlineSeconds: 120` elapses —
before that, `rollout status` just hangs, waiting, exactly like the pods it's
describing.

## Why it stalls instead of failing immediately

The Deployment controller's job is to converge desired state (2 healthy
replicas of the new template) with observed state, subject to the
`maxSurge`/`maxUnavailable` budget — it is not wired to treat "a probe keeps
failing" as an error to abort on. It just keeps retrying the probe on the
schedule in `readinessProbe` (`periodSeconds: 5`, `failureThreshold: 3`
here) forever, because from the controller's point of view a currently-failing
probe might pass on the very next check. `progressDeadlineSeconds` is the
only thing that eventually calls the situation a status condition
(`Progressing=False`) — and even then, it only *reports* failure. It does
not scale the new ReplicaSet back down or bring the old one back up; the
Pods you saw above are still sitting there in the same state after the
deadline fires. Compare with ECS: Day 3's service is gated by CodeDeploy's
own health-check gate, which is explicitly designed to detect "the green
task set never passes its health check" as a deployment failure and *act*
on it (stop the deployment, roll the service back to the previous task
definition via `DEPLOYMENT_FAILURE` auto-rollback) rather than only report
it. (This is *not* the ECS deployment circuit breaker — that only exists
for the `ECS` rolling-update controller, which Day 3 doesn't use. It's the
rolling-update analog of the gate CodeDeploy is enforcing here — see
`content/day04.md` Core concept 6.)

## ECS ↔ Kubernetes comparison, worked for this lab specifically

| What happened | Day 3 (ECS) | Day 4 (Kubernetes) |
|---|---|---|
| You changed the running version | `aws ecs update-service` / CodeDeploy triggers a new task set | `kubectl apply` edits the Deployment's Pod template |
| The platform checks the new version's health | ALB target group health check against the new task set | `readinessProbe` against the new ReplicaSet's Pods |
| The new version fails its health check | CodeDeploy's health-check gate fails the deployment (green task set never reaches steady state) | New Pod stays `0/1 READY`; kubelet keeps re-probing forever |
| What happens to traffic | Old task set keeps serving until the new one is healthy or rolled back | Old ReplicaSet's Pods keep serving via the Service the whole time |
| Who un-sticks it | CodeDeploy itself — `DEPLOYMENT_FAILURE` auto-rollback to the previous task definition | Nobody, automatically — `progressDeadlineSeconds` only flips a status condition; a human or GitOps controller must run `kubectl rollout undo` |

## Which failure each mechanism catches

Both mechanisms catch the same *class* of failure: "the new version can't
pass the health check that gates traffic." They differ in what happens
next. Day 3's mechanism (CodeDeploy's health-check gate, not the ECS
deployment circuit breaker — see the table's naming note above) closes the
loop — it detects the failure *and* reverses it, unattended. Kubernetes's
`progressDeadlineSeconds` only detects and reports; the reversal
(`kubectl rollout undo`) is a separate, manual (or GitOps-automated) step.
Neither one protects you from a *silent* correctness bug that still
returns 200 from `/readyz` — that class of failure is what Day 3's
alarm-driven rollback and Day 5's SLOs are for, not this mechanism.

## After `kubectl rollout undo`

```
$ kubectl rollout status deployment/awsdevops-sample
deployment "awsdevops-sample" successfully rolled out

$ kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
awsdevops-sample-6c8b9d7f21-klmno   1/1     Running   0          6m
awsdevops-sample-6c8b9d7f21-zzzzz   1/1     Running   0          10s
```

Back to two `1/1 READY` Pods from the last-known-good ReplicaSet
(`6c8b9d7f21`). `curl localhost:8080/readyz` returns `200 ready` again.

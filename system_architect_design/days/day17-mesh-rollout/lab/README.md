# Day 17 lab — canary via weighted routing (Traefik)

**Goal:** run orders-v1 + orders-v2 behind Traefik with **weighted upstreams
(90/10)**. Drive traffic and confirm ~10% hits v2. Watch v2's error rate. Promote
to 100%. Simulate v2 errors and roll back. **Break-it:** make v2 fail its health
check mid-canary and confirm the router serves 100% v1.

Standalone stack (its own `docker-compose.yml`, not the shared `labs/` stack).

## 0. Bring it up

```bash
cd days/day17-mesh-rollout/lab
chmod +x count-versions.sh
docker compose up -d --build
docker compose ps           # traefik + orders-v1 + orders-v2 running

# sanity: hit each version directly (bypassing the router)
curl -s localhost:8091/orders; echo    # -> orders v1
curl -s localhost:8092/orders; echo    # -> orders v2
# and through the router (weighted):
curl -si localhost:8080/orders | grep -i x-orders-version
```

Dashboard: <http://localhost:8081/dashboard/>. Metrics: <http://localhost:8081/metrics>.

## 1. Build: confirm the 90/10 split

```bash
./count-versions.sh 300
#  -> requests=300  v1≈270 (90%)  v2≈30 (10%)  errors=0
```

You should see roughly 90% v1 / 10% v2. That's the canary receiving a small,
bounded slice of real traffic.

## 2. Measure: watch v2's error rate, then promote

Simulate v2 being subtly worse — inject a 30% error rate into v2 only:

```bash
curl -s -XPOST 'localhost:8092/admin/errors?rate=0.3'   # v2 errRate=0.30
./count-versions.sh 300
#  -> errors ≈ 10% of requests * 30% ≈ ~9 (only the v2 slice errors)
```

**Observe:** at 10% weight, a broken v2 only affects ~10% × its error rate of
traffic — the blast radius is bounded. This is the whole point of the canary.

Now clear the errors and **promote** by editing the weights (Traefik hot-reloads
`traefik-dynamic.yml` on save — no restart):

```bash
curl -s -XPOST 'localhost:8092/admin/errors?rate=0'      # v2 healthy again
# edit traefik-dynamic.yml: set orders-v1 weight: 0, orders-v2 weight: 100
./count-versions.sh 300
#  -> v2 ≈ 100%
```

## 3. Roll back: simulate v2 errors after promotion

```bash
# v2 is now serving 100% and starts failing:
curl -s -XPOST 'localhost:8092/admin/errors?rate=0.5'
./count-versions.sh 200
#  -> errors ≈ 50%  (this is the SLO burn your automated trigger would catch)

# ROLL BACK: edit traefik-dynamic.yml back to v1 weight: 100, v2 weight: 0
./count-versions.sh 200
#  -> v1 ≈ 100%, errors ≈ 0   (recovered by shifting weight, no redeploy)
curl -s -XPOST 'localhost:8092/admin/errors?rate=0'      # reset
```

This is the manual version of the automated rollback. In production you'd have
Argo Rollouts / Flagger (or a Prometheus-watching script) set v2's weight to 0
automatically when `error_rate(v2)` breaches the threshold.

## 4. Break-it (core): v2 fails its health check mid-canary

Set the weights back to **90/10** (edit `traefik-dynamic.yml`), then knock v2's
health check out while traffic flows:

```bash
curl -s -XPOST 'localhost:8092/admin/unhealthy?v=true'   # /health now returns 503
sleep 3                                                   # let Traefik's 2s probe notice
./count-versions.sh 300
#  -> v1 ≈ 100%, v2 ≈ 0, errors ≈ 0
```

**Observe:** even though v2 still has weight 10, Traefik's **active health check**
marks it down and drops it from the weighted pool — the router serves 100% v1.
Weight and health are ANDed. Bring it back:

```bash
curl -s -XPOST 'localhost:8092/admin/unhealthy?v=false'
sleep 3
./count-versions.sh 300     # v2 returns to ~10%
```

> If you swapped in the **nginx** alternative (`nginx.conf`), health is *passive*:
> v2 is only dropped after `max_fails` real requests fail, so you'll see a few
> errors leak before it's ejected — a good contrast with Traefik's active probe.

## 5. AWS alternative (optional, note only)

The same shape on AWS: two target groups (v1, v2) behind one ALB listener rule
with **weighted forward** (`forward` action, `target_group_weight` 90/10). Health
checks on each target group do the eligibility gating. Promote by shifting
weights; CodeDeploy canary configs automate it. Tear down the ALB + target groups
after. (Keep the AWS session to the $1–3 target — see Day 10's teardown discipline.)

## 6. Teardown (mandatory)

```bash
docker compose down -v
```

## What to record in `results.md`
- The measured split at 90/10 (should be ~90/10).
- Error % when v2 has a 30% injected rate at 10% weight (bounded blast radius).
- The promote result (v2 ~100%) and the roll-back result (v1 ~100%, errors ~0).
- Break-it: v1/v2/error counts after v2's health check fails (expect v2 ≈ 0).

> **TODO for you (the one insight to implement):** wire the rollback to be
> *automatic*. Write a small watcher (bash + curl `count-versions.sh`, or a
> Prometheus query against `:8081/metrics`) that flips v2's weight to 0 when
> the v2 error rate exceeds your threshold for N seconds. Define the exact
> metric/threshold/window in your ADR first. Everything else runs as-is.

# Atlas console walkthrough

This is a manual, console-driven walkthrough, not Terraform-managed —
Atlas cluster creation is out of scope for this day's Terraform, and the
brief financial exposure below is small enough that a console click-
through is faster than writing and debugging a provider config for a
resource you tear down again within hours.

**Cost:** an M10 cluster runs roughly $0.08/hr (varies slightly by cloud
provider and region). Left up for the same few hours as the RDS side of
this lab, it costs well under $1; the combined RDS + Atlas $2-5 estimate
in `README.md` assumes both are gone by the end of the day. **Terminate
the cluster the same day** — this is not a "leave it running over the
weekend" resource, unlike the local Docker stack every other day uses.

## 1. Create the M10 cluster

In the Atlas UI, create a new project (or reuse one dedicated to this
course), then create a cluster:

- Tier: **M10** — the smallest tier with Performance Advisor, the
  Profiler, and alerting enabled; the free M0 tier has none of the three.
- Name: **`dbm-lab`** exactly — `labs/verify-teardown.sh` matches on this
  name when it checks for a leftover cluster, and a different name means
  a clean teardown will report a false pass.
- Region: pick one geographically close to you; not load-bearing for
  anything this lab checks, but a nearby region keeps `mongoimport`'s
  latency out of your way while you work.
- Cloud provider: whichever you already use for the RDS side, or either —
  they don't need to match.

Look at: the **cluster tier table** Atlas shows before you confirm — note
that sharding is an option only from **M30 up**. M10 is a plain three-
member replica set, which is why this lab reasons about a shard key
rather than provisioning one; see the note in step 4.

## 2. Database user and IP access list

- **Database Access** → add a database user with a generated password
  (store it the same way you're storing `db_password` for RDS — a
  password manager, never a file in this repository).
- **Network Access** → add your current public IP (`curl -s
  https://checkip.amazonaws.com` gives it to you) as a single-address
  entry. Do not add `0.0.0.0/0` — this cluster does not need to be
  reachable from anywhere but where you're working.

Look at: the **connection string** Atlas gives you once the user and IP
entry exist (Cluster → Connect → Drivers). It has the shape
`mongodb+srv://<user>:<password>@dbm-lab.xxxxx.mongodb.net/`; the
`xxxxx` segment is your cluster's actual assigned hostname, never
predictable in advance, and no example in this file uses a real one.

## 3. Load a subset of `payment_events`

Run this from your own machine (or anywhere with network access to both
Docker and the internet) — it exports a subset from the local stack's
`mongo` service and imports it straight into Atlas, both from inside
`ws`, so no intermediate file leaves the container:

```bash
docker compose -p dbmastery exec ws bash -c '
  mongoexport \
    --uri "mongodb://mongo:27017/payments?replicaSet=rs0" \
    --collection payment_events \
    --sort "{ts:1}" \
    --limit 200000 \
    --out /tmp/payment_events_subset.json \
  && mongoimport \
    --uri "mongodb+srv://<user>:<password>@dbm-lab.xxxxx.mongodb.net/payments?retryWrites=true&w=majority" \
    --collection payment_events \
    --file /tmp/payment_events_subset.json
'
```

Replace `<user>`, `<password>`, and the `dbm-lab.xxxxx.mongodb.net` host
with your own values from step 2 — none of the three are real above, on
purpose. `--sort "{ts:1}"` keeps the subset's monotonic ordering intact,
which matters for step 4: a subset that happened to be shuffled would no
longer demonstrate the property you're about to reason about.

Look at: the `mongoimport` summary line (`imported N documents`) — confirm
it reports 200,000, not a partial count from a dropped connection partway
through.

## 4. The monotonic index, and why this lab does not actually shard

Create the index a shard key on `ts` would be backed by:

```javascript
// against the Atlas cluster, e.g. via mongosh using the same
// mongodb+srv connection string from step 3
db.payment_events.createIndex({ ts: 1 })
```

Atlas does not offer sharding below M30 — there is no "shard this
collection" button to click on an M10 cluster at all, and provisioning an
M30 only to watch one collection develop a hot chunk would roughly triple
this day's cost for a demonstration this lab gets equally honestly from
reasoning. So: do not upgrade the tier. Instead, use the index you built
above plus `explain()` on a few inserts and range queries to reason about
what `sh.shardCollection("payments.payment_events", { ts: 1 })` would do
if it existed here — every new document's `ts` is higher than every
previous one, so a real deployment sharded on it would route 100% of
insert traffic to whichever chunk currently owns the high end of the `ts`
range, regardless of how many distinct `ts` values exist. That reasoning,
written up, is `hot_shard_reason` in `/tmp/answer` — see
`labs/day07/README.md`.

## 5. Enable the Profiler

Cluster page → **Profiler** tab (under the cluster's monitoring section,
alongside Metrics and Real Time). Enable it — Atlas's Profiler is a
per-cluster toggle in the console, not a `db.setProfilingLevel()` call you
run yourself, though the effect is the same idea as the local stack's own
`slowms=100`, profiler level 1 you've been running against `mongo` all
week. Run a handful of queries against `payment_events` (a `find()` by
`merchant_id`, a range query on `ts`) so the Profiler has something to
show, then look at: the **slow query list** it produces, and whether the
queries you ran a moment ago appear with the operation shape you expect.

## 6. Performance Advisor

Cluster page → **Performance Advisor** tab. It reads the same slow-
operation data the Profiler recorded and suggests indexes. Look at:
whether it suggests anything involving `ts` or `merchant_id` — treat its
suggestion as a second opinion to weigh against your own `explain()`-based
shard-key reasoning from step 4, not a replacement for having done that
reasoning yourself.

## When you're done

Go straight to `labs/day07/teardown.md`. Terminating this cluster is not
optional cleanup — it is a real, metered resource, and it is the one half
of this lab's cost `labs/verify-teardown.sh` cannot check for you unless
the Atlas CLI is installed and configured (its Atlas-cluster check is
skipped, not failed, when the CLI is absent — see that script's own
comments).

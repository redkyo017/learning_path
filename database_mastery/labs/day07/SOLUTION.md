# Day 7 — solution

Read this only after your own attempt, or after `verify.sh` has forced a
specific question you can't otherwise answer. This mirrors the chain
template in `journal.md`, adapted the way Day 1's and Day 2's `SOLUTION.md`
already were: Day 7 measures a real managed system and reasons about a
scenario it deliberately does not provision (see step 4 below), rather
than diagnosing an injected pathology, so "Fix applied" describes what the
Multi-AZ mechanism itself did, not a repair you performed.

### Day 7 — a forced failover, a wait-event histogram, and a shard key that never gets a second chance

**Predictions (written before running anything):**
- Failover duration: predicted 45 seconds — assumed "failover" meant a
  fast promotion with no meaningful DNS propagation delay.
- What happens to an open connection and an in-flight transaction:
  predicted "the connection pauses, then resumes once the standby takes
  over" — assumed TCP sessions could survive a promotion the way a load
  balancer's connection draining might let a request finish.
- Top `pgbench` wait event: predicted `CPU` — assumed a `db.t4g.micro`
  under any real load would be undersized on compute first, above all else.

**Symptom (verbatim, no interpretation):**
`aws rds reboot-db-instance --db-instance-identifier dbm-lab-pg
--force-failover`, timed from issue to the endpoint accepting connections
again, reports 92 seconds. The `psql` session held open across that window
reports `server closed the connection unexpectedly` the moment the
transaction on it tries to commit. Performance Insights' `DBLoad` panel
for the `pgbench` run shows `Lock:transactionid` as the largest wait-event
band, well above `CPU`.

**Layer:** distribution

**Chain of evidence:**

1. Claim: the failover's 92 seconds is dominated by promotion and DNS
   propagation, not by anything an application could shorten. | Proof:
   `aws rds describe-events --source-identifier dbm-lab-pg
   --source-type db-instance` lists, in order, "Multi-AZ instance failover
   started," "Multi-AZ instance failover to instance dbm-lab-pg-standby
   completed," each timestamped a bit under 90 seconds apart — the gap
   between the two events, not any client-side retry loop, accounts for
   almost the entire measured duration.
2. Claim: the dropped connection is not a bug in the driver or in `psql`
   — the old primary's TCP session cannot be handed to a different host,
   because a TCP connection is bound to one IP and port pair, and the
   promoted standby is a different instance entirely. | Proof: the held
   `psql` session's error (`server closed the connection unexpectedly`)
   arrives at the same moment `describe-events` timestamps the failover
   as starting, not at some later point — the session died the instant
   the original primary stopped being the endpoint's target, not because
   of a timeout on the client side.
3. Claim: the in-flight transaction on that session was never committed,
   so nothing was lost by its disappearing — it was never durable in the
   first place. | Proof: `SELECT count(*) FROM pgbench_history WHERE
   ...` (a row that transaction would have inserted) after reconnecting
   shows the row absent; a second, already-committed transaction run
   moments before the failover shows its row present — confirming the
   Multi-AZ standby's synchronous replication had that earlier commit,
   and the only thing missing is exactly the one transaction that never
   finished.
4. Claim: `Lock:transactionid` dominating over `CPU` means the bottleneck
   is row-lock contention, not raw compute, and default `pgbench`'s own
   schema is why. | Proof: default `pgbench -i` builds `pgbench_branches`
   with one row per `-s` scale-factor unit — at `-s 10`, ten branch rows —
   while `-c 20` runs twenty concurrent clients, each of whose transaction
   updates one `pgbench_branches` row chosen at random; with twenty
   clients contending over ten rows, multiple clients routinely want the
   same branch row's exclusive lock at once, which Performance Insights
   attributes to `Lock:transactionid` while the process is blocked, not to
   `CPU`, which only counts time actually executing.
5. Claim: `top_wait_event` genuinely could differ across two runs of this
   same lab and both still be correct — this is the honest limitation
   `README.md` states, not a hedge. | Proof: a rerun with `-s 50` instead
   of `-s 10` (fifty branch rows instead of ten, same twenty clients)
   measurably lowers `Lock:transactionid`'s share of `DBLoad` and raises
   `IO:DataFileRead`'s, because contention eases once there are more
   distinct rows to spread twenty clients across, and the workload becomes
   more genuinely I/O-bound on a `db.t4g.micro`'s small, memory-starved
   buffer cache instead.

**Diagnosis:** the 92-second failover is the DNS-swap-plus-promotion
window RDS Multi-AZ actually takes, not something a faster driver could
shorten — `content/day07.md`'s Core concepts section names the typical
60-120 second range this falls inside. The dropped connection and lost
in-flight transaction are the correct, expected behavior of a
synchronous-standby failover: every *committed* transaction survives
because the standby had already acknowledged it before commit returned to
the client, and every *uncommitted* one is discarded because it was never
durable to begin with — this is ACID's Durability guarantee working
exactly as specified, not a gap in it. `Lock:transactionid` beating `CPU`
is default `pgbench`'s own well-known contention artifact at a small scale
factor with many concurrent clients, not evidence the instance is
undersized on compute — a genuinely CPU-bound reading would need a larger
scale factor to remove the row-lock bottleneck first.

**Fix applied:** Not a fix in the diagnostic-lab sense — nothing was
broken to repair. The corrective action this evidence chain sets up is
configuration, not repair: the connection pool the application uses in
front of an RDS Multi-AZ instance needs a bounded connection lifetime and
validate-before-use checked out, specifically so it re-resolves DNS and
discards a connection to a now-defunct primary within seconds of a
failover, instead of retrying a dead endpoint until some longer, unrelated
timeout finally gives up.

**Proof the fix worked (same instrument re-read):** Not applicable in the
usual sense — there is no before/after pair to compare on the failover
itself. The equivalent proof, if you configure a pool this way, is
watching the pool's own connection-error and reconnect counters during a
second forced failover and confirming they show a brief, bounded spike
rather than sustained failures past the DNS record's TTL.

**Prediction error and what it tells me:** The 45-second failover
prediction missed by roughly a factor of two against the measured 92
seconds — the model behind it had no real basis for "45," only an
assumption that promotion itself is instantaneous once RDS decides to do
it, with no accounting for DNS propagation as a separate, non-negotiable
step. The "pauses, then resumes" prediction for the open connection was
wrong in kind, not degree: a TCP connection cannot migrate between two
different physical hosts no matter how briefly, so "it pauses" was never
on the table as an outcome — the actual behavior (a hard connection
failure) was not a slower version of what was predicted, it was a
different category of event entirely. The `CPU`-as-top-wait-event
prediction reflected a reasonable instinct (a t4g.micro is small) applied
to the wrong bottleneck — default `pgbench`'s own tiny branch-table
cardinality creates lock contention long before compute becomes the
limit, a workload-shape fact no amount of reasoning about instance size
alone would surface.

**What I would check first next time:** For any Multi-AZ failover
question, start from `aws rds describe-events`, not a stopwatch on the
client — it gives the actual state-transition timestamps AWS recorded,
which is a cleaner instrument than timing a retry loop's success. For any
`pgbench` wait-event question, check the scale factor against the client
count before trusting a wait-event reading as "the instance's real
bottleneck" — a small scale factor with many clients manufactures lock
contention as an artifact of the benchmark's own default schema, not of
the hardware underneath it.

---

### The shard-key argument in full

`hot_shard_reason` asks for the mechanism, not a verdict, so here it is
stated completely: a MongoDB shard key partitions a collection into
chunks, each chunk owning a contiguous range of the key's values, and the
balancer's job is to keep chunks evenly distributed across shards by
splitting and migrating them as data grows. That job depends on chunks
actually being splittable across a range of *currently active* write
traffic — a chunk that owns values nobody is inserting into any more is
cheap to leave wherever it sits. `payment_events.ts` violates the one
assumption that job needs: it increases monotonically across the entire
load, so at any moment, the only chunk receiving inserts is the one that
owns the highest end of the current `ts` range — every other chunk, no
matter how many there are or how evenly they're currently balanced, is
receiving zero write traffic. The balancer can migrate that hot chunk to
an empty shard, but the next chunk split immediately produces a new
highest-range chunk, which immediately becomes the new sole target of 100%
of insert traffic. This repeats forever, because nothing about the shard
key ever generates a new insert into an *old* range — a payment event from
last week doesn't get inserted this week. High cardinality genuinely
predicts how many distinct chunks the range *could* eventually be split
into; it says nothing about whether writes will actually spread across
those chunks once they exist, and for a monotonic key, they never do. The
fix is not "add more shards" — it's changing the key so that the field
determining chunk ownership is one where old values keep receiving new
writes too (a hashed key, or a compound key led by a field like
`merchant_id` that isn't strictly increasing), which is exactly what
`content/day07.md`'s exercise 3 asks you to design.

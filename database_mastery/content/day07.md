# Day 7 — Distribution, and the Managed Cloud

**Layer:** distribution
**Budget:** 3 h — 1.5 h concepts, 1.5 h cloud lab

## Why this matters

Every other day in this path runs against a single container you can kill
and reseed for free. Today runs against a real RDS instance and a real
Atlas cluster, because the concepts underneath them — physical versus
logical replication, quorum, shard-key monotonicity, what a wait-event
histogram actually counts — do not exist in a form you can observe
honestly on a single local node. A single-node PostgreSQL container has no
standby to lag behind, and a single-member `rs0` replica set never has to
choose a read preference. The console screens you already look at during
an on-call rotation — Performance Insights, CloudWatch, Atlas's Profiler
and Performance Advisor — are renderings of exactly the mechanisms this
day names, and the rendering only makes sense once you've read the
mechanism underneath it directly.

This is also the only day with a cost, and the only day `verify.sh` cannot
grade against a computed truth: the numbers you produce today live in your
own AWS and Atlas accounts, and vary with region, instance class, and the
moment you happened to run the load. Read the honest-limitation section in
`labs/day07/README.md` before you assume today's lab checks what every
other day's `verify.sh` checked.

## Read the instrument first

Before "physical replication" or "replica set" is defined, read what each
engine actually reports about its own replication state — and, equally
important, what it reports nothing about at all.

Run `SELECT * FROM pg_stat_replication;` against the classic Multi-AZ
instance this lab's own `terraform/rds.tf` provisions (`multi_az = true`,
no read replica) and it comes back **empty. Zero rows.** That is not a
misconfiguration to chase down — classic RDS Multi-AZ replicates to its
standby below the PostgreSQL layer entirely, at the block-storage level,
using a mechanism with no `walreceiver` process, no WAL streaming
protocol, and therefore nothing for `pg_stat_replication` to have a row
about. The standby is completely real and completely synchronous — that
part of the "Synchronous versus asynchronous" concept below is accurate
and load-bearing — it is invisible to this particular view, not absent. Only a
genuine streaming replica populates `pg_stat_replication`: an RDS **read
replica**, or the newer Multi-AZ *DB cluster* deployment (two readable
standbys, a different feature from the single-standby Multi-AZ this lab
uses). Here is that raw shape, illustrated from a read replica, the
instrument this lab's own instance genuinely cannot show you:

```
payments=# SELECT usename, application_name, client_addr, state,
  sent_lsn, write_lsn, flush_lsn, replay_lsn,
  write_lag, flush_lag, replay_lag, sync_state
  FROM pg_stat_replication;
-[ RECORD 1 ]----+------------------------------
usename          | rdsrepladmin
application_name | walreceiver
client_addr      | 10.0.4.87
state            | streaming
sent_lsn         | 4A/DE102F30
write_lsn        | 4A/DE0FF110
flush_lsn        | 4A/DE0FE9A0
replay_lsn       | 4A/DE0F8C40
write_lag        | 00:00:00.412009
flush_lag        | 00:00:00.803557
replay_lag       | 00:00:02.518344
sync_state       | async
```

Nothing here has been named yet, but the shape already tells you
something: four different LSN columns, three different lag intervals, all
noticeably larger than a synchronous standby's would be, and a
`sync_state` value of `async` — worth holding next to the fact that the
Multi-AZ standby backing this exact lab's instance is synchronous and
still produces no row here at all. Core concepts below explains every one
of those fields, and exactly which replication topologies do and do not
populate this view — knowing which durability guarantee your instruments
can and cannot see is the actual point of reading this raw output first,
not a footnote to it.

Second, a MongoDB replica set's own view of itself:

```
rs0 [direct: primary] payments> rs.status()
{
  set: 'rs0',
  myState: 1,
  members: [
    {
      _id: 0,
      name: 'dbm-lab-shard-00-00.abcde.mongodb.net:27017',
      health: 1,
      state: 1,
      stateStr: 'PRIMARY',
      uptime: 41822,
      optime: { ts: Timestamp({ t: 1737310042, i: 3 }), t: 14 },
      optimeDate: ISODate('2026-09-07T10:27:22.000Z')
    },
    {
      _id: 1,
      name: 'dbm-lab-shard-00-01.abcde.mongodb.net:27017',
      health: 1,
      state: 2,
      stateStr: 'SECONDARY',
      uptime: 41819,
      optime: { ts: Timestamp({ t: 1737310041, i: 1 }), t: 14 },
      optimeDate: ISODate('2026-09-07T10:27:21.000Z'),
      syncSourceHost: 'dbm-lab-shard-00-00.abcde.mongodb.net:27017'
    },
    {
      _id: 2,
      name: 'dbm-lab-shard-00-02.abcde.mongodb.net:27017',
      health: 1,
      state: 2,
      stateStr: 'SECONDARY',
      uptime: 41819,
      optime: { ts: Timestamp({ t: 1737310040, i: 9 }), t: 14 },
      optimeDate: ISODate('2026-09-07T10:27:20.000Z'),
      syncSourceHost: 'dbm-lab-shard-00-00.abcde.mongodb.net:27017'
    }
  ]
}
```

This is the three-member shape an Atlas M10 cluster actually runs — richer
than the single-member `rs0` you've been running against all week, where
`rs.status()` always reports exactly one member in `PRIMARY` state with
nothing to sync from. `optime` is the same idea as PostgreSQL's LSNs above:
a position in each member's oplog, and the gap between the primary's
`optime` and a secondary's is MongoDB's replication lag, measured the same
way PostgreSQL's `replay_lag` is — by comparing positions, not by trusting
a label.

## Core concepts

**Physical versus logical replication — what each can and cannot do.**
Physical replication (PostgreSQL's own WAL streaming protocol, the
mechanism under an RDS read replica and under a self-managed standby;
MongoDB's oplog replication between replica-set members is the same idea
under a different name) ships the actual bytes of change — WAL records,
oplog entries — and applies them in the exact physical order they
occurred. Classic RDS Multi-AZ's standby is physically replicated too, in
the sense that it is a byte-for-byte copy kept current by shipping
changes rather than by re-deriving them, but AWS implements that specific
copy at the block-storage layer, underneath PostgreSQL's own replication
protocol entirely — which is exactly why it produces no row in
`pg_stat_replication` above, unlike a read replica, which does use the
protocol this paragraph describes. A physical replica is a
byte-for-byte copy of the primary's data files, always the same major
version, always the same schema, and it can serve reads but cannot
transform the data in flight. Logical replication (PostgreSQL's
`CREATE PUBLICATION`/`CREATE SUBSCRIPTION`, decoding WAL back into a
stream of row-level `INSERT`/`UPDATE`/`DELETE` operations) ships a
higher-level description of the change instead of the bytes, which buys
things physical replication cannot do at all: replicating a subset of
tables, replicating into a different major version, replicating into a
schema with extra columns or a different index set, or fanning one
publisher out to subscribers doing entirely different things with the
same stream. The cost is that logical replication has no equivalent for
DDL (schema changes need a separate mechanism) and starts from a
snapshot, not from an empty target, when you first bring a subscriber up.

**Synchronous versus asynchronous — the latency each buys or costs.**
`sync_state = async`, in the read-replica row above, means the primary
commits and acknowledges the client immediately and ships WAL to that
replica on its own schedule — faster commits, at the cost of a replica
that is always at least slightly behind and can lose the tail of
unshipped WAL if the primary dies before shipping it. `sync_state = sync`
(what a manually configured synchronous streaming replica would show,
listed as its own row in this same view, if one existed) means the
primary will not report a transaction as committed to the client until
that standby has *at least* written — not necessarily applied — the WAL
for it. Classic RDS Multi-AZ's standby is synchronous in exactly this
sense, but enforces it at the block-storage layer below PostgreSQL
entirely, which is the mechanism behind the empty result "Read the
instrument first" opened with: there is no WAL streaming connection to
show a `sync_state` for, sync or async, because the replication protocol
this view reports on is not the one Multi-AZ uses at all. The durability
outcome — zero committed transactions lost on a promoted Multi-AZ
failover — is real and is this lab's own failover exercise; the row that
would explain the mechanism by name is not available to read, on this
instance, in this view. Whichever mechanism is in play, the underlying
trade-off is the same, and there is no configuration that gets both zero
latency cost and zero data-loss risk: every synchronous-versus-
asynchronous choice spends one against the other, never neither.
MongoDB's write concern (below) is the same trade-off stated per write
instead of per replica.

**What actually causes replication lag, and how to measure it rather than
guess.** Four real causes, in the order worth checking: (1) A long-running
transaction on the primary doesn't directly slow WAL shipping, but it does
hold back the row versions autovacuum can reclaim, which grows the WAL
volume behind it and, on a busy system, backs up everything downstream.
(2) A conflicting query on the replica — a long-running read that a
`VACUUM` on the primary needs to remove row versions the replica's
snapshot still needs — forces the replica to choose between canceling the
query (`hot_standby_feedback` off) or pausing WAL replay until the query
finishes (`hot_standby_feedback` on), and either choice shows up as lag
from a query, not from the network. (3) WAL replay on a standby is a
single process — one CPU core, full stop, regardless of how many cores the
instance has — so a write-heavy primary can generate WAL faster than one
core can replay it, and no amount of standby CPU headroom fixes that.
Logical replication's parallel apply (PostgreSQL 16+) relaxes this for a
subset of workloads, but plain physical replay never does. (4) Network
bandwidth or latency between AZs or regions, which is the cause everyone
assumes first and is, in practice, the least common of the four on a
same-region Multi-AZ pair. Measure lag from the instrument, not the
label: `pg_wal_lsn_diff(sent_lsn, replay_lsn)` on the primary gives bytes
of WAL generated but not yet replayed — a real backlog size, immune to
clock skew between primary and replica — while `replay_lag` gives a wall-
clock interval that depends on the replica's feedback message arriving on
time and can go stale or blank under load. Exercise 1 below asks you to
compute the byte-based version yourself, not read the interval column and
call it done.

**The read-your-writes hazard.** An application that writes to the primary
and immediately reads from a replica is not "eventually consistent" — that
phrase describes a system that is guaranteed to converge, given enough
time, with no promise about what any single read sees before it does. What
that application actually has is a race: read fast enough after the write
and you get the stale value, wait long enough and you get the fresh one,
with no way to tell from inside a single request which one you got.
"Eventually consistent" undersells this by making it sound smooth and bounded, when the observed behavior is a coin flip that looks like a bug in
whatever workflow depends on reading back what it wrote a moment earlier (an order
confirmation page, a "your payment is now captured" screen). The fix is a
routing decision — read your own writes from the primary, or track a
causal token and route the read to a replica proven to have caught up to
it (MongoDB's causal consistency, below, is exactly this token) — never a
database setting, because no setting on the replica side can retroactively
make a write arrive faster than the replication stream carries it.

**Failover semantics — what is actually lost.** When RDS Multi-AZ fails
over — the primary AZ has a problem, or you force it with `aws rds
reboot-db-instance --force-failover` — three things happen, and the
distinction between them is the whole lesson: RDS promotes the synchronous
standby, which (because it was synchronous) holds every transaction the
primary had committed, so **no committed transaction is lost**. Any
transaction that was in flight and had not committed at the moment of
failure is gone outright — there is nothing to lose, because it was never
durable in the first place, which is exactly what "committed" is supposed
to mean. And every existing client connection is dropped: the old primary
either failed outright or is being demoted, and the new primary does not
inherit its TCP sessions. RDS's mechanism for redirecting new connections
is a DNS change — the instance's endpoint CNAME is repointed at the new
primary's address, with a short TTL (typically a few seconds) specifically
so a client that re-resolves promptly finds the new address fast. That
detail is why a naive connection pool makes failover look far worse than
it is: a pool that resolved the endpoint once at startup and holds
long-lived connections (or worse, caches the resolved IP at the JVM or OS
level past the DNS record's TTL) keeps retrying the address of an instance
that no longer answers as primary, and only recovers once something in the
pool notices the connection error and forces a fresh DNS lookup. Configure
the pool to validate connections before reuse and to cap connection
lifetime below what you're willing to wait during a failover — that is the
actual fix, not a database-side setting, because the database side already
did its job in the 60–120 seconds the DNS swap and promotion typically
take.

**Partitioning.** Declarative range partitioning splits one logical table
into several physical ones, each owning a disjoint range of a partition
key — `payments.created_at` in the monthly case. The planner's partition
pruning is the payoff: a query with a `WHERE created_at >= '2026-08-01'`
predicate never opens the partitions for July or earlier at all, visible
directly in `EXPLAIN` as partitions absent from the plan entirely, rather
than scanned and discarded. A join between two tables partitioned the same
way (partition-wise join) lets the planner join matching partition pairs
independently instead of one giant join across the whole unpartitioned
data — real parallelism, not merely pruning. None of this is free
maintenance: partitions do not create themselves ahead of the data that
needs them (a missing future partition is a hard insert failure, not a
slow one), and a retention policy described as "detaches old partitions" is a
scheduled job you have to build and monitor like any other, not a
built-in feature of declaring the table partitioned in the first place.

**MongoDB sharding, and the monotonic shard key as the worked failure.**
Choosing a shard key means choosing, once, and expensively-to-change-later,
the field a balancer will use to decide which shard owns which document.
Three properties matter, and only one of them is what most people check:
cardinality (how many distinct values exist — too few, and some shard
inevitably owns a value shared by a disproportionate slice of the
collection, an unsplittable **jumbo chunk**), frequency (how evenly
documents are spread across the values that do exist — high cardinality
with a power-law-skewed frequency, like `merchant_id` in this schema's own
`payments`, still concentrates a jumbo chunk on whichever few values are
hot), and monotonicity, which this dataset's `payment_events.ts` exists to
demonstrate. `ts` increases across the *entire* load, not merely within a
batch, and it has enormous cardinality — millions of distinct values. Shard
on it anyway and every single insert, for the entire life of the
collection, carries a `ts` value higher than every value already written,
which means every insert routes to whichever chunk currently owns the
high end of the range — one chunk, therefore one shard, forever, no matter
how the balancer tries to redistribute existing chunks. High cardinality
does not save a monotonic key: cardinality only bounds how finely a range
*could* be split, and a shard key that never revisits an old range never
benefits from that fineness, because 100% of write traffic always lands
in the newest, still-growing chunk. This is mistake #11 in `STRATEGY.md`'s
list for a reason — cardinality is the property every tutorial leads with,
and it is necessary, not sufficient.

**CAP and PACELC as engineering trade-offs, not slogans.** CAP says: under
a network partition, choose availability (serve reads/writes with
possibly-stale or possibly-conflicting data) or consistency (refuse
requests you can't currently prove are safe) — you cannot have both during
the partition. PACELC adds the clause CAP leaves silent: **E**lse, when
there is no partition, you are still trading **L**atency against
**C**onsistency, because a synchronous acknowledgment from a quorum of
replicas costs a round trip even on a perfectly healthy network. RDS
Multi-AZ's synchronous standby write and MongoDB's `w: majority` write
concern are both PE/LC choices under this framework — they spend latency
on every write, healthy network or not, to buy the durability guarantee.
A **quorum** read or write requires acknowledgment from a majority of
replica-set members rather than only the primary — `w: "majority"` on a
write, `readConcern: "majority"` on a read — which is what makes a
majority-committed write survive an election, at the cost of the extra
round trip PACELC already named. MongoDB's causal consistency (a driver
session tracks the last operation time it has seen and a subsequent read
on that session waits, if necessary, until the node it's routed to has
caught up to that time) is the actual mechanism that fixes the read-your-
writes hazard above — not "eventual consistency getting better with time,"
a specific, bounded wait tied to a specific prior write.

**Managed reality: what the console is actually showing you.** RDS
parameter groups hold every tunable, but not every parameter in a
parameter group is actually changeable by you: a parameter's `Modifiable`
column in the console (or `IsModifiable` from `describe-parameters`) says
whether AWS lets a customer touch it at all, and even a modifiable
parameter can be static (change takes effect only after a reboot — nearly
always true of anything that sizes shared memory at postmaster start, like
`shared_preload_libraries`) or dynamic (applies immediately or at the next
session). Performance Insights' central object is the wait event: every
active-session sample is bucketed either as `CPU` (actually running) or as
waiting on one of a fixed vocabulary of named events (`IO:DataFileRead`,
`Lock:transactionid`, `LWLock:BufferMapping`, `Client:ClientRead`, and
others) — `DBLoad` is the average number of active sessions in any given
second, stacked by wait event, which is the one chart that tells you
whether an instance is CPU-bound, I/O-bound, or lock-bound without reading
a single log line. Enhanced Monitoring and CloudWatch look at the same
instance from different vantage points: CloudWatch's metrics come from
the hypervisor, at up to one-minute granularity by default, and cannot see
inside the guest OS at all; Enhanced Monitoring runs an agent inside the
instance itself and reports real OS-level detail — per-process CPU, actual
free versus cached memory, per-disk I/O — at up to one-second granularity,
which is the only place `FreeableMemory` (CloudWatch) and genuine OS
memory pressure can be told apart, since `FreeableMemory` counts memory
the OS could reclaim, including page cache it is currently using
productively. `ReadIOPS` and `BurstBalance` matter together, not
separately: `gp3`/`gp2` volumes below a size threshold earn I/O credits
they spend during bursts, and `BurstBalance` heading toward zero while
`ReadIOPS` stays flat is not a stable state — it is a countdown to the
same workload suddenly running at baseline IOPS instead of burst IOPS,
which reads, from the application, exactly like an unexplained cliff.
`ReplicaLag` is CloudWatch's own name for what `pg_stat_replication`
computes directly on the instance — trust the direct read on the box
during an incident; the CloudWatch metric aggregates and delays.

**Atlas: the same reflex, different console.** The Profiler records slow
operations (mirroring `system.profile` and `slowms`, which the local
stack already runs at) without you connecting a shell at all. Performance
Advisor reads the Profiler's own data to suggest indexes — treat its
suggestions as a second opinion to check against your own `explain()`
reading, not a replacement for it. Alerts on host and replica-set metrics
(replication lag, connections, disk usage) are the Atlas equivalent of a
CloudWatch alarm, and configuring at least one before you generate load is
the same discipline as checking a catalog before trusting a dashboard —
`STRATEGY.md`'s mistake #12, restated for a managed control plane instead
of a self-hosted one.

## Predict before you measure

Write these in `journal.md`, with your one-sentence reasoning for each,
before you touch the console or run a single command:

1. How many seconds a Multi-AZ failover you force yourself will actually
   take, start (you issue the failover) to finish (the endpoint resolves
   to, and accepts connections against, the new primary).
2. What happens to a connection your `ws` container holds open across
   that failover, and to a transaction that is mid-flight on it at the
   moment failover begins.
3. The single wait event Performance Insights will report as the largest
   contributor to `DBLoad` under a default `pgbench` run against the
   `db.t4g.micro` instance.

## Lab

`labs/day07/README.md` has the full instructions, and `labs/day07/
atlas-setup.md` walks the Atlas console side in detail. In outline: apply
the Terraform in `labs/day07/terraform/` to stand up one `db.t4g.micro`
Multi-AZ PostgreSQL instance, force a failover against it and time it,
`pgbench` it and read Performance Insights' top wait event, then follow
`atlas-setup.md` to bring up an M10 Atlas cluster, load a subset of
`payment_events` into it, and reason about — rather than actually
provision — a shard key on its monotonic `ts` field (Atlas sharding starts
at M30, well outside this day's budget; the lesson is in the reasoning,
which `hot_shard_reason` below captures, not in watching a live chunk
migration). Three deliverables, written to `/tmp/answer` inside `ws`:
`failover_seconds`, `top_wait_event`, `hot_shard_reason`. Tear everything
down the same day — `labs/day07/teardown.md` is not optional reading here
the way it is on other days.

## Exercises

1. Compute replication lag from `pg_stat_replication`'s byte positions
   rather than its time column. This is a reasoning exercise against the
   read-replica shape shown in "Read the instrument first" — this lab's
   own Multi-AZ instance has no row in this view at all, per that
   section, so there is nothing to query on `dbm-lab-pg` itself for this
   one.

   **Hint:** `pg_wal_lsn_diff(sent_lsn, replay_lsn)` gives you a byte
   count directly; the interval columns depend on standby feedback timing
   in a way the byte count does not.
   **Solution sketch:** `SELECT pg_wal_lsn_diff(sent_lsn, replay_lsn) AS
   bytes_behind FROM pg_stat_replication;` reports the volume of WAL
   generated on the primary but not yet replayed on the standby. Divide
   that by a measured WAL-generation rate (`pg_current_wal_lsn()` sampled
   twice, a known interval apart, gives bytes/second) to get an
   *estimated* time-behind — an estimate, not a direct read, and worth
   comparing against `replay_lag` on the same row to see how far the two
   methods agree.

2. Design a partition scheme for `payments` with a stated retention
   policy.

   **Hint:** the partition key has to be a column every query's `WHERE`
   clause can realistically constrain, or pruning never triggers.
   **Solution sketch:** `PARTITION BY RANGE (created_at)`, one partition
   per month, with a retention policy of "detach and archive any partition
   whose upper bound is more than 13 months old" — implemented as a
   monthly job that both creates next month's partition ahead of time
   (never on demand, since a missing partition is an insert failure) and
   detaches the oldest one, rather than deleting rows out of a live
   partition.

3. Pick a shard key for `payment_events` that avoids the hot-shard failure
   and defend it.

   **Hint:** a compound key that puts a low-monotonicity, higher-frequency
   field first and the monotonic timestamp second gets you range queries
   on the timestamp without concentrating writes on one value of the
   leading field.
   **Solution sketch:** `{merchant_id: 1, ts: 1}` (or a hashed
   `merchant_id`) spreads inserts across however many distinct
   `merchant_id` values are actively writing at once, instead of all
   inserts sharing one ever-increasing `ts`. This schema's own power-law
   skew on `merchant_id` means the defense isn't complete — a few
   merchants still write disproportionately — but it is no longer a single
   point, and `ts` as the second key still supports efficient range scans
   within a merchant's own event history.

4. Explain what `readConcern: "majority"` costs.

   **Hint:** a majority read has to know a majority of nodes have
   acknowledged the data it's about to return, which is not free
   information the primary already has cached.
   **Solution sketch:** it costs latency, not availability, under PACELC's
   "else" clause — the primary can only return data as majority-committed
   once it has confirmation a majority of the replica set has replicated
   it, so a majority read waits for whatever that confirmation's own lag
   is, and during an election or a slow replica it can wait meaningfully
   longer than a local read of the primary's most recent (not yet
   majority-acknowledged) state would.

5. Identify which of five RDS parameters are modifiable and which are
   locked: `shared_preload_libraries`, `log_min_duration_statement`,
   `max_connections`, `wal_level`, `shared_buffers`.

   **Hint:** the ones AWS itself uses to guarantee Multi-AZ and backup
   behavior are the ones you cannot touch; check each one's `Modifiable`
   column in the parameter group console or `describe-parameters` rather
   than guessing from the name.
   **Solution sketch:** `log_min_duration_statement` and `max_connections`
   are modifiable (the latter through the DB instance class's formula
   unless overridden). `shared_preload_libraries` is modifiable but
   static — it takes a reboot. `wal_level` and `shared_buffers` are locked
   on RDS: `wal_level` is fixed by RDS at whatever its replication and
   backup mechanism requires, and `shared_buffers` is computed by RDS from
   the instance class and is not exposed as a settable parameter at all.

6. Interpret a `BurstBalance` graph that is heading toward zero.

   **Hint:** a straight-line decline is a countdown, not noise — read the
   slope, not only the current value.
   **Solution sketch:** the volume is spending I/O credits faster than it
   earns them at its baseline rate; extrapolate the slope to find roughly
   when it hits zero, and treat that time as the moment `ReadIOPS`/
   `WriteIOPS` will be clamped to the volume's baseline rate regardless of
   demand — the fix is a bigger volume (raises the baseline) or lower
   sustained IOPS demand, not waiting to see what happens, since what
   happens is a sudden, predictable throughput cliff at a known time.

## Anti-patterns / common mistakes

- Choosing a shard key by cardinality alone, and stopping there. `ts` in
  this schema's own dataset has excellent cardinality and is still the
  worst possible shard key, because monotonicity routes every write to one
  chunk regardless of how many distinct values exist behind it.
- Treating a read replica as a consistent read source for anything the
  same request wrote moments earlier. A replica is a valid target for load you can
  tolerate being stale; it is never a substitute for read-your-writes,
  which is a routing problem, not a replica-configuration problem.
- Sizing an RDS instance from CPU utilization alone. A `db.t4g.micro` can
  show comfortable CPU headroom right up until `BurstBalance` hits zero or
  storage IOPS saturate, at which point the same CPU-bound-looking
  workload falls off a cliff that CPU graphs never showed coming.

## Teardown

See `labs/day07/teardown.md`. This is the only day in this path with a
real financial consequence for skipping it — do not leave it for later.

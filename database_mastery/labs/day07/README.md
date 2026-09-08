# Day 7 lab — distribution, and the managed cloud

## Cost, up front

This lab spends real money in your own AWS and MongoDB Atlas accounts —
the only day in this path that does. Expect **$2-5** total if you tear
down the same day: a `db.t4g.micro` Multi-AZ RDS instance runs roughly
$0.07-0.09/hr (see the cost comment at the top of `terraform/rds.tf`), and
an Atlas M10 cluster runs roughly $0.08/hr (see `atlas-setup.md`). Leave
either one running for more than a day and these estimates stop holding.
Read `teardown.md` before you start, not after — you will run it the same
day you run this lab, not "eventually."

## Goal

Three deliverables, all required, written to `/tmp/answer` inside `ws`:

```
failover_seconds=<how long your forced Multi-AZ failover took, in seconds>
top_wait_event=<the top Performance Insights wait event under your pgbench run>
hot_shard_reason=<why a monotonic shard key on payment_events.ts is a hot-shard failure>
```

## How to run

1. **Predict first.** Write your answers to `content/day07.md`'s "Predict
   before you measure" section in `journal.md`, with one-sentence
   reasoning for each, before you provision anything.

2. **Stand up the RDS instance.**

   ```bash
   cd labs/day07/terraform
   cp terraform.tfvars.example terraform.tfvars
   # edit terraform.tfvars: real region, a generated db_password, your
   # own /32 in my_ip_cidr
   git check-ignore -v terraform.tfvars   # confirm the ignore rule below actually matches before you go further
   terraform init
   terraform apply
   ```

   `terraform.tfvars`, `terraform.tfstate`, `terraform.tfstate.*` and
   `.terraform/` are listed in `labs/day07/terraform/.gitignore` — but
   confirm that with `git check-ignore`, as above, rather than trusting
   this sentence; a false assumption here is how a real password ends up
   in a commit. The state file matters as much as `terraform.tfvars`
   does: `terraform apply` writes `db_password` into `terraform.tfstate`
   in plaintext, so an ignored `terraform.tfvars` next to a committed
   `terraform.tfstate` leaks the same password anyway.

   This repository does not run `terraform` for you, and this README
   does not either — Terraform touches your own AWS account and bills it,
   so every apply here is something you run yourself, deliberately, with
   the plan output in front of you.

3. **Force a failover and time it.** With the instance available:

   ```bash
   time aws rds reboot-db-instance --db-instance-identifier dbm-lab-pg --force-failover
   ```

   Time from issuing that command to the endpoint (`terraform output
   db_endpoint`) accepting connections against the new primary again —
   a `psql` connection loop that retries every second and prints when it
   first succeeds is the simplest way to pin this down. Round to the
   nearest second and write `failover_seconds=<n>` to `/tmp/answer`.
   While you're at it: keep one `psql` session open across the failover
   and note what happens to it, and to a transaction you start on it right
   before triggering the failover — `content/day07.md`'s Core concepts and
   this lab's `SOLUTION.md` both cover what you should see.

4. **Run `pgbench` and read Performance Insights.**

   ```bash
   pgbench -i -s 10 -h <db_endpoint> -p 5432 -U dbmlab_admin -d dbmlab
   pgbench -c 20 -T 120 -h <db_endpoint> -p 5432 -U dbmlab_admin -d dbmlab
   ```

   In the RDS console, open Performance Insights for `dbm-lab-pg` while
   `pgbench` runs (or immediately after, using its "look back" window),
   and read the `DBLoad` chart's wait-event breakdown. Write the single
   largest contributor as `top_wait_event=<name>` — it has to match one of
   Performance Insights' actual wait-event names (`CPU`,
   `IO:DataFileRead`, `Lock:transactionid`, `LWLock:BufferMapping`,
   `Client:ClientRead`, and the rest of that vocabulary), not a
   paraphrase. The match is case-insensitive, so copy the name off the
   console as-is rather than guessing at its capitalization.

5. **Atlas side.** Follow `atlas-setup.md` in full: create the `dbm-lab`
   M10 cluster, load a `payment_events` subset, create the monotonic
   index, and work through the shard-key reasoning it walks you through.
   Write your conclusion as `hot_shard_reason=<...>` — it has to name
   monotonicity as the actual mechanism, not merely assert the key is
   "bad." "High cardinality doesn't help because every write still lands
   on the newest chunk" is the shape of a correct answer; "the key isn't
   diverse enough" is not, because `ts` is plenty diverse — that's
   exactly what makes the failure worth teaching.

6. **Verify.**

   ```bash
   docker compose -p dbmastery exec ws bash labs/day07/verify.sh
   ```

   (or run it directly from your host if `bash` and the AWS/Atlas CLIs are
   on your own machine — `verify.sh` checks `/tmp/answer` inside `ws` and
   then shells out to `labs/verify-teardown.sh`, which needs the AWS CLI
   on whatever machine actually runs it, not inside `ws`.)

7. **Tear down.** Immediately — see `teardown.md`. Do not leave this for
   a later session.

## The honest limitation of `verify.sh`

Every other day in this path computes the correct answer itself, live,
from the same database it broke moments earlier, and grades you against that
computed truth. Day 7 cannot do that: the truth here lives in your own
AWS and Atlas accounts, and it genuinely varies — by region, by instance
class, by which moment you happened to run `pgbench`, by how loaded the
underlying AWS hardware was during your specific failover. There is no
single correct `failover_seconds` this script could compute and compare
you against, because the honest correct value is different every time
this lab runs, for anyone, including you on a different day.

So `verify.sh` checks weaker things, plainly, rather than pretending to a
rigor it cannot actually deliver: that `failover_seconds` parses as a
number and falls in a plausible range (20-600 seconds — RDS Multi-AZ
failovers typically land in the 60-120 second neighborhood, and this
range is deliberately wider than that to avoid failing a real, correctly-
measured outlier); that `top_wait_event` matches a real Performance
Insights wait-event name rather than a guess or a typo; that
`hot_shard_reason` actually mentions monotonicity, the specific mechanism,
rather than a vague "shard keys matter" non-answer; and, finally, that
`labs/verify-teardown.sh` reports nothing still running in your AWS and
Atlas accounts. A passing `verify.sh` here proves your answers are
present, well-formed, and plausible, and that you left nothing billing —
it does not prove `failover_seconds` is the number your specific failover
actually took, because nothing outside your own AWS account timeline
could know that number to check it against.

## Success signal

`labs/day07/verify.sh` exits `0` — which, because it ends by invoking
`labs/verify-teardown.sh` and propagating its exit code, also means
teardown is genuinely clean. A "pass" on this lab is simultaneously a
teardown receipt; there is no way to pass with a billable resource still
running.

No further hints here. `SOLUTION.md` has the full chain — what the
failover actually did to your connection, how to read the Performance
Insights panels, and the complete monotonic-shard-key argument — if you
get stuck, but reading it before your own attempt skips the lesson this
lab exists to teach.

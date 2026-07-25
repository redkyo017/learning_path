# Day 14 Lab — produce, fan-out, replay, dead-letter

Orders emits keyed `OrderPlaced` events; `inventory` and `analytics` consumer
groups each receive every event; you replay Analytics from the start of the log;
then a poison message stalls a partition until you add a dead-letter path.

The Kafka CLI scripts live inside the broker container under `/opt/kafka/bin/`;
run them via `docker compose exec kafka`. A shell function keeps the commands short:

## Setup

```bash
cd ../../../labs && docker compose up -d kafka && cd -   # bring up shared Kafka

# helper: run any Kafka CLI script inside the broker container
kfk() { docker compose -f ../../../labs/docker-compose.yml exec -T kafka "/opt/kafka/bin/$@"; }

# create the topics (partitions = unit of parallelism + ordering)
kfk kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --topic orders --partitions 3 --replication-factor 1
kfk kafka-topics.sh --bootstrap-server localhost:9092 \
  --create --topic orders.DLQ --partitions 1 --replication-factor 1
kfk kafka-topics.sh --bootstrap-server localhost:9092 --list

go mod tidy   # once, needs network
```

## Step 1 — produce events

```bash
go run ./producer -n 20
```

## Step 2 — fan-out: two groups each get ALL events

Run each in its own terminal:

```bash
go run ./consumer -group inventory     # decrements stock, logs on_hand
go run ./consumer -group analytics     # counts events + sums revenue
```

Both should print **20** records. Confirm each group has its own offsets:

```bash
docker compose -f ../../../labs/docker-compose.yml exec kafka \
  /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group analytics
# CURRENT-OFFSET should equal LOG-END-OFFSET per partition (fully caught up)
```

Kill both consumers (Ctrl-C) before the next step.

## Step 3 — REPLAY: rebuild analytics from the log alone

Reset the `analytics` group to the beginning and re-consume — it rebuilds its
counts from history with no help from the producer. This is "log as source of truth".

```bash
docker compose -f ../../../labs/docker-compose.yml exec kafka \
  /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --group analytics --topic orders --reset-offsets --to-earliest --execute

go run ./consumer -group analytics     # replays all 20, count climbs 1..20 again
```

Note that `inventory` is untouched — offsets are per group.

## Step 4 — BREAK IT: poison message stalls a partition (mandatory break-it)

```bash
go run ./producer -n 3 -poison         # 3 good events + 1 malformed
go run ./consumer -group inventory     # NAIVE: crashes on the poison record
go run ./consumer -group inventory     # re-run: crashes AGAIN at the same offset
```

**Observe:** the consumer dies on the malformed record; because the offset was
never committed, every restart re-reads it and dies again — a **crash loop**. That
partition is wedged: any well-formed order *behind* the poison record never gets
processed, even though the group looks "running". Confirm the stuck offset:

```bash
docker compose -f ../../../labs/docker-compose.yml exec kafka \
  /opt/kafka/bin/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --group inventory
# LAG > 0 and CURRENT-OFFSET frozen on the poison partition
```

## Step 5 — the fix: dead-letter and continue

```bash
go run ./consumer -group inventory -dlq   # dead-letters the bad record, keeps going
```

The consumer routes the malformed record to `orders.DLQ` (with provenance headers),
commits, and processes the good records behind it. Inspect the DLQ:

```bash
docker compose -f ../../../labs/docker-compose.yml exec kafka \
  /opt/kafka/bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic orders.DLQ --from-beginning --property print.headers=true --timeout-ms 3000
```

## Teardown

```bash
cd ../../../labs && docker compose down -v
```

Record measurements and observations in `results.md`.

# 15-Day Kafka Plan — Content Index

Each day below has theory (concepts, mechanisms, why things are designed the
way they are), best practices, common pitfalls, real-world use cases, a
worked example, and exercises with full explained answers. Start with
`docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md` for the daily
schedule, exact commands, and chaos labs; use this index — and each day's
`content/dayNN.md` — for the concepts behind those commands.

Code labs: `labs/` is the Java (Maven) implementation used throughout the
plan. `labs-go/` is a parallel Go implementation (see `labs-go/README.md`)
for days that have one — useful if you want to work in Go while you ramp up
on Java. Kafka Streams (Day 13, and the Streams portion of Day 14) has no
official Go client, so those two stay Java-only by design, not oversight.

| Day | Topic | Content | Java lab | Go lab |
|---|---|---|---|---|
| 1 | Kafka's mental model, cluster internals, KRaft | [day01.md](day01.md) | cluster + `pom.xml` scaffold only | — |
| 2 | Producer/consumer semantics, delivery guarantees | [day02.md](day02.md) | `ProducerDemo.java`, `ConsumerDemo.java` | `cmd/producerdemo`, `cmd/consumerdemo` |
| 3 | Consumer groups & rebalancing (chaos: rebalance storm) | [day03.md](day03.md) | `ConsumerDemo.java` (updated), `ProducerLoop.java` | `cmd/consumerdemo` (updated), `cmd/producerloop` |
| 4 | Log internals, replication (chaos: broker kill) | [day04.md](day04.md) | `CompactedProducer.java` | `cmd/compactedproducer` |
| 5 | Security — SASL/SCRAM, ACLs, mTLS (chaos: ACL revocation) + Phase 1 review | [day05.md](day05.md) | `generate-certs.sh`, `local-sasl.properties` | `config/local-sasl.properties` (flat keys, no JAAS string) |
| 6 | AWS MSK provisioning (IAM auth, cost control) | [day06.md](day06.md) | `msk-cluster-config.json`, `msk-iam.properties` | `config/msk-iam.properties` (+ `kafkaclient.MaybeConfigureAWSIAM` code) |
| 7 | Kafka Connect & integration patterns on MSK | [day07.md](day07.md) | AWS CLI only (no fixed connector JSON — see doc for why) | — |
| 8 | Monitoring & operations on MSK | [day08.md](day08.md) | reuses `ProducerLoop.java` | reuses `cmd/producerloop` |
| 9 | Multi-region DR & scaling — MirrorMaker2 (chaos: broker failure) | [day09.md](day09.md) | `mm2.properties` (language-agnostic) | same file |
| 10 | Phase 2 review (Days 6-9) + AWS teardown | [day10.md](day10.md) | — | — |
| 11 | Confluent Cloud — RBAC vs. ACLs vs. IAM | [day11.md](day11.md) | `confluent-app-consumer.properties` | `config/confluent-app-consumer.properties` (flat keys) |
| 12 | Schema Registry, schema evolution, managed Connect | [day12.md](day12.md) | `AvroProducerDemo.java`, `orders-value.avsc` | `cmd/avroproducerdemo` (Go's schema-registry serde derives schema by reflection, not from the `.avsc` file — see code comments) |
| 13 | Kafka Streams + ksqlDB + Phase 3 review + Confluent teardown | [day13.md](day13.md) | `OrderAggregationStreamsApp.java` | Java-only (no Go Kafka Streams client) |
| 14 | Capstone — end-to-end pipeline, one deliberate failure | [day14.md](day14.md) | `CapstoneStreamsApp.java`, `FileSinkConsumer.java` | `cmd/filesinkconsumer` only (Streams half stays Java) |
| 15 | Final CCAAK-style practice exam + gap analysis | [day15.md](day15.md) | — | — |

All 15 content docs and all Go ports were reviewed against the plan's exact
commands/behavior and the Java originals for consistency. The Go client
files carry `TODO(human)` comments at every API call whose exact signature
couldn't be confirmed without running `go build` — check those against the
current `confluent-kafka-go` docs before relying on them.

# 15-Day Kafka Mastery — Implementation Plan

> **For the learner:** This plan is executed by you, not by an agent — each
> day's "task" is a study/lab session, not a code change made on your behalf.
> Work top to bottom, one day at a time, and check off steps as you complete
> them. Do not skip ahead; the phase-review days (5, 10, 13) and the capstone
> (14) depend on the journal entries and lab code from the days before them.
> Saving your work (git add/commit, or however you track progress) is entirely
> your own responsibility — nothing in this plan runs git on your behalf.

**Goal:** Reach production-credible Kafka competence in 15 days (5–6
hours/day) for an integration/infrastructure role — able to secure, operate,
and integrate against a Kafka cluster, not just write client code — culminating
in a self-administered CCAAK-style practice exam.

**Architecture:** Four phases of increasing environment complexity, built on
one shared Java lab project whose client code is reused across every
environment via swappable `.properties` config files (not rewritten each day):
Local Docker KRaft cluster (Days 1–5) → AWS MSK (Days 6–10) → Confluent Cloud
(Days 11–13) → local capstone + exam (Days 14–15). Each content day runs the
same rhythm: primer from primary sources → hands-on build → deliberate-failure
("chaos") lab → integration coding → teach-it-back journal entry.

**Tech Stack:** Docker/Docker Compose, Apache Kafka in KRaft mode
(`apache/kafka` Docker image, no ZooKeeper), Java 17, Maven, `kafka-clients` /
`kafka-streams`, Confluent's Avro serializer + Schema Registry client,
`aws-msk-iam-auth`, AWS CLI, AWS MSK + MSK Connect + CloudWatch + Glue Schema
Registry, Confluent CLI, Confluent Cloud (Kafka, Schema Registry, Connect,
ksqlDB), MirrorMaker2.

## Global Constraints

- 5–6 hour daily budget. If a step overruns, note it in the journal and move
  on — the phase-review days exist to catch up, not the daily schedule.
- Chaos labs (deliberate failure injection) are mandatory, not optional — per
  the spec, they are the plan's primary retention mechanism, not a stretch
  goal.
- CLI-first for all administration: no Kafka GUI tools (Conduktor, AKHQ, etc.)
  during the 15 days. Typing the actual commands is what builds a transferable
  mental model.
- Security is live from Day 5 onward: every day from Day 5 forward talks to an
  authenticated cluster, never an open one.
- Cloud resources (AWS in Days 6–10, Confluent Cloud in Days 11–13) must be
  fully torn down at the end of their phase (Day 10, Day 13) — this is a
  scheduled step, not an afterthought, per the spec's cost-control rule.
- All client, Streams, and Connect code is Java 17, built with Maven.
- Exact AWS CLI / Confluent CLI flag names and JSON schema fields are given as
  written at time of planning, but both CLIs evolve — cross-check against
  `aws kafka <command> help` / `confluent <command> --help` if a command
  errors on an unrecognized flag. Exact dependency patch versions in `pom.xml`
  should similarly be bumped to the latest patch if the pinned one is stale.
- Journal file: `kafka_practice/journal.md`, one entry appended per day.

## Lab Project Layout

Built up incrementally across the 15 days — this is the target end state, not
something to create all at once:

```
kafka_practice/
  journal.md
  docker/
    docker-compose.yml          # Day 1, edited again on Day 5
    generate-certs.sh           # Day 5
    certs/                      # Day 5 (generated, not hand-written)
  labs/
    pom.xml                     # Day 1
    config/
      local.properties          # Day 1
      local-sasl.properties      # Day 5
      local-ssl.properties       # Day 5
      admin-superuser.properties # Day 5
      msk-iam.properties         # Day 6
      confluent.properties       # Day 11
      confluent-app-consumer.properties # Day 11
      confluent-sr.properties    # Day 12
    schemas/
      orders-value.avsc         # Day 12
    src/main/java/com/kafkapractice/
      KafkaClientConfig.java    # Day 2
      ProducerDemo.java         # Day 2, modified Day 3
      ConsumerDemo.java         # Day 2, modified Day 3
      ProducerLoop.java         # Day 3
      CompactedProducer.java    # Day 4
      AvroProducerDemo.java     # Day 12
      OrderAggregationStreamsApp.java # Day 13
      CapstoneStreamsApp.java   # Day 14
      FileSinkConsumer.java     # Day 14
    capstone-output.jsonl       # Day 14 (generated)
  mm2/
    mm2.properties             # Day 9
  aws/
    msk-cluster-config.json    # Day 6
    iam-policy.json            # Day 6
    datagen-connector.json     # Day 7
    s3-sink-connector.json     # Day 7
```

---

## Day 1: Kafka's mental model, cluster internals, local KRaft cluster

**Materials:**
- Apache Kafka docs: "Introduction" and "Design" (kafka.apache.org/documentation/)
- Docker, Docker Compose, Java 17, Maven installed locally

**Builds on:** nothing (Day 1).
**Sets up:** Day 2 needs the running cluster and the Maven project scaffold to
write the first producer/consumer code.

- [ ] **Step 1 (20 min): Primer.** Read the Kafka "Introduction" and "Design"
  doc pages. While reading, write down in `journal.md` five concrete ways
  Kafka's model differs from a generic message queue (RabbitMQ/SQS), since
  borrowing that mental model is the single biggest time-waster for people
  with adjacent broker experience:
  - Kafka retains a log; messages are not deleted on consume.
  - Ordering is only guaranteed within a partition, not across a topic.
  - Multiple independent consumer groups can each re-read the same data.
  - Consumers pull and track their own offset; the broker doesn't push or
    track "delivered" state per consumer.
  - You can rewind/replay by resetting an offset — a queue has no equivalent.
- [ ] **Step 2 (10 min): Verify prerequisites.**

Run:
```bash
docker --version
docker compose version
java --version
mvn --version
```
Expected: Docker Engine 24+, Compose v2, Java 17+, Maven 3.9+. Install/upgrade
whichever is missing before continuing.

- [ ] **Step 3 (40 min): Bring up a 3-broker KRaft cluster.** Create
  `kafka_practice/docker/docker-compose.yml`:

```yaml
services:
  kafka1:
    image: apache/kafka:3.7.0
    container_name: kafka1
    ports:
      - "29092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9094
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:29092
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka1:9094,2@kafka2:9094,3@kafka3:9094
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      CLUSTER_ID: "4L6g3nShT-eMCtK--X86sw"
  kafka2:
    image: apache/kafka:3.7.0
    container_name: kafka2
    ports:
      - "29093:9092"
    environment:
      KAFKA_NODE_ID: 2
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9094
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:29093
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka1:9094,2@kafka2:9094,3@kafka3:9094
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      CLUSTER_ID: "4L6g3nShT-eMCtK--X86sw"
  kafka3:
    image: apache/kafka:3.7.0
    container_name: kafka3
    ports:
      - "29094:9092"
    environment:
      KAFKA_NODE_ID: 3
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9094
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:29094
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka1:9094,2@kafka2:9094,3@kafka3:9094
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      KAFKA_DEFAULT_REPLICATION_FACTOR: 3
      KAFKA_MIN_INSYNC_REPLICAS: 2
      CLUSTER_ID: "4L6g3nShT-eMCtK--X86sw"
```

Run:
```bash
cd kafka_practice/docker
docker compose up -d
docker compose ps
```
Expected: all three containers show state `running`/`Up`. If a container
restarts in a loop, run `docker compose logs kafka1` and check the
`CLUSTER_ID` and `KAFKA_CONTROLLER_QUORUM_VOTERS` values match exactly across
all three services (a common first-run mistake).

- [ ] **Step 4 (30 min): CLI-first admin exploration.** From the host:

```bash
docker exec -it kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --topic orders --partitions 3 --replication-factor 3

docker exec -it kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --describe --topic orders
```
Expected `--describe` output: 3 partitions, each with 3 replicas, a `Leader`
broker id, and all 3 brokers listed in `Isr` (in-sync replicas). In
`journal.md`, write one sentence each defining Leader, Replicas, and Isr in
your own words from this concrete output — not from the docs' definition.

- [ ] **Step 5 (30 min): Manual produce/consume, two independent groups.**

```bash
docker exec -it kafka1 /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 --topic orders
```
Type 3-4 lines, then Ctrl+D. In a second terminal:
```bash
docker exec -it kafka1 /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 --topic orders --from-beginning \
  --group group-a
```
Expected: all messages appear. In a third terminal, run the same consumer
command with `--group group-b` instead. Expected: `group-b` also gets *all*
messages from the beginning, independently of `group-a` — the direct, hands-on
contradiction of "it's just a queue."

- [ ] **Step 6 (30 min): Scaffold the shared Java lab project.** Create
  `kafka_practice/labs/pom.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>com.kafkapractice</groupId>
  <artifactId>kafka-practice-labs</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>

  <properties>
    <maven.compiler.source>17</maven.compiler.source>
    <maven.compiler.target>17</maven.compiler.target>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <kafka.version>3.7.0</kafka.version>
  </properties>

  <repositories>
    <repository>
      <id>confluent</id>
      <url>https://packages.confluent.io/maven/</url>
    </repository>
  </repositories>

  <dependencies>
    <dependency>
      <groupId>org.apache.kafka</groupId>
      <artifactId>kafka-clients</artifactId>
      <version>${kafka.version}</version>
    </dependency>
    <dependency>
      <groupId>org.apache.kafka</groupId>
      <artifactId>kafka-streams</artifactId>
      <version>${kafka.version}</version>
    </dependency>
    <dependency>
      <groupId>io.confluent</groupId>
      <artifactId>kafka-avro-serializer</artifactId>
      <version>7.6.0</version>
    </dependency>
    <dependency>
      <groupId>io.confluent</groupId>
      <artifactId>kafka-streams-avro-serde</artifactId>
      <version>7.6.0</version>
    </dependency>
    <dependency>
      <groupId>software.amazon.msk</groupId>
      <artifactId>aws-msk-iam-auth</artifactId>
      <version>2.2.0</version>
    </dependency>
    <dependency>
      <groupId>org.slf4j</groupId>
      <artifactId>slf4j-simple</artifactId>
      <version>2.0.13</version>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.13.0</version>
      </plugin>
      <plugin>
        <groupId>org.codehaus.mojo</groupId>
        <artifactId>exec-maven-plugin</artifactId>
        <version>3.2.0</version>
      </plugin>
    </plugins>
  </build>
</project>
```

Create the directory `kafka_practice/labs/src/main/java/com/kafkapractice/`
(no files yet) and `kafka_practice/labs/config/local.properties`:

```properties
bootstrap.servers=localhost:29092,localhost:29093,localhost:29094
```

Run:
```bash
cd kafka_practice/labs
mvn -q validate
```
Expected: no errors (there's no source yet, so there's nothing to compile —
`validate` just confirms the POM and repositories resolve correctly).

- [ ] **Step 7 (20 min): Journal entry.** Append to `journal.md`:
  ```
  ## Day 1 — Kafka's model, cluster internals
  Key idea in my own words: ...
  What confused me: ...
  ```
  Save your work however you track progress — this plan doesn't run git for
  you.

---

## Day 2: Producer/consumer semantics — delivery guarantees, partitioning

**Materials:**
- Kafka docs: Producer Configs (`acks`, `enable.idempotence`, `retries`) and
  Consumer Configs (`enable.auto.commit`, `auto.offset.reset`)
- KIP-98 (Exactly Once Delivery and Transactional Messaging) — abstract and
  motivation sections only

**Builds on:** Day 1's cluster and Maven scaffold.
**Sets up:** Day 3 needs this producer/consumer code, unmodified in spirit, to
build the rebalance-storm chaos lab.

- [ ] **Step 1 (20 min): Primer.** Read the producer/consumer config docs
  above plus KIP-98's motivation section. Write one journal sentence
  correcting the most common misconception: an idempotent producer prevents
  *duplicate writes from its own retries* — it does not, by itself, give you
  end-to-end "exactly once" if your consumer also has side effects (e.g.
  writing to a database) that can be retried independently.

- [ ] **Step 2 (15 min): Shared config-loading helper.** Create
  `kafka_practice/labs/src/main/java/com/kafkapractice/KafkaClientConfig.java`:

```java
package com.kafkapractice;

import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;

public final class KafkaClientConfig {
    private KafkaClientConfig() {
    }

    public static Properties load(String path) throws IOException {
        Properties props = new Properties();
        try (FileInputStream in = new FileInputStream(path)) {
            props.load(in);
        }
        return props;
    }
}
```

Every lab class below loads its broker/security config from a `.properties`
file path passed as the first CLI argument, defaulting to
`config/local.properties`. This is what lets the *same* class run unmodified
against Docker (Day 2), MSK (Day 6), and Confluent Cloud (Day 11) — only the
config file changes.

- [ ] **Step 3 (45 min): Producer demo.** Create
  `kafka_practice/labs/src/main/java/com/kafkapractice/ProducerDemo.java`:

```java
package com.kafkapractice;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;
import java.util.Random;

public class ProducerDemo {
    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/local.properties";
        String topic = args.length > 1 ? args[1] : "orders";

        Properties props = KafkaClientConfig.load(configPath);
        props.put("key.serializer", StringSerializer.class.getName());
        props.put("value.serializer", StringSerializer.class.getName());
        props.put("acks", "all");
        props.put("enable.idempotence", "true");

        Random random = new Random();
        try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
            for (int i = 0; i < 20; i++) {
                String key = "order-" + (1 + random.nextInt(3));
                String value = "{\"orderId\":" + i + ",\"amount\":" + (10 + random.nextInt(90)) + "}";
                RecordMetadata metadata = producer.send(new ProducerRecord<>(topic, key, value)).get();
                System.out.printf("key=%s -> partition=%d offset=%d%n", key, metadata.partition(), metadata.offset());
            }
        }
    }
}
```

Note: this uses synchronous `.get()` per send so you can observe partition
assignment for every message, at the cost of throughput. A production
producer would use the async callback instead — that trade-off is worth
noting in the journal, not fixing here.

Run:
```bash
cd kafka_practice/labs
mvn -q compile exec:java -Dexec.mainClass=com.kafkapractice.ProducerDemo \
  -Dexec.args="config/local.properties orders"
```
Expected: 20 lines of `key=order-N -> partition=P offset=O`. Note that every
message with the same key lands on the same partition — write down why in the
journal (hash of the key determines partition, by default).

- [ ] **Step 4 (45 min): Consumer demo with manual commits.** Create
  `kafka_practice/labs/src/main/java/com/kafkapractice/ConsumerDemo.java`:

```java
package com.kafkapractice;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class ConsumerDemo {
    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/local.properties";
        String topic = args.length > 1 ? args[1] : "orders";
        String groupId = args.length > 2 ? args[2] : "orders-group";

        Properties props = KafkaClientConfig.load(configPath);
        props.put("key.deserializer", StringDeserializer.class.getName());
        props.put("value.deserializer", StringDeserializer.class.getName());
        props.put("group.id", groupId);
        props.put("enable.auto.commit", "false");
        props.put("auto.offset.reset", "earliest");

        try (KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props)) {
            consumer.subscribe(Collections.singletonList(topic));
            while (true) {
                ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(500));
                for (ConsumerRecord<String, String> record : records) {
                    System.out.printf("partition=%d offset=%d key=%s value=%s%n",
                            record.partition(), record.offset(), record.key(), record.value());
                }
                if (!records.isEmpty()) {
                    consumer.commitSync();
                }
            }
        }
    }
}
```

Run (separate terminal, leave it running):
```bash
mvn -q compile exec:java -Dexec.mainClass=com.kafkapractice.ConsumerDemo \
  -Dexec.args="config/local.properties orders orders-group"
```
Expected: prints the 20 messages from Step 3. Stop it with Ctrl+C once done.

- [ ] **Step 5 (30 min): At-least-once, made concrete.** Temporarily edit
  `ConsumerDemo.java` to throw after processing the 5th record in a poll batch,
  *before* `commitSync()`:
```java
                int processed = 0;
                for (ConsumerRecord<String, String> record : records) {
                    System.out.printf("partition=%d offset=%d key=%s value=%s%n",
                            record.partition(), record.offset(), record.key(), record.value());
                    processed++;
                    if (processed == 5) {
                        throw new RuntimeException("simulated crash before commit");
                    }
                }
```
  Re-run `ProducerDemo` to generate fresh messages, then run `ConsumerDemo` and
  let it crash. Run it again. Expected: it reprocesses some already-seen
  messages from the last committed offset — the concrete, observed meaning of
  "at-least-once." Revert the throw before moving on.

- [ ] **Step 6 (30 min): `acks=all` under partial failure.** With
  `ProducerDemo` running in a loop (re-run Step 3's command 5 times in a row),
  stop one broker mid-stream:
```bash
docker stop kafka2
```
  Expected: with `min.insync.replicas=2` and 2 brokers still alive, sends still
  succeed (just slower). Restart it:
```bash
docker start kafka2
```
  In the journal, write what you predict would happen if you stopped *two* of
  the three brokers instead — you'll test this for real on Day 4.

- [ ] **Step 7 (15 min): Journal entry + save point.** Append the Day 2 entry
  to `journal.md` and save your work your own way.

---

## Day 3: Consumer groups & rebalancing — chaos lab: rebalance storm

**Materials:**
- Kafka docs: Consumer Groups, `partition.assignment.strategy`
- KIP-429 (Kafka Consumer Incremental Rebalance Protocol) — abstract only

**Builds on:** Day 2's `ConsumerDemo`.
**Sets up:** Day 5's security labs reuse this same consumer group and topic.

- [ ] **Step 1 (20 min): Primer.** Read the Consumer Groups doc and KIP-429's
  abstract. Note the difference: the default eager
  (`RangeAssignor`/`CooperativeStickyAssignor` depending on version) rebalance
  historically revoked *all* partitions from *all* group members before
  reassigning ("stop the world"); `CooperativeStickyAssignor` only moves the
  partitions that actually need to move, letting unaffected consumers keep
  processing during the rebalance.

- [ ] **Step 2 (20 min): Add rebalance visibility.** Replace the contents of
  `ConsumerDemo.java` with this version (adds a `ConsumerRebalanceListener` so
  every assignment change is printed):

```java
package com.kafkapractice;

import org.apache.kafka.clients.consumer.ConsumerRebalanceListener;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.time.Duration;
import java.util.Collection;
import java.util.Collections;
import java.util.Properties;

public class ConsumerDemo {
    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/local.properties";
        String topic = args.length > 1 ? args[1] : "orders";
        String groupId = args.length > 2 ? args[2] : "orders-group";

        Properties props = KafkaClientConfig.load(configPath);
        props.put("key.deserializer", StringDeserializer.class.getName());
        props.put("value.deserializer", StringDeserializer.class.getName());
        props.put("group.id", groupId);
        props.put("enable.auto.commit", "false");
        props.put("auto.offset.reset", "earliest");

        try (KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props)) {
            consumer.subscribe(Collections.singletonList(topic), new ConsumerRebalanceListener() {
                @Override
                public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
                    System.out.println("[rebalance] revoked: " + partitions);
                }

                @Override
                public void onPartitionsAssigned(Collection<TopicPartition> partitions) {
                    System.out.println("[rebalance] assigned: " + partitions);
                }
            });
            while (true) {
                ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(500));
                for (ConsumerRecord<String, String> record : records) {
                    System.out.printf("partition=%d offset=%d key=%s value=%s%n",
                            record.partition(), record.offset(), record.key(), record.value());
                }
                if (!records.isEmpty()) {
                    consumer.commitSync();
                }
            }
        }
    }
}
```

- [ ] **Step 3 (20 min): Continuous producer for the chaos lab.** Create
  `kafka_practice/labs/src/main/java/com/kafkapractice/ProducerLoop.java`:

```java
package com.kafkapractice;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;
import java.util.Random;

public class ProducerLoop {
    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/local.properties";
        String topic = args.length > 1 ? args[1] : "orders";
        int messagesPerSecond = args.length > 2 ? Integer.parseInt(args[2]) : 5;

        Properties props = KafkaClientConfig.load(configPath);
        props.put("key.serializer", StringSerializer.class.getName());
        props.put("value.serializer", StringSerializer.class.getName());
        props.put("acks", "all");
        props.put("enable.idempotence", "true");

        Random random = new Random();
        long delayMs = 1000L / messagesPerSecond;
        try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
            long i = 0;
            while (true) {
                String key = "order-" + (1 + random.nextInt(3));
                String value = "{\"orderId\":" + i++ + ",\"amount\":" + (10 + random.nextInt(90)) + "}";
                producer.send(new ProducerRecord<>(topic, key, value));
                Thread.sleep(delayMs);
            }
        }
    }
}
```

- [ ] **Step 4 (20 min): Check lag visibility.** With `ProducerLoop` running
  (`-Dexec.args="config/local.properties orders 5"`) and one `ConsumerDemo`
  consuming, in a third terminal:
```bash
docker exec -it kafka1 /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --describe --group orders-group
```
Expected columns: `CURRENT-OFFSET`, `LOG-END-OFFSET`, `LAG`. Note these three
column names — you'll watch `LAG` climb and drain in the next step.

- [ ] **Step 5 (60 min): Chaos lab — rebalance storm.** Start `ProducerLoop` at
  a higher rate (`... orders 20`). Start three `ConsumerDemo` instances in
  three terminals, same `group.id=orders-group`. Once all three show a stable
  `[rebalance] assigned` partition set, run this from a fourth terminal to
  simulate churn — kill and restart one consumer's *process* every 5 seconds
  for one minute (do this by hand: Ctrl+C one terminal's `ConsumerDemo` and
  immediately re-run its `mvn exec:java` command; repeat with a different
  terminal 5 seconds later; keep cycling for a minute). While doing this, keep
  the `kafka-consumer-groups.sh --describe` command from Step 4 running in a
  loop in a fifth terminal:
```bash
watch -n 2 'docker exec kafka1 /opt/kafka/bin/kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --describe --group orders-group'
```
Expected: `LAG` climbs during the churn window and every `[rebalance]` log line
shows a full revoke-then-reassign across *all* members, not just the one that
left. Stop the churn, let it settle 30 seconds, confirm `LAG` drains to ~0.

- [ ] **Step 6 (20 min): Cooperative-sticky comparison.** Add
  `props.put("partition.assignment.strategy", "org.apache.kafka.clients.consumer.CooperativeStickyAssignor");`
  to `ConsumerDemo.java` right after the `group.id` line, recompile, and repeat
  Step 5's churn for another minute. Expected: `[rebalance] revoked` lines now
  only ever list the partitions that actually moved, and the `LAG` spike is
  visibly smaller/shorter than the eager run. Write the comparison in the
  journal with the two `LAG` peak numbers side by side.

- [ ] **Step 7 (20 min): Teach-it-back + journal + save point.** Write a
  postmortem-style paragraph: "Consumer lag spiked to N during a deploy that
  restarted 2 of 3 pods in a tight loop — here's why, and here's the one
  config change that would have limited the blast radius." Append to
  `journal.md` and save your work.

---

## Day 4: Log internals — segments, compaction, replication — chaos lab: broker kill

**Materials:**
- Kafka docs: Log Compaction, Topic Configs (`retention.ms`, `retention.bytes`,
  `min.insync.replicas`, `unclean.leader.election.enable`)

**Builds on:** Day 1's cluster, Day 2's `min.insync.replicas=2` config already
in the compose file.
**Sets up:** Day 5's security config change requires understanding how a
broker restart with a config change is safely rolled through a cluster.

- [ ] **Step 1 (20 min): Primer.** Read the Log Compaction doc and the
  replication-related topic configs. Note `unclean.leader.election.enable`
  defaults to `false` precisely to prevent the data loss scenario you'll
  reproduce in Step 5.

- [ ] **Step 2 (20 min): Inspect log segments directly.**
```bash
docker exec -it kafka1 ls -la /tmp/kraft-combined-logs/orders-0/
```
Expected: `.log`, `.index`, and `.timeindex` files. Open the largest `.log`
file's directory listing and note its size versus `log.segment.bytes`
(default 1 GiB) — at this message volume you won't see a rollover, which is
expected; note in the journal what would trigger one (size or
`log.segment.ms`, whichever comes first).

- [ ] **Step 3 (40 min): Compacted topic.**
```bash
docker exec -it kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --topic user-profiles --partitions 3 --replication-factor 3 \
  --config cleanup.policy=compact --config segment.ms=100 \
  --config min.cleanable.dirty.ratio=0.01
```
Create `kafka_practice/labs/src/main/java/com/kafkapractice/CompactedProducer.java`:

```java
package com.kafkapractice;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;

public class CompactedProducer {
    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/local.properties";
        String topic = args.length > 1 ? args[1] : "user-profiles";

        Properties props = KafkaClientConfig.load(configPath);
        props.put("key.serializer", StringSerializer.class.getName());
        props.put("value.serializer", StringSerializer.class.getName());
        props.put("acks", "all");

        String[] keys = {"user-1", "user-2", "user-3"};
        try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
            for (int round = 0; round < 5; round++) {
                for (String key : keys) {
                    String value = "{\"round\":" + round + ",\"status\":\"update-" + round + "\"}";
                    producer.send(new ProducerRecord<>(topic, key, value)).get();
                }
                Thread.sleep(200);
            }
        }
    }
}
```
Run it, wait ~30 seconds for the log cleaner thread to run (it polls
periodically, not instantly), then:
```bash
docker exec -it kafka1 /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 --topic user-profiles --from-beginning
```
Expected: only 3 messages (the last `round=4` update per key), not all 15 —
compaction removed the superseded versions.

- [ ] **Step 4 (45 min): Chaos lab, part A — under-replication.**
```bash
docker stop kafka2
docker exec -it kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --describe --topic orders
```
Expected: partitions that had `kafka2` as a replica now show a shorter `Isr`
list than `Replicas` (under-replicated), and any partition whose leader was
`kafka2` shows a new leader. Run `ProducerDemo` again — expected: it still
succeeds (2 of 3 replicas alive still satisfies `min.insync.replicas=2`).
```bash
docker start kafka2
```
Poll `--describe` every few seconds until `Isr` matches `Replicas` again —
note how long recatch-up took.

- [ ] **Step 5 (30 min): Chaos lab, part B — data-loss guard.**
```bash
docker stop kafka2
docker stop kafka3
```
Run `ProducerDemo` again. Expected: it now fails with
`org.apache.kafka.common.errors.NotEnoughReplicasException` (only 1 of 3
replicas alive, below `min.insync.replicas=2`). This is the guard working as
designed, not a bug. Restart both:
```bash
docker start kafka2
docker start kafka3
```
In the journal, explain why `unclean.leader.election.enable=false` (the
default) would have refused to elect a leader from an out-of-sync replica in
this scenario even if you'd set `min.insync.replicas=1` — and what data it
would silently lose if it did.

- [ ] **Step 6 (20 min): Teach-it-back + journal + save point.** Write the
  Day 4 postmortem paragraph and save your work.

---

## Day 5: Security fundamentals — SASL/SCRAM, ACLs, mTLS — chaos lab: ACL revocation

**Materials:**
- Kafka docs: Security Overview, SASL/SCRAM, Authorization (ACLs), SSL/TLS

**Builds on:** Day 1's cluster (rebuilt fresh with security enabled from the
start — broker-level auth/authorizer settings can't be hot-added to a running
KRaft cluster the way a topic config can).
**Sets up:** Day 6 compares this ACL model directly against AWS IAM; Day 11
compares it again against Confluent RBAC.

- [ ] **Step 1 (20 min): Primer.** Read the Security Overview, SASL/SCRAM, and
  Authorization pages. Note the distinction the rest of today is built on:
  *authentication* (SASL/SCRAM, mTLS — proving who you are) is separate from
  *authorization* (ACLs — what that identity is allowed to do).

- [ ] **Step 2 (45 min): Rebuild the cluster with SASL/SCRAM + an authorizer.**
  Edit `kafka_practice/docker/docker-compose.yml`. The new `SASL_PLAINTEXT`
  listener needs its own distinct **host** port per broker, exactly like
  `PLAINTEXT` already does (`29092`/`29093`/`29094` from Day 1) — reusing the
  same host port across containers isn't possible, Docker can only bind one
  container to a given host port. Replace each service's
  `KAFKA_LISTENERS`/`KAFKA_ADVERTISED_LISTENERS`/
  `KAFKA_LISTENER_SECURITY_PROTOCOL_MAP` lines from Day 1 and add the new
  keys, per this per-broker mapping:

  | Service | `KAFKA_LISTENERS` | `KAFKA_ADVERTISED_LISTENERS` |
  |---|---|---|
  | kafka1 | `PLAINTEXT://:9092,CONTROLLER://:9094,SASL_PLAINTEXT://:9095` | `PLAINTEXT://localhost:29092,SASL_PLAINTEXT://localhost:29095` |
  | kafka2 | `PLAINTEXT://:9092,CONTROLLER://:9094,SASL_PLAINTEXT://:9095` | `PLAINTEXT://localhost:29093,SASL_PLAINTEXT://localhost:29096` |
  | kafka3 | `PLAINTEXT://:9092,CONTROLLER://:9094,SASL_PLAINTEXT://:9095` | `PLAINTEXT://localhost:29094,SASL_PLAINTEXT://localhost:29097` |

  Also add the following to **all three** services' `environment` blocks
  (also add a matching `- "29095:9095"`/`"29096:9095"`/`"29097:9095"` line to
  each service's `ports` list, one per broker per the table above), and these
  identical keys to all three (values are the same across brokers):

```yaml
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT,SASL_PLAINTEXT:SASL_PLAINTEXT
      KAFKA_SASL_ENABLED_MECHANISMS: SCRAM-SHA-256
      KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL: PLAINTEXT
      KAFKA_AUTHORIZER_CLASS_NAME: org.apache.kafka.metadata.authorizer.StandardAuthorizer
      KAFKA_SUPER_USERS: User:ANONYMOUS;User:admin
```
  Ports 9092/`PLAINTEXT` stay open deliberately as the bootstrap channel: an
  anonymous connection over `PLAINTEXT` has no identity to authorize against,
  so `User:ANONYMOUS` is included as a superuser here to make that channel a
  trusted admin path for the SCRAM-user bootstrap step below — mirroring how
  some real deployments keep one internal, unauthenticated admin listener that
  is never exposed past the VPC. It's only reachable from `localhost` here,
  which is the equivalent guarantee for this lab. Once the SASL_PLAINTEXT
  listener and its SCRAM users exist, `admin` (an authenticated principal, not
  anonymous) is the one you'll actually use for anything that should be
  auditable, starting in Step 5.

Run:
```bash
cd kafka_practice/docker
docker compose down -v
docker compose up -d
```
The `-v` wipes previous topic data — expected and necessary, since you're
changing broker-level security settings, not a topic config.

- [ ] **Step 3 (30 min): Create SCRAM users.**
```bash
docker exec -it kafka1 /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server localhost:9092 \
  --alter --add-config 'SCRAM-SHA-256=[password=admin-secret]' \
  --entity-type users --entity-name admin

docker exec -it kafka1 /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server localhost:9092 \
  --alter --add-config 'SCRAM-SHA-256=[password=app-secret]' \
  --entity-type users --entity-name app-consumer
```
Create `kafka_practice/labs/config/admin-superuser.properties`:
```properties
bootstrap.servers=localhost:29095
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin-secret";
```
Re-create the topics on the fresh cluster (data was wiped in Step 2):
```bash
docker exec -it kafka1 /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 --create --topic orders --partitions 3 --replication-factor 3
```

- [ ] **Step 4 (30 min): Confirm authorization is active, then deny-by-default.**
  Create `kafka_practice/labs/config/local-sasl.properties`:
```properties
bootstrap.servers=localhost:29095
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="app-consumer" password="app-secret";
```
Run `ConsumerDemo` against it:
```bash
mvn -q compile exec:java -Dexec.mainClass=com.kafkapractice.ConsumerDemo \
  -Dexec.args="config/local-sasl.properties orders orders-group"
```
Expected: authentication succeeds (no SASL error) but it hangs / logs
`TopicAuthorizationException` or similar — `app-consumer` is authenticated but
has zero ACLs yet, so the authorizer denies everything by default. This is the
"authentication ≠ authorization" distinction from Step 1, observed directly.

- [ ] **Step 5 (20 min): Grant the ACL.** Note the bootstrap address is
  `localhost:9095` here, not `9092` — inside the `kafka1` container, `9095` is
  where the `SASL_PLAINTEXT` listener is actually bound (per the table in
  Step 2); `9092` only speaks plain `PLAINTEXT` and would reject a connection
  that presents SASL credentials.

```bash
docker exec -it kafka1 /opt/kafka/bin/kafka-acls.sh \
  --bootstrap-server localhost:9095 \
  --command-config /dev/stdin \
  --add --allow-principal User:app-consumer \
  --operation Read --operation Describe --topic orders <<'EOF'
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin-secret";
EOF

docker exec -it kafka1 /opt/kafka/bin/kafka-acls.sh \
  --bootstrap-server localhost:9095 \
  --command-config /dev/stdin \
  --add --allow-principal User:app-consumer \
  --operation Read --group orders-group <<'EOF'
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin-secret";
EOF
```
Re-run the Step 4 `ConsumerDemo` command. Expected: it now consumes
successfully (using `ProducerDemo` with `config/admin-superuser.properties` in
another terminal to produce, since `admin` is a super user and bypasses ACLs).

- [ ] **Step 6 (40 min): mTLS lab.** Create
  `kafka_practice/docker/generate-certs.sh`:

```bash
#!/bin/bash
set -e
PASSWORD=kafkapractice
DAYS=365

mkdir -p certs && cd certs

openssl req -new -x509 -keyout ca-key -out ca-cert -days $DAYS \
  -subj "/CN=kafka-practice-ca" -passout pass:$PASSWORD

keytool -keystore broker.keystore.jks -alias broker -validity $DAYS -genkey -keyalg RSA \
  -dname "CN=kafka1" -storepass $PASSWORD -keypass $PASSWORD
keytool -keystore broker.keystore.jks -alias broker -certreq -file broker.csr -storepass $PASSWORD
openssl x509 -req -CA ca-cert -CAkey ca-key -in broker.csr -out broker-signed.crt \
  -days $DAYS -CAcreateserial -passin pass:$PASSWORD
keytool -keystore broker.keystore.jks -alias caroot -import -file ca-cert -storepass $PASSWORD -noprompt
keytool -keystore broker.keystore.jks -alias broker -import -file broker-signed.crt -storepass $PASSWORD -noprompt
keytool -keystore broker.truststore.jks -alias caroot -import -file ca-cert -storepass $PASSWORD -noprompt

keytool -keystore client.keystore.jks -alias client -validity $DAYS -genkey -keyalg RSA \
  -dname "CN=client" -storepass $PASSWORD -keypass $PASSWORD
keytool -keystore client.keystore.jks -alias client -certreq -file client.csr -storepass $PASSWORD
openssl x509 -req -CA ca-cert -CAkey ca-key -in client.csr -out client-signed.crt \
  -days $DAYS -CAcreateserial -passin pass:$PASSWORD
keytool -keystore client.keystore.jks -alias caroot -import -file ca-cert -storepass $PASSWORD -noprompt
keytool -keystore client.keystore.jks -alias client -import -file client-signed.crt -storepass $PASSWORD -noprompt
keytool -keystore client.truststore.jks -alias caroot -import -file ca-cert -storepass $PASSWORD -noprompt

echo "Done. Keystores/truststores are in $(pwd)"
```
Run `chmod +x generate-certs.sh && ./generate-certs.sh`. This CA/keystore
setup is for this lab only — never reuse this password or CA in anything real.
Read (don't necessarily hand-execute) the MSK/Confluent mTLS docs' equivalent
section and note in the journal that the identity model is the same
(certificate CN as principal) even though the tooling differs — a full
broker-listener SSL wiring + client connectivity test is a good stretch
exercise here if time allows, but is not required to hit today's core
objective (understanding mTLS as an authentication mechanism structurally
parallel to SASL/SCRAM).

- [ ] **Step 7 (45 min): Chaos lab — ACL revocation mid-session.** Start
  `ConsumerDemo` against `config/local-sasl.properties` and leave it running.
  In another terminal, revoke the ACL:
```bash
docker exec -it kafka1 /opt/kafka/bin/kafka-acls.sh \
  --bootstrap-server localhost:9095 \
  --command-config /dev/stdin \
  --remove --allow-principal User:app-consumer \
  --operation Read --operation Describe --topic orders --force <<'EOF'
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin-secret";
EOF
```
(Again using port `9095`, the container-internal `SASL_PLAINTEXT` listener —
see the note in Step 5.)
Expected: the running `ConsumerDemo` starts throwing
`TopicAuthorizationException` on its next poll — authorization is checked
per-request, not just at connect time. Diagnose it using:
```bash
docker exec -it kafka1 /opt/kafka/bin/kafka-acls.sh \
  --bootstrap-server localhost:9095 --command-config /dev/stdin --list <<'EOF'
security.protocol=SASL_PLAINTEXT
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin-secret";
EOF
```
Confirm the ACL is gone, re-add it from Step 5, confirm the consumer recovers
without a restart. Write this up as a journal postmortem.

- [ ] **Step 8 (30 min): Phase 1 closed-book review.** Without looking at
  notes, write answers in `journal.md` to:
  - What is ISR, and why does `acks=all` + `min.insync.replicas=2` protect
    against data loss with one broker down but not two?
  - What's the practical difference between eager and cooperative-sticky
    rebalancing?
  - What's the difference between authentication and authorization, in terms
    of which Kafka mechanism does which?
  Then check your answers against the Days 1–4 journal entries and correct
  anything wrong.

- [ ] **Step 9 (10 min): Save point.** Save your work your own way — Days
  6–10 will branch into AWS but this Docker cluster should be left running
  (or easy to bring back up) for Day 9's MirrorMaker2 lab.

---

## Day 6: AWS MSK — provisioning a secured, cost-conscious cluster

**Materials:**
- AWS MSK docs: Getting Started, IAM Access Control for MSK, MSK pricing page
- AWS CLI configured with your personal account credentials (`aws configure`)

**Builds on:** Day 5's security model (SASL/SCRAM+ACLs) — today's IAM auth is
the same authentication+authorization idea, AWS-native.
**Sets up:** Day 7's Connect labs need this cluster and its bootstrap brokers.

- [ ] **Step 1 (20 min): Primer.** Read the MSK Getting Started guide, the IAM
  Access Control page, and the pricing page for `kafka.t3.small` broker-hours
  and storage. Note MSK Serverless as a cost alternative if you'd rather pay
  per-request than per-broker-hour; this plan uses provisioned `kafka.t3.small`
  for direct comparability with Day 5's config knobs (Serverless hides most of
  them).

- [ ] **Step 2 (15 min): Cost guardrail.**
```bash
aws budgets create-budget --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{"BudgetName":"kafka-practice","BudgetLimit":{"Amount":"10","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST"}'
```
This alerts you if the MSK phase runs away in cost — it does not stop
spending on its own. The real guardrail is the Day 10 teardown; treat this as
a smoke detector, not a fire suppressor.

- [ ] **Step 3 (30 min): Networking.**
```bash
aws ec2 describe-vpcs --filters Name=is-default,Values=true --query 'Vpcs[0].VpcId' --output text
# note the VpcId as $VPC_ID, then:
aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC_ID --query 'Subnets[*].[SubnetId,AvailabilityZone]' --output table
# pick 2 subnet IDs in different AZs as $SUBNET_1, $SUBNET_2

MY_IP=$(curl -s https://checkip.amazonaws.com)
aws ec2 create-security-group --group-name msk-lab-sg \
  --description "kafka-practice MSK access" --vpc-id $VPC_ID
# note the returned GroupId as $SG_ID, then:
aws ec2 authorize-security-group-ingress --group-id $SG_ID \
  --protocol tcp --port 9098 --cidr ${MY_IP}/32
```
Port 9098 is the IAM-auth broker port. Cross-check the current port number
against the MSK docs' port reference table if `create-cluster-v2` later
reports connection errors on this port.

- [ ] **Step 4 (45 min): Provision the cluster.** Create
  `kafka_practice/aws/msk-cluster-config.json` (fill in your `$SUBNET_1`,
  `$SUBNET_2`, `$SG_ID` values):

```json
{
  "ClusterName": "kafka-practice-msk",
  "KafkaVersion": "3.7.x",
  "NumberOfBrokerNodes": 2,
  "BrokerNodeGroupInfo": {
    "InstanceType": "kafka.t3.small",
    "ClientSubnets": ["<SUBNET_1>", "<SUBNET_2>"],
    "SecurityGroups": ["<SG_ID>"],
    "StorageInfo": {"EbsStorageInfo": {"VolumeSize": 100}},
    "ConnectivityInfo": {"PublicAccess": {"Type": "SERVICE_PROVIDED_EIPS"}}
  },
  "ClientAuthentication": {
    "Sasl": {"Iam": {"Enabled": true}}
  }
}
```
```bash
aws kafka create-cluster-v2 --cluster-name kafka-practice-msk \
  --provisioned file://kafka_practice/aws/msk-cluster-config.json
```
Verify the exact JSON shape against `aws kafka create-cluster-v2 help` first
if this errors — the MSK CLI schema has changed across versions.
`PublicAccess.Type: SERVICE_PROVIDED_EIPS` is what lets you reach this cluster
directly from your laptop rather than needing a VPN or bastion host; it
requires (and gets, since you picked default-VPC subnets) subnets with a route
to an internet gateway. Provisioning takes 15–20 minutes.

- [ ] **Step 5 (30 min, while the cluster provisions): Draft the IAM policy.**
  Create `kafka_practice/aws/iam-policy.json` (fill in your account ID/region
  once you have the cluster ARN from Step 6):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "kafka-cluster:Connect",
        "kafka-cluster:DescribeCluster",
        "kafka-cluster:AlterCluster",
        "kafka-cluster:*Topic*",
        "kafka-cluster:WriteData",
        "kafka-cluster:ReadData",
        "kafka-cluster:AlterGroup",
        "kafka-cluster:DescribeGroup"
      ],
      "Resource": "arn:aws:kafka:<REGION>:<ACCOUNT_ID>:cluster/kafka-practice-msk/*"
    }
  ]
}
```
Compare this against Day 5's ACL grants (`--operation Read --topic orders`,
etc.) — same shape, principal + resource + allowed operations, different
syntax.

- [ ] **Step 6 (20 min): Attach the policy, get bootstrap brokers.**
```bash
aws kafka describe-cluster-v2 --cluster-arn <CLUSTER_ARN> --query 'ClusterInfo.State'
# wait for "ACTIVE"
aws kafka get-bootstrap-brokers --cluster-arn <CLUSTER_ARN>
# note the "BootstrapBrokerStringSaslIam" value

aws iam put-user-policy --user-name <YOUR_IAM_USER> \
  --policy-name kafka-practice-msk-access \
  --policy-document file://kafka_practice/aws/iam-policy.json
```

- [ ] **Step 7 (45 min): Connect from the Java lab project.** Create
  `kafka_practice/labs/config/msk-iam.properties` (using the bootstrap string
  from Step 6):
```properties
bootstrap.servers=<BootstrapBrokerStringSaslIam>
security.protocol=SASL_SSL
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
```
Create the topic (the `kafka-topics.sh` CLI needs the same IAM auth config —
either run it from an EC2 instance in the VPC, or use the same
`msk-iam.properties`-equivalent `--command-config` locally if you have the
Kafka CLI tools installed outside Docker):
```bash
kafka-topics.sh --bootstrap-server <BootstrapBrokerStringSaslIam> \
  --command-config kafka_practice/labs/config/msk-iam.properties \
  --create --topic orders --partitions 6 --replication-factor 2
```
Then run the same `ProducerDemo`/`ConsumerDemo` classes from Days 2–3,
unmodified, just pointed at the new config:
```bash
mvn -q compile exec:java -Dexec.mainClass=com.kafkapractice.ProducerDemo \
  -Dexec.args="config/msk-iam.properties orders"
```
Expected: same partition/offset output as Day 2, now against MSK. This is the
DRY payoff from Day 2's config-file design — zero new client code needed to
move environments.

- [ ] **Step 8 (20 min): Journal entry + save point.**

---

## Day 7: Kafka Connect & integration patterns on MSK

**Materials:**
- AWS MSK Connect docs, AWS Glue Schema Registry docs
- Kafka Connect concepts doc (source/sink connectors, converters)

**Builds on:** Day 6's cluster.
**Sets up:** Day 12 repeats this with Confluent's fully-managed Connect for a
direct comparison.

- [ ] **Step 1 (20 min): Primer.** Read Kafka Connect's architecture doc
  (source vs. sink connectors, converters, standalone vs. distributed
  workers) and MSK Connect's specifics (custom plugins via S3, IAM roles per
  connector). This is the core skill for an integration team: connectors are
  how external systems get wired to Kafka without hand-written client code.

- [ ] **Step 2 (20 min): Schema registry.**
```bash
aws glue create-registry --registry-name kafka-practice-registry
```
Low request volume here stays within Glue's free tier.

- [ ] **Step 3 (60 min): Source connector — Datagen (no external DB needed).**
  Download the `kafka-connect-datagen` connector plugin, zip it, and upload to
  a new S3 bucket:
```bash
aws s3 mb s3://kafka-practice-connect-plugins-<yourname>
# download the datagen connector release zip per its GitHub releases page, then:
aws s3 cp kafka-connect-datagen.zip s3://kafka-practice-connect-plugins-<yourname>/
aws kafkaconnect create-custom-plugin \
  --name kafka-practice-datagen \
  --content-type ZIP \
  --location s3Location='{bucketArn=arn:aws:s3:::kafka-practice-connect-plugins-<yourname>,fileKey=kafka-connect-datagen.zip}'
```
Create an IAM role for the connector granting `kafka-cluster:*` scoped to your
cluster ARN plus `glue:*Schema*` for registry access (mirror Step 5's Day 6
policy pattern), then create
`kafka_practice/aws/datagen-connector.json` with the worker configuration
(bootstrap servers, IAM auth config block, plugin ARN, and the datagen
connector's `quickstart=orders` setting), and:
```bash
aws kafkaconnect create-connector --cli-input-json file://kafka_practice/aws/datagen-connector.json
```
Verify the exact JSON shape against `aws kafkaconnect create-connector help`
first — MSK Connect's request schema has several nested required blocks
(capacity, kafkaCluster, kafkaConnectVersion) not shown above for brevity.

- [ ] **Step 4 (30 min): Verify the source connector.**
```bash
kafka-topics.sh --bootstrap-server <BootstrapBrokerStringSaslIam> \
  --command-config kafka_practice/labs/config/msk-iam.properties --list
```
Expected: a new topic matching the datagen connector's configured output.
Consume a few records from it via `ConsumerDemo` pointed at
`config/msk-iam.properties` and that topic name — confirm fake order records
are flowing in without any producer code of your own running.

- [ ] **Step 5 (60 min): Sink connector — S3.** Create an S3 bucket for sink
  output, an IAM role granting the connector `s3:PutObject` on it plus the
  same Kafka/Glue access pattern as Step 3, then
  `kafka_practice/aws/s3-sink-connector.json` configuring the (Apache
  2.0-licensed) S3 sink connector plugin, pointed at the `orders` topic from
  Day 6:
```bash
aws kafkaconnect create-connector --cli-input-json file://kafka_practice/aws/s3-sink-connector.json
```
Produce a few messages to `orders` via `ProducerDemo` (`config/msk-iam.properties`),
wait for the connector's flush interval (a few minutes by default), then:
```bash
aws s3 ls s3://<your-sink-bucket>/ --recursive
```
Expected: at least one object; download and inspect it — it should contain the
records you just produced.

- [ ] **Step 6 (20 min): Schema registry integration.** Reconfigure either
  connector's `value.converter` to `AWSKafkaAvroConverter` referencing the Glue
  registry from Step 2, produce again, then:
```bash
aws glue get-schema-versions --schema-id SchemaName=<topic-name>,RegistryName=kafka-practice-registry
```
Expected: at least one registered schema version, confirming the
converter successfully registered a schema on write.

- [ ] **Step 7 (20 min): Journal entry + save point.**

---

## Day 8: Monitoring & operations on MSK

**Materials:**
- MSK monitoring docs: Enhanced Monitoring, Open Monitoring with Prometheus
- Kafka JMX metrics reference

**Builds on:** Day 6's cluster, Day 7's connector traffic.
**Sets up:** Day 9 needs monitoring already wired up to observe the DR/scaling
chaos lab's effects live rather than only via CLI.

- [ ] **Step 1 (20 min): Primer.** Read the monitoring docs. Note the metrics
  you'll wire alerts on today: `UnderReplicatedPartitions`,
  `OfflinePartitionsCount`, `BytesInPerSec`/`BytesOutPerSec`, `MaxOffsetLag`
  (per consumer group), `KafkaDataLogsDiskUsed`.

- [ ] **Step 2 (30 min): Enable enhanced + open monitoring.**
```bash
aws kafka update-monitoring --cluster-arn <CLUSTER_ARN> \
  --current-version <CURRENT_VERSION> \
  --enhanced-monitoring PER_TOPIC_PER_PARTITION \
  --open-monitoring '{"Prometheus":{"JmxExporter":{"EnabledInBroker":true},"NodeExporter":{"EnabledInBroker":true}}}'
```
Get `<CURRENT_VERSION>` from `aws kafka describe-cluster-v2` first — MSK
requires it to detect concurrent modification.

- [ ] **Step 3 (30 min): CloudWatch dashboard.**
```bash
aws cloudwatch put-dashboard --dashboard-name kafka-practice-msk \
  --dashboard-body file://kafka_practice/aws/dashboard-body.json
```
Author `dashboard-body.json` with widgets for the Step 1 metrics, scoped via
the `Cluster Name` dimension to `kafka-practice-msk`. Cross-check the exact
widget JSON schema against an existing CloudWatch dashboard export from the
console if this errors — it's easier to build one widget in the console UI
first and export its JSON than to hand-write the schema from scratch.

- [ ] **Step 4 (30 min): Alerting.**
```bash
aws cloudwatch put-metric-alarm --alarm-name msk-under-replicated \
  --namespace AWS/Kafka --metric-name UnderReplicatedPartitions \
  --dimensions Name="Cluster Name",Value=kafka-practice-msk \
  --statistic Maximum --period 60 --evaluation-periods 1 \
  --threshold 0 --comparison-operator GreaterThanThreshold

aws cloudwatch put-metric-alarm --alarm-name msk-consumer-lag \
  --namespace AWS/Kafka --metric-name MaxOffsetLag \
  --dimensions Name="Cluster Name",Value=kafka-practice-msk Name="Consumer Group",Value=orders-group \
  --statistic Maximum --period 60 --evaluation-periods 1 \
  --threshold 1000 --comparison-operator GreaterThanThreshold
```
Optionally wire both to an SNS topic you subscribe your own email to
(`aws sns create-topic` + `aws sns subscribe` + `--alarm-actions` on the
alarms above) so you get a real page, not just a console indicator.

- [ ] **Step 5 (45 min): Generate load, cross-check CLI vs. dashboard.** Run
  `ProducerLoop` against MSK at a higher rate:
```bash
mvn -q compile exec:java -Dexec.mainClass=com.kafkapractice.ProducerLoop \
  -Dexec.args="config/msk-iam.properties orders 200"
```
In another terminal, loop the CLI lag check every 5 seconds:
```bash
watch -n 5 'kafka-consumer-groups.sh --bootstrap-server <BootstrapBrokerStringSaslIam> \
  --command-config kafka_practice/labs/config/msk-iam.properties \
  --describe --group orders-group'
```
Open the CloudWatch dashboard from Step 3 side by side. Expected: the CLI's
`LAG` column and the dashboard's `MaxOffsetLag` widget track each other,
within the CloudWatch metric's ~1-minute granularity. Write in the journal why
you'd trust the CLI over the dashboard during an active incident (lower
latency, no dashboard refresh delay) but the dashboard over the CLI for
historical/trend analysis.

- [ ] **Step 6 (30 min): Capacity planning, pen-and-paper.** Using the
  `BytesInPerSec` value observed in Step 5, calculate: at this throughput,
  sustained continuously, how many days until a 100 GB broker volume (from
  Day 6's `StorageInfo`) fills up, given `retention.ms` defaults to 7 days? Is
  100 GB enough headroom, or would you need to shorten retention or grow
  storage first? Write the arithmetic and conclusion in the journal — this is
  a direct CCAAK-style capacity-planning question.

- [ ] **Step 7 (20 min): Journal entry + save point.**

---

## Day 9: Multi-region DR & scaling — chaos lab: broker failure

**Materials:**
- MirrorMaker2 docs (KIP-382)
- MSK docs: rebooting brokers, updating broker count/storage

**Builds on:** Day 6's MSK cluster as the MirrorMaker2 *source*; Day 1–5's
Docker cluster as the *target* (avoids paying for a second MSK cluster).
**Sets up:** Day 10's review covers this alongside Days 6–8.

- [ ] **Step 1 (20 min): Primer.** Read the MirrorMaker2 docs: cluster
  aliasing, the default topic-renaming convention (`<source-alias>.<topic>`),
  offset translation, and consumer-group replication.

- [ ] **Step 2 (15 min): Bring the Docker cluster back up if it's down.**
```bash
cd kafka_practice/docker && docker compose up -d && docker compose ps
```
Expected: all 3 containers `Up` again, same topics as Day 5 (data persists in
the named Docker volume unless you ran `down -v`).

- [ ] **Step 3 (40 min): Configure MirrorMaker2.** Create
  `kafka_practice/mm2/mm2.properties`:
```properties
clusters=msk,docker

msk.bootstrap.servers=<BootstrapBrokerStringSaslIam>
msk.security.protocol=SASL_SSL
msk.sasl.mechanism=AWS_MSK_IAM
msk.sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
msk.sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler

docker.bootstrap.servers=localhost:29095
docker.security.protocol=SASL_PLAINTEXT
docker.sasl.mechanism=SCRAM-SHA-256
docker.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="admin-secret";

msk->docker.enabled=true
msk->docker.topics=orders
docker->msk.enabled=false

replication.factor=1
```
Run it (needs the Kafka distribution's `connect-mirror-maker.sh`, either from
a local unpacked Kafka install matching `kafka.version` in `pom.xml`, or via
`docker run` against the `apache/kafka` image with this file mounted in):
```bash
connect-mirror-maker.sh kafka_practice/mm2/mm2.properties
```

- [ ] **Step 4 (30 min): Verify replication.** With MirrorMaker2 running,
  produce to `orders` on MSK (`ProducerDemo` with `config/msk-iam.properties`),
  then:
```bash
docker exec -it kafka1 /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic msk.orders --from-beginning
```
No `--consumer.config` is needed here: port `9092` inside the container is
the plain `PLAINTEXT` listener, and Day 5's Step 2 made `User:ANONYMOUS` a
superuser over that listener specifically so this kind of quick admin-side
read works without juggling SASL credentials. (Passing SASL properties
against port `9092` would fail — that listener doesn't speak SASL at all; the
`SASL_PLAINTEXT` listener is on `9095`/`29095`, used everywhere a real client
identity matters, as in Day 5 Steps 4–7.)
Expected: the same messages you produced to MSK's `orders` topic, now
appearing on the Docker cluster's auto-created `msk.orders` topic.

- [ ] **Step 5 (40 min): Chaos lab — broker failure during replication.**
```bash
aws kafka list-nodes --cluster-arn <CLUSTER_ARN>
# note a broker id, then:
aws kafka reboot-broker --cluster-arn <CLUSTER_ARN> --broker-ids <BROKER_ID>
```
While the reboot is in progress, watch:
```bash
watch -n 5 'kafka-topics.sh --bootstrap-server <BootstrapBrokerStringSaslIam> \
  --command-config kafka_practice/labs/config/msk-iam.properties --describe --topic orders'
```
Expected: transient under-replication on partitions led by the rebooting
broker, and MirrorMaker2's own internal consumer group lag ticks up briefly
(check via `kafka-consumer-groups.sh --describe --group
<mirrormaker-group-id>` against MSK) but does not stop or error out. Confirm
it self-heals once the broker is back — no manual restart of MirrorMaker2
needed.

- [ ] **Step 6 (30 min): Scale-up exercise.**
```bash
kafka-topics.sh --bootstrap-server <BootstrapBrokerStringSaslIam> \
  --command-config kafka_practice/labs/config/msk-iam.properties \
  --alter --topic orders --partitions 12
```
Expected: `ConsumerDemo`/MirrorMaker2 pick up the new partitions on their next
rebalance, no restart required. Then, without executing it (cost), read the
`aws kafka update-broker-count` doc page and write in the journal why adding
partitions is usually the first scaling lever tried (near-instant, no data
migration) versus adding brokers (requires partition reassignment to actually
rebalance load onto the new broker).

- [ ] **Step 7 (30 min): Rolling upgrade concept.** Read MSK's broker-update
  doc section on one-broker-at-a-time rolling updates. Write a journal
  paragraph explaining why `min.insync.replicas=2` with replication factor 3
  (or here, 2 with RF matching your Day 6 topic config) is exactly the
  mechanism that makes a rolling upgrade safe — connecting directly back to
  Day 4's chaos labs.

- [ ] **Step 8 (20 min): Journal entry + save point.**

---

## Day 10: Phase 2 review + full AWS teardown

**Materials:** `journal.md` entries for Days 6–9.

**Builds on:** Days 6–9.
**Sets up:** nothing further needs AWS after today.

- [ ] **Step 1 (30 min): Journal pass.** Re-derive every "what confused me"
  item from Days 6–9, closed-book, before moving on.

- [ ] **Step 2 (90 min): Closed-book mixed review.** From memory, write in
  `journal.md`:
  - The specific IAM actions needed for a client to produce and consume
    (compare against your Day 6 policy).
  - What each of `UnderReplicatedPartitions`, `OfflinePartitionsCount`,
    `MaxOffsetLag`, `KafkaDataLogsDiskUsed` indicates when it's non-zero/high.
  - How MirrorMaker2 names replicated topics and why offset translation is
    needed at all (source and target offsets for "the same" message differ).
  - Why MSK's public access mode requires a TLS-based auth mechanism (IAM or
    TLS client certs) rather than allowing plaintext.
  Then check against Days 6–9 and correct anything wrong by rewriting it by
  hand.

- [ ] **Step 3 (20 min): CCAAK domain self-check.** Map today's review against
  the domain table from the spec (`kafka_practice/docs/superpowers/specs/2026-07-09-kafka-15-day-plan-design.md`):
  cluster config/deployment, security, monitoring, Connect, multi-cluster/DR.
  For any domain that felt shaky just now, note it explicitly — Day 15's gap
  analysis will come back to this note.

- [ ] **Step 4 (60 min): Full AWS teardown — do this in order.**
```bash
aws kafkaconnect list-connectors --query 'connectors[?contains(connectorName,`kafka-practice`)]'
# for each connector ARN returned:
aws kafkaconnect delete-connector --connector-arn <CONNECTOR_ARN>
# wait for deletion, then:
aws kafkaconnect list-custom-plugins --query 'customPlugins[?contains(name,`kafka-practice`)]'
# for each plugin ARN:
aws kafkaconnect delete-custom-plugin --custom-plugin-arn <PLUGIN_ARN>

aws kafka delete-cluster --cluster-arn <CLUSTER_ARN>

aws s3 rm s3://kafka-practice-connect-plugins-<yourname> --recursive
aws s3 rb s3://kafka-practice-connect-plugins-<yourname>
aws s3 rm s3://<your-sink-bucket> --recursive
aws s3 rb s3://<your-sink-bucket>

aws glue delete-registry --registry-id RegistryName=kafka-practice-registry

aws cloudwatch delete-alarms --alarm-names msk-under-replicated msk-consumer-lag
aws cloudwatch delete-dashboards --dashboard-names kafka-practice-msk
aws sns delete-topic --topic-arn <SNS_TOPIC_ARN>   # if you created one on Day 8

aws ec2 delete-security-group --group-id $SG_ID
```
Verify nothing billable remains:
```bash
aws kafka list-clusters-v2 --query 'ClusterInfoList[?clusterName==`kafka-practice-msk`]'
aws s3 ls | grep kafka-practice
```
Expected: both return empty. Leave the AWS Budget from Day 6 in place — it's
free and harmless to keep watching your account.

- [ ] **Step 5 (20 min): Journal entry + save point.** Confirm the teardown
  checklist above is fully checked off before ending the day.

---

## Day 11: Confluent Cloud — comparative cluster admin (RBAC vs. IAM/ACLs)

**Materials:**
- Confluent Cloud docs: Quick Start, Role-Based Access Control
- Confluent CLI installed and authenticated (`confluent login`)

**Builds on:** Day 5's ACLs and Day 6's IAM policies — today adds a third
mechanism for the same underlying problem.
**Sets up:** Day 12 needs this running cluster for Schema Registry/Connect.

- [ ] **Step 1 (20 min): Primer.** Read the RBAC doc. Note the predefined
  roles you'll use today: `CloudClusterAdmin` (full cluster control),
  `DeveloperRead`/`DeveloperWrite` (scoped to specific topics/groups).

- [ ] **Step 2 (20 min): Create environment + cluster.**
```bash
confluent login
confluent environment create kafka-practice
confluent environment use <ENV_ID>
confluent kafka cluster create kafka-practice-basic \
  --cloud aws --region us-east-1 --type basic
confluent kafka cluster use <CLUSTER_ID>
```
`type basic` is Confluent Cloud's cheapest pay-as-you-go tier — check your
free-tier credit balance via the Billing page in the console right after
creating this, and again after each subsequent Confluent day.

- [ ] **Step 3 (20 min): API key.**
```bash
confluent api-key create --resource <CLUSTER_ID>
confluent api-key use <API_KEY> --resource <CLUSTER_ID>
```

- [ ] **Step 4 (30 min): Topic + CLI produce/consume.**
```bash
confluent kafka topic create orders --partitions 6
confluent kafka topic produce orders
# type a few lines, Ctrl+D, then:
confluent kafka topic consume orders --from-beginning
```
Expected: the lines you typed appear.

- [ ] **Step 5 (40 min): RBAC lab.**
```bash
confluent iam service-account create app-consumer-sa \
  --description "kafka-practice least-privilege consumer"
# note the returned service account id as $SA_ID
confluent iam rbac role-binding create --principal User:$SA_ID \
  --role DeveloperRead --resource Topic:orders --cluster $CLUSTER_ID
confluent iam rbac role-binding create --principal User:$SA_ID \
  --role DeveloperRead --resource Group:orders-group --cluster $CLUSTER_ID
confluent api-key create --resource $CLUSTER_ID --service-account $SA_ID
```
Create `kafka_practice/labs/config/confluent-app-consumer.properties` using
the new API key/secret (Confluent's cluster settings page or
`confluent kafka cluster describe` gives the bootstrap endpoint):
```properties
bootstrap.servers=<CLUSTER_BOOTSTRAP_ENDPOINT>
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="<APP_CONSUMER_API_KEY>" password="<APP_CONSUMER_API_SECRET>";
```
Run `ConsumerDemo` against it: expected success (read-only granted). Then run
`ProducerDemo` against the same config: expected `TopicAuthorizationException`
— `DeveloperRead` doesn't include write.

- [ ] **Step 6 (30 min): Three-way comparison, teach-it-back.** Write a table
  in `journal.md`: Kafka ACLs (Day 5) vs. AWS IAM policies (Day 6) vs.
  Confluent RBAC (today) — same underlying model (principal + resource +
  permission), three different systems/syntaxes. This is the kind of
  consolidation exercise that turns three separate memorized procedures into
  one transferable concept.

- [ ] **Step 7 (20 min): Journal entry + save point.**

---

## Day 12: Schema Registry & fully-managed Kafka Connect on Confluent

**Materials:**
- Confluent Schema Registry docs: compatibility modes, Avro schema evolution
- Confluent-managed connectors catalog

**Builds on:** Day 11's cluster; Day 7's MSK Connect/Glue experience for
direct comparison.
**Sets up:** Day 13's Streams app consumes the Avro data produced today.

- [ ] **Step 1 (20 min): Primer.** Read the compatibility-modes doc
  (`BACKWARD`, `FORWARD`, `FULL`) and Avro's evolution rules: adding a field
  requires a default value; removing a required field breaks `BACKWARD`
  compatibility.

- [ ] **Step 2 (20 min): Enable Schema Registry.**
```bash
confluent schema-registry cluster enable --cloud aws --region us-east-1
confluent schema-registry cluster describe
# note the endpoint URL
confluent api-key create --resource <SCHEMA_REGISTRY_ID>
```
Create `kafka_practice/labs/config/confluent-sr.properties` (extends
`confluent.properties`-style auth from Day 11, plus):
```properties
bootstrap.servers=<CLUSTER_BOOTSTRAP_ENDPOINT>
security.protocol=SASL_SSL
sasl.mechanism=PLAIN
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="<API_KEY>" password="<API_SECRET>";
schema.registry.url=<SCHEMA_REGISTRY_ENDPOINT>
basic.auth.credentials.source=USER_INFO
schema.registry.basic.auth.user.info=<SR_API_KEY>:<SR_API_SECRET>
```

- [ ] **Step 3 (30 min): Define and register the schema.** Create
  `kafka_practice/labs/schemas/orders-value.avsc`:
```json
{
  "type": "record",
  "name": "Order",
  "namespace": "com.kafkapractice.avro",
  "fields": [
    {"name": "orderId", "type": "string"},
    {"name": "customerId", "type": "string"},
    {"name": "amount", "type": "double"}
  ]
}
```
```bash
confluent schema-registry schema create --subject orders-value \
  --schema kafka_practice/labs/schemas/orders-value.avsc --type avro
```

- [ ] **Step 4 (45 min): Avro producer.** Create
  `kafka_practice/labs/src/main/java/com/kafkapractice/AvroProducerDemo.java`:

```java
package com.kafkapractice;

import io.confluent.kafka.serializers.KafkaAvroSerializer;
import org.apache.avro.Schema;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.apache.kafka.common.serialization.StringSerializer;

import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Properties;
import java.util.Random;

public class AvroProducerDemo {
    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/confluent-sr.properties";
        String topic = args.length > 1 ? args[1] : "orders";
        String schemaPath = args.length > 2 ? args[2] : "schemas/orders-value.avsc";

        Schema schema = new Schema.Parser().parse(new String(Files.readAllBytes(Paths.get(schemaPath))));

        Properties props = KafkaClientConfig.load(configPath);
        props.put("key.serializer", StringSerializer.class.getName());
        props.put("value.serializer", KafkaAvroSerializer.class.getName());
        props.put("acks", "all");

        Random random = new Random();
        try (KafkaProducer<String, GenericRecord> producer = new KafkaProducer<>(props)) {
            for (int i = 0; i < 30; i++) {
                String customerId = "customer-" + (1 + random.nextInt(3));
                GenericRecord order = new GenericData.Record(schema);
                order.put("orderId", "order-" + i);
                order.put("customerId", customerId);
                order.put("amount", 10.0 + random.nextInt(90));

                RecordMetadata metadata = producer.send(new ProducerRecord<>(topic, customerId, order)).get();
                System.out.printf("customerId=%s -> partition=%d offset=%d%n",
                        customerId, metadata.partition(), metadata.offset());
                Thread.sleep(500);
            }
        }
    }
}
```
Run:
```bash
mvn -q compile exec:java -Dexec.mainClass=com.kafkapractice.AvroProducerDemo \
  -Dexec.args="config/confluent-sr.properties orders schemas/orders-value.avsc"
```
Expected: 30 lines of partition/offset output, and a new registered schema
version visible via `confluent schema-registry schema describe --subject
orders-value --version latest`.

- [ ] **Step 5 (30 min): Schema evolution exercise.** Edit
  `orders-value.avsc`, adding a field with a default:
```json
    {"name": "discountCode", "type": "string", "default": ""}
```
```bash
confluent schema-registry schema create --subject orders-value \
  --schema kafka_practice/labs/schemas/orders-value.avsc --type avro
```
Expected: succeeds (BACKWARD-compatible — old consumers reading new data just
see the default). Now try removing the required `amount` field entirely (no
default) and re-registering. Expected: rejected by the compatibility check.
Revert to the version with `discountCode` added. Write in the journal why the
first change was safe and the second wasn't, in terms of what an old consumer
expecting `amount` would do in each case.

- [ ] **Step 6 (40 min): Fully-managed connector.**
```bash
confluent connect cluster create --config-file kafka_practice/aws/datagen-connector-confluent.json \
  --cluster <CLUSTER_ID>
```
Author `datagen-connector-confluent.json` picking the Confluent-managed
"Datagen Source" connector from the catalog (`confluent connect plugin list`
to see available connector class names) with `kafka.topic=orders-datagen` and
a built-in quickstart template (e.g. `orders`). Verify with
`confluent connect cluster describe <CONNECTOR_ID>` that it reaches `RUNNING`,
then consume from `orders-datagen` to confirm data is flowing. In the journal,
compare this against Day 7's MSK Connect flow: no custom plugin packaging, no
IAM role wiring for the connector itself — the trade-off of a managed
connector catalog versus MSK Connect's more hands-on plugin model.

- [ ] **Step 7 (20 min): Journal entry + save point.**

---

## Day 13: Kafka Streams + ksqlDB — Phase 3 review — Confluent teardown

**Materials:**
- Kafka Streams docs: `KStream`/`KTable`, windowing (`TimeWindows`)
- ksqlDB docs: `CREATE TABLE ... WINDOW TUMBLING`

**Builds on:** Day 12's Avro `orders` topic.
**Sets up:** Day 14's capstone reuses this windowed-aggregation pattern,
adapted to run without a cloud Schema Registry.

- [ ] **Step 1 (20 min): Primer.** Read the `KStream` vs. `KTable` doc section
  and the windowing doc's grace-period explanation (why a window needs to stay
  "open" briefly after its nominal end, to admit slightly late records).

- [ ] **Step 2 (60 min): Windowed aggregation Streams app.** Create
  `kafka_practice/labs/src/main/java/com/kafkapractice/OrderAggregationStreamsApp.java`:

```java
package com.kafkapractice;

import io.confluent.kafka.streams.serdes.avro.GenericAvroSerde;
import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.KeyValue;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.Topology;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.Materialized;
import org.apache.kafka.streams.kstream.Produced;
import org.apache.kafka.streams.kstream.TimeWindows;
import org.apache.kafka.streams.kstream.Windowed;

import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class OrderAggregationStreamsApp {
    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/confluent-sr.properties";
        String inputTopic = args.length > 1 ? args[1] : "orders";
        String outputTopic = args.length > 2 ? args[2] : "customer-spend-per-minute";

        Properties props = KafkaClientConfig.load(configPath);
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, "order-aggregation-app");
        props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass());

        GenericAvroSerde avroSerde = new GenericAvroSerde();
        avroSerde.configure(
                Collections.singletonMap("schema.registry.url", props.getProperty("schema.registry.url")),
                false
        );

        StreamsBuilder builder = new StreamsBuilder();
        KStream<String, GenericRecord> orders = builder.stream(inputTopic, Consumed.with(Serdes.String(), avroSerde));

        KStream<String, Double> spendPerMinute = orders
                .groupByKey()
                .windowedBy(TimeWindows.ofSizeAndGrace(Duration.ofMinutes(1), Duration.ofSeconds(10)))
                .aggregate(
                        () -> 0.0,
                        (customerId, order, total) -> total + (double) order.get("amount"),
                        Materialized.with(Serdes.String(), Serdes.Double())
                )
                .toStream()
                .map((Windowed<String> windowedKey, Double total) -> KeyValue.pair(windowedKey.key(), total));

        spendPerMinute.to(outputTopic, Produced.with(Serdes.String(), Serdes.Double()));

        Topology topology = builder.build();
        System.out.println(topology.describe());

        try (KafkaStreams streams = new KafkaStreams(topology, props)) {
            Runtime.getRuntime().addShutdownHook(new Thread(streams::close));
            streams.start();
            Thread.sleep(Long.MAX_VALUE);
        }
    }
}
```
Run:
```bash
mvn -q compile exec:java -Dexec.mainClass=com.kafkapractice.OrderAggregationStreamsApp \
  -Dexec.args="config/confluent-sr.properties orders customer-spend-per-minute"
```
Expected: the printed topology, then a running app with no output yet (needs
input traffic — next step).

- [ ] **Step 3 (30 min): Feed it and verify.** In another terminal, loop
  `AvroProducerDemo` (re-run its command a few times over 2-3 minutes so
  windows actually close), then consume the output:
```bash
confluent kafka topic consume customer-spend-per-minute --from-beginning
```
Expected: roughly one aggregated total per active `customerId` per elapsed
minute.

- [ ] **Step 4 (30 min): ksqlDB comparison.**
```bash
confluent ksql cluster create kafka-practice-ksql --cluster <CLUSTER_ID> --csu 1
confluent ksql cluster use <KSQL_CLUSTER_ID>
```
In the ksqlDB CLI/console, define the same logic declaratively:
```sql
CREATE STREAM orders_stream (orderId VARCHAR, customerId VARCHAR, amount DOUBLE)
  WITH (KAFKA_TOPIC='orders', VALUE_FORMAT='AVRO');

CREATE TABLE customer_spend_per_minute AS
  SELECT customerId, SUM(amount) AS total_amount
  FROM orders_stream
  WINDOW TUMBLING (SIZE 1 MINUTE)
  GROUP BY customerId
  EMIT CHANGES;
```
Expected: `customer_spend_per_minute` produces results matching (up to timing/
window-boundary differences) the Java Streams app's output. In the journal,
note when you'd reach for each: ksqlDB for fast iteration/exploration and
simple pipelines, Java Streams when you need custom logic, testability, or
tighter integration with existing Java services.

- [ ] **Step 5 (30 min): Phase 3 closed-book review.** From memory, write:
  `KStream` vs. `KTable` in one sentence each; why windowed aggregations need
  a grace period; the three-way ACL/IAM/RBAC comparison from Day 11. Check
  against the journal afterward.

- [ ] **Step 6 (45 min): Full Confluent Cloud teardown.**
```bash
confluent ksql cluster delete <KSQL_CLUSTER_ID>
confluent connect cluster delete <CONNECTOR_ID>
confluent kafka cluster delete <CLUSTER_ID>
confluent environment delete <ENV_ID>
confluent api-key delete <API_KEY> <APP_CONSUMER_API_KEY> <SR_API_KEY>
```
Verify:
```bash
confluent kafka cluster list
confluent environment list
```
Expected: the `kafka-practice*` resources no longer appear. Check the Billing/
usage page in the console to confirm no unexpected residual charge.

- [ ] **Step 7 (20 min): Journal entry + save point.**

---

## Day 14: Capstone — end-to-end integration pipeline (local Docker)

**Materials:** `journal.md` Days 1–13; the Day 1–5 Docker cluster.

**Builds on:** everything so far.
**Sets up:** Day 15's exam draws scenario questions from this pipeline.

- [ ] **Step 1 (20 min): Bring the cluster back up.**
```bash
cd kafka_practice/docker && docker compose up -d && docker compose ps
```
Expected: all 3 brokers `Up`, SASL/ACL config from Day 5 still active (it's
the same compose file, not reverted).

- [ ] **Step 2 (30 min): Design doc, written before any code.** In
  `journal.md`, sketch the pipeline: `ProducerLoop` (Day 3) → secured `orders`
  topic (Day 5) → a windowed-aggregation Streams app (pattern from Day 13,
  adapted below since Confluent's Schema Registry no longer exists after Day
  13's teardown) → a new file-sink consumer → `capstone-output.jsonl`.
  Annotate each arrow with the day/concept it exercises (partitioning, ACLs,
  windowed aggregation, manual offset commits).

- [ ] **Step 3 (60 min): Streams app without a cloud Schema Registry.** Day
  13's `OrderAggregationStreamsApp` requires Confluent's Avro Schema Registry,
  which was torn down. Create a plain-JSON variant instead of resurrecting
  cloud infrastructure for one lab: `kafka_practice/labs/src/main/java/com/kafkapractice/CapstoneStreamsApp.java`:

```java
package com.kafkapractice;

import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.KeyValue;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.Topology;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.Materialized;
import org.apache.kafka.streams.kstream.Produced;
import org.apache.kafka.streams.kstream.TimeWindows;
import org.apache.kafka.streams.kstream.Windowed;

import java.time.Duration;
import java.util.Properties;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class CapstoneStreamsApp {
    private static final Pattern AMOUNT_PATTERN = Pattern.compile("\"amount\":(\\d+)");

    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/local-sasl.properties";
        String inputTopic = args.length > 1 ? args[1] : "orders";
        String outputTopic = args.length > 2 ? args[2] : "customer-spend-per-minute";

        Properties props = KafkaClientConfig.load(configPath);
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, "capstone-streams-app");
        props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass());
        props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass());

        StreamsBuilder builder = new StreamsBuilder();
        KStream<String, String> orders = builder.stream(inputTopic);

        KStream<String, Double> spendPerMinute = orders
                .mapValues(CapstoneStreamsApp::extractAmount)
                .groupByKey()
                .windowedBy(TimeWindows.ofSizeAndGrace(Duration.ofMinutes(1), Duration.ofSeconds(10)))
                .aggregate(
                        () -> 0.0,
                        (key, amount, total) -> total + amount,
                        Materialized.with(Serdes.String(), Serdes.Double())
                )
                .toStream()
                .map((Windowed<String> windowedKey, Double total) -> KeyValue.pair(windowedKey.key(), total));

        spendPerMinute.to(outputTopic, Produced.with(Serdes.String(), Serdes.Double()));

        Topology topology = builder.build();
        System.out.println(topology.describe());

        try (KafkaStreams streams = new KafkaStreams(topology, props)) {
            Runtime.getRuntime().addShutdownHook(new Thread(streams::close));
            streams.start();
            Thread.sleep(Long.MAX_VALUE);
        }
    }

    private static double extractAmount(String json) {
        Matcher matcher = AMOUNT_PATTERN.matcher(json);
        return matcher.find() ? Double.parseDouble(matcher.group(1)) : 0.0;
    }
}
```
This groups by the message *key* (the `order-1`/`order-2`/`order-3` values
`ProducerLoop` already produces), reusing the exact JSON shape from Day 2–3
rather than introducing a new schema.

- [ ] **Step 4 (30 min): File-sink consumer.** Create
  `kafka_practice/labs/src/main/java/com/kafkapractice/FileSinkConsumer.java`:

```java
package com.kafkapractice;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.DoubleDeserializer;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.io.FileWriter;
import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class FileSinkConsumer {
    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/local-sasl.properties";
        String topic = args.length > 1 ? args[1] : "customer-spend-per-minute";
        String outputPath = args.length > 2 ? args[2] : "capstone-output.jsonl";

        Properties props = KafkaClientConfig.load(configPath);
        props.put("key.deserializer", StringDeserializer.class.getName());
        props.put("value.deserializer", DoubleDeserializer.class.getName());
        props.put("group.id", "capstone-file-sink");
        props.put("enable.auto.commit", "false");
        props.put("auto.offset.reset", "earliest");

        try (KafkaConsumer<String, Double> consumer = new KafkaConsumer<>(props);
             FileWriter writer = new FileWriter(outputPath, true)) {
            consumer.subscribe(Collections.singletonList(topic));
            while (true) {
                ConsumerRecords<String, Double> records = consumer.poll(Duration.ofMillis(500));
                for (ConsumerRecord<String, Double> record : records) {
                    writer.write("{\"key\":\"" + record.key() + "\",\"totalAmount\":" + record.value() + "}\n");
                }
                if (!records.isEmpty()) {
                    writer.flush();
                    consumer.commitSync();
                }
            }
        }
    }
}
```
Remember to grant `app-consumer` (or use `admin-superuser.properties`) the
ACLs needed on `customer-spend-per-minute` and the `capstone-file-sink` group,
mirroring Day 5 Step 5, before running this against `local-sasl.properties`.

- [ ] **Step 5 (45 min): Wire it end-to-end.** In three terminals:
```bash
mvn -q compile exec:java -Dexec.mainClass=com.kafkapractice.ProducerLoop \
  -Dexec.args="config/local-sasl.properties orders 10"

mvn -q compile exec:java -Dexec.mainClass=com.kafkapractice.CapstoneStreamsApp \
  -Dexec.args="config/local-sasl.properties orders customer-spend-per-minute"

mvn -q compile exec:java -Dexec.mainClass=com.kafkapractice.FileSinkConsumer \
  -Dexec.args="config/local-sasl.properties customer-spend-per-minute capstone-output.jsonl"
```
Let it run 2-3 minutes, then:
```bash
cat kafka_practice/labs/capstone-output.jsonl
```
Expected: JSON lines with `key` (`order-1`/`order-2`/`order-3`) and a
`totalAmount` accumulating per minute window.

- [ ] **Step 6 (40 min): Inject a deliberate failure.** Pick one from Days
  3–5 (rebalance storm, broker kill, or ACL revocation). Before triggering it,
  write your closed-book prediction of exactly what will happen in
  `journal.md`. Trigger it against the running capstone pipeline. Confirm or
  correct your prediction.

- [ ] **Step 7 (30 min): Capstone retrospective.** Write a one-page
  `journal.md` entry explaining the full pipeline and tracing every design
  decision back to the specific day/concept that motivated it, as if handing
  this system off to a teammate joining the integration team.

- [ ] **Step 8 (20 min): Journal entry + save point.**

---

## Day 15: Self-administered CCAAK-style practice exam + gap analysis

**Materials:** `journal.md` Days 1–14; the CCAAK domain table from
`kafka_practice/docs/superpowers/specs/2026-07-09-kafka-15-day-plan-design.md`;
Confluent's current official CCAAK exam guide (look this up fresh — objectives
can change since this plan was written).

**Builds on:** everything.
**Sets up:** nothing — this is the last day.

- [ ] **Step 1 (15 min): Check the current exam guide.** Look up Confluent's
  published CCAAK exam guide/sample questions and note any domain weighting
  they publish, to sanity-check the spec's approximate domain table.

- [ ] **Step 2 (150 min): Closed-book practice exam.** Write out answers, no
  notes, to at least 5 scenario-style questions per domain (30 total),
  covering: Kafka fundamentals/architecture, cluster config/deployment,
  security, monitoring/ops, Connect, multi-cluster/DR. Draw scenarios directly
  from your own 14 days of chaos labs, e.g.:
  - "The under-replicated-partitions alarm fires at 3am. What are the first
    three things you check, in order, and why?"
  - "A consumer group's lag spikes right after a rolling deploy. Name the two
    most likely causes and how you'd distinguish between them."
  - "A teammate asks why their Kafka Connect sink connector's schema
    registration is failing after a field removal. What's your diagnosis?"
  Time yourself roughly against whatever pacing the official guide publishes.

- [ ] **Step 3 (45 min): Score and correct.** Grade yourself against your own
  journal and the docs referenced throughout the plan. For every miss,
  rewrite the correct answer by hand — not just read it.

- [ ] **Step 4 (30 min): Gap analysis.** For any domain with 2+ misses, find
  which day's chaos lab covers it (via the domain table) and redo that lab's
  core exercise once more, closed-book, right now.

- [ ] **Step 5 (20 min): Final journal entry.** Summarize the 15 days against
  the spec's success criteria: which are met, which need more practice, and a
  one-paragraph plan for the explicitly deferred topics (deeper Streams/
  ksqlDB, non-Java clients) as a follow-on.

- [ ] **Step 6 (10 min): Save point.** Note the plan as complete. Saving/
  committing this work, if you choose to, is entirely your own call.

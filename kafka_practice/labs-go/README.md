# kafka_practice/labs-go

A parallel Go implementation of the Java labs in `kafka_practice/labs/`, for
following the [15-day Kafka plan](../docs/superpowers/plans/2026-07-09-kafka-15-day-plan.md)
using Go instead of (or alongside) Java, via
[`confluent-kafka-go`](https://github.com/confluentinc/confluent-kafka-go) — a
cgo wrapper around `librdkafka`, the C Kafka client Java's own broker-facing
protocol work is not built on. The plan itself is written for the Java labs;
this directory exists so a Go-proficient learner who is still ramping up on
Java can do the same exercises in a language they're already fluent in, and
lean on Java only where Go has no equivalent (see "What stays Java-only"
below).

## Setup

`confluent-kafka-go` needs the native `librdkafka` library available via cgo
— it isn't a pure-Go client. On macOS:

```
brew install librdkafka
```

Then resolve Go module dependencies:

```
cd kafka_practice/labs-go
go mod tidy
```

`go.mod` currently pins:

```
github.com/aws/aws-msk-iam-sasl-signer-go v1.0.1
github.com/confluentinc/confluent-kafka-go/v2 v2.4.0
```

These versions are best-effort, picked at the time this directory was
scaffolded, and have **not** been resolved by actually running `go mod tidy`
in this environment. If `go mod tidy` reports a resolution failure (a version
that no longer exists, a missing transitive dependency, etc.), bump the
pinned version to the latest compatible release and re-run it — same spirit
as the Java plan's note to bump stale Maven dependency versions if a pinned
one goes stale.

## How this differs from `kafka_practice/labs/` (the Java labs)

Same idea as the Java labs' config-file design — client code stays the same
across environments, only the `.properties` file passed as an argument
changes — but the *shape* of those `.properties` files is different, because
Java's client and `librdkafka` configure SASL differently:

- **Java** (`kafka_practice/labs/config/*.properties`) packs SASL credentials
  into a single JAAS config string:

  ```properties
  sasl.mechanism=SCRAM-SHA-256
  sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="app-consumer" password="app-secret";
  ```

- **Go** (`kafka_practice/labs-go/config/*.properties`) uses flat,
  librdkafka-native keys instead — no JAAS string, no login-module class
  name:

  ```properties
  sasl.mechanisms=SCRAM-SHA-256
  sasl.username=app-consumer
  sasl.password=app-secret
  ```

  (Note also the key is `sasl.mechanisms`, plural, in librdkafka — Java uses
  the singular `sasl.mechanism`.)

The two config directories are **not interchangeable** — a Go lab pointed at
a Java `.properties` file (or vice versa) will fail to parse the fields it
expects. Each has its own copy of the same six files
(`local.properties`, `local-sasl.properties`, `admin-superuser.properties`,
`msk-iam.properties`, `confluent-app-consumer.properties`,
`confluent-sr.properties`), same bootstrap servers and credentials per
environment, translated into each ecosystem's native config style. Parsing
and mapping onto `librdkafka`'s `ConfigMap` for the Go side is handled by
`internal/kafkaclient/config.go` (`LoadProperties` + `ToConfigMap`).

## AWS MSK IAM auth: config alone isn't enough in Go

On the Java side, the `aws-msk-iam-auth` plugin (`kafka_practice/labs/config/msk-iam.properties`)
is entirely config-driven:

```properties
sasl.mechanism=AWS_MSK_IAM
sasl.jaas.config=software.amazon.msk.auth.iam.IAMLoginModule required;
sasl.client.callback.handler.class=software.amazon.msk.auth.iam.IAMClientCallbackHandler
```

`librdkafka` has no built-in `AWS_MSK_IAM` SASL mechanism the way the JVM
ecosystem's plugin does, so the Go side can't just point at an equivalent
config key. Instead it uses the mechanism `librdkafka` *does* support for
this — `OAUTHBEARER` — and supplies AWS SigV4-signed tokens itself in code.
That's what `internal/kafkaclient/iam.go`'s `MaybeConfigureAWSIAM` does:

- It reads the Go-only `auth.mode`/`aws.region` keys from
  `config/msk-iam.properties` (these aren't `librdkafka` settings; they're
  this package's own convenience keys — see the comment in `config.go`).
- If `auth.mode=aws-msk-iam`, it sets `security.protocol=SASL_SSL` and
  `sasl.mechanisms=OAUTHBEARER` on the `kafka.ConfigMap`, and returns an
  `attach` function.
- **Any Go file that connects to MSK must call `MaybeConfigureAWSIAM` and
  then call the returned `attach` function on the live producer/consumer
  handle immediately after constructing it** — `librdkafka`'s OAuth token
  refresh callback has to be registered on the client instance itself, not
  on the `ConfigMap`, so it can't be folded into config the way the rest of
  the setup is. Skipping the `attach` call means the client never gets a
  valid token and authentication will fail once the initial connection needs
  to refresh.

## What stays Java-only

Kafka Streams has no official Go client library. That means:

- **Day 13** (`OrderAggregationStreamsApp.java` — windowed Avro aggregation
  against Confluent Cloud) and
- **the Streams portion of Day 14** (`CapstoneStreamsApp.java` — the
  plain-JSON windowed aggregation in the capstone pipeline)

stay Java-only; there is no Go lab for either, and none is planned. Everything
else in the 15-day plan — Days 1–12, plus the plain-consumer file-sink half of
Day 14 (the `FileSinkConsumer.java` equivalent, which is just a `KafkaConsumer`
writing lines to a file — no Streams involved) — has or will have a Go
equivalent under this directory. Concretely, expect (mirroring the Java
labs' `src/main/java/com/kafkapractice/` files) Go equivalents of
`ProducerDemo`, `ConsumerDemo`, `ProducerLoop`, `CompactedProducer`,
`AvroProducerDemo`, and `FileSinkConsumer` — everything in that package
except the two Streams apps above.

## Running a lab

As of this writing, only `go.mod`, `internal/kafkaclient/`, and `config/`
exist under `kafka_practice/labs-go/` — no lab `main` files and no `cmd/`
directory have been added yet, so there's no established `cmd/<name>/`
convention to point at yet. Once lab files land, check first whether they
follow a `cmd/<name>/main.go` layout (common for Go projects with multiple
binaries, since a directory can only hold one `main` package); if so, run a
lab with:

```
go run ./cmd/producerdemo config/local.properties orders
```

If instead a lab ships as a single standalone file (each lab is a small,
self-contained `main` package), run it directly by path:

```
go run ./path/to/producerdemo.go config/local.properties orders
```

Either way, the argument convention mirrors the Java labs: first arg is the
`.properties` file under `config/` (e.g. `config/local.properties`,
`config/local-sasl.properties`, `config/msk-iam.properties`), second arg is
the topic name, with sensible defaults (`config/local.properties`, `orders`)
if omitted — matching `KafkaClientConfig`'s `configPath`/`topic` argument
handling in the Java labs.

// Command filesinkconsumer is the Go port of the Day 14 capstone lab's
// FileSinkConsumer (kafka_practice/labs/src/main/java/com/kafkapractice/FileSinkConsumer.java).
//
// IMPORTANT — this binary is only useful paired with a producer for the
// customer-spend-per-minute topic, and today that producer is Java-only.
// The Day 14 pipeline is: ProducerLoop -> orders topic -> CapstoneStreamsApp
// (a Kafka Streams windowed aggregation) -> customer-spend-per-minute topic
// -> this consumer -> capstone-output.jsonl. Kafka Streams has no Go
// equivalent in this repo — it stays Java-only by explicit project decision
// (there is no Go streams library used here) — so nothing in the Go track
// currently produces to customer-spend-per-minute. To exercise this binary
// for real you run the Java kafka_practice/labs CapstoneStreamsApp (and its
// upstream ProducerLoop) alongside this Go consumer, mixing both language
// tracks for this one exercise; that is the only way to run this lab
// end-to-end without a Go Streams app. See
// kafka_practice/labs/src/main/java/com/kafkapractice/CapstoneStreamsApp.java
// for the producer side.
//
// Mechanics mirrored faithfully from the Java original: manual offset
// commits (enable.auto.commit=false, commit only after a non-empty poll
// batch), earliest auto.offset.reset, and appending one JSON line per
// record to the output file, flushed after each non-empty batch.
package main

import (
	"bufio"
	"encoding/binary"
	"fmt"
	"log"
	"math"
	"os"
	"strconv"
	"time"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"

	"kafkapractice/internal/kafkaclient"
)

// pollBatchWindow mirrors the Java consumer's consumer.poll(Duration.ofMillis(500)).
// confluent-kafka-go's Consumer.Poll returns one event at a time (unlike
// Java's KafkaConsumer.poll, which returns a batch/ConsumerRecords), so this
// program drains events into a slice for up to this long before treating
// the accumulated slice as "one poll batch" for the write+flush+commit step
// below — that is the closest equivalent of the Java loop's per-poll-batch
// commit behavior.
const pollBatchWindow = 500 * time.Millisecond

func main() {
	configPath := "config/local-sasl.properties"
	topic := "customer-spend-per-minute"
	outputPath := "capstone-output.jsonl"
	if len(os.Args) > 1 {
		configPath = os.Args[1]
	}
	if len(os.Args) > 2 {
		topic = os.Args[2]
	}
	if len(os.Args) > 3 {
		outputPath = os.Args[3]
	}

	props, err := kafkaclient.LoadProperties(configPath)
	if err != nil {
		log.Fatalf("load config %s: %v", configPath, err)
	}

	cm := kafkaclient.ToConfigMap(props)
	attach, err := kafkaclient.MaybeConfigureAWSIAM(cm, props)
	if err != nil {
		log.Fatalf("configure AWS IAM auth: %v", err)
	}

	// Java sets these via props.put(...) after loading the base config file,
	// overriding anything present there. There is no key.deserializer /
	// value.deserializer equivalent to set here: confluent-kafka-go always
	// hands back raw []byte for both key and value on kafka.Message — the
	// "deserialization" happens by hand below (string(m.Key) for the key,
	// decodeJavaDouble(m.Value) for the value) rather than via a configured
	// plugin class.
	if err := cm.SetKey("group.id", "capstone-file-sink"); err != nil {
		log.Fatalf("set group.id: %v", err)
	}
	if err := cm.SetKey("enable.auto.commit", "false"); err != nil {
		log.Fatalf("set enable.auto.commit: %v", err)
	}
	if err := cm.SetKey("auto.offset.reset", "earliest"); err != nil {
		log.Fatalf("set auto.offset.reset: %v", err)
	}

	consumer, err := kafka.NewConsumer(cm)
	if err != nil {
		log.Fatalf("create consumer: %v", err)
	}
	defer consumer.Close()

	if err := attach(consumer); err != nil {
		log.Fatalf("attach AWS IAM token refresh callback: %v", err)
	}

	if err := consumer.Subscribe(topic, nil); err != nil {
		log.Fatalf("subscribe to %s: %v", topic, err)
	}

	// Java opens the FileWriter once, in append mode, for the lifetime of
	// the process (try-with-resources), and writes to it across poll
	// iterations. os.O_APPEND|os.O_CREATE mirrors new FileWriter(path, true).
	file, err := os.OpenFile(outputPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		log.Fatalf("open output file %s: %v", outputPath, err)
	}
	defer file.Close()
	writer := bufio.NewWriter(file)

	for {
		batch := pollBatch(consumer)

		for _, m := range batch {
			value, err := decodeJavaDouble(m.Value)
			if err != nil {
				// Java's DoubleDeserializer throws SerializationException
				// here, which is uncaught and terminates the process; a
				// Fatalf does the same in Go.
				log.Fatalf("decode value for key %q: %v", string(m.Key), err)
			}

			// Mirrors the Java version's manual string concatenation
			// exactly (including the lack of any JSON escaping of the
			// key) rather than using encoding/json, since the Java
			// original does the same.
			line := fmt.Sprintf("{\"key\":\"%s\",\"totalAmount\":%s}\n",
				string(m.Key), strconv.FormatFloat(value, 'f', -1, 64))
			if _, err := writer.WriteString(line); err != nil {
				log.Fatalf("write output line: %v", err)
			}
		}

		if len(batch) > 0 {
			if err := writer.Flush(); err != nil {
				log.Fatalf("flush output file: %v", err)
			}
			if _, err := consumer.Commit(); err != nil {
				log.Fatalf("commit offsets: %v", err)
			}
		}
	}
}

// pollBatch drains events from consumer for up to pollBatchWindow and
// returns the messages collected, approximating one call to Java's
// consumer.poll(Duration.ofMillis(500)) — see the pollBatchWindow comment
// above for why this loop exists instead of a single Poll call.
func pollBatch(consumer *kafka.Consumer) []*kafka.Message {
	var batch []*kafka.Message
	deadline := time.Now().Add(pollBatchWindow)
	for {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			break
		}
		ev := consumer.Poll(int(remaining.Milliseconds()))
		if ev == nil {
			break
		}
		switch e := ev.(type) {
		case *kafka.Message:
			if e.TopicPartition.Error != nil {
				log.Printf("message delivery error on %v: %v", e.TopicPartition, e.TopicPartition.Error)
				continue
			}
			batch = append(batch, e)
		case kafka.Error:
			log.Printf("consumer error: %v", e)
		default:
			// Ignore other event types Poll can surface (rebalance
			// events, stats, etc.) — the Java loop only ever sees
			// ConsumerRecords, so there is nothing analogous to handle.
		}
	}
	return batch
}

// decodeJavaDouble decodes the raw message value bytes the way Java's
// built-in org.apache.kafka.common.serialization.DoubleSerializer writes
// them on the wire: DoubleSerializer allocates an 8-byte java.nio.ByteBuffer
// (big-endian by default) and calls putDouble(value), which stores the
// IEEE 754 bit pattern from Double.doubleToLongBits. confluent-kafka-go /
// librdkafka has no typed Deserializer<T> plugin system like Java's — Poll
// only ever returns the raw []byte value — so this function must
// reimplement that exact decode (8 bytes, big-endian, IEEE 754 double bits)
// to interoperate with CapstoneStreamsApp's Double-valued output topic.
//
// ASSUMPTION TO VERIFY (flagged per review): this matches Kafka's built-in
// DoubleSerializer as of the client version CapstoneStreamsApp uses. If
// that serializer's wire format ever changes, or if the producer switches
// serializers, this function must change in lockstep or it will silently
// decode garbage/NaN instead of failing loudly (a malformed 8-byte value
// is still a valid-looking double bit pattern).
func decodeJavaDouble(raw []byte) (float64, error) {
	if len(raw) != 8 {
		return 0, fmt.Errorf("expected 8-byte big-endian IEEE 754 double, got %d bytes", len(raw))
	}
	bits := binary.BigEndian.Uint64(raw)
	return math.Float64frombits(bits), nil
}

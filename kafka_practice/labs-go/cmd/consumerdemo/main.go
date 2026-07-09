// Command consumerdemo is the Go port of the Day 3 shape of the Java lab's
// ConsumerDemo (kafka_practice/labs/src/main/java/com/kafkapractice/ConsumerDemo.java):
// manual commits plus a rebalance listener. It subscribes with a rebalance
// callback that prints every assignment change (mirroring the Java
// version's ConsumerRebalanceListener), polls in a loop, prints each record,
// and commits once per poll batch only if that batch had records.
package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"kafkapractice/internal/kafkaclient"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
)

const pollTimeoutMs = 500

func main() {
	configPath := "config/local.properties"
	if len(os.Args) > 1 {
		configPath = os.Args[1]
	}
	topic := "orders"
	if len(os.Args) > 2 {
		topic = os.Args[2]
	}
	groupID := "orders-group"
	if len(os.Args) > 3 {
		groupID = os.Args[3]
	}

	props, err := kafkaclient.LoadProperties(configPath)
	if err != nil {
		log.Fatalf("load properties: %v", err)
	}

	cm := kafkaclient.ToConfigMap(props)
	// No Go equivalent of Java's key.deserializer/value.deserializer props:
	// confluent-kafka-go always hands back raw []byte for key/value.
	if err := cm.SetKey("group.id", groupID); err != nil {
		log.Fatalf("set group.id: %v", err)
	}
	if err := cm.SetKey("enable.auto.commit", "false"); err != nil {
		log.Fatalf("set enable.auto.commit: %v", err)
	}
	if err := cm.SetKey("auto.offset.reset", "earliest"); err != nil {
		log.Fatalf("set auto.offset.reset: %v", err)
	}
	// TODO(human): verify against confluent-kafka-go docs -- confirm that
	// go.application.rebalance.enable must be set to true for the
	// rebalanceCb passed to SubscribeTopics below to actually receive
	// kafka.AssignedPartitions/kafka.RevokedPartitions events. Without this
	// setting, librdkafka may handle partition assignment entirely
	// internally and never invoke the callback with these event types,
	// unlike Java's KafkaConsumer, which always invokes a registered
	// ConsumerRebalanceListener regardless of any config flag.
	if err := cm.SetKey("go.application.rebalance.enable", "true"); err != nil {
		log.Fatalf("set go.application.rebalance.enable: %v", err)
	}

	attach, err := kafkaclient.MaybeConfigureAWSIAM(cm, props)
	if err != nil {
		log.Fatalf("configure AWS IAM: %v", err)
	}

	consumer, err := kafka.NewConsumer(cm)
	if err != nil {
		log.Fatalf("create consumer: %v", err)
	}
	// TODO(human): verify against confluent-kafka-go docs -- confirm
	// Consumer.Close() returns an error (unlike Producer.Close(), which does
	// not) and that logging-and-continuing on shutdown error is acceptable
	// for this demo.
	defer func() {
		if cerr := consumer.Close(); cerr != nil {
			log.Printf("close consumer: %v", cerr)
		}
	}()

	if err := attach(consumer); err != nil {
		log.Fatalf("attach AWS IAM callback: %v", err)
	}

	// SubscribeTopics takes a topic list plus a rebalance callback, mirroring
	// the Java version's consumer.subscribe(Collections.singletonList(topic),
	// new ConsumerRebalanceListener() {...}).
	// TODO(human): verify against confluent-kafka-go docs -- confirm
	// SubscribeTopics(topics []string, rebalanceCb kafka.RebalanceCb) error
	// is the right signature for subscribing with a rebalance callback.
	if err := consumer.SubscribeTopics([]string{topic}, rebalanceCb); err != nil {
		log.Fatalf("subscribe: %v", err)
	}

	for {
		batch := pollBatch(consumer, pollTimeoutMs)
		for _, msg := range batch {
			fmt.Printf("partition=%d offset=%d key=%s value=%s\n",
				msg.TopicPartition.Partition, msg.TopicPartition.Offset, string(msg.Key), string(msg.Value))
		}
		if len(batch) > 0 {
			// TODO(human): verify against confluent-kafka-go docs -- confirm
			// Commit() (no args) returns ([]kafka.TopicPartition, error) and
			// that it commits the consumer's full current position across
			// all assigned partitions, matching the Java version's no-arg
			// consumer.commitSync() (as opposed to CommitMessage, which
			// commits a single message's offset).
			if _, err := consumer.Commit(); err != nil {
				log.Printf("commit failed: %v", err)
			}
		}
	}
}

// rebalanceCb prints every partition-assignment change, mirroring the Java
// version's ConsumerRebalanceListener.onPartitionsAssigned/onPartitionsRevoked
// output ("[rebalance] assigned: ..." / "[rebalance] revoked: ...").
// TODO(human): verify against confluent-kafka-go docs -- confirm the
// kafka.RebalanceCb signature is func(*kafka.Consumer, kafka.Event) error,
// that kafka.AssignedPartitions and kafka.RevokedPartitions (each carrying a
// Partitions []kafka.TopicPartition field) are the two event types delivered
// to this callback, and that the callback itself is expected to call
// c.Assign(...)/c.Unassign() -- unlike Java's KafkaConsumer, which keeps
// managing partition assignment internally even when a listener is
// registered, so the listener there is purely observational.
func rebalanceCb(c *kafka.Consumer, event kafka.Event) error {
	switch e := event.(type) {
	case kafka.AssignedPartitions:
		fmt.Printf("[rebalance] assigned: %v\n", e.Partitions)
		if err := c.Assign(e.Partitions); err != nil {
			return err
		}
	case kafka.RevokedPartitions:
		fmt.Printf("[rebalance] revoked: %v\n", e.Partitions)
		if err := c.Unassign(); err != nil {
			return err
		}
	}
	return nil
}

// pollBatch mimics the Java client's consumer.poll(Duration) semantics: one
// call there returns a batch of ConsumerRecords accumulated within the
// timeout window. confluent-kafka-go's Consumer.Poll returns at most one
// event per call, so this gathers every message that arrives before the
// window elapses into a single batch, letting the caller process the whole
// batch and commit exactly once -- matching the Java version's
// "if (!records.isEmpty()) consumer.commitSync()".
func pollBatch(c *kafka.Consumer, timeoutMs int) []*kafka.Message {
	deadline := time.Now().Add(time.Duration(timeoutMs) * time.Millisecond)
	var batch []*kafka.Message
	for {
		remaining := time.Until(deadline)
		if remaining <= 0 {
			break
		}
		// TODO(human): verify against confluent-kafka-go docs -- confirm
		// Poll(timeoutMs int) Event returns nil on timeout and a
		// *kafka.Message / kafka.Error (among other event types) otherwise.
		ev := c.Poll(int(remaining.Milliseconds()))
		if ev == nil {
			break
		}
		switch e := ev.(type) {
		case *kafka.Message:
			batch = append(batch, e)
		case kafka.Error:
			log.Printf("consumer error: %v", e)
		}
	}
	return batch
}

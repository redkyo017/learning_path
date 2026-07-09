// Command compactedproducer is the Go port of the Day 4 Java lab's
// CompactedProducer
// (kafka_practice/labs/src/main/java/com/kafkapractice/CompactedProducer.java):
// it writes 5 rounds of updates for the same 3 fixed keys to a compacted
// topic, waiting synchronously for each message's delivery report before
// sending the next one (mirroring the Java version's
// producer.send(...).get() per message) and sleeping 200ms between rounds so
// the effect of log compaction -- only the last update per key survives --
// can be observed afterward.
package main

import (
	"fmt"
	"log"
	"os"
	"time"

	"kafkapractice/internal/kafkaclient"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
)

func main() {
	configPath := "config/local.properties"
	if len(os.Args) > 1 {
		configPath = os.Args[1]
	}
	topic := "user-profiles"
	if len(os.Args) > 2 {
		topic = os.Args[2]
	}

	props, err := kafkaclient.LoadProperties(configPath)
	if err != nil {
		log.Fatalf("load properties: %v", err)
	}

	cm := kafkaclient.ToConfigMap(props)
	// No Go equivalent of Java's key.serializer/value.serializer props:
	// confluent-kafka-go always sends raw []byte for key/value, so there is
	// no serializer plugin config to set here.
	if err := cm.SetKey("acks", "all"); err != nil {
		log.Fatalf("set acks: %v", err)
	}

	attach, err := kafkaclient.MaybeConfigureAWSIAM(cm, props)
	if err != nil {
		log.Fatalf("configure AWS IAM: %v", err)
	}

	producer, err := kafka.NewProducer(cm)
	if err != nil {
		log.Fatalf("create producer: %v", err)
	}
	// TODO(human): verify against confluent-kafka-go docs -- confirm
	// Producer.Close() has no error return (unlike Consumer.Close(), which
	// does). If it turns out to return an error, this defer needs updating.
	defer producer.Close()

	if err := attach(producer); err != nil {
		log.Fatalf("attach AWS IAM callback: %v", err)
	}

	keys := []string{"user-1", "user-2", "user-3"}

	deliveryChan := make(chan kafka.Event)

	for round := 0; round < 5; round++ {
		for _, key := range keys {
			value := fmt.Sprintf(`{"round":%d,"status":"update-%d"}`, round, round)

			// TODO(human): verify against confluent-kafka-go docs -- confirm
			// Produce(msg *kafka.Message, deliveryChan chan Event) error is the
			// right signature, and that reading exactly one event off
			// deliveryChan per call is the correct synchronous-delivery pattern
			// (mirroring the Java version's producer.send(...).get() per
			// message).
			err := producer.Produce(&kafka.Message{
				TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
				Key:            []byte(key),
				Value:          []byte(value),
			}, deliveryChan)
			if err != nil {
				log.Fatalf("produce round=%d key=%s: %v", round, key, err)
			}

			event := <-deliveryChan
			msg, ok := event.(*kafka.Message)
			if !ok {
				log.Fatalf("unexpected delivery event type: %T", event)
			}
			if msg.TopicPartition.Error != nil {
				log.Fatalf("delivery failed round=%d key=%s: %v", round, key, msg.TopicPartition.Error)
			}
		}

		// Same 200ms pause between rounds as the Java version's
		// Thread.sleep(200), run once per round after all 3 keys have been
		// sent.
		time.Sleep(200 * time.Millisecond)
	}
}

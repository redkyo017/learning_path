// Command producerdemo is the Go port of the Day 2 Java lab's ProducerDemo
// (kafka_practice/labs/src/main/java/com/kafkapractice/ProducerDemo.java): it
// sends 20 messages to a topic, waiting synchronously for each delivery
// report before sending the next one, so partition assignment can be
// observed message by message. This trades throughput for observability,
// same as the Java version's synchronous producer.send(...).get() per
// message.
package main

import (
	"fmt"
	"log"
	"math/rand"
	"os"

	"kafkapractice/internal/kafkaclient"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
)

func main() {
	configPath := "config/local.properties"
	if len(os.Args) > 1 {
		configPath = os.Args[1]
	}
	topic := "orders"
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
	if err := cm.SetKey("enable.idempotence", "true"); err != nil {
		log.Fatalf("set enable.idempotence: %v", err)
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

	deliveryChan := make(chan kafka.Event)

	for i := 0; i < 20; i++ {
		key := fmt.Sprintf("order-%d", 1+rand.Intn(3))
		value := fmt.Sprintf(`{"orderId":%d,"amount":%d}`, i, 10+rand.Intn(90))

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
			log.Fatalf("produce: %v", err)
		}

		event := <-deliveryChan
		msg, ok := event.(*kafka.Message)
		if !ok {
			log.Fatalf("unexpected delivery event type: %T", event)
		}
		if msg.TopicPartition.Error != nil {
			log.Fatalf("delivery failed: %v", msg.TopicPartition.Error)
		}

		fmt.Printf("key=%s -> partition=%d offset=%d\n", key, msg.TopicPartition.Partition, msg.TopicPartition.Offset)
	}
}

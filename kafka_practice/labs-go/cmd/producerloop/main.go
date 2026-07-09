// Command producerloop is the Go port of the Java lab's ProducerLoop
// (kafka_practice/labs/src/main/java/com/kafkapractice/ProducerLoop.java): it
// sends messages to a topic forever at a configurable rate, firing each
// produce call without waiting for its delivery report, matching the Java
// version's async producer.send(...) (no .get()) inside its while(true)
// loop. Unlike cmd/producerdemo (the Day 2 port of ProducerDemo.java, which
// does wait for each delivery report and sends a fixed 20 messages), this
// command runs indefinitely and is meant to be paired with several
// consumerdemo instances for the Day 3 rebalance-storm chaos lab.
package main

import (
	"fmt"
	"log"
	"math/rand"
	"os"
	"strconv"
	"time"

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
	messagesPerSecond := 5
	if len(os.Args) > 3 {
		n, err := strconv.Atoi(os.Args[3])
		if err != nil {
			log.Fatalf("invalid messagesPerSecond %q: %v", os.Args[3], err)
		}
		messagesPerSecond = n
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
	defer producer.Close()

	if err := attach(producer); err != nil {
		log.Fatalf("attach AWS IAM callback: %v", err)
	}

	// delayMs = 1000L / messagesPerSecond in the Java version; same integer
	// division here (and the same divide-by-zero panic if
	// messagesPerSecond == 0, matching Java's ArithmeticException in that
	// case -- neither version guards against it).
	delay := time.Second / time.Duration(messagesPerSecond)

	var i int64
	for {
		key := fmt.Sprintf("order-%d", 1+rand.Intn(3))
		value := fmt.Sprintf(`{"orderId":%d,"amount":%d}`, i, 10+rand.Intn(90))
		i++

		// Fire-and-forget: pass a nil delivery channel so Produce doesn't
		// block waiting for a delivery report, matching the Java version's
		// async producer.send(...) with no .get() in this file (unlike
		// ProducerDemo.java / cmd/producerdemo, which does wait for each
		// delivery report before sending the next message).
		// TODO(human): verify against confluent-kafka-go docs -- confirm
		// that passing deliveryChan=nil to Produce is the correct
		// fire-and-forget pattern, and that delivery reports it then routes
		// to the producer's default Events() channel (which nothing here
		// drains) don't eventually block Produce() once that channel's
		// internal buffer fills, for a long-running loop like this one.
		if err := producer.Produce(&kafka.Message{
			TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
			Key:            []byte(key),
			Value:          []byte(value),
		}, nil); err != nil {
			log.Printf("produce failed: %v", err)
		}

		time.Sleep(delay)
	}
}

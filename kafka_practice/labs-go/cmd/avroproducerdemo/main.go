// Command avroproducerdemo is the Go port of the Day 12 Java lab's
// AvroProducerDemo
// (kafka_practice/labs/src/main/java/com/kafkapractice/AvroProducerDemo.java):
// it sends 30 orders to a topic, each Avro-serialized against Confluent
// Schema Registry, keyed by a randomly chosen customerId, waiting
// synchronously for each delivery report and sleeping 500ms between sends --
// same shape as the Java original's loop.
//
// Unlike every other Go port in this lab set, this one needs a second HTTP
// client (Schema Registry) in addition to the librdkafka ConfigMap, because
// schema.registry.url/username/password are this repo's own convenience
// keys, not librdkafka settings -- see kafkaclient.knownConfigKeys's comment
// and kafka_practice/labs-go/config/confluent-sr.properties.
package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	"kafkapractice/internal/kafkaclient"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
	"github.com/confluentinc/confluent-kafka-go/v2/schemaregistry"
	"github.com/confluentinc/confluent-kafka-go/v2/schemaregistry/serde"
	"github.com/confluentinc/confluent-kafka-go/v2/schemaregistry/serde/avro"
)

// Order mirrors the fields of kafka_practice/labs/schemas/orders-value.avsc
// (orderId string, customerId string, amount double).
//
// TODO(human): verify against confluent-kafka-go docs -- this struct, not
// the .avsc file read below, is what actually determines the Avro schema
// this program registers/produces. As of confluent-kafka-go v2.4.0,
// schemaregistry/serde/avro's GenericSerializer is backed by
// github.com/heetch/avro, and its Serialize method
// (schemaregistry/serde/avro/avro_generic.go) derives the schema purely by
// Go reflection -- it calls avro.TypeOf(msg) / avro.Marshal(msg) internally
// and has no parameter or config field anywhere (NewGenericSerializer,
// SerializerConfig, Serialize) that accepts an explicit/parsed schema
// string. This is a real API-surface gap versus the Java original, which
// explicitly parses orders-value.avsc into a Schema and builds each
// GenericRecord against that exact parsed Schema object.
//
// Practical consequence: heetch/avro derives Avro field names from Go
// struct field names or "json" tags (used below to match orderId/
// customerId/amount), but the record's Avro full name (name+namespace) is
// derived from this Go type's name/package, NOT from the .avsc file's
// "name": "Order", "namespace": "com.kafkapractice.avro". If the "orders-
// value" subject in Schema Registry already has a schema registered by the
// Java producer (per the Day 12 brief), the schema this Go program derives
// and attempts to register/use may have a different full name and could be
// rejected by, or diverge from, that existing subject's compatibility
// rules. Before relying on this in a real environment: either (a) confirm
// confluent-kafka-go has since added a way to force an explicit schema
// (e.g. a newer avro serde variant, "avrov3" per its examples directory
// naming, or a SerializerConfig field for this), or (b) generate this Go
// type from orders-value.avsc with heetch/avro's "avrogo" code generator
// (using its go.name/go.package schema annotations) so the reflected
// full name matches exactly, or (c) bypass GenericSerializer and call the
// exported BaseSerializer.GetID/WriteBytes methods directly with a
// hand-built schemaregistry.SchemaInfo{Schema: <raw .avsc content>}.
type Order struct {
	OrderID    string  `json:"orderId"`
	CustomerID string  `json:"customerId"`
	Amount     float64 `json:"amount"`
}

func main() {
	configPath := "config/confluent-sr.properties"
	if len(os.Args) > 1 {
		configPath = os.Args[1]
	}
	topic := "orders"
	if len(os.Args) > 2 {
		topic = os.Args[2]
	}
	// The Java original defaults to "schemas/orders-value.avsc", relative to
	// kafka_practice/labs/'s own module root. This binary's module root is
	// kafka_practice/labs-go/, one directory over from labs/, so the
	// equivalent default relative path climbs up one level first.
	schemaPath := "../labs/schemas/orders-value.avsc"
	if len(os.Args) > 3 {
		schemaPath = os.Args[3]
	}

	schemaBytes, err := os.ReadFile(schemaPath)
	if err != nil {
		log.Fatalf("read schema %s: %v", schemaPath, err)
	}
	// Mirrors the Java original's Schema.Parser().parse(...) call failing
	// fast on a missing/malformed schema file. Only a JSON-shape check,
	// not a full Avro schema parse/validation -- see the TODO(human) on the
	// Order type above for why the parsed content doesn't actually reach
	// the serializer in this Go port.
	if !json.Valid(schemaBytes) {
		log.Fatalf("schema %s is not valid JSON", schemaPath)
	}

	props, err := kafkaclient.LoadProperties(configPath)
	if err != nil {
		log.Fatalf("load properties: %v", err)
	}

	// schema.registry.url/username/password are this repo's own convenience
	// keys (see kafkaclient.knownConfigKeys's comment) for building a
	// separate Schema Registry HTTP client -- they are not librdkafka
	// ConfigMap settings, so read them directly out of props rather than out
	// of kafkaclient.ToConfigMap's result.
	srURL := props["schema.registry.url"]
	srUsername := props["schema.registry.username"]
	srPassword := props["schema.registry.password"]
	if srURL == "" {
		log.Fatalf("schema.registry.url missing from %s", configPath)
	}

	// TODO(human): verify against confluent-kafka-go docs -- confirm
	// schemaregistry.NewConfigWithBasicAuthentication(url, username,
	// password) *Config is still the current v2 constructor for HTTP basic
	// auth (Confluent Cloud SR API key/secret). Some versions/forks also
	// expose a deprecated NewConfigWithAuthentication with the same
	// signature; make sure this call resolves to the non-deprecated one.
	srConf := schemaregistry.NewConfigWithBasicAuthentication(srURL, srUsername, srPassword)

	srClient, err := schemaregistry.NewClient(srConf)
	if err != nil {
		log.Fatalf("create schema registry client: %v", err)
	}
	// TODO(human): verify against confluent-kafka-go docs -- confirm
	// schemaregistry.Client exposes Close() (error) with this exact
	// signature in v2.4.0; some client interfaces expose no Close method at
	// all, in which case this defer needs to be removed instead.
	defer srClient.Close()

	// TODO(human): verify against confluent-kafka-go docs -- confirm
	// avro.NewGenericSerializer(client schemaregistry.Client, serdeType
	// serde.Type, conf *avro.SerializerConfig) (*avro.GenericSerializer,
	// error) is the exact v2.4.0 signature, and that serde.ValueSerde (as
	// opposed to some other exported constant name/spelling) is correct for
	// "this serializer is for message values, not keys."
	valueSerializer, err := avro.NewGenericSerializer(srClient, serde.ValueSerde, avro.NewSerializerConfig())
	if err != nil {
		log.Fatalf("create avro serializer: %v", err)
	}

	cm := kafkaclient.ToConfigMap(props)
	// No Go equivalent of Java's key.serializer/value.serializer props: the
	// key is sent as raw []byte below, and the value is pre-serialized by
	// valueSerializer.Serialize before being handed to Produce.
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
	defer producer.Close()

	if err := attach(producer); err != nil {
		log.Fatalf("attach AWS IAM callback: %v", err)
	}

	deliveryChan := make(chan kafka.Event)

	rnd := rand.New(rand.NewSource(time.Now().UnixNano()))
	for i := 0; i < 30; i++ {
		customerID := fmt.Sprintf("customer-%d", 1+rnd.Intn(3))
		order := &Order{
			OrderID:    fmt.Sprintf("order-%d", i),
			CustomerID: customerID,
			Amount:     10.0 + float64(rnd.Intn(90)),
		}

		// TODO(human): verify against confluent-kafka-go docs -- confirm
		// GenericSerializer.Serialize(topic string, msg interface{})
		// ([]byte, error) accepts a pointer-to-struct the way Confluent's
		// own avro_generic_producer_example passes &value, and that it
		// correctly derives and auto-registers the Avro schema (under
		// AutoRegisterSchemas' default setting -- also worth confirming
		// that default is true) via reflection over *Order on first call.
		valueBytes, err := valueSerializer.Serialize(topic, order)
		if err != nil {
			log.Fatalf("serialize order: %v", err)
		}

		// TODO(human): verify against confluent-kafka-go docs -- confirm
		// Produce(msg *kafka.Message, deliveryChan chan Event) error is the
		// right signature, and that reading exactly one event off
		// deliveryChan per call is the correct synchronous-delivery pattern
		// (mirroring the Java version's producer.send(...).get() per
		// message).
		err = producer.Produce(&kafka.Message{
			TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
			Key:            []byte(customerID),
			Value:          valueBytes,
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

		fmt.Printf("customerId=%s -> partition=%d offset=%d\n",
			customerID, msg.TopicPartition.Partition, msg.TopicPartition.Offset)

		time.Sleep(500 * time.Millisecond)
	}
}

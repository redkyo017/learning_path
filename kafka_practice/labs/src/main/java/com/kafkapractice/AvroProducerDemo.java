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

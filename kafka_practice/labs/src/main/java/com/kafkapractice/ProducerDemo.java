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

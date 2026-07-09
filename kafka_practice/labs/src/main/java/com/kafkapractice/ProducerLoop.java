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

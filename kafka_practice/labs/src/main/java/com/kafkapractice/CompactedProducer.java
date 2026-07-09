package com.kafkapractice;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.Properties;

public class CompactedProducer {
    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/local.properties";
        String topic = args.length > 1 ? args[1] : "user-profiles";

        Properties props = KafkaClientConfig.load(configPath);
        props.put("key.serializer", StringSerializer.class.getName());
        props.put("value.serializer", StringSerializer.class.getName());
        props.put("acks", "all");

        String[] keys = {"user-1", "user-2", "user-3"};
        try (KafkaProducer<String, String> producer = new KafkaProducer<>(props)) {
            for (int round = 0; round < 5; round++) {
                for (String key : keys) {
                    String value = "{\"round\":" + round + ",\"status\":\"update-" + round + "\"}";
                    producer.send(new ProducerRecord<>(topic, key, value)).get();
                }
                Thread.sleep(200);
            }
        }
    }
}

package com.kafkapractice;

import org.apache.kafka.clients.consumer.ConsumerRebalanceListener;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.time.Duration;
import java.util.Collection;
import java.util.Collections;
import java.util.Properties;

public class ConsumerDemo {
    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/local.properties";
        String topic = args.length > 1 ? args[1] : "orders";
        String groupId = args.length > 2 ? args[2] : "orders-group";

        Properties props = KafkaClientConfig.load(configPath);
        props.put("key.deserializer", StringDeserializer.class.getName());
        props.put("value.deserializer", StringDeserializer.class.getName());
        props.put("group.id", groupId);
        props.put("enable.auto.commit", "false");
        props.put("auto.offset.reset", "earliest");

        try (KafkaConsumer<String, String> consumer = new KafkaConsumer<>(props)) {
            consumer.subscribe(Collections.singletonList(topic), new ConsumerRebalanceListener() {
                @Override
                public void onPartitionsRevoked(Collection<TopicPartition> partitions) {
                    System.out.println("[rebalance] revoked: " + partitions);
                }

                @Override
                public void onPartitionsAssigned(Collection<TopicPartition> partitions) {
                    System.out.println("[rebalance] assigned: " + partitions);
                }
            });
            while (true) {
                ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(500));
                for (ConsumerRecord<String, String> record : records) {
                    System.out.printf("partition=%d offset=%d key=%s value=%s%n",
                            record.partition(), record.offset(), record.key(), record.value());
                }
                if (!records.isEmpty()) {
                    consumer.commitSync();
                }
            }
        }
    }
}

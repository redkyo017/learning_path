package com.kafkapractice;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.DoubleDeserializer;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.io.FileWriter;
import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class FileSinkConsumer {
    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/local-sasl.properties";
        String topic = args.length > 1 ? args[1] : "customer-spend-per-minute";
        String outputPath = args.length > 2 ? args[2] : "capstone-output.jsonl";

        Properties props = KafkaClientConfig.load(configPath);
        props.put("key.deserializer", StringDeserializer.class.getName());
        props.put("value.deserializer", DoubleDeserializer.class.getName());
        props.put("group.id", "capstone-file-sink");
        props.put("enable.auto.commit", "false");
        props.put("auto.offset.reset", "earliest");

        try (KafkaConsumer<String, Double> consumer = new KafkaConsumer<>(props);
             FileWriter writer = new FileWriter(outputPath, true)) {
            consumer.subscribe(Collections.singletonList(topic));
            while (true) {
                ConsumerRecords<String, Double> records = consumer.poll(Duration.ofMillis(500));
                for (ConsumerRecord<String, Double> record : records) {
                    writer.write("{\"key\":\"" + record.key() + "\",\"totalAmount\":" + record.value() + "}\n");
                }
                if (!records.isEmpty()) {
                    writer.flush();
                    consumer.commitSync();
                }
            }
        }
    }
}

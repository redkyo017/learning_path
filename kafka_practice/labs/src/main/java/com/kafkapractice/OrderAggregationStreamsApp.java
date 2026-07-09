package com.kafkapractice;

import io.confluent.kafka.streams.serdes.avro.GenericAvroSerde;
import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.KeyValue;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.Topology;
import org.apache.kafka.streams.kstream.Consumed;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.Materialized;
import org.apache.kafka.streams.kstream.Produced;
import org.apache.kafka.streams.kstream.TimeWindows;
import org.apache.kafka.streams.kstream.Windowed;

import java.time.Duration;
import java.util.Collections;
import java.util.Properties;

public class OrderAggregationStreamsApp {
    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/confluent-sr.properties";
        String inputTopic = args.length > 1 ? args[1] : "orders";
        String outputTopic = args.length > 2 ? args[2] : "customer-spend-per-minute";

        Properties props = KafkaClientConfig.load(configPath);
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, "order-aggregation-app");
        props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass());

        GenericAvroSerde avroSerde = new GenericAvroSerde();
        avroSerde.configure(
                Collections.singletonMap("schema.registry.url", props.getProperty("schema.registry.url")),
                false
        );

        StreamsBuilder builder = new StreamsBuilder();
        KStream<String, GenericRecord> orders = builder.stream(inputTopic, Consumed.with(Serdes.String(), avroSerde));

        KStream<String, Double> spendPerMinute = orders
                .groupByKey()
                .windowedBy(TimeWindows.ofSizeAndGrace(Duration.ofMinutes(1), Duration.ofSeconds(10)))
                .aggregate(
                        () -> 0.0,
                        (customerId, order, total) -> total + (double) order.get("amount"),
                        Materialized.with(Serdes.String(), Serdes.Double())
                )
                .toStream()
                .map((Windowed<String> windowedKey, Double total) -> KeyValue.pair(windowedKey.key(), total));

        spendPerMinute.to(outputTopic, Produced.with(Serdes.String(), Serdes.Double()));

        Topology topology = builder.build();
        System.out.println(topology.describe());

        try (KafkaStreams streams = new KafkaStreams(topology, props)) {
            Runtime.getRuntime().addShutdownHook(new Thread(streams::close));
            streams.start();
            Thread.sleep(Long.MAX_VALUE);
        }
    }
}

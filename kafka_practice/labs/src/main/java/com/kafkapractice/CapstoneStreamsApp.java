package com.kafkapractice;

import org.apache.kafka.common.serialization.Serdes;
import org.apache.kafka.streams.KafkaStreams;
import org.apache.kafka.streams.KeyValue;
import org.apache.kafka.streams.StreamsBuilder;
import org.apache.kafka.streams.StreamsConfig;
import org.apache.kafka.streams.Topology;
import org.apache.kafka.streams.kstream.KStream;
import org.apache.kafka.streams.kstream.Materialized;
import org.apache.kafka.streams.kstream.Produced;
import org.apache.kafka.streams.kstream.TimeWindows;
import org.apache.kafka.streams.kstream.Windowed;

import java.time.Duration;
import java.util.Properties;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class CapstoneStreamsApp {
    private static final Pattern AMOUNT_PATTERN = Pattern.compile("\"amount\":(\\d+)");

    public static void main(String[] args) throws Exception {
        String configPath = args.length > 0 ? args[0] : "config/local-sasl.properties";
        String inputTopic = args.length > 1 ? args[1] : "orders";
        String outputTopic = args.length > 2 ? args[2] : "customer-spend-per-minute";

        Properties props = KafkaClientConfig.load(configPath);
        props.put(StreamsConfig.APPLICATION_ID_CONFIG, "capstone-streams-app");
        props.put(StreamsConfig.DEFAULT_KEY_SERDE_CLASS_CONFIG, Serdes.String().getClass());
        props.put(StreamsConfig.DEFAULT_VALUE_SERDE_CLASS_CONFIG, Serdes.String().getClass());

        StreamsBuilder builder = new StreamsBuilder();
        KStream<String, String> orders = builder.stream(inputTopic);

        KStream<String, Double> spendPerMinute = orders
                .mapValues(CapstoneStreamsApp::extractAmount)
                .groupByKey()
                .windowedBy(TimeWindows.ofSizeAndGrace(Duration.ofMinutes(1), Duration.ofSeconds(10)))
                .aggregate(
                        () -> 0.0,
                        (key, amount, total) -> total + amount,
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

    private static double extractAmount(String json) {
        Matcher matcher = AMOUNT_PATTERN.matcher(json);
        return matcher.find() ? Double.parseDouble(matcher.group(1)) : 0.0;
    }
}

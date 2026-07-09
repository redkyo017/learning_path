package com.kafkapractice;

import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;

public final class KafkaClientConfig {
    private KafkaClientConfig() {
    }

    public static Properties load(String path) throws IOException {
        Properties props = new Properties();
        try (FileInputStream in = new FileInputStream(path)) {
            props.load(in);
        }
        return props;
    }
}

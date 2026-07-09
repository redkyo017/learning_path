package kafkaclient

import (
	"bufio"
	"fmt"
	"os"
	"strings"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
)

// LoadProperties reads a flat key=value properties file. Unlike the Java labs'
// config files, there is no JAAS config string here — librdkafka (which this
// client wraps) takes SASL username/password/mechanism as separate flat keys,
// so these Go config files use different key names than their Java
// counterparts even where the underlying setting is the same. Lines starting
// with # are comments.
func LoadProperties(path string) (map[string]string, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("open %s: %w", path, err)
	}
	defer f.Close()

	props := make(map[string]string)
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		props[strings.TrimSpace(parts[0])] = strings.TrimSpace(parts[1])
	}
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("read %s: %w", path, err)
	}
	return props, nil
}

// knownConfigKeys are properties passed straight through to librdkafka's
// ConfigMap. auth.mode, aws.region, and schema.registry.* are this package's
// own convenience keys (not librdkafka settings) — auth.mode/aws.region are
// handled by MaybeConfigureAWSIAM, and schema.registry.* is read directly by
// callers that build a Schema Registry client (e.g. the Avro producer),
// since that's a separate HTTP client, not a librdkafka setting.
var knownConfigKeys = []string{
	"bootstrap.servers",
	"security.protocol",
	"sasl.mechanisms",
	"sasl.username",
	"sasl.password",
	"ssl.ca.location",
	"ssl.certificate.location",
	"ssl.key.location",
	"ssl.key.password",
}

// ToConfigMap copies the recognized librdkafka keys from props into a
// kafka.ConfigMap. Call MaybeConfigureAWSIAM afterward if the properties
// file has auth.mode=aws-msk-iam — that path needs a callback registered on
// the live producer/consumer handle, not just config values.
func ToConfigMap(props map[string]string) *kafka.ConfigMap {
	cm := &kafka.ConfigMap{}
	for _, key := range knownConfigKeys {
		if v, ok := props[key]; ok && v != "" {
			_ = cm.SetKey(key, v)
		}
	}
	return cm
}

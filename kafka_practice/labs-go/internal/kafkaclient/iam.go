package kafkaclient

import (
	"context"
	"fmt"

	"github.com/aws/aws-msk-iam-sasl-signer-go/signer"
	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
)

// MaybeConfigureAWSIAM checks props for auth.mode=aws-msk-iam — this
// package's own convenience key, not a librdkafka setting, since librdkafka
// has no built-in "AWS_MSK_IAM" mechanism the way Java's aws-msk-iam-auth
// plugin does. If set, it configures cm for OAUTHBEARER and returns an
// attach function the caller MUST invoke with the live producer/consumer
// handle immediately after construction: librdkafka's OAuth refresh
// callback is registered on the client instance, not the ConfigMap, so it
// can't be folded into ToConfigMap.
//
// Verify this against the confluent-kafka-go OAUTHBEARER example and the
// aws-msk-iam-sasl-signer-go README before relying on it — this couldn't be
// compiled/run here to confirm the exact method signatures still match.
//
// If auth.mode is not "aws-msk-iam", returns a no-op attach function.
func MaybeConfigureAWSIAM(cm *kafka.ConfigMap, props map[string]string) (attach func(kafka.Handle) error, err error) {
	if props["auth.mode"] != "aws-msk-iam" {
		return func(kafka.Handle) error { return nil }, nil
	}

	region := props["aws.region"]
	if region == "" {
		return nil, fmt.Errorf("auth.mode=aws-msk-iam requires aws.region to be set in the properties file")
	}

	if err := cm.SetKey("security.protocol", "SASL_SSL"); err != nil {
		return nil, err
	}
	if err := cm.SetKey("sasl.mechanisms", "OAUTHBEARER"); err != nil {
		return nil, err
	}

	attach = func(h kafka.Handle) error {
		return h.SetOAuthBearerTokenRefreshCallback(func(_ kafka.Handle, _ string) {
			token, expirationMs, genErr := signer.GenerateAuthToken(context.Background(), region)
			if genErr != nil {
				h.SetOAuthBearerTokenFailure(genErr.Error())
				return
			}
			setErr := h.SetOAuthBearerToken(kafka.OAuthBearerToken{
				TokenValue: token,
				Expiration: expirationMs,
			})
			if setErr != nil {
				h.SetOAuthBearerTokenFailure(setErr.Error())
			}
		})
	}
	return attach, nil
}

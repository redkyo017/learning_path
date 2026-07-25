//go:build bedrock

// Bedrock provider — compiled in only with `go build -tags bedrock`, so the
// default (mock) build has no AWS dependency and runs fully offline.
//
// First add the deps (once), then build/run with the tag:
//
//	go get github.com/aws/aws-sdk-go-v2/config \
//	       github.com/aws/aws-sdk-go-v2/service/bedrockruntime
//	MODEL_PROVIDER=bedrock AWS_REGION=ap-southeast-1 go run -tags bedrock . ingest
//
// Embeddings: Amazon Titan Text Embeddings v2  (amazon.titan-embed-text-v2:0)
// Completion: Claude on Bedrock                (anthropic.claude-opus-4-8 by default)
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/bedrockruntime"
)

type bedrockModel struct {
	rt       *bedrockruntime.Client
	embedID  string
	chatID   string
	inPer1K  float64
	outPer1K float64
}

func init() {
	registerProvider("bedrock", func() (Model, error) {
		cfg, err := config.LoadDefaultConfig(context.Background())
		if err != nil {
			return nil, fmt.Errorf("aws config: %w", err)
		}
		return &bedrockModel{
			rt:      bedrockruntime.NewFromConfig(cfg),
			embedID: env("BEDROCK_EMBED_MODEL", "amazon.titan-embed-text-v2:0"),
			// Default to Opus per Anthropic guidance; swap to
			// anthropic.claude-haiku-4-5 for a far cheaper RAG answerer.
			chatID:   env("BEDROCK_CHAT_MODEL", "anthropic.claude-opus-4-8"),
			inPer1K:  envFloat("PRICE_IN_PER_1K", 0.005),  // approximate, $/1K input tokens
			outPer1K: envFloat("PRICE_OUT_PER_1K", 0.025), // approximate, $/1K output tokens
		}, nil
	})
}

func (b *bedrockModel) Name() string { return "bedrock (" + b.embedID + " + " + b.chatID + ")" }

func (b *bedrockModel) Embed(ctx context.Context, texts []string) ([][]float32, error) {
	out := make([][]float32, len(texts))
	for i, t := range texts {
		body, _ := json.Marshal(map[string]any{
			"inputText":  t,
			"dimensions": EmbedDim,
			"normalize":  true,
		})
		resp, err := b.rt.InvokeModel(ctx, &bedrockruntime.InvokeModelInput{
			ModelId:     aws.String(b.embedID),
			ContentType: aws.String("application/json"),
			Accept:      aws.String("application/json"),
			Body:        body,
		})
		if err != nil {
			return nil, fmt.Errorf("titan embed: %w", err)
		}
		var r struct {
			Embedding []float32 `json:"embedding"`
		}
		if err := json.Unmarshal(resp.Body, &r); err != nil {
			return nil, err
		}
		out[i] = r.Embedding
	}
	return out, nil
}

func (b *bedrockModel) Complete(ctx context.Context, prompt string) (string, error) {
	body, _ := json.Marshal(map[string]any{
		"anthropic_version": "bedrock-2023-05-31",
		"max_tokens":        512,
		"messages": []map[string]any{
			{"role": "user", "content": []map[string]any{{"type": "text", "text": prompt}}},
		},
	})
	resp, err := b.rt.InvokeModel(ctx, &bedrockruntime.InvokeModelInput{
		ModelId:     aws.String(b.chatID),
		ContentType: aws.String("application/json"),
		Accept:      aws.String("application/json"),
		Body:        body,
	})
	if err != nil {
		return "", fmt.Errorf("claude complete: %w", err)
	}
	var r struct {
		Content []struct {
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.Unmarshal(resp.Body, &r); err != nil {
		return "", err
	}
	if len(r.Content) == 0 {
		return "", nil
	}
	return r.Content[0].Text, nil
}

func (b *bedrockModel) Cost(inTokens, outTokens int) float64 {
	return float64(inTokens)/1000*b.inPer1K + float64(outTokens)/1000*b.outPer1K
}

func envFloat(k string, def float64) float64 {
	if v := env(k, ""); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			return f
		}
	}
	return def
}

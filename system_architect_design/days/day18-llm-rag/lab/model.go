package main

import (
	"context"
	"fmt"
)

// EmbedDim is fixed for the whole lab: the schema declares vector(1024), so the
// query embedding and the chunk embeddings must all be 1024-dim and normalized.
const EmbedDim = 1024

// Model is the pluggable interface every provider implements. The RAG pipeline
// (ingest / retrieve / answer / cache) is written against THIS — swapping the
// provider does not touch the pipeline. That is the whole point of keeping the
// model client pluggable (see the ADR).
type Model interface {
	Name() string
	Embed(ctx context.Context, texts []string) ([][]float32, error)
	Complete(ctx context.Context, prompt string) (string, error)
	// Cost returns an approximate USD cost for the given token counts, so the
	// lab can print $/query. Prices are approximate + provider-configurable.
	Cost(inTokens, outTokens int) float64
}

// Provider registry. Each provider file registers itself in an init(); which
// providers are compiled in depends on build tags:
//
//	default build            -> "mock" only  (no external deps, runs offline)
//	go build -tags bedrock   -> also "bedrock" (AWS SDK, Titan + Claude)
var providers = map[string]func() (Model, error){}

func registerProvider(name string, f func() (Model, error)) { providers[name] = f }

func newModel() (Model, error) {
	name := env("MODEL_PROVIDER", "mock")
	f, ok := providers[name]
	if !ok {
		avail := make([]string, 0, len(providers))
		for k := range providers {
			avail = append(avail, k)
		}
		return nil, fmt.Errorf(
			"unknown MODEL_PROVIDER %q (compiled-in: %v). For Bedrock, rebuild with: go run -tags bedrock . <cmd>",
			name, avail)
	}
	return f()
}

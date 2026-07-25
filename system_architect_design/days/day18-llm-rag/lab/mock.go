package main

import (
	"context"
	"hash/fnv"
	"math"
	"strings"
	"unicode"
)

// mockModel is a deterministic, dependency-free provider so the whole RAG
// pipeline — ingest, retrieval, precision@k, and the semantic cache — runs
// offline with no API key. Embeddings are hashed bag-of-words vectors: they carry
// LEXICAL similarity (chunks sharing words with the query rank higher), enough to
// demonstrate the mechanics and how precision@k moves with chunk size and k.
//
// It is NOT semantic: paraphrases with no shared words won't match. For real
// semantic quality, build with `-tags bedrock` and set MODEL_PROVIDER=bedrock.
type mockModel struct{}

func init() {
	registerProvider("mock", func() (Model, error) { return mockModel{}, nil })
}

func (mockModel) Name() string { return "mock (hashed bag-of-words, offline)" }

func (mockModel) Embed(_ context.Context, texts []string) ([][]float32, error) {
	out := make([][]float32, len(texts))
	for i, t := range texts {
		v := make([]float32, EmbedDim)
		for _, tok := range tokenize(t) {
			h := fnv.New32a()
			_, _ = h.Write([]byte(tok))
			v[h.Sum32()%EmbedDim] += 1
		}
		normalize(v)
		out[i] = v
	}
	return out, nil
}

// Complete returns a deterministic, grounded-looking answer. Answer *quality* is
// not what this lab measures — retrieval precision, latency, and cost are — so a
// canned extractive reply is fine. It echoes the context the retriever supplied.
func (mockModel) Complete(_ context.Context, prompt string) (string, error) {
	ctxText := prompt
	if i := strings.Index(prompt, "Context:"); i >= 0 {
		ctxText = prompt[i+len("Context:"):]
	}
	ctxText = strings.TrimSpace(ctxText)
	if len(ctxText) > 240 {
		ctxText = ctxText[:240] + "…"
	}
	return "(mock answer, grounded in retrieved context) " + ctxText, nil
}

// Cost is zero — the mock runs locally.
func (mockModel) Cost(_, _ int) float64 { return 0 }

func tokenize(s string) []string {
	return strings.FieldsFunc(strings.ToLower(s), func(r rune) bool {
		return !unicode.IsLetter(r) && !unicode.IsDigit(r)
	})
}

func normalize(v []float32) {
	var sum float64
	for _, x := range v {
		sum += float64(x) * float64(x)
	}
	n := math.Sqrt(sum)
	if n == 0 {
		return
	}
	for i := range v {
		v[i] = float32(float64(v[i]) / n)
	}
}

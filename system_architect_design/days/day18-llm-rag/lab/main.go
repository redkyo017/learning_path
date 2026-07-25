// Day 18 lab — minimal RAG on pgvector with a PLUGGABLE model client.
//
// Subcommands:
//
//	go run . ingest              # chunk + embed corpus.jsonl into pgvector
//	go run . ask "your question" # retrieve top-k -> prompt -> answer (with cache)
//	go run . eval                # precision@k (k=3 vs 5) + p95 latency + $/query + cache win
//	go run . resetcache          # clear the semantic cache
//	go run . status              # counts + which model provider is active
//
// Default provider is the offline `mock` (no key). For real Bedrock quality:
//
//	go get github.com/aws/aws-sdk-go-v2/config github.com/aws/aws-sdk-go-v2/service/bedrockruntime
//	MODEL_PROVIDER=bedrock AWS_REGION=ap-southeast-1 go run -tags bedrock . ingest
//
// Key env (defaults suit the lab): DATABASE_URL, MODEL_PROVIDER, TOP_K (5),
// CHUNK_MAX_CHARS (400), CACHE_THRESHOLD (0.05 cosine distance).
package main

import (
	"context"
	"fmt"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	ctx := context.Background()
	model, err := newModel()
	if err != nil {
		die(err)
	}
	pool := mustPool(ctx)
	defer pool.Close()

	switch os.Args[1] {
	case "ingest":
		cmdIngest(ctx, pool, model)
	case "ask":
		if len(os.Args) < 3 {
			usage()
		}
		cmdAsk(ctx, pool, model, strings.Join(os.Args[2:], " "))
	case "eval":
		cmdEval(ctx, pool, model)
	case "resetcache":
		mustExec(ctx, pool, `TRUNCATE query_cache`)
		fmt.Println("semantic cache cleared")
	case "status":
		cmdStatus(ctx, pool, model)
	default:
		usage()
	}
}

// ---- ingest -----------------------------------------------------------------

type doc struct {
	ID   string `json:"id"`
	Text string `json:"text"`
}

func cmdIngest(ctx context.Context, pool *pgxpool.Pool, model Model) {
	docs := readJSONL[doc]("corpus.jsonl")
	mustExec(ctx, pool, `TRUNCATE chunks`)

	total := 0
	maxChars := envInt("CHUNK_MAX_CHARS", 400)
	for _, d := range docs {
		chunks := chunk(d.Text, maxChars)
		vecs, err := model.Embed(ctx, chunks)
		if err != nil {
			die(err)
		}
		for i, c := range chunks {
			if _, err := pool.Exec(ctx,
				`INSERT INTO chunks (doc_id, chunk_index, content, embedding)
				 VALUES ($1,$2,$3,$4::vector)`,
				d.ID, i, c, vecToString(vecs[i])); err != nil {
				die(err)
			}
			total++
		}
	}
	fmt.Printf("ingested %d docs -> %d chunks (chunk_max_chars=%d, provider=%s)\n",
		len(docs), total, maxChars, model.Name())
}

// chunk splits text into pieces up to maxChars, breaking on sentence boundaries
// so ideas aren't cut mid-sentence. Short docs become a single chunk.
func chunk(text string, maxChars int) []string {
	sentences := strings.SplitAfter(text, ". ")
	var out []string
	var cur strings.Builder
	for _, s := range sentences {
		if cur.Len() > 0 && cur.Len()+len(s) > maxChars {
			out = append(out, strings.TrimSpace(cur.String()))
			cur.Reset()
		}
		cur.WriteString(s)
	}
	if cur.Len() > 0 {
		out = append(out, strings.TrimSpace(cur.String()))
	}
	if len(out) == 0 {
		out = []string{text}
	}
	return out
}

// ---- retrieval + answer -----------------------------------------------------

type hit struct {
	docID   string
	content string
	dist    float64
}

func retrieve(ctx context.Context, pool *pgxpool.Pool, qvec []float32, k int) []hit {
	rows, err := pool.Query(ctx,
		`SELECT doc_id, content, embedding <=> $1::vector AS dist
		 FROM chunks
		 ORDER BY embedding <=> $1::vector
		 LIMIT $2`,
		vecToString(qvec), k)
	if err != nil {
		die(err)
	}
	defer rows.Close()
	var out []hit
	for rows.Next() {
		var h hit
		if err := rows.Scan(&h.docID, &h.content, &h.dist); err != nil {
			die(err)
		}
		out = append(out, h)
	}
	return out
}

type answer struct {
	text     string
	sources  []hit
	cacheHit bool
	inTok    int
	outTok   int
	cost     float64
	latency  time.Duration
}

// answerQuery is the core RAG path: (optional) semantic cache -> retrieve -> prompt
// -> LLM -> store in cache.
func answerQuery(ctx context.Context, pool *pgxpool.Pool, model Model, q string, k int, useCache bool) answer {
	start := time.Now()
	qvecs, err := model.Embed(ctx, []string{q})
	if err != nil {
		die(err)
	}
	qvec := qvecs[0]

	if useCache {
		if cached, ok := cacheLookup(ctx, pool, qvec); ok {
			return answer{text: cached, cacheHit: true, latency: time.Since(start)}
		}
	}

	sources := retrieve(ctx, pool, qvec, k)
	var b strings.Builder
	b.WriteString("Answer the question using ONLY the Context below. ")
	b.WriteString("If the answer is not in the context, say you don't know.\n\nContext:\n")
	for _, s := range sources {
		b.WriteString("- ")
		b.WriteString(s.content)
		b.WriteString("\n")
	}
	b.WriteString("\nQuestion: ")
	b.WriteString(q)
	b.WriteString("\nAnswer:")
	prompt := b.String()

	text, err := model.Complete(ctx, prompt)
	if err != nil {
		die(err)
	}
	in, out := estimateTokens(prompt), estimateTokens(text)

	if useCache {
		if _, err := pool.Exec(ctx,
			`INSERT INTO query_cache (query, embedding, answer) VALUES ($1,$2::vector,$3)`,
			q, vecToString(qvec), text); err != nil {
			die(err)
		}
	}
	return answer{
		text: text, sources: sources, inTok: in, outTok: out,
		cost: model.Cost(in, out), latency: time.Since(start),
	}
}

// cacheLookup returns a cached answer if the nearest previously-answered query is
// within CACHE_THRESHOLD cosine distance. Too-loose a threshold serves the answer
// to a DIFFERENT question — tune it (see the ADR / theory).
func cacheLookup(ctx context.Context, pool *pgxpool.Pool, qvec []float32) (string, bool) {
	threshold := envFloatMain("CACHE_THRESHOLD", 0.05)
	var ans string
	var dist float64
	err := pool.QueryRow(ctx,
		`SELECT answer, embedding <=> $1::vector AS dist
		 FROM query_cache ORDER BY embedding <=> $1::vector LIMIT 1`,
		vecToString(qvec)).Scan(&ans, &dist)
	if err != nil { // no rows -> miss
		return "", false
	}
	if dist <= threshold {
		return ans, true
	}
	return "", false
}

// ---- ask --------------------------------------------------------------------

func cmdAsk(ctx context.Context, pool *pgxpool.Pool, model Model, q string) {
	k := envInt("TOP_K", 5)
	a := answerQuery(ctx, pool, model, q, k, os.Getenv("NOCACHE") == "")
	fmt.Printf("Q: %s\n\nA: %s\n\n", q, a.text)
	if a.cacheHit {
		fmt.Printf("[semantic cache HIT]  latency=%s\n", a.latency.Round(time.Millisecond))
		return
	}
	fmt.Println("sources (doc_id  cosine_dist):")
	for _, s := range a.sources {
		fmt.Printf("  %-6s %.4f\n", s.docID, s.dist)
	}
	fmt.Printf("\nlatency=%s  in_tok≈%d out_tok≈%d  est_cost=$%.6f\n",
		a.latency.Round(time.Millisecond), a.inTok, a.outTok, a.cost)
}

// ---- eval -------------------------------------------------------------------

type labeled struct {
	Query    string `json:"query"`
	Expected string `json:"expected"` // expected doc_id
}

func cmdEval(ctx context.Context, pool *pgxpool.Pool, model Model) {
	qs := readJSONL[labeled]("queries.jsonl")
	fmt.Printf("provider=%s  queries=%d\n\n", model.Name(), len(qs))

	// --- precision@k (here: hit-rate@k on the labeled gold doc) ---
	fmt.Println("precision@k (fraction of queries whose expected doc is in top-k):")
	for _, k := range []int{3, 5} {
		hits := 0
		for _, q := range qs {
			qvec, _ := model.Embed(ctx, []string{q.Query})
			for _, h := range retrieve(ctx, pool, qvec[0], k) {
				if h.docID == q.Expected {
					hits++
					break
				}
			}
		}
		fmt.Printf("  precision@%d = %.2f  (%d/%d)\n", k, float64(hits)/float64(len(qs)), hits, len(qs))
	}

	// --- latency + cost, cold (empty cache) then warm (cache primed) ---
	k := envInt("TOP_K", 5)
	mustExec(ctx, pool, `TRUNCATE query_cache`)
	var cold []time.Duration
	var totalCost float64
	for _, q := range qs {
		a := answerQuery(ctx, pool, model, q.Query, k, true)
		cold = append(cold, a.latency)
		totalCost += a.cost
	}
	var warm []time.Duration
	warmHits := 0
	for _, q := range qs {
		a := answerQuery(ctx, pool, model, q.Query, k, true)
		warm = append(warm, a.latency)
		if a.cacheHit {
			warmHits++
		}
	}

	fmt.Printf("\nlatency cold (cache empty):  p50=%s  p95=%s\n", pctl(cold, 50), pctl(cold, 95))
	fmt.Printf("latency warm (cache primed): p50=%s  p95=%s  cache_hits=%d/%d\n",
		pctl(warm, 50), pctl(warm, 95), warmHits, len(qs))
	fmt.Printf("avg $/query (cold): $%.6f  (provider=%s)\n", totalCost/float64(len(qs)), model.Name())
	fmt.Println("\nTune: change CHUNK_MAX_CHARS / TOP_K / CACHE_THRESHOLD, re-ingest, re-eval.")
}

// ---- status -----------------------------------------------------------------

func cmdStatus(ctx context.Context, pool *pgxpool.Pool, model Model) {
	var chunks, docs, cache int
	_ = pool.QueryRow(ctx, `SELECT count(*) FROM chunks`).Scan(&chunks)
	_ = pool.QueryRow(ctx, `SELECT count(DISTINCT doc_id) FROM chunks`).Scan(&docs)
	_ = pool.QueryRow(ctx, `SELECT count(*) FROM query_cache`).Scan(&cache)
	fmt.Printf("provider=%s\nchunks=%d  docs=%d  cache_entries=%d\n", model.Name(), chunks, docs, cache)
}

// ---- helpers ----------------------------------------------------------------

func usage() {
	fmt.Fprintln(os.Stderr, `usage: go run . [ingest | ask "question" | eval | resetcache | status]`)
	os.Exit(2)
}

func die(err error) { fmt.Fprintln(os.Stderr, "error:", err); os.Exit(1) }

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
func envInt(k string, def int) int {
	if v := os.Getenv(k); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return def
}
func envFloatMain(k string, def float64) float64 {
	if v := os.Getenv(k); v != "" {
		if f, err := strconv.ParseFloat(v, 64); err == nil {
			return f
		}
	}
	return def
}

func mustPool(ctx context.Context) *pgxpool.Pool {
	pool, err := pgxpool.New(ctx, env("DATABASE_URL", "postgres://postgres:pass@localhost:5432/app"))
	if err != nil {
		die(err)
	}
	return pool
}
func mustExec(ctx context.Context, pool *pgxpool.Pool, sql string) {
	if _, err := pool.Exec(ctx, sql); err != nil {
		die(err)
	}
}

// vecToString formats a float32 slice as a pgvector literal: [0.1,0.2,...].
func vecToString(v []float32) string {
	var b strings.Builder
	b.WriteByte('[')
	for i, x := range v {
		if i > 0 {
			b.WriteByte(',')
		}
		b.WriteString(strconv.FormatFloat(float64(x), 'f', -1, 32))
	}
	b.WriteByte(']')
	return b.String()
}

// estimateTokens is a rough ~4-chars-per-token approximation, good enough for a
// $/query estimate. For exact counts use the provider's tokenizer.
func estimateTokens(s string) int { return (len(s) + 3) / 4 }

func pctl(ds []time.Duration, p int) time.Duration {
	if len(ds) == 0 {
		return 0
	}
	s := append([]time.Duration(nil), ds...)
	sort.Slice(s, func(i, j int) bool { return s[i] < s[j] })
	idx := (p * (len(s) - 1)) / 100
	return s[idx].Round(time.Millisecond)
}

package main

import (
	"bufio"
	"context"
	"flag"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"golang.org/x/sync/errgroup"
)

type result struct {
	URL        string `json:"url"`
	StatusCode int    `json:"status_code,omitempty"`
	LatencyMs  int64  `json:"latency_ms"`
	Err        string `json:"error,omitempty"`
}

func checkURL(ctx context.Context, client *http.Client, url string) result {
	start := time.Now()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return result{URL: url, LatencyMs: time.Since(start).Milliseconds(), Err: err.Error()}
	}
	resp, err := client.Do(req)
	latencyMs := time.Since(start).Milliseconds()
	if err != nil {
		return result{URL: url, LatencyMs: latencyMs, Err: err.Error()}
	}
	defer resp.Body.Close()
	return result{URL: url, StatusCode: resp.StatusCode, LatencyMs: latencyMs}
}

func main() {
	workers := flag.Int("workers", 10, "number of concurrent workers")
	timeout := flag.Duration("timeout", 30*time.Second, "global timeout")
	flag.Parse()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	ctx, cancel := context.WithTimeout(context.Background(), *timeout)
	defer cancel()

	// Read URLs from stdin before starting workers
	var urls []string
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		if u := strings.TrimSpace(scanner.Text()); u != "" {
			urls = append(urls, u)
		}
	}

	if len(urls) == 0 {
		slog.Warn("no URLs provided on stdin")
		return
	}

	var (
		mu      sync.Mutex
		results []result
	)

	client := &http.Client{Timeout: 10 * time.Second}
	g, ctx := errgroup.WithContext(ctx)
	g.SetLimit(*workers)

	for _, url := range urls {
		url := url
		g.Go(func() error {
			r := checkURL(ctx, client, url)
			mu.Lock()
			results = append(results, r)
			mu.Unlock()
			return nil
		})
	}

	if err := g.Wait(); err != nil {
		slog.Error("worker group error", "err", err)
	}

	var failed int
	for _, r := range results {
		if r.Err != "" {
			failed++
			slog.Error("check failed",
				"url", r.URL,
				"error", r.Err,
				"latency_ms", r.LatencyMs,
			)
		} else {
			slog.Info("check ok",
				"url", r.URL,
				"status_code", r.StatusCode,
				"latency_ms", r.LatencyMs,
			)
		}
	}

	slog.Info("summary",
		"total", len(results),
		"failed", failed,
		"passed", len(results)-failed,
	)

	if failed > 0 {
		os.Exit(1)
	}
}

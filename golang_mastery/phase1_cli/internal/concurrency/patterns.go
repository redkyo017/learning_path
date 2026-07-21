package concurrency

import (
	"context"
	"errors"
	"log/slog"
	"sync"
	"time"

	"golang.org/x/sync/errgroup"
)

// LeakyWorker launches goroutines that never stop — DO NOT USE IN PRODUCTION.
// This is a study artifact to make goroutine leaks visible.
func LeakyWorker(items []string, process func(string)) {
	for _, item := range items {
		item := item // capture loop variable (required pre-Go 1.22)
		go func() {
			for {
				process(item)
				time.Sleep(100 * time.Millisecond)
			}
			// BUG: no exit condition — this goroutine runs forever
		}()
	}
}

// BoundedWorker is the fixed version: every goroutine exits when ctx is done.
func BoundedWorker(ctx context.Context, items []string, process func(string)) {
	for _, item := range items {
		item := item
		go func() {
			for {
				select {
				case <-ctx.Done():
					slog.Info("worker exiting", "item", item, "reason", ctx.Err())
					return
				default:
					process(item)
					time.Sleep(100 * time.Millisecond)
				}
			}
		}()
	}
}

// LazyConfig demonstrates sync.Once for safe lazy initialization.
// The inner init runs exactly once, even under concurrent access.
type LazyConfig struct {
	once   sync.Once
	config map[string]string
}

func (c *LazyConfig) Get(key string) string {
	c.once.Do(func() {
		c.config = map[string]string{
			"host": "localhost",
			"port": "5432",
		}
	})
	return c.config[key]
}

// RWCounter shows RWMutex: many readers can proceed concurrently,
// but a writer takes exclusive access.
type RWCounter struct {
	mu    sync.RWMutex
	value int
}

func (c *RWCounter) Inc() {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.value++
}

func (c *RWCounter) Get() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.value
}

// CancelWithCause demonstrates the Go 1.20 addition: you can attach a
// specific error to a cancellation, not just signal done.
func RunWithCause(ctx context.Context) {
	ctx, cancel := context.WithCancelCause(ctx)

	go func() {
		time.Sleep(50 * time.Millisecond)
		cancel(ErrNotFound) // attach a specific cause
	}()

	<-ctx.Done()
	cause := context.Cause(ctx) // retrieves ErrNotFound, not context.Canceled
	slog.Info("cancelled", "cause", cause)
}

// ErrNotFound is a sentinel used in this demo.
var ErrNotFound = errors.New("resource not found")

// Pipeline demonstrates typed channel directions — send-only and receive-only.
// This prevents callers from accidentally closing the wrong end.

func producer(ctx context.Context, items []int) <-chan int {
	out := make(chan int, len(items))
	go func() {
		defer close(out)
		for _, v := range items {
			select {
			case out <- v:
			case <-ctx.Done():
				return
			}
		}
	}()
	return out
}

func doubler(ctx context.Context, in <-chan int) <-chan int {
	out := make(chan int, cap(in))
	go func() {
		defer close(out)
		for v := range in {
			select {
			case out <- v * 2:
			case <-ctx.Done():
				return
			}
		}
	}()
	return out
}

// RunPipeline chains producer → doubler and collects results.
func RunPipeline(ctx context.Context, items []int) []int {
	ch := producer(ctx, items)
	ch = doubler(ctx, ch)
	var results []int
	for v := range ch {
		results = append(results, v)
	}
	return results
}

// BoundedPool runs process on each item using at most maxWorkers goroutines.
// If any call returns an error, remaining work is cancelled.
func BoundedPool[T any](
	ctx context.Context,
	items []T,
	maxWorkers int,
	process func(context.Context, T) error,
) error {
	g, ctx := errgroup.WithContext(ctx)
	g.SetLimit(maxWorkers)
	for _, item := range items {
		item := item
		g.Go(func() error {
			return process(ctx, item)
		})
	}
	return g.Wait()
}

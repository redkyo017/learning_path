package concurrency_test

import (
	"context"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"github.com/yourname/golang-mastery/phase1-cli/internal/concurrency"
)

func TestBoundedWorkerExits(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
	defer cancel()

	var count atomic.Int64
	concurrency.BoundedWorker(ctx, []string{"a", "b", "c"}, func(s string) {
		count.Add(1)
	})

	<-ctx.Done()
	time.Sleep(50 * time.Millisecond) // let final iterations settle

	before := count.Load()
	time.Sleep(200 * time.Millisecond)
	after := count.Load()

	if after > before+3 {
		t.Errorf("goroutines still running after context cancel: count grew from %d to %d", before, after)
	}
}

func TestLazyConfig(t *testing.T) {
	cfg := &concurrency.LazyConfig{}
	var wg sync.WaitGroup
	for range 10 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			v := cfg.Get("host")
			if v != "localhost" {
				t.Errorf("unexpected value: %s", v)
			}
		}()
	}
	wg.Wait()
}

func TestRWCounter(t *testing.T) {
	c := &concurrency.RWCounter{}
	var wg sync.WaitGroup
	for range 100 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			c.Inc()
		}()
	}
	wg.Wait()
	if c.Get() != 100 {
		t.Errorf("counter = %d, want 100", c.Get())
	}
}

func TestPipeline(t *testing.T) {
	ctx := context.Background()
	got := concurrency.RunPipeline(ctx, []int{1, 2, 3})
	want := []int{2, 4, 6}
	for i, v := range want {
		if got[i] != v {
			t.Errorf("Pipeline[%d] = %d, want %d", i, got[i], v)
		}
	}
}

func TestBoundedPool(t *testing.T) {
	ctx := context.Background()
	items := []int{1, 2, 3, 4, 5}
	var mu sync.Mutex
	var processed []int
	err := concurrency.BoundedPool(ctx, items, 2, func(ctx context.Context, n int) error {
		mu.Lock()
		processed = append(processed, n)
		mu.Unlock()
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(processed) != 5 {
		t.Errorf("processed %d items, want 5", len(processed))
	}
}

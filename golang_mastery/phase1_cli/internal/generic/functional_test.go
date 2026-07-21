package generic_test

import (
	"errors"
	"testing"

	"github.com/yourname/golang-mastery/phase1-cli/internal/generic"
)

func TestMap(t *testing.T) {
	in := []int{1, 2, 3}
	got := generic.Map(in, func(n int) int { return n * 2 })
	want := []int{2, 4, 6}
	for i, v := range want {
		if got[i] != v {
			t.Errorf("Map[%d] = %d, want %d", i, got[i], v)
		}
	}
}

func TestFilter(t *testing.T) {
	in := []int{1, 2, 3, 4, 5}
	got := generic.Filter(in, func(n int) bool { return n%2 == 0 })
	if len(got) != 2 || got[0] != 2 || got[1] != 4 {
		t.Errorf("Filter = %v, want [2 4]", got)
	}
}

func TestReduce(t *testing.T) {
	in := []int{1, 2, 3, 4}
	got := generic.Reduce(in, 0, func(acc, n int) int { return acc + n })
	if got != 10 {
		t.Errorf("Reduce = %d, want 10", got)
	}
}

func TestCache(t *testing.T) {
	c := generic.NewCache[string, int]()
	c.Set("a", 1)
	v, ok := c.Get("a")
	if !ok || v != 1 {
		t.Errorf("Get(a) = %d, %v; want 1, true", v, ok)
	}
	c.Delete("a")
	_, ok = c.Get("a")
	if ok {
		t.Error("expected key to be deleted")
	}
}

func TestResult(t *testing.T) {
	r := generic.Ok(42)
	if !r.IsOk() || r.Value() != 42 {
		t.Error("Ok result should hold value")
	}
	e := generic.Err[int](errors.New("bad"))
	if e.IsOk() {
		t.Error("Err result should not be ok")
	}
	_, err := e.Unwrap()
	if err == nil {
		t.Error("Err result should have error")
	}
}

package stdlib_tour_test

import (
	"testing"

	"github.com/yourname/golang-mastery/phase1-cli/internal/stdlib_tour"
)

func TestErrorChain(t *testing.T) {
	err := stdlib_tour.FetchResource("item-42")

	if !stdlib_tour.IsNotFound(err) {
		t.Error("expected IsNotFound to unwrap through fmt.Errorf %w chain")
	}

	id, ok := stdlib_tour.ExtractResourceID(err)
	if !ok || id != "item-42" {
		t.Errorf("ExtractResourceID = %q, %v; want item-42, true", id, ok)
	}
}

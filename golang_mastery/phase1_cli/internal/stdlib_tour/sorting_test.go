package stdlib_tour_test

import (
	"testing"

	"github.com/yourname/golang-mastery/phase1-cli/internal/stdlib_tour"
)

func TestSortByAge(t *testing.T) {
	people := []stdlib_tour.Person{
		{"Charlie", 35}, {"Alice", 30}, {"Bob", 25},
	}
	sorted := stdlib_tour.SortByAge(people)
	if sorted[0].Name != "Bob" || sorted[2].Name != "Charlie" {
		t.Errorf("unexpected order: %v", sorted)
	}
}

func TestUniqueNames(t *testing.T) {
	people := []stdlib_tour.Person{
		{"Alice", 30}, {"Bob", 25}, {"Alice", 22},
	}
	got := stdlib_tour.UniqueNames(people)
	if len(got) != 2 || got[0] != "Alice" || got[1] != "Bob" {
		t.Errorf("UniqueNames = %v, want [Alice Bob]", got)
	}
}

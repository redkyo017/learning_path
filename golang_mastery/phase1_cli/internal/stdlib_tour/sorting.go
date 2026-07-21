package stdlib_tour

import (
	"cmp"
	"slices"
)

type Person struct {
	Name string
	Age  int
}

// SortByAge sorts people by age ascending.
// Pre-1.21: sort.Slice(people, func(i,j int) bool { return people[i].Age < people[j].Age })
func SortByAge(people []Person) []Person {
	slices.SortFunc(people, func(a, b Person) int {
		return cmp.Compare(a.Age, b.Age)
	})
	return people
}

// OldestOver returns the first person older than minAge, or false if none.
func OldestOver(people []Person, minAge int) (Person, bool) {
	idx := slices.IndexFunc(people, func(p Person) bool {
		return p.Age > minAge
	})
	if idx == -1 {
		return Person{}, false
	}
	return people[idx], true
}

// UniqueNames returns deduplicated names, sorted.
func UniqueNames(people []Person) []string {
	names := make([]string, len(people))
	for i, p := range people {
		names[i] = p.Name
	}
	slices.Sort(names)
	return slices.Compact(names)
}

// GroupByFirstLetter groups people by the first letter of their name.
// Returns a new map — maps.Clone avoids mutating the input accidentally.
func GroupByFirstLetter(people []Person) map[string][]Person {
	result := make(map[string][]Person)
	for _, p := range people {
		key := string(p.Name[0])
		result[key] = append(result[key], p)
	}
	return result
}

// MapKeys returns all keys of a map, deterministically sorted.
// Note: maps.Keys returns iter.Seq[K] in Go 1.23+; we range over the map
// directly here so this compiles on Go 1.22.
func MapKeys[K cmp.Ordered, V any](m map[K]V) []K {
	keys := make([]K, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	slices.Sort(keys)
	return keys
}

package generic

// Map transforms each element of s using f.
func Map[T, U any](s []T, f func(T) U) []U {
	result := make([]U, len(s))
	for i, v := range s {
		result[i] = f(v)
	}
	return result
}

// Filter returns elements of s for which f returns true.
func Filter[T any](s []T, f func(T) bool) []T {
	var result []T
	for _, v := range s {
		if f(v) {
			result = append(result, v)
		}
	}
	return result
}

// Reduce folds s into a single value, starting from init.
func Reduce[T, U any](s []T, init U, f func(U, T) U) U {
	acc := init
	for _, v := range s {
		acc = f(acc, v)
	}
	return acc
}

// WHY NOT interface{}: The pre-generics Map would look like:
//
//	func MapAny(s []interface{}, f func(interface{}) interface{}) []interface{}
//
// Callers lose type information; they must type-assert every element.
// The generic Map[T, U any] preserves types at compile time — the compiler
// rejects Map([]int{1,2,3}, func(s string) string {...}) at compile time,
// not at runtime.
//
// WHEN NOT TO USE GENERICS: if an interface satisfies the constraint, use
// the interface. Example: io.Writer, http.Handler, sort.Interface all use
// interfaces and are correct — they describe behavior, not type identity.
// Generics are for type-safe containers and algorithms that work on any type.

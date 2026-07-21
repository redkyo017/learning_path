package generic

// Result holds either a value of type T or an error, never both.
type Result[T any] struct {
	value T
	err   error
}

func Ok[T any](v T) Result[T]        { return Result[T]{value: v} }
func Err[T any](err error) Result[T] { return Result[T]{err: err} }

func (r Result[T]) Unwrap() (T, error) { return r.value, r.err }
func (r Result[T]) IsOk() bool         { return r.err == nil }
func (r Result[T]) Value() T           { return r.value }
func (r Result[T]) Error() error       { return r.err }

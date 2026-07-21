package stdlib_tour

import (
	"errors"
	"fmt"
)

var ErrNotFound = errors.New("not found")
var ErrPermission = errors.New("permission denied")

type ResourceError struct {
	ID  string
	Err error
}

func (e *ResourceError) Error() string { return fmt.Sprintf("resource %q: %v", e.ID, e.Err) }
func (e *ResourceError) Unwrap() error { return e.Err }

// FetchResource simulates a layered error chain.
func FetchResource(id string) error {
	inner := &ResourceError{ID: id, Err: ErrNotFound}
	return fmt.Errorf("fetch: %w", inner)
}

// IsNotFound unwraps any depth to find ErrNotFound.
func IsNotFound(err error) bool {
	return errors.Is(err, ErrNotFound)
}

// ExtractResourceID unwraps to find the ResourceError and returns its ID.
func ExtractResourceID(err error) (string, bool) {
	var re *ResourceError
	if errors.As(err, &re) {
		return re.ID, true
	}
	return "", false
}

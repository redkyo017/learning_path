package proxy

import "net/http"

// Upstream describes a backend service the gateway can route to.
type Upstream struct {
	Name    string
	BaseURL string // e.g. "http://localhost:8080"
}

// Registry holds named upstreams.
type Registry struct {
	upstreams map[string]*Upstream
}

func NewRegistry(upstreams ...*Upstream) *Registry {
	r := &Registry{upstreams: make(map[string]*Upstream)}
	for _, u := range upstreams {
		r.upstreams[u.Name] = u
	}
	return r
}

func (r *Registry) Get(name string) (*Upstream, bool) {
	u, ok := r.upstreams[name]
	return u, ok
}

// Transport returns an *http.Transport tuned for gateway upstream connections.
func Transport() *http.Transport {
	return &http.Transport{
		MaxIdleConns:        200,
		MaxIdleConnsPerHost: 20,
		IdleConnTimeout:     90,
		DisableKeepAlives:   false,
	}
}

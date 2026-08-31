# Solution — Lab Day 17

## Why `Chain` iterates right-to-left

`Chain(h, m1, m2, m3)` must produce `m1(m2(m3(h)))` so that `m1` is the outermost wrapper
and therefore runs first on an incoming request.

To build `m1(m2(m3(h)))` by applying one wrapper at a time, you must start from the inside:

```
step 1 (i=2): h = m3(h)          → h is now m3(h)
step 2 (i=1): h = m2(m3(h))      → h is now m2(m3(h))
step 3 (i=0): h = m1(m2(m3(h)))  → h is now m1(m2(m3(h)))
```

If you iterated left-to-right instead:

```
step 1 (i=0): h = m1(h)          → h is m1(h)
step 2 (i=1): h = m2(m1(h))      → h is m2(m1(h))
step 3 (i=2): h = m3(m2(m1(h)))  → h is m3(m2(m1(h)))
```

That produces `m3` as outermost — `m3` would run first, which is the opposite of the order
you wrote. Right-to-left iteration preserves the intuitive "first listed = first to run"
contract.

---

## `activityid` Director code

```go
proxy.Director = func(req *http.Request) {
    original(req)
    req.Host = u.Host
    // By the time Director runs, requestIDMiddleware has already set X-Request-ID.
    // Copy it to activityid to match WSO2 GW correlation behavior.
    req.Header.Set("activityid", req.Header.Get("X-Request-ID"))
}
```

The `Director` function runs inside `httputil.ReverseProxy.ServeHTTP`, which is the
innermost layer of the chain. At that point all outer middlewares have already run and
modified the request — so `X-Request-ID` is guaranteed to be present.

---

## Exercise 3: Response header middleware

```go
func gatewayHeaderMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Headers added before next.ServeHTTP reach the client if the downstream
        // handler hasn't called WriteHeader yet. For safety, set them after next
        // returns only if using a response-recording wrapper. For simple cases:
        next.ServeHTTP(w, r)
        // Note: adding headers after ServeHTTP only works if the inner handler
        // hasn't already flushed them. The reverse proxy flushes immediately,
        // so for proxy responses you need to set this in ModifyResponse instead.
    })
}
```

For response headers that must survive proxying, set them in `proxy.ModifyResponse`:

```go
proxy.ModifyResponse = func(resp *http.Response) error {
    resp.Header.Set("X-Gateway", "go-gateway/1.0")
    return nil
}
```
